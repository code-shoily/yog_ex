const std = @import("std");
const utils = @import("../utils.zig");

/// Key for residual capacity map.
fn EdgeKey(comptime NodeId: type) type {
    return struct { from: NodeId, to: NodeId };
}

// =============================================================================
// Result Types
// =============================================================================

/// Result of a maximum flow computation.
pub fn MaxFlowResult(comptime NodeId: type, comptime Flow: type) type {
    return struct {
        const Self = @This();

        /// The maximum flow value from source to sink.
        max_flow: Flow,
        /// The source node.
        source: NodeId,
        /// The sink node.
        sink: NodeId,
        /// All nodes that appeared in the original graph.
        all_nodes: []NodeId,
        /// Residual capacities after flow computation.
        /// Key is (from, to); positive values indicate available capacity.
        residual: std.AutoHashMap(EdgeKey(NodeId), Flow),

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.all_nodes);
            self.residual.deinit();
        }
    };
}

/// Represents a minimum s-t cut.
pub fn MinCut(comptime NodeId: type) type {
    return struct {
        const Self = @This();

        /// Nodes on the source side of the cut.
        source_side: []NodeId,
        /// Nodes on the sink side of the cut.
        sink_side: []NodeId,

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.source_side);
            allocator.free(self.sink_side);
        }
    };
}

// =============================================================================
// Edmonds-Karp (Ford-Fulkerson with BFS)
// =============================================================================

/// Finds the maximum flow using the Edmonds-Karp algorithm.
///
/// Edmonds-Karp is a specific implementation of the Ford-Fulkerson method
/// that uses BFS to find the shortest augmenting path, guaranteeing
/// O(VE²) time complexity.
///
/// **Time Complexity:** O(VE²)
///
/// Capacities must be non-negative.
pub fn edmondsKarp(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: utils.NodeId(@TypeOf(graph)),
    sink: utils.NodeId(@TypeOf(graph)),
    comptime Flow: type,
    zero: Flow,
    addFn: fn (Flow, Flow) Flow,
    subFn: fn (Flow, Flow) Flow,
    compareFn: fn (Flow, Flow) std.math.Order,
    minFn: fn (Flow, Flow) Flow,
) !MaxFlowResult(utils.NodeId(@TypeOf(graph)), Flow) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const EKey = EdgeKey(NodeId);

    // Collect all nodes.
    var nodes_list = std.ArrayList(NodeId).empty;
    errdefer nodes_list.deinit(allocator);
    var node_it = graph.nodeIds();
    while (node_it.next()) |node| try nodes_list.append(allocator, node);

    // Early exit if source == sink.
    if (std.meta.eql(source, sink)) {
        const all_nodes = try nodes_list.toOwnedSlice(allocator);
        const empty_residual = std.AutoHashMap(EKey, Flow).init(allocator);
        return .{
            .max_flow = zero,
            .source = source,
            .sink = sink,
            .all_nodes = all_nodes,
            .residual = empty_residual,
        };
    }

    const V = nodes_list.items.len;

    // Count edges in the input graph.
    var edge_count: usize = 0;
    var count_it = graph.allEdges();
    while (count_it.next()) |_| edge_count += 1;

    const num_caps = edge_count * 2;

    // Pre-allocate CSR representation.
    var head = try allocator.alloc(?u32, V);
    @memset(head, null);
    defer allocator.free(head);

    var to_nodes = try allocator.alloc(u32, num_caps);
    defer allocator.free(to_nodes);

    var cap = try allocator.alloc(Flow, num_caps);
    defer allocator.free(cap);

    var next_edge = try allocator.alloc(?u32, num_caps);
    defer allocator.free(next_edge);

    // Ingest edges in pairs.
    var e_idx: u32 = 0;
    var add_edge_it = graph.allEdges();
    while (add_edge_it.next()) |edge| {
        const u = @as(u32, @intCast(edge.from));
        const v = @as(u32, @intCast(edge.to));
        const c = edge.data;

        // Forward edge (u -> v)
        to_nodes[e_idx] = v;
        cap[e_idx] = c;
        next_edge[e_idx] = head[u];
        head[u] = e_idx;

        // Backward edge (v -> u)
        to_nodes[e_idx + 1] = u;
        cap[e_idx + 1] = zero;
        next_edge[e_idx + 1] = head[v];
        head[v] = e_idx + 1;

        e_idx += 2;
    }

    var total_flow = zero;

    // Pre-allocate BFS workspace.
    var parent_edge = try allocator.alloc(u32, V);
    defer allocator.free(parent_edge);

    var parent_node = try allocator.alloc(u32, V);
    defer allocator.free(parent_node);

    var path_cap = try allocator.alloc(Flow, V);
    defer allocator.free(path_cap);

    var queue = try allocator.alloc(u32, V);
    defer allocator.free(queue);

    var visited = try allocator.alloc(bool, V);
    defer allocator.free(visited);

    const src_idx = @as(u32, @intCast(source));
    const snk_idx = @as(u32, @intCast(sink));

    // Ford-Fulkerson with BFS (Edmonds-Karp).
    while (true) {
        @memset(visited, false);

        var q_head: usize = 0;
        var q_tail: usize = 0;

        queue[q_tail] = src_idx;
        q_tail += 1;
        visited[src_idx] = true;
        path_cap[src_idx] = zero;

        var found = false;

        while (q_head < q_tail) {
            const u = queue[q_head];
            q_head += 1;

            var opt_e = head[u];
            while (opt_e) |e| {
                const v = to_nodes[e];
                const c = cap[e];

                if (!visited[v] and compareFn(c, zero) == .gt) {
                    const new_cap = if (u == src_idx)
                        c
                    else
                        minFn(path_cap[u], c);

                    parent_node[v] = u;
                    parent_edge[v] = e;
                    path_cap[v] = new_cap;
                    visited[v] = true;

                    if (v == snk_idx) {
                        found = true;
                        break;
                    }
                    queue[q_tail] = v;
                    q_tail += 1;
                }
                opt_e = next_edge[e];
            }
            if (found) break;
        }

        if (!found) break;

        const bottleneck = path_cap[snk_idx];

        // Augment path.
        var curr = snk_idx;
        while (curr != src_idx) {
            const e = parent_edge[curr];
            cap[e] = subFn(cap[e], bottleneck);
            cap[e ^ 1] = addFn(cap[e ^ 1], bottleneck);
            curr = parent_node[curr];
        }

        total_flow = addFn(total_flow, bottleneck);
    }

    // Build residual hash map for result compatibility.
    var residual = std.AutoHashMap(EKey, Flow).init(allocator);
    errdefer residual.deinit();

    for (0..num_caps) |e| {
        const u = to_nodes[e ^ 1];
        const v = to_nodes[e];
        const c = cap[e];

        const key = EKey{ .from = @as(NodeId, @intCast(u)), .to = @as(NodeId, @intCast(v)) };
        try residual.put(key, c);
    }

    const all_nodes = try nodes_list.toOwnedSlice(allocator);
    return .{
        .max_flow = total_flow,
        .source = source,
        .sink = sink,
        .all_nodes = all_nodes,
        .residual = residual,
    };
}

/// Extracts the minimum s-t cut from a max flow result.
///
/// By the max-flow min-cut theorem, the capacity of this cut equals the max flow.
/// Uses the final residual graph to find all nodes reachable from the source.
pub fn minCut(
    allocator: std.mem.Allocator,
    result: anytype,
    comptime Flow: type,
    zero: Flow,
    compareFn: fn (Flow, Flow) std.math.Order,
) !MinCut(@TypeOf(result.source)) {
    const NodeId = @TypeOf(result.source);

    // Build adjacency list from residual capacities for efficient DFS.
    var residual_adj = std.AutoHashMap(NodeId, std.ArrayListUnmanaged(NodeId)).init(allocator);
    defer {
        var rit = residual_adj.valueIterator();
        while (rit.next()) |list| list.deinit(allocator);
        residual_adj.deinit();
    }

    var cap_it = result.residual.iterator();
    while (cap_it.next()) |entry| {
        if (compareFn(entry.value_ptr.*, zero) == .gt) {
            const from = entry.key_ptr.from;
            const to = entry.key_ptr.to;
            const gop = try residual_adj.getOrPut(from);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(allocator, to);
        }
    }

    // DFS from source in residual graph.
    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();

    var stack = std.ArrayList(NodeId).empty;
    defer stack.deinit(allocator);

    try stack.append(allocator, result.source);

    while (stack.items.len > 0) {
        const current = stack.pop().?;
        if (visited.contains(current)) continue;
        try visited.put(current, {});

        const neighbors = residual_adj.get(current) orelse continue;
        for (neighbors.items) |next| {
            if (!visited.contains(next)) {
                try stack.append(allocator, next);
            }
        }
    }

    var source_side = std.ArrayList(NodeId).empty;
    errdefer source_side.deinit(allocator);
    var sink_side = std.ArrayList(NodeId).empty;
    errdefer sink_side.deinit(allocator);

    for (result.all_nodes) |node| {
        if (visited.contains(node)) {
            try source_side.append(allocator, node);
        } else {
            try sink_side.append(allocator, node);
        }
    }

    return .{
        .source_side = try source_side.toOwnedSlice(allocator),
        .sink_side = try sink_side.toOwnedSlice(allocator),
    };
}

/// Finds the maximum flow using the Push-Relabel algorithm with highest-label selection and the gap heuristic.
///
/// **Time Complexity:** O(V²√E)
pub fn pushRelabel(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: utils.NodeId(@TypeOf(graph)),
    sink: utils.NodeId(@TypeOf(graph)),
    comptime Flow: type,
    zero: Flow,
    addFn: fn (Flow, Flow) Flow,
    subFn: fn (Flow, Flow) Flow,
    compareFn: fn (Flow, Flow) std.math.Order,
    minFn: fn (Flow, Flow) Flow,
) !MaxFlowResult(utils.NodeId(@TypeOf(graph)), Flow) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const EKey = EdgeKey(NodeId);

    // Collect all nodes.
    var nodes_list = std.ArrayList(NodeId).empty;
    errdefer nodes_list.deinit(allocator);
    var node_it = graph.nodeIds();
    while (node_it.next()) |node| try nodes_list.append(allocator, node);

    // Early exit if source == sink.
    if (std.meta.eql(source, sink)) {
        const all_nodes = try nodes_list.toOwnedSlice(allocator);
        const empty_residual = std.AutoHashMap(EKey, Flow).init(allocator);
        return .{
            .max_flow = zero,
            .source = source,
            .sink = sink,
            .all_nodes = all_nodes,
            .residual = empty_residual,
        };
    }

    const V = nodes_list.items.len;

    // Count edges in the input graph.
    var edge_count: usize = 0;
    var count_it = graph.allEdges();
    while (count_it.next()) |_| edge_count += 1;

    const num_caps = edge_count * 2;

    // Pre-allocate CSR representation.
    var head = try allocator.alloc(?u32, V);
    @memset(head, null);
    defer allocator.free(head);

    var to_nodes = try allocator.alloc(u32, num_caps);
    defer allocator.free(to_nodes);

    var cap = try allocator.alloc(Flow, num_caps);
    defer allocator.free(cap);

    var next_edge = try allocator.alloc(?u32, num_caps);
    defer allocator.free(next_edge);

    // Ingest edges in pairs.
    var e_idx: u32 = 0;
    var add_edge_it = graph.allEdges();
    while (add_edge_it.next()) |edge| {
        const u = @as(u32, @intCast(edge.from));
        const v = @as(u32, @intCast(edge.to));
        const c = edge.data;

        // Forward edge (u -> v)
        to_nodes[e_idx] = v;
        cap[e_idx] = c;
        next_edge[e_idx] = head[u];
        head[u] = e_idx;

        // Backward edge (v -> u)
        to_nodes[e_idx + 1] = u;
        cap[e_idx + 1] = zero;
        next_edge[e_idx + 1] = head[v];
        head[v] = e_idx + 1;

        e_idx += 2;
    }

    const src_idx = @as(u32, @intCast(source));
    const snk_idx = @as(u32, @intCast(sink));

    // Flat pre-allocated workspaces for Push-Relabel
    const height = try allocator.alloc(u32, V);
    @memset(height, 0);
    defer allocator.free(height);

    const excess = try allocator.alloc(Flow, V);
    @memset(excess, zero);
    defer allocator.free(excess);

    const current_edge = try allocator.alloc(?u32, V);
    defer allocator.free(current_edge);
    for (0..V) |i| current_edge[i] = head[i];

    const height_count = try allocator.alloc(u32, V);
    @memset(height_count, 0);
    defer allocator.free(height_count);

    // Linked list active nodes buckets.
    // Max height of active node can be 2V - 1.
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

    // Helper functions for bucket operations (inlined or inline fn)
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

    // 1. Initial backwards BFS from sink to exact heights.
    {
        var queue = try allocator.alloc(u32, V);
        defer allocator.free(queue);

        var visited = try allocator.alloc(bool, V);
        @memset(visited, false);
        defer allocator.free(visited);

        var q_head: usize = 0;
        var q_tail: usize = 0;

        queue[q_tail] = snk_idx;
        q_tail += 1;
        visited[snk_idx] = true;
        height[snk_idx] = 0;

        while (q_head < q_tail) {
            const v = queue[q_head];
            q_head += 1;

            var opt_e = head[v];
            while (opt_e) |e| {
                const u = to_nodes[e];
                // In residual graph backwards: we traverse v -> u, checking if the forward edge cap[e ^ 1] > 0.
                if (!visited[u] and compareFn(cap[e ^ 1], zero) == .gt) {
                    height[u] = height[v] + 1;
                    visited[u] = true;
                    queue[q_tail] = u;
                    q_tail += 1;
                }
                opt_e = next_edge[e];
            }
        }

        // For nodes not reachable from sink, set height to V.
        for (0..V) |i| {
            if (!visited[i]) {
                height[i] = @as(u32, @intCast(V));
            }
            if (height[i] < V) {
                height_count[height[i]] += 1;
            }
        }
    }

    // Set source height to V.
    height[src_idx] = @as(u32, @intCast(V));

    // 2. Initial flow from source.
    var opt_se = head[src_idx];
    while (opt_se) |e| {
        const v = to_nodes[e];
        const c = cap[e];
        if (compareFn(c, zero) == .gt) {
            cap[e] = zero;
            cap[e ^ 1] = addFn(cap[e ^ 1], c);
            excess[src_idx] = subFn(excess[src_idx], c);
            excess[v] = addFn(excess[v], c);
            helpers.pushActive(v, height[v], bucket_head, bucket_next, in_bucket, &max_height, src_idx, snk_idx);
        }
        opt_se = next_edge[e];
    }

    // 3. Discharge loop using highest-label selection.
    while (true) {
        // Pop highest active node.
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

        // Discharge node u.
        while (compareFn(excess[u], zero) == .gt) {
            const opt_e = current_edge[u];
            if (opt_e) |e| {
                const v = to_nodes[e];
                const c = cap[e];
                if (compareFn(c, zero) == .gt and height[u] == height[v] + 1) {
                    // Push flow
                    const flow_to_push = minFn(excess[u], c);
                    cap[e] = subFn(cap[e], flow_to_push);
                    cap[e ^ 1] = addFn(cap[e ^ 1], flow_to_push);
                    excess[u] = subFn(excess[u], flow_to_push);
                    excess[v] = addFn(excess[v], flow_to_push);
                    helpers.pushActive(v, height[v], bucket_head, bucket_next, in_bucket, &max_height, src_idx, snk_idx);
                } else {
                    current_edge[u] = next_edge[e];
                }
            } else {
                // Relabel node u
                const old_h = height[u];
                var min_h: u32 = std.math.maxInt(u32);

                var opt_re = head[u];
                while (opt_re) |re| {
                    const v = to_nodes[re];
                    const rc = cap[re];
                    if (compareFn(rc, zero) == .gt) {
                        min_h = @min(min_h, height[v]);
                    }
                    opt_re = next_edge[re];
                }

                if (min_h != std.math.maxInt(u32)) {
                    height[u] = min_h + 1;
                    current_edge[u] = head[u];
                    max_height = @max(max_height, height[u]);

                    // Gap heuristic
                    if (old_h < V) {
                        height_count[old_h] -= 1;
                        if (height_count[old_h] == 0) {
                            for (0..V) |w| {
                                if (w != src_idx and height[w] > old_h and height[w] < V) {
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

    // Build residual hash map.
    var residual = std.AutoHashMap(EKey, Flow).init(allocator);
    errdefer residual.deinit();

    for (0..num_caps) |e| {
        const u = to_nodes[e ^ 1];
        const v = to_nodes[e];
        const c = cap[e];

        const key = EKey{ .from = @as(NodeId, @intCast(u)), .to = @as(NodeId, @intCast(v)) };
        try residual.put(key, c);
    }

    const all_nodes = try nodes_list.toOwnedSlice(allocator);
    return .{
        .max_flow = excess[snk_idx],
        .source = source,
        .sink = sink,
        .all_nodes = all_nodes,
        .residual = residual,
    };
}

// =============================================================================
// Convenience Wrappers
// =============================================================================

/// Finds maximum flow with **i32** capacities using Edmonds-Karp.
pub fn edmondsKarpI32(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: utils.NodeId(@TypeOf(graph)),
    sink: utils.NodeId(@TypeOf(graph)),
) !MaxFlowResult(utils.NodeId(@TypeOf(graph)), i32) {
    return edmondsKarp(allocator, graph, source, sink, i32, 0, addI32, subI32, compareI32, minI32);
}

/// Finds maximum flow with **f64** capacities using Edmonds-Karp.
pub fn edmondsKarpF64(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: utils.NodeId(@TypeOf(graph)),
    sink: utils.NodeId(@TypeOf(graph)),
) !MaxFlowResult(utils.NodeId(@TypeOf(graph)), f64) {
    return edmondsKarp(allocator, graph, source, sink, f64, 0.0, utils.addF64, utils.subF64, utils.compareF64, minF64);
}

/// Finds maximum flow with **i32** capacities using Push-Relabel.
pub fn pushRelabelI32(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: utils.NodeId(@TypeOf(graph)),
    sink: utils.NodeId(@TypeOf(graph)),
) !MaxFlowResult(utils.NodeId(@TypeOf(graph)), i32) {
    return pushRelabel(allocator, graph, source, sink, i32, 0, addI32, subI32, compareI32, minI32);
}

/// Finds maximum flow with **f64** capacities using Push-Relabel.
pub fn pushRelabelF64(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: utils.NodeId(@TypeOf(graph)),
    sink: utils.NodeId(@TypeOf(graph)),
) !MaxFlowResult(utils.NodeId(@TypeOf(graph)), f64) {
    return pushRelabel(allocator, graph, source, sink, f64, 0.0, utils.addF64, utils.subF64, utils.compareF64, minF64);
}

// =============================================================================
// Helpers
// =============================================================================

fn addI32(a: i32, b: i32) i32 {
    return a + b;
}
fn subI32(a: i32, b: i32) i32 {
    return a - b;
}
fn compareI32(a: i32, b: i32) std.math.Order {
    return std.math.order(a, b);
}
fn minI32(a: i32, b: i32) i32 {
    return @min(a, b);
}

fn minF64(a: f64, b: f64) f64 {
    return @min(a, b);
}

// =============================================================================
// Tests
// =============================================================================

test "Edmonds-Karp on classic flow network (i32)" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    // 6 nodes: 0..5
    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        _ = try g.addNode({});
    }

    // Classic CLRS-style max flow network.
    // Max flow from 0 to 5 is 23.
    _ = try g.addEdge(0, 1, 16);
    _ = try g.addEdge(0, 2, 13);
    _ = try g.addEdge(1, 2, 10);
    _ = try g.addEdge(1, 3, 12);
    _ = try g.addEdge(2, 1, 4);
    _ = try g.addEdge(2, 4, 14);
    _ = try g.addEdge(3, 2, 9);
    _ = try g.addEdge(3, 5, 20);
    _ = try g.addEdge(4, 3, 7);
    _ = try g.addEdge(4, 5, 4);

    var result = try edmondsKarpI32(allocator, g, 0, 5);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 23), result.max_flow);
}

test "Edmonds-Karp min cut extraction" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        _ = try g.addNode({});
    }

    _ = try g.addEdge(0, 1, 16);
    _ = try g.addEdge(0, 2, 13);
    _ = try g.addEdge(1, 2, 10);
    _ = try g.addEdge(1, 3, 12);
    _ = try g.addEdge(2, 1, 4);
    _ = try g.addEdge(2, 4, 14);
    _ = try g.addEdge(3, 2, 9);
    _ = try g.addEdge(3, 5, 20);
    _ = try g.addEdge(4, 3, 7);
    _ = try g.addEdge(4, 5, 4);

    var result = try edmondsKarpI32(allocator, g, 0, 5);
    defer result.deinit(allocator);

    var cut = try minCut(allocator, result, i32, 0, compareI32);
    defer cut.deinit(allocator);

    // Source (0) must be on the source side.
    var has_source = false;
    for (cut.source_side) |n| {
        if (n == 0) {
            has_source = true;
            break;
        }
    }
    try std.testing.expect(has_source);

    // Sink (5) must be on the sink side.
    var has_sink = false;
    for (cut.sink_side) |n| {
        if (n == 5) {
            has_sink = true;
            break;
        }
    }
    try std.testing.expect(has_sink);

    // The two sides partition all nodes.
    try std.testing.expectEqual(@as(usize, 6), cut.source_side.len + cut.sink_side.len);
}

test "Edmonds-Karp on trivial graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, 5);

    var result = try edmondsKarpI32(allocator, g, 0, 1);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 5), result.max_flow);
}

test "Edmonds-Karp when source equals sink" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});

    var result = try edmondsKarpI32(allocator, g, 0, 0);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 0), result.max_flow);
}

test "Edmonds-Karp with no path" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});

    var result = try edmondsKarpI32(allocator, g, 0, 1);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 0), result.max_flow);
}


test "Push-Relabel on classic flow network (i32)" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    // 6 nodes: 0..5
    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        _ = try g.addNode({});
    }

    _ = try g.addEdge(0, 1, 16);
    _ = try g.addEdge(0, 2, 13);
    _ = try g.addEdge(1, 2, 10);
    _ = try g.addEdge(1, 3, 12);
    _ = try g.addEdge(2, 1, 4);
    _ = try g.addEdge(2, 4, 14);
    _ = try g.addEdge(3, 2, 9);
    _ = try g.addEdge(3, 5, 20);
    _ = try g.addEdge(4, 3, 7);
    _ = try g.addEdge(4, 5, 4);

    var result = try pushRelabelI32(allocator, g, 0, 5);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 23), result.max_flow);
}

test "Push-Relabel min cut extraction" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        _ = try g.addNode({});
    }

    _ = try g.addEdge(0, 1, 16);
    _ = try g.addEdge(0, 2, 13);
    _ = try g.addEdge(1, 2, 10);
    _ = try g.addEdge(1, 3, 12);
    _ = try g.addEdge(2, 1, 4);
    _ = try g.addEdge(2, 4, 14);
    _ = try g.addEdge(3, 2, 9);
    _ = try g.addEdge(3, 5, 20);
    _ = try g.addEdge(4, 3, 7);
    _ = try g.addEdge(4, 5, 4);

    var result = try pushRelabelI32(allocator, g, 0, 5);
    defer result.deinit(allocator);

    var cut = try minCut(allocator, result, i32, 0, compareI32);
    defer cut.deinit(allocator);

    // Source (0) must be on the source side.
    var has_source = false;
    for (cut.source_side) |n| {
        if (n == 0) {
            has_source = true;
            break;
        }
    }
    try std.testing.expect(has_source);

    // Sink (5) must be on the sink side.
    var has_sink = false;
    for (cut.sink_side) |n| {
        if (n == 5) {
            has_sink = true;
            break;
        }
    }
    try std.testing.expect(has_sink);

    try std.testing.expectEqual(@as(usize, 6), cut.source_side.len + cut.sink_side.len);
}

test "Push-Relabel on trivial graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, i32).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, 5);

    var result = try pushRelabelI32(allocator, g, 0, 1);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 5), result.max_flow);
}

