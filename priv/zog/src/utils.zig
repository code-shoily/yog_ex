const std = @import("std");

// =============================================================================
// Shared f64 Weight Helpers
// =============================================================================

/// Adds two f64 values (used as generic weight addition).
pub fn addF64(a: f64, b: f64) f64 {
    return a + b;
}

/// Subtracts two f64 values (used for potential adjustments).
pub fn subF64(a: f64, b: f64) f64 {
    return a - b;
}

/// Compares two f64 values by natural ordering.
pub fn compareF64(a: f64, b: f64) std.math.Order {
    return std.math.order(a, b);
}

/// Identity function for f64 (used for weight extraction).
pub fn identityF64(x: f64) f64 {
    return x;
}

// =============================================================================
// Graph Type Helpers
// =============================================================================

/// Extracts the NodeId type from a generic Graph type.
pub fn NodeId(comptime GraphType: type) type {
    return @TypeOf(@as(GraphType.Edge, undefined).to);
}

/// Convenience alias for an ArrayList of NodeIds.
pub fn NodeList(comptime GraphType: type) type {
    return std.ArrayList(NodeId(GraphType));
}

/// Collects all node IDs from a graph into an ArrayList.
pub fn collectNodes(allocator: std.mem.Allocator, graph: anytype) !NodeList(@TypeOf(graph)) {
    var nodes = NodeList(@TypeOf(graph)).empty;
    errdefer nodes.deinit(allocator);
    var it = graph.nodeIds();
    while (it.next()) |node| try nodes.append(allocator, node);
    return nodes;
}

/// Builds a mapping of NodeId -> list of in-neighbors for the given nodes in the graph.
/// (Helpful for algorithms like PageRank that require reverse traversal on generic directed graphs)
pub fn buildInNeighbors(
    allocator: std.mem.Allocator,
    graph: anytype,
    nodes: []const NodeId(@TypeOf(graph)),
) !std.AutoHashMap(NodeId(@TypeOf(graph)), NodeList(@TypeOf(graph))) {
    const NId = NodeId(@TypeOf(graph));
    var in_neighbors = std.AutoHashMap(NId, NodeList(@TypeOf(graph))).init(allocator);
    errdefer freeInNeighbors(allocator, &in_neighbors);

    for (nodes) |node| {
        var sit = graph.successors(node);
        while (sit.next()) |edge| {
            const to = edge.to;
            const gop = try in_neighbors.getOrPut(to);
            if (!gop.found_existing) {
                gop.value_ptr.* = NodeList(@TypeOf(graph)).empty;
            }
            try gop.value_ptr.append(allocator, node);
        }
    }
    return in_neighbors;
}

/// Helper to free an in-neighbors map.
pub fn freeInNeighbors(
    allocator: std.mem.Allocator,
    in_neighbors: anytype,
) void {
    var iit = in_neighbors.valueIterator();
    while (iit.next()) |list| {
        list.deinit(allocator);
    }
    in_neighbors.deinit();
}


