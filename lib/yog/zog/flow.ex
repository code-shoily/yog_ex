defmodule Yog.Zog.Flow do
  @moduledoc """
  Native network flow and cut algorithms backed by Zog (Zig) via Zigler.

  These algorithms leverage native flat memory models in Zig to compute maximum flow
  and extract minimum s-t cuts at high performance.
  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      nifs: [
        edmonds_karp_f64: [concurrency: :dirty_cpu],
        global_min_cut_f64: [concurrency: :dirty_cpu],
        push_relabel_f64: [concurrency: :dirty_cpu]
      ]

    ~Z"""
    const std = @import("std");
    const beam = @import("beam");
    const zog = @import("zog");

    const FlowNifResult = struct {
        max_flow: f64,
        residual_from: []u32,
        residual_to: []u32,
        residual_cap: []f64,
        source_side: []u32,
        sink_side: []u32,
    };

    fn buildGraph(
        allocator: std.mem.Allocator,
        node_count: usize,
        from: []u32,
        to: []u32,
        capacity: []f64,
    ) !zog.models.ArrayGraph(void, f64) {
        const ArrayGraph = zog.models.ArrayGraph;
        var g = ArrayGraph(void, f64).init(allocator);
        errdefer g.deinit();

        try g.nodes.ensureTotalCapacity(allocator, node_count);
        try g.edges.ensureTotalCapacity(allocator, from.len);

        for (0..node_count) |_| {
            _ = try g.addNode({});
        }

        for (from, to, capacity) |f, t, w| {
            _ = try g.addEdge(f, t, w);
        }

        return g;
    }

    fn toFlowNifResult(
        allocator: std.mem.Allocator,
        max_flow: f64,
        residual: anytype,
        source_side: []u32,
        sink_side: []u32,
    ) !FlowNifResult {
        const res_count = residual.count();
        var res_from = try allocator.alloc(u32, res_count);
        errdefer allocator.free(res_from);
        var res_to = try allocator.alloc(u32, res_count);
        errdefer allocator.free(res_to);
        var res_cap = try allocator.alloc(f64, res_count);
        errdefer allocator.free(res_cap);

        var it = residual.iterator();
        var idx: usize = 0;
        while (it.next()) |entry| {
            res_from[idx] = entry.key_ptr.from;
            res_to[idx] = entry.key_ptr.to;
            res_cap[idx] = entry.value_ptr.*;
            idx += 1;
        }

        const ss = try allocator.alloc(u32, source_side.len);
        errdefer allocator.free(ss);
        @memcpy(ss, source_side);

        const sk = try allocator.alloc(u32, sink_side.len);
        errdefer allocator.free(sk);
        @memcpy(sk, sink_side);

        return .{
            .max_flow = max_flow,
            .residual_from = res_from,
            .residual_to = res_to,
            .residual_cap = res_cap,
            .source_side = ss,
            .sink_side = sk,
        };
    }

    pub fn edmonds_karp_f64(
        node_count: usize,
        from: []u32,
        to: []u32,
        capacity: []f64,
        source: u32,
        sink: u32,
    ) !FlowNifResult {
        const allocator = beam.allocator;
        var g = try buildGraph(allocator, node_count, from, to, capacity);
        defer g.deinit();

        var result = try zog.flow.max_flow.edmondsKarpF64(allocator, g, source, sink);
        defer result.deinit(allocator);

        var cut = try zog.flow.max_flow.minCut(allocator, result, f64, 0.0, zog.utils.compareF64);
        defer cut.deinit(allocator);

        return try toFlowNifResult(allocator, result.max_flow, result.residual, cut.source_side, cut.sink_side);
    }

    pub fn push_relabel_f64(
        node_count: usize,
        from: []u32,
        to: []u32,
        capacity: []f64,
        source: u32,
        sink: u32,
    ) !FlowNifResult {
        const allocator = beam.allocator;
        var g = try buildGraph(allocator, node_count, from, to, capacity);
        defer g.deinit();

        var result = try zog.flow.max_flow.pushRelabelF64(allocator, g, source, sink);
        defer result.deinit(allocator);

        var cut = try zog.flow.max_flow.minCut(allocator, result, f64, 0.0, zog.utils.compareF64);
        defer cut.deinit(allocator);

        return try toFlowNifResult(allocator, result.max_flow, result.residual, cut.source_side, cut.sink_side);
    }

    const MinCutNifResult = struct {
        cut_value: f64,
        source_side: []u32,
        sink_side: []u32,
    };

    pub fn global_min_cut_f64(
        node_count: usize,
        from: []u32,
        to: []u32,
        capacity: []f64,
    ) !MinCutNifResult {
        const allocator = beam.allocator;
        const ArrayGraph = zog.models.ArrayGraph;

        var g = ArrayGraph(void, f64).init(allocator);
        defer g.deinit();

        try g.nodes.ensureTotalCapacity(allocator, node_count);
        try g.edges.ensureTotalCapacity(allocator, from.len);

        for (0..node_count) |_| {
            _ = try g.addNode({});
        }

        for (from, to, capacity) |f, t, w| {
            _ = try g.addEdge(f, t, w);
        }

        const result = try zog.flow.min_cut.globalMinCutF64(allocator, g);

        return .{
            .cut_value = result.weight,
            .source_side = result.group_a,
            .sink_side = result.group_b,
        };
    }
    """

    @doc """
    Computes the maximum flow and minimum cut from source to sink in the network using the native Zog backend.

    Supports `:edmonds_karp` and `:push_relabel` algorithms.

    **Time Complexity:** O(VE²) for Edmonds-Karp, O(V²E) for Push-Relabel.

    ## Returns

    A map with the following keys:
    - `:max_flow` — The float value of the maximum flow.
    - `:residual_graph` — A directed `Yog.Graph` representing the remaining edge capacities.
    - `:source_side` — List of original user node labels reachable from the source in the residual graph.
    - `:sink_side` — List of original user node labels not reachable from the source.

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.directed()
        ...>   |> Zog.add_edge("s", "a", 10.0)
        ...>   |> Zog.add_edge("a", "t", 5.0)
        iex> result = Yog.Zog.Flow.max_flow(builder, "s", "t", :push_relabel)
        iex> result.max_flow
        5.0
        iex> "s" in result.source_side
        true
        iex> "t" in result.sink_side
        true
    """
    @spec max_flow(Zog.t(), Zog.label(), Zog.label(), atom()) ::
            %{
              max_flow: float(),
              residual_graph: Yog.Graph.t(),
              source_side: list(Zog.label()),
              sink_side: list(Zog.label())
            }
    def max_flow(%Yog.Builder.Zog{} = builder, source, sink, algorithm \\ :edmonds_karp) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      source_idx = Zog.label_to_id(builder, source)
      sink_idx = Zog.label_to_id(builder, sink)

      if is_nil(source_idx) or is_nil(sink_idx) do
        raise ArgumentError, "source or sink node not found in graph"
      end

      result =
        case algorithm do
          :push_relabel ->
            push_relabel_f64(node_count, from, to, weights, source_idx, sink_idx)

          _ ->
            edmonds_karp_f64(node_count, from, to, weights, source_idx, sink_idx)
        end

      source_side = Enum.map(result.source_side, &Zog.id_to_label(builder, &1))
      sink_side = Enum.map(result.sink_side, &Zog.id_to_label(builder, &1))

      residual_graph =
        Enum.zip([result.residual_from, result.residual_to, result.residual_cap])
        |> Enum.reduce(Yog.directed(), fn {f_idx, t_idx, cap}, g ->
          f_lbl = Zog.id_to_label(builder, f_idx)
          t_lbl = Zog.id_to_label(builder, t_idx)
          Yog.add_edge_ensure(g, f_lbl, t_lbl, cap)
        end)

      %{
        max_flow: result.max_flow,
        residual_graph: residual_graph,
        source_side: source_side,
        sink_side: sink_side
      }
    end

    @doc """
    Computes the global minimum cut of an undirected weighted network using the Stoer-Wagner algorithm via the native Zog backend.

    **Time Complexity:** O(V³) (with priority queue optimizations)

    ## Returns

    A map with the following keys:
    - `:cut_value` — The total weight of the minimum cut.
    - `:source_side` — List of original user node labels in the first partition.
    - `:sink_side` — List of original user node labels in the second partition.

    ## Example

        iex> alias Yog.Builder.Zog
        iex> builder = Zog.undirected()
        ...>   |> Zog.add_edge("a1", "a2", 10.0)
        ...>   |> Zog.add_edge("b1", "b2", 10.0)
        ...>   |> Zog.add_edge("a2", "b1", 2.0)
        iex> result = Yog.Zog.Flow.global_min_cut(builder)
        iex> result.cut_value
        2.0
    """
    @spec global_min_cut(Zog.t()) :: %{
            cut_value: float(),
            source_side: list(Zog.label()),
            sink_side: list(Zog.label())
          }
    def global_min_cut(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      result = global_min_cut_f64(node_count, from, to, weights)

      source_side = Enum.map(result.source_side, &Zog.id_to_label(builder, &1))
      sink_side = Enum.map(result.sink_side, &Zog.id_to_label(builder, &1))

      %{
        cut_value: result.cut_value,
        source_side: source_side,
        sink_side: sink_side
      }
    end
  else
    @moduledoc """
    Native network flow and cut algorithms backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed. All functions will raise at runtime.
    """

    def max_flow(_builder, _source, _sink, _algorithm \\ :edmonds_karp) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end

    def global_min_cut(_builder) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end
  end
end
