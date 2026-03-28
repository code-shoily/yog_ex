defmodule Yog.Property.Structure do
  @moduledoc """
  Structural properties of graphs.

  This module provides checks for various graph classes and regularities.

  ## Algorithms

  | Problem | Function | Complexity |
  |---------|----------|------------|
  | Tree check | `tree?/1` | O(V + E) |
  | Arborescence check | `arborescence?/1` | O(V + E) |
  | Complete graph check | `complete?/1` | O(V) |
  | Regular graph check | `regular?/2` | O(V) |
  | Connected check | `connected?/1` | O(V + E) |
  | Strongly connected check | `strongly_connected?/1` | O(V + E) |
  | Weakly connected check | `weakly_connected?/1` | O(V + E) |
  | Planar check | `planar?/1` | O(V + E) |
  | Chordal check | `chordal?/1` | O(V + E) |
  | Connected check | `connected?/1` | O(V + E) |
  | Strongly connected check | `strongly_connected?/1` | O(V + E) |
  | Weakly connected check | `weakly_connected?/1` | O(V + E) |

  ## Key Concepts

  - **Tree**: Connected acyclic undirected graph.
  - **Arborescence**: Directed tree with a unique root.
  - **Complete Graph (Kn)**: Every pair of distinct vertices is connected by an edge.
  - **Regular Graph**: Every vertex has the same degree k.

  ## Examples

      # Simple tree
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(1, 2, 1)
      iex> Yog.Property.Structure.tree?(graph)
      true

      # Complete graph K3 (triangle)
      iex> graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(1, 2, 1) |> Yog.add_edge_ensure(2, 3, 1) |> Yog.add_edge_ensure(3, 1, 1)
      iex> Yog.Property.Structure.complete?(graph)
      true
  """

  alias Yog.Model
  alias Yog.Property.Bipartite

  @doc """
  Checks if the graph is a tree (connected and acyclic).
  Works for undirected graphs.

  ## Time Complexity
  O(V + E)
  """
  @spec tree?(Yog.graph()) :: boolean()
  def tree?(graph) do
    case graph.kind do
      :undirected ->
        n = Model.node_count(graph)
        e = Model.edge_count(graph)
        n > 0 and e == n - 1 and connected?(graph)

      :directed ->
        false
    end
  end

  @doc """
  Checks if the graph is an arborescence (directed tree with a single root).
  """
  @spec arborescence?(Yog.graph()) :: boolean()
  def arborescence?(graph) do
    case graph.kind do
      :directed ->
        n = Model.node_count(graph)

        if n > 0 and Model.edge_count(graph) == n - 1 do
          nodes = Model.all_nodes(graph)

          in_edges = graph.in_edges

          in_degrees =
            for node <- nodes, reduce: %{} do
              acc -> Map.put(acc, node, map_size(Map.get(in_edges, node, %{})))
            end

          roots = Enum.filter(nodes, fn node -> Map.get(in_degrees, node) == 0 end)

          case roots do
            [root] ->
              Enum.all?(nodes, fn node -> node == root or Map.get(in_degrees, node) == 1 end) and
                reachable_count(graph, root) == n

            _ ->
              false
          end
        else
          false
        end

      _ ->
        false
    end
  end

  @doc """
  Finds the root of an arborescence.
  """
  @spec arborescence_root(Yog.graph()) :: Yog.node_id() | nil
  def arborescence_root(graph) do
    if arborescence?(graph) do
      nodes = Model.all_nodes(graph)
      Enum.find(nodes, fn node -> Enum.empty?(Model.predecessors(graph, node)) end)
    else
      nil
    end
  end

  @doc """
  Checks if the graph is complete (every pair of distinct nodes is connected).
  """
  @spec complete?(Yog.graph()) :: boolean()
  def complete?(graph) do
    n = Model.node_count(graph)

    if n <= 1 do
      true
    else
      e = Model.edge_count(graph)

      expected_e =
        case graph.kind do
          :undirected -> div(n * (n - 1), 2)
          :directed -> n * (n - 1)
        end

      e == expected_e and no_self_loops?(graph)
    end
  end

  @doc """
  Checks if the graph is k-regular (every node has degree exactly k).
  """
  @spec regular?(Yog.graph(), integer()) :: boolean()
  def regular?(graph, k) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      true
    else
      case graph.kind do
        :undirected ->
          Enum.all?(nodes, fn u -> length(Model.neighbor_ids(graph, u)) == k end)

        :directed ->
          Enum.all?(nodes, fn u ->
            length(Model.successors(graph, u)) == k and
              length(Model.predecessors(graph, u)) == k
          end)
      end
    end
  end

  @doc """
  Checks if the graph is connected.

  For undirected graphs, every node is reachable from every other node.
  For directed graphs, this checks for strong connectivity.
  """
  @spec connected?(Yog.graph()) :: boolean()
  def connected?(graph) do
    case graph.kind do
      :undirected ->
        case Model.all_nodes(graph) do
          [] -> true
          [start | _] -> reachable_count(graph, start) == Model.node_count(graph)
        end

      :directed ->
        strongly_connected?(graph)
    end
  end

  @doc """
  Checks if a directed graph is strongly connected.
  """
  @spec strongly_connected?(Yog.graph()) :: boolean()
  def strongly_connected?(graph) do
    case graph.kind do
      :undirected ->
        connected?(graph)

      :directed ->
        nodes = Model.all_nodes(graph)

        case nodes do
          [] ->
            true

          [start | _] ->
            if reachable_count(graph, start) == length(nodes) do
              Yog.Transform.transpose(graph) |> reachable_count(start) == length(nodes)
            else
              false
            end
        end
    end
  end

  @doc """
  Checks if a directed graph is weakly connected.
  """
  @spec weakly_connected?(Yog.graph()) :: boolean()
  def weakly_connected?(graph) do
    case graph.kind do
      :undirected ->
        connected?(graph)

      :directed ->
        # Use a simple resolver for undirected conversion as connectivity ignores weights.
        Yog.Transform.to_undirected(graph, fn w, _ -> w end) |> connected?()
    end
  end

  @doc """
  Checks if the graph is planar (necessary conditions only).

  Implements necessary checks: $|E| \le 3|V| - 6$ and bipartite $|E| \le 2|V| - 4$.
  """
  @spec planar?(Yog.graph()) :: boolean()
  def planar?(graph) do
    n = Model.node_count(graph)
    e = Model.edge_count(graph)

    if n <= 4 do
      true
    else
      if e > 3 * n - 6 do
        false
      else
        if Bipartite.bipartite?(graph) and e > 2 * n - 4 do
          false
        else
          true
        end
      end
    end
  end

  @doc """
  Checks if the graph is chordal using Maximum Cardinality Search.
  """
  @spec chordal?(Yog.graph()) :: boolean()
  def chordal?(graph) do
    case graph.kind do
      :undirected ->
        case mcs_ordering(graph) do
          nil -> false
          order -> peo?(graph, order)
        end

      :directed ->
        false
    end
  end

  # Helpers
  defp mcs_ordering(graph) do
    nodes = Model.all_nodes(graph)
    weights = Map.new(nodes, fn id -> {id, 0} end)
    do_mcs(graph, weights, [], MapSet.new(nodes))
  end

  defp do_mcs(_graph, _weights, order, remaining) when remaining == %MapSet{} do
    Enum.reverse(order)
  end

  defp do_mcs(graph, weights, order, remaining) do
    v = Enum.max_by(remaining, fn node -> Map.get(weights, node) end)

    neighbors = Model.neighbor_ids(graph, v)

    new_weights =
      Enum.reduce(neighbors, weights, fn u, acc ->
        if MapSet.member?(remaining, u) do
          Map.update!(acc, u, &(&1 + 1))
        else
          acc
        end
      end)

    do_mcs(graph, new_weights, [v | order], MapSet.delete(remaining, v))
  end

  defp peo?(graph, order) do
    pos_map = order |> Enum.with_index() |> Map.new()

    Enum.all?(order, fn v ->
      earlier_neighbors =
        Model.neighbor_ids(graph, v)
        |> Enum.filter(fn u -> Map.get(pos_map, u) < Map.get(pos_map, v) end)

      clique?(graph, earlier_neighbors)
    end)
  end

  defp clique?(graph, nodes) do
    combinations(nodes, 2)
    |> Enum.all?(fn pair ->
      case pair do
        [u, v] -> Model.has_edge?(graph, u, v)
        _ -> true
      end
    end)
  end

  defp combinations([], _), do: [[]]
  defp combinations(_, 0), do: [[]]
  defp combinations(list, n) when length(list) == n, do: [list]

  defp combinations([head | tail], n) do
    for(subset <- combinations(tail, n - 1), do: [head | subset]) ++ combinations(tail, n)
  end

  defp reachable_count(graph, start) do
    Yog.walk(graph, start, :breadth_first) |> length()
  end

  defp no_self_loops?(graph) do
    Enum.all?(Model.all_nodes(graph), fn u -> not Model.has_edge?(graph, u, u) end)
  end
end
