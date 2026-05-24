const std = @import("std");
const utils = @import("utils.zig");


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

/// Result of an all-pairs shortest path computation using a flat matrix.
pub fn AllPairsShortestPathResult(comptime NId: type, comptime Weight: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        matrix: []?Weight,
        node_to_idx: std.AutoHashMap(NId, usize),
        stride: usize,

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.matrix);
            self.node_to_idx.deinit();
        }

        /// Returns the shortest distance from `from` to `to`, or `null` if unreachable.
        pub fn get(self: Self, from: NId, to: NId) ?Weight {
            const i = self.node_to_idx.get(from) orelse return null;
            const j = self.node_to_idx.get(to) orelse return null;
            return self.matrix[i * self.stride + j];
        }
    };
}

// =============================================================================
// Floyd-Warshall Algorithm
// =============================================================================

/// Computes shortest paths between all pairs of nodes using Floyd-Warshall.
pub fn floydWarshallGeneric(
    allocator: std.mem.Allocator,
    graph: anytype,
    comptime Weight: type,
    zero: Weight,
    addFn: fn (Weight, Weight) Weight,
    compareFn: fn (Weight, Weight) std.math.Order,
) !AllPairsShortestPathResult(utils.NodeId(@TypeOf(graph)), Weight) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    const n = nodes.items.len;
    if (n == 0) {
        const node_to_idx = std.AutoHashMap(NodeId, usize).init(allocator);
        return AllPairsShortestPathResult(NodeId, Weight){
            .allocator = allocator,
            .matrix = try allocator.alloc(?Weight, 0),
            .node_to_idx = node_to_idx,
            .stride = 0,
        };
    }

    // Map NodeId to matrix index
    var node_to_idx = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer node_to_idx.deinit();
    for (nodes.items, 0..) |node, idx| {
        try node_to_idx.put(node, idx);
    }

    // Flat matrix: matrix[i * n + j]
    // null means infinity
    var matrix = try allocator.alloc(?Weight, n * n);
    errdefer allocator.free(matrix);
    @memset(matrix, null);

    // 1. Initialize matrix
    for (nodes.items, 0..) |u, i| {
        matrix[i * n + i] = zero;

        var succ_it = graph.successors(u);
        while (succ_it.next()) |edge| {
            const v = edge.to;
            const j = node_to_idx.get(v).?;
            const weight = edge.data;
            const idx = i * n + j;
            if (matrix[idx]) |curr| {
                if (compareFn(weight, curr) == .lt) {
                    matrix[idx] = weight;
                }
            } else {
                matrix[idx] = weight;
            }
        }
    }

    // 2. Floyd-Warshall triple loop (Hot path)
    const cpu_count = std.Thread.getCpuCount() catch 1;
    const threshold = 512;
    const use_parallel = n >= threshold and cpu_count > 1;

    const ParallelCtx = struct {
        matrix: []?Weight,
        n: usize,
        k: usize,
        start: usize,
        end: usize,
        addFn: *const fn (Weight, Weight) Weight,
        compareFn: *const fn (Weight, Weight) std.math.Order,

        fn run(ctx: @This()) void {
            for (ctx.start..ctx.end) |i| {
                const ik_idx = i * ctx.n + ctx.k;
                const ik = ctx.matrix[ik_idx] orelse continue;

                for (0..ctx.n) |j| {
                    const kj_idx = ctx.k * ctx.n + j;
                    const kj = ctx.matrix[kj_idx] orelse continue;

                    const new_dist = ctx.addFn(ik, kj);
                    const ij_idx = i * ctx.n + j;
                    if (ctx.matrix[ij_idx]) |curr| {
                        if (ctx.compareFn(new_dist, curr) == .lt) {
                            ctx.matrix[ij_idx] = new_dist;
                        }
                    } else {
                        ctx.matrix[ij_idx] = new_dist;
                    }
                }
            }
        }
    };

    if (use_parallel) {
        var threads = try allocator.alloc(std.Thread, cpu_count - 1);
        defer allocator.free(threads);

        for (0..n) |k| {
            const chunk_size = (n + cpu_count - 1) / cpu_count;
            var spawned: usize = 0;
            errdefer {
                for (0..spawned) |s| threads[s].detach();
            }

            for (0..cpu_count - 1) |t| {
                const start = t * chunk_size;
                const end = @min(start + chunk_size, n);
                threads[t] = try std.Thread.spawn(.{}, ParallelCtx.run, .{ParallelCtx{
                    .matrix = matrix,
                    .n = n,
                    .k = k,
                    .start = start,
                    .end = end,
                    .addFn = addFn,
                    .compareFn = compareFn,
                }});
                spawned += 1;
            }

            // Current thread handles the last chunk
            const start = (cpu_count - 1) * chunk_size;
            if (start < n) {
                const end = n;
                ParallelCtx.run(.{
                    .matrix = matrix,
                    .n = n,
                    .k = k,
                    .start = start,
                    .end = end,
                    .addFn = addFn,
                    .compareFn = compareFn,
                });
            }

            for (0..spawned) |s| {
                threads[s].join();
            }
        }
    } else {
        for (0..n) |k| {
            for (0..n) |i| {
                const ik_idx = i * n + k;
                const ik = matrix[ik_idx] orelse continue;

                for (0..n) |j| {
                    const kj_idx = k * n + j;
                    const kj = matrix[kj_idx] orelse continue;

                    const new_dist = addFn(ik, kj);
                    const ij_idx = i * n + j;
                    if (matrix[ij_idx]) |curr| {
                        if (compareFn(new_dist, curr) == .lt) {
                            matrix[ij_idx] = new_dist;
                        }
                    } else {
                        matrix[ij_idx] = new_dist;
                    }
                }
            }
        }
    }

    // 3. Negative cycle detection
    for (0..n) |i| {
        if (matrix[i * n + i]) |dist| {
            if (compareFn(dist, zero) == .lt) {
                return error.NegativeCycle;
            }
        }
    }

    return AllPairsShortestPathResult(NodeId, Weight){
        .allocator = allocator,
        .matrix = matrix,
        .node_to_idx = node_to_idx,
        .stride = n,
    };
}

pub fn floydWarshall(allocator: std.mem.Allocator, graph: anytype) !AllPairsShortestPathResult(utils.NodeId(@TypeOf(graph)), f64) {
    return floydWarshallGeneric(allocator, graph, f64, 0.0, utils.addF64, utils.compareF64);
}

// =============================================================================
// Johnson's Algorithm
// =============================================================================

/// Computes All-Pairs Shortest Paths using Johnson's Algorithm.
pub fn johnsonsGeneric(
    allocator: std.mem.Allocator,
    graph: anytype,
    comptime Weight: type,
    zero: Weight,
    comptime addFn: fn (a: Weight, b: Weight) Weight,
    comptime subFn: fn (a: Weight, b: Weight) Weight,
    comptime compareFn: fn (a: Weight, b: Weight) std.math.Order,
) !AllPairsShortestPathResult(utils.NodeId(@TypeOf(graph)), Weight) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    const n = nodes.items.len;
    if (n == 0) {
        const node_to_idx = std.AutoHashMap(NodeId, usize).init(allocator);
        return AllPairsShortestPathResult(NodeId, Weight){
            .allocator = allocator,
            .matrix = try allocator.alloc(?Weight, 0),
            .node_to_idx = node_to_idx,
            .stride = 0,
        };
    }

    // Map NodeId to matrix index
    var node_to_idx = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer node_to_idx.deinit();
    for (nodes.items, 0..) |node, idx| {
        try node_to_idx.put(node, idx);
    }

    // 1. Bellman-Ford to find potentials `h`
    var h = try allocator.alloc(Weight, n);
    defer allocator.free(h);
    @memset(h, zero);

    const passes = n - 1;
    for (0..passes) |_| {
        var relaxed = false;
        for (nodes.items, 0..) |u, i| {
            const h_u = h[i];
            var sit = graph.successors(u);
            while (sit.next()) |edge| {
                const v_idx = node_to_idx.get(edge.to).?;
                const w = edge.data;
                const tentative = addFn(h_u, w);
                const h_v = h[v_idx];
                if (compareFn(tentative, h_v) == .lt) {
                    h[v_idx] = tentative;
                    relaxed = true;
                }
            }
        }
        if (!relaxed) break;
    }

    // V-th pass for negative cycles
    for (nodes.items, 0..) |u, i| {
        const h_u = h[i];
        var sit = graph.successors(u);
        while (sit.next()) |edge| {
            const v_idx = node_to_idx.get(edge.to).?;
            const w = edge.data;
            const tentative = addFn(h_u, w);
            const h_v = h[v_idx];
            if (compareFn(tentative, h_v) == .lt) {
                return error.NegativeCycle;
            }
        }
    }

    // 2. Setup Dijkstra
    const Item = struct {
        node_idx: usize,
        d: Weight,
    };
    const PQ = std.PriorityQueue(Item, void, struct {
        fn lessThan(_: void, a: Item, b: Item) std.math.Order {
            return compareFn(a.d, b.d);
        }
    }.lessThan);

    var final_matrix = try allocator.alloc(?Weight, n * n);
    errdefer allocator.free(final_matrix);
    @memset(final_matrix, null);

    var pq = PQ.init(allocator, {});
    defer pq.deinit();

    // 3. Run Dijkstra from each node (Parallelized)
    const ParallelDijkstraCtx = struct {
        allocator: std.mem.Allocator,
        graph: @TypeOf(graph),
        nodes: []const NodeId,
        node_to_idx: *const std.AutoHashMap(NodeId, usize),
        h: []const Weight,
        final_matrix: []?Weight,
        start_u_idx: usize,
        end_u_idx: usize,
        n: usize,
        zero: Weight,
        addFn: *const fn (a: Weight, b: Weight) Weight,
        subFn: *const fn (a: Weight, b: Weight) Weight,
        compareFn: *const fn (a: Weight, b: Weight) std.math.Order,

        fn run(ctx: @This()) void {
            const DijkstraItem = struct {
                node_idx: usize,
                d: Weight,
            };
            const PQContext = struct {
                compareFn: *const fn (Weight, Weight) std.math.Order,
                fn lessThan(c: @This(), a: DijkstraItem, b: DijkstraItem) std.math.Order {
                    return c.compareFn(a.d, b.d);
                }
            };
            const LocalPQ = std.PriorityQueue(DijkstraItem, PQContext, PQContext.lessThan);

            var local_pq = LocalPQ.init(ctx.allocator, .{ .compareFn = ctx.compareFn });
            defer local_pq.deinit();

            var dist = ctx.allocator.alloc(?Weight, ctx.n) catch return;
            defer ctx.allocator.free(dist);

            for (ctx.start_u_idx..ctx.end_u_idx) |u_idx| {
                @memset(dist, null);
                dist[u_idx] = ctx.zero;

                local_pq.items.len = 0;
                local_pq.add(.{ .node_idx = u_idx, .d = ctx.zero }) catch continue;

                while (local_pq.count() > 0) {
                    const current = local_pq.remove();
                    const current_dist = dist[current.node_idx] orelse continue;
                    if (ctx.compareFn(current.d, current_dist) == .gt) continue;

                    const h_u_inner = ctx.h[current.node_idx];
                    var sit = ctx.graph.successors(ctx.nodes[current.node_idx]);
                    while (sit.next()) |edge| {
                        const v_idx = ctx.node_to_idx.get(edge.to).?;
                        const w = edge.data;
                        const h_v = ctx.h[v_idx];

                        const reweighted_w = ctx.subFn(ctx.addFn(w, h_u_inner), h_v);
                        const tentative = ctx.addFn(current_dist, reweighted_w);

                        const old_dist = dist[v_idx];
                        const better = if (old_dist) |old|
                            ctx.compareFn(tentative, old) == .lt
                        else
                            true;

                        if (better) {
                            dist[v_idx] = tentative;
                            local_pq.add(.{ .node_idx = v_idx, .d = tentative }) catch continue;
                        }
                    }
                }

                const h_u = ctx.h[u_idx];
                for (0..ctx.n) |v_idx| {
                    if (dist[v_idx]) |d_prime| {
                        const h_v = ctx.h[v_idx];
                        const final_d = ctx.subFn(ctx.addFn(d_prime, h_v), h_u);
                        ctx.final_matrix[u_idx * ctx.n + v_idx] = final_d;
                    }
                }
            }
        }
    };

    const j_cpu_count = std.Thread.getCpuCount() catch 1;
    const j_use_parallel = n >= 128 and j_cpu_count > 1;

    if (j_use_parallel) {
        var threads = try allocator.alloc(std.Thread, j_cpu_count - 1);
        defer allocator.free(threads);
        var contexts = try allocator.alloc(ParallelDijkstraCtx, j_cpu_count);
        defer allocator.free(contexts);

        const chunk_size = (n + j_cpu_count - 1) / j_cpu_count;
        for (0..j_cpu_count) |t| {
            const start = t * chunk_size;
            const end = @min(start + chunk_size, n);
            contexts[t] = .{
                .allocator = allocator,
                .graph = graph,
                .nodes = nodes.items,
                .node_to_idx = &node_to_idx,
                .h = h,
                .final_matrix = final_matrix,
                .start_u_idx = start,
                .end_u_idx = end,
                .n = n,
                .zero = zero,
                .addFn = addFn,
                .subFn = subFn,
                .compareFn = compareFn,
            };
        }

        var spawned: usize = 0;
        errdefer {
            for (0..spawned) |s| threads[s].detach();
        }
        for (0..j_cpu_count - 1) |t| {
            threads[t] = try std.Thread.spawn(.{}, ParallelDijkstraCtx.run, .{contexts[t]});
            spawned += 1;
        }

        ParallelDijkstraCtx.run(contexts[j_cpu_count - 1]);

        for (0..spawned) |s| {
            threads[s].join();
        }
    } else {
        // Serial Dijkstra loop (use existing code pattern)
        var dist = try allocator.alloc(?Weight, n);
        defer allocator.free(dist);

        for (0..n) |u_idx| {
            @memset(dist, null);
            dist[u_idx] = zero;

            while (pq.removeOrNull()) |_| {}
            try pq.add(.{ .node_idx = u_idx, .d = zero });

            while (pq.count() > 0) {
                const current = pq.remove();
                const current_dist = dist[current.node_idx] orelse continue;
                if (compareFn(current.d, current_dist) == .gt) continue;

                const h_u_inner = h[current.node_idx];
                var sit = graph.successors(nodes.items[current.node_idx]);
                while (sit.next()) |edge| {
                    const v_idx = node_to_idx.get(edge.to).?;
                    const w = edge.data;
                    const h_v = h[v_idx];

                    const reweighted_w = subFn(addFn(w, h_u_inner), h_v);
                    const tentative = addFn(current_dist, reweighted_w);

                    const old_dist = dist[v_idx];
                    const better = if (old_dist) |old|
                        compareFn(tentative, old) == .lt
                    else
                        true;

                    if (better) {
                        dist[v_idx] = tentative;
                        try pq.add(.{ .node_idx = v_idx, .d = tentative });
                    }
                }
            }

            const h_u = h[u_idx];
            for (0..n) |v_idx| {
                if (dist[v_idx]) |d_prime| {
                    const h_v = h[v_idx];
                    const final_d = subFn(addFn(d_prime, h_v), h_u);
                    final_matrix[u_idx * n + v_idx] = final_d;
                }
            }
        }
    }

    return AllPairsShortestPathResult(NodeId, Weight){
        .allocator = allocator,
        .matrix = final_matrix,
        .node_to_idx = node_to_idx,
        .stride = n,
    };
}

// --- Tests ---

test "floydWarshall on triangle" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 2, 2.0);
    _ = try g.addEdge(0, 2, 5.0);

    var result = try floydWarshall(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(f64, 1.0), result.get(0, 1).?);
    try std.testing.expectEqual(@as(f64, 2.0), result.get(1, 2).?);
    try std.testing.expectEqual(@as(f64, 3.0), result.get(0, 2).?);
    try std.testing.expectEqual(@as(f64, 0.0), result.get(0, 0).?);
}

test "floydWarshall detects negative cycle" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;
    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, 1.0);
    _ = try g.addEdge(1, 2, -3.0);
    _ = try g.addEdge(2, 0, 1.0);

    const result = floydWarshall(allocator, g);
    try std.testing.expectError(error.NegativeCycle, result);
}

test "Johnson's Algorithm: Simple graph with negative weights" {
    const models = @import("../root.zig").models;
    const allocator = std.testing.allocator;
    var g = models.ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    // Nodes: 0, 1, 2, 3, 4
    for (0..5) |_| _ = try g.addNode({});

    _ = try g.addEdge(0, 1, 3.0);
    _ = try g.addEdge(0, 2, 8.0);
    _ = try g.addEdge(0, 4, -4.0);
    _ = try g.addEdge(1, 3, 1.0);
    _ = try g.addEdge(1, 4, 7.0);
    _ = try g.addEdge(2, 1, 4.0);
    _ = try g.addEdge(3, 0, 2.0);
    _ = try g.addEdge(3, 2, -5.0);
    _ = try g.addEdge(4, 3, 6.0);

    var result = try johnsonsGeneric(
        allocator,
        g,
        f64,
        0.0,
        utils.addF64,
        utils.subF64,
        utils.compareF64,
    );
    defer result.deinit();

    try std.testing.expectEqual(@as(f64, 0.0), result.get(0, 0).?);
    try std.testing.expectEqual(@as(f64, 1.0), result.get(0, 1).?);
    try std.testing.expectEqual(@as(f64, -3.0), result.get(0, 2).?);
    try std.testing.expectEqual(@as(f64, 2.0), result.get(0, 3).?);
    try std.testing.expectEqual(@as(f64, -4.0), result.get(0, 4).?);
    try std.testing.expectEqual(@as(f64, 8.0), result.get(4, 0).?);
}
