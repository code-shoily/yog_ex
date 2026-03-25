defmodule Yog.Pathfinding do
  @moduledoc """
  Unified facade for pathfinding algorithms.

  This module provides a single entry point for all pathfinding and distance
  computation algorithms. Each function delegates to a specialized submodule.

  ## Submodules

  - `Yog.Pathfinding.Dijkstra` — Single-source shortest paths (non-negative weights)
  - `Yog.Pathfinding.AStar` — Heuristic-guided shortest paths
  - `Yog.Pathfinding.BellmanFord` — Shortest paths with negative weights, cycle detection
  - `Yog.Pathfinding.Bidirectional` — Bidirectional BFS/Dijkstra for faster convergence
  - `Yog.Pathfinding.FloydWarshall` — All-pairs shortest paths (dense graphs)
  - `Yog.Pathfinding.Johnson` — All-pairs shortest paths (sparse graphs, negative weights)
  - `Yog.Pathfinding.Matrix` — Distance matrix computation
  - `Yog.Pathfinding.Path` — Path struct for representing results

  ## Algorithm Selection Guide

  | Algorithm | Use When | Time Complexity |
  |-----------|----------|-----------------|
  | **Dijkstra** | Non-negative weights, single pair | O((V+E) log V) |
  | **A*** | Non-negative weights + good heuristic | O((V+E) log V) |
  | **Bellman-Ford** | Negative weights OR cycle detection | O(VE) |
  | **Bidirectional** | Large graphs, unweighted or uniform weights | O((V+E) log V) |
  | **Floyd-Warshall** | All-pairs, dense graphs | O(V³) |
  | **Johnson's** | All-pairs, sparse graphs, negative weights | O(V² log V + VE) |
  """

  alias Yog.Pathfinding.AStar
  alias Yog.Pathfinding.BellmanFord
  alias Yog.Pathfinding.Bidirectional
  alias Yog.Pathfinding.Dijkstra
  alias Yog.Pathfinding.FloydWarshall
  alias Yog.Pathfinding.Johnson
  alias Yog.Pathfinding.Matrix

  # =============================================================================
  # Dijkstra
  # =============================================================================

  @doc """
  Finds the shortest path between two nodes using Dijkstra's algorithm.

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Zero value for weights (default: 0)
    * `:add` - Addition function for weights (default: &Kernel.+/2)
    * `:compare` - Comparison function for weights (:lt, :eq, :gt) (default: &Yog.Utils.compare/2)

  ## Example

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])
      iex> {:ok, path} = Yog.Pathfinding.shortest_path(
      ...>   in: graph, from: 1, to: 3
      ...> )
      iex> path.weight
      8
  """
  defdelegate shortest_path(opts), to: Dijkstra

  @doc """
  Single-source distances from a node to all reachable nodes (Dijkstra).

  ## Options
    * `:in` - The graph
    * `:from` - Source node
    * `:zero` - Zero value (default: 0)
    * `:add` - Addition function (default: &Kernel.+/2)
    * `:compare` - Comparison function (default: &Yog.Utils.compare/2)
  """
  defdelegate single_source_distances(opts), to: Dijkstra

  # =============================================================================
  # A*
  # =============================================================================

  @doc """
  Finds the shortest path using A* search with a heuristic.

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Zero value for weights (default: 0)
    * `:add` - Addition function for weights (default: &Kernel.+/2)
    * `:compare` - Comparison function for weights (default: &Yog.Utils.compare/2)
    * `:heuristic` - Heuristic function `(node, goal) -> weight` (Mandatory)
  """
  defdelegate a_star(opts), to: AStar

  @doc """
  Alias for `a_star/1`.
  """
  def astar(opts), do: a_star(opts)

  # =============================================================================
  # Bellman-Ford
  # =============================================================================

  @doc """
  Finds the shortest path using Bellman-Ford (supports negative weights).

  Returns `{:error, :negative_cycle}` if a negative cycle is reachable.

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Identity value for weights (default: 0)
    * `:add` - Addition function (default: &Kernel.+/2)
    * `:compare` - Comparison function (default: &Yog.Utils.compare/2)
  """
  defdelegate bellman_ford(opts), to: BellmanFord

  # =============================================================================
  # Bidirectional
  # =============================================================================

  @doc """
  Finds the shortest path using bidirectional BFS (unweighted graphs).

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
  """
  defdelegate bidirectional_unweighted(opts), to: Bidirectional, as: :shortest_path_unweighted

  @doc """
  Finds the shortest path using bidirectional Dijkstra.

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Zero value for weights (default: 0)
    * `:add` - Addition function (default: &Kernel.+/2)
    * `:compare` - Comparison function (default: &Yog.Utils.compare/2)

  ## Example

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])
      iex> {:ok, path} = Yog.Pathfinding.bidirectional(
      ...>   in: graph, from: 1, to: 3
      ...> )
      iex> path.weight
      8
  """
  defdelegate bidirectional(opts), to: Bidirectional, as: :shortest_path

  # =============================================================================
  # Floyd-Warshall
  # =============================================================================

  @doc """
  Computes all-pairs shortest paths using Floyd-Warshall.

  ## Options
    * `:in` - The graph
    * `:zero` - Identity element (default: 0)
    * `:add` - Addition function (default: &Kernel.+/2)
    * `:compare` - Comparison function (default: &Yog.Utils.compare/2)
  """
  def floyd_warshall(opts) do
    graph = Keyword.fetch!(opts, :in)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    FloydWarshall.floyd_warshall(graph, zero, add, compare)
  end

  @doc """
  Detects negative cycles in the graph via Floyd-Warshall.
  """
  defdelegate detect_negative_cycle?(graph, zero, add, compare), to: FloydWarshall

  # =============================================================================
  # Johnson's
  # =============================================================================

  @doc """
  Computes all-pairs shortest paths using Johnson's algorithm.

  More efficient than Floyd-Warshall for sparse graphs. Supports negative
  edge weights (but not negative cycles).
  """
  def johnson(
        graph,
        zero \\ 0,
        add \\ &Kernel.+/2,
        subtract \\ &Kernel.-/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    Johnson.johnson(graph, zero, add, subtract, compare)
  end

  # =============================================================================
  # Distance Matrix
  # =============================================================================

  @doc """
  Computes a distance matrix between specified points of interest.

  Uses Dijkstra from each point to compute pairwise distances.
  """
  def distance_matrix(
        graph,
        points,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2,
        subtract \\ nil
      ) do
    Matrix.distance_matrix(graph, points, zero, add, compare, subtract)
  end
end
