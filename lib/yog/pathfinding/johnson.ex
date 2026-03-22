defmodule Yog.Pathfinding.Johnson do
  @moduledoc """
  [Johnson's algorithm](https://en.wikipedia.org/wiki/Johnson%27s_algorithm) for
  all-pairs shortest paths in weighted graphs with negative edge weights.

  Johnson's algorithm efficiently computes shortest paths between all pairs of nodes
  in sparse graphs, even when edges have negative weights (but no negative cycles).
  It combines Bellman-Ford and Dijkstra's algorithms with a reweighting technique.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Johnson's](https://en.wikipedia.org/wiki/Johnson%27s_algorithm) | `johnson/5` | O(V² log V + VE) | Sparse graphs with negative weights |

  ## Key Concepts

  - **Reweighting**: Transform negative weights to non-negative while preserving shortest paths
  - **Bellman-Ford Phase**: Compute reweighting function and detect negative cycles
  - **Dijkstra Phase**: Run Dijkstra from each vertex on reweighted graph
  - **Distance Adjustment**: Transform reweighted distances back to original weights

  ## How Reweighting Works

  The algorithm computes a potential function `h(v)` for each vertex such that:
  ```
  w'(u,v) = w(u,v) + h(u) - h(v) ≥ 0
  ```

  This transformation preserves shortest paths because for any path p = v₁→v₂→...→vₖ:
  ```
  w'(p) = w(p) + h(v₁) - h(vₖ)
  ```

  So the relative ordering of path weights remains the same!

  ## The Algorithm Steps

  1. **Add temporary source**: Create new vertex `s` with 0-weight edges to all vertices
  2. **Run Bellman-Ford**: From `s` to compute h(v) = distance[v] and detect negative cycles
  3. **Reweight edges**: Set w'(u,v) = w(u,v) + h(u) - h(v) for all edges
  4. **Run V × Dijkstra**: Compute shortest paths on reweighted graph
  5. **Adjust distances**: Set dist(u,v) = dist'(u,v) - h(u) + h(v)

  ## Comparison with Other All-Pairs Algorithms

  | Approach | Complexity | Best For |
  |----------|------------|----------|
  | Floyd-Warshall | O(V³) | Dense graphs (E ≈ V²) |
  | Johnson's | O(V² log V + VE) | Sparse graphs (E ≪ V²) |
  | V × Dijkstra | O(V(V+E) log V) | Sparse graphs, non-negative weights only |

  **Rule of thumb**:
  - Use Johnson's for sparse graphs with negative weights
  - Use Floyd-Warshall for dense graphs or when simplicity matters
  - Use V × Dijkstra for sparse graphs with only non-negative weights

  ## Negative Cycles

  The algorithm detects negative cycles during the Bellman-Ford phase.
  If a negative cycle exists, the function returns `{:error, :negative_cycle}`.

  ## Use Cases

  - **Sparse road networks**: Computing all-pairs distances with tolls/credits
  - **Currency arbitrage**: Finding profitable exchange cycles
  - **Network routing**: Precomputing routing tables with various costs
  - **Game AI**: Pathfinding in large sparse maps with varied terrain costs

  ## History

  Published by Donald B. Johnson in 1977.

  ## References

  - [Wikipedia: Johnson's Algorithm](https://en.wikipedia.org/wiki/Johnson%27s_algorithm)
  """

  @typedoc """
  Distance matrix: map from `{from, to}` tuple to distance.
  """
  @type distance_matrix :: %{{Yog.node_id(), Yog.node_id()} => any()}

  @doc """
  Computes all-pairs shortest paths using Johnson's algorithm.

  **Time Complexity:** O(V² log V + VE)

  Returns `{:ok, distance_matrix}` on success, or `{:error, :negative_cycle}`
  if a negative cycle is detected.

  ## Parameters

  - `graph` - The graph to analyze
  - `zero` - Identity element for addition
  - `add` - Function to add two weights
  - `subtract` - Function to subtract two weights
  - `compare` - Function to compare two weights

  ## Examples

      # Graph with negative weights (but no negative cycles)
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: -3)
      ...> |> Yog.add_edge!(from: 1, to: 3, with: 10)
      iex> {:ok, distances} = Yog.Pathfinding.Johnson.johnson(graph, 0, &(&1 + &2), &(&1 - &2), &Integer.compare/2)
      iex> # Shortest path from 1 to 3 should be 1->2->3 = 1, not direct 10
      ...> distances[{1, 3}]
      1

      # Negative cycle detection
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 1, with: -3)
      iex> Yog.Pathfinding.Johnson.johnson(bad_graph, 0, &(&1 + &2), &(&1 - &2), &Integer.compare/2)
      {:error, :negative_cycle}
  """
  @spec johnson(
          Yog.graph(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: {:ok, distance_matrix()} | {:error, :negative_cycle}
  def johnson(graph, zero, add, subtract, compare) do
    case :yog@pathfinding@johnson.johnson(graph, zero, add, subtract, compare) do
      {:ok, gleam_dict} -> {:ok, wrap_distance_matrix(gleam_dict)}
      {:error, _} -> {:error, :negative_cycle}
    end
  end

  @doc """
  Convenience function for integer weights.
  """
  @spec johnson_int(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => integer()}}
          | {:error, :negative_cycle}
  def johnson_int(graph) do
    case :yog@pathfinding@johnson.johnson_int(graph) do
      {:ok, gleam_dict} -> {:ok, wrap_distance_matrix(gleam_dict)}
      {:error, _} -> {:error, :negative_cycle}
    end
  end

  @doc """
  Convenience function for float weights.
  """
  @spec johnson_float(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => float()}}
          | {:error, :negative_cycle}
  def johnson_float(graph) do
    case :yog@pathfinding@johnson.johnson_float(graph) do
      {:ok, gleam_dict} -> {:ok, wrap_distance_matrix(gleam_dict)}
      {:error, _} -> {:error, :negative_cycle}
    end
  end

  # Private helper to wrap Gleam distance matrix
  defp wrap_distance_matrix(gleam_dict) do
    gleam_dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end
end
