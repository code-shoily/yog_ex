defmodule Yog.Zog.Community do
  @moduledoc """
  Native community detection algorithms backed by Zog (Zig) via Zigler.

  These functions accept a `Yog.Builder.Zog` struct and return community
  assignments as maps of `label => community_id`, handling the index↔label
  mapping transparently.

  ## Requirements

  - `zigler` must be installed and available.
  - Zig compiler version **0.15.x** is required for zigler 0.15.2.

  ## Supported Algorithms

  | Algorithm | Function | Weighted? |
  |-----------|----------|-----------|
  | Louvain | `louvain/2` | Yes |
  | Modularity | `modularity/2` | Yes |

  ## Example

      builder = Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      Yog.Zog.Community.louvain(builder)
      # => %{"A" => 0, "B" => 0, "C" => 0}

  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      nifs: [
        ...,
        louvain: [concurrency: :dirty_cpu],
        leiden: [concurrency: :dirty_cpu],
        modularity_f64: [concurrency: :dirty_cpu]
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



    fn extractAssignments(result: anytype, node_count: usize) ![]usize {
        const allocator = beam.allocator;
        var assignments = try allocator.alloc(usize, node_count);
        errdefer allocator.free(assignments);

        for (0..node_count) |i| {
            assignments[i] = result.assignments.get(@intCast(i)) orelse 0;
        }

        return assignments;
    }

    // =============================================================================
    // Louvain
    // =============================================================================

    /// Louvain community detection for weighted graphs.
    pub fn louvain(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        min_modularity_gain: f64,
        max_iterations: usize,
        seed: u64,
    ) ![]usize {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.community.louvain.detectWeightedWithOptions(
            beam.allocator,
            g,
            .{
                .min_modularity_gain = min_modularity_gain,
                .max_iterations = max_iterations,
                .seed = seed,
            },
            zog.utils.identityF64,
        );
        defer result.deinit();

        return extractAssignments(result, node_count);
    }

    // =============================================================================
    // Leiden
    // =============================================================================

    /// Leiden community detection for weighted graphs.
    pub fn leiden(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        min_modularity_gain: f64,
        max_iterations: usize,
        seed: u64,
        theta: f64,
    ) ![]usize {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = try zog.community.leiden.detectWeightedWithOptions(
            beam.allocator,
            g,
            .{
                .min_modularity_gain = min_modularity_gain,
                .max_iterations = max_iterations,
                .seed = seed,
                .theta = theta,
            },
            zog.utils.identityF64,
        );
        defer result.deinit();

        return extractAssignments(result, node_count);
    }

    // =============================================================================
    // Modularity
    // =============================================================================

    /// Computes modularity for a given community partition.
    pub fn modularity_f64(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        assignments: []usize,
    ) !f64 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var map = std.AutoHashMap(u32, usize).init(beam.allocator);
        defer map.deinit();

        for (assignments, 0..) |comm, i| {
            try map.put(@intCast(i), comm);
        }

        return try zog.community.metrics.modularity(beam.allocator, g, map, zog.utils.identityF64);
    }
    """

    # ============================================================================
    # Public API
    # ============================================================================

    @doc """
    Detects communities using the Louvain algorithm.

    ## Options

    - `:min_modularity_gain` — Stop moving nodes when the best modularity gain
      is below this threshold (default: `0.000001`).
    - `:max_iterations` — Maximum iterations per phase (default: `100`).
    - `:seed` — Random seed for node shuffling (default: `42`).

    Returns a map of `label => community_id`.
    """
    @spec louvain(Zog.t(), keyword()) :: %{
            Zog.label() => non_neg_integer()
          }
    def louvain(%Yog.Builder.Zog{} = builder, opts \\ []) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      seed = Keyword.get(opts, :seed, 42)

      assignments =
        louvain(node_count, from, to, weights, min_modularity_gain, max_iterations, seed)

      map_assignments(builder, assignments)
    end

    @doc """
    Detects communities using the Leiden algorithm.

    ## Options

    - `:min_modularity_gain` — Stop moving nodes when the best modularity gain
      is below this threshold (default: `0.000001`).
    - `:max_iterations` — Maximum iterations per phase (default: `100`).
    - `:seed` — Random seed for node shuffling and probabilistic moves (default: `42`).
    - `:theta` — Temperature parameter for the probabilistic refinement phase (default: `1.0`).

    Returns a map of `label => community_id`.
    """
    @spec leiden(Zog.t(), keyword()) :: %{
            Zog.label() => non_neg_integer()
          }
    def leiden(%Yog.Builder.Zog{} = builder, opts \\ []) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      seed = Keyword.get(opts, :seed, 42)
      theta = Keyword.get(opts, :theta, 1.0)

      assignments =
        leiden(node_count, from, to, weights, min_modularity_gain, max_iterations, seed, theta)

      map_assignments(builder, assignments)
    end

    @doc """
    Computes the modularity of a given community partition.

    Accepts a builder and a map of `label => community_id` (as returned by
    `louvain/2`).

    Returns a float in the range `[-0.5, 1.0]`.
    """
    @spec modularity(Zog.t(), %{Zog.label() => non_neg_integer()}) ::
            float()
    def modularity(%Yog.Builder.Zog{} = builder, community_map) when is_map(community_map) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      assignments =
        builder
        |> Zog.all_labels()
        |> Enum.with_index()
        |> Enum.map(fn {label, _idx} ->
          Map.get(community_map, label, 0)
        end)

      modularity_f64(node_count, from, to, weights, assignments)
    end

    # ============================================================================
    # Private Helpers
    # ============================================================================

    defp map_assignments(builder, assignments) do
      builder
      |> Zog.all_labels()
      |> Enum.zip(assignments)
      |> Map.new()
    end
  else
    @moduledoc """
    Native community detection algorithms backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed. All functions will raise at runtime.
    """

    for fun <- [
          :louvain,
          :modularity
        ] do
      def unquote(fun)(_builder, _opts \\ []) do
        raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
      end
    end
  end
end
