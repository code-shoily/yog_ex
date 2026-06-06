const std = @import("std");

/// Computes core numbers for all nodes in the undirected graph.
/// Returns an allocated slice of core numbers.
pub fn coreNumbers(allocator: std.mem.Allocator, graph: anytype) ![]u32 {
    const V = graph.nodeCount();
    const cores = try allocator.alloc(u32, V);
    @memset(cores, 0);

    if (V == 0) return cores;

    // Build undirected adjacency list
    var degrees = try allocator.alloc(u32, V);
    defer allocator.free(degrees);
    var adj = try allocator.alloc(std.ArrayList(u32), V);
    defer allocator.free(adj);
    for (0..V) |i| {
        degrees[i] = 0;
        adj[i] = std.ArrayList(u32).empty;
    }
    defer {
        for (0..V) |i| {
            adj[i].deinit(allocator);
        }
    }

    var node_it = graph.nodeIds();
    while (node_it.next()) |u| {
        var succ_it = graph.successors(u);
        while (succ_it.next()) |edge| {
            const v = edge.to;
            if (u != v) {
                var found = false;
                for (adj[u].items) |existing| {
                    if (existing == v) { found = true; break; }
                }
                if (!found) {
                    try adj[u].append(allocator, v);
                    try adj[v].append(allocator, u);
                    degrees[u] += 1;
                    degrees[v] += 1;
                }
            }
        }
    }

    var max_deg: u32 = 0;
    for (degrees) |d| {
        if (d > max_deg) max_deg = d;
    }

    // Build buckets (arrays of array lists) of size max_deg + 1
    var buckets = try allocator.alloc(std.ArrayList(u32), max_deg + 1);
    defer allocator.free(buckets);
    for (0..max_deg + 1) |i| {
        buckets[i] = std.ArrayList(u32).empty;
    }
    defer {
        for (0..max_deg + 1) |i| {
            buckets[i].deinit(allocator);
        }
    }

    // Populate buckets based on initial degrees
    for (0..V) |u| {
        const d = degrees[u];
        try buckets[d].append(allocator, @intCast(u));
    }

    var processed = try std.DynamicBitSet.initEmpty(allocator, V);
    defer processed.deinit();

    // Loop through degrees/buckets
    var i: usize = 0;
    while (i <= max_deg) {
        while (buckets[i].items.len > 0) {
            const u = @as(usize, buckets[i].pop().?);
            if (processed.isSet(u)) continue;

            cores[u] = @intCast(i);
            processed.set(u);

            for (adj[u].items) |v_u32| {
                const v = @as(usize, v_u32);
                if (processed.isSet(v)) continue;

                const old_deg = degrees[v];
                if (old_deg > 0) {
                    degrees[v] -= 1;
                }
                const new_deg = degrees[v];

                const target_bucket = @max(new_deg, i);
                try buckets[target_bucket].append(allocator, @intCast(v));
            }
        }
        i += 1;
    }

    return cores;
}

test "coreNumbers: cycle graph and clique" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, {}); _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {}); _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 3, {}); _ = try g.addEdge(3, 2, {});
    _ = try g.addEdge(3, 0, {}); _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(0, 4, {}); _ = try g.addEdge(4, 0, {});

    const cores = try coreNumbers(allocator, g);
    defer allocator.free(cores);

    try std.testing.expectEqual(@as(u32, 2), cores[0]);
    try std.testing.expectEqual(@as(u32, 2), cores[1]);
    try std.testing.expectEqual(@as(u32, 2), cores[2]);
    try std.testing.expectEqual(@as(u32, 2), cores[3]);
    try std.testing.expectEqual(@as(u32, 1), cores[4]);
}

const TarjanContext = struct {
    allocator: std.mem.Allocator,
    V: usize,
    adj: []std.ArrayList(u32),
    disc: []u32,
    low: []u32,
    parent: []u32,
    visited: []bool,
    time: u32,
    articulation_points_set: []bool,
    bridges: *std.ArrayList([2]u32),
    err: ?anyerror,

    fn dfs(self: *TarjanContext, u: u32) !void {
        self.visited[u] = true;
        self.disc[u] = self.time;
        self.low[u] = self.time;
        self.time += 1;
        var children: u32 = 0;

        for (self.adj[u].items) |v| {
            if (!self.visited[v]) {
                children += 1;
                self.parent[v] = u;
                try self.dfs(v);

                self.low[u] = @min(self.low[u], self.low[v]);

                if (self.parent[u] == std.math.maxInt(u32)) {
                    if (children > 1) {
                        self.articulation_points_set[u] = true;
                    }
                } else {
                    if (self.low[v] >= self.disc[u]) {
                        self.articulation_points_set[u] = true;
                    }
                }

                if (self.low[v] > self.disc[u]) {
                    const b0 = @min(u, v);
                    const b1 = @max(u, v);
                    try self.bridges.append(self.allocator, .{ b0, b1 });
                }
            } else if (v != self.parent[u]) {
                self.low[u] = @min(self.low[u], self.disc[v]);
            }
        }
    }
};

fn runDfsOnThread(ctx: *TarjanContext) void {
    for (0..ctx.V) |i| {
        if (!ctx.visited[i]) {
            ctx.dfs(@intCast(i)) catch |err| {
                ctx.err = err;
                return;
            };
        }
    }
}

pub const ConnectivityAnalysisResult = struct {
    bridges: [][2]u32,
    articulation_points: []u32,
};

/// Finds all bridges and articulation points in the undirected graph using Tarjan's DFS algorithm.
pub fn analyzeConnectivity(allocator: std.mem.Allocator, graph: anytype) !ConnectivityAnalysisResult {
    const V = graph.nodeCount();
    if (V == 0) {
        return .{
            .bridges = &[_][2]u32{},
            .articulation_points = &[_]u32{},
        };
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const temp_allocator = arena.allocator();

    // Build undirected adjacency list
    var adj = try temp_allocator.alloc(std.ArrayList(u32), V);
    defer temp_allocator.free(adj);
    for (0..V) |i| {
        adj[i] = std.ArrayList(u32).empty;
    }
    defer {
        for (0..V) |i| {
            adj[i].deinit(temp_allocator);
        }
    }

    var node_it = graph.nodeIds();
    while (node_it.next()) |u| {
        var succ_it = graph.successors(u);
        while (succ_it.next()) |edge| {
            const v = edge.to;
            if (u != v) {
                var found = false;
                for (adj[u].items) |existing| {
                    if (existing == v) { found = true; break; }
                }
                if (!found) {
                    try adj[u].append(temp_allocator, v);
                    try adj[v].append(temp_allocator, u);
                }
            }
        }
    }

    const disc = try temp_allocator.alloc(u32, V);
    defer temp_allocator.free(disc);
    @memset(disc, 0);

    const low = try temp_allocator.alloc(u32, V);
    defer temp_allocator.free(low);
    @memset(low, 0);

    const parent = try temp_allocator.alloc(u32, V);
    defer temp_allocator.free(parent);
    @memset(parent, std.math.maxInt(u32));

    const visited = try temp_allocator.alloc(bool, V);
    defer temp_allocator.free(visited);
    @memset(visited, false);

    const articulation_points_set = try temp_allocator.alloc(bool, V);
    defer temp_allocator.free(articulation_points_set);
    @memset(articulation_points_set, false);

    var bridges_list = std.ArrayList([2]u32).empty;
    defer bridges_list.deinit(temp_allocator);

    var ctx = TarjanContext{
        .allocator = temp_allocator,
        .V = V,
        .adj = adj,
        .disc = disc,
        .low = low,
        .parent = parent,
        .visited = visited,
        .time = 0,
        .articulation_points_set = articulation_points_set,
        .bridges = &bridges_list,
        .err = null,
    };

    const thread = try std.Thread.spawn(.{ .stack_size = 4 * 1024 * 1024 }, runDfsOnThread, .{&ctx});
    thread.join();

    if (ctx.err) |err| {
        return err;
    }

    // Collect articulation points
    var ap_count: usize = 0;
    for (ctx.articulation_points_set) |is_ap| {
        if (is_ap) ap_count += 1;
    }

    const articulation_points = try allocator.alloc(u32, ap_count);
    errdefer allocator.free(articulation_points);
    var ap_idx: usize = 0;
    for (ctx.articulation_points_set, 0..) |is_ap, i| {
        if (is_ap) {
            articulation_points[ap_idx] = @intCast(i);
            ap_idx += 1;
        }
    }

    // Collect bridges as [][2]u32 using allocator (beam.allocator)
    const bridges = try allocator.alloc([2]u32, ctx.bridges.items.len);
    errdefer allocator.free(bridges);
    @memcpy(bridges, ctx.bridges.items);

    return .{
        .bridges = bridges,
        .articulation_points = articulation_points,
    };
}

test "analyzeConnectivity: cycle graph and tail" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, {}); _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {}); _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 3, {}); _ = try g.addEdge(3, 2, {});
    _ = try g.addEdge(3, 0, {}); _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(0, 4, {}); _ = try g.addEdge(4, 0, {});

    const res = try analyzeConnectivity(allocator, g);
    defer {
        for (res.bridges) |b| {
            allocator.free(b);
        }
        allocator.free(res.bridges);
        allocator.free(res.articulation_points);
    }

    try std.testing.expectEqual(@as(usize, 1), res.bridges.len);
    try std.testing.expectEqual(@as(u32, 0), res.bridges[0][0]);
    try std.testing.expectEqual(@as(u32, 4), res.bridges[0][1]);

    try std.testing.expectEqual(@as(usize, 1), res.articulation_points.len);
    try std.testing.expectEqual(@as(u32, 0), res.articulation_points[0]);
}
