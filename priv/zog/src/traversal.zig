const std = @import("std");
const utils = @import("utils.zig");

/// Computes a topological sort of a directed graph.
/// Returns a list of node IDs such that for every directed edge U -> V,
/// U appears before V in the list.
///
/// Returns `error.NotADAG` if the graph contains a cycle.
///
/// **Time Complexity:** O(V + E)
pub fn topologicalSort(allocator: std.mem.Allocator, graph: anytype) ![]utils.NodeId(@TypeOf(graph)) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    var in_degrees = std.AutoHashMap(NodeId, usize).init(allocator);
    defer in_degrees.deinit();

    // Initialize in-degrees
    for (nodes.items) |node| {
        try in_degrees.put(node, 0);
    }

    // Compute in-degrees
    for (nodes.items) |node| {
        var sit = graph.successors(node);
        while (sit.next()) |edge| {
            const gop = try in_degrees.getOrPut(edge.to);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
        }
    }

    var queue = std.ArrayList(NodeId).empty;
    defer queue.deinit(allocator);

    var result = std.ArrayList(NodeId).empty;
    errdefer result.deinit(allocator);

    var it = in_degrees.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* == 0) {
            try queue.append(allocator, entry.key_ptr.*);
        }
    }

    // Process nodes with zero in-degree
    var head: usize = 0;
    while (head < queue.items.len) {
        const u = queue.items[head];
        head += 1;
        try result.append(allocator, u);

        var sit = graph.successors(u);
        while (sit.next()) |edge| {
            const v = edge.to;
            if (in_degrees.getPtr(v)) |deg| {
                deg.* -= 1;
                if (deg.* == 0) {
                    try queue.append(allocator, v);
                }
            }
        }
    }

    if (result.items.len != nodes.items.len) {
        return error.NotADAG;
    }

    return result.toOwnedSlice(allocator);
}

// --- Tests ---

test "topologicalSort: simple DAG" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, void).init(allocator);
    defer g.deinit();

    const n0 = try g.addNode({});
    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    _ = try g.addEdge(n0, n1, {});
    _ = try g.addEdge(n1, n2, {});

    const result = try topologicalSort(allocator, g);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(n0, result[0]);
    try std.testing.expectEqual(n1, result[1]);
    try std.testing.expectEqual(n2, result[2]);
}

test "topologicalSort: detects cycle" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, void).init(allocator);
    defer g.deinit();

    const n0 = try g.addNode({});
    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    _ = try g.addEdge(n0, n1, {});
    _ = try g.addEdge(n1, n2, {});
    _ = try g.addEdge(n2, n0, {});

    const result = topologicalSort(allocator, g);
    try std.testing.expectError(error.NotADAG, result);
}
