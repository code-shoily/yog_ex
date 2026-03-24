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

  alias Yog.Model

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
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, distances} = Yog.Pathfinding.Johnson.johnson(graph, 0, &(&1 + &2), &(&1 - &2), compare)
      iex> # Shortest path from 1 to 3 should be 1->2->3 = 1, not direct 10
      ...> distances[{1, 3}]
      1

      # Negative cycle detection
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 1, with: -3)
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
  def johnson(graph, zero, add, subtract, compare) do
    nodes = Model.all_nodes(graph)

    # Step 1 & 2: Run Bellman-Ford from temporary source to get potentials h(v)
    case compute_potentials(graph, nodes, zero, add, compare) do
      {:ok, potentials} ->
        # Step 3, 4, 5: Run Dijkstra from each node with reweighted edges
        distances = run_dijkstra_from_all(graph, nodes, potentials, zero, add, subtract, compare)
        {:ok, distances}

      {:error, :negative_cycle} ->
        {:error, :negative_cycle}
    end
  end

  @doc """
  Convenience function for integer weights.
  """
  @spec johnson_int(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => integer()}}
          | {:error, :negative_cycle}
  def johnson_int(graph) do
    johnson(graph, 0, &(&1 + &2), &(&1 - &2), &Yog.Utils.compare/2)
  end

  @doc """
  Convenience function for float weights.
  """
  @spec johnson_float(Yog.graph()) ::
          {:ok, %{required({Yog.node_id(), Yog.node_id()}) => float()}}
          | {:error, :negative_cycle}
  def johnson_float(graph) do
    johnson(graph, 0.0, &(&1 + &2), &(&1 - &2), &Yog.Utils.compare/2)
  end

  # Step 1 & 2: Compute potentials h(v) using Bellman-Ford from temporary source
  defp compute_potentials(graph, nodes, zero, add, compare) do
    # Create temporary source with 0-weight edges to all nodes
    temp_source = :__johnson_temp_source__

    # Initialize distances: temp_source = 0, others = nil (infinity)
    initial_distances = %{temp_source => zero}

    # Get all edges including from temporary source
    edges = get_all_edges_with_temp_source(graph, nodes, temp_source, zero)

    # Relax edges |V| times (where |V| includes temp_source, so length(nodes) + 1)
    node_count = length(nodes) + 1

    distances =
      Enum.reduce(1..node_count, initial_distances, fn iteration, dist ->
        new_dist = relax_all_edges(edges, dist, add, compare)

        # Check for negative cycle on last iteration
        if iteration == node_count do
          if distances_changed?(dist, new_dist, compare) do
            :negative_cycle
          else
            new_dist
          end
        else
          new_dist
        end
      end)

    case distances do
      :negative_cycle -> {:error, :negative_cycle}
      dists -> {:ok, Map.delete(dists, temp_source)}
    end
  end

  # Get all edges from graph plus 0-weight edges from temp source to all nodes
  defp get_all_edges_with_temp_source(graph, nodes, temp_source, zero) do
    # Edges from temporary source to all nodes (weight = 0)
    temp_edges = Enum.map(nodes, fn node -> {temp_source, node, zero} end)

    # Regular edges from graph
    regular_edges =
      Enum.flat_map(nodes, fn u ->
        successors = Model.successors(graph, u)
        Enum.map(successors, fn {v, weight} -> {u, v, weight} end)
      end)

    temp_edges ++ regular_edges
  end

  # Relax all edges once
  defp relax_all_edges(edges, distances, add, compare) do
    Enum.reduce(edges, distances, fn {u, v, weight}, dist ->
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

  # Steps 3, 4, 5: Run Dijkstra from each node with reweighted edges
  defp run_dijkstra_from_all(graph, nodes, potentials, zero, add, subtract, compare) do
    Enum.reduce(nodes, %{}, fn source, acc ->
      # Run Dijkstra on reweighted graph
      reweighted_distances =
        dijkstra_reweighted(graph, source, potentials, zero, add, subtract, compare)

      # Adjust distances back: dist(u,v) = dist'(u,v) - h(u) + h(v)
      h_u = Map.get(potentials, source, zero)

      adjusted =
        Enum.reduce(reweighted_distances, %{}, fn {dest, dist_prime}, inner_acc ->
          h_v = Map.get(potentials, dest, zero)
          # dist = dist' - h(u) + h(v)
          adjusted_dist = add.(subtract.(dist_prime, h_u), h_v)
          Map.put(inner_acc, {source, dest}, adjusted_dist)
        end)

      Map.merge(acc, adjusted)
    end)
  end

  # Dijkstra on reweighted graph
  defp dijkstra_reweighted(graph, source, potentials, zero, add, subtract, compare) do
    # Priority queue implemented as sorted list for simplicity
    # {distance, node}
    initial_queue = [{zero, source}]
    initial_distances = %{source => zero}

    do_dijkstra(graph, initial_queue, initial_distances, potentials, add, subtract, compare)
  end

  defp do_dijkstra(_graph, [], distances, _potentials, _add, _subtract, _compare) do
    distances
  end

  defp do_dijkstra(
         graph,
         [{dist_u, u} | rest_queue],
         distances,
         potentials,
         add,
         subtract,
         compare
       ) do
    # Check if we've found a better path to u already
    current_best = Map.get(distances, u)

    if current_best != nil and compare.(dist_u, current_best) == :gt do
      # This entry is outdated, skip it
      do_dijkstra(graph, rest_queue, distances, potentials, add, subtract, compare)
    else
      # Relax edges from u
      h_u = Map.get(potentials, u, 0)
      successors = Model.successors(graph, u)

      {new_queue, new_distances} =
        Enum.reduce(successors, {rest_queue, distances}, fn {v, weight}, {q, d} ->
          h_v = Map.get(potentials, v, 0)
          # Reweighted edge: w'(u,v) = w(u,v) + h(u) - h(v)
          reweighted = add.(weight, h_u) |> subtract.(h_v)
          new_dist_v = add.(dist_u, reweighted)

          case Map.fetch(d, v) do
            {:ok, current} ->
              if compare.(new_dist_v, current) == :lt do
                new_q = insert_sorted(q, {new_dist_v, v}, compare)
                new_d = Map.put(d, v, new_dist_v)
                {new_q, new_d}
              else
                {q, d}
              end

            :error ->
              new_q = insert_sorted(q, {new_dist_v, v}, compare)
              new_d = Map.put(d, v, new_dist_v)
              {new_q, new_d}
          end
        end)

      do_dijkstra(graph, new_queue, new_distances, potentials, add, subtract, compare)
    end
  end

  # Insert into sorted list (priority queue)
  defp insert_sorted([], item, _compare), do: [item]

  defp insert_sorted([head | tail], item, compare) do
    {dist_item, _} = item
    {dist_head, _} = head

    if compare.(dist_item, dist_head) == :lt do
      [item, head | tail]
    else
      [head | insert_sorted(tail, item, compare)]
    end
  end
end
