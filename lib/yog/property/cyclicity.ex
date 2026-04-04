defmodule Yog.Property.Cyclicity do
  @moduledoc """
  Graph [cyclicity](https://en.wikipedia.org/wiki/Cycle_(graph_theory)) and
  [Directed Acyclic Graph (DAG)](https://en.wikipedia.org/wiki/Directed_acyclic_graph) analysis.

  This module provides efficient algorithms for detecting cycles in graphs,
  which is fundamental for topological sorting, deadlock detection, and
  validating graph properties.

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Cycle detection (directed) | [Kahn's algorithm](https://en.wikipedia.org/wiki/Topological_sorting#Kahn's_algorithm) | `acyclic?/1`, `cyclic?/1` | O(V + E) |
  | Cycle detection (undirected) | [Union-Find / DFS](https://en.wikipedia.org/wiki/Cycle_detection) | `acyclic?/1`, `cyclic?/1` | O(V + E) |

  ## Key Concepts

  - **Cycle**: Path that starts and ends at the same vertex
  - **Simple Cycle**: No repeated vertices (except start/end)
  - **Acyclic Graph**: Graph with no cycles
  - **DAG**: Directed Acyclic Graph - directed graph with no directed cycles
  - **Self-Loop**: Edge from a vertex to itself

  ## Cycle Detection Methods

  **Directed Graphs (Kahn's Algorithm)**:
  - Repeatedly remove vertices with no incoming edges
  - If all vertices removed → acyclic
  - If stuck with remaining vertices → cycle exists

  **Undirected Graphs**:
  - Track visited nodes during DFS
  - If we revisit a node (that's not the immediate parent) → cycle exists
  - Self-loops also count as cycles

  ## Applications of Cycle Detection

  - **Dependency resolution**: Detect circular dependencies in package managers
  - **Deadlock detection**: Resource allocation graphs in operating systems
  - **Schema validation**: Ensure no circular references in data models
  - **Build systems**: Detect circular dependencies in Makefiles
  - **Course prerequisites**: Validate prerequisite chains aren't circular

  ## Relationship to Other Properties

  - **Tree**: Connected acyclic graph
  - **Forest**: Disjoint union of trees (acyclic)
  - **Topological sort**: Only possible on DAGs (acyclic directed graphs)
  - **Eulerian paths**: Require specific degree conditions related to cycles

  ## Examples

      # DAG is acyclic
      iex> dag = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Property.Cyclicity.acyclic?(dag)
      true
      iex> Yog.Property.Cyclicity.cyclic?(dag)
      false

      # Triangle is cyclic
      iex> triangle = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Property.Cyclicity.cyclic?(triangle)
      true

  ## References

  - [Wikipedia: Cycle Detection](https://en.wikipedia.org/wiki/Cycle_detection)
  - [Wikipedia: Directed Acyclic Graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph)
  - [Wikipedia: Kahn's Algorithm](https://en.wikipedia.org/wiki/Topological_sorting#Kahn's_algorithm)
  - [CP-Algorithms: Finding Cycles](https://cp-algorithms.com/graph/finding-cycle.html)
  """

  alias Yog.Model
  alias Yog.Traversal.Sort

  @doc """
  Checks if the graph is a Directed Acyclic Graph (DAG) or has no cycles if undirected.

  For directed graphs, a cycle exists if there is a path from a node back to itself.
  For undirected graphs, a cycle exists if there is a path of length >= 3 from a node back to itself,
  or a self-loop.

  ## Examples

      # Empty graph is acyclic
      iex> Yog.Property.Cyclicity.acyclic?(Yog.directed())
      true

      # Single node is acyclic
      iex> graph = Yog.directed() |> Yog.add_node(1, "A")
      iex> Yog.Property.Cyclicity.acyclic?(graph)
      true

      # DAG is acyclic
      iex> dag = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Property.Cyclicity.acyclic?(dag)
      true

      # Self-loop creates a cycle
      iex> cyclic = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_edge_ensure(from: 1, to: 1, with: 1)
      iex> Yog.Property.Cyclicity.acyclic?(cyclic)
      false

      # Triangle is cyclic
      iex> triangle = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Property.Cyclicity.acyclic?(triangle)
      false

  ## Time Complexity

  O(V + E)
  """
  @spec acyclic?(Yog.graph()) :: boolean()
  def acyclic?(graph) do
    not cyclic?(graph)
  end

  @doc """
  Checks if the graph contains at least one cycle.

  Logical opposite of `acyclic?/1`.

  ## Examples

      # Empty graph is not cyclic
      iex> Yog.Property.Cyclicity.cyclic?(Yog.directed())
      false

      # Simple cycle
      iex> cycle = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Property.Cyclicity.cyclic?(cycle)
      true

  ## Time Complexity

  O(V + E)
  """
  @spec cyclic?(Yog.graph()) :: boolean()
  def cyclic?(graph) do
    case graph.kind do
      :directed ->
        case Sort.topological_sort(graph) do
          {:error, :contains_cycle} -> true
          _ -> false
        end

      :undirected ->
        has_undirected_cycle?(graph)
    end
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  defp has_undirected_cycle?(graph) do
    nodes = Model.all_nodes(graph)

    # Manual DFS to detect back-edges while ignoring the immediate parent
    {has_cycle?, _visited} =
      Enum.reduce_while(nodes, {false, MapSet.new()}, fn node, {_, visited} ->
        if MapSet.member?(visited, node) do
          {:cont, {false, visited}}
        else
          case dfs_check_cycle(graph, node, nil, visited) do
            {true, new_visited} -> {:halt, {true, new_visited}}
            {false, new_visited} -> {:cont, {false, new_visited}}
          end
        end
      end)

    has_cycle?
  end

  defp dfs_check_cycle(graph, u, parent, visited) do
    visited = MapSet.put(visited, u)
    neighbors = Model.neighbor_ids(graph, u)

    Enum.reduce_while(neighbors, {false, visited}, fn v, {_, current_visited} ->
      cond do
        v == parent ->
          {:cont, {false, current_visited}}

        MapSet.member?(current_visited, v) ->
          {:halt, {true, current_visited}}

        true ->
          case dfs_check_cycle(graph, v, u, current_visited) do
            {true, next_visited} -> {:halt, {true, next_visited}}
            {false, next_visited} -> {:cont, {false, next_visited}}
          end
      end
    end)
  end
end
