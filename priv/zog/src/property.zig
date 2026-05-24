const std = @import("std");
const utils = @import("utils.zig");
const connectivity = @import("connectivity.zig");
const traversal = @import("traversal.zig");

// =============================================================================
// Cyclicity
// =============================================================================

/// Checks if a directed graph contains at least one cycle.
///
/// Uses `traversal.topologicalSort` under the hood: a cycle exists
/// iff a topological ordering is impossible.
///
/// **Time Complexity:** O(V + E)
pub fn isCyclicDirected(allocator: std.mem.Allocator, graph: anytype) !bool {
    const sorted = traversal.topologicalSort(allocator, graph) catch |err| switch (err) {
        error.NotADAG => return true,
        else => return err,
    };
    allocator.free(sorted);
    return false;
}

/// Checks if an undirected graph contains at least one cycle.
///
/// Uses DFS with parent tracking. Self-loops and parallel edges count as cycles.
/// For directed graphs the behavior follows the underlying undirected structure
/// (edges are traversed without considering direction).
///
/// **Time Complexity:** O(V + E)
pub fn isCyclicUndirected(allocator: std.mem.Allocator, graph: anytype) !bool {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();

    var parent = std.AutoHashMap(NodeId, NodeId).init(allocator);
    defer parent.deinit();

    var start_it = graph.nodeIds();
    while (start_it.next()) |start| {
        if (visited.contains(start)) continue;

        var stack = std.ArrayList(NodeId).empty;
        defer stack.deinit(allocator);

        try stack.append(allocator, start);
        try parent.put(start, start);

        while (stack.items.len > 0) {
            const current = stack.pop().?;
            if (visited.contains(current)) continue;
            try visited.put(current, {});

            const p = parent.get(current).?;

            var succ_it = graph.successors(current);
            while (succ_it.next()) |edge| {
                const next = edge.to;

                // Self-loop is a cycle.
                if (std.meta.eql(current, next)) return true;

                if (visited.contains(next)) {
                    if (!std.meta.eql(next, p)) return true;
                } else {
                    try parent.put(next, current);
                    try stack.append(allocator, next);
                }
            }
        }
    }
    return false;
}

// =============================================================================
// Bipartite
// =============================================================================

/// Result of a bipartite partition.
pub fn BipartitionResult(comptime NodeId: type) type {
    return struct {
        const Self = @This();

        left: []NodeId,
        right: []NodeId,

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.left);
            allocator.free(self.right);
        }
    };
}

/// Checks whether a graph is bipartite (2-colorable).
///
/// Uses BFS coloring. Works on disconnected graphs. For directed graphs
/// the underlying undirected structure is used.
///
/// **Time Complexity:** O(V + E)
pub fn isBipartite(allocator: std.mem.Allocator, graph: anytype) !bool {
    const maybe = try bipartitePartition(allocator, graph);
    if (maybe) |result| {
        result.deinit(allocator);
        return true;
    }
    return false;
}

/// Returns the two partitions of a bipartite graph, or `null` if the graph
/// is not bipartite.
///
/// **Time Complexity:** O(V + E)
pub fn bipartitePartition(allocator: std.mem.Allocator, graph: anytype) !?BipartitionResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var colors = std.AutoHashMap(NodeId, bool).init(allocator);
    defer colors.deinit();

    var left = std.ArrayList(NodeId).empty;
    errdefer left.deinit(allocator);
    var right = std.ArrayList(NodeId).empty;
    errdefer right.deinit(allocator);

    var start_it = graph.nodeIds();
    while (start_it.next()) |start| {
        if (colors.contains(start)) continue;

        var queue = std.ArrayList(NodeId).empty;
        defer queue.deinit(allocator);

        try queue.append(allocator, start);
        try colors.put(start, true);

        var head: usize = 0;
        while (head < queue.items.len) {
            const current = queue.items[head];
            head += 1;
            const color = colors.get(current).?;

            var succ_it = graph.successors(current);
            while (succ_it.next()) |edge| {
                const next = edge.to;
                if (colors.get(next)) |next_color| {
                    if (next_color == color) return null;
                } else {
                    try colors.put(next, !color);
                    try queue.append(allocator, next);
                }
            }
        }
    }

    var it = colors.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.*) {
            try left.append(allocator, entry.key_ptr.*);
        } else {
            try right.append(allocator, entry.key_ptr.*);
        }
    }

    return .{
        .left = try left.toOwnedSlice(allocator),
        .right = try right.toOwnedSlice(allocator),
    };
}

// =============================================================================
// Structure
// =============================================================================

/// Checks whether an undirected graph is a tree (connected and acyclic).
///
/// A tree with `n` nodes has exactly `n - 1` edges and is connected.
/// For directed graphs this will generally return `false` because
/// `edgeCount()` counts directed edges.
///
/// **Time Complexity:** O(V + E)
pub fn isTree(allocator: std.mem.Allocator, graph: anytype) !bool {
    const n = graph.nodeCount();
    if (n == 0) return false;
    const e = graph.edgeCount();
    // Support both undirected GraphMap (e == n-1) and bidirectional ArrayGraph (e == 2(n-1)).
    if (e != n - 1 and e != 2 * (n - 1)) return false;

    var components = try connectivity.connectedComponents(allocator, graph);
    defer components.deinit();

    return components.componentCount() == 1;
}

/// Checks whether the graph is complete.
///
/// For undirected graphs every pair of distinct nodes is connected by an edge.
/// For directed graphs with both directions stored this also returns `true`.
///
/// **Time Complexity:** O(1) (queries node and edge counts only)
pub fn isComplete(graph: anytype) bool {
    const n = graph.nodeCount();
    if (n <= 1) return true;
    const e = graph.edgeCount();
    const undirected_expected = n * (n - 1) / 2;
    const directed_expected = n * (n - 1);
    return e == undirected_expected or e == directed_expected;
}

/// Checks whether the graph is k-regular (every node has out-degree exactly `k`).
///
/// For undirected graphs `outDegree` equals the total degree, so this checks
/// total k-regularity. For directed graphs it checks out-degree regularity.
///
/// **Time Complexity:** O(V)
pub fn isRegular(graph: anytype, k: usize) bool {
    var it = graph.nodeIds();
    while (it.next()) |node| {
        if (graph.outDegree(node) != k) return false;
    }
    return true;
}

/// Checks whether the graph is connected.
///
/// For undirected graphs this checks that all nodes belong to a single
/// connected component. For directed graphs it checks that all nodes are
/// reachable from the first node in iteration order (not strong connectivity).
///
/// **Time Complexity:** O(V + E)
pub fn isConnected(allocator: std.mem.Allocator, graph: anytype) !bool {
    var components = try connectivity.connectedComponents(allocator, graph);
    defer components.deinit();
    return components.componentCount() <= 1;
}

// =============================================================================
// Tests
// =============================================================================

test "isCyclicDirected: DAG" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 2, {});

    try std.testing.expect(!try isCyclicDirected(allocator, g));
}

test "isCyclicDirected: cycle" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 0, {});

    try std.testing.expect(try isCyclicDirected(allocator, g));
}

test "isCyclicUndirected: tree" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    try std.testing.expect(!try isCyclicUndirected(allocator, g));
}

test "isCyclicUndirected: triangle" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

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

    try std.testing.expect(try isCyclicUndirected(allocator, g));
}

test "isBipartite: path graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 3, {});
    _ = try g.addEdge(3, 2, {});

    try std.testing.expect(try isBipartite(allocator, g));
}

test "isBipartite: odd cycle" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

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

    try std.testing.expect(!try isBipartite(allocator, g));
}

test "bipartitePartition" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 3, {});
    _ = try g.addEdge(3, 2, {});

    const result = try bipartitePartition(allocator, g);
    defer if (result) |r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 4), result.?.left.len + result.?.right.len);
}

test "isTree: actual tree" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    // Star: 0 connected to 1,2,3
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(3, 0, {});

    try std.testing.expect(try isTree(allocator, g));
}

test "isTree: cycle is not a tree" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

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

    try std.testing.expect(!try isTree(allocator, g));
}

test "isComplete" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // K3: all pairs connected
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    try std.testing.expect(isComplete(g));
}

test "isRegular" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Cycle C3: each node degree 2
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    try std.testing.expect(isRegular(g, 2));
    try std.testing.expect(!isRegular(g, 1));
}

test "isConnected" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});

    try std.testing.expect(try isConnected(allocator, g));
}

test "isConnected: disconnected" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    // node 2 is isolated

    try std.testing.expect(!try isConnected(allocator, g));
}

// =============================================================================
// Cliques (Bron-Kerbosch)
// =============================================================================

/// Finds all maximal cliques using the Bron-Kerbosch algorithm with pivot optimization.
///
/// **Time Complexity:** O(3^(V/3)) worst case
pub fn allMaximalCliques(allocator: std.mem.Allocator, graph: anytype) ![][]u32 {
    const V = graph.nodeCount();
    if (V == 0) return &[_][]u32{};

    // Pre-allocate bitsets for recursive stack to avoid any allocations in recursive loops
    var P_depth = try allocator.alloc(std.DynamicBitSet, V + 1);
    defer allocator.free(P_depth);
    var X_depth = try allocator.alloc(std.DynamicBitSet, V + 1);
    defer allocator.free(X_depth);

    for (0..V + 1) |d| {
        P_depth[d] = try std.DynamicBitSet.initEmpty(allocator, V);
        X_depth[d] = try std.DynamicBitSet.initEmpty(allocator, V);
    }
    defer {
        for (0..V + 1) |d| {
            P_depth[d].deinit();
            X_depth[d].deinit();
        }
    }

    var R = try std.DynamicBitSet.initEmpty(allocator, V);
    defer R.deinit();

    // Adjacency bitsets for O(1) intersection
    var neighbors = try allocator.alloc(std.DynamicBitSet, V);
    defer allocator.free(neighbors);
    for (0..V) |i| {
        neighbors[i] = try std.DynamicBitSet.initEmpty(allocator, V);
    }
    defer {
        for (0..V) |i| {
            neighbors[i].deinit();
        }
    }

    // Populate neighbor bitsets
    var start_it = graph.nodeIds();
    while (start_it.next()) |u| {
        var succ_it = graph.successors(u);
        while (succ_it.next()) |edge| {
            const v = edge.to;
            if (u != v) {
                neighbors[u].set(v);
                neighbors[v].set(u);
            }
        }
    }

    // Initialize depth 0
    for (0..V) |i| {
        P_depth[0].set(i);
    }

    var cliques = std.ArrayList([]u32).empty;
    errdefer {
        for (cliques.items) |c| {
            allocator.free(c);
        }
        cliques.deinit(allocator);
    }

    const Context = struct {
        allocator: std.mem.Allocator,
        V: usize,
        neighbors: []std.DynamicBitSet,
        P_depth: []std.DynamicBitSet,
        X_depth: []std.DynamicBitSet,
        R: *std.DynamicBitSet,
        cliques: *std.ArrayList([]u32),

        fn recurse(self: *@This(), depth: usize) !void {
            const p = &self.P_depth[depth];
            const x = &self.X_depth[depth];

            if (p.count() == 0 and x.count() == 0) {
                // Found a maximal clique!
                if (self.R.count() > 0) {
                    var clique = try self.allocator.alloc(u32, self.R.count());
                    errdefer self.allocator.free(clique);

                    var it = self.R.iterator(.{});
                    var idx: usize = 0;
                    while (it.next()) |node_idx| {
                        clique[idx] = @intCast(node_idx);
                        idx += 1;
                    }
                    try self.cliques.append(self.allocator, clique);
                }
                return;
            }

            if (p.count() == 0) return;

            // Choose pivot u from P union X maximizing |P intersection N(u)|
            var pivot: ?usize = null;
            var max_intersect: usize = 0;

            var p_it = p.iterator(.{});
            while (p_it.next()) |u| {
                var intersect_count: usize = 0;
                var n_it = self.neighbors[u].iterator(.{});
                while (n_it.next()) |v| {
                    if (p.isSet(v)) {
                        intersect_count += 1;
                    }
                }
                if (pivot == null or intersect_count >= max_intersect) {
                    pivot = u;
                    max_intersect = intersect_count;
                }
            }

            var x_it = x.iterator(.{});
            while (x_it.next()) |u| {
                var intersect_count: usize = 0;
                var n_it = self.neighbors[u].iterator(.{});
                while (n_it.next()) |v| {
                    if (p.isSet(v)) {
                        intersect_count += 1;
                    }
                }
                if (pivot == null or intersect_count > max_intersect) {
                    pivot = u;
                    max_intersect = intersect_count;
                }
            }

            // Candidates to explore: P \ N(pivot)
            var candidates = try std.DynamicBitSet.initEmpty(self.allocator, self.V);
            defer candidates.deinit();

            var p_copy_it = p.iterator(.{});
            while (p_copy_it.next()) |u| {
                candidates.set(u);
            }

            if (pivot) |pv| {
                var n_it = self.neighbors[pv].iterator(.{});
                while (n_it.next()) |v| {
                    candidates.unset(v);
                }
            }

            var cand_it = candidates.iterator(.{});
            while (cand_it.next()) |v| {
                self.R.set(v);

                const next_p = &self.P_depth[depth + 1];
                const next_x = &self.X_depth[depth + 1];

                const num_masks = (self.V + (@bitSizeOf(std.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.DynamicBitSet.MaskInt);
                @memcpy(next_p.unmanaged.masks[0..num_masks], p.unmanaged.masks[0..num_masks]);
                next_p.setIntersection(self.neighbors[v]);

                @memcpy(next_x.unmanaged.masks[0..num_masks], x.unmanaged.masks[0..num_masks]);
                next_x.setIntersection(self.neighbors[v]);

                try self.recurse(depth + 1);

                self.R.unset(v);

                p.unset(v);
                x.set(v);
            }
        }
    };

    var context = Context{
        .allocator = allocator,
        .V = V,
        .neighbors = neighbors,
        .P_depth = P_depth,
        .X_depth = X_depth,
        .R = &R,
        .cliques = &cliques,
    };

    try context.recurse(0);

    return cliques.toOwnedSlice(allocator);
}

test "allMaximalCliques: complete graph K4" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(3, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(1, 3, {});
    _ = try g.addEdge(3, 1, {});
    _ = try g.addEdge(2, 3, {});
    _ = try g.addEdge(3, 2, {});

    const cliques = try allMaximalCliques(allocator, g);
    defer {
        for (cliques) |c| {
            allocator.free(c);
        }
        allocator.free(cliques);
    }

    try std.testing.expectEqual(@as(usize, 1), cliques.len);
    try std.testing.expectEqual(@as(usize, 4), cliques[0].len);
}

test "allMaximalCliques: disjoint triangles" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    // Triangle 1: 0-1-2
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Triangle 2: 3-4-5
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, {}); _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {}); _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {}); _ = try g.addEdge(0, 2, {});

    _ = try g.addEdge(3, 4, {}); _ = try g.addEdge(4, 3, {});
    _ = try g.addEdge(4, 5, {}); _ = try g.addEdge(5, 4, {});
    _ = try g.addEdge(5, 3, {}); _ = try g.addEdge(3, 5, {});

    const cliques = try allMaximalCliques(allocator, g);
    defer {
        for (cliques) |c| {
            allocator.free(c);
        }
        allocator.free(cliques);
    }

    try std.testing.expectEqual(@as(usize, 2), cliques.len);
}

