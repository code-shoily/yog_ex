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

  alias Yog.Model

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 3, with: 10)
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, distances} = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph, 0, &(&1 + &2), compare)
      iex> # Shortest path from 1 to 3 should be 1->2->3 = 5, not direct 10
      ...> distances[{1, 3}]
      5

      # Negative cycle detection
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 1, with: -3)
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
  def floyd_warshall(graph, zero, add, compare) do
    nodes = Model.all_nodes(graph)

    # Initialize distance matrix
    initial_dist = initialize_distances(nodes, graph, zero)

    # Floyd-Warshall main algorithm
    final_dist =
      Enum.reduce(nodes, initial_dist, fn k, acc_dist ->
        Enum.reduce(nodes, acc_dist, fn i, acc_dist_i ->
          Enum.reduce(nodes, acc_dist_i, fn j, acc_dist_j ->
            relax_via_intermediate(i, j, k, acc_dist_j, add, compare)
          end)
        end)
      end)

    # Check for negative cycles
    if has_negative_cycle?(nodes, final_dist, compare) do
      {:error, :negative_cycle}
    else
      {:ok, final_dist}
    end
  end

  @doc """
  Convenience function for integer weights.
  """
  @spec floyd_warshall_int(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => integer()}}
          | {:error, :negative_cycle}
  def floyd_warshall_int(graph) do
    floyd_warshall(graph, 0, &(&1 + &2), &Yog.Utils.compare/2)
  end

  @doc """
  Convenience function for float weights.
  """
  @spec floyd_warshall_float(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => float()}}
          | {:error, :negative_cycle}
  def floyd_warshall_float(graph) do
    floyd_warshall(graph, 0.0, &(&1 + &2), &Yog.Utils.compare/2)
  end

  @doc """
  Detects whether the graph contains a negative cycle.

  More efficient than running the full algorithm if you only need cycle detection.
  """
  @spec detect_negative_cycle?(
          Yog.graph(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: boolean()
  def detect_negative_cycle?(graph, zero, add, compare) do
    case floyd_warshall(graph, zero, add, compare) do
      {:error, :negative_cycle} -> true
      {:ok, _} -> false
    end
  end

  # Initialize distance matrix with direct edge weights
  defp initialize_distances(nodes, graph, zero) do
    # Start with diagonal (self-distances = zero)
    initial =
      Enum.reduce(nodes, %{}, fn i, acc ->
        Map.put(acc, {i, i}, zero)
      end)

    # Add direct edges
    Enum.reduce(nodes, initial, fn i, acc ->
      successors = Model.successors(graph, i)

      Enum.reduce(successors, acc, fn {j, weight}, acc_inner ->
        # Keep the minimum weight if multiple edges exist
        case Map.fetch(acc_inner, {i, j}) do
          {:ok, existing} ->
            if compare_weights(weight, existing, &Yog.Utils.compare/2) == :lt do
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
  defp has_negative_cycle?(nodes, dist, compare) do
    Enum.any?(nodes, fn i ->
      case Map.fetch(dist, {i, i}) do
        {:ok, d} -> compare_weights(d, 0, compare) == :lt
        :error -> false
      end
    end)
  end

  # Compare two weights using the comparison function
  defp compare_weights(a, b, compare) do
    compare.(a, b)
  end
end
