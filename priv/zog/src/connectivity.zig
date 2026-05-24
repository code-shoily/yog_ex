const std = @import("std");
const utils = @import("utils.zig");
const traversal = @import("traversal.zig");

// =============================================================================
// Types
// =============================================================================

pub fn Bridge(comptime NodeId: type) type {
    return struct {
        from: NodeId,
        to: NodeId,
    };
}

pub fn AnalysisResult(comptime NodeId: type) type {
    return struct {
        allocator: std.mem.Allocator,
        bridges: []Bridge(NodeId),
        articulation_points: []NodeId,

        pub fn deinit(self: @This()) void {
            self.allocator.free(self.bridges);
            self.allocator.free(self.articulation_points);
        }
    };
}

pub fn ComponentsResult(comptime NodeId: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        components: [][]NodeId,

        pub fn deinit(self: Self) void {
            for (self.components) |comp| {
                self.allocator.free(comp);
            }
            self.allocator.free(self.components);
        }

        pub fn componentCount(self: Self) usize {
            return self.components.len;
        }
    };
}

pub fn CoreNumbersResult(comptime NodeId: type) type {
    return struct {
        map: std.AutoHashMap(NodeId, usize),

        pub fn deinit(self: *@This()) void {
            self.map.deinit();
        }
    };
}

// =============================================================================
// Bridge & Articulation Point Analysis (Tarjan)
// =============================================================================

/// Analyzes an undirected graph to find all bridges and articulation points
/// using Tarjan's algorithm in a single DFS pass.
pub fn analyze(allocator: std.mem.Allocator, graph: anytype) !AnalysisResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var tin = std.AutoHashMap(NodeId, usize).init(allocator);
    defer tin.deinit();
    var low = std.AutoHashMap(NodeId, usize).init(allocator);
    defer low.deinit();
    var points = std.AutoHashMap(NodeId, void).init(allocator);
    defer points.deinit();
    var bridges = std.ArrayList(Bridge(NodeId)).empty;
    defer bridges.deinit(allocator);

    var timer: usize = 0;

    const Context = struct {
        tin: *std.AutoHashMap(NodeId, usize),
        low: *std.AutoHashMap(NodeId, usize),
        points: *std.AutoHashMap(NodeId, void),
        bridges: *std.ArrayList(Bridge(NodeId)),
        children: *std.AutoHashMap(NodeId, usize),
        timer: *usize,
        root: NodeId = undefined,
        allocator: std.mem.Allocator,
    };

    var children_map = std.AutoHashMap(NodeId, usize).init(allocator);
    defer children_map.deinit();

    var ctx = Context{
        .tin = &tin,
        .low = &low,
        .points = &points,
        .bridges = &bridges,
        .children = &children_map,
        .timer = &timer,
        .allocator = allocator,
    };

    const Callbacks = traversal.DfsCallbacks(NodeId, *Context);
    const cb = Callbacks{
        .onDiscover = struct {
            fn f(c: *Context, u: NodeId) !void {
                try c.tin.put(u, c.timer.*);
                try c.low.put(u, c.timer.*);
                c.timer.* += 1;
            }
        }.f,
        .onBackEdge = struct {
            fn f(c: *Context, u: NodeId, v: NodeId) !void {
                const u_low = c.low.get(u).?;
                const v_tin = c.tin.get(v).?;
                try c.low.put(u, @min(u_low, v_tin));
            }
        }.f,
        .onTreeEdge = struct {
            fn f(c: *Context, u: NodeId, _: NodeId) !void {
                const gop = try c.children.getOrPut(u);
                if (!gop.found_existing) gop.value_ptr.* = 0;
                gop.value_ptr.* += 1;
            }
        }.f,
        .onFinish = struct {
            fn f(c: *Context, u: NodeId, p: ?NodeId) !void {
                if (p) |parent| {
                    const u_low = c.low.get(u).?;
                    const parent_low = c.low.get(parent).?;
                    try c.low.put(parent, @min(parent_low, u_low));

                    const parent_tin = c.tin.get(parent).?;
                    if (u_low > parent_tin) {
                        try c.bridges.append(c.allocator, .{ .from = parent, .to = u });
                    }

                    if (std.meta.eql(parent, c.root)) {
                        if ((c.children.get(parent) orelse 0) > 1) {
                            try c.points.put(parent, {});
                        }
                    } else if (u_low >= parent_tin) {
                        try c.points.put(parent, {});
                    }
                }
            }
        }.f,
    };

    var status = std.AutoHashMap(NodeId, traversal.DfsStatus).init(allocator);
    defer status.deinit();

    var node_it = graph.nodeIds();
    while (node_it.next()) |node| {
        if (status.contains(node)) continue;
        ctx.root = node;
        try traversal.dfsAdvanced(allocator, graph, node, &ctx, cb, &status);
    }

    const bridges_slice = try bridges.toOwnedSlice(allocator);
    var points_list = std.ArrayList(NodeId).empty;
    defer points_list.deinit(allocator);
    var pit = points.keyIterator();
    while (pit.next()) |key| try points_list.append(allocator, key.*);

    return .{
        .allocator = allocator,
        .bridges = bridges_slice,
        .articulation_points = try points_list.toOwnedSlice(allocator),
    };
}

// =============================================================================
// Tarjan's Strongly Connected Components
// =============================================================================

/// Finds Strongly Connected Components using Tarjan's Algorithm.
pub fn stronglyConnectedComponents(allocator: std.mem.Allocator, graph: anytype) !ComponentsResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var indices = std.AutoHashMap(NodeId, usize).init(allocator);
    defer indices.deinit();
    var low_links = std.AutoHashMap(NodeId, usize).init(allocator);
    defer low_links.deinit();
    var on_stack = std.AutoHashMap(NodeId, bool).init(allocator);
    defer on_stack.deinit();
    var stack = std.ArrayList(NodeId).empty;
    defer stack.deinit(allocator);
    var components = std.ArrayList([]NodeId).empty;
    defer {
        for (components.items) |comp| allocator.free(comp);
        components.deinit(allocator);
    }

    var index: usize = 0;

    const Context = struct {
        indices: *std.AutoHashMap(NodeId, usize),
        low_links: *std.AutoHashMap(NodeId, usize),
        on_stack: *std.AutoHashMap(NodeId, bool),
        stack: *std.ArrayList(NodeId),
        components: *std.ArrayList([]NodeId),
        allocator: std.mem.Allocator,
        index: *usize,
    };

    var ctx = Context{
        .indices = &indices,
        .low_links = &low_links,
        .on_stack = &on_stack,
        .stack = &stack,
        .components = &components,
        .allocator = allocator,
        .index = &index,
    };

    const Callbacks = traversal.DfsCallbacks(NodeId, *Context);
    const cb = Callbacks{
        .onDiscover = struct {
            fn f(c: *Context, u: NodeId) !void {
                try c.indices.put(u, c.index.*);
                try c.low_links.put(u, c.index.*);
                c.index.* += 1;
                try c.stack.append(c.allocator, u);
                try c.on_stack.put(u, true);
            }
        }.f,
        .onBackEdge = struct {
            fn f(c: *Context, u: NodeId, v: NodeId) !void {
                if (c.on_stack.get(v) orelse false) {
                    const u_low = c.low_links.get(u).?;
                    const v_index = c.indices.get(v).?;
                    try c.low_links.put(u, @min(u_low, v_index));
                }
            }
        }.f,
        .onFinish = struct {
            fn f(c: *Context, u: NodeId, p: ?NodeId) !void {
                const u_index = c.indices.get(u).?;
                const u_low = c.low_links.get(u).?;

                if (u_low == u_index) {
                    var component = std.ArrayList(NodeId).empty;
                    defer component.deinit(c.allocator);
                    while (true) {
                        const w = c.stack.pop().?;
                        try c.on_stack.put(w, false);
                        try component.append(c.allocator, w);
                        if (std.meta.eql(w, u)) break;
                    }
                    try c.components.append(c.allocator, try component.toOwnedSlice(c.allocator));
                }

                if (p) |parent| {
                    const parent_low = c.low_links.get(parent).?;
                    const child_low = c.low_links.get(u).?;
                    try c.low_links.put(parent, @min(parent_low, child_low));
                }
            }
        }.f,
    };

    var status = std.AutoHashMap(NodeId, traversal.DfsStatus).init(allocator);
    defer status.deinit();

    var node_it = graph.nodeIds();
    while (node_it.next()) |node| {
        if (status.contains(node)) continue;
        try traversal.dfsAdvanced(allocator, graph, node, &ctx, cb, &status);
    }

    const comps = try components.toOwnedSlice(allocator);
    return .{
        .allocator = allocator,
        .components = comps,
    };
}

// =============================================================================
// Kosaraju's Algorithm
// =============================================================================

/// Finds Strongly Connected Components using Kosaraju's Algorithm.
pub fn kosaraju(allocator: std.mem.Allocator, graph: anytype) !ComponentsResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    // First DFS: compute finishing order.
    var finish_stack = std.ArrayList(NodeId).empty;
    defer finish_stack.deinit(allocator);

    const FirstPassContext = struct {
        allocator: std.mem.Allocator,
        stack: *std.ArrayList(NodeId),
    };
    var fp_ctx = FirstPassContext{ .allocator = allocator, .stack = &finish_stack };

    const FirstPassCallbacks = traversal.DfsCallbacks(NodeId, *FirstPassContext);
    const first_cb = FirstPassCallbacks{
        .onFinish = struct {
            fn f(c: *FirstPassContext, u: NodeId, _: ?NodeId) !void {
                try c.stack.append(c.allocator, u);
            }
        }.f,
    };

    var status = std.AutoHashMap(NodeId, traversal.DfsStatus).init(allocator);
    defer status.deinit();

    var node_it = graph.nodeIds();
    while (node_it.next()) |node| {
        if (status.contains(node)) continue;
        try traversal.dfsAdvanced(allocator, graph, node, &fp_ctx, first_cb, &status);
    }

    // Build transpose.
    var transpose = std.AutoHashMap(NodeId, std.ArrayList(NodeId)).init(allocator);
    defer {
        var tit = transpose.valueIterator();
        while (tit.next()) |list| list.deinit(allocator);
        transpose.deinit();
    }

    var nit = graph.nodeIds();
    while (nit.next()) |from| {
        var succ_it = graph.successors(from);
        while (succ_it.next()) |edge| {
            const to = edge.to;
            const gop = try transpose.getOrPut(to);
            if (!gop.found_existing) gop.value_ptr.* = std.ArrayList(NodeId).empty;
            try gop.value_ptr.append(allocator, from);
        }
    }

    // Second DFS: process in reverse finishing order.
    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();
    var components = std.ArrayList([]NodeId).empty;
    defer {
        for (components.items) |comp| allocator.free(comp);
        components.deinit(allocator);
    }

    const G = struct {
        adj: *const std.AutoHashMap(NodeId, std.ArrayList(NodeId)),
        pub fn successors(self: @This(), u: NodeId) utils.SliceIterator(NodeId) {
            const list = self.adj.get(u) orelse return .{ .items = &[_]NodeId{} };
            return .{ .items = list.items };
        }
    };

    const CollectCtx = struct {
        allocator: std.mem.Allocator,
        list: *std.ArrayList(NodeId),
        fn visit(ctx: @This(), node: NodeId) bool {
            ctx.list.append(ctx.allocator, node) catch return false;
            return true;
        }
    };

    var i: usize = finish_stack.items.len;
    while (i > 0) {
        i -= 1;
        const node = finish_stack.items[i];
        if (visited.contains(node)) continue;

        var component = std.ArrayList(NodeId).empty;
        errdefer component.deinit(allocator);
        try traversal.dfs(allocator, G{ .adj = &transpose }, node, CollectCtx{ .allocator = allocator, .list = &component }, CollectCtx.visit, &visited);
        try components.append(allocator, try component.toOwnedSlice(allocator));
    }

    const comps = try components.toOwnedSlice(allocator);
    return .{
        .allocator = allocator,
        .components = comps,
    };
}

// =============================================================================
// Connected Components (Undirected)
// =============================================================================

pub fn connectedComponents(allocator: std.mem.Allocator, graph: anytype) !ComponentsResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();
    var components = std.ArrayList([]NodeId).empty;
    defer {
        for (components.items) |comp| allocator.free(comp);
        components.deinit(allocator);
    }

    const CollectCtx = struct {
        allocator: std.mem.Allocator,
        list: *std.ArrayList(NodeId),
        fn visit(ctx: @This(), node: NodeId) bool {
            ctx.list.append(ctx.allocator, node) catch return false;
            return true;
        }
    };

    var node_it = graph.nodeIds();
    while (node_it.next()) |node| {
        if (visited.contains(node)) continue;
        var component = std.ArrayList(NodeId).empty;
        errdefer component.deinit(allocator);

        try traversal.dfs(allocator, graph, node, CollectCtx{ .allocator = allocator, .list = &component }, CollectCtx.visit, &visited);
        try components.append(allocator, try component.toOwnedSlice(allocator));
    }

    const comps = try components.toOwnedSlice(allocator);
    return .{
        .allocator = allocator,
        .components = comps,
    };
}

// =============================================================================
// Weakly Connected Components (Directed)
// =============================================================================

pub fn weaklyConnectedComponents(allocator: std.mem.Allocator, graph: anytype) !ComponentsResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var adj = std.AutoHashMap(NodeId, std.ArrayList(NodeId)).init(allocator);
    defer {
        var ait = adj.valueIterator();
        while (ait.next()) |list| list.deinit(allocator);
        adj.deinit();
    }

    var nit = graph.nodeIds();
    while (nit.next()) |from| {
        var succ_it = graph.successors(from);
        while (succ_it.next()) |edge| {
            const to = edge.to;
            const gop1 = try adj.getOrPut(from);
            if (!gop1.found_existing) gop1.value_ptr.* = std.ArrayList(NodeId).empty;
            try gop1.value_ptr.append(allocator, to);

            const gop2 = try adj.getOrPut(to);
            if (!gop2.found_existing) gop2.value_ptr.* = std.ArrayList(NodeId).empty;
            try gop2.value_ptr.append(allocator, from);
        }
    }

    var visited = std.AutoHashMap(NodeId, void).init(allocator);
    defer visited.deinit();
    var components = std.ArrayList([]NodeId).empty;
    defer {
        for (components.items) |comp| allocator.free(comp);
        components.deinit(allocator);
    }

    const G = struct {
        adj: *const std.AutoHashMap(NodeId, std.ArrayList(NodeId)),
        pub fn successors(self: @This(), u: NodeId) utils.SliceIterator(NodeId) {
            const list = self.adj.get(u) orelse return .{ .items = &[_]NodeId{} };
            return .{ .items = list.items };
        }
    };

    const CollectCtx = struct {
        allocator: std.mem.Allocator,
        list: *std.ArrayList(NodeId),
        fn visit(ctx: @This(), node: NodeId) bool {
            ctx.list.append(ctx.allocator, node) catch return false;
            return true;
        }
    };

    nit = graph.nodeIds();
    while (nit.next()) |node| {
        if (visited.contains(node)) continue;
        var component = std.ArrayList(NodeId).empty;
        errdefer component.deinit(allocator);
        try traversal.dfs(allocator, G{ .adj = &adj }, node, CollectCtx{ .allocator = allocator, .list = &component }, CollectCtx.visit, &visited);
        try components.append(allocator, try component.toOwnedSlice(allocator));
    }

    const comps = try components.toOwnedSlice(allocator);
    return .{
        .allocator = allocator,
        .components = comps,
    };
}

// =============================================================================
// Core Number Analysis
// =============================================================================

pub fn coreNumbers(allocator: std.mem.Allocator, graph: anytype) !CoreNumbersResult(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var degrees = std.AutoHashMap(NodeId, usize).init(allocator);
    defer degrees.deinit();

    var max_deg: usize = 0;
    var node_it = graph.nodeIds();
    while (node_it.next()) |u| {
        var deg: usize = 0;
        var it = graph.successors(u);
        while (it.next()) |_| {
            deg += 1;
        }
        try degrees.put(u, deg);
        if (deg > max_deg) max_deg = deg;
    }

    var buckets = std.AutoHashMap(usize, std.ArrayList(NodeId)).init(allocator);
    defer {
        var bit = buckets.valueIterator();
        while (bit.next()) |list| list.deinit(allocator);
        buckets.deinit();
    }

    var nit = graph.nodeIds();
    while (nit.next()) |u| {
        const deg = degrees.get(u).?;
        const gop = try buckets.getOrPut(deg);
        if (!gop.found_existing) gop.value_ptr.* = std.ArrayList(NodeId).empty;
        try gop.value_ptr.append(allocator, u);
    }

    var processed = std.AutoHashMap(NodeId, void).init(allocator);
    defer processed.deinit();
    var cores = std.AutoHashMap(NodeId, usize).init(allocator);

    var k: usize = 0;
    while (k <= max_deg) : (k += 1) {
        while (true) {
            const bucket_ptr = buckets.getPtr(k) orelse break;
            if (bucket_ptr.items.len == 0) break;

            const u = bucket_ptr.pop().?;
            if (processed.contains(u)) continue;

            try cores.put(u, k);
            try processed.put(u, {});

            var it = graph.successors(u);
            while (it.next()) |edge| {
                const v = edge.to;
                if (processed.contains(v)) continue;
                const old_deg = degrees.get(v).?;
                const new_deg = old_deg - 1;
                try degrees.put(v, new_deg);

                const target_bucket = @max(new_deg, k);
                const gop = try buckets.getOrPut(target_bucket);
                if (!gop.found_existing) gop.value_ptr.* = std.ArrayList(NodeId).empty;
                try gop.value_ptr.append(allocator, v);
            }
        }
    }

    return .{ .map = cores };
}

pub fn degeneracy(allocator: std.mem.Allocator, graph: anytype) !usize {
    var cores = try coreNumbers(allocator, graph);
    defer cores.deinit();

    var max_core: usize = 0;
    var it = cores.map.valueIterator();
    while (it.next()) |c| {
        if (c.* > max_core) max_core = c.*;
    }
    return max_core;
}

pub fn shellDecomposition(allocator: std.mem.Allocator, graph: anytype) !std.AutoHashMap(usize, []utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var cores = try coreNumbers(allocator, graph);
    defer cores.deinit();

    var shells = std.AutoHashMap(usize, std.ArrayList(NodeId)).init(allocator);
    defer {
        var sit = shells.valueIterator();
        while (sit.next()) |list| list.deinit(allocator);
        shells.deinit();
    }

    var it = cores.map.iterator();
    while (it.next()) |entry| {
        const node = entry.key_ptr.*;
        const core = entry.value_ptr.*;
        const gop = try shells.getOrPut(core);
        if (!gop.found_existing) gop.value_ptr.* = std.ArrayList(NodeId).empty;
        try gop.value_ptr.append(allocator, node);
    }

    var result = std.AutoHashMap(usize, []NodeId).init(allocator);
    errdefer {
        var rit = result.valueIterator();
        while (rit.next()) |slice| allocator.free(slice.*);
        result.deinit();
    }

    var sit = shells.iterator();
    while (sit.next()) |entry| {
        try result.put(entry.key_ptr.*, try entry.value_ptr.*.toOwnedSlice(allocator));
    }

    return result;
}

// =============================================================================
// Tests
// =============================================================================

test "connectedComponents on undirected graph" {
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

    var result = try connectedComponents(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.componentCount());
}

test "connectedComponents on fully disconnected graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    var result = try connectedComponents(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.componentCount());
    for (result.components) |comp| {
        try std.testing.expectEqual(@as(usize, 1), comp.len);
    }
}

test "stronglyConnectedComponents on cycle" {
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

    var result = try stronglyConnectedComponents(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.componentCount());
    try std.testing.expectEqual(@as(usize, 3), result.components[0].len);
}

test "stronglyConnectedComponents on DAG" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 2, {});

    var result = try stronglyConnectedComponents(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.componentCount());
}

test "kosaraju matches tarjan on cycle" {
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

    var tarjan = try stronglyConnectedComponents(allocator, g);
    defer tarjan.deinit();

    var kos = try kosaraju(allocator, g);
    defer kos.deinit();

    try std.testing.expectEqual(tarjan.componentCount(), kos.componentCount());
}

test "analyze finds bridges and articulation points" {
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

    var result = try analyze(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.bridges.len);
    try std.testing.expectEqual(@as(usize, 1), result.articulation_points.len);
    try std.testing.expectEqual(@as(u32, 1), result.articulation_points[0]);
}

test "analyze on cycle has no bridges" {
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

    var result = try analyze(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.bridges.len);
    try std.testing.expectEqual(@as(usize, 0), result.articulation_points.len);
}

test "weaklyConnectedComponents on directed graph" {
    const allocator = std.testing.allocator;
    const AG = @import("models/array_graph.zig").ArrayGraph;
    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    _ = try g.addEdge(0, 1, {});

    var result = try weaklyConnectedComponents(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.componentCount());
}

test "coreNumbers on triangle" {
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

    var result = try coreNumbers(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.map.get(0).?);
    try std.testing.expectEqual(@as(usize, 2), result.map.get(1).?);
    try std.testing.expectEqual(@as(usize, 2), result.map.get(2).?);
}

test "degeneracy on triangle" {
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

    const d = try degeneracy(allocator, g);
    try std.testing.expectEqual(@as(usize, 2), d);
}
