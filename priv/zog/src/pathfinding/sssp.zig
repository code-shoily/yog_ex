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

    var dist = try singleSourceDistances(allocator, g, a, f64, 0.0, utils.addF64, utils.compareF64, null);
    defer dist.deinit(allocator);

    try std.testing.expectEqual(@as(f64, 0.0), dist.get(a).?);
    try std.testing.expectEqual(@as(f64, 1.0), dist.get(b).?);
    try std.testing.expectEqual(@as(f64, 3.0), dist.get(c).?);
}
