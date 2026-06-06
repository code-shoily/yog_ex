defmodule Yog.Zog.Pathfinding do
  @moduledoc """
  Native pathfinding algorithms backed by Zog (Zig) via Zigler.

  These functions accept a `Yog.Builder.Zog` struct and return shortest-path
  distance matrices or individual paths, handling the index↔label mapping
  transparently.

  ## Requirements

  - `zigler` must be installed and available.
  - Zig compiler version **0.15.x** is required for zigler 0.15.2.

  ## Supported Algorithms

  | Algorithm | Function | Complexity |
  |-----------|----------|------------|
  | Floyd-Warshall | `floyd_warshall/1` | O(V³) |
  | Johnson's APSP | `johnsons/1` | O(V² log V + VE) |

  ## Example

      builder = Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("A", "C", 10.0)

      {:ok, matrix} = Yog.Zog.Pathfinding.floyd_warshall(builder)
      # => [[0.0, 1.0, 2.0], [Inf, 0.0, 1.0], [Inf, Inf, 0.0]]

  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      nifs: [
        ...,
        floyd_warshall: [concurrency: :dirty_cpu],
        johnsons: [concurrency: :dirty_cpu],
        nif_dijkstra: [concurrency: :dirty_cpu]
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

    fn extractMatrix(result: anytype, node_count: usize) !beam.term {
        const allocator = beam.allocator;
        var matrix = try allocator.alloc(f64, node_count * node_count);
        defer allocator.free(matrix);

        for (0..node_count) |i| {
            for (0..node_count) |j| {
                const val = result.get(@intCast(i), @intCast(j));
                matrix[i * node_count + j] = val orelse std.math.inf(f64);
            }
        }

        return beam.make(.{.ok, matrix}, .{});
    }

    // =============================================================================
    // Floyd-Warshall
    // =============================================================================

    /// All-pairs shortest paths using Floyd-Warshall.
    /// Returns `{:ok, matrix}` or `{:error, :negative_cycle}`.
    pub fn floyd_warshall(node_count: usize, from: []u32, to: []u32, weight: []f64) !beam.term {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = zog.pathfinding.floydWarshall(beam.allocator, g) catch |err| {
            if (err == error.NegativeCycle) {
                return beam.make(.{.@"error", .negative_cycle}, .{});
            }
            return err;
        };
        defer result.deinit();

        return extractMatrix(result, node_count);
    }

    // =============================================================================
    // Johnson's Algorithm
    // =============================================================================

    /// All-pairs shortest paths using Johnson's Algorithm.
    /// Returns `{:ok, matrix}` or `{:error, :negative_cycle}`.
    pub fn johnsons(node_count: usize, from: []u32, to: []u32, weight: []f64) !beam.term {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        var result = zog.pathfinding.johnsonsGeneric(
            beam.allocator,
            g,
            f64,
            0.0,
            zog.utils.addF64,
            zog.utils.subF64,
            zog.utils.compareF64,
        ) catch |err| {
            if (err == error.NegativeCycle) {
                return beam.make(.{.@"error", .negative_cycle}, .{});
            }
            return err;
        };
        defer result.deinit();

        return extractMatrix(result, node_count);
    }

    // =============================================================================
    // Dijkstra's Algorithm
    // =============================================================================

    /// Point-to-point shortest path using Dijkstra's Algorithm.
    /// Returns `{:ok, {path, weight}}` or `{:error, :no_path}`.
    pub fn nif_dijkstra(
        node_count: usize,
        from: []u32,
        to: []u32,
        weight: []f64,
        start_node: u32,
        goal_node: u32,
    ) !beam.term {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        const opt_res = zog.pathfinding.dijkstra(beam.allocator, g, start_node, goal_node) catch |err| {
            return err;
        };

        if (opt_res) |res| {
            var path_res = res;
            defer path_res.deinit(beam.allocator);

            const path_slice = try beam.allocator.alloc(u32, path_res.path.items.len);
            @memcpy(path_slice, path_res.path.items);

            return beam.make(.{.ok, .{path_slice, path_res.weight}}, .{});
        } else {
            return beam.make(.{.@"error", .no_path}, .{});
        }
    }
    """

    # ============================================================================
    # Public API
    # ============================================================================

    @doc """
    Computes all-pairs shortest paths using the Floyd-Warshall algorithm via the native Zog backend.

    The Floyd-Warshall algorithm computes shortest paths between all pairs of nodes
    in a single execution using dynamic programming.

    **Time Complexity:** O(V³)

    ## Interpreting All-Pairs Shortest Paths

    The result is returned as `{:ok, distance_matrix}` where the matrix is structured as
    a list of lists. Unreachable pairs are represented as `:infinity`.

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 2.0)
        iex> {:ok, matrix} = Yog.Zog.Pathfinding.floyd_warshall(builder)
        iex> matrix
        [[0.0, 1.0, 3.0], [:infinity, 0.0, 2.0], [:infinity, :infinity, 0.0]]
    """
    @spec floyd_warshall(Zog.t()) ::
            {:ok, [[float() | :infinity]]} | {:error, :negative_cycle}
    def floyd_warshall(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      case floyd_warshall(node_count, from, to, weights) do
        {:ok, flat_matrix} ->
          matrix =
            if node_count == 0 do
              []
            else
              flat_matrix
              |> Enum.chunk_every(node_count)
              |> Enum.map(& &1)
            end

          {:ok, matrix}

        {:error, :negative_cycle} ->
          {:error, :negative_cycle}
      end
    end

    @doc """
    Computes all-pairs shortest paths using Johnson's Algorithm via the native Zog backend.

    More efficient than Floyd-Warshall for sparse graphs. Combines Bellman-Ford
    and Dijkstra's algorithms with a reweighting technique to handle negative edge weights.

    **Time Complexity:** O(V² log V + VE)

    ## Interpreting All-Pairs Shortest Paths

    The result is returned as `{:ok, distance_matrix}` where the matrix is structured as
    a list of lists. Unreachable pairs are represented as `:infinity`.

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 2.0)
        iex> {:ok, matrix} = Yog.Zog.Pathfinding.johnsons(builder)
        iex> matrix
        [[0.0, 1.0, 3.0], [:infinity, 0.0, 2.0], [:infinity, :infinity, 0.0]]
    """
    @spec johnsons(Zog.t()) ::
            {:ok, [[float() | :infinity]]} | {:error, :negative_cycle}
    def johnsons(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      case johnsons(node_count, from, to, weights) do
        {:ok, flat_matrix} ->
          matrix =
            if node_count == 0 do
              []
            else
              flat_matrix
              |> Enum.chunk_every(node_count)
              |> Enum.map(& &1)
            end

          {:ok, matrix}

        {:error, :negative_cycle} ->
          {:error, :negative_cycle}
      end
    end

    @doc """
    Computes the shortest path and its weight between two nodes using Dijkstra's algorithm via the native Zog backend.

    **Time Complexity:** O((V + E) log V)

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("A", "B", 1.0)
        ...>   |> Zog.add_edge("B", "C", 2.0)
        ...>   |> Zog.add_edge("A", "C", 10.0)
        iex> Yog.Zog.Pathfinding.dijkstra(builder, "A", "C")
        {:ok, {["A", "B", "C"], 3.0}}
    """
    @spec dijkstra(Zog.t(), Zog.label(), Zog.label()) ::
            {:ok, {[Zog.label()], float()}} | {:error, :no_path}
    def dijkstra(%Yog.Builder.Zog{} = builder, start_label, goal_label) do
      start_id = Map.get(builder.label_to_id, start_label)
      goal_id = Map.get(builder.label_to_id, goal_label)

      if is_nil(start_id) or is_nil(goal_id) do
        {:error, :no_path}
      else
        node_count = Zog.node_count(builder)
        {from, to, weights} = Zog.to_edge_arrays(builder)

        case nif_dijkstra(node_count, from, to, weights, start_id, goal_id) do
          {:ok, {path_ids, weight}} ->
            path_labels = Enum.map(path_ids, &Zog.id_to_label(builder, &1))
            {:ok, {path_labels, weight}}

          {:error, :no_path} ->
            {:error, :no_path}
        end
      end
    end
  else
    @moduledoc """
    Native pathfinding algorithms backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed. All functions will raise at runtime.
    """

    for fun <- [:floyd_warshall, :johnsons] do
      def unquote(fun)(_builder) do
        raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
      end
    end

    def dijkstra(_builder, _start_label, _goal_label) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end
  end
end
