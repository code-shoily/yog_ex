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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 3, with: 10)
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
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
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
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
    case :yog@pathfinding@floyd_warshall.floyd_warshall(graph, zero, add, compare) do
      {:ok, gleam_dict} ->
        {:ok, wrap_distance_matrix(gleam_dict)}

      {:error, _} ->
        {:error, :negative_cycle}
    end
  end

  @doc """
  Convenience function for integer weights.
  """
  @spec floyd_warshall_int(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => integer()}}
          | {:error, :negative_cycle}
  def floyd_warshall_int(graph) do
    case :yog@pathfinding@floyd_warshall.floyd_warshall_int(graph) do
      {:ok, gleam_dict} -> {:ok, wrap_distance_matrix(gleam_dict)}
      {:error, _} -> {:error, :negative_cycle}
    end
  end

  @doc """
  Convenience function for float weights.
  """
  @spec floyd_warshall_float(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => float()}}
          | {:error, :negative_cycle}
  def floyd_warshall_float(graph) do
    case :yog@pathfinding@floyd_warshall.floyd_warshall_float(graph) do
      {:ok, gleam_dict} -> {:ok, wrap_distance_matrix(gleam_dict)}
      {:error, _} -> {:error, :negative_cycle}
    end
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
    :yog@pathfinding@floyd_warshall.detect_negative_cycle(graph, zero, add, compare)
  end

  # Private helper to wrap Gleam distance matrix
  defp wrap_distance_matrix(gleam_dict) do
    gleam_dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end
end
