defmodule Yog.Pathfinding.Yen do
  @moduledoc """
  Yen's algorithm for finding the k shortest loopless paths between two nodes.

  This algorithm iteratively finds the next shortest path by exploring "spur"
  deviations from previously found paths. It is a natural extension of Dijkstra's
  algorithm for applications that require backup routes or alternative paths.

  **Time Complexity:** O(k · N · (E + V log V)) where N is the number of nodes
  in the shortest path.

  ## Algorithm

  1. Find the shortest path using Dijkstra.
  2. For each previously found path, consider every node as a "spur node".
  3. Temporarily remove the edge following the spur node and all earlier nodes
     in the path, then run Dijkstra from the spur node to the target.
  4. Combine the root path with the spur path to form a candidate.
  5. Select the lowest-weight candidate as the next shortest path.

  ## Example

      iex> graph = Yog.from_edges(:directed, [
      ...>     {1, 2, 1}, {1, 3, 2}, {2, 3, 1}, {2, 4, 3},
      ...>     {3, 4, 1}, {3, 5, 4}, {4, 5, 1}
      ...>   ])
      iex> {:ok, paths} = Yog.Pathfinding.Yen.k_shortest_paths(graph, 1, 5, 3)
      iex> length(paths)
      3
      iex> hd(paths).weight
      4

  ## References

  - Jin Y. Yen (1971). "Finding the k shortest loopless paths in a network"
  """

  alias Yog.Graph
  alias Yog.PairingHeap
  alias Yog.Pathfinding.Dijkstra
  alias Yog.Pathfinding.Path
  alias Yog.Transform

  @doc """
  Finds the k shortest loopless paths from `source` to `target`.

  ## Options

  - `:with` - Function to extract/transform edge weight before pathfinding
  - `:zero` - Identity value for the weight type (default: `0`)
  - `:add` - Function to add two weights (default: `&Kernel.+/2`)
  - `:compare` - Function comparing two weights returning `:lt`, `:eq`, or `:gt`
    (default: `&Yog.Utils.compare/2`)

  ## Returns

  - `{:ok, [Path.t()]}` — list of paths sorted by total weight, shortest first
  - `:error` — if no path exists at all
  """
  @spec k_shortest_paths(
          Graph.t(),
          Yog.node_id(),
          Yog.node_id(),
          pos_integer(),
          keyword()
        ) :: {:ok, [Path.t()]} | :error
  def k_shortest_paths(graph, source, target, k, opts \\ []) when k >= 1 do
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    weight_fn = opts[:with] || (&Function.identity/1)

    graph =
      if weight_fn != (&Function.identity/1),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    case Dijkstra.shortest_path(graph, source, target, zero, add, compare) do
      :error ->
        :error

      {:ok, first_path} ->
        paths = [first_path]
        seen_paths = MapSet.new([first_path.nodes])
        seen_candidates = MapSet.new()
        heap = PairingHeap.new(fn {w1, _}, {w2, _} -> compare.(w1, w2) != :gt end)

        {candidates, seen_candidates} =
          generate_candidates(
            graph,
            first_path,
            paths,
            seen_paths,
            seen_candidates,
            heap,
            target,
            zero,
            add,
            compare
          )

        do_k_iterations(
          graph,
          k - 1,
          paths,
          seen_paths,
          seen_candidates,
          candidates,
          target,
          zero,
          add,
          compare
        )
    end
  end

  # ---------------------------------------------------------------------------
  # Core iteration loop
  # ---------------------------------------------------------------------------

  defp do_k_iterations(
         _graph,
         0,
         paths,
         _seen_paths,
         _seen_candidates,
         _candidates,
         _target,
         _zero,
         _add,
         _compare
       ) do
    {:ok, Enum.reverse(paths)}
  end

  defp do_k_iterations(
         graph,
         remaining,
         paths,
         seen_paths,
         seen_candidates,
         candidates,
         target,
         zero,
         add,
         compare
       ) do
    case pop_valid_candidate(candidates, seen_paths) do
      :error ->
        {:ok, Enum.reverse(paths)}

      {:ok, {weight, nodes}, candidates} ->
        path = Path.new(nodes, weight, :yen)
        seen_paths = MapSet.put(seen_paths, nodes)
        paths = [path | paths]

        {candidates, seen_candidates} =
          generate_candidates(
            graph,
            path,
            paths,
            seen_paths,
            seen_candidates,
            candidates,
            target,
            zero,
            add,
            compare
          )

        do_k_iterations(
          graph,
          remaining - 1,
          paths,
          seen_paths,
          seen_candidates,
          candidates,
          target,
          zero,
          add,
          compare
        )
    end
  end

  # ---------------------------------------------------------------------------
  # Candidate generation
  # ---------------------------------------------------------------------------

  defp generate_candidates(
         graph,
         prev_path,
         paths,
         seen_paths,
         seen_candidates,
         candidates,
         target,
         zero,
         add,
         compare
       ) do
    prev_nodes = prev_path.nodes
    max_spur_index = length(prev_nodes) - 2

    if max_spur_index < 0 do
      {candidates, seen_candidates}
    else
      prefix_weights = build_prefix_weights(prev_nodes, graph, zero, add)

      Enum.reduce(
        0..max_spur_index,
        {candidates, seen_candidates},
        fn i, {cand_acc, cand_seen_acc} ->
          spur_node = Enum.at(prev_nodes, i)
          root_path = Enum.take(prev_nodes, i + 1)
          root_weight = Map.fetch!(prefix_weights, i)
          root_nodes = Enum.take(prev_nodes, i)

          edges_to_remove =
            Enum.reduce(paths, [], fn p, acc ->
              p_nodes = p.nodes

              if List.starts_with?(p_nodes, root_path) do
                next_node = Enum.at(p_nodes, i + 1)
                [{spur_node, next_node} | acc]
              else
                acc
              end
            end)

          modified_graph =
            graph
            |> remove_edges(edges_to_remove)
            |> remove_nodes(root_nodes)

          case Dijkstra.shortest_path(
                 modified_graph,
                 spur_node,
                 target,
                 zero,
                 add,
                 compare
               ) do
            :error ->
              {cand_acc, cand_seen_acc}

            {:ok, spur_path} ->
              total_nodes = root_path ++ tl(spur_path.nodes)
              total_weight = add.(root_weight, spur_path.weight)

              if MapSet.member?(seen_paths, total_nodes) or
                   MapSet.member?(cand_seen_acc, total_nodes) do
                {cand_acc, cand_seen_acc}
              else
                {
                  PairingHeap.push(cand_acc, {total_weight, total_nodes}),
                  MapSet.put(cand_seen_acc, total_nodes)
                }
              end
          end
        end
      )
    end
  end

  defp build_prefix_weights(nodes, graph, zero, add) do
    # Returns %{index => weight_from_source_to_node_at_index}
    # index 0 is the source node itself, so weight is zero
    do_prefix_weights(nodes, graph, zero, add, 0, %{0 => zero})
  end

  defp do_prefix_weights([_last], _graph, _zero, _add, _idx, acc), do: acc

  defp do_prefix_weights([u, v | rest], graph, zero, add, idx, acc) do
    w = get_edge_weight(graph, u, v)
    next_weight = add.(Map.fetch!(acc, idx), w)
    next_acc = Map.put(acc, idx + 1, next_weight)
    do_prefix_weights([v | rest], graph, zero, add, idx + 1, next_acc)
  end

  defp get_edge_weight(%Graph{out_edges: out_edges}, u, v) do
    case Map.fetch(out_edges, u) do
      {:ok, inner} -> Map.fetch!(inner, v)
      :error -> raise "Edge #{inspect(u)} -> #{inspect(v)} not found"
    end
  end

  # ---------------------------------------------------------------------------
  # Candidate heap helpers
  # ---------------------------------------------------------------------------

  defp pop_valid_candidate(heap, seen_paths) do
    case PairingHeap.pop(heap) do
      :error ->
        :error

      {:ok, {_weight, nodes} = candidate, new_heap} ->
        if MapSet.member?(seen_paths, nodes) do
          pop_valid_candidate(new_heap, seen_paths)
        else
          {:ok, candidate, new_heap}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Graph mutation helpers (operate on copies)
  # ---------------------------------------------------------------------------

  defp remove_edges(graph, edges) do
    Enum.reduce(edges, graph, fn {u, v}, g ->
      g = remove_directed_edge(g, u, v)
      if g.kind == :undirected, do: remove_directed_edge(g, v, u), else: g
    end)
  end

  defp remove_directed_edge(%Graph{} = g, u, v) do
    new_out =
      case Map.fetch(g.out_edges, u) do
        {:ok, inner} -> %{g.out_edges | u => Map.delete(inner, v)}
        :error -> g.out_edges
      end

    new_in =
      case Map.fetch(g.in_edges, v) do
        {:ok, inner} -> %{g.in_edges | v => Map.delete(inner, u)}
        :error -> g.in_edges
      end

    %Graph{g | out_edges: new_out, in_edges: new_in}
  end

  defp remove_nodes(graph, nodes) do
    Enum.reduce(nodes, graph, fn node, g -> remove_node(g, node) end)
  end

  defp remove_node(%Graph{} = g, node) do
    new_nodes = Map.delete(g.nodes, node)

    # Update out_edges: delete the node itself, and delete references to it
    # from other nodes' adjacency maps (using in_edges to find predecessors).
    new_out =
      g.out_edges
      |> Map.delete(node)
      |> then(fn out ->
        preds = Map.get(g.in_edges, node, %{})

        Enum.reduce(preds, out, fn {pred, _}, acc ->
          case Map.fetch(acc, pred) do
            {:ok, inner} -> %{acc | pred => Map.delete(inner, node)}
            :error -> acc
          end
        end)
      end)

    # Update in_edges: delete the node itself, and delete references to it
    # from other nodes' adjacency maps (using out_edges to find successors).
    new_in =
      g.in_edges
      |> Map.delete(node)
      |> then(fn inn ->
        succs = Map.get(g.out_edges, node, %{})

        Enum.reduce(succs, inn, fn {succ, _}, acc ->
          case Map.fetch(acc, succ) do
            {:ok, inner} -> %{acc | succ => Map.delete(inner, node)}
            :error -> acc
          end
        end)
      end)

    %Graph{g | nodes: new_nodes, out_edges: new_out, in_edges: new_in}
  end
end
