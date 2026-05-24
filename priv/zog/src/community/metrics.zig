const std = @import("std");
const utils = @import("../utils.zig");

// =============================================================================
// Modularity
// =============================================================================

/// Calculates Newman's modularity Q for a graph partition.
///
/// Q measures the density of edges inside communities compared to what
/// would be expected by chance. Ranges from roughly -1 to 1, with positive
/// values indicating community structure better than random.
///
/// `weightFn` converts the graph's edge data to `f64`. For unweighted graphs
/// use a function that always returns `1.0`.
///
/// **Time Complexity:** O(E)
pub fn modularity(
    allocator: std.mem.Allocator,
    graph: anytype,
    assignments: std.AutoHashMap(utils.NodeId(@TypeOf(graph)), usize),
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
) !f64 {
    const NodeId = utils.NodeId(@TypeOf(graph));

    // Compute degree (weighted) for each node and total weight in one pass.
    var degree_map = std.AutoHashMap(NodeId, f64).init(allocator);
    defer degree_map.deinit();

    var total_weight: f64 = 0.0;
    var node_it = graph.nodeIds();
    while (node_it.next()) |node| {
        var deg: f64 = 0.0;
        var sit = graph.successors(node);
        while (sit.next()) |edge| {
            deg += weightFn(edge.data);
        }
        try degree_map.put(node, deg);
        total_weight += deg;
    }

    const m = total_weight / 2.0;
    if (m == 0.0) return 0.0;
    const two_m = 2.0 * m;

    // Single pass over all edges for internal edge weights.
    var sum_in = std.AutoHashMap(usize, f64).init(allocator);
    defer sum_in.deinit();

    var edge_it = graph.allEdges();
    while (edge_it.next()) |edge| {
        const u_comm = assignments.get(edge.from) orelse continue;
        const v_comm = assignments.get(edge.to) orelse continue;
        if (u_comm == v_comm) {
            const gop = try sum_in.getOrPut(u_comm);
            if (!gop.found_existing) gop.value_ptr.* = 0.0;
            gop.value_ptr.* += weightFn(edge.data);
        }
    }

    // Group degrees by community.
    var sum_deg = std.AutoHashMap(usize, f64).init(allocator);
    defer sum_deg.deinit();

    var dit = degree_map.iterator();
    while (dit.next()) |entry| {
        const comm = assignments.get(entry.key_ptr.*) orelse continue;
        const gop = try sum_deg.getOrPut(comm);
        if (!gop.found_existing) gop.value_ptr.* = 0.0;
        gop.value_ptr.* += entry.value_ptr.*;
    }

    // Compute Q from sum_in and sum_deg.  Every community present in
    // sum_deg contributes a term, even those with no internal edges.
    var q: f64 = 0.0;
    var sit = sum_deg.iterator();
    while (sit.next()) |entry| {
        const comm = entry.key_ptr.*;
        const deg_sum = entry.value_ptr.*;
        const in_weight = sum_in.get(comm) orelse 0.0;
        q += in_weight / two_m - (deg_sum * deg_sum) / (two_m * two_m);
    }

    return q;
}

/// Convenience wrapper for modularity on unweighted graphs.
pub fn modularityUnweighted(
    allocator: std.mem.Allocator,
    graph: anytype,
    assignments: std.AutoHashMap(utils.NodeId(@TypeOf(graph)), usize),
) !f64 {
    const EdgeData = @TypeOf(@as(@TypeOf(graph).Edge, undefined).data);
    const S = struct {
        fn weight(_: EdgeData) f64 {
            return 1.0;
        }
    };
    return modularity(allocator, graph, assignments, S.weight);
}

// =============================================================================
// Workspace types for repeated metric calculations
// =============================================================================

/// Reusable workspace for triangle counting and clustering coefficient.
/// Pre-allocates a HashMap so repeated calls avoid per-node allocations.
pub fn MetricWorkspace(comptime NodeId: type) type {
    return struct {
        const Self = @This();

        neighbor_set: std.AutoHashMap(NodeId, void),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .neighbor_set = std.AutoHashMap(NodeId, void).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.neighbor_set.deinit();
        }

        pub fn clear(self: *Self) void {
            self.neighbor_set.clearRetainingCapacity();
        }
    };
}

// =============================================================================
// Triangle Counting
// =============================================================================

/// Counts the total number of triangles in the graph.
///
/// A triangle is a set of three nodes where each pair is connected.
/// Works on the underlying undirected structure (both directions should
/// be present for undirected graphs).
///
/// Uses a degree-based forward-triangle algorithm that counts each triangle
/// exactly once, avoiding the 6× overcount of the naive approach.
///
/// For unsigned-integer NodeIds (e.g. ArrayGraph) the implementation uses a
/// direct-indexed degree slice and skips the sorting step entirely — NodeId
/// comparison serves as the tie-breaker.  For arbitrary NodeIds it falls
/// back to sorting + HashMap rank lookups.
///
/// **Time Complexity:** O(E^1.5) for real-world graphs; O(V × k²) worst case.
pub fn countTriangles(allocator: std.mem.Allocator, graph: anytype) !usize {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const node_id_is_unsigned = switch (@typeInfo(NodeId)) {
        .int => |info| info.signedness == .unsigned,
        else => false,
    };

    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);
    if (nodes.items.len == 0) return 0;

    if (node_id_is_unsigned) {
        // Fast path: NodeId is an unsigned integer.
        // Use a degree slice indexed directly by NodeId, and use NodeId
        // comparison as the tie-breaker.  No sorting or HashMap needed.
        var max_id: NodeId = 0;
        for (nodes.items) |node| {
            if (node > max_id) max_id = node;
        }

        const degree_slice = try allocator.alloc(usize, @as(usize, max_id) + 1);
        defer allocator.free(degree_slice);
        @memset(degree_slice, 0);

        for (nodes.items) |node| {
            var deg: usize = 0;
            var sit = graph.successors(node);
            while (sit.next()) |_| deg += 1;
            degree_slice[@as(usize, node)] = deg;
        }

        var workspace = MetricWorkspace(NodeId).init(allocator);
        defer workspace.deinit();

        var count: usize = 0;
        for (nodes.items) |u| {
            const du = degree_slice[@as(usize, u)];
            workspace.clear();

            // Build forward neighbor set.
            var sit = graph.successors(u);
            while (sit.next()) |edge| {
                const v = edge.to;
                const dv = degree_slice[@as(usize, v)];
                if (du < dv or (du == dv and u < v)) {
                    workspace.neighbor_set.put(v, {}) catch continue;
                }
            }

            // Check triangles through forward edges.
            var sit2 = graph.successors(u);
            while (sit2.next()) |edge| {
                const v = edge.to;
                const dv = degree_slice[@as(usize, v)];
                if (!(du < dv or (du == dv and u < v))) continue;

                var v_sit = graph.successors(v);
                while (v_sit.next()) |v_edge| {
                    const w = v_edge.to;
                    const dw = degree_slice[@as(usize, w)];
                    if (!(dv < dw or (dv == dw and v < w))) continue;

                    if (workspace.neighbor_set.contains(w)) {
                        count += 1;
                    }
                }
            }
        }

        return count;
    }

    // Slow path: arbitrary NodeId type.  Sort by degree and use a HashMap
    // for rank lookups.
    var degrees = std.AutoHashMap(NodeId, usize).init(allocator);
    defer degrees.deinit();

    for (nodes.items) |node| {
        var deg: usize = 0;
        var sit = graph.successors(node);
        while (sit.next()) |_| deg += 1;
        try degrees.put(node, deg);
    }

    var idx_map = std.AutoHashMap(NodeId, usize).init(allocator);
    defer idx_map.deinit();
    for (nodes.items, 0..) |node, i| {
        try idx_map.put(node, i);
    }

    const indices = try allocator.alloc(usize, nodes.items.len);
    defer allocator.free(indices);
    for (0..nodes.items.len) |i| indices[i] = i;

    const SortCtx = struct {
        deg: *const std.AutoHashMap(NodeId, usize),
        node_list: []const NodeId,

        fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            const da = ctx.deg.get(ctx.node_list[a]) orelse 0;
            const db = ctx.deg.get(ctx.node_list[b]) orelse 0;
            if (da != db) return da < db;
            return a < b;
        }
    };

    std.mem.sort(usize, indices, SortCtx{ .deg = &degrees, .node_list = nodes.items }, SortCtx.lessThan);

    const ranks = try allocator.alloc(usize, nodes.items.len);
    defer allocator.free(ranks);
    for (indices, 0..) |node_idx, rank| {
        ranks[node_idx] = rank;
    }

    var workspace = MetricWorkspace(NodeId).init(allocator);
    defer workspace.deinit();

    var count: usize = 0;
    for (nodes.items, 0..) |u, u_idx| {
        const u_rank = ranks[u_idx];
        workspace.clear();

        var sit = graph.successors(u);
        while (sit.next()) |edge| {
            const v = edge.to;
            const v_idx = idx_map.get(v) orelse continue;
            if (u_rank < ranks[v_idx]) {
                workspace.neighbor_set.put(v, {}) catch continue;
            }
        }

        var sit2 = graph.successors(u);
        while (sit2.next()) |edge| {
            const v = edge.to;
            const v_idx = idx_map.get(v) orelse continue;
            if (u_rank >= ranks[v_idx]) continue;

            var v_sit = graph.successors(v);
            while (v_sit.next()) |v_edge| {
                const w = v_edge.to;
                const w_idx = idx_map.get(w) orelse continue;
                if (ranks[v_idx] >= ranks[w_idx]) continue;

                if (workspace.neighbor_set.contains(w)) {
                    count += 1;
                }
            }
        }
    }

    return count;
}

/// Triangle count using a pre-allocated workspace.
///
/// Uses the naive O(V × k²) algorithm; each triangle is counted 6 times.
/// Callers should reuse the workspace across multiple calls for best performance.
/// For a single call prefer `countTriangles` which uses a forward-triangle
/// algorithm with better asymptotic bounds.
pub fn countTrianglesWithWorkspace(graph: anytype, workspace: anytype) usize {
    var total: usize = 0;

    var node_it = graph.nodeIds();
    while (node_it.next()) |u| {
        workspace.neighbor_set.clearRetainingCapacity();

        var sit = graph.successors(u);
        while (sit.next()) |edge| {
            workspace.neighbor_set.put(edge.to, {}) catch continue;
        }

        var sit2 = graph.successors(u);
        while (sit2.next()) |edge| {
            const v = edge.to;
            var v_sit = graph.successors(v);
            while (v_sit.next()) |v_edge| {
                if (workspace.neighbor_set.contains(v_edge.to)) {
                    total += 1;
                }
            }
        }
    }

    // Each triangle is counted 6 times (3 nodes × 2 directions).
    return total / 6;
}

// =============================================================================
// Clustering Coefficient
// =============================================================================

/// Calculates the local clustering coefficient for a node.
///
/// C(u) = 2 × T(u) / (k_u × (k_u - 1))
/// where T(u) is the number of triangles through u and k_u is its degree.
/// Returns 0.0 for nodes with degree < 2.
pub fn clusteringCoefficient(
    allocator: std.mem.Allocator,
    graph: anytype,
    node: utils.NodeId(@TypeOf(graph)),
) !f64 {
    const NodeId = utils.NodeId(@TypeOf(graph));
    var workspace = MetricWorkspace(NodeId).init(allocator);
    defer workspace.deinit();
    return clusteringCoefficientWithWorkspace(graph, node, &workspace);
}

/// Local clustering coefficient using a pre-allocated workspace.
pub fn clusteringCoefficientWithWorkspace(graph: anytype, node: anytype, workspace: anytype) f64 {
    workspace.neighbor_set.clearRetainingCapacity();

    var k: usize = 0;
    var sit = graph.successors(node);
    while (sit.next()) |edge| {
        workspace.neighbor_set.put(edge.to, {}) catch continue;
        k += 1;
    }

    if (k < 2) return 0.0;

    var triangles: usize = 0;
    var it = workspace.neighbor_set.iterator();
    while (it.next()) |entry| {
        const v = entry.key_ptr.*;
        var v_sit = graph.successors(v);
        while (v_sit.next()) |edge| {
            if (workspace.neighbor_set.contains(edge.to)) {
                triangles += 1;
            }
        }
    }

    // Each triangle is counted twice (u-v-w and u-w-v).
    const t = @as(f64, @floatFromInt(triangles / 2));
    const kf = @as(f64, @floatFromInt(k));
    return 2.0 * t / (kf * (kf - 1.0));
}

/// Calculates the average clustering coefficient for the entire graph.
pub fn averageClusteringCoefficient(allocator: std.mem.Allocator, graph: anytype) !f64 {
    const NodeId = utils.NodeId(@TypeOf(graph));
    var workspace = MetricWorkspace(NodeId).init(allocator);
    defer workspace.deinit();

    var sum: f64 = 0.0;
    var count: usize = 0;

    var it = graph.nodeIds();
    while (it.next()) |node| {
        sum += clusteringCoefficientWithWorkspace(graph, node, &workspace);
        count += 1;
    }

    if (count == 0) return 0.0;
    return sum / @as(f64, @floatFromInt(count));
}

// =============================================================================
// Density
// =============================================================================

/// Graph density: ratio of actual edges to maximum possible edges.
///
/// For a directed graph with n nodes, max edges = n × (n - 1).
/// For undirected graphs represented with bidirectional edges, this
/// will report the directed density; divide by 2 for undirected density.
pub fn density(graph: anytype) f64 {
    const n = graph.nodeCount();
    if (n < 2) return 0.0;
    const e = graph.edgeCount();
    const nf = @as(f64, @floatFromInt(n));
    const ef = @as(f64, @floatFromInt(e));
    return ef / (nf * (nf - 1.0));
}

/// Density within a community (ratio of internal edges to possible edges).
///
/// `community_nodes` is a slice of node IDs belonging to the community.
pub fn communityDensity(
    allocator: std.mem.Allocator,
    graph: anytype,
    community_nodes: []const utils.NodeId(@TypeOf(graph)),
) !f64 {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const n = community_nodes.len;
    if (n < 2) return 0.0;

    var node_set = std.AutoHashMap(NodeId, void).init(allocator);
    defer node_set.deinit();
    for (community_nodes) |node| {
        try node_set.put(node, {});
    }

    var internal_edges: usize = 0;
    for (community_nodes) |u| {
        var sit = graph.successors(u);
        while (sit.next()) |edge| {
            if (node_set.contains(edge.to)) {
                internal_edges += 1;
            }
        }
    }

    const nf = @as(f64, @floatFromInt(n));
    const max_edges = nf * (nf - 1.0);
    const ef = @as(f64, @floatFromInt(internal_edges));
    return ef / max_edges;
}

// =============================================================================
// Tests
// =============================================================================

test "modularity: perfect partition" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    // Two disconnected triangles.
    var i: u32 = 0;
    while (i < 6) : (i += 1) _ = try g.addNode({});

    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);
    _ = try g.addEdge(2, 0, 1.0);
    _ = try g.addEdge(0, 2, 1.0);

    _ = try g.addEdge(3, 4, 1.0);
    _ = try g.addEdge(4, 3, 1.0);
    _ = try g.addEdge(4, 5, 1.0);
    _ = try g.addEdge(5, 4, 1.0);
    _ = try g.addEdge(5, 3, 1.0);
    _ = try g.addEdge(3, 5, 1.0);

    var assignments = std.AutoHashMap(u32, usize).init(allocator);
    defer assignments.deinit();
    try assignments.put(0, 0);
    try assignments.put(1, 0);
    try assignments.put(2, 0);
    try assignments.put(3, 1);
    try assignments.put(4, 1);
    try assignments.put(5, 1);

    const q = try modularityUnweighted(allocator, g, assignments);
    // Two disconnected triangles should have high positive modularity.
    try std.testing.expect(q > 0.4);
}

test "countTriangles: triangle" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    try std.testing.expectEqual(@as(usize, 1), try countTriangles(allocator, g));
}

test "clusteringCoefficient: complete graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    const c = try clusteringCoefficient(allocator, g, 0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), c, 0.001);
}

test "density" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    // 3-node complete graph: 6 directed edges, max = 6
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), density(g), 0.001);
}

test "communityDensity" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    const nodes = [_]u32{ 0, 1, 2 };
    const d = try communityDensity(allocator, g, &nodes);
    // Path of 3 nodes: internal directed edges = 4, max directed = 3*2 = 6
    try std.testing.expectApproxEqAbs(@as(f64, 4.0 / 6.0), d, 0.001);
}

test "workspace reuse across multiple calls" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    var workspace = MetricWorkspace(u32).init(allocator);
    defer workspace.deinit();

    const t1 = countTrianglesWithWorkspace(g, &workspace);
    const c0 = clusteringCoefficientWithWorkspace(g, 0, &workspace);
    const c1 = clusteringCoefficientWithWorkspace(g, 1, &workspace);
    const c2 = clusteringCoefficientWithWorkspace(g, 2, &workspace);

    try std.testing.expectEqual(@as(usize, 1), t1);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), c0, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), c1, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), c2, 0.001);
}
