defmodule Yog.Centrality do
  @moduledoc """
  Centrality measures for identifying important nodes in graphs.

  Provides degree, closeness, harmonic, betweenness, and PageRank centrality.
  All functions return a map of Node IDs to their scores.

  ## Overview

  | Measure | Function | Best For |
  |---------|----------|----------|
  | Degree | `degree/2` | Local connectivity |
  | Closeness | `closeness/2` | Distance to all others |
  | Harmonic | `harmonic/2` | Disconnected graphs |
  | Betweenness | `betweenness/2` | Bridge/gatekeeper detection |
  | PageRank | `pagerank/2` | Link-quality importance |
  | Eigenvector | `eigenvector/2` | Influence based on neighbor importance |
  | Katz | `katz/2` | Attenuated influence with base score |
  | Alpha | `alpha/2` | Directed graph influence |

  """

  alias Yog.PairingHeap, as: PQ
  alias Yog.Pathfinding.Dijkstra

  @typedoc """
  A mapping of Node IDs to their calculated centrality scores.
  """
  @type centrality_scores :: %{Yog.node_id() => float()}

  @typedoc """
  Specifies which edges to consider for directed graphs.
  - `:in_degree` - Consider only incoming edges (Prestige)
  - `:out_degree` - Consider only outgoing edges (Gregariousness)
  - `:total_degree` - Consider both incoming and outgoing edges
  """
  @type degree_mode :: :in_degree | :out_degree | :total_degree

  @doc """
  Calculates the Degree Centrality for all nodes in the graph.

  For directed graphs, use `mode` to specify which edges to count.
  For undirected graphs, the `mode` is ignored.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.degree(graph)
      iex> # In a triangle, all nodes have degree 2, normalized is 2/2 = 1.0
      iex> scores[1] |> Float.round(3)
      1.0

      iex> # Directed graph with different modes
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> # Out-degree: Node 1 has 1 outgoing edge
      iex> scores = Yog.Centrality.degree(graph, :out_degree)
      iex> scores[1] |> Float.round(3)
      0.5
  """
  @spec degree(Yog.graph(), degree_mode()) :: centrality_scores()
  def degree(graph, mode \\ :total_degree) do
    n = map_size(graph.nodes)
    nodes = Map.keys(graph.nodes)

    factor = if n > 1, do: (n - 1) * 1.0, else: 1.0

    %Yog.Graph{kind: kind, out_edges: out_edges, in_edges: in_edges} = graph

    List.foldl(nodes, %{}, fn id, acc ->
      count =
        case kind do
          :undirected ->
            Map.get(out_edges, id, %{}) |> map_size()

          :directed ->
            case mode do
              :in_degree ->
                Map.get(in_edges, id, %{}) |> map_size()

              :out_degree ->
                Map.get(out_edges, id, %{}) |> map_size()

              :total_degree ->
                (Map.get(out_edges, id, %{}) |> map_size()) +
                  (Map.get(in_edges, id, %{}) |> map_size())
            end
        end

      Map.put(acc, id, count / factor)
    end)
  end

  @doc """
  Calculates Closeness Centrality for all nodes.

  Closeness centrality measures how close a node is to all other nodes
  in the graph. It is calculated as the reciprocal of the sum of the
  shortest path distances from the node to all other nodes.

  Formula: C(v) = (n - 1) / Σ d(v, u) for all u ≠ v

  Note: In disconnected graphs, nodes that cannot reach all other nodes
  will have a centrality of 0.0. Consider `harmonic/2` for disconnected graphs.

  **Time Complexity:** O(V * (V + E) log V) using Dijkstra from each node

  ## Options

  - `:zero` - The identity element for distances (e.g., 0 for integers)
  - `:add` - Function to add two distances
  - `:compare` - Function to compare two distances (returns `:lt`, `:eq`, or `:gt`)
  - `:to_float` - Function to convert distance type to Float for final score

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.closeness(graph,
      ...>   zero: 0,
      ...>   add: &Kernel.+/2,
      ...>   compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   to_float: fn x -> x * 1.0 end
      ...> )
      iex> # In a triangle, all nodes have closeness 1.0
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec closeness(Yog.graph(), keyword()) :: centrality_scores()
  def closeness(graph, opts \\ []) do
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    to_float = opts[:to_float] || fn x -> x * 1.0 end

    nodes = Map.keys(graph.nodes)
    n = map_size(graph.nodes)

    if n <= 1 do
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 0.0)
      end)
    else
      # Set parallelism options
      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      nodes
      |> Task.async_stream(
        fn source ->
          distances = dijkstra_single_source(graph, source, zero, add, compare)

          if map_size(distances) < n do
            {source, 0.0}
          else
            total_distance =
              List.foldl(Map.to_list(distances), zero, fn {_node, dist}, sum ->
                add.(sum, dist)
              end)

            centrality_score = (n - 1) / to_float.(total_distance)
            {source, centrality_score}
          end
        end,
        parallel_opts
      )
      |> Enum.reduce(%{}, fn {:ok, {source, score}}, acc ->
        Map.put(acc, source, score)
      end)
    end
  end

  @doc """
  Calculates Harmonic Centrality for all nodes.

  Harmonic centrality is a variation of closeness centrality that handles
  disconnected graphs gracefully. It sums the reciprocals of the shortest
  path distances from a node to all reachable nodes.

  Formula: H(v) = Σ (1 / d(v, u)) / (n - 1) for all u ≠ v

  **Time Complexity:** O(V * (V + E) log V)

  ## Options

  - `:zero` - The identity element for distances
  - `:add` - Function to add two distances
  - `:compare` - Function to compare two distances (returns `:lt`, `:eq`, or `:gt`)
  - `:to_float` - Function to convert distance type to Float

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "Center")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}])
      iex> scores = Yog.Centrality.harmonic(graph,
      ...>   zero: 0,
      ...>   add: &Kernel.+/2,
      ...>   compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   to_float: fn x -> x * 1.0 end
      ...> )
      iex> # Center node: (1/1 + 1/1) / 2 = 1.0
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec harmonic(Yog.graph(), keyword()) :: centrality_scores()
  def harmonic(graph, opts \\ []) do
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    to_float = opts[:to_float] || fn x -> x * 1.0 end

    nodes = Map.keys(graph.nodes)
    n = map_size(graph.nodes)

    if n <= 1 do
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 0.0)
      end)
    else
      denominator = (n - 1) * 1.0

      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      nodes
      |> Task.async_stream(
        fn source ->
          distances = dijkstra_single_source(graph, source, zero, add, compare)

          sum_of_reciprocals =
            List.foldl(Map.to_list(distances), 0.0, fn {node, dist}, sum ->
              if node == source do
                sum
              else
                d = to_float.(dist)

                if d > 0.0 do
                  sum + 1.0 / d
                else
                  sum
                end
              end
            end)

          {source, sum_of_reciprocals / denominator}
        end,
        parallel_opts
      )
      |> Enum.reduce(%{}, fn {:ok, {source, score}}, acc ->
        Map.put(acc, source, score)
      end)
    end
  end

  @doc """
  Calculates Betweenness Centrality for all nodes.

  Betweenness centrality of a node v is the sum of the fraction of
  all-pairs shortest paths that pass through v.

  **Time Complexity:** O(VE) for unweighted, O(VE + V²logV) for weighted.

  ## Options

  - `:zero` - The identity element for distances
  - `:add` - Function to add two distances
  - `:compare` - Function to compare two distances (returns `:lt`, `:eq`, or `:gt`)
  - `:to_float` - Function to convert distance type to Float

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.betweenness(graph,
      ...>   zero: 0,
      ...>   add: &Kernel.+/2,
      ...>   compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   to_float: fn x -> x * 1.0 end
      ...> )
      iex> # In a path 1->2->3, node 2 lies on the shortest path from 1 to 3
      iex> scores[2] |> Float.round(3)
      1.0
  """
  @spec betweenness(Yog.graph(), keyword()) :: centrality_scores()
  def betweenness(graph, opts \\ []) do
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    _to_float = opts[:to_float] || fn x -> x * 1.0 end

    nodes = Map.keys(graph.nodes)

    initial =
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 0.0)
      end)

    parallel_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    ]

    scores =
      nodes
      |> Task.async_stream(
        fn s ->
          discovery = brandes_dijkstra(graph, s, zero, add, compare)
          dependencies = accumulate_dependencies(discovery)
          {s, dependencies}
        end,
        parallel_opts
      )
      |> Enum.reduce(initial, fn {:ok, {s, dependencies}}, acc ->
        merge_scores(acc, dependencies, s)
      end)

    apply_undirected_scaling(scores, graph)
  end

  @doc """
  Calculates PageRank centrality for all nodes.

  PageRank measures node importance based on the quality and quantity of
  incoming links. A node is important if it is linked to by other important
  nodes. Originally developed for ranking web pages, it's useful for:

  - Ranking nodes in directed networks
  - Identifying influential nodes in citation networks
  - Finding important entities in knowledge graphs
  - Recommendation systems

  The algorithm uses a "random surfer" model: with probability `damping`,
  the surfer follows a random outgoing link; otherwise, they jump to any
  random node.

  **Time Complexity:** O(max_iterations × (V + E))

  ## When to Use PageRank

  - **Directed graphs** where link direction matters
  - When you care about **link quality** (links from important nodes count more)
  - Citation networks, web graphs, recommendation systems

  For undirected graphs, consider `eigenvector/2` instead.

  ## Options

  - `:damping` - Probability of continuing to follow links (default: 0.85)
  - `:max_iterations` - Maximum iterations before returning (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.pagerank(graph)
      iex> # Scores should sum to approximately 1.0
      iex> Enum.sum(Map.values(scores)) |> Float.round(2)
      1.0
      iex> # With custom options
      iex> scores = Yog.Centrality.pagerank(graph, damping: 0.9, max_iterations: 50, tolerance: 0.001)
      iex> map_size(scores)
      3
  """
  @spec pagerank(Yog.graph(), keyword()) :: centrality_scores()
  def pagerank(graph, opts \\ []) do
    damping = Keyword.get(opts, :damping, 0.85)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    nodes = Map.keys(graph.nodes)
    n = length(nodes)

    %Yog.Graph{kind: kind, out_edges: out_edges, in_edges: in_edges} = graph

    in_neighbors_map =
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, get_in_neighbor_ids_fast(kind, out_edges, in_edges, id))
      end)

    out_degrees_map =
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, get_out_degree_fast(kind, out_edges, id))
      end)

    sinks =
      Enum.filter(nodes, fn id -> out_degrees_map[id] == 0 end)

    initial_rank = 1.0 / n

    ranks =
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, initial_rank)
      end)

    iterate_pagerank(
      ranks,
      nodes,
      n,
      damping,
      max_iterations,
      tolerance,
      0,
      in_neighbors_map,
      out_degrees_map,
      sinks
    )
  end

  @doc """
  Calculates Eigenvector Centrality for all nodes.

  Eigenvector centrality measures a node's influence based on the centrality
  of its neighbors. A node is important if it is connected to other important
  nodes. Uses power iteration to converge on the principal eigenvector.

  **Time Complexity:** O(max_iterations * (V + E))

  ## Options

  - `:max_iterations` - Maximum number of power iterations (default: 100)
  - `:tolerance` - Convergence threshold for L2 norm (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "center")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}])
      iex> scores = Yog.Centrality.eigenvector(graph)
      iex> scores[1] > scores[2]
      true
  """
  @spec eigenvector(Yog.graph(), keyword()) :: centrality_scores()
  def eigenvector(graph, opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    nodes = Map.keys(graph.nodes)
    n = map_size(graph.nodes)

    %Yog.Graph{kind: kind, out_edges: out_edges, in_edges: in_edges} = graph

    if n <= 1 do
      List.foldl(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 1.0)
      end)
    else
      in_neighbors_map =
        List.foldl(nodes, %{}, fn id, acc ->
          Map.put(acc, id, get_in_neighbor_ids_fast(kind, out_edges, in_edges, id))
        end)

      initial_scores =
        List.foldl(nodes, %{}, fn id, acc ->
          perturbation = :erlang.phash2(id) / 1_000_000_000.0
          Map.put(acc, id, 1.0 + perturbation)
        end)

      iterate_eigenvector(
        nodes,
        initial_scores,
        %{},
        max_iterations,
        tolerance,
        0,
        in_neighbors_map
      )
    end
  end

  @doc """
  Calculates Katz Centrality for all nodes.

  Katz centrality is a variant of eigenvector centrality that adds an
  attenuation factor (alpha) to prevent the infinite accumulation of
  centrality in cycles. It also includes a constant term (beta) to give
  every node some base centrality.

  Formula: C(v) = α * Σ C(u) + β for all neighbors u

  **Time Complexity:** O(max_iterations * (V + E))

  ## Options

  - `:alpha` - Attenuation factor (must be < 1/largest_eigenvalue, typically 0.1-0.3)
  - `:beta` - Base centrality (typically 1.0)
  - `:max_iterations` - Maximum number of iterations (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.katz(graph, alpha: 0.1, beta: 1.0)
      iex> # All scores should be >= beta
      iex> scores[1] >= 1.0
      true
  """
  @spec katz(Yog.graph(), keyword()) :: centrality_scores()
  def katz(graph, opts \\ []) do
    alpha = Keyword.fetch!(opts, :alpha)
    beta = Keyword.get(opts, :beta, 1.0)

    alpha(graph, Keyword.merge(opts, alpha: alpha, initial: beta))
  end

  @doc """
  Calculates Alpha Centrality for all nodes.

  Alpha centrality is a generalization of Katz centrality for directed
  graphs. It measures the total number of paths from a node, weighted
  by path length with attenuation factor alpha.

  Unlike Katz, alpha centrality does not include a constant beta term
  and is particularly useful for analyzing influence in directed networks.

  **Time Complexity:** O(max_iterations * (V + E))

  ## Options

  - `:alpha` - Attenuation factor (typically 0.1-0.5)
  - `:initial` - Initial centrality value for all nodes
  - `:max_iterations` - Maximum number of iterations (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.alpha(graph, alpha: 0.3, initial: 1.0)
      iex> map_size(scores)
      3
  """
  @spec alpha(Yog.graph(), keyword()) :: centrality_scores()
  def alpha(graph, opts \\ []) do
    alpha = Keyword.get(opts, :alpha, 0.1)
    max_iter = Keyword.get(opts, :max_iterations, 100)
    tol = Keyword.get(opts, :tolerance, 1.0e-6)

    nodes = Map.keys(graph.nodes)

    initial_scores =
      opts
      |> Keyword.get(:initial, 1.0)
      |> normalize_initial_scores(nodes)

    iterate_alpha(graph, nodes, initial_scores, initial_scores, alpha, max_iter, tol)
  end

  @doc """
  Degree centrality with default options for undirected graphs.
  Uses `:total_degree` mode.

  Same as `degree(graph, :total_degree)`.
  """
  @spec degree_total(Yog.graph()) :: centrality_scores()
  def degree_total(graph), do: degree(graph, :total_degree)

  # =============================================================================
  # Internal Helper Functions
  # =============================================================================

  # Dijkstra's algorithm for single-source shortest paths
  defp dijkstra_single_source(graph, source, zero, add, compare) do
    Dijkstra.single_source_distances(graph, source, zero, add, compare)
  end

  # Brandes' algorithm for betweenness centrality
  # Returns {stack, predecessors, sigma}
  defp brandes_dijkstra(graph, source, zero, add, compare) do
    pq = PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
    queue = PQ.push(pq, {zero, source})

    dist = %{source => zero}
    sigma = %{source => 1}
    preds = %{}
    stack = []

    do_brandes_dijkstra(graph, queue, dist, sigma, preds, stack, add, compare)
  end

  defp do_brandes_dijkstra(graph, pq, dist, sigma, preds, stack, add, compare) do
    out_edges = graph.out_edges

    if PQ.empty?(pq) do
      {stack, preds, sigma}
    else
      {:ok, {d_v, v}, rest_q} = PQ.pop(pq)
      current_best = Map.get(dist, v)

      if compare.(d_v, current_best) == :gt do
        do_brandes_dijkstra(graph, rest_q, dist, sigma, preds, stack, add, compare)
      else
        new_stack = [v | stack]

        successors =
          case Map.fetch(out_edges, v) do
            {:ok, edges} -> Map.to_list(edges)
            :error -> []
          end

        {new_q, new_dist, new_sigma, new_preds} =
          List.foldl(successors, {rest_q, dist, sigma, preds}, fn {w, weight}, {q, ds, ss, ps} ->
            new_dist_w = add.(d_v, weight)

            case Map.fetch(ds, w) do
              :error ->
                q2 = PQ.push(q, {new_dist_w, w})
                ds2 = Map.put(ds, w, new_dist_w)
                ss2 = Map.put(ss, w, Map.get(ss, v, 0))
                ps2 = Map.put(ps, w, [v])
                {q2, ds2, ss2, ps2}

              {:ok, old_dist} ->
                case compare.(new_dist_w, old_dist) do
                  :lt ->
                    q2 = PQ.push(q, {new_dist_w, w})
                    ds2 = Map.put(ds, w, new_dist_w)
                    ss2 = Map.put(ss, w, Map.get(ss, v, 0))
                    ps2 = Map.put(ps, w, [v])
                    {q2, ds2, ss2, ps2}

                  :eq ->
                    sigma_v = Map.get(ss, v, 0)
                    ss2 = Map.update(ss, w, sigma_v, fn curr -> curr + sigma_v end)
                    ps2 = Map.put(ps, w, [v | Map.get(ps, w, [])])

                    {q, ds, ss2, ps2}

                  :gt ->
                    {q, ds, ss, ps}
                end
            end
          end)

        do_brandes_dijkstra(graph, new_q, new_dist, new_sigma, new_preds, new_stack, add, compare)
      end
    end
  end

  defp accumulate_dependencies({stack, preds, sigma}) do
    do_accumulate(stack, preds, sigma, %{})
  end

  defp do_accumulate([], _preds, _sigma, deltas) do
    deltas
  end

  defp do_accumulate([v | rest], preds, sigma, deltas) do
    sigma_v = Map.get(sigma, v, 0)
    delta_v = Map.get(deltas, v, 0.0)
    v_preds = Map.get(preds, v, [])

    new_deltas =
      Enum.reduce(v_preds, deltas, fn u, acc_deltas ->
        sigma_u = Map.get(sigma, u, 0)
        # delta[u] += (sigma[u]/sigma[v]) * (1 + delta[v])
        fraction = sigma_u / sigma_v * (1.0 + delta_v)

        Map.update(acc_deltas, u, fraction, fn curr ->
          curr + fraction
        end)
      end)

    do_accumulate(rest, preds, sigma, new_deltas)
  end

  defp merge_scores(acc, dependencies, source) do
    List.foldl(Map.to_list(dependencies), acc, fn {node, delta}, acc2 ->
      if node == source do
        acc2
      else
        current = Map.get(acc2, node, 0.0)
        Map.put(acc2, node, current + delta)
      end
    end)
  end

  defp apply_undirected_scaling(scores, %Yog.Graph{kind: kind}) do
    case kind do
      :undirected ->
        Map.new(scores, fn {node, score} -> {node, score * 0.5} end)

      :directed ->
        scores
    end
  end

  defp iterate_pagerank(
         ranks,
         _nodes,
         _n,
         _damping,
         max_iterations,
         _tolerance,
         iter,
         _in_map,
         _out_map,
         _sinks
       )
       when iter >= max_iterations do
    ranks
  end

  defp iterate_pagerank(
         ranks,
         nodes,
         n,
         damping,
         max_iterations,
         tolerance,
         iter,
         in_map,
         out_map,
         sinks
       ) do
    n_float = n * 1.0

    sink_total =
      List.foldl(sinks, 0.0, fn sink, sum ->
        sum + Map.get(ranks, sink, 0.0)
      end)

    new_ranks =
      List.foldl(nodes, %{}, fn node, acc ->
        in_neighbors = Map.get(in_map, node, [])

        rank_sum =
          List.foldl(in_neighbors, 0.0, fn neighbor, sum ->
            neighbor_rank = Map.get(ranks, neighbor, 0.0)
            out_degree = Map.get(out_map, neighbor, 0)

            if out_degree > 0 do
              sum + neighbor_rank / out_degree
            else
              sum
            end
          end)

        teleport_const = (1.0 - damping) / n_float + damping * sink_total / n_float

        new_rank = teleport_const + damping * rank_sum
        Map.put(acc, node, new_rank)
      end)

    if Yog.Utils.norm_diff(ranks, new_ranks, :l1) < tolerance do
      new_ranks
    else
      iterate_pagerank(
        new_ranks,
        nodes,
        n,
        damping,
        max_iterations,
        tolerance,
        iter + 1,
        in_map,
        out_map,
        sinks
      )
    end
  end

  # Eigenvector centrality iteration
  defp iterate_eigenvector(_nodes, scores, _prev_prev, max_iterations, _tolerance, iter, _in_map)
       when iter >= max_iterations do
    scores
  end

  defp iterate_eigenvector(nodes, scores, prev_prev, max_iterations, tolerance, iter, in_map) do
    # Compute new scores: x_v = Σ A_uv * x_u for neighbors u
    new_scores =
      List.foldl(nodes, %{}, fn node, acc ->
        neighbor_sum =
          Map.get(in_map, node, [])
          |> List.foldl(0.0, fn neighbor, sum ->
            neighbor_score = Map.get(scores, neighbor, 0.0)
            sum + neighbor_score
          end)

        Map.put(acc, node, neighbor_sum)
      end)

    l2_sum =
      List.foldl(Map.to_list(new_scores), 0.0, fn {_, s}, acc ->
        acc + s * s
      end)

    l2_norm = :math.sqrt(l2_sum)

    normalized_scores =
      if l2_norm > 0 do
        Map.new(new_scores, fn {id, s} -> {id, s / l2_norm} end)
      else
        new_scores
      end

    diff_norm = Yog.Utils.norm_diff(scores, normalized_scores, :l2)

    is_oscillating =
      if map_size(prev_prev) > 0 do
        Yog.Utils.norm_diff(prev_prev, normalized_scores, :l2) < tolerance
      else
        false
      end

    if diff_norm < tolerance or is_oscillating do
      normalized_scores
    else
      iterate_eigenvector(
        nodes,
        normalized_scores,
        scores,
        max_iterations,
        tolerance,
        iter + 1,
        in_map
      )
    end
  end

  defp normalize_initial_scores(val, nodes) when is_number(val) do
    val_float = val / 1.0
    Map.new(nodes, fn node -> {node, val_float} end)
  end

  defp normalize_initial_scores(map, nodes) when is_map(map) do
    List.foldl(nodes, map, fn node, acc ->
      Map.put_new(acc, node, 1.0)
    end)
  end

  # Alpha centrality iteration
  defp iterate_alpha(_graph, _nodes, scores, _initial, _alpha, 0, _tol), do: scores

  defp iterate_alpha(graph, nodes, scores, initial_scores, alpha, iterations, tol) do
    in_edges = graph.in_edges

    new_scores =
      List.foldl(nodes, %{}, fn node, acc ->
        predecessors =
          case Map.fetch(in_edges, node) do
            {:ok, edges} -> Map.keys(edges)
            :error -> []
          end

        neighbor_influence =
          List.foldl(predecessors, 0.0, fn pred, sum ->
            sum + Map.get(scores, pred, 0.0)
          end)

        e_i = Map.get(initial_scores, node, 0.0)
        Map.put(acc, node, alpha * neighbor_influence + e_i)
      end)

    if converged?(scores, new_scores, nodes, tol) do
      new_scores
    else
      iterate_alpha(graph, nodes, new_scores, initial_scores, alpha, iterations - 1, tol)
    end
  end

  # Standardized L1 Norm convergence check
  defp converged?(old_scores, new_scores, _nodes, tolerance) do
    Yog.Utils.norm_diff(old_scores, new_scores, :l1) < tolerance
  end

  # Fast direct access versions for internal use
  defp get_in_neighbor_ids_fast(:undirected, out_edges, _in_edges, node) do
    case Map.fetch(out_edges, node) do
      {:ok, inner} -> Map.keys(inner)
      :error -> []
    end
  end

  defp get_in_neighbor_ids_fast(:directed, _out_edges, in_edges, node) do
    case Map.fetch(in_edges, node) do
      {:ok, inner} -> Map.keys(inner)
      :error -> []
    end
  end

  defp get_out_degree_fast(:undirected, out_edges, node) do
    case Map.fetch(out_edges, node) do
      {:ok, inner} -> map_size(inner)
      :error -> 0
    end
  end

  defp get_out_degree_fast(:directed, out_edges, node) do
    case Map.fetch(out_edges, node) do
      {:ok, inner} -> map_size(inner)
      :error -> 0
    end
  end
end
