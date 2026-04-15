defmodule Yog.Approximate do
  @moduledoc """
  Fast approximation algorithms for expensive graph properties.

  These algorithms trade exact precision for dramatically improved
  time complexity, making them suitable for large graphs where exact
  computation is prohibitive.

  ## Algorithms

  | Property | Function | Exact Complexity | Approximate Complexity |
  |----------|----------|------------------|------------------------|
  | Diameter | `diameter/2` | O(V × (V+E)) or O(V³) | O(k × (V+E)) |
  | Betweenness | `betweenness/2` | O(VE) | O(k(V+E)) |
  | Avg Path Length | `average_path_length/2` | O(V²E) or O(V³) | O(k(V+E)) |
  | Global Efficiency | `global_efficiency/2` | O(V²E) or O(V³) | O(k(V+E)) |
  | Transitivity | `transitivity/2` | O(V³) or O(Δ²E) | O(k) |
  | Vertex Cover | `vertex_cover/1` | NP-hard | O(V+E) |
  | Max Clique | `max_clique/1` | O(3^(V/3)) | O(V²) |

  ## Approximation Quality

  - **Diameter**: Multi-sweep BFS/Dijkstra provides a lower bound. Empirically
    within 10–20% on real-world networks. Set `samples: 4` for fast estimates,
    `samples: 10` for tighter bounds.
  - **Betweenness**: Sampled Brandes algorithm. Scores are unbiased when
    scaled by the sampling ratio.
  - **Path metrics**: Pivot sampling averages shortest paths from a random
    subset of source nodes.
  - **Transitivity**: Wedge sampling estimates the global clustering coefficient
    by randomly sampling connected triples.
  """

  alias Yog.Graph
  alias Yog.Model
  alias Yog.Pathfinding.Brandes
  alias Yog.Pathfinding.Dijkstra
  alias Yog.Transform

  @type metric_opts :: [
          with_zero: any(),
          with_add: (any(), any() -> any()),
          with_compare: (any(), any() -> :lt | :eq | :gt),
          with: (any() -> any()),
          to_float: (any() -> float())
        ]

  # =============================================================================
  # Diameter Approximation
  # =============================================================================

  @doc """
  Approximates the diameter using multi-sweep BFS/Dijkstra.

  The algorithm picks a random start node, finds the farthest node via
  shortest-path search, and repeats from that peripheral candidate.
  Each sweep provides a lower bound on the diameter. The maximum over
  all sweeps is returned.

  ## Options

  - `:samples` - Number of sweeps (default: 4)
  - `:with_zero`, `:with_add`, `:with_compare`, `:with` - Weight options
    for weighted graphs (same interface as `Yog.Health.diameter/2`)

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> diam = Yog.Approximate.diameter(graph, samples: 2)
      iex> diam >= 2 and diam <= 3
      true

  ## Time Complexity

  O(k × (V+E)) for unweighted graphs, O(k × (E + V log V)) for weighted.
  """
  @spec diameter(Graph.t(), keyword()) :: any()
  def diameter(%Graph{} = graph, opts \\ []) do
    samples = Keyword.get(opts, :samples, 4)

    zero = opts[:with_zero] || 0
    add = opts[:with_add] || (&Kernel.+/2)
    compare = opts[:with_compare] || (&Yog.Utils.compare/2)
    weight_fn = opts[:with] || (&Function.identity/1)

    reweighted_graph =
      if weight_fn != (&Function.identity/1),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    nodes = Model.all_nodes(reweighted_graph)

    if nodes == [] do
      nil
    else
      start = Enum.random(nodes)

      {best, _} =
        Enum.reduce(1..samples, {zero, start}, fn _i, {best_so_far, candidate} ->
          {farthest, dist} =
            farthest_node(reweighted_graph, candidate, zero, add, compare)

          new_best =
            if compare.(dist, best_so_far) == :gt, do: dist, else: best_so_far

          {new_best, farthest}
        end)

      best
    end
  end

  defp farthest_node(graph, source, zero, add, compare) do
    distances = Dijkstra.single_source_distances(graph, source, zero, add, compare)

    Enum.reduce(distances, {source, zero}, fn {node, dist}, {farthest, max_dist} ->
      if compare.(dist, max_dist) == :gt,
        do: {node, dist},
        else: {farthest, max_dist}
    end)
  end

  # =============================================================================
  # Betweenness Centrality Approximation
  # =============================================================================

  @doc """
  Approximates betweenness centrality using sampled Brandes sources.

  Only a random subset of nodes is used as sources for the dependency
  accumulation. The resulting scores are scaled by `n / k` to remain
  unbiased estimators of the exact betweenness values.

  ## Options

  - `:samples` - Number of source nodes to sample. Defaults to `sqrt(V)`.
  - `:seed` - Random seed for reproducible sampling (optional)
  - `:zero`, `:add`, `:compare` - Weight options for weighted graphs

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {2, 3, 1}, {2, 4, 1}])
      iex> scores = Yog.Approximate.betweenness(graph, samples: 2)
      iex> is_map(scores) and map_size(scores) == 4
      true

  ## Time Complexity

  O(k(V+E)) where k is the sample count.
  """
  @spec betweenness(Graph.t(), keyword()) :: %{Yog.node_id() => float()}
  def betweenness(%Graph{} = graph, opts \\ []) do
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n == 0 do
      %{}
    else
      samples = Keyword.get(opts, :samples, trunc(:math.sqrt(n)))
      seed = Keyword.get(opts, :seed)

      sampled = sample_nodes(nodes, min(samples, n), seed)
      n_sampled = length(sampled)

      initial = Map.new(nodes, fn id -> {id, 0.0} end)

      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      scores =
        sampled
        |> Task.async_stream(
          fn s ->
            {stack, preds, sigmas} = Brandes.discovery(graph, s, zero, add, compare)
            deps = Brandes.accumulate_node_dependencies(stack, preds, sigmas)
            {s, deps}
          end,
          parallel_opts
        )
        |> Enum.reduce(initial, fn {:ok, {_s, dependencies}}, acc ->
          merge_scores(acc, dependencies)
        end)

      # Scale to unbiased estimate: multiply by n / k
      scale = n / max(n_sampled, 1) * 1.0

      scaled_scores = Map.new(scores, fn {id, score} -> {id, score * scale} end)
      apply_undirected_scaling(scaled_scores, graph)
    end
  end

  defp merge_scores(acc, dependencies) do
    Enum.reduce(dependencies, acc, fn {node, score}, scores ->
      Map.update(scores, node, score, &(&1 + score))
    end)
  end

  defp apply_undirected_scaling(scores, %Graph{kind: :undirected}) do
    Map.new(scores, fn {id, score} -> {id, score * 0.5} end)
  end

  defp apply_undirected_scaling(scores, %Graph{kind: :directed}), do: scores

  # =============================================================================
  # Average Shortest Path Length Approximation
  # =============================================================================

  @doc """
  Approximates the average shortest path length using pivot sampling.

  Instead of computing shortest paths from all nodes, a random subset of
  source nodes is used. The mean over sampled sources is returned.

  Returns `nil` if the graph is empty or disconnected.

  ## Options

  - `:samples` - Number of pivot nodes (default: `sqrt(V)`)
  - `:seed` - Random seed for reproducibility
  - `:with_zero`, `:with_add`, `:with_compare`, `:with`, `:to_float` -
    Weight options (same as `Yog.Health.average_path_length/2`)

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> apl = Yog.Approximate.average_path_length(graph, samples: 2)
      iex> apl > 0
      true

  ## Time Complexity

  O(k × (E + V log V)) where k is the sample count.
  """
  @spec average_path_length(Graph.t(), keyword()) :: float() | nil
  def average_path_length(%Graph{} = graph, opts \\ []) do
    %{zero: zero, add: add, compare: compare, weight_fn: weight_fn, to_float: to_float} =
      parse_metric_opts(opts)

    reweighted_graph =
      if Keyword.has_key?(opts, :with),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    nodes = Model.all_nodes(reweighted_graph)
    n = length(nodes)

    if n <= 1 do
      0.0
    else
      samples = Keyword.get(opts, :samples, trunc(:math.sqrt(n)))
      seed = Keyword.get(opts, :seed)
      sampled = sample_nodes(nodes, min(samples, n), seed)

      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      {total_sum, reachable_pairs} =
        sampled
        |> Task.async_stream(
          fn source ->
            distances =
              Dijkstra.single_source_distances(reweighted_graph, source, zero, add, compare)

            distances
            |> Map.delete(source)
            |> Enum.reduce({0.0, 0}, fn {_node, dist}, {sum, count} ->
              {sum + to_float.(dist), count + 1}
            end)
          end,
          parallel_opts
        )
        |> Enum.reduce({0.0, 0}, fn {:ok, {sum, count}}, {acc_sum, acc_count} ->
          {acc_sum + sum, acc_count + count}
        end)

      if reachable_pairs == 0 do
        nil
      else
        # Scale the sample average to the population
        total_sum / reachable_pairs
      end
    end
  end

  # =============================================================================
  # Global Efficiency Approximation
  # =============================================================================

  @doc """
  Approximates global efficiency using pivot sampling.

  ## Options

  - `:samples` - Number of pivot nodes (default: `sqrt(V)`)
  - `:seed` - Random seed for reproducibility
  - `:with_zero`, `:with_add`, `:with_compare`, `:with`, `:to_float` -
    Weight options (same as `Yog.Health.global_efficiency/2`)

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> eff = Yog.Approximate.global_efficiency(graph, samples: 2)
      iex> eff > 0.0 and eff <= 1.0
      true

  ## Time Complexity

  O(k × (E + V log V)) where k is the sample count.
  """
  @spec global_efficiency(Graph.t(), keyword()) :: float()
  def global_efficiency(%Graph{} = graph, opts \\ []) do
    %{zero: zero, add: add, compare: compare, weight_fn: weight_fn, to_float: to_float} =
      parse_metric_opts(opts)

    reweighted_graph =
      if Keyword.has_key?(opts, :with),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    nodes = Model.all_nodes(reweighted_graph)
    n = length(nodes)

    if n <= 1 do
      0.0
    else
      samples = Keyword.get(opts, :samples, trunc(:math.sqrt(n)))
      seed = Keyword.get(opts, :seed)
      sampled = sample_nodes(nodes, min(samples, n), seed)

      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      total =
        sampled
        |> Task.async_stream(
          fn source ->
            distances =
              Dijkstra.single_source_distances(reweighted_graph, source, zero, add, compare)

            distances
            |> Map.delete(source)
            |> Enum.reduce(0.0, fn {_node, dist}, sum ->
              sum + safe_inverse(dist, to_float)
            end)
          end,
          parallel_opts
        )
        |> Enum.reduce(0.0, fn {:ok, source_sum}, acc -> acc + source_sum end)

      # Scale from sample average to population average
      total * (n / max(length(sampled), 1)) / (n * (n - 1) * 1.0)
    end
  end

  defp safe_inverse(dist, to_float) do
    f = to_float.(dist)
    if f == 0.0, do: 0.0, else: 1.0 / f
  end

  # =============================================================================
  # Transitivity Approximation
  # =============================================================================

  @doc """
  Approximates transitivity (global clustering coefficient) via wedge sampling.

  Randomly samples "wedges" (connected triples u-v-w) and checks whether
  the closing edge v-w or u-w exists, forming a triangle. The fraction of
  closed wedges estimates the clustering coefficient.

  For exact transitivity, use `Yog.Community.Metrics.transitivity/1`.

  ## Options

  - `:samples` - Number of wedges to sample (default: `min(10_000, V²)`)
  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> triangle = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> t = Yog.Approximate.transitivity(triangle, samples: 100)
      iex> t > 0.9
      true

  ## Time Complexity

  O(k) where k is the number of sampled wedges.
  """
  @spec transitivity(Graph.t(), keyword()) :: float()
  def transitivity(%Graph{nodes: nodes} = graph, opts \\ []) do
    node_list = Map.keys(nodes)
    n = length(node_list)

    if n < 3 do
      0.0
    else
      # Build adjacency sets for fast O(1) lookups
      adj =
        Map.new(node_list, fn u ->
          neighbors =
            graph
            |> Model.neighbor_ids(u)
            |> MapSet.new()

          {u, neighbors}
        end)

      # Compute degree of each node and total wedge count
      degrees = Map.new(node_list, fn u -> {u, MapSet.size(Map.fetch!(adj, u))} end)

      total_wedges =
        Enum.reduce(degrees, 0, fn {_u, deg}, acc ->
          acc + div(deg * (deg - 1), 2)
        end)

      if total_wedges == 0 do
        0.0
      else
        samples = Keyword.get(opts, :samples, min(10_000, n * n))
        seed = Keyword.get(opts, :seed)

        closed = sample_wedges(node_list, adj, degrees, samples, seed)
        closed / samples * 1.0
      end
    end
  end

  defp sample_wedges(nodes, adj, _degrees, samples, seed) do
    rng = if seed, do: :rand.seed_s(:exsss, {seed, seed, seed}), else: :rand.seed_s(:exsss)

    {closed, _rng} =
      Enum.reduce(1..samples, {0, rng}, fn _i, {acc, rng_state} ->
        {u, rng_state} = random_element(nodes, rng_state)
        u_neighbors = Map.fetch!(adj, u) |> MapSet.to_list()

        if length(u_neighbors) < 2 do
          {acc, rng_state}
        else
          {v, rng_state} = random_element(u_neighbors, rng_state)
          w_candidates = Enum.reject(u_neighbors, &(&1 == v))

          if w_candidates == [] do
            {acc, rng_state}
          else
            {w, rng_state} = random_element(w_candidates, rng_state)

            if MapSet.member?(Map.fetch!(adj, v), w) do
              {acc + 1, rng_state}
            else
              {acc, rng_state}
            end
          end
        end
      end)

    closed
  end

  defp random_element(list, rng_state) do
    {idx, new_rng} = :rand.uniform_s(length(list), rng_state)
    {Enum.at(list, idx - 1), new_rng}
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  defp sample_nodes(nodes, k, seed) do
    if k >= length(nodes) do
      nodes
    else
      shuffled =
        if seed do
          Yog.Utils.fisher_yates(nodes, seed)
        else
          Enum.shuffle(nodes)
        end

      Enum.take(shuffled, k)
    end
  end

  defp parse_metric_opts(opts) do
    %{
      zero: opts[:with_zero] || 0,
      add: opts[:with_add] || (&Kernel.+/2),
      compare: opts[:with_compare] || (&Yog.Utils.compare/2),
      weight_fn: opts[:with] || (&Function.identity/1),
      to_float: opts[:with_to_float] || fn x -> x * 1.0 end
    }
  end

  # =============================================================================
  # Vertex Cover Approximation
  # =============================================================================

  @doc """
  Returns a 2-approximation of the minimum vertex cover.

  A vertex cover is a set of nodes such that every edge in the graph is
  incident to at least one node in the set. This implementation uses the
  classic greedy algorithm: repeatedly pick an uncovered edge and add both
  endpoints to the cover. The result is guaranteed to be at most twice the
  size of the optimal minimum vertex cover.

  Works for both undirected and directed graphs. For directed graphs,
  an edge (u, v) is considered covered if u or v is in the set.

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> cover = Yog.Approximate.vertex_cover(graph)
      iex> MapSet.size(cover) <= 4
      true
      iex> # Every edge touches the cover
      iex> Enum.all?(Yog.all_edges(graph), fn {u, v, _} ->
      ...>   MapSet.member?(cover, u) or MapSet.member?(cover, v)
      ...> end)
      true

  ## Time Complexity

  O(V + E)
  """
  @spec vertex_cover(Graph.t()) :: MapSet.t(Yog.node_id())
  def vertex_cover(%Graph{} = graph) do
    edges = Model.all_edges(graph)
    do_vertex_cover(edges, MapSet.new())
  end

  defp do_vertex_cover([], cover), do: cover

  defp do_vertex_cover([{u, v, _} | rest], cover) do
    if MapSet.member?(cover, u) or MapSet.member?(cover, v) do
      do_vertex_cover(rest, cover)
    else
      do_vertex_cover(rest, cover |> MapSet.put(u) |> MapSet.put(v))
    end
  end

  # =============================================================================
  # Max Clique Approximation
  # =============================================================================

  @doc """
  Returns a large clique using a greedy heuristic.

  The algorithm sorts nodes by degree (descending) and greedily builds a
  clique by adding each node if it is adjacent to all nodes already in the
  clique. While not guaranteed to find the maximum clique, it runs in
  O(V²) time and typically finds a clique of reasonable size on dense graphs.

  Returns a `MapSet` of node IDs.

  ## Examples

      iex> triangle = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> clique = Yog.Approximate.max_clique(triangle)
      iex> MapSet.size(clique)
      3

      iex> path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> clique = Yog.Approximate.max_clique(path)
      iex> MapSet.size(clique) >= 2
      true

  ## Time Complexity

  O(V²)
  """
  @spec max_clique(Graph.t()) :: MapSet.t(Yog.node_id())
  def max_clique(%Graph{} = graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      MapSet.new()
    else
      adj =
        Map.new(nodes, fn u ->
          {u, Model.neighbor_ids(graph, u) |> MapSet.new()}
        end)

      # Try starting from each node, keep the best clique found
      sorted = Enum.sort_by(nodes, fn u -> MapSet.size(Map.fetch!(adj, u)) end, :desc)

      Enum.reduce(sorted, MapSet.new(), fn start_node, best ->
        clique = greedy_clique([start_node | sorted], adj, MapSet.new([start_node]))

        if MapSet.size(clique) > MapSet.size(best) do
          clique
        else
          best
        end
      end)
    end
  end

  defp greedy_clique([], _adj, clique), do: clique

  defp greedy_clique([candidate | rest], adj, clique) do
    if MapSet.member?(clique, candidate) do
      greedy_clique(rest, adj, clique)
    else
      neighbors = Map.fetch!(adj, candidate)

      if MapSet.subset?(clique, neighbors) do
        greedy_clique(rest, adj, MapSet.put(clique, candidate))
      else
        greedy_clique(rest, adj, clique)
      end
    end
  end
end
