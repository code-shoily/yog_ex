const std = @import("std");
const utils = @import("utils.zig");
const sssp = @import("pathfinding/sssp.zig");

// =============================================================================
// Distance Metrics
// =============================================================================

/// Eccentricity is the maximum distance from `node` to all other nodes.
///
/// Returns `null` if the node cannot reach all other nodes (disconnected graph).
///
/// **Time Complexity:** O((V+E) log V)
pub fn eccentricity(
    allocator: std.mem.Allocator,
    graph: anytype,
    node: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !?Weight {
    var node_count: usize = 0;
    var it = graph.nodeIds();
    while (it.next()) |_| node_count += 1;

    if (node_count <= 1) return zero;

    var result = try sssp.singleSourceDistances(
        allocator,
        graph,
        node,
        Weight,
        zero,
        addFn,
        compareFn,
        null,
    );
    defer result.deinit(allocator);

    if (result.count() != node_count) return null;

    var max_dist = zero;
    for (result.dists) |d| {
        if (d) |val| {
            if (compareFn(val, max_dist) == .gt) {
                max_dist = val;
            }
        }
    }

    return max_dist;
}

/// The diameter is the maximum eccentricity across all nodes.
///
/// Returns `null` if the graph is disconnected or empty.
///
/// **Time Complexity:** O(V × (V+E) log V)
pub fn diameter(
    allocator: std.mem.Allocator,
    graph: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !?Weight {
    var max_ecc: ?Weight = null;

    var it = graph.nodeIds();
    while (it.next()) |node| {
        const ecc = try eccentricity(allocator, graph, node, Weight, zero, addFn, compareFn);
        if (ecc == null) return null;

        if (max_ecc == null or compareFn(ecc.?, max_ecc.?) == .gt) {
            max_ecc = ecc.?;
        }
    }

    return max_ecc;
}

/// The radius is the minimum eccentricity across all nodes.
///
/// Returns `null` if the graph is disconnected or empty.
///
/// **Time Complexity:** O(V × (V+E) log V)
pub fn radius(
    allocator: std.mem.Allocator,
    graph: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !?Weight {
    var min_ecc: ?Weight = null;

    var it = graph.nodeIds();
    while (it.next()) |node| {
        const ecc = try eccentricity(allocator, graph, node, Weight, zero, addFn, compareFn);
        if (ecc == null) return null;

        if (min_ecc == null or compareFn(ecc.?, min_ecc.?) == .lt) {
            min_ecc = ecc.?;
        }
    }

    return min_ecc;
}

// =============================================================================
// Assortativity
// =============================================================================

/// Assortativity coefficient measures degree correlation.
///
/// Returns a value in the range `[-1, 1]` where:
/// - Positive: high-degree nodes connect to other high-degree nodes
/// - Negative: high-degree nodes connect to low-degree nodes
/// - Zero: random mixing or regular graph
///
/// **Time Complexity:** O(V + E)
pub fn assortativity(allocator: std.mem.Allocator, graph: anytype) !f64 {
    const NodeId = utils.NodeId(@TypeOf(graph));

    // Compute out-degree of each node.
    var degrees = std.AutoHashMap(NodeId, usize).init(allocator);
    defer degrees.deinit();

    var nit = graph.nodeIds();
    while (nit.next()) |u| {
        var deg: usize = 0;
        var it = graph.successors(u);
        while (it.next()) |_| {
            deg += 1;
        }
        try degrees.put(u, deg);
    }

    var sum_jk: f64 = 0.0;
    var sum_j: f64 = 0.0;
    var sum_k: f64 = 0.0;
    var sum_j_sq: f64 = 0.0;
    var sum_k_sq: f64 = 0.0;
    var edge_count: usize = 0;

    nit = graph.nodeIds();
    while (nit.next()) |u| {
        const du = degrees.get(u) orelse 0;
        var it = graph.successors(u);
        while (it.next()) |edge| {
            const v = edge.to;
            const dv = degrees.get(v) orelse 0;
            const jf = @as(f64, @floatFromInt(du));
            const kf = @as(f64, @floatFromInt(dv));

            sum_jk += jf * kf;
            sum_j += jf;
            sum_k += kf;
            sum_j_sq += jf * jf;
            sum_k_sq += kf * kf;
            edge_count += 1;
        }
    }

    if (edge_count == 0) return 0.0;

    const m = @as(f64, @floatFromInt(edge_count));
    const mean_j = sum_j / m;
    const mean_k = sum_k / m;
    const numerator = sum_jk / m - mean_j * mean_k;

    const denom_j = sum_j_sq / m - mean_j * mean_j;
    const denom_k = sum_k_sq / m - mean_k * mean_k;
    const denom_product = denom_j * denom_k;

    if (denom_product <= 0.0) return 0.0;
    const denominator = std.math.sqrt(denom_product);

    return numerator / denominator;
}

// =============================================================================
// Average Path Length
// =============================================================================

/// Average shortest path length across all node pairs.
///
/// Returns `null` if the graph is disconnected or has fewer than 2 nodes.
///
/// **Time Complexity:** O(V × (V+E) log V)
pub fn averagePathLength(
    allocator: std.mem.Allocator,
    graph: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
    toFloat: fn (Weight) f64,
) !?f64 {
    var node_count: usize = 0;
    var nit = graph.nodeIds();
    while (nit.next()) |_| node_count += 1;

    if (node_count <= 1) return null;

    var total: f64 = 0.0;

    nit = graph.nodeIds();
    while (nit.next()) |node| {
        var result = try sssp.singleSourceDistances(
            allocator,
            graph,
            node,
            Weight,
            zero,
            addFn,
            compareFn,
            null,
        );
        defer result.deinit(allocator);

        if (result.count() != node_count) return null;

        for (result.dists) |d| {
            if (d) |val| total += toFloat(val);
        }
    }

    // Subtract self-distances (zero) from total.
    const zero_distances = @as(f64, @floatFromInt(node_count)) * toFloat(zero);
    const num_pairs = @as(f64, @floatFromInt(node_count * (node_count - 1)));
    return (total - zero_distances) / num_pairs;
}

// =============================================================================
// Convenience Wrappers (f64)
// =============================================================================

/// Eccentricity for `f64` weights.
pub fn eccentricityF64(allocator: std.mem.Allocator, graph: anytype, node: anytype) !?f64 {
    return eccentricity(allocator, graph, node, f64, 0.0, utils.addF64, utils.compareF64);
}

/// Diameter for `f64` weights.
pub fn diameterF64(allocator: std.mem.Allocator, graph: anytype) !?f64 {
    return diameter(allocator, graph, f64, 0.0, utils.addF64, utils.compareF64);
}

/// Radius for `f64` weights.
pub fn radiusF64(allocator: std.mem.Allocator, graph: anytype) !?f64 {
    return radius(allocator, graph, f64, 0.0, utils.addF64, utils.compareF64);
}

/// Average path length for `f64` weights.
pub fn averagePathLengthF64(allocator: std.mem.Allocator, graph: anytype) !?f64 {
    return averagePathLength(allocator, graph, f64, 0.0, utils.addF64, utils.compareF64, utils.identityF64);
}

// =============================================================================
// Tests
// =============================================================================

test "eccentricity on bidirectional chain" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // 0 <-> 1 <-> 2
    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);

    const e0 = try eccentricityF64(allocator, g, @as(u32, 0));
    try std.testing.expectEqual(@as(f64, 2.0), e0.?);

    const e1 = try eccentricityF64(allocator, g, @as(u32, 1));
    try std.testing.expectEqual(@as(f64, 1.0), e1.?);

    const e2 = try eccentricityF64(allocator, g, @as(u32, 2));
    try std.testing.expectEqual(@as(f64, 2.0), e2.?);
}

test "eccentricity on disconnected graph returns null" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});

    // No edges
    const e = try eccentricityF64(allocator, g, @as(u32, 0));
    try std.testing.expect(e == null);
}

test "diameter and radius on complete graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Complete graph with bidirectional edges
    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(0, 2, 1.0);
    _ = try g.addEdge(2, 0, 1.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);

    const diam = try diameterF64(allocator, g);
    const rad = try radiusF64(allocator, g);

    try std.testing.expectEqual(@as(f64, 1.0), diam.?);
    try std.testing.expectEqual(@as(f64, 1.0), rad.?);
}

test "diameter and radius on bidirectional chain" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // 0 <-> 1 <-> 2 <-> 3
    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);
    _ = try g.addEdge(2, 3, 1.0);
    _ = try g.addEdge(3, 2, 1.0);

    const diam = try diameterF64(allocator, g);
    const rad = try radiusF64(allocator, g);

    try std.testing.expectEqual(@as(f64, 3.0), diam.?);
    try std.testing.expectEqual(@as(f64, 2.0), rad.?);
}

test "assortativity on undirected star graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Undirected star: 0 <-> 1,2,3,4
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(3, 0, {});
    _ = try g.addEdge(0, 4, {});
    _ = try g.addEdge(4, 0, {});

    const r = try assortativity(allocator, g);
    // Undirected star is disassortative
    try std.testing.expect(r < 0.0);
}

test "assortativity on complete graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Complete graph: all nodes have same degree
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    const r = try assortativity(allocator, g);
    // All nodes have same degree => denominator is zero => returns 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), r, 0.001);
}

test "averagePathLength on triangle" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Triangle with bidirectional edges
    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);
    _ = try g.addEdge(2, 0, 1.0);
    _ = try g.addEdge(0, 2, 1.0);

    const apl = try averagePathLengthF64(allocator, g);
    // 3 nodes, all pairs have distance 1 => average = 1
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), apl.?, 0.001);
}

test "averagePathLength on disconnected graph returns null" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});

    // No edges
    const apl = try averagePathLengthF64(allocator, g);
    try std.testing.expect(apl == null);
}
