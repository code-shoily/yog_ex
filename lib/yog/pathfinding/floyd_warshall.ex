defmodule Yog.Pathfinding.FloydWarshall do
  @moduledoc """
  [Floyd-Warshall algorithm](https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm)
  for all-pairs shortest paths in weighted graphs.

  The Floyd-Warshall algorithm finds the shortest paths between all pairs of nodes
  in a single execution. It uses dynamic programming to iteratively improve shortest
  path estimates by considering each node as a potential intermediate vertex.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Floyd-Warshall](https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm) | `floyd_warshall/4` | O(V³) | Dense graphs, all-pairs paths |

  ## Key Concepts

  - **Dynamic Programming**: Builds solution from smaller subproblems
  - **K-Intermediate Nodes**: After k iterations, paths use only nodes {1,...,k} as intermediates
  - **Path Reconstruction**: Predecessor matrix allows full path recovery
  - **Transitive Closure**: Can be adapted for reachability (boolean weights)

  ## The DP Recurrence

  ```
  dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
  ```

  For each intermediate node k, check if going through k improves the path from i to j.

  ## Comparison with Running Dijkstra V Times

  | Approach | Complexity | Best For |
  |----------|------------|----------|
  | Floyd-Warshall | O(V³) | Dense graphs (E ≈ V²) |
  | V × Dijkstra | O(V(V+E) log V) | Sparse graphs |
  | Johnson's | O(V² log V + VE) | Sparse graphs with negative weights |

  **Rule of thumb**: Use Floyd-Warshall when E > V × log V (fairly dense)

  ## Negative Cycles

  The algorithm can detect negative cycles: after completion, if any node has
  dist[node][node] < 0, a negative cycle exists.

  ## Variants

  - **Transitive Closure**: Use boolean OR instead of min-plus (Warshall's algorithm)
  - **Successor Matrix**: Track next hop for path reconstruction

  ## Use Cases

  - **All-pairs routing**: Precompute distances for fast lookup
  - **Transitive closure**: Reachability queries in databases
  - **Centrality metrics**: Closeness and betweenness calculations
  - **Graph analysis**: Detecting negative cycles

  ## History

  Published independently by Robert Floyd (1962), Stephen Warshall (1962),
  and Bernard Roy (1959). Floyd's version included path reconstruction.

  ## References

  - [Wikipedia: Floyd-Warshall Algorithm](https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm)
  - [CP-Algorithms: Floyd-Warshall](https://cp-algorithms.com/graph/all-pair-shortest-path-floyd-warshall.html)
  """

  @typedoc """
  Distance matrix: map from `{from, to}` tuple to distance.
  """
  @type distance_matrix :: %{{Yog.node_id(), Yog.node_id()} => any()}

  @doc """
  Computes shortest paths between all pairs of nodes using Floyd-Warshall.

  **Time Complexity:** O(V³)

  Returns `{:ok, distance_matrix}` on success, or `{:error, :negative_cycle}`
  if a negative cycle is detected.

  ## Parameters

  - `graph` - The graph to analyze
  - `zero` - Identity element for addition
  - `add` - Function to add two weights
  - `compare` - Function to compare two weights

  ## Examples

      # Triangle graph with all-pairs distances
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 3, with: 10)
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, distances} = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph, 0, &(&1 + &2), compare)
      iex> # Shortest path from 1 to 3 should be 1->2->3 = 5, not direct 10
      ...> distances[{1, 3}]
      5

      # Negative cycle detection
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 1, with: -3)
      iex> compare = &Yog.Utils.compare/2
      iex> Yog.Pathfinding.FloydWarshall.floyd_warshall(bad_graph, 0, &(&1 + &2), compare)
      {:error, :negative_cycle}
  """
  @spec floyd_warshall(
          Yog.graph(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: {:ok, distance_matrix()} | {:error, :negative_cycle}
  def floyd_warshall(graph, zero \\ 0, add \\ &Kernel.+/2, compare \\ &Yog.Utils.compare/2) do
    nodes = Map.keys(graph.nodes)

    initial_dist = initialize_distances(nodes, graph, zero, compare)

    final_dist =
      List.foldl(nodes, initial_dist, fn k, acc_dist ->
        List.foldl(nodes, acc_dist, fn i, acc_dist_i ->
          List.foldl(nodes, acc_dist_i, fn j, acc_dist_j ->
            relax_via_intermediate(i, j, k, acc_dist_j, add, compare)
          end)
        end)
      end)

    if has_negative_cycle?(nodes, final_dist, compare, zero) do
      {:error, :negative_cycle}
    else
      {:ok, final_dist}
    end
  end

  @doc """
  Detects whether the graph contains a negative cycle.

  More efficient than running the full algorithm - returns early as soon as
  a negative cycle is detected during the k iterations.
  """
  @spec detect_negative_cycle?(
          Yog.graph(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: boolean()
  def detect_negative_cycle?(
        graph,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    nodes = Map.keys(graph.nodes)
    initial_dist = initialize_distances(nodes, graph, zero, compare)

    result =
      Enum.reduce_while(nodes, initial_dist, fn k, acc_dist ->
        new_dist =
          List.foldl(nodes, acc_dist, fn i, acc_dist_i ->
            List.foldl(nodes, acc_dist_i, fn j, acc_dist_j ->
              relax_via_intermediate(i, j, k, acc_dist_j, add, compare)
            end)
          end)

        has_negative =
          Enum.any?(nodes, fn i ->
            case Map.fetch(new_dist, {i, i}) do
              {:ok, d} -> compare_weights(d, zero, compare) == :lt
              :error -> false
            end
          end)

        if has_negative do
          {:halt, :negative_cycle}
        else
          {:cont, new_dist}
        end
      end)

    result == :negative_cycle
  end

  # ============================================================
  # Helper functions
  # ============================================================

  # Initialize distance matrix with direct edge weights
  defp initialize_distances(nodes, graph, zero, compare) do
    out_edges = graph.out_edges

    initial =
      List.foldl(nodes, %{}, fn i, acc ->
        Map.put(acc, {i, i}, zero)
      end)

    List.foldl(nodes, initial, fn i, acc ->
      successors =
        case Map.fetch(out_edges, i) do
          {:ok, edges} -> Map.to_list(edges)
          :error -> []
        end

      List.foldl(successors, acc, fn {j, weight}, acc_inner ->
        case Map.fetch(acc_inner, {i, j}) do
          {:ok, existing} ->
            if compare_weights(weight, existing, compare) == :lt do
              Map.put(acc_inner, {i, j}, weight)
            else
              acc_inner
            end

          :error ->
            Map.put(acc_inner, {i, j}, weight)
        end
      end)
    end)
  end

  # Try to relax distance from i to j via intermediate k
  defp relax_via_intermediate(i, j, k, dist, add, compare) do
    with {:ok, dist_ik} <- Map.fetch(dist, {i, k}),
         {:ok, dist_kj} <- Map.fetch(dist, {k, j}) do
      new_dist = add.(dist_ik, dist_kj)

      case Map.fetch(dist, {i, j}) do
        {:ok, current} ->
          if compare_weights(new_dist, current, compare) == :lt do
            Map.put(dist, {i, j}, new_dist)
          else
            dist
          end

        :error ->
          Map.put(dist, {i, j}, new_dist)
      end
    else
      :error -> dist
    end
  end

  # Check if any node has negative distance to itself
  defp has_negative_cycle?(nodes, dist, compare, zero) do
    Enum.any?(nodes, fn i ->
      case Map.fetch(dist, {i, i}) do
        {:ok, d} -> compare_weights(d, zero, compare) == :lt
        :error -> false
      end
    end)
  end

  # Compare two weights using the comparison function
  defp compare_weights(a, b, compare) do
    compare.(a, b)
  end
end
