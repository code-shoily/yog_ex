const std = @import("std");
const utils = @import("utils.zig");

/// Breadth-First Search.
/// Traverses the graph starting from 'start_node' and calls 'visitor' for each node.
/// If 'visitor' returns false, the traversal stops.
///
/// 'graph' must implement .successors(node_id) which returns an iterator with a .next() method.
pub fn bfs(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    context: anytype,
    visitor: fn (ctx: @TypeOf(context), node: @TypeOf(start_node)) bool,
) !void {
    const NodeId = @TypeOf(start_node);
    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();

    var queue = std.ArrayList(NodeId).empty;
    defer queue.deinit(allocator);

    try visited.put(start_node, {});
    try queue.append(allocator, start_node);

    var head: usize = 0;
    while (head < queue.items.len) {
        const current = queue.items[head];
        head += 1;

        if (!visitor(context, current)) break;

        // Use the unified Iterator pattern
        var it = graph.successors(current);
        while (it.next()) |edge| {
            const res = try visited.getOrPut(edge.to);
            if (!res.found_existing) {
                try queue.append(allocator, edge.to);
            }
        }
    }
}

/// Depth-First Search (Iterative).
pub fn dfs(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    context: anytype,
    visitor: fn (ctx: @TypeOf(context), node: @TypeOf(start_node)) bool,
    visited_opt: ?*std.AutoHashMap(@TypeOf(start_node), void),
) !void {
    const NodeId = @TypeOf(start_node);
    var local_visited: std.AutoHashMap(NodeId, void) = undefined;
    if (visited_opt == null) {
        local_visited = std.AutoHashMap(NodeId, void).init(allocator);
    }
    defer if (visited_opt == null) local_visited.deinit();
    const visited = visited_opt orelse &local_visited;

    var stack = std.ArrayList(NodeId).empty;
    defer stack.deinit(allocator);

    try stack.append(allocator, start_node);

    while (stack.items.len > 0) {
        const current = stack.items[stack.items.len - 1];
        stack.items.len -= 1;

        const res = try visited.getOrPut(current);
        if (res.found_existing) continue;

        if (!visitor(context, current)) break;

        var it = graph.successors(current);
        while (it.next()) |edge| {
            if (!visited.contains(edge.to)) {
                try stack.append(allocator, edge.to);
            }
        }
    }
}

/// Callbacks for advanced DFS traversal.
pub fn DfsCallbacks(comptime NodeId: type, comptime ContextType: type) type {
    return struct {
        onDiscover: ?*const fn (ctx: ContextType, u: NodeId) anyerror!void = null,
        onFinish: ?*const fn (ctx: ContextType, u: NodeId, p: ?NodeId) anyerror!void = null,
        onTreeEdge: ?*const fn (ctx: ContextType, u: NodeId, v: NodeId) anyerror!void = null,
        onBackEdge: ?*const fn (ctx: ContextType, u: NodeId, v: NodeId) anyerror!void = null,
        onForwardOrCrossEdge: ?*const fn (ctx: ContextType, u: NodeId, v: NodeId) anyerror!void = null,
    };
}

/// Status of a node during DFS.
pub const DfsStatus = enum { unvisited, visiting, visited };

/// Advanced Depth-First Search (Iterative).
/// Supports pre-order, post-order, and edge classification.
pub fn dfsAdvanced(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    context: anytype,
    callbacks: DfsCallbacks(@TypeOf(start_node), @TypeOf(context)),
    status_map_opt: ?*std.AutoHashMap(@TypeOf(start_node), DfsStatus),
) !void {
    const NodeId = @TypeOf(start_node);
    var local_status: std.AutoHashMap(NodeId, DfsStatus) = undefined;
    if (status_map_opt == null) {
        local_status = std.AutoHashMap(NodeId, DfsStatus).init(allocator);
    }
    defer if (status_map_opt == null) local_status.deinit();
    const status_map = status_map_opt orelse &local_status;

    const SuccIt = @TypeOf(graph.successors(start_node));
    const Frame = struct {
        u: NodeId,
        p: ?NodeId,
        it: SuccIt,
    };

    var stack = std.ArrayList(Frame).empty;
    defer stack.deinit(allocator);

    // Initial discovery
    try status_map.put(start_node, .visiting);
    if (callbacks.onDiscover) |f| try f(context, start_node);
    try stack.append(allocator, .{
        .u = start_node,
        .p = null,
        .it = graph.successors(start_node),
    });

    while (stack.items.len > 0) {
        const frame = &stack.items[stack.items.len - 1];

        if (frame.it.next()) |edge| {
            const v = edge.to;
            const v_status = status_map.get(v) orelse .unvisited;

            switch (v_status) {
                .unvisited => {
                    if (callbacks.onTreeEdge) |f| try f(context, frame.u, v);
                    try status_map.put(v, .visiting);
                    if (callbacks.onDiscover) |f| try f(context, v);
                    try stack.append(allocator, .{
                        .u = v,
                        .p = frame.u,
                        .it = graph.successors(v),
                    });
                },
                .visiting => {
                    if (frame.p != null and std.meta.eql(v, frame.p.?)) continue;
                    if (callbacks.onBackEdge) |f| try f(context, frame.u, v);
                },
                .visited => {
                    if (callbacks.onForwardOrCrossEdge) |f| try f(context, frame.u, v);
                },
            }
        } else {
            const finished = stack.items[stack.items.len - 1];
            stack.items.len -= 1;
            try status_map.put(finished.u, .visited);
            if (callbacks.onFinish) |f| try f(context, finished.u, finished.p);
        }
    }
}

/// Best-First Search.
/// Greedy traversal that always expands the node that looks closest to the goal
/// according to the provided heuristic.
///
/// Uses a min-heap for O(log N) extraction instead of O(N) linear scan.
///
/// 'heuristic' should return a lower score for "better" nodes.
pub fn bestFirstSearch(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
    context: anytype,
    heuristic: fn (ctx: @TypeOf(context), node: @TypeOf(start_node)) f64,
) !?@TypeOf(start_node) {
    const NodeId = @TypeOf(start_node);

    const Entry = struct {
        node: NodeId,
        score: f64,
    };

    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();

    var frontier = std.PriorityQueue(Entry, void, struct {
        fn compare(_: void, a: Entry, b: Entry) std.math.Order {
            return std.math.order(a.score, b.score);
        }
    }.compare).init(allocator, {});
    defer frontier.deinit();

    try visited.put(start_node, {});
    try frontier.add(.{ .node = start_node, .score = heuristic(context, start_node) });

    while (true) {
        const entry = frontier.removeOrNull() orelse break;
        if (std.meta.eql(entry.node, goal_node)) return entry.node;

        var it = graph.successors(entry.node);
        while (it.next()) |edge| {
            const res = try visited.getOrPut(edge.to);
            if (!res.found_existing) {
                try frontier.add(.{ .node = edge.to, .score = heuristic(context, edge.to) });
            }
        }
    }

    return null;
}

/// Random Walk.
/// Starting from 'start_node', takes 'steps' random moves through the graph.
/// Returns the final node reached, or null if stuck before completing all steps.
///
/// 'random' must implement .intRangeLessThan(comptime T, less_than: T) T
pub fn randomWalk(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    steps: usize,
    random: anytype,
) !?@TypeOf(start_node) {
    const NodeId = @TypeOf(start_node);
    var current = start_node;

    var neighbors = std.ArrayList(NodeId).empty;
    defer neighbors.deinit(allocator);

    var step: usize = 0;
    while (step < steps) : (step += 1) {
        neighbors.clearRetainingCapacity();

        var it = graph.successors(current);
        while (it.next()) |edge| {
            try neighbors.append(allocator, edge.to);
        }

        if (neighbors.items.len == 0) return null; // dead end

        const idx = random.intRangeLessThan(usize, 0, neighbors.items.len);
        current = neighbors.items[idx];
    }

    return current;
}

pub const TopologicalError = error{
    NotADAG,
    OutOfMemory,
};

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

test "BFS: Basic traversal" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;
    var g = models.GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});
    try g.addEdge(1, 2, {});
    try g.addEdge(2, 3, {});

    var visited_count: usize = 0;
    const v = struct {
        fn visit(ctx: *usize, node: u32) bool {
            _ = node;
            ctx.* += 1;
            return true;
        }
    }.visit;

    try bfs(allocator, g, @as(u32, 1), &visited_count, v);
    try std.testing.expectEqual(@as(usize, 3), visited_count);
}

test "DFS: Basic traversal" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;
    var g = models.GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});
    try g.addEdge(1, 2, {});
    try g.addEdge(1, 3, {});

    var visited_count_dfs: usize = 0;
    const v = struct {
        fn visit(ctx: *usize, node: u32) bool {
            _ = node;
            ctx.* += 1;
            return true;
        }
    }.visit;

    try dfs(allocator, g, @as(u32, 1), &visited_count_dfs, v, null);
    try std.testing.expectEqual(@as(usize, 3), visited_count_dfs);
}

test "BFS: Works with ArrayGraph" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, void).init(allocator);
    defer g.deinit();

    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    const n3 = try g.addNode({});
    _ = try g.addEdge(n1, n2, {});
    _ = try g.addEdge(n2, n3, {});

    var visited_count: usize = 0;
    const v = struct {
        fn visit(ctx: *usize, node: u32) bool {
            _ = node;
            ctx.* += 1;
            return true;
        }
    }.visit;

    try bfs(allocator, g, n1, &visited_count, v);
    try std.testing.expectEqual(@as(usize, 3), visited_count);
}

test "Best-First Search: finds goal" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;
    var g = models.GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});
    try g.addEdge(1, 2, {});
    try g.addEdge(1, 3, {});

    // Heuristic: node 3 is "closer" (lower score)
    const h = struct {
        fn heuristic(_: void, node: u32) f64 {
            return if (node == 3) 0.0 else 100.0;
        }
    }.heuristic;

    const result = try bestFirstSearch(allocator, g, @as(u32, 1), @as(u32, 3), {}, h);
    try std.testing.expectEqual(@as(u32, 3), result.?);
}

test "Random Walk: doesn't crash" {
    const models = @import("root.zig").models;
    const allocator = std.testing.allocator;
    var g = models.GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addEdge(1, 2, {});
    try g.addEdge(2, 1, {});

    var prng = std.Random.DefaultPrng.init(42);
    const result = try randomWalk(allocator, g, @as(u32, 1), 5, prng.random());
    try std.testing.expect(result != null);
}
