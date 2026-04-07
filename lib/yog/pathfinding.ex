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

  ## All-Pairs Functions

  - `all_pairs_shortest_paths_unweighted/1` — Parallel BFS for unweighted graphs
  - `floyd_warshall/1` — Floyd-Warshall for weighted graphs
  - `johnson/5` — Johnson's algorithm for sparse graphs with negative weights
  - `distance_matrix/6` — Distance matrix between specific points of interest

  ## Algorithm Selection Guide

  | Algorithm | Use When | Time Complexity |
  |-----------|----------|-----------------|
  | **Dijkstra** | Non-negative weights, single pair | O((V+E) log V) |
  | **A*** | Non-negative weights + good heuristic | O((V+E) log V) |
  | **Bellman-Ford** | Negative weights OR cycle detection | O(VE) |
  | **Bidirectional** | Large graphs, unweighted or uniform weights | O((V+E) log V) |
  | **All-Pairs Unweighted** | All-pairs, unweighted graphs (parallel) | O(V² + VE) |
  | **Floyd-Warshall** | All-pairs, dense weighted graphs | O(V³) |
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

  @doc """
  Computes all-pairs shortest paths in an unweighted graph using parallel BFS.

  Returns a map of `%{source => %{target => distance}}` where distances are the
  number of edges in the shortest path.

  ## Parameters

  - `graph` - The unweighted graph to analyze

  ## Returns

  - A map from source nodes to distance maps: `%{source => %{target => distance}}`
  - Each inner map contains distances from the source to all reachable nodes
  - Distance from a node to itself is always 0
  - Unreachable nodes have `nil` distance (note: this differs from `floyd_warshall/1`
    which omits unreachable pairs entirely)

  ## Complexity

  - **Time:** O(V × (V + E)) = O(V² + VE) overall, but parallelized across CPU cores
  - **Space:** O(V²) for the result matrix

  ## When to Use

  - **Unweighted graphs only** - For weighted graphs, use `floyd_warshall/1` or `johnson/1`
  - **All-pairs needed** - When you need distances between all node pairs
  - **Large graphs** - Parallelization makes this efficient on multi-core systems

  ## Algorithm

  1. For each node, run BFS to compute distances to all other nodes
  2. BFS from each source is parallelized using `Task.async_stream`
  3. Results are aggregated into a nested map structure

  ## Examples

      # Simple path graph: 1-2-3-4
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      iex> distances = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)
      iex> distances[1][4]
      3
      iex> distances[2][4]
      2
      iex> distances[1][1]
      0

      # Directed graph with unreachable nodes
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> distances = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)
      iex> distances[1][2]
      1
      iex> distances[3][1]
      nil

  ## See Also

  - `floyd_warshall/1` - For weighted graphs (all-pairs)
  - `johnson/5` - For sparse weighted graphs with negative weights
  - `distance_matrix/6` - For distances between specific points of interest only
  """
  @spec all_pairs_shortest_paths_unweighted(Yog.graph()) :: %{
          Yog.node_id() => %{Yog.node_id() => non_neg_integer()}
        }
  def all_pairs_shortest_paths_unweighted(graph) do
    nodes = Yog.Model.all_nodes(graph)

    parallel_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: :infinity,
      ordered: false
    ]

    nodes
    |> Task.async_stream(
      fn source ->
        {source, bfs_distances(graph, source)}
      end,
      parallel_opts
    )
    |> Enum.reduce(%{}, fn {:ok, {source, dist_map}}, acc ->
      Map.put(acc, source, dist_map)
    end)
  end

  # =============================================================================
  # Single-Pair Shortest Path (Unweighted) - BFS with early termination
  # =============================================================================

  @doc """
  Finds the shortest path between two nodes in an unweighted graph using BFS.

  This is significantly faster than Dijkstra for unweighted graphs because:
  1. Uses BFS instead of Dijkstra's algorithm (no heap overhead)
  2. Stops as soon as the target is found (early termination)
  3. Works for both directed and undirected graphs
  4. Handles nil weights or uniform weights (e.g., all weight=1)

  ## Parameters

    * `graph` - The unweighted graph (directed or undirected)
    * `source` - Starting node ID
    * `target` - Target node ID

  ## Returns

    * `{:ok, [node_id]}` - List of nodes representing the shortest path from source to target
    * `{:ok, [source]}` - When source == target
    * `{:error, :no_path}` - When target is unreachable from source

  ## Complexity

    * **Time:** O(V + E) worst case, but typically much less due to early termination
    * **Space:** O(V) for the queue and visited set

  ## Examples

      # Simple path: 1-2-3
      iex> graph = Yog.undirected()
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Pathfinding.shortest_path_unweighted(graph, 1, 3)
      {:ok, [1, 2, 3]}

      # Same source and target
      iex> graph = Yog.undirected()
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> Yog.Pathfinding.shortest_path_unweighted(graph, 1, 1)
      {:ok, [1]}

      # No path exists
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      iex> Yog.Pathfinding.shortest_path_unweighted(graph, :a, :b)
      {:error, :no_path}

      # Directed graph - respects edge direction
      iex> graph = Yog.directed()
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Pathfinding.shortest_path_unweighted(graph, 1, 3)
      {:ok, [1, 2, 3]}
      iex> Yog.Pathfinding.shortest_path_unweighted(graph, 3, 1)
      {:error, :no_path}

  ## When to Use

    * **Unweighted graphs** - All edges have the same cost (or nil weight)
    * **Single pair query** - When you only need one source-target path
    * **Performance critical** - Faster than Dijkstra for unweighted graphs

  ## See Also

    * `shortest_path/1` - Dijkstra for weighted graphs
    * `bidirectional_unweighted/1` - Bidirectional BFS (potentially faster for large graphs)
    * `all_pairs_shortest_paths_unweighted/1` - When you need all-pairs distances

  """
  @spec shortest_path_unweighted(Yog.graph(), Yog.node_id(), Yog.node_id()) ::
          {:ok, [Yog.node_id()]} | {:error, :no_path}
  def shortest_path_unweighted(graph, source, target) when source == target do
    if Yog.Model.has_node?(graph, source) do
      {:ok, [source]}
    else
      {:error, :no_path}
    end
  end

  def shortest_path_unweighted(graph, source, target) do
    cond do
      not Yog.Model.has_node?(graph, source) ->
        {:error, :no_path}

      not Yog.Model.has_node?(graph, target) ->
        {:error, :no_path}

      true ->
        q = :queue.in({source, 0}, :queue.new())
        visited = MapSet.new([source])
        predecessors = %{source => nil}

        case do_bfs_path_optimized(graph, q, visited, predecessors, target) do
          nil -> {:error, :no_path}
          preds -> {:ok, reconstruct_path(preds, target)}
        end
    end
  end

  # BFS with predecessor map - memory efficient
  defp do_bfs_path_optimized(graph, q, visited, predecessors, target) do
    case :queue.out(q) do
      {:empty, _} ->
        nil

      {{:value, {curr, _depth}}, rest_q} ->
        if curr == target do
          predecessors
        else
          neighbors =
            case Yog.Model.successors(graph, curr) do
              [] -> []
              succs -> Enum.map(succs, &elem(&1, 0))
            end

          {next_q, next_visited, next_preds, found} =
            Enum.reduce(neighbors, {rest_q, visited, predecessors, false}, fn nb,
                                                                              {q_acc, v_acc,
                                                                               p_acc, found_acc} ->
              cond do
                found_acc ->
                  {q_acc, v_acc, p_acc, found_acc}

                nb == target ->
                  next_q = :queue.in({nb, 0}, q_acc)
                  next_v = MapSet.put(v_acc, nb)
                  next_p = Map.put(p_acc, nb, curr)
                  {next_q, next_v, next_p, true}

                MapSet.member?(v_acc, nb) ->
                  {q_acc, v_acc, p_acc, found_acc}

                true ->
                  next_q = :queue.in({nb, 0}, q_acc)
                  next_v = MapSet.put(v_acc, nb)
                  next_p = Map.put(p_acc, nb, curr)
                  {next_q, next_v, next_p, found_acc}
              end
            end)

          if found do
            next_preds
          else
            do_bfs_path_optimized(graph, next_q, next_visited, next_preds, target)
          end
        end
    end
  end

  # Reconstruct path from target back to source using predecessor map
  defp reconstruct_path(predecessors, target) do
    do_reconstruct_path(predecessors, target, [])
  end

  defp do_reconstruct_path(predecessors, node, acc) do
    case Map.get(predecessors, node) do
      nil -> [node | acc]
      parent -> do_reconstruct_path(predecessors, parent, [node | acc])
    end
  end

  # Standard BFS to find all distances from a single source: O(V + E)
  defp bfs_distances(graph, source) do
    case Yog.Model.successors(graph, source) do
      [] ->
        %{source => 0}

      _ ->
        q = :queue.in({source, 0}, :queue.new())
        do_bfs_dist(graph, q, %{source => 0})
    end
  end

  defp do_bfs_dist(graph, q, visited) do
    case :queue.out(q) do
      {:empty, _} ->
        visited

      {{:value, {curr, dist}}, rest_q} ->
        neighbors = Yog.Model.successors(graph, curr) |> Enum.map(&elem(&1, 0))

        {next_q, next_v} =
          Enum.reduce(neighbors, {rest_q, visited}, fn nb, {q_acc, v_acc} ->
            if Map.has_key?(v_acc, nb) do
              {q_acc, v_acc}
            else
              {:queue.in({nb, dist + 1}, q_acc), Map.put(v_acc, nb, dist + 1)}
            end
          end)

        do_bfs_dist(graph, next_q, next_v)
    end
  end
end
