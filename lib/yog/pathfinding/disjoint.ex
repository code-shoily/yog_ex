defmodule Yog.Pathfinding.Disjoint do
  @moduledoc """
  Disjoint shortest path algorithms.

  This module implements algorithms for finding multiple path-disjoint or
  edge-disjoint routes of minimum total cost between a source and a target.

  ## Algorithms

  | Algorithm | Function | Purpose | Complexity |
  |-----------|----------|---------|------------|
  | Suurballe's | `suurballe/4` | Finds two edge-disjoint shortest paths | O((V + E) log V) |

  ## References

  - Suurballe, J. W. (1974). "Disjoint paths in a network". Networks. 4 (2): 125–145.
  """

  alias Yog.Model
  alias Yog.Pathfinding.Dijkstra
  alias Yog.Pathfinding.Path

  @typedoc "Result type for suurballe query"
  @type suurballe_result :: {:ok, [Path.t()]} | :error

  @doc """
  Finds two edge-disjoint paths of minimum total weight between `from` and `to`.

  Uses Suurballe's algorithm, which executes Dijkstra's algorithm twice:
  1. Computes the first shortest path $P_1$ and vertex potentials.
  2. Modifies the edge weights to non-negative reduced costs, reverses the direction
     of the edges in $P_1$, and sets their weights to $0$.
  3. Computes the second shortest path $P_2$ in the modified graph.
  4. Cancels overlapping/antiparallel edges to produce the final two disjoint paths.

  ## Parameters

    * `graph` - The input graph (directed or undirected)
    * `from` - Starting source node
    * `to` - Target destination node
    * `zero` - Zero value for the weight type (default: `0`)
    * `add` - Addition function for weights (default: `&Kernel.+/2`)
    * `compare` - Comparison function for weights (default: `&Yog.Utils.compare/2`)
    * `subtract` - Subtraction function for weights (default: `&Kernel.-/2`)
    * `weight_fn` - Function extracting a numeric weight from edge data (default: checks for nil, then returns 1 or edge value)

  ## Returns

    * `{:ok, [path1, path2]}` - Two disjoint paths sorted by weight/nodes on success
    * `:error` - Less than two edge-disjoint paths exist between `from` and `to`

  ## Examples

      iex> alias Yog.Pathfinding.Disjoint
      iex> graph = Yog.from_edges(:directed, [
      ...>   {1, 2, 1}, {2, 4, 1},
      ...>   {1, 3, 1}, {3, 4, 1},
      ...>   {2, 3, 0.5}
      ...> ])
      iex> {:ok, [p1, p2]} = Disjoint.suurballe(graph, 1, 4)
      iex> p1.nodes
      [1, 2, 4]
      iex> p2.nodes
      [1, 3, 4]

  """
  @spec suurballe(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt),
          (weight, weight -> weight),
          (any() -> weight)
        ) :: suurballe_result()
        when weight: var
  def suurballe(
        graph,
        from,
        to,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2,
        subtract \\ &Kernel.-/2,
        weight_fn \\ fn w -> if is_nil(w), do: 1, else: w end
      ) do
    # 1. Convert undirected graph to directed and resolve unweighted edge values
    dir_graph = to_directed(graph, weight_fn)

    # 2. Find the first shortest path
    case Dijkstra.shortest_path(dir_graph, from, to, zero, add, compare) do
      :error ->
        :error

      {:ok, path1} ->
        nodes1 = path1.nodes

        # Retrieve single-source distances to calculate reduced edge costs (vertex potentials)
        distances = Dijkstra.single_source_distances(dir_graph, from, zero, add, compare)

        # 3. Build G' (g_prime)
        p1_edges =
          nodes1
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [u, v] -> {u, v} end)
          |> MapSet.new()

        g_prime = Model.new(:directed)

        # Copy all nodes
        g_prime =
          Enum.reduce(Model.all_nodes(dir_graph), g_prime, fn node, acc ->
            Model.add_node(acc, node, Model.node(dir_graph, node))
          end)

        # Add edges with reduced costs: w' = w - d(s, v) + d(s, u)
        g_prime =
          Enum.reduce(Model.all_edges(dir_graph), g_prime, fn {u, v, weight}, acc ->
            if MapSet.member?(p1_edges, {u, v}) do
              acc
            else
              # weight is already computed by to_directed/2
              du = Map.get(distances, u)
              dv = Map.get(distances, v)

              if is_nil(du) or is_nil(dv) do
                acc
              else
                w_prime = add.(subtract.(weight, dv), du)
                Model.add_edge!(acc, u, v, w_prime)
              end
            end
          end)

        # Add reversed edges of P1 with weight 0
        g_prime =
          Enum.reduce(p1_edges, g_prime, fn {u, v}, acc ->
            # Remove original u -> v if any remained
            acc
            |> Model.remove_edge(u, v)
            |> Model.add_edge!(v, u, zero)
          end)

        # 4. Find the second shortest path P2 on G'
        case Dijkstra.shortest_path(g_prime, from, to, zero, add, compare) do
          :error ->
            :error

          {:ok, path2} ->
            nodes2 = path2.nodes

            # 5. Merge paths and cancel antiparallel/overlapping edges
            e1 = Enum.chunk_every(nodes1, 2, 1, :discard) |> Enum.map(fn [u, v] -> {u, v} end)
            e2 = Enum.chunk_every(nodes2, 2, 1, :discard) |> Enum.map(fn [u, v] -> {u, v} end)

            e1_set = MapSet.new(e1)
            e2_set = MapSet.new(e2)

            kept_edges =
              (e1 ++ e2)
              |> Enum.filter(fn {u, v} ->
                not (MapSet.member?(e1_set, {v, u}) or MapSet.member?(e2_set, {v, u}))
              end)

            {s_edges, other_edges} = Enum.split_with(kept_edges, fn {u, _v} -> u == from end)

            if length(s_edges) < 2 do
              :error
            else
              # Build a multimap so edges from shared intermediate nodes aren't lost
              adj =
                Enum.reduce(other_edges, %{}, fn {u, v}, acc ->
                  Map.update(acc, u, [v], fn vs -> [v | vs] end)
                end)

              case trace_all_paths(s_edges, from, to, adj) do
                :error ->
                  :error

                path_nodes_list ->
                  res_paths =
                    Enum.map(path_nodes_list, fn path_nodes ->
                      weight = path_weight(path_nodes, graph, weight_fn, zero, add)
                      Path.new(path_nodes, weight, :suurballe)
                    end)
                    |> Enum.sort_by(& &1.weight, fn w1, w2 -> compare.(w1, w2) != :gt end)

                  {:ok, res_paths}
              end
            end
        end
    end
  end

  # ============================================================
  # Internal Helpers
  # ============================================================

  defp to_directed(graph, weight_fn) do
    directed = Model.new(:directed)

    with_nodes =
      Enum.reduce(Model.all_nodes(graph), directed, fn node, acc ->
        Model.add_node(acc, node, Model.node(graph, node))
      end)

    Enum.reduce(Model.all_edges(graph), with_nodes, fn {u, v, weight}, acc ->
      w_val = weight_fn.(weight)

      if Model.type(graph) == :undirected do
        acc
        |> Model.add_edge!(u, v, w_val)
        |> Model.add_edge!(v, u, w_val)
      else
        acc
        |> Model.add_edge!(u, v, w_val)
      end
    end)
  end

  # Traces all paths sequentially, threading the adjacency multimap so that
  # edges consumed by one path aren't available to the next. This is critical
  # when two disjoint paths share an intermediate node.
  defp trace_all_paths(s_edges, from, to, adj) do
    result =
      Enum.reduce_while(s_edges, {[], adj}, fn {^from, next_node}, {paths, current_adj} ->
        case trace_path(next_node, to, current_adj, [from]) do
          {:ok, path_nodes, updated_adj} ->
            {:cont, {[path_nodes | paths], updated_adj}}

          :error ->
            {:halt, :error}
        end
      end)

    case result do
      :error -> :error
      {paths, _adj} -> Enum.reverse(paths)
    end
  end

  defp trace_path(curr, target, adj, path_acc) when curr == target do
    {:ok, Enum.reverse([target | path_acc]), adj}
  end

  defp trace_path(curr, target, adj, path_acc) do
    case Map.get(adj, curr) do
      nil ->
        :error

      [] ->
        :error

      [next_node | rest] ->
        updated_adj =
          case rest do
            [] -> Map.delete(adj, curr)
            _ -> Map.put(adj, curr, rest)
          end

        trace_path(next_node, target, updated_adj, [curr | path_acc])
    end
  end

  defp path_weight(nodes, graph, weight_fn, zero, add) do
    nodes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(zero, fn [u, v], acc ->
      w = Model.edge_data(graph, u, v) |> weight_fn.()
      add.(acc, w)
    end)
  end
end
