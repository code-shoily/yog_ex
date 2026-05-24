const std = @import("std");
const utils = @import("../utils.zig");

/// Returns the number of slots to allocate for workspace arrays.
/// For ArrayGraph this is nodeCapacity() (includes tombstoned entries, needed
/// because workspaces are indexed by NodeIndex). For other graph types this
/// falls back to nodeCount().
fn graphNodeCapacity(graph: anytype) usize {
    const G = @TypeOf(graph);
    if (@hasDecl(G, "nodeCapacity")) return graph.nodeCapacity();
    return graph.nodeCount();
}

/// Result of a single-source shortest path query.
pub fn ShortestPathResult(comptime NId: type, comptime Weight: type) type {
    return struct {
        weight: Weight,
        path: std.ArrayList(NId),

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.path.deinit(allocator);
        }
    };
}

pub fn SingleSourceDistancesResult(comptime NodeId: type, comptime Weight: type) type {
    return struct {
        dists: []?Weight,
        node_to_idx: ?std.AutoHashMap(NodeId, usize),

        pub fn get(self: @This(), node: NodeId) ?Weight {
            if (self.node_to_idx) |m| {
                const idx = m.get(node) orelse return null;
                return self.dists[idx];
            } else {
                const idx = @as(usize, @intCast(node));
                if (idx >= self.dists.len) return null;
                return self.dists[idx];
            }
        }

        pub fn count(self: @This()) usize {
            var c: usize = 0;
            for (self.dists) |d| {
                if (d != null) c += 1;
            }
            return c;
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.dists);
            if (self.node_to_idx) |*m| m.deinit();
        }
    };
}

/// Result of a single-source shortest path query that includes path counts
/// and the predecessor DAG. Used by Brandes' betweenness centrality.
pub fn PathCountsResult(comptime NodeId: type, comptime Weight: type) type {
    return struct {
        const Self = @This();

        dist: std.AutoHashMap(NodeId, Weight),
        sigma: std.AutoHashMap(NodeId, usize),
        pred: std.AutoHashMap(NodeId, std.ArrayList(NodeId)),
        stack: std.ArrayList(NodeId),

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.dist.deinit();
            self.sigma.deinit();
            var pit = self.pred.valueIterator();
            while (pit.next()) |list| {
                list.deinit(allocator);
            }
            self.pred.deinit();
            self.stack.deinit(allocator);
        }
    };
}

/// A reusable workspace for SSSP algorithms to avoid allocations.

/// A reusable workspace for SSSP algorithms to avoid allocations.
pub fn SSSPWorkspace(comptime NodeId: type, comptime Weight: type) type {
    return struct {
        dist: []?Weight,
        prev: []?NodeId,

        pub fn init(allocator: std.mem.Allocator, node_count: usize) !@This() {
            const dist = try allocator.alloc(?Weight, node_count);
            const prev = try allocator.alloc(?NodeId, node_count);
            var self = @This(){
                .dist = dist,
                .prev = prev,
            };
            self.reset();
            return self;
        }

        pub fn ensureCapacity(self: *@This(), allocator: std.mem.Allocator, node_count: usize) !void {
            if (self.dist.len < node_count) {
                self.dist = try allocator.realloc(self.dist, node_count);
                self.prev = try allocator.realloc(self.prev, node_count);
            }
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.dist);
            allocator.free(self.prev);
        }

        pub fn reset(self: *@This()) void {
            @memset(self.dist, null);
            @memset(self.prev, null);
        }
    };
}

// =============================================================================
// Internal Helpers
// =============================================================================

fn NodeMapper(comptime NodeId: type, comptime Weight: type) type {
    return struct {
        const Self = @This();
        is_direct: bool,
        node_to_idx: ?std.AutoHashMap(NodeId, usize),
        next_idx: usize = 0,
        ws: *SSSPWorkspace(NodeId, Weight),
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, graph: anytype, ws: *SSSPWorkspace(NodeId, Weight)) !Self {
            const is_direct = comptime blk: {
                const T = @TypeOf(graph);
                break :blk @hasDecl(T, "NodeIndex") and T.NodeIndex == NodeId;
            };
            return Self{
                .is_direct = is_direct,
                .node_to_idx = if (is_direct) null else std.AutoHashMap(NodeId, usize).init(allocator),
                .ws = ws,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Self) void {
            if (self.node_to_idx) |*m| m.deinit();
        }

        fn get(self: @This(), id: NodeId) usize {
            if (self.is_direct) return @as(usize, @intCast(id));
            return self.node_to_idx.?.get(id) orelse 0;
        }

        fn getOrPut(self: *@This(), id: NodeId) !usize {
            if (self.is_direct) {
                const idx = @as(usize, @intCast(id));
                try self.ws.ensureCapacity(self.allocator, idx + 1);
                return idx;
            }
            const res = try self.node_to_idx.?.getOrPut(id);
            if (!res.found_existing) {
                res.value_ptr.* = self.next_idx;
                self.next_idx += 1;
                try self.ws.ensureCapacity(self.allocator, self.next_idx);
            }
            return res.value_ptr.*;
        }
    };
}

fn reconstructPath(
    allocator: std.mem.Allocator,
    node: anytype,
    start_node: anytype,
    weight: anytype,
    ws: anytype,
    mapper: anytype,
) !ShortestPathResult(@TypeOf(node), @TypeOf(weight)) {
    const NodeId = @TypeOf(node);
    var path = std.ArrayList(NodeId).empty;
    errdefer path.deinit(allocator);

    var at = node;
    while (true) {
        try path.append(allocator, at);
        if (std.meta.eql(at, start_node)) break;
        const at_idx = mapper.get(at);
        at = ws.prev[at_idx] orelse break;
    }
    std.mem.reverse(NodeId, path.items);

    return .{
        .weight = weight,
        .path = path,
    };
}

fn pointToPointSearchInternal(
    comptime is_astar: bool,
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
    comptime Weight: type,
    zero: Weight,
    comptime addFn: fn (a: Weight, b: Weight) Weight,
    comptime compareFn: fn (a: Weight, b: Weight) std.math.Order,
    heuristic_opt: ?fn (node: @TypeOf(start_node), goal: @TypeOf(start_node)) Weight,
    workspace_opt: ?*SSSPWorkspace(@TypeOf(start_node), Weight),
) !?ShortestPathResult(@TypeOf(start_node), Weight) {
    const NodeId = @TypeOf(start_node);

    var internal_ws: ?SSSPWorkspace(NodeId, Weight) = null;
    defer if (internal_ws) |*ws| ws.deinit(allocator);

    const ws = if (workspace_opt) |ws| ws else blk: {
        internal_ws = try SSSPWorkspace(NodeId, Weight).init(allocator, graphNodeCapacity(graph));
        break :blk &internal_ws.?;
    };
    ws.reset();

    var mapper = try NodeMapper(NodeId, Weight).init(allocator, graph, ws);
    defer mapper.deinit();

    const Item = struct {
        node: NodeId,
        f: Weight,
        g: Weight,
    };

    const PQ = std.PriorityQueue(Item, void, struct {
        fn lessThan(_: void, a: Item, b: Item) std.math.Order {
            return compareFn(a.f, b.f);
        }
    }.lessThan);

    var pq = PQ.init(allocator, {});
    defer pq.deinit();

    const start_g = zero;
    const start_f = if (is_astar) addFn(start_g, heuristic_opt.?(start_node, goal_node)) else start_g;

    const start_idx = try mapper.getOrPut(start_node);
    ws.dist[start_idx] = start_g;
    try pq.add(.{ .node = start_node, .f = start_f, .g = start_g });

    while (pq.count() > 0) {
        const current = pq.remove();
        const current_idx = mapper.get(current.node);
        const best_g = ws.dist[current_idx] orelse continue;

        if (compareFn(current.g, best_g) == .gt) continue;

        if (std.meta.eql(current.node, goal_node)) {
            return try reconstructPath(allocator, goal_node, start_node, current.g, ws, mapper);
        }

        var it = graph.successors(current.node);
        while (it.next()) |edge| {
            const tentative_g = addFn(current.g, edge.data);
            const to_idx = try mapper.getOrPut(edge.to);
            const old_g_opt = ws.dist[to_idx];
            const better = if (old_g_opt) |old_g| compareFn(tentative_g, old_g) == .lt else true;

            if (better) {
                ws.dist[to_idx] = tentative_g;
                ws.prev[to_idx] = current.node;
                const f = if (is_astar) addFn(tentative_g, heuristic_opt.?(edge.to, goal_node)) else tentative_g;
                try pq.add(.{ .node = edge.to, .f = f, .g = tentative_g });
            }
        }
    }

    return null;
}

// =============================================================================
// Dijkstra's Algorithm
// =============================================================================

/// Generic Dijkstra with explicit zero/add/compare semantics.
pub fn dijkstraGeneric(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
    comptime Weight: type,
    zero: Weight,
    comptime addFn: fn (a: Weight, b: Weight) Weight,
    comptime compareFn: fn (a: Weight, b: Weight) std.math.Order,
    workspace_opt: ?*SSSPWorkspace(@TypeOf(start_node), Weight),
) !?ShortestPathResult(@TypeOf(start_node), Weight) {
    return pointToPointSearchInternal(false, allocator, graph, start_node, goal_node, Weight, zero, addFn, compareFn, null, workspace_opt);
}

pub fn dijkstra(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
) !?ShortestPathResult(@TypeOf(start_node), f64) {
    return dijkstraGeneric(allocator, graph, start_node, goal_node, f64, 0.0, utils.addF64, utils.compareF64, null);
}

/// Runs Dijkstra from `start_node` and returns distances to all reachable nodes.
pub fn singleSourceDistances(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    comptime Weight: type,
    zero: Weight,
    comptime addFn: fn (a: Weight, b: Weight) Weight,
    comptime compareFn: fn (a: Weight, b: Weight) std.math.Order,
    workspace_opt: ?*SSSPWorkspace(@TypeOf(start_node), Weight),
) !SingleSourceDistancesResult(@TypeOf(start_node), Weight) {
    const NodeId = @TypeOf(start_node);

    var internal_ws: ?SSSPWorkspace(NodeId, Weight) = null;
    defer if (internal_ws) |*ws| ws.deinit(allocator);

    const ws = if (workspace_opt) |ws| ws else blk: {
        internal_ws = try SSSPWorkspace(NodeId, Weight).init(allocator, graphNodeCapacity(graph));
        break :blk &internal_ws.?;
    };
    ws.reset();

    var mapper = try NodeMapper(NodeId, Weight).init(allocator, graph, ws);
    defer mapper.deinit();

    const Item = struct {
        node: NodeId,
        d: Weight,
    };

    const PQ = std.PriorityQueue(Item, void, struct {
        fn lessThan(_: void, a: Item, b: Item) std.math.Order {
            return compareFn(a.d, b.d);
        }
    }.lessThan);

    var pq = PQ.init(allocator, {});
    defer pq.deinit();

    const start_idx = try mapper.getOrPut(start_node);
    ws.dist[start_idx] = zero;
    try pq.add(.{ .node = start_node, .d = zero });

    while (pq.count() > 0) {
        const current = pq.remove();

        const current_idx = mapper.get(current.node);
        const current_dist = ws.dist[current_idx] orelse continue;
        if (compareFn(current.d, current_dist) == .gt) continue;

        var it = graph.successors(current.node);
        while (it.next()) |edge| {
            const w = edge.data;
            const alt = addFn(current.d, w);

            const to_idx = try mapper.getOrPut(edge.to);
            const old_dist_opt = ws.dist[to_idx];
            const better = if (old_dist_opt) |old_dist|
                compareFn(alt, old_dist) == .lt
            else
                true;

            if (better) {
                ws.dist[to_idx] = alt;
                try pq.add(.{ .node = edge.to, .d = alt });
            }
        }
    }

    // Return a copy of the distances to ensure the result is independent of the workspace
    const dist_copy = try allocator.dupe(?Weight, ws.dist);
    errdefer allocator.free(dist_copy);

    return SingleSourceDistancesResult(NodeId, Weight){
        .dists = dist_copy,
        .node_to_idx = if (mapper.is_direct) null else try mapper.node_to_idx.?.clone(),
    };
}

pub fn singleSourceDistancesF64(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
) !SingleSourceDistancesResult(@TypeOf(start_node), f64) {
    return singleSourceDistances(allocator, graph, start_node, f64, 0.0, utils.addF64, utils.compareF64, null);
}

// =============================================================================
// A* Search
// =============================================================================

/// Generic A* search with explicit zero/add/compare semantics.
pub fn astarGeneric(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
    comptime Weight: type,
    zero: Weight,
    comptime addFn: fn (a: Weight, b: Weight) Weight,
    comptime compareFn: fn (a: Weight, b: Weight) std.math.Order,
    heuristic: fn (node: @TypeOf(start_node), goal: @TypeOf(start_node)) Weight,
    workspace_opt: ?*SSSPWorkspace(@TypeOf(start_node), Weight),
) !?ShortestPathResult(@TypeOf(start_node), Weight) {
    return pointToPointSearchInternal(true, allocator, graph, start_node, goal_node, Weight, zero, addFn, compareFn, heuristic, workspace_opt);
}

pub fn astar(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
    heuristic: fn (node: @TypeOf(start_node), goal: @TypeOf(start_node)) f64,
) !?ShortestPathResult(@TypeOf(start_node), f64) {
    return astarGeneric(allocator, graph, start_node, goal_node, f64, 0.0, utils.addF64, utils.compareF64, heuristic, null);
}

// =============================================================================
// Bellman-Ford Algorithm
// =============================================================================

/// Bellman-Ford algorithm finds shortest paths from a single source node to a
/// destination node, even in graphs with negative edge weights.
///
/// Returns `error.NegativeCycle` if a negative weight cycle is reachable from `start_node`.
///
/// **Time Complexity:** O(V × E)
pub fn bellmanFordGeneric(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
    comptime Weight: type,
    zero: Weight,
    comptime addFn: fn (a: Weight, b: Weight) Weight,
    comptime compareFn: fn (a: Weight, b: Weight) std.math.Order,
    workspace_opt: ?*SSSPWorkspace(@TypeOf(start_node), Weight),
) !?ShortestPathResult(@TypeOf(start_node), Weight) {
    const NodeId = @TypeOf(start_node);

    var internal_ws: ?SSSPWorkspace(NodeId, Weight) = null;
    defer if (internal_ws) |*ws| ws.deinit(allocator);

    const ws = if (workspace_opt) |ws| ws else blk: {
        internal_ws = try SSSPWorkspace(NodeId, Weight).init(allocator, graphNodeCapacity(graph));
        break :blk &internal_ws.?;
    };
    ws.reset();


    var mapper = try NodeMapper(NodeId, Weight).init(allocator, graph, ws);
    defer mapper.deinit();

    const start_idx = try mapper.getOrPut(start_node);
    ws.dist[start_idx] = zero;

    const node_count = graph.nodeCount();

    // V-1 relaxation passes
    const passes = if (node_count > 0) node_count - 1 else 0;
    for (0..passes) |_| {
        var relaxed = false;

        var node_it = graph.nodeIds();
        while (node_it.next()) |u| {
            const u_idx = try mapper.getOrPut(u);
            const u_dist = ws.dist[u_idx] orelse continue;

            var succ_it = graph.successors(u);
            while (succ_it.next()) |edge| {
                const w = edge.data;
                const tentative = addFn(u_dist, w);

                const to_idx = try mapper.getOrPut(edge.to);
                const old_opt = ws.dist[to_idx];
                const better = if (old_opt) |old|
                    compareFn(tentative, old) == .lt
                else
                    true;

                if (better) {
                    ws.dist[to_idx] = tentative;
                    ws.prev[to_idx] = u;
                    relaxed = true;
                }
            }
        }

        if (!relaxed) break;
    }

    // Negative cycle detection
    var node_it = graph.nodeIds();
    while (node_it.next()) |u| {
        const u_idx = mapper.get(u);
        const u_dist = ws.dist[u_idx] orelse continue;

        var succ_it = graph.successors(u);
        while (succ_it.next()) |edge| {
            const w = edge.data;
            const tentative = addFn(u_dist, w);

            const to_idx = mapper.get(edge.to);
            const old_opt = ws.dist[to_idx];
            const better = if (old_opt) |old|
                compareFn(tentative, old) == .lt
            else
                true;

            if (better) return error.NegativeCycle;
        }
    }

    const goal_idx = mapper.get(goal_node);
    const goal_dist = ws.dist[goal_idx] orelse return null;

    return try reconstructPath(allocator, goal_node, start_node, goal_dist, ws, mapper);
}

pub fn bellmanFord(
    allocator: std.mem.Allocator,
    graph: anytype,
    start_node: anytype,
    goal_node: anytype,
) !?ShortestPathResult(@TypeOf(start_node), f64) {
    return bellmanFordGeneric(allocator, graph, start_node, goal_node, f64, 0.0, utils.addF64, utils.compareF64, null);
}

// =============================================================================
// Path Counting / Brandes Discovery
// =============================================================================

/// Finds all shortest paths from a single source, counting path multiplicities.
/// This is the discovery phase of Brandes' betweenness centrality algorithm.
///
/// **Time Complexity:** O(E + V)
pub fn singleSourceShortestPathCountsUnweighted(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: anytype,
) !PathCountsResult(@TypeOf(source), usize) {
    const NodeId = @TypeOf(source);

    var dist = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer dist.deinit();
    var sigma = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer sigma.deinit();
    var pred = std.AutoHashMap(NodeId, std.ArrayList(NodeId)).init(allocator);
    errdefer {
        var pit = pred.valueIterator();
        while (pit.next()) |list| list.deinit(allocator);
        pred.deinit();
    }
    var stack = std.ArrayList(NodeId).empty;
    errdefer stack.deinit(allocator);

    try dist.put(source, 0);
    try sigma.put(source, 1);

    var queue = std.ArrayList(NodeId).empty;
    defer queue.deinit(allocator);
    try queue.append(allocator, source);

    var head: usize = 0;
    while (head < queue.items.len) {
        const v = queue.items[head];
        head += 1;
        try stack.append(allocator, v);

        const d_v = dist.get(v).?;

        var sit = graph.successors(v);
        while (sit.next()) |edge| {
            const w = edge.to;

            if (!dist.contains(w)) {
                try dist.put(w, d_v + 1);
                try queue.append(allocator, w);
            }

            if (dist.get(w).? == d_v + 1) {
                const curr_sigma = sigma.get(w) orelse 0;
                try sigma.put(w, curr_sigma + sigma.get(v).?);

                if (pred.getPtr(w)) |plist| {
                    try plist.append(allocator, v);
                } else {
                    var list = std.ArrayList(NodeId).empty;
                    try list.append(allocator, v);
                    try pred.put(w, list);
                }
            }
        }
    }

    return .{
        .dist = dist,
        .sigma = sigma,
        .pred = pred,
        .stack = stack,
    };
}

/// Finds all shortest paths from a single source in a weighted graph, counting path multiplicities.
/// This is the discovery phase of Brandes' betweenness centrality algorithm.
///
/// **Time Complexity:** O(VE + V² log V)
pub fn singleSourceShortestPathCounts(
    allocator: std.mem.Allocator,
    graph: anytype,
    source: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !PathCountsResult(@TypeOf(source), Weight) {
    const NodeId = @TypeOf(source);

    var dist = std.AutoHashMap(NodeId, Weight).init(allocator);
    errdefer dist.deinit();
    var sigma = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer sigma.deinit();
    var pred = std.AutoHashMap(NodeId, std.ArrayList(NodeId)).init(allocator);
    errdefer {
        var pit = pred.valueIterator();
        while (pit.next()) |list| list.deinit(allocator);
        pred.deinit();
    }
    var stack = std.ArrayList(NodeId).empty;
    errdefer stack.deinit(allocator);

    try dist.put(source, zero);
    try sigma.put(source, 1);

    const Item = struct {
        d: Weight,
        node: NodeId,
    };

    const PQ = std.PriorityQueue(Item, void, struct {
        fn lessThan(_: void, a: Item, b: Item) std.math.Order {
            return compareFn(a.d, b.d);
        }
    }.lessThan);

    var pq = PQ.init(allocator, {});
    defer pq.deinit();
    try pq.add(.{ .d = zero, .node = source });

    while (pq.count() > 0) {
        const item = pq.remove();
        const d_v = item.d;
        const v = item.node;

        const current_best = dist.get(v) orelse d_v;
        if (compareFn(d_v, current_best) == .gt) continue;

        try stack.append(allocator, v);

        var sit = graph.successors(v);
        while (sit.next()) |edge| {
            const w = edge.to;
            const weight = edge.data;
            const new_dist = addFn(d_v, weight);

            if (dist.get(w)) |old_dist| {
                const ord = compareFn(new_dist, old_dist);
                if (ord == .lt) {
                    try dist.put(w, new_dist);
                    try sigma.put(w, sigma.get(v).?);

                    if (pred.getPtr(w)) |plist| {
                        plist.items.len = 0;
                        try plist.append(allocator, v);
                    } else {
                        var list = std.ArrayList(NodeId).empty;
                        try list.append(allocator, v);
                        try pred.put(w, list);
                    }
                    try pq.add(.{ .d = new_dist, .node = w });
                } else if (ord == .eq) {
                    const curr_sigma = sigma.get(w).?;
                    try sigma.put(w, curr_sigma + sigma.get(v).?);

                    if (pred.getPtr(w)) |plist| {
                        try plist.append(allocator, v);
                    } else {
                        var list = std.ArrayList(NodeId).empty;
                        try list.append(allocator, v);
                        try pred.put(w, list);
                    }
                }
            } else {
                try dist.put(w, new_dist);
                try sigma.put(w, sigma.get(v).?);
                var list = std.ArrayList(NodeId).empty;
                try list.append(allocator, v);
                try pred.put(w, list);
                try pq.add(.{ .d = new_dist, .node = w });
            }
        }
    }

    return .{
        .dist = dist,
        .sigma = sigma,
        .pred = pred,
        .stack = stack,
    };
}

// --- Tests ---

test "Dijkstra: simple linear path" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    const n3 = try g.addNode({});

    _ = try g.addEdge(n1, n2, 1.0);
    _ = try g.addEdge(n2, n3, 2.0);

    var result = try dijkstra(allocator, g, n1, n3);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 3.0), result.?.weight);
    try std.testing.expectEqual(@as(usize, 3), result.?.path.items.len);
    try std.testing.expectEqual(n1, result.?.path.items[0]);
    try std.testing.expectEqual(n2, result.?.path.items[1]);
    try std.testing.expectEqual(n3, result.?.path.items[2]);
}

test "Dijkstra: chooses shorter path" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const a = try g.addNode({});
    const b = try g.addNode({});
    const c = try g.addNode({});
    const d = try g.addNode({});

    _ = try g.addEdge(a, b, 10.0);
    _ = try g.addEdge(b, d, 10.0);
    _ = try g.addEdge(a, c, 1.0);
    _ = try g.addEdge(c, d, 1.0);

    var result = try dijkstra(allocator, g, a, d);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 2.0), result.?.weight);
    try std.testing.expectEqual(a, result.?.path.items[0]);
    try std.testing.expectEqual(c, result.?.path.items[1]);
    try std.testing.expectEqual(d, result.?.path.items[2]);
}

test "Dijkstra: unreachable goal returns null" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const a = try g.addNode({});
    const b = try g.addNode({});
    const c = try g.addNode({});

    _ = try g.addEdge(a, b, 1.0);

    var result = try dijkstra(allocator, g, a, c);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result == null);
}

test "Dijkstra: works with GraphMap" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.GraphMap(u32, void, f64, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});

    try g.addEdge(1, 2, 1.0);
    try g.addEdge(2, 3, 2.0);

    var result = try dijkstra(allocator, g, @as(u32, 1), @as(u32, 3));
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 3.0), result.?.weight);
}

test "DijkstraGeneric: integer weights" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, u32).init(allocator);
    defer g.deinit();

    const a = try g.addNode({});
    const b = try g.addNode({});
    const c = try g.addNode({});

    _ = try g.addEdge(a, b, @as(u32, 5));
    _ = try g.addEdge(b, c, @as(u32, 7));

    var result = try dijkstraGeneric(
        allocator,
        g,
        a,
        c,
        u32,
        0,
        struct {
            fn add(x: u32, y: u32) u32 {
                return x +% y;
            }
        }.add,
        struct {
            fn cmp(x: u32, y: u32) std.math.Order {
                return std.math.order(x, y);
            }
        }.cmp,
        null,
    );
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 12), result.?.weight);
}

test "Dijkstra: ArrayGraph with sparse/large indices" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    // Create a gap
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // 0 -> 1 -> 2
    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 2, 2.0);

    // Reuse workspace manually to test ensureCapacity
    var ws = try SSSPWorkspace(u32, f64).init(allocator, 1);
    defer ws.deinit(allocator);

    var result = try dijkstraGeneric(allocator, g, @as(u32, 0), @as(u32, 2), f64, 0.0, utils.addF64, utils.compareF64, &ws);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 3.0), result.?.weight);
    try std.testing.expect(ws.dist.len >= 3);
}

test "singleSourceDistances: all reachable nodes" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const a = try g.addNode({});
    const b = try g.addNode({});
    const c = try g.addNode({});

    _ = try g.addEdge(a, b, 1.0);
    _ = try g.addEdge(b, c, 2.0);

    var dist = try singleSourceDistancesF64(allocator, g, a);
    defer dist.deinit(allocator);

    try std.testing.expectEqual(@as(f64, 0.0), dist.get(a).?);
    try std.testing.expectEqual(@as(f64, 1.0), dist.get(b).?);
    try std.testing.expectEqual(@as(f64, 3.0), dist.get(c).?);
}

test "A*: simple grid with Manhattan heuristic" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    // Grid: 0-1-2
    //       | | |
    //       3-4-5
    const n0 = try g.addNode({});
    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    const n3 = try g.addNode({});
    const n4 = try g.addNode({});
    const n5 = try g.addNode({});

    _ = try g.addEdge(n0, n1, 1.0);
    _ = try g.addEdge(n1, n2, 1.0);
    _ = try g.addEdge(n0, n3, 1.0);
    _ = try g.addEdge(n1, n4, 1.0);
    _ = try g.addEdge(n2, n5, 1.0);
    _ = try g.addEdge(n3, n4, 1.0);
    _ = try g.addEdge(n4, n5, 1.0);

    const h = struct {
        fn heuristic(node: u32, goal: u32) f64 {
            const xs = [_]f64{ 0, 1, 2, 0, 1, 2 };
            const ys = [_]f64{ 0, 0, 0, 1, 1, 1 };
            const dx = xs[node] - xs[goal];
            const dy = ys[node] - ys[goal];
            return @abs(dx) + @abs(dy);
        }
    }.heuristic;

    var result = try astar(allocator, g, n0, n5, h);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 3.0), result.?.weight);
}

test "Bellman-Ford: simple linear path" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    const n3 = try g.addNode({});

    _ = try g.addEdge(n1, n2, 1.0);
    _ = try g.addEdge(n2, n3, 2.0);

    var result = try bellmanFord(allocator, g, n1, n3);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 3.0), result.?.weight);
}

test "Bellman-Ford: negative edge weights" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const a = try g.addNode({});
    const b = try g.addNode({});
    const c = try g.addNode({});

    _ = try g.addEdge(a, b, 5.0);
    _ = try g.addEdge(b, c, -3.0);
    _ = try g.addEdge(a, c, 10.0);

    var result = try bellmanFord(allocator, g, a, c);
    defer if (result) |*r| r.deinit(allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f64, 2.0), result.?.weight);
}

test "Bellman-Ford: detects negative cycle" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;

    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    const a = try g.addNode({});
    const b = try g.addNode({});
    const c = try g.addNode({});

    _ = try g.addEdge(a, b, 1.0);
    _ = try g.addEdge(b, c, -2.0);
    _ = try g.addEdge(c, a, -1.0);

    const result = bellmanFord(allocator, g, a, b);
    try std.testing.expectError(error.NegativeCycle, result);
}
