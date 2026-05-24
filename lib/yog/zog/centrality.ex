defmodule Yog.Zog.Centrality do
  @moduledoc """
  Native centrality algorithms backed by Zog (Zig) via Zigler.

  These functions accept a `Yog.Builder.Zog` struct and return maps of
  `label => score`, handling the index↔label mapping transparently.

  ## Requirements

  - `zigler` must be installed and available.
  - Zig compiler version **0.15.x** is required for zigler 0.15.2.

  ## Supported Algorithms

  | Algorithm | Function | Weighted? |
  |-----------|----------|-----------|
  | Betweenness (unweighted) | `betweenness_unweighted/1` | No |
  | Betweenness (f64) | `betweenness_f64/1` | Yes |
  | Closeness (f64) | `closeness_f64/1` | Yes |
  | Harmonic Centrality (f64) | `harmonic_centrality_f64/1` | Yes |
  | PageRank | `pagerank/2` | No |
  | Eigenvector | `eigenvector/2` | No |
  | Katz | `katz/2` | No |
  | Alpha Centrality | `alpha_centrality/2` | No |

  ## Example

      builder = Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      Yog.Zog.Centrality.betweenness_unweighted(builder)
      # => %{"A" => 0.0, "B" => 1.0, "C" => 0.0}

  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      nifs: [
        ...,
        betweenness_unweighted: [concurrency: :dirty_cpu],
        betweenness_f64: [concurrency: :dirty_cpu],
        closeness_f64: [concurrency: :dirty_cpu],
        harmonic_centrality_f64: [concurrency: :dirty_cpu],
        pagerank: [concurrency: :dirty_cpu],
        eigenvector: [concurrency: :dirty_cpu],
        katz: [concurrency: :dirty_cpu],
        alpha_centrality: [concurrency: :dirty_cpu]
      ]

    ~Z"""
    const std = @import("std");
    const beam = @import("beam");
    const zog = @import("zog");

    const ArrayGraph = zog.models.ArrayGraph;

    // =============================================================================
    // Helpers
    // =============================================================================

    fn buildGraph(node_count: usize, from: []u32, to: []u32, weight: []f64) !ArrayGraph(void, f64) {
        const allocator = beam.allocator;
        var g = ArrayGraph(void, f64).init(allocator);
        errdefer g.deinit();

        try g.nodes.ensureTotalCapacity(allocator, node_count);
        try g.edges.ensureTotalCapacity(allocator, from.len);

        for (0..node_count) |_| {
            _ = try g.addNode({});
        }

        for (from, to, weight) |f, t, w| {
            _ = try g.addEdge(f, t, w);
        }

        return g;
    }

    fn extractScores(result: anytype, node_count: usize) ![]f64 {
        const allocator = beam.allocator;
        var scores = try allocator.alloc(f64, node_count);
        errdefer allocator.free(scores);

        for (0..node_count) |i| {
            scores[i] = result.get(@intCast(i));
        }

        return scores;
    }

    // =============================================================================
    // Betweenness Centrality
    // =============================================================================

    /// Unweighted betweenness centrality (Brandes' algorithm).
    pub fn betweenness_unweighted(node_count: usize, from: []u32, to: []u32) ![]f64 {
        const allocator = beam.allocator;
        var g = ArrayGraph(void, f64).init(allocator);
        defer g.deinit();

        try g.nodes.ensureTotalCapacity(allocator, node_count);
        try g.edges.ensureTotalCapacity(allocator, from.len);

        for (0..node_count) |_| { _ = try g.addNode({}); }
        for (from, to) |f, t| { _ = try g.addEdge(f, t, 1.0); }

        var result = try zog.centrality.betweennessUnweighted(allocator, g);
        defer result.deinit();

        return extractScores(result, node_count);
    }

    /// Weighted betweenness centrality for f64 weights.
    pub fn betweenness_f64(node_count: usize, from: []u32, to: []u32, weight: []f64) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.betweennessF64(beam.allocator, g);
        defer result.deinit();

        return extractScores(result, node_count);
    }

    // =============================================================================
    // Closeness & Harmonic Centrality
    // =============================================================================

    /// Closeness centrality for f64 weights.
    /// Returns 0.0 for nodes that cannot reach all other nodes.
    pub fn closeness_f64(node_count: usize, from: []u32, to: []u32, weight: []f64) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.closenessF64(beam.allocator, g);
        defer result.deinit();

        return extractScores(result, node_count);
    }

    /// Harmonic centrality for f64 weights.
    /// Handles disconnected graphs gracefully.
    pub fn harmonic_centrality_f64(node_count: usize, from: []u32, to: []u32, weight: []f64) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.harmonicCentralityF64(beam.allocator, g);
        defer result.deinit();

        return extractScores(result, node_count);
    }

    // =============================================================================
    // PageRank
    // =============================================================================

    /// PageRank centrality.
    pub fn pagerank(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        damping: f64,
        max_iterations: usize,
        tolerance: f64,
    ) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.pagerank(beam.allocator, g, .{
            .damping = damping,
            .max_iterations = max_iterations,
            .tolerance = tolerance,
        });
        defer result.deinit();

        return extractScores(result, node_count);
    }

    // =============================================================================
    // Eigenvector Centrality
    // =============================================================================

    /// Eigenvector centrality using power iteration.
    pub fn eigenvector(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        max_iterations: usize,
        tolerance: f64,
    ) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.eigenvector(beam.allocator, g, max_iterations, tolerance);
        defer result.deinit();

        return extractScores(result, node_count);
    }

    // =============================================================================
    // Katz Centrality
    // =============================================================================

    /// Katz centrality.
    pub fn katz(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        alpha: f64,
        beta: f64,
        max_iterations: usize,
        tolerance: f64,
    ) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.katz(beam.allocator, g, alpha, beta, max_iterations, tolerance);
        defer result.deinit();

        return extractScores(result, node_count);
    }

    // =============================================================================
    // Alpha Centrality
    // =============================================================================

    /// Alpha centrality.
    pub fn alpha_centrality(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        alpha: f64,
        initial: f64,
        max_iterations: usize,
        tolerance: f64,
    ) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.centrality.alphaCentrality(beam.allocator, g, alpha, initial, max_iterations, tolerance);
        defer result.deinit();

        return extractScores(result, node_count);
    }
    """

    # ============================================================================
    # Public API
    # ============================================================================

    @doc """
    Calculates unweighted Betweenness Centrality for all nodes using the native Zog backend.

    Betweenness centrality of a node v is the sum of the fraction of
    all-pairs shortest paths that pass through v.

    **Time Complexity:** O(VE)

    ## Interpreting Betweenness Centrality

    | Value | Meaning |
    |-------|---------|
    | **High** | The node is a bridge or gatekeeper — many shortest paths go through it |
    | **Low** | The node is peripheral — most paths bypass it |
    | `0.0` | The node lies on no shortest paths between any other pair |

    A high betweenness node is critical for network connectivity:
    removing it can fragment the graph or severely increase path lengths.

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.undirected()
        ...>   |> Zog.add_edge("Broker", "A1", 1)
        ...>   |> Zog.add_edge("Broker", "A2", 1)
        ...>   |> Zog.add_edge("Broker", "A3", 1)
        ...>   |> Zog.add_edge("A1", "A2", 1)
        ...>   |> Zog.add_edge("A2", "A3", 1)
        ...>   |> Zog.add_edge("A3", "A1", 1)
        ...>   |> Zog.add_edge("Broker", "B1", 1)
        ...>   |> Zog.add_edge("Broker", "B2", 1)
        ...>   |> Zog.add_edge("Broker", "B3", 1)
        ...>   |> Zog.add_edge("B1", "B2", 1)
        ...>   |> Zog.add_edge("B2", "B3", 1)
        ...>   |> Zog.add_edge("B3", "B1", 1)
        iex> scores = Yog.Zog.Centrality.betweenness_unweighted(builder)
        iex> scores["Broker"] > scores["A1"]
        true
    """
    @spec betweenness_unweighted(Zog.t()) :: %{Zog.label() => float()}
    def betweenness_unweighted(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, _weights} = Zog.to_edge_arrays(builder)
      raw_scores = betweenness_unweighted(node_count, from, to)
      scores = maybe_scale_undirected(builder, raw_scores)
      map_scores(builder, scores)
    end

    @doc """
    Calculates weighted Betweenness Centrality for all nodes using the native Zog backend.

    Edge weights are used as distances for shortest-path computation.

    **Time Complexity:** O(VE + V²logV)

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 1.0)
        iex> scores = Yog.Zog.Centrality.betweenness_f64(builder)
        iex> scores["B"] |> Float.round(3)
        1.0
    """
    @spec betweenness_f64(Zog.t()) :: %{Zog.label() => float()}
    def betweenness_f64(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      raw_scores = betweenness_f64(node_count, from, to, weights)
      scores = maybe_scale_undirected(builder, raw_scores)
      map_scores(builder, scores)
    end

    @doc """
    Calculates Closeness Centrality for all nodes using the native Zog backend.

    Closeness centrality measures how close a node is to all other nodes
    in the graph. It is calculated as the reciprocal of the sum of the
    shortest path distances from the node to all other nodes.

    Formula: C(v) = (n - 1) / Σ d(v, u) for all u ≠ v

    Note: In disconnected graphs, nodes that cannot reach all other nodes
    will have a centrality of 0.0. Consider `harmonic_centrality_f64/1` for disconnected graphs.

    **Time Complexity:** O(V * (V + E) log V) using Dijkstra from each node

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.undirected()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 1.0)
        ...>   |> Zog.add_edge("C", "A", 1.0)
        iex> scores = Yog.Zog.Centrality.closeness_f64(builder)
        iex> scores["A"] |> Float.round(3)
        1.0
    """
    @spec closeness_f64(Zog.t()) :: %{Zog.label() => float()}
    def closeness_f64(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      scores = closeness_f64(node_count, from, to, weights)
      map_scores(builder, scores)
    end

    @doc """
    Calculates Harmonic Centrality for all nodes using the native Zog backend.

    Harmonic centrality is a variation of closeness centrality that handles
    disconnected graphs gracefully. It sums the reciprocals of the shortest
    path distances from a node to all reachable nodes.

    Formula: H(v) = Σ (1 / d(v, u)) / (n - 1) for all u ≠ v

    **Time Complexity:** O(V * (V + E) log V)

    ## Example

         iex> alias Yog.Builder.Zog
         iex> builder = Zog.undirected()
         ...>   |> Zog.add_edge("Center", "A", 1.0)
         ...>   |> Zog.add_edge("Center", "B", 1.0)
         iex> scores = Yog.Zog.Centrality.harmonic_centrality_f64(builder)
         iex> scores["Center"] |> Float.round(3)
         1.0
    """
    @spec harmonic_centrality_f64(Zog.t()) :: %{Zog.label() => float()}
    def harmonic_centrality_f64(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      scores = harmonic_centrality_f64(node_count, from, to, weights)
      map_scores(builder, scores)
    end

    @doc """
    Calculates PageRank centrality for all nodes using the native Zog backend.

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

    ## Options

    - `:damping` — Damping factor (default: `0.85`).
    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 1.0)
        iex> scores = Yog.Zog.Centrality.pagerank(builder)
        iex> # Scores should sum to approximately 1.0
        iex> Enum.sum(Map.values(scores)) |> Float.round(2)
        1.0
        iex> # With custom options
        iex> scores = Yog.Zog.Centrality.pagerank(builder, damping: 0.9, max_iterations: 50, tolerance: 0.001)
        iex> map_size(scores)
        3
    """
    @spec pagerank(Zog.t(), keyword()) :: %{Zog.label() => float()}
    def pagerank(%Yog.Builder.Zog{} = builder, opts \\ []) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      damping = Keyword.get(opts, :damping, 0.85)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = pagerank(node_count, from, to, weights, damping, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    @doc """
    Calculates Eigenvector Centrality for all nodes using the native Zog backend.

    Eigenvector centrality measures a node's influence based on the centrality
    of its neighbors. A node is important if it is connected to other important
    nodes. Uses power iteration to converge on the principal eigenvector.

    **Time Complexity:** O(max_iterations * (V + E))

    ## Options

    - `:max_iterations` — Maximum number of power iterations (default: `100`).
    - `:tolerance` — Convergence threshold for L2 norm (default: `0.0001`).

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.undirected()
        ...>   |> Zog.add_edge("center", "A", 1.0)
        ...>   |> Zog.add_edge("center", "B", 1.0)
        iex> scores = Yog.Zog.Centrality.eigenvector(builder)
        iex> scores["center"] > scores["A"]
        true
    """
    @spec eigenvector(Zog.t(), keyword()) :: %{Zog.label() => float()}
    def eigenvector(%Yog.Builder.Zog{} = builder, opts \\ []) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = eigenvector(node_count, from, to, weights, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    @doc """
    Calculates Katz Centrality for all nodes using the native Zog backend.

    Katz centrality is a variant of eigenvector centrality that adds an
    attenuation factor (alpha) to prevent the infinite accumulation of
    centrality in cycles. It also includes a constant term (beta) to give
    every node some base centrality.

    Formula: C(v) = α * Σ C(u) + β for all neighbors u

    **Time Complexity:** O(max_iterations * (V + E))

    ## Options

    - `:alpha` — Attenuation factor (default: `0.1`).
    - `:beta` — Initial score / bias (default: `1.0`).
    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.undirected()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 1.0)
        ...>   |> Zog.add_edge("C", "A", 1.0)
        iex> scores = Yog.Zog.Centrality.katz(builder, alpha: 0.1, beta: 1.0)
        iex> # All scores should be >= beta
        iex> scores["A"] >= 1.0
        true
    """
    @spec katz(Zog.t(), keyword()) :: %{Zog.label() => float()}
    def katz(%Yog.Builder.Zog{} = builder, opts \\ []) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      alpha = Keyword.get(opts, :alpha, 0.1)
      beta = Keyword.get(opts, :beta, 1.0)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = katz(node_count, from, to, weights, alpha, beta, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    @doc """
    Calculates Alpha Centrality for all nodes using the native Zog backend.

    Alpha centrality is a generalization of Katz centrality for directed
    graphs. It measures the total number of paths from a node, weighted
    by path length with attenuation factor alpha.

    Unlike Katz, alpha centrality does not include a constant beta term
    and is particularly useful for analyzing influence in directed networks.

    **Time Complexity:** O(max_iterations * (V + E))

    ## Options

    - `:alpha` — Attenuation factor (default: `0.5`).
    - `:initial` — Initial score for all nodes (default: `1.0`).
    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("A", "C", 1.0)
        ...>   |> Zog.add_edge("B", "C", 1.0)
        iex> scores = Yog.Zog.Centrality.alpha_centrality(builder, alpha: 0.3, initial: 1.0)
        iex> map_size(scores)
        3
    """
    @spec alpha_centrality(Zog.t(), keyword()) :: %{
            Zog.label() => float()
          }
    def alpha_centrality(%Yog.Builder.Zog{} = builder, opts \\ []) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      alpha = Keyword.get(opts, :alpha, 0.5)
      initial = Keyword.get(opts, :initial, 1.0)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores =
        alpha_centrality(node_count, from, to, weights, alpha, initial, max_iterations, tolerance)

      map_scores(builder, scores)
    end

    # ============================================================================
    # Private Helpers
    # ============================================================================

    defp map_scores(builder, scores) do
      builder
      |> Zog.all_labels()
      |> Enum.zip(scores)
      |> Map.new()
    end

    defp maybe_scale_undirected(%Yog.Builder.Zog{kind: :undirected}, scores) do
      Enum.map(scores, fn score -> score * 0.5 end)
    end

    defp maybe_scale_undirected(_, scores), do: scores
  else
    @moduledoc """
    Native centrality algorithms backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed. All functions will raise at runtime.
    """

    for fun <- [
          :betweenness_unweighted,
          :betweenness_f64,
          :closeness_f64,
          :harmonic_centrality_f64,
          :pagerank,
          :eigenvector,
          :katz,
          :alpha_centrality
        ] do
      def unquote(fun)(_builder, _opts \\ []) do
        raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
      end
    end
  end
end
