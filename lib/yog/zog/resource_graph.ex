defmodule Yog.Zog.ResourceGraph do
  @moduledoc """
  Native graph resource backed by Zog (Zig) via Zigler.

  Unlike the Copy-In/Copy-Out pattern, `ResourceGraph` keeps the Zig
  `ArrayGraph` alive as a NIF resource between calls. Build once, run many
  algorithms, destroy when done.

  ## Usage

      builder = Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)

      # Build once — one-time cost
      graph = Yog.Zog.ResourceGraph.new(builder)

      # Run algorithms directly on native memory
      Yog.Zog.ResourceGraph.betweenness_unweighted(graph)
      Yog.Zog.ResourceGraph.pagerank(graph)

      # Clean up
      Yog.Zog.ResourceGraph.destroy(graph)

  ## Requirements

  - `zigler` must be installed and available.
  - Zig compiler version **0.15.x** is required for zigler 0.15.2.

  ## Performance

  For repeated operations on the same graph, ResourceGraph is **5–50× faster**
  than pure Elixir because it eliminates per-call graph reconstruction.
  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      resources: [:GraphRes],
      nifs: [
        ...,
        new: [concurrency: :dirty_cpu],
        nif_destroy: [],
        nif_betweenness_unweighted: [concurrency: :dirty_cpu],
        nif_betweenness_f64: [concurrency: :dirty_cpu],
        nif_closeness_f64: [concurrency: :dirty_cpu],
        nif_harmonic_centrality_f64: [concurrency: :dirty_cpu],
        pagerank: [concurrency: :dirty_cpu],
        eigenvector: [concurrency: :dirty_cpu],
        katz: [concurrency: :dirty_cpu],
        alpha_centrality: [concurrency: :dirty_cpu],
        louvain: [concurrency: :dirty_cpu],
        modularity_f64: [concurrency: :dirty_cpu],
        nif_floyd_warshall: [concurrency: :dirty_cpu],
        nif_johnsons: [concurrency: :dirty_cpu],
        nif_density: [concurrency: :dirty_cpu],
        nif_triangle_count: [concurrency: :dirty_cpu],
        nif_average_clustering_coefficient: [concurrency: :dirty_cpu],
        nif_local_clustering_coefficient: [concurrency: :dirty_cpu],
        nif_assortativity: [concurrency: :dirty_cpu],
        nif_max_flow: [concurrency: :dirty_cpu],
        nif_push_relabel: [concurrency: :dirty_cpu],
        nif_global_min_cut: [concurrency: :dirty_cpu]
      ]

    ~Z"""
    const std = @import("std");
    const beam = @import("beam");
    const e = @import("erl_nif");
    const zog = @import("zog");
    const ArrayGraph = zog.models.ArrayGraph;

    // =============================================================================
    // Resource Type
    // =============================================================================

    const GraphResource = struct {
        graph: ArrayGraph(void, f64),
    };

    pub const GraphRes = beam.Resource(GraphResource, @import("root"), .{
        .Callbacks = struct {
            pub fn dtor(ptr: *GraphResource) void {
                ptr.graph.deinit();
            }
        },
    });

    // =============================================================================
    // Helpers
    // =============================================================================

    fn buildGraph(node_count: usize, from: []u32, to: []u32, weight: []f64) !ArrayGraph(void, f64) {
        const allocator = beam.allocator;
        var g = ArrayGraph(void, f64).init(allocator);
        errdefer g.deinit();
        try g.nodes.ensureTotalCapacity(allocator, node_count);
        try g.edges.ensureTotalCapacity(allocator, from.len);
        for (0..node_count) |_| { _ = try g.addNode({}); }
        for (from, to, weight) |f, t, w| { _ = try g.addEdge(f, t, w); }
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
    // Lifecycle
    // =============================================================================

    pub fn new(node_count: usize, from: []u32, to: []u32, weight: []f64) !GraphRes {
        const g = try buildGraph(node_count, from, to, weight);
        return GraphRes.create(.{ .graph = g }, .{ .released = false });
    }

    pub fn nif_destroy(res: GraphRes) void {
        res.release();
    }

    // =============================================================================
    // Centrality
    // =============================================================================

    pub fn nif_betweenness_unweighted(res: GraphRes) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.betweennessUnweighted(beam.allocator, g);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn nif_betweenness_f64(res: GraphRes) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.betweennessF64(beam.allocator, g);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn nif_closeness_f64(res: GraphRes) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.closenessF64(beam.allocator, g);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn nif_harmonic_centrality_f64(res: GraphRes) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.harmonicCentralityF64(beam.allocator, g);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn pagerank(res: GraphRes, damping: f64, max_iterations: usize, tolerance: f64) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.pagerank(beam.allocator, g, .{
            .damping = damping,
            .max_iterations = max_iterations,
            .tolerance = tolerance,
        });
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn eigenvector(res: GraphRes, max_iterations: usize, tolerance: f64) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.eigenvector(beam.allocator, g, max_iterations, tolerance);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn katz(res: GraphRes, alpha: f64, beta: f64, max_iterations: usize, tolerance: f64) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.katz(beam.allocator, g, alpha, beta, max_iterations, tolerance);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    pub fn alpha_centrality(res: GraphRes, alpha: f64, initial: f64, max_iterations: usize, tolerance: f64) ![]f64 {
        const g = res.unpack().graph;
        var result = try zog.centrality.alphaCentrality(beam.allocator, g, alpha, initial, max_iterations, tolerance);
        defer result.deinit();
        return extractScores(result, g.nodeCapacity());
    }

    // =============================================================================
    // Community
    // =============================================================================

    pub fn louvain(res: GraphRes, min_modularity_gain: f64, max_iterations: usize, seed: u64) ![]usize {
        const g = res.unpack().graph;
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
        return extractAssignments(result, g.nodeCapacity());
    }

    pub fn modularity_f64(res: GraphRes, assignments: []usize) !f64 {
        const g = res.unpack().graph;
        var map = std.AutoHashMap(u32, usize).init(beam.allocator);
        defer map.deinit();
        for (assignments, 0..) |comm, i| {
            try map.put(@intCast(i), comm);
        }
        return try zog.community.metrics.modularity(beam.allocator, g, map, zog.utils.identityF64);
    }

    // =============================================================================
    // Pathfinding
    // =============================================================================

    fn extractMatrix(result: anytype, node_count: usize) !beam.term {
        var matrix = try beam.allocator.alloc(f64, node_count * node_count);
        defer beam.allocator.free(matrix);
        for (0..node_count) |i| {
            for (0..node_count) |j| {
                matrix[i * node_count + j] = result.get(@intCast(i), @intCast(j)) orelse std.math.inf(f64);
            }
        }
        return beam.make(.{.ok, matrix}, .{});
    }

    pub fn nif_floyd_warshall(res: GraphRes) !beam.term {
        const g = res.unpack().graph;
        const node_count = g.nodeCapacity();
        var result = zog.pathfinding.apsp.floydWarshall(beam.allocator, g) catch |err| {
            if (err == error.NegativeCycle) {
                return beam.make(.{.@"error", .negative_cycle}, .{});
            }
            return err;
        };
        defer result.deinit();
        return extractMatrix(result, node_count);
    }

    pub fn nif_johnsons(res: GraphRes) !beam.term {
        const g = res.unpack().graph;
        const node_count = g.nodeCapacity();
        var result = zog.pathfinding.apsp.johnsonsGeneric(
            beam.allocator, g, f64, 0.0,
            zog.utils.addF64, zog.utils.subF64, zog.utils.compareF64,
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
    // Metrics
    // =============================================================================

    pub fn nif_density(res: GraphRes) !f64 {
        const g = res.unpack().graph;
        const n = g.nodeCapacity();
        if (n <= 1) return 0.0;
        const possible_edges = @as(f64, @floatFromInt(n * (n - 1)));
        return @as(f64, @floatFromInt(g.edgeCount())) / possible_edges;
    }

    pub fn nif_triangle_count(res: GraphRes) !usize {
        const g = res.unpack().graph;
        return try zog.community.metrics.countTriangles(beam.allocator, g);
    }

    pub fn nif_average_clustering_coefficient(res: GraphRes) !f64 {
        const g = res.unpack().graph;
        return try zog.community.metrics.averageClusteringCoefficient(beam.allocator, g);
    }

    pub fn nif_local_clustering_coefficient(res: GraphRes) ![]f64 {
        const g = res.unpack().graph;
        const node_count = g.nodeCapacity();
        var scores = try beam.allocator.alloc(f64, node_count);
        errdefer beam.allocator.free(scores);
        for (0..node_count) |i| {
            scores[i] = zog.community.metrics.clusteringCoefficient(beam.allocator, g, @intCast(i)) catch 0.0;
        }
        return scores;
    }

    pub fn nif_assortativity(res: GraphRes) !f64 {
        const g = res.unpack().graph;
        return try zog.metrics.assortativity(beam.allocator, g);
    }

    const FlowNifResult = struct {
        max_flow: f64,
        residual_from: []u32,
        residual_to: []u32,
        residual_cap: []f64,
        source_side: []u32,
        sink_side: []u32,
    };

    fn edmondsKarpCSR(
        node_count: usize,
        from: []u32,
        to: []u32,
        capacity: []f64,
        source: u32,
        sink: u32,
    ) !FlowNifResult {
        const allocator = beam.allocator;
        const V = node_count;
        const E = from.len;
        const num_caps = E * 2;

        // Pre-allocate CSR representation.
        var head = try allocator.alloc(?u32, V);
        @memset(head, null);
        defer allocator.free(head);

        var to_nodes = try allocator.alloc(u32, num_caps);
        defer allocator.free(to_nodes);

        var cap = try allocator.alloc(f64, num_caps);
        defer allocator.free(cap);

        var next_edge = try allocator.alloc(?u32, num_caps);
        defer allocator.free(next_edge);

        // Ingest edges in pairs.
        for (from, to, capacity, 0..) |u, v, c, i| {
            const e_idx = @as(u32, @intCast(i * 2));

            // Forward edge (u -> v)
            to_nodes[e_idx] = v;
            cap[e_idx] = c;
            next_edge[e_idx] = head[u];
            head[u] = e_idx;

            // Backward edge (v -> u)
            to_nodes[e_idx + 1] = u;
            cap[e_idx + 1] = 0.0;
            next_edge[e_idx + 1] = head[v];
            head[v] = e_idx + 1;
        }

        var total_flow: f64 = 0.0;

        // Pre-allocate BFS workspace.
        var parent_edge = try allocator.alloc(u32, V);
        defer allocator.free(parent_edge);

        var parent_node = try allocator.alloc(u32, V);
        defer allocator.free(parent_node);

        var path_cap = try allocator.alloc(f64, V);
        defer allocator.free(path_cap);

        var queue = try allocator.alloc(u32, V);
        defer allocator.free(queue);

        var visited = try allocator.alloc(bool, V);
        defer allocator.free(visited);

        // Ford-Fulkerson with BFS (Edmonds-Karp).
        while (true) {
            @memset(visited, false);

            var q_head: usize = 0;
            var q_tail: usize = 0;

            queue[q_tail] = source;
            q_tail += 1;
            visited[source] = true;
            path_cap[source] = 0.0;

            var found = false;

            while (q_head < q_tail) {
                const u = queue[q_head];
                q_head += 1;

                var opt_e = head[u];
                while (opt_e) |edge_idx| {
                    const v = to_nodes[edge_idx];
                    const c = cap[edge_idx];

                    if (!visited[v] and c > 0.0) {
                        const new_cap = if (u == source)
                            c
                        else
                            @min(path_cap[u], c);

                        parent_node[v] = u;
                        parent_edge[v] = edge_idx;
                        path_cap[v] = new_cap;
                        visited[v] = true;

                        if (v == sink) {
                            found = true;
                            break;
                        }
                        queue[q_tail] = v;
                        q_tail += 1;
                    }
                    opt_e = next_edge[edge_idx];
                }
                if (found) break;
            }

            if (!found) break;

            const bottleneck = path_cap[sink];

            // Augment path.
            var curr = sink;
            while (curr != source) {
                const edge_idx = parent_edge[curr];
                cap[edge_idx] -= bottleneck;
                cap[edge_idx ^ 1] += bottleneck;
                curr = parent_node[curr];
            }

            total_flow += bottleneck;
        }

        // --- Min-Cut Reachability DFS/BFS ---
        @memset(visited, false);
        var mc_head: usize = 0;
        var mc_tail: usize = 0;

        queue[mc_tail] = source;
        mc_tail += 1;
        visited[source] = true;

        while (mc_head < mc_tail) {
            const u = queue[mc_head];
            mc_head += 1;

            var opt_e = head[u];
            while (opt_e) |edge_idx| {
                const v = to_nodes[edge_idx];
                const c = cap[edge_idx];
                if (!visited[v] and c > 0.0) {
                    visited[v] = true;
                    queue[mc_tail] = v;
                    mc_tail += 1;
                }
                opt_e = next_edge[edge_idx];
            }
        }

        // Split source-side and sink-side nodes.
        var source_side_list = std.ArrayList(u32).empty;
        errdefer source_side_list.deinit(allocator);
        var sink_side_list = std.ArrayList(u32).empty;
        errdefer sink_side_list.deinit(allocator);

        for (0..V) |u| {
            if (visited[u]) {
                try source_side_list.append(allocator, @intCast(u));
            } else {
                try sink_side_list.append(allocator, @intCast(u));
            }
        }

        // Flatten residual capacities.
        var res_from = try allocator.alloc(u32, num_caps);
        errdefer allocator.free(res_from);
        var res_to = try allocator.alloc(u32, num_caps);
        errdefer allocator.free(res_to);
        var res_cap = try allocator.alloc(f64, num_caps);
        errdefer allocator.free(res_cap);

        for (0..num_caps) |edge_idx| {
            res_from[edge_idx] = to_nodes[edge_idx ^ 1];
            res_to[edge_idx] = to_nodes[edge_idx];
            res_cap[edge_idx] = cap[edge_idx];
        }

        return .{
            .max_flow = total_flow,
            .residual_from = res_from,
            .residual_to = res_to,
            .residual_cap = res_cap,
            .source_side = try source_side_list.toOwnedSlice(allocator),
            .sink_side = try sink_side_list.toOwnedSlice(allocator),
        };
    }

    pub fn nif_max_flow(res: GraphRes, source: u32, sink: u32) !FlowNifResult {
        const g = res.unpack().graph;
        const V = g.nodes.len;

        var from_list = std.ArrayList(u32).empty;
        defer from_list.deinit(beam.allocator);
        var to_list = std.ArrayList(u32).empty;
        defer to_list.deinit(beam.allocator);
        var cap_list = std.ArrayList(f64).empty;
        defer cap_list.deinit(beam.allocator);

        for (0..V) |u| {
            var opt_e = g.nodes.items(.first_edge)[u];
            while (opt_e) |edge_idx| {
                const edge = g.edges.get(edge_idx);
                if (!edge.is_deleted) {
                    try from_list.append(beam.allocator, @intCast(u));
                    try to_list.append(beam.allocator, edge.to);
                    try cap_list.append(beam.allocator, edge.data);
                }
                opt_e = edge.next_edge;
            }
        }

        return try edmondsKarpCSR(V, from_list.items, to_list.items, cap_list.items, source, sink);
    }

    fn pushRelabelCSR(
        node_count: usize,
        from: []u32,
        to: []u32,
        capacity: []f64,
        source: u32,
        sink: u32,
    ) !FlowNifResult {
        const allocator = beam.allocator;
        const V = node_count;
        const E = from.len;
        const num_caps = E * 2;

        const head = try allocator.alloc(?u32, V);
        @memset(head, null);
        defer allocator.free(head);

        const to_nodes = try allocator.alloc(u32, num_caps);
        defer allocator.free(to_nodes);

        const cap = try allocator.alloc(f64, num_caps);
        defer allocator.free(cap);

        const next_edge = try allocator.alloc(?u32, num_caps);
        defer allocator.free(next_edge);

        for (from, to, capacity, 0..) |u, v, c, i| {
            const e_idx = @as(u32, @intCast(i * 2));

            to_nodes[e_idx] = v;
            cap[e_idx] = c;
            next_edge[e_idx] = head[u];
            head[u] = e_idx;

            to_nodes[e_idx + 1] = u;
            cap[e_idx + 1] = 0.0;
            next_edge[e_idx + 1] = head[v];
            head[v] = e_idx + 1;
        }

        const height = try allocator.alloc(u32, V);
        @memset(height, 0);
        defer allocator.free(height);

        const excess = try allocator.alloc(f64, V);
        @memset(excess, 0.0);
        defer allocator.free(excess);

        const current_edge = try allocator.alloc(?u32, V);
        defer allocator.free(current_edge);
        for (0..V) |i| current_edge[i] = head[i];

        const height_count = try allocator.alloc(u32, V);
        @memset(height_count, 0);
        defer allocator.free(height_count);

        const max_buckets = 2 * V;
        const bucket_head = try allocator.alloc(?u32, max_buckets);
        @memset(bucket_head, null);
        defer allocator.free(bucket_head);

        const bucket_next = try allocator.alloc(?u32, V);
        @memset(bucket_next, null);
        defer allocator.free(bucket_next);

        const in_bucket = try allocator.alloc(bool, V);
        @memset(in_bucket, false);
        defer allocator.free(in_bucket);

        var max_height: usize = 0;

        const helpers = struct {
            inline fn pushActive(
                u: u32,
                h: u32,
                b_head: []?u32,
                b_next: []?u32,
                in_b: []bool,
                max_h: *usize,
                src: u32,
                snk: u32,
            ) void {
                if (u != src and u != snk and !in_b[u]) {
                    b_next[u] = b_head[h];
                    b_head[h] = u;
                    in_b[u] = true;
                    max_h.* = @max(max_h.*, h);
                }
            }
        };

        {
            var queue = try allocator.alloc(u32, V);
            defer allocator.free(queue);

            var visited = try allocator.alloc(bool, V);
            @memset(visited, false);
            defer allocator.free(visited);

            var q_head: usize = 0;
            var q_tail: usize = 0;

            queue[q_tail] = sink;
            q_tail += 1;
            visited[sink] = true;
            height[sink] = 0;

            while (q_head < q_tail) {
                const v = queue[q_head];
                q_head += 1;

                var opt_e = head[v];
                while (opt_e) |edge_idx| {
                    const u = to_nodes[edge_idx];
                    if (!visited[u] and cap[edge_idx ^ 1] > 0.0) {
                        height[u] = height[v] + 1;
                        visited[u] = true;
                        queue[q_tail] = u;
                        q_tail += 1;
                    }
                    opt_e = next_edge[edge_idx];
                }
            }

            for (0..V) |i| {
                if (!visited[i]) {
                    height[i] = @as(u32, @intCast(V));
                }
                if (height[i] < V) {
                    height_count[height[i]] += 1;
                }
            }
        }

        height[source] = @as(u32, @intCast(V));

        var opt_se = head[source];
        while (opt_se) |edge_idx| {
            const v = to_nodes[edge_idx];
            const c = cap[edge_idx];
            if (c > 0.0) {
                cap[edge_idx] = 0.0;
                cap[edge_idx ^ 1] += c;
                excess[source] -= c;
                excess[v] += c;
                helpers.pushActive(v, height[v], bucket_head, bucket_next, in_bucket, &max_height, source, sink);
            }
            opt_se = next_edge[edge_idx];
        }

        while (true) {
            var opt_active: ?u32 = null;
            while (max_height >= 0) {
                if (bucket_head[max_height]) |u| {
                    bucket_head[max_height] = bucket_next[u];
                    in_bucket[u] = false;
                    opt_active = u;
                    break;
                }
                if (max_height == 0) break;
                max_height -= 1;
            }

            const u = opt_active orelse break;

            while (excess[u] > 0.0) {
                const opt_e = current_edge[u];
                if (opt_e) |edge_idx| {
                    const v = to_nodes[edge_idx];
                    const c = cap[edge_idx];
                    if (c > 0.0 and height[u] == height[v] + 1) {
                        const flow_to_push = @min(excess[u], c);
                        cap[edge_idx] -= flow_to_push;
                        cap[edge_idx ^ 1] += flow_to_push;
                        excess[u] -= flow_to_push;
                        excess[v] += flow_to_push;
                        helpers.pushActive(v, height[v], bucket_head, bucket_next, in_bucket, &max_height, source, sink);
                    } else {
                        current_edge[u] = next_edge[edge_idx];
                    }
                } else {
                    const old_h = height[u];
                    var min_h: u32 = std.math.maxInt(u32);

                    var opt_re = head[u];
                    while (opt_re) |re| {
                        const v = to_nodes[re];
                        const rc = cap[re];
                        if (rc > 0.0) {
                            min_h = @min(min_h, height[v]);
                        }
                        opt_re = next_edge[re];
                    }

                    if (min_h != std.math.maxInt(u32)) {
                        height[u] = min_h + 1;
                        current_edge[u] = head[u];
                        max_height = @max(max_height, height[u]);

                        if (old_h < V) {
                            height_count[old_h] -= 1;
                            if (height_count[old_h] == 0) {
                                for (0..V) |w| {
                                    if (w != source and height[w] > old_h and height[w] < V) {
                                        height[w] = @as(u32, @intCast(V + 1));
                                        current_edge[w] = head[w];
                                    }
                                }
                            }
                        }

                        if (height[u] < V) {
                            height_count[height[u]] += 1;
                        }
                    }
                }
            }
        }

        var visited = try allocator.alloc(bool, V);
        @memset(visited, false);
        defer allocator.free(visited);

        var queue = try allocator.alloc(u32, V);
        defer allocator.free(queue);

        var mc_head: usize = 0;
        var mc_tail: usize = 0;

        queue[mc_tail] = source;
        mc_tail += 1;
        visited[source] = true;

        while (mc_head < mc_tail) {
            const u = queue[mc_head];
            mc_head += 1;

            var opt_e = head[u];
            while (opt_e) |edge_idx| {
                const v = to_nodes[edge_idx];
                const c = cap[edge_idx];
                if (!visited[v] and c > 0.0) {
                    visited[v] = true;
                    queue[mc_tail] = v;
                    mc_tail += 1;
                }
                opt_e = next_edge[edge_idx];
            }
        }

        var source_side_list = std.ArrayList(u32).empty;
        errdefer source_side_list.deinit(allocator);
        var sink_side_list = std.ArrayList(u32).empty;
        errdefer sink_side_list.deinit(allocator);

        for (0..V) |u| {
            if (visited[u]) {
                try source_side_list.append(allocator, @intCast(u));
            } else {
                try sink_side_list.append(allocator, @intCast(u));
            }
        }

        var res_from = try allocator.alloc(u32, num_caps);
        errdefer allocator.free(res_from);
        var res_to = try allocator.alloc(u32, num_caps);
        errdefer allocator.free(res_to);
        var res_cap = try allocator.alloc(f64, num_caps);
        errdefer allocator.free(res_cap);

        for (0..num_caps) |edge_idx| {
            res_from[edge_idx] = to_nodes[edge_idx ^ 1];
            res_to[edge_idx] = to_nodes[edge_idx];
            res_cap[edge_idx] = cap[edge_idx];
        }

        return .{
            .max_flow = excess[sink],
            .residual_from = res_from,
            .residual_to = res_to,
            .residual_cap = res_cap,
            .source_side = try source_side_list.toOwnedSlice(allocator),
            .sink_side = try sink_side_list.toOwnedSlice(allocator),
        };
    }

    pub fn nif_push_relabel(res: GraphRes, source: u32, sink: u32) !FlowNifResult {
        const g = res.unpack().graph;
        const V = g.nodes.len;

        var from_list = std.ArrayList(u32).empty;
        defer from_list.deinit(beam.allocator);
        var to_list = std.ArrayList(u32).empty;
        defer to_list.deinit(beam.allocator);
        var cap_list = std.ArrayList(f64).empty;
        defer cap_list.deinit(beam.allocator);

        for (0..V) |u| {
            var opt_e = g.nodes.items(.first_edge)[u];
            while (opt_e) |edge_idx| {
                const edge = g.edges.get(edge_idx);
                if (!edge.is_deleted) {
                    try from_list.append(beam.allocator, @intCast(u));
                    try to_list.append(beam.allocator, edge.to);
                    try cap_list.append(beam.allocator, edge.data);
                }
                opt_e = edge.next_edge;
            }
        }

        return try pushRelabelCSR(V, from_list.items, to_list.items, cap_list.items, source, sink);
    }

    const MinCutNifResult = struct {
        cut_value: f64,
        source_side: []u32,
        sink_side: []u32,
    };

    pub fn nif_global_min_cut(res: GraphRes) !MinCutNifResult {
        const allocator = beam.allocator;
        const g = res.unpack().graph;

        const result = try zog.flow.min_cut.globalMinCutF64(allocator, g);

        return .{
            .cut_value = result.weight,
            .source_side = result.group_a,
            .sink_side = result.group_b,
        };
    }
    """

    # ============================================================================
    # Public API
    # ============================================================================

    @typedoc "A native graph resource together with its label mapping."
    @type t :: %{
            resource: reference(),
            builder: Zog.t()
          }

    @doc """
    Builds a native graph resource from a `Yog.Builder.Zog`.

    This is a one-time serialization cost. The returned struct can be passed
    to any algorithm function in this module.
    """
    @spec new(Zog.t()) :: t()
    def new(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      %{
        resource: new(node_count, from, to, weights),
        builder: builder
      }
    end

    @doc """
    Explicitly destroys a native graph resource, freeing its memory.

    Resources are also automatically freed when garbage-collected by the BEAM.
    """
    @spec destroy(t()) :: :ok
    def destroy(%{resource: res}) do
      nif_destroy(res)
      :ok
    end

    # --------------------------------------------------------------------------
    # Centrality
    # --------------------------------------------------------------------------

    @doc """
    Unweighted betweenness centrality (Brandes' algorithm).
    """
    @spec betweenness_unweighted(t()) :: %{Zog.label() => float()}
    def betweenness_unweighted(%{resource: res, builder: builder}) do
      scores = nif_betweenness_unweighted(res)
      map_scores(builder, scores)
    end

    @doc """
    Weighted betweenness centrality.
    """
    @spec betweenness_f64(t()) :: %{Zog.label() => float()}
    def betweenness_f64(%{resource: res, builder: builder}) do
      scores = nif_betweenness_f64(res)
      map_scores(builder, scores)
    end

    @doc """
    Closeness centrality.
    """
    @spec closeness_f64(t()) :: %{Zog.label() => float()}
    def closeness_f64(%{resource: res, builder: builder}) do
      scores = nif_closeness_f64(res)
      map_scores(builder, scores)
    end

    @doc """
    Harmonic centrality.
    """
    @spec harmonic_centrality_f64(t()) :: %{Zog.label() => float()}
    def harmonic_centrality_f64(%{resource: res, builder: builder}) do
      scores = nif_harmonic_centrality_f64(res)
      map_scores(builder, scores)
    end

    @doc """
    PageRank centrality.

    ## Options

    - `:damping` — Damping factor (default: `0.85`).
    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).
    """
    @spec pagerank(t(), keyword()) :: %{Zog.label() => float()}
    def pagerank(%{resource: res, builder: builder}, opts \\ []) do
      damping = Keyword.get(opts, :damping, 0.85)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = pagerank(res, damping, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    @doc """
    Eigenvector centrality.

    ## Options

    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).
    """
    @spec eigenvector(t(), keyword()) :: %{Zog.label() => float()}
    def eigenvector(%{resource: res, builder: builder}, opts \\ []) do
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = eigenvector(res, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    @doc """
    Katz centrality.

    ## Options

    - `:alpha` — Attenuation factor (default: `0.1`).
    - `:beta` — Initial score / bias (default: `1.0`).
    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).
    """
    @spec katz(t(), keyword()) :: %{Zog.label() => float()}
    def katz(%{resource: res, builder: builder}, opts \\ []) do
      alpha = Keyword.get(opts, :alpha, 0.1)
      beta = Keyword.get(opts, :beta, 1.0)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = katz(res, alpha, beta, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    @doc """
    Alpha centrality.

    ## Options

    - `:alpha` — Attenuation factor (default: `0.5`).
    - `:initial` — Initial score for all nodes (default: `1.0`).
    - `:max_iterations` — Maximum iterations (default: `100`).
    - `:tolerance` — Convergence tolerance (default: `0.0001`).
    """
    @spec alpha_centrality(t(), keyword()) :: %{Zog.label() => float()}
    def alpha_centrality(%{resource: res, builder: builder}, opts \\ []) do
      alpha = Keyword.get(opts, :alpha, 0.5)
      initial = Keyword.get(opts, :initial, 1.0)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      tolerance = Keyword.get(opts, :tolerance, 0.0001)

      scores = alpha_centrality(res, alpha, initial, max_iterations, tolerance)
      map_scores(builder, scores)
    end

    # --------------------------------------------------------------------------
    # Community
    # --------------------------------------------------------------------------

    @doc """
    Louvain community detection.

    ## Options

    - `:min_modularity_gain` — Stop threshold (default: `0.000001`).
    - `:max_iterations` — Maximum iterations per phase (default: `100`).
    - `:seed` — Random seed (default: `42`).
    """
    @spec louvain(t(), keyword()) :: %{Zog.label() => non_neg_integer()}
    def louvain(%{resource: res, builder: builder}, opts \\ []) do
      min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
      max_iterations = Keyword.get(opts, :max_iterations, 100)
      seed = Keyword.get(opts, :seed, 42)

      assignments = louvain(res, min_modularity_gain, max_iterations, seed)
      map_assignments(builder, assignments)
    end

    @doc """
    Computes modularity for a given community partition.
    """
    @spec modularity(t(), %{Zog.label() => non_neg_integer()}) :: float()
    def modularity(%{resource: res, builder: builder}, community_map)
        when is_map(community_map) do
      assignments =
        builder
        |> Zog.all_labels()
        |> Enum.map(fn label -> Map.get(community_map, label, 0) end)

      modularity_f64(res, assignments)
    end

    # --------------------------------------------------------------------------
    # Pathfinding
    # --------------------------------------------------------------------------

    @doc """
    Floyd-Warshall all-pairs shortest paths.

    Returns `{:ok, distance_matrix}` or `{:error, :negative_cycle}`.
    """
    @spec floyd_warshall(t()) :: {:ok, [[float()]]} | {:error, :negative_cycle}
    def floyd_warshall(%{resource: res, builder: builder}) do
      node_count = Zog.node_count(builder)

      case nif_floyd_warshall(res) do
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
    Johnson's Algorithm for all-pairs shortest paths.

    Returns `{:ok, distance_matrix}` or `{:error, :negative_cycle}`.
    """
    @spec johnsons(t()) :: {:ok, [[float()]]} | {:error, :negative_cycle}
    def johnsons(%{resource: res, builder: builder}) do
      node_count = Zog.node_count(builder)

      case nif_johnsons(res) do
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

    # --------------------------------------------------------------------------
    # Metrics
    # --------------------------------------------------------------------------

    @doc """
    Graph density.
    """
    @spec density(t()) :: float()
    def density(%{resource: res}) do
      nif_density(res)
    end

    @doc """
    Triangle count.
    """
    @spec triangle_count(t()) :: non_neg_integer()
    def triangle_count(%{resource: res}) do
      nif_triangle_count(res)
    end

    @doc """
    Average clustering coefficient.
    """
    @spec average_clustering_coefficient(t()) :: float()
    def average_clustering_coefficient(%{resource: res}) do
      nif_average_clustering_coefficient(res)
    end

    @doc """
    Local clustering coefficient for each node.
    """
    @spec local_clustering_coefficient(t()) :: %{Zog.label() => float()}
    def local_clustering_coefficient(%{resource: res, builder: builder}) do
      scores = nif_local_clustering_coefficient(res)
      map_scores(builder, scores)
    end

    @doc """
    Degree assortativity.
    """
    @spec assortativity(t()) :: float()
    def assortativity(%{resource: res}) do
      nif_assortativity(res)
    end

    @doc """
    Computes the maximum flow and minimum cut natively on a `ResourceGraph`.
    """
    @spec max_flow(t(), Zog.label(), Zog.label(), atom()) :: %{
            max_flow: float(),
            residual_graph: Yog.Graph.t(),
            source_side: list(Zog.label()),
            sink_side: list(Zog.label())
          }
    def max_flow(%{resource: res, builder: builder}, source, sink, algorithm \\ :edmonds_karp) do
      source_idx = Zog.label_to_id(builder, source)
      sink_idx = Zog.label_to_id(builder, sink)

      if is_nil(source_idx) or is_nil(sink_idx) do
        raise ArgumentError, "source or sink node not found in graph"
      end

      result =
        case algorithm do
          :push_relabel ->
            nif_push_relabel(res, source_idx, sink_idx)

          _ ->
            nif_max_flow(res, source_idx, sink_idx)
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
    Computes the global minimum cut of the undirected network using the Stoer-Wagner algorithm.

    Reuses the persistent native resource graph.

    ## Returns

    A map with the following keys:
    - `:cut_value` — The total weight of the minimum cut.
    - `:source_side` — List of original user node labels in the first partition.
    - `:sink_side` — List of original user node labels in the second partition.
    """
    @spec global_min_cut(t()) :: %{
            cut_value: float(),
            source_side: list(Zog.label()),
            sink_side: list(Zog.label())
          }
    def global_min_cut(%{resource: res, builder: builder}) do
      result = nif_global_min_cut(res)

      source_side = Enum.map(result.source_side, &Zog.id_to_label(builder, &1))
      sink_side = Enum.map(result.sink_side, &Zog.id_to_label(builder, &1))

      %{
        cut_value: result.cut_value,
        source_side: source_side,
        sink_side: sink_side
      }
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

    defp map_assignments(builder, assignments) do
      builder
      |> Zog.all_labels()
      |> Enum.zip(assignments)
      |> Map.new()
    end
  else
    @moduledoc """
    Native graph resource backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed.
    """

    def new(_builder) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end

    def destroy(_graph) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end

    for fun <- [
          :betweenness_unweighted,
          :betweenness_f64,
          :closeness_f64,
          :harmonic_centrality_f64,
          :pagerank,
          :eigenvector,
          :katz,
          :alpha_centrality,
          :louvain,
          :modularity,
          :floyd_warshall,
          :johnsons,
          :density,
          :triangle_count,
          :average_clustering_coefficient,
          :local_clustering_coefficient,
          :assortativity
        ] do
      def unquote(fun)(_graph, _opts \\ []) do
        raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
      end
    end

    def max_flow(_graph, _source, _sink, _algorithm \\ :edmonds_karp) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end

    def global_min_cut(_graph) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end
  end
end
