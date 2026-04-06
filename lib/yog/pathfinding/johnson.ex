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

  alias Yog.Pathfinding.Dijkstra
  alias Yog.Transform

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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: -3)
      ...> |> Yog.add_edge_ensure(from: 1, to: 3, with: 10)
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, distances} = Yog.Pathfinding.Johnson.johnson(graph, 0, &(&1 + &2), &(&1 - &2), compare)
      iex> # Shortest path from 1 to 3 should be 1->2->3 = 1, not direct 10
      ...> distances[{1, 3}]
      1

      # Negative cycle detection
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 1, with: -3)
      iex> compare = &Yog.Utils.compare/2
      iex> Yog.Pathfinding.Johnson.johnson(bad_graph, 0, &(&1 + &2), &(&1 - &2), compare)
      {:error, :negative_cycle}
  """
  @spec johnson(
          Yog.graph(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: {:ok, distance_matrix()} | {:error, :negative_cycle}
  def johnson(
        graph,
        zero \\ 0,
        add \\ &Kernel.+/2,
        subtract \\ &Kernel.-/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    nodes = Map.keys(graph.nodes)

    case compute_potentials(graph, nodes, zero, add, compare) do
      {:ok, potentials} ->
        distances = run_dijkstra_from_all(graph, nodes, potentials, zero, add, subtract, compare)
        {:ok, distances}

      {:error, :negative_cycle} ->
        {:error, :negative_cycle}
    end
  end

  # ============================================================
  # Helper functions
  # ============================================================

  defp compute_potentials(graph, nodes, zero, add, compare) do
    temp_source = make_ref()

    initial_distances = %{temp_source => zero}

    edges = get_all_edges_with_temp_source(graph.out_edges, nodes, temp_source, zero)

    node_count = length(nodes) + 1

    # Run Bellman-Ford with early termination
    case run_bellman_ford_with_early_stop(edges, initial_distances, node_count, add, compare) do
      :negative_cycle -> {:error, :negative_cycle}
      dists -> {:ok, Map.delete(dists, temp_source)}
    end
  end

  # Run Bellman-Ford with early termination optimization
  defp run_bellman_ford_with_early_stop(_edges, distances, 0, _add, _compare) do
    distances
  end

  defp run_bellman_ford_with_early_stop(edges, distances, iterations_left, add, compare) do
    new_distances = relax_all_edges(edges, distances, add, compare)

    if iterations_left == 1 do
      if distances_changed?(distances, new_distances, compare) do
        :negative_cycle
      else
        new_distances
      end
    else
      # Early termination: if no changes, we can stop
      if distances_equal?(distances, new_distances) do
        new_distances
      else
        run_bellman_ford_with_early_stop(edges, new_distances, iterations_left - 1, add, compare)
      end
    end
  end

  # Quick check if distances are equal (no changes)
  defp distances_equal?(old_dist, new_dist) do
    old_dist == new_dist
  end

  defp get_all_edges_with_temp_source(out_edges, nodes, temp_source, zero) do
    temp_edges = List.foldl(nodes, [], fn node, acc -> [{temp_source, node, zero} | acc] end)

    regular_edges =
      List.foldl(nodes, [], fn u, acc ->
        successors =
          case Map.fetch(out_edges, u) do
            {:ok, edges} -> Map.to_list(edges)
            :error -> []
          end

        List.foldl(successors, acc, fn {v, weight}, inner_acc -> [{u, v, weight} | inner_acc] end)
      end)

    temp_edges ++ regular_edges
  end

  # Relax all edges once
  defp relax_all_edges(edges, distances, add, compare) do
    List.foldl(edges, distances, fn {u, v, weight}, dist ->
      case Map.fetch(dist, u) do
        {:ok, dist_u} ->
          new_dist_v = add.(dist_u, weight)

          case Map.fetch(dist, v) do
            {:ok, current_dist_v} ->
              if compare.(new_dist_v, current_dist_v) == :lt do
                Map.put(dist, v, new_dist_v)
              else
                dist
              end

            :error ->
              Map.put(dist, v, new_dist_v)
          end

        :error ->
          dist
      end
    end)
  end

  # Check if distances changed (for negative cycle detection)
  defp distances_changed?(old_dist, new_dist, compare) do
    Enum.any?(new_dist, fn {node, new_val} ->
      case Map.fetch(old_dist, node) do
        {:ok, old_val} -> compare.(new_val, old_val) == :lt
        :error -> true
      end
    end)
  end

  # Run Dijkstra from each node with reweighted edges
  defp run_dijkstra_from_all(graph, nodes, potentials, zero, add, subtract, compare) do
    reweighted_graph =
      Transform.map_edges_indexed(graph, fn u, v, w ->
        h_u = Map.get(potentials, u, zero)
        h_v = Map.get(potentials, v, zero)
        add.(w, h_u) |> subtract.(h_v)
      end)

    parallel_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    ]

    nodes
    |> Task.async_stream(
      fn source ->
        reweighted_distances =
          Dijkstra.single_source_distances(reweighted_graph, source, zero, add, compare)

        h_source = Map.get(potentials, source, zero)

        List.foldl(Map.to_list(reweighted_distances), %{}, fn {dest, dist_prime}, inner_acc ->
          h_dest = Map.get(potentials, dest, zero)
          # dist = dist' - h(u) + h(v)
          adjusted_dist = add.(subtract.(dist_prime, h_source), h_dest)
          Map.put(inner_acc, {source, dest}, adjusted_dist)
        end)
      end,
      parallel_opts
    )
    |> Enum.reduce(%{}, fn {:ok, source_results}, acc ->
      Map.merge(acc, source_results)
    end)
  end
end
