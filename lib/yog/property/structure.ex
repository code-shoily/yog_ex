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
      ...> |> Yog.add_edge!(1, 2, 1)
      iex> Yog.Property.Structure.tree?(graph)
      true

      # Complete graph K3 (triangle)
      iex> graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(1, 2, 1) |> Yog.add_edge!(2, 3, 1) |> Yog.add_edge!(3, 1, 1)
      iex> Yog.Property.Structure.complete?(graph)
      true
  """

  alias Yog.Model

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

  # Helpers
  defp connected?(graph) do
    case Model.all_nodes(graph) do
      [] ->
        true

      nodes ->
        [start | _] = nodes
        reachable_count(graph, start) == length(nodes)
    end
  end

  defp reachable_count(graph, start) do
    Yog.walk(graph, start, :breadth_first) |> length()
  end

  defp no_self_loops?(graph) do
    Enum.all?(Model.all_nodes(graph), fn u -> not Model.has_edge?(graph, u, u) end)
  end
end
