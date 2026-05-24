const std = @import("std");
const utils = @import("utils.zig");
const DisjointSet = @import("disjoint_set.zig").DisjointSet;

/// An edge in the minimum spanning tree result.
pub fn Edge(comptime NodeId: type, comptime Weight: type) type {
    return struct {
        from: NodeId,
        to: NodeId,
        weight: Weight,
    };
}

/// Result of a Minimum Spanning Tree computation.
pub fn MstResult(comptime NodeId: type, comptime Weight: type) type {
    return struct {
        const Self = @This();

        edges: []Edge(NodeId, Weight),
        total_weight: Weight,
        node_count: usize,
        edge_count: usize,

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.edges);
        }
    };
}

/// Finds the Minimum Spanning Tree using Kruskal's algorithm.
///
/// **Time Complexity:** O(E log E)
///
/// The graph's `EdgeData` is used directly as the weight.
/// For disconnected graphs, returns a Minimum Spanning Forest.
pub fn kruskal(
    allocator: std.mem.Allocator,
    graph: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !MstResult(utils.NodeId(@TypeOf(graph)), Weight) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const E = Edge(NodeId, Weight);

    // Extract all edges from the graph.
    var all_edges = std.ArrayList(E).empty;
    defer all_edges.deinit(allocator);

    var node_it = graph.nodeIds();
    while (node_it.next()) |from| {
        var succ_it = graph.successors(from);
        while (succ_it.next()) |e| {
            try all_edges.append(allocator, .{
                .from = from,
                .to = e.to,
                .weight = e.data,
            });
        }
    }

    // Sort edges by weight (ascending).
    std.mem.sort(E, all_edges.items, {}, struct {
        fn lessThan(_: void, a: E, b: E) bool {
            return compareFn(a.weight, b.weight) == .lt;
        }
    }.lessThan);

    var dsu = DisjointSet(NodeId).init(allocator);
    defer dsu.deinit();

    var mst_edges = std.ArrayList(E).empty;
    defer mst_edges.deinit(allocator);

    var total_weight = zero;
    const max_edges = if (graph.nodeCount() > 0) graph.nodeCount() - 1 else 0;

    for (all_edges.items) |e| {
        if (try dsu.merge(e.from, e.to)) {
            try mst_edges.append(allocator, e);
            total_weight = addFn(total_weight, e.weight);
            if (mst_edges.items.len >= max_edges) break;
        }
    }

    const edges = try mst_edges.toOwnedSlice(allocator);

    return .{
        .edges = edges,
        .total_weight = total_weight,
        .node_count = graph.nodeCount(),
        .edge_count = edges.len,
    };
}

/// Finds the Minimum Spanning Tree using Prim's algorithm.
///
/// **Time Complexity:** O(E log V)
///
/// Starts from `start` and only covers its connected component.
/// The graph's `EdgeData` is used directly as the weight.
pub fn prim(
    allocator: std.mem.Allocator,
    graph: anytype,
    start: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !MstResult(utils.NodeId(@TypeOf(graph)), Weight) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const E = Edge(NodeId, Weight);

    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();

    var mst_edges = std.ArrayList(E).empty;
    defer mst_edges.deinit(allocator);

    const PQ = std.PriorityQueue(E, void, struct {
        fn lessThan(_: void, a: E, b: E) std.math.Order {
            return compareFn(a.weight, b.weight);
        }
    }.lessThan);

    var pq = PQ.init(allocator, {});
    defer pq.deinit();

    var total_weight = zero;

    try visited.put(start, {});

    var succ_it = graph.successors(start);
    while (succ_it.next()) |e| {
        try pq.add(.{
            .from = start,
            .to = e.to,
            .weight = e.data,
        });
    }

    while (pq.count() > 0) {
        const edge = pq.remove();

        if (visited.contains(edge.to)) continue;

        try visited.put(edge.to, {});
        try mst_edges.append(allocator, edge);
        total_weight = addFn(total_weight, edge.weight);

        var next_it = graph.successors(edge.to);
        while (next_it.next()) |e| {
            if (!visited.contains(e.to)) {
                try pq.add(.{
                    .from = edge.to,
                    .to = e.to,
                    .weight = e.data,
                });
            }
        }
    }

    const edges = try mst_edges.toOwnedSlice(allocator);

    return .{
        .edges = edges,
        .total_weight = total_weight,
        .node_count = graph.nodeCount(),
        .edge_count = edges.len,
    };
}



// --- Helpers ---

// --- Tests ---

test "Kruskal on simple undirected graph (ArrayGraph)" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    // 4 nodes
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Undirected edges: add both directions
    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(0, 2, 3.0);
    _ = try g.addEdge(2, 0, 3.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);
    _ = try g.addEdge(1, 3, 4.0);
    _ = try g.addEdge(3, 1, 4.0);
    _ = try g.addEdge(2, 3, 2.0);
    _ = try g.addEdge(3, 2, 2.0);

    var result = try kruskal(allocator, g, f64, 0.0, utils.addF64, utils.compareF64);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), result.node_count);
    try std.testing.expectEqual(@as(usize, 3), result.edge_count);
    try std.testing.expectApproxEqAbs(@as(f64, 4.0), result.total_weight, 0.001);
}

test "Prim on simple undirected graph (ArrayGraph)" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 0, 1.0);
    _ = try g.addEdge(0, 2, 3.0);
    _ = try g.addEdge(2, 0, 3.0);
    _ = try g.addEdge(1, 2, 1.0);
    _ = try g.addEdge(2, 1, 1.0);
    _ = try g.addEdge(1, 3, 4.0);
    _ = try g.addEdge(3, 1, 4.0);
    _ = try g.addEdge(2, 3, 2.0);
    _ = try g.addEdge(3, 2, 2.0);

    var result = try prim(allocator, g, @as(u32, 0), f64, 0.0, utils.addF64, utils.compareF64);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), result.node_count);
    try std.testing.expectEqual(@as(usize, 3), result.edge_count);
    try std.testing.expectApproxEqAbs(@as(f64, 4.0), result.total_weight, 0.001);
}

test "Kruskal and Prim agree on total weight" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Create a more complex graph
    _ = try g.addEdge(0, 1, 2.0);
    _ = try g.addEdge(1, 0, 2.0);
    _ = try g.addEdge(0, 3, 6.0);
    _ = try g.addEdge(3, 0, 6.0);
    _ = try g.addEdge(1, 2, 3.0);
    _ = try g.addEdge(2, 1, 3.0);
    _ = try g.addEdge(1, 3, 8.0);
    _ = try g.addEdge(3, 1, 8.0);
    _ = try g.addEdge(1, 4, 5.0);
    _ = try g.addEdge(4, 1, 5.0);
    _ = try g.addEdge(2, 4, 7.0);
    _ = try g.addEdge(4, 2, 7.0);
    _ = try g.addEdge(3, 4, 9.0);
    _ = try g.addEdge(4, 3, 9.0);

    var kruskal_result = try kruskal(allocator, g, f64, 0.0, utils.addF64, utils.compareF64);
    defer kruskal_result.deinit(allocator);

    var prim_result = try prim(allocator, g, @as(u32, 0), f64, 0.0, utils.addF64, utils.compareF64);
    defer prim_result.deinit(allocator);

    try std.testing.expectApproxEqAbs(kruskal_result.total_weight, prim_result.total_weight, 0.001);
    try std.testing.expectEqual(@as(usize, 4), kruskal_result.edge_count);
    try std.testing.expectEqual(@as(usize, 4), prim_result.edge_count);
}

test "Kruskal on empty graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    var result = try kruskal(allocator, g, f64, 0.0, utils.addF64, utils.compareF64);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), result.node_count);
    try std.testing.expectEqual(@as(usize, 0), result.edge_count);
    try std.testing.expectEqual(@as(f64, 0.0), result.total_weight);
}

test "Prim on single-node graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});

    var result = try prim(allocator, g, @as(u32, 0), f64, 0.0, utils.addF64, utils.compareF64);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), result.node_count);
    try std.testing.expectEqual(@as(usize, 0), result.edge_count);
    try std.testing.expectEqual(@as(f64, 0.0), result.total_weight);
}

test "Kruskal with GraphMap (u32 nodes)" {
    const allocator = std.testing.allocator;
    const GM = @import("models/graph_map.zig").GraphMap;
    const Direction = @import("models/graph_map.zig").Direction;
    const Storage = @import("models/graph_map.zig").Storage;

    var g = GM(u32, void, f64, Direction.directed, Storage.single).init(allocator);
    defer g.deinit();

    try g.addNode(0, {});
    try g.addNode(1, {});
    try g.addNode(2, {});

    try g.addEdge(0, 1, 1.0);
    try g.addEdge(1, 0, 1.0);
    try g.addEdge(1, 2, 2.0);
    try g.addEdge(2, 1, 2.0);
    try g.addEdge(0, 2, 5.0);
    try g.addEdge(2, 0, 5.0);

    var result = try kruskal(allocator, g, f64, 0.0, utils.addF64, utils.compareF64);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), result.node_count);
    try std.testing.expectEqual(@as(usize, 2), result.edge_count);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result.total_weight, 0.001);
}
