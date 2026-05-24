defmodule Yog.Zog.Metrics do
  @moduledoc """
  Native graph metrics backed by Zog (Zig) via Zigler.

  These functions accept a `Yog.Builder.Zog` struct and return scalar
  measurements of graph structure.

  ## Requirements

  - `zigler` must be installed and available.
  - Zig compiler version **0.15.x** is required for zigler 0.15.2.

  ## Supported Metrics

  | Metric | Function | Range |
  |--------|----------|-------|
  | Density | `density/1` | `[0.0, 1.0]` |
  | Triangle Count | `triangle_count/1` | `non_neg_integer()` |
  | Avg Clustering Coefficient | `average_clustering_coefficient/1` | `[0.0, 1.0]` |
  | Local Clustering Coefficient | `local_clustering_coefficient/1` | `[0.0, 1.0]` |
  | Assortativity | `assortativity/1` | `[-1.0, 1.0]` |

  ## Example

      builder = Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      Yog.Zog.Metrics.density(builder)
      # => 1.0

      Yog.Zog.Metrics.triangle_count(builder)
      # => 1

  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      nifs: [
        ...,
        density: [concurrency: :dirty_cpu],
        triangle_count: [concurrency: :dirty_cpu],
        average_clustering_coefficient: [concurrency: :dirty_cpu],
        local_clustering_coefficient: [concurrency: :dirty_cpu],
        assortativity: [concurrency: :dirty_cpu]
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

    // =============================================================================
    // Density
    // =============================================================================

    /// Graph density: ratio of actual edges to possible edges.
    pub fn density(node_count: usize, from: []u32, to: []u32, weight: []f64) !f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        return zog.community.metrics.density(g);
    }

    // =============================================================================
    // Triangle Count
    // =============================================================================

    /// Number of triangles in the graph.
    pub fn triangle_count(node_count: usize, from: []u32, to: []u32, weight: []f64) !usize {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        return try zog.community.metrics.countTriangles(beam.allocator, g);
    }

    // =============================================================================
    // Clustering Coefficient
    // =============================================================================

    /// Average clustering coefficient across all nodes.
    pub fn average_clustering_coefficient(node_count: usize, from: []u32, to: []u32, weight: []f64) !f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        return try zog.community.metrics.averageClusteringCoefficient(beam.allocator, g);
    }

    /// Computes the local clustering coefficient for each node.
    pub fn local_clustering_coefficient(node_count: usize, from: []u32, to: []u32, weight: []f64) ![]f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var scores = try beam.allocator.alloc(f64, node_count);
        errdefer beam.allocator.free(scores);

        for (0..node_count) |i| {
            scores[i] = try zog.community.metrics.clusteringCoefficient(beam.allocator, g, @intCast(i));
        }

        return scores;
    }

    // =============================================================================
    // Assortativity
    // =============================================================================

    /// Degree assortativity coefficient.
    pub fn assortativity(node_count: usize, from: []u32, to: []u32, weight: []f64) !f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        return try zog.metrics.assortativity(beam.allocator, g);
    }
    """

    # ============================================================================
    # Public API
    # ============================================================================

    @doc """
    Computes graph density.

    For undirected graphs: `E / (V * (V - 1) / 2)`
    For directed graphs: `E / (V * (V - 1))`

    Returns a float in the range `[0.0, 1.0]`.
    """
    @spec density(Zog.t()) :: float()
    def density(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      density(node_count, from, to, weights)
    end

    @doc """
    Counts the number of triangles in the graph.

    A triangle is a set of three nodes where each node is connected to
    the other two.
    """
    @spec triangle_count(Zog.t()) :: non_neg_integer()
    def triangle_count(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      triangle_count(node_count, from, to, weights)
    end

    @doc """
    Computes the average clustering coefficient.

    Measures the degree to which nodes in a graph tend to cluster together.
    Returns a float in the range `[0.0, 1.0]`.
    """
    @spec average_clustering_coefficient(Zog.t()) :: float()
    def average_clustering_coefficient(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      average_clustering_coefficient(node_count, from, to, weights)
    end

    @doc """
    Computes degree assortativity.

    Measures the tendency for high-degree nodes to connect to other
    high-degree nodes.

    Returns a float in the range `[-1.0, 1.0]` where:
    - Positive: assortative (like connects to like)
    - Negative: disassortative (unlike connects to unlike)
    - Zero: neutral
    """
    @spec assortativity(Zog.t()) :: float()
    def assortativity(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)
      assortativity(node_count, from, to, weights)
    end

    @doc """
    Computes the local clustering coefficient for each node.

    Returns a map of `label => coefficient` where each value is in the
    range `[0.0, 1.0]`.
    """
    @spec local_clustering_coefficient(Zog.t()) :: %{
            Zog.label() => float()
          }
    def local_clustering_coefficient(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      scores = local_clustering_coefficient(node_count, from, to, weights)

      builder
      |> Zog.all_labels()
      |> Enum.zip(scores)
      |> Map.new()
    end
  else
    @moduledoc """
    Native graph metrics backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed. All functions will raise at runtime.
    """

    for fun <- [
          :density,
          :triangle_count,
          :average_clustering_coefficient,
          :local_clustering_coefficient,
          :assortativity
        ] do
      def unquote(fun)(_builder) do
        raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
      end
    end
  end
end
