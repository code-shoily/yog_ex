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

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.Model
  alias Yog.PriorityQueue, as: PQ

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
    n = Model.order(graph)
    nodes = Model.all_nodes(graph)

    factor = if n > 1, do: (n - 1) * 1.0, else: 1.0

    %Yog.Graph{kind: kind} = graph

    Enum.reduce(nodes, %{}, fn id, acc ->
      count =
        case kind do
          :undirected ->
            length(Model.neighbors(graph, id))

          :directed ->
            case mode do
              :in_degree ->
                length(Model.predecessors(graph, id))

              :out_degree ->
                length(Model.successors(graph, id))

              :total_degree ->
                length(Model.successors(graph, id)) + length(Model.predecessors(graph, id))
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
  def closeness(graph, opts) do
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    to_float = Keyword.fetch!(opts, :to_float)

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n <= 1 do
      Enum.reduce(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 0.0)
      end)
    else
      Enum.reduce(nodes, %{}, fn source, acc ->
        distances = dijkstra_single_source(graph, source, zero, add, compare)

        if map_size(distances) < n do
          # Node cannot reach all others
          Map.put(acc, source, 0.0)
        else
          # Sum all distances (including 0 for self)
          total_distance =
            Enum.reduce(distances, zero, fn {_node, dist}, sum ->
              add.(sum, dist)
            end)

          # Calculate closeness: (n-1) / sum_of_distances
          centrality_score = (n - 1) / to_float.(total_distance)
          Map.put(acc, source, centrality_score)
        end
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
  def harmonic(graph, opts) do
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    to_float = Keyword.fetch!(opts, :to_float)

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n <= 1 do
      Enum.reduce(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 0.0)
      end)
    else
      denominator = (n - 1) * 1.0

      Enum.reduce(nodes, %{}, fn source, acc ->
        distances = dijkstra_single_source(graph, source, zero, add, compare)

        sum_of_reciprocals =
          Enum.reduce(distances, 0.0, fn {node, dist}, sum ->
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

        Map.put(acc, source, sum_of_reciprocals / denominator)
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
  def betweenness(graph, opts) do
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    _to_float = Keyword.fetch!(opts, :to_float)

    nodes = Model.all_nodes(graph)

    initial =
      Enum.reduce(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 0.0)
      end)

    scores =
      Enum.reduce(nodes, initial, fn s, acc ->
        discovery = brandes_dijkstra(graph, s, zero, add, compare)
        dependencies = accumulate_dependencies(discovery)

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

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    initial_rank = 1.0 / n

    ranks =
      Enum.reduce(nodes, %{}, fn id, acc ->
        Map.put(acc, id, initial_rank)
      end)

    iterate_pagerank(graph, ranks, nodes, n, damping, max_iterations, tolerance, 0)
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

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n <= 1 do
      Enum.reduce(nodes, %{}, fn id, acc ->
        Map.put(acc, id, 1.0)
      end)
    else
      # Initialize with small perturbation based on node ID to break symmetry
      initial_scores =
        Enum.reduce(nodes, %{}, fn id, acc ->
          perturbation = id / 1000.0
          Map.put(acc, id, 1.0 + perturbation)
        end)

      iterate_eigenvector(graph, nodes, initial_scores, %{}, max_iterations, tolerance, 0)
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
    beta = Keyword.fetch!(opts, :beta)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n <= 0 do
      %{}
    else
      initial_scores =
        Enum.reduce(nodes, %{}, fn id, acc ->
          Map.put(acc, id, beta)
        end)

      iterate_katz(graph, nodes, initial_scores, alpha, beta, max_iterations, tolerance, 0)
    end
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
    alpha = Keyword.fetch!(opts, :alpha)
    initial = Keyword.fetch!(opts, :initial)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n <= 0 do
      %{}
    else
      initial_scores =
        Enum.reduce(nodes, %{}, fn id, acc ->
          Map.put(acc, id, initial)
        end)

      iterate_alpha(graph, nodes, initial_scores, alpha, max_iterations, tolerance, 0)
    end
  end

  @doc """
  Closeness centrality with **Int** weights (e.g., unweighted graphs).
  Uses 0 as zero, `&Kernel.+/2`, integer comparison, and `&(&1 * 1.0)` for conversion.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.closeness_int(graph)
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec closeness_int(Yog.graph()) :: centrality_scores()
  def closeness_int(graph) do
    closeness(graph,
      zero: 0,
      add: &Kernel.+/2,
      compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      to_float: fn x -> x * 1.0 end
    )
  end

  @doc """
  Harmonic centrality with **Int** weights.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.harmonic_int(graph)
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec harmonic_int(Yog.graph()) :: centrality_scores()
  def harmonic_int(graph) do
    harmonic(graph,
      zero: 0,
      add: &Kernel.+/2,
      compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      to_float: fn x -> x * 1.0 end
    )
  end

  @doc """
  Betweenness centrality with **Int** weights.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.betweenness_int(graph)
      iex> # Node 2 is on the shortest path from 1 to 3
      iex> scores[2] |> Float.round(3)
      1.0
  """
  @spec betweenness_int(Yog.graph()) :: centrality_scores()
  def betweenness_int(graph) do
    betweenness(graph,
      zero: 0,
      add: &Kernel.+/2,
      compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      to_float: fn x -> x * 1.0 end
    )
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
    # Priority queue: [{distance, node}], ordered by distance
    pq = PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
    initial_pq = PQ.push(pq, {zero, source})
    initial_distances = %{source => zero}

    do_dijkstra(graph, initial_pq, initial_distances, add, compare)
  end

  defp do_dijkstra(graph, pq, distances, add, compare) do
    if PQ.empty?(pq) do
      distances
    else
      {:ok, {dist, node}, rest_pq} = PQ.pop(pq)
      current_best = Map.get(distances, node)

      if compare.(dist, current_best) == :gt do
        # This entry is outdated, skip it
        do_dijkstra(graph, rest_pq, distances, add, compare)
      else
        # Relax neighbors
        neighbors = Model.successors(graph, node)

        {new_pq, new_distances} =
          Enum.reduce(neighbors, {rest_pq, distances}, fn {neighbor, weight}, {pq_acc, dists} ->
            new_dist = add.(dist, weight)

            case Map.fetch(dists, neighbor) do
              :error ->
                # First time visiting this node
                new_dists = Map.put(dists, neighbor, new_dist)
                new_pq = PQ.push(pq_acc, {new_dist, neighbor})
                {new_pq, new_dists}

              {:ok, old_dist} ->
                if compare.(new_dist, old_dist) == :lt do
                  new_dists = Map.put(dists, neighbor, new_dist)
                  new_pq = PQ.push(pq_acc, {new_dist, neighbor})
                  {new_pq, new_dists}
                else
                  {pq_acc, dists}
                end
            end
          end)

        do_dijkstra(graph, new_pq, new_distances, add, compare)
      end
    end
  end

  # Brandes' algorithm for betweenness centrality
  # Returns {stack, predecessors, sigma}
  defp brandes_dijkstra(graph, source, zero, add, compare) do
    # Priority queue: [{distance, node}], ordered by distance
    pq = PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
    queue = PQ.push(pq, {zero, source})

    # Distance map
    dist = %{source => zero}

    # Sigma (number of shortest paths)
    sigma = %{source => 1}

    # Predecessors
    preds = %{}

    # Stack for accumulation phase
    stack = []

    do_brandes_dijkstra(graph, queue, dist, sigma, preds, stack, add, compare)
  end

  defp do_brandes_dijkstra(graph, pq, dist, sigma, preds, stack, add, compare) do
    if PQ.empty?(pq) do
      {stack, preds, sigma}
    else
      {:ok, {d_v, v}, rest_q} = PQ.pop(pq)
      current_best = Map.get(dist, v)

      if compare.(d_v, current_best) == :gt do
        # Outdated entry
        do_brandes_dijkstra(graph, rest_q, dist, sigma, preds, stack, add, compare)
      else
        new_stack = [v | stack]

        {new_q, new_dist, new_sigma, new_preds} =
          Model.successors(graph, v)
          |> Enum.reduce({rest_q, dist, sigma, preds}, fn {w, weight}, {q, ds, ss, ps} ->
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
                    ss2 =
                      Map.update(ss, w, Map.get(ss, v, 0), fn curr ->
                        curr + Map.get(ss, v, 0)
                      end)

                    ps2 =
                      Map.update(ps, w, [v], fn curr ->
                        [v | curr]
                      end)

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
    Enum.reduce(dependencies, acc, fn {node, delta}, acc2 ->
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
        Map.new(scores, fn {node, score} ->
          {node, score * 0.5}
        end)

      :directed ->
        scores
    end
  end

  # PageRank iteration
  defp iterate_pagerank(_graph, ranks, _nodes, _n, _damping, max_iter, _tolerance, iter)
       when iter >= max_iter do
    ranks
  end

  defp iterate_pagerank(graph, ranks, nodes, n, damping, max_iter, tolerance, iter) do
    n_float = n * 1.0

    sink_sum = calculate_sink_sum(graph, ranks, nodes, n_float)

    new_ranks =
      Enum.reduce(nodes, %{}, fn node, acc ->
        in_neighbors = get_in_neighbors(graph, node)

        rank_sum =
          Enum.reduce(in_neighbors, 0.0, fn neighbor, sum ->
            neighbor_rank = Map.get(ranks, neighbor, 0.0)
            out_degree = get_out_degree(graph, neighbor)

            if out_degree > 0 do
              sum + neighbor_rank / out_degree
            else
              sum
            end
          end)

        new_rank = (1.0 - damping) / n_float + damping * (sink_sum + rank_sum)
        Map.put(acc, node, new_rank)
      end)

    l1_norm = calculate_l1_norm(ranks, new_ranks, nodes)

    if l1_norm < tolerance do
      new_ranks
    else
      iterate_pagerank(graph, new_ranks, nodes, n, damping, max_iter, tolerance, iter + 1)
    end
  end

  defp calculate_sink_sum(graph, ranks, nodes, n_float) do
    Enum.reduce(nodes, 0.0, fn node, sum ->
      out_degree = get_out_degree(graph, node)

      if out_degree == 0 do
        node_rank = Map.get(ranks, node, 0.0)
        sum + node_rank / n_float
      else
        sum
      end
    end)
  end

  defp get_in_neighbors(graph, node) do
    %Yog.Graph{kind: kind} = graph

    case kind do
      :undirected ->
        Model.successors(graph, node)
        |> Enum.map(fn {edge, _} -> edge end)

      :directed ->
        Model.predecessors(graph, node)
        |> Enum.map(fn {edge, _} -> edge end)
    end
  end

  defp get_out_degree(graph, node) do
    %Yog.Graph{kind: kind} = graph

    case kind do
      :undirected ->
        length(Model.neighbors(graph, node))

      :directed ->
        length(Model.successors(graph, node))
    end
  end

  defp calculate_l1_norm(old_ranks, new_ranks, nodes) do
    Enum.reduce(nodes, 0.0, fn node, sum ->
      old_val = Map.get(old_ranks, node, 0.0)
      new_val = Map.get(new_ranks, node, 0.0)
      diff = abs(new_val - old_val)
      sum + diff
    end)
  end

  # Eigenvector centrality iteration
  defp iterate_eigenvector(_graph, _nodes, scores, _prev_prev, max_iter, _tolerance, iter)
       when iter >= max_iter do
    scores
  end

  defp iterate_eigenvector(graph, nodes, scores, prev_prev, max_iter, tolerance, iter) do
    # Compute new scores: x_v = Σ A_uv * x_u for neighbors u
    new_scores =
      Enum.reduce(nodes, %{}, fn node, acc ->
        neighbor_sum =
          get_in_neighbors(graph, node)
          |> Enum.reduce(0.0, fn neighbor, sum ->
            neighbor_score = Map.get(scores, neighbor, 0.0)
            sum + neighbor_score
          end)

        Map.put(acc, node, neighbor_sum)
      end)

    l2_norm = calculate_l2_norm(new_scores, nodes)

    normalized =
      if l2_norm > 0.0 do
        Map.new(new_scores, fn {node, score} ->
          {node, score / l2_norm}
        end)
      else
        new_scores
      end

    l2_diff = calculate_l2_difference(scores, normalized, nodes)

    is_oscillating =
      if map_size(prev_prev) > 0 do
        l2_diff_2 = calculate_l2_difference(prev_prev, normalized, nodes)
        l2_diff_2 < tolerance
      else
        false
      end

    cond do
      is_oscillating ->
        # Average the two oscillating states
        averaged =
          Enum.reduce(nodes, %{}, fn node, acc ->
            val1 = Map.get(normalized, node, 0.0)
            val2 = Map.get(scores, node, 0.0)
            avg = (val1 + val2) / 2.0
            Map.put(acc, node, avg)
          end)

        avg_norm = calculate_l2_norm(averaged, nodes)

        if avg_norm > 0.0 do
          Map.new(averaged, fn {node, score} ->
            {node, score / avg_norm}
          end)
        else
          averaged
        end

      l2_diff < tolerance ->
        normalized

      true ->
        iterate_eigenvector(graph, nodes, normalized, scores, max_iter, tolerance, iter + 1)
    end
  end

  defp calculate_l2_norm(scores, nodes) do
    sum_squares =
      Enum.reduce(nodes, 0.0, fn node, sum ->
        score = Map.get(scores, node, 0.0)
        sum + score * score
      end)

    if sum_squares > 0.0 do
      :math.sqrt(sum_squares)
    else
      0.0
    end
  end

  defp calculate_l2_difference(old_scores, new_scores, nodes) do
    sum_squares =
      Enum.reduce(nodes, 0.0, fn node, sum ->
        old_val = Map.get(old_scores, node, 0.0)
        new_val = Map.get(new_scores, node, 0.0)
        diff = new_val - old_val
        sum + diff * diff
      end)

    if sum_squares > 0.0 do
      :math.sqrt(sum_squares)
    else
      0.0
    end
  end

  # Katz centrality iteration
  defp iterate_katz(_graph, _nodes, scores, _alpha, _beta, max_iter, _tolerance, iter)
       when iter >= max_iter do
    scores
  end

  defp iterate_katz(graph, nodes, scores, alpha, beta, max_iter, tolerance, iter) do
    # Compute new scores: x_v = α * Σ x_u + β for neighbors u
    new_scores =
      Enum.reduce(nodes, %{}, fn node, acc ->
        neighbor_sum =
          get_in_neighbors(graph, node)
          |> Enum.reduce(0.0, fn neighbor, sum ->
            neighbor_score = Map.get(scores, neighbor, 0.0)
            sum + neighbor_score
          end)

        new_score = alpha * neighbor_sum + beta
        Map.put(acc, node, new_score)
      end)

    l1_diff = calculate_l1_norm_diff(scores, new_scores, nodes)

    if l1_diff < tolerance do
      new_scores
    else
      iterate_katz(graph, nodes, new_scores, alpha, beta, max_iter, tolerance, iter + 1)
    end
  end

  defp calculate_l1_norm_diff(old_scores, new_scores, nodes) do
    Enum.reduce(nodes, 0.0, fn node, sum ->
      old_val = Map.get(old_scores, node, 0.0)
      new_val = Map.get(new_scores, node, 0.0)
      diff = abs(new_val - old_val)
      sum + diff
    end)
  end

  # Alpha centrality iteration
  defp iterate_alpha(_graph, _nodes, scores, _alpha, max_iter, _tolerance, iter)
       when iter >= max_iter do
    scores
  end

  defp iterate_alpha(graph, nodes, scores, alpha, max_iter, tolerance, iter) do
    # Compute new scores: x_v = α * Σ x_u for neighbors u
    new_scores =
      Enum.reduce(nodes, %{}, fn node, acc ->
        neighbor_sum =
          get_in_neighbors(graph, node)
          |> Enum.reduce(0.0, fn neighbor, sum ->
            neighbor_score = Map.get(scores, neighbor, 0.0)
            sum + neighbor_score
          end)

        new_score = alpha * neighbor_sum
        Map.put(acc, node, new_score)
      end)

    l1_diff = calculate_l1_norm_diff(scores, new_scores, nodes)

    if l1_diff < tolerance do
      new_scores
    else
      iterate_alpha(graph, nodes, new_scores, alpha, max_iter, tolerance, iter + 1)
    end
  end
end
