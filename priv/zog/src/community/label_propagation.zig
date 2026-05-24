const std = @import("std");
const utils = @import("../utils.zig");

/// Result of a community detection algorithm.
pub fn Communities(comptime NodeId: type) type {
    return struct {
        const Self = @This();

        /// Mapping from node ID to community ID.
        assignments: std.AutoHashMap(NodeId, usize),
        /// Number of distinct communities.
        num_communities: usize,

        pub fn deinit(self: *Self) void {
            self.assignments.deinit();
        }
    };
}

/// Options for Label Propagation Algorithm.
pub const LabelPropagationOptions = struct {
    max_iterations: usize = 100,
    seed: u64 = 42,
};

/// Detects communities using the Label Propagation Algorithm with default options.
///
/// LPA is a near-linear time algorithm where each node adopts the most
/// frequent label among its neighbors until convergence.
///
/// For graphs with dense unsigned-integer node IDs (e.g. ArrayGraph's u32),
/// labels are stored in a flat slice for O(1) cache-friendly lookups.
///
/// **Time Complexity:** O(E × iterations)
pub fn detect(
    allocator: std.mem.Allocator,
    graph: anytype,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    return detectWithOptions(allocator, graph, .{});
}

/// Detects communities using LPA with custom options.
pub fn detectWithOptions(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LabelPropagationOptions,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const node_id_is_dense_unsigned = comptime blk: {
        const info = @typeInfo(NodeId);
        break :blk info == .int and info.int.signedness == .unsigned;
    };

    // Collect all nodes.
    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    if (nodes.items.len == 0) {
        const empty = std.AutoHashMap(NodeId, usize).init(allocator);
        return .{ .assignments = empty, .num_communities = 0 };
    }

    var prng = std.Random.DefaultPrng.init(options.seed);
    const random = prng.random();

    // Working copy of nodes for shuffling.
    const shuffled = try allocator.dupe(NodeId, nodes.items);
    defer allocator.free(shuffled);

    var label_counts = std.AutoHashMap(usize, usize).init(allocator);
    defer label_counts.deinit();

    // -------------------------------------------------------------------------
    // Fast path: dense unsigned integer NodeIds → flat slice.
    // -------------------------------------------------------------------------
    if (node_id_is_dense_unsigned) {
        var max_id: NodeId = 0;
        for (nodes.items) |node| {
            if (node > max_id) max_id = node;
        }
        const slice_len = @as(usize, max_id) + 1;

        var labels = try allocator.alloc(usize, slice_len);
        defer allocator.free(labels);
        @memset(labels, 0);

        for (nodes.items, 0..) |node, i| {
            labels[node] = i;
        }

        // Flat arrays for O(1) label-count accumulation (no HashMap in hot loop).
        const label_counts_buf = try allocator.alloc(usize, slice_len);
        defer allocator.free(label_counts_buf);
        @memset(label_counts_buf, 0);

        const label_seen = try allocator.alloc(bool, slice_len);
        defer allocator.free(label_seen);
        @memset(label_seen, false);

        const active_labels = try allocator.alloc(usize, slice_len);
        defer allocator.free(active_labels);

        var changed = true;
        var iteration: usize = 0;

        while (changed and iteration < options.max_iterations) : (iteration += 1) {
            changed = false;
            random.shuffle(NodeId, shuffled);

            for (shuffled) |node| {
                var active_count: usize = 0;
                var has_neighbors = false;

                var sit = graph.successors(node);
                while (sit.next()) |edge| {
                    has_neighbors = true;
                    const neighbor = edge.to;
                    const neighbor_label = labels[neighbor];

                    if (!label_seen[neighbor_label]) {
                        label_seen[neighbor_label] = true;
                        active_labels[active_count] = neighbor_label;
                        active_count += 1;
                    }
                    label_counts_buf[neighbor_label] += 1;
                }

                if (!has_neighbors) continue;

                var best_label: usize = 0;
                var max_count: usize = 0;
                var num_ties: usize = 0;

                for (0..active_count) |j| {
                    const label = active_labels[j];
                    const count = label_counts_buf[label];
                    if (count > max_count) {
                        max_count = count;
                        best_label = label;
                        num_ties = 1;
                    } else if (count == max_count) {
                        num_ties += 1;
                        // Deterministic tie-breaking: smaller label wins.
                        // (Eliminates RNG calls from the hot loop.)
                        if (label < best_label) {
                            best_label = label;
                        }
                    }
                }

                // Fast reset: only clear the labels we touched.
                for (0..active_count) |j| {
                    const lbl = active_labels[j];
                    label_counts_buf[lbl] = 0;
                    label_seen[lbl] = false;
                }

                if (num_ties == 0) continue;

                const old_label = labels[node];
                if (best_label != old_label) {
                    labels[node] = best_label;
                    changed = true;
                }
            }
        }

        return try buildResult(allocator, nodes.items, labels);
    }

    // -------------------------------------------------------------------------
    // Fallback: arbitrary NodeIds → HashMap.
    // -------------------------------------------------------------------------
    var labels = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer labels.deinit();

    for (nodes.items, 0..) |node, i| {
        try labels.put(node, i);
    }

    var changed = true;
    var iteration: usize = 0;

    while (changed and iteration < options.max_iterations) : (iteration += 1) {
        changed = false;
        random.shuffle(NodeId, shuffled);

        for (shuffled) |node| {
            label_counts.clearRetainingCapacity();
            var has_neighbors = false;

            var succ_it = graph.successors(node);
            while (succ_it.next()) |edge| {
                has_neighbors = true;
                const neighbor_label = labels.get(edge.to) orelse edge.to;
                const gop = try label_counts.getOrPut(neighbor_label);
                if (!gop.found_existing) gop.value_ptr.* = 0;
                gop.value_ptr.* += 1;
            }

            if (!has_neighbors) continue;

            var best_label: usize = 0;
            var max_count: usize = 0;
            var num_ties: usize = 0;

            var it = label_counts.iterator();
            while (it.next()) |entry| {
                const count = entry.value_ptr.*;
                const label = entry.key_ptr.*;
                if (count > max_count) {
                    max_count = count;
                    best_label = label;
                    num_ties = 1;
                } else if (count == max_count) {
                    num_ties += 1;
                    if (random.uintLessThan(usize, num_ties) == 0) {
                        best_label = label;
                    }
                }
            }

            if (num_ties == 0) continue;

            const old_label = labels.get(node).?;
            if (best_label != old_label) {
                try labels.put(node, best_label);
                changed = true;
            }
        }
    }

    var unique = std.AutoHashMap(usize, void).init(allocator);
    defer unique.deinit();

    var lit = labels.valueIterator();
    while (lit.next()) |label_ptr| {
        try unique.put(label_ptr.*, {});
    }

    return .{
        .assignments = labels,
        .num_communities = unique.count(),
    };
}

// =============================================================================
// Parallel LPA (dense unsigned-integer node IDs only)
// =============================================================================

/// Detects communities using parallel LPA.
///
/// Each iteration shuffles the node order, splits it into chunks, and spawns
/// worker threads. Workers read neighbor labels from a shared slice (dirty
/// reads are expected and harmless) and write only their assigned nodes.
///
/// Only available for graphs with dense unsigned-integer node IDs.
pub fn detectParallel(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LabelPropagationOptions,
    thread_count: usize,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const node_id_is_dense_unsigned = comptime blk: {
        const info = @typeInfo(NodeId);
        break :blk info == .int and info.int.signedness == .unsigned;
    };

    if (!node_id_is_dense_unsigned) {
        @compileError("detectParallel requires dense unsigned-integer node IDs (e.g. ArrayGraph)");
    }

    // Collect all nodes.
    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    if (nodes.items.len == 0) {
        const empty = std.AutoHashMap(NodeId, usize).init(allocator);
        return .{ .assignments = empty, .num_communities = 0 };
    }

    var prng = std.Random.DefaultPrng.init(options.seed);
    const random = prng.random();

    const shuffled = try allocator.dupe(NodeId, nodes.items);
    defer allocator.free(shuffled);

    // Find max node ID to size the shared labels slice.
    var max_id: NodeId = 0;
    for (nodes.items) |node| {
        if (node > max_id) max_id = node;
    }
    const slice_len = @as(usize, max_id) + 1;

    var labels = try allocator.alloc(usize, slice_len);
    defer allocator.free(labels);
    @memset(labels, 0);

    for (nodes.items, 0..) |node, i| {
        labels[node] = i;
    }

    // Per-thread label-count buffers.
    var thread_label_counts = try allocator.alloc(std.AutoHashMap(usize, usize), thread_count);
    defer {
        for (thread_label_counts) |*lc| lc.deinit();
        allocator.free(thread_label_counts);
    }
    for (thread_label_counts) |*lc| {
        lc.* = std.AutoHashMap(usize, usize).init(allocator);
    }

    var thread_changed = try allocator.alloc(bool, thread_count);
    defer allocator.free(thread_changed);

    const GraphType = @TypeOf(graph);

    var changed = true;
    var iteration: usize = 0;

    while (changed and iteration < options.max_iterations) : (iteration += 1) {
        changed = false;
        random.shuffle(NodeId, shuffled);

        const chunk_size = (shuffled.len + thread_count - 1) / thread_count;
        const actual_threads = @min(thread_count, shuffled.len);

        var threads = std.ArrayList(std.Thread).empty;
        defer threads.deinit(allocator);

        // errdefer joins any threads we already spawned if a later spawn fails.
        errdefer {
            for (threads.items) |*t| t.join();
        }

        for (0..actual_threads) |t| {
            const start = t * chunk_size;
            const end = @min(start + chunk_size, shuffled.len);
            if (start >= end) break;

            const ctx = ParallelCtx(GraphType){
                .graph = &graph,
                .nodes = shuffled[start..end],
                .labels = labels,
                .label_counts = &thread_label_counts[t],
                .changed = &thread_changed[t],
                .seed = options.seed ^ @as(u64, t) ^ @as(u64, iteration),
            };

            const Worker = ParallelWorker(GraphType);
            const thread = try std.Thread.spawn(.{}, Worker.run, .{ctx});
            try threads.append(allocator, thread);
        }

        for (threads.items) |*t| t.join();

        for (thread_changed[0..actual_threads]) |c| {
            if (c) {
                changed = true;
                break;
            }
        }
    }

    return try buildResult(allocator, nodes.items, labels);
}

fn ParallelCtx(comptime GraphType: type) type {
    const NodeId = utils.NodeId(GraphType);
    return struct {
        graph: *const GraphType,
        nodes: []const NodeId,
        labels: []usize,
        label_counts: *std.AutoHashMap(usize, usize),
        changed: *bool,
        seed: u64,
    };
}

fn ParallelWorker(comptime GraphType: type) type {
    return struct {
        pub fn run(ctx: ParallelCtx(GraphType)) void {
            var prng = std.Random.DefaultPrng.init(ctx.seed);
            const random = prng.random();

            ctx.changed.* = false;

            for (ctx.nodes) |node| {
                ctx.label_counts.clearRetainingCapacity();
                var has_neighbors = false;

                var succ_it = ctx.graph.successors(node);
                while (succ_it.next()) |edge| {
                    has_neighbors = true;
                    const neighbor_label = ctx.labels[edge.to];
                    const gop = ctx.label_counts.getOrPut(neighbor_label) catch continue;
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    gop.value_ptr.* += 1;
                }

                if (!has_neighbors) continue;

                var best_label: usize = 0;
                var max_count: usize = 0;
                var num_ties: usize = 0;

                var it = ctx.label_counts.iterator();
                while (it.next()) |entry| {
                    const count = entry.value_ptr.*;
                    const label = entry.key_ptr.*;
                    if (count > max_count) {
                        max_count = count;
                        best_label = label;
                        num_ties = 1;
                    } else if (count == max_count) {
                        num_ties += 1;
                        if (random.uintLessThan(usize, num_ties) == 0) {
                            best_label = label;
                        }
                    }
                }

                if (num_ties == 0) continue;

                const old_label = ctx.labels[node];
                if (best_label != old_label) {
                    ctx.labels[node] = best_label;
                    ctx.changed.* = true;
                }
            }
        }
    };
}

// =============================================================================
// Helpers
// =============================================================================

fn buildResult(
    allocator: std.mem.Allocator,
    nodes: anytype,
    labels: []usize,
) !Communities(@TypeOf(nodes[0])) {
    const NodeId = @TypeOf(nodes[0]);

    var unique = std.AutoHashMap(usize, void).init(allocator);
    defer unique.deinit();

    for (nodes) |node| {
        try unique.put(labels[node], {});
    }

    var result_map = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer result_map.deinit();
    for (nodes) |node| {
        try result_map.put(node, labels[node]);
    }

    return .{
        .assignments = result_map,
        .num_communities = unique.count(),
    };
}

// =============================================================================
// Tests
// =============================================================================

test "LPA on disconnected graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    // Two separate triangles.
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Triangle 0-1-2
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    // Triangle 3-4-5
    _ = try g.addEdge(3, 4, {});
    _ = try g.addEdge(4, 3, {});
    _ = try g.addEdge(4, 5, {});
    _ = try g.addEdge(5, 4, {});
    _ = try g.addEdge(5, 3, {});
    _ = try g.addEdge(3, 5, {});

    var result = try detect(allocator, g);
    defer result.deinit();

    // Should find exactly 2 communities.
    try std.testing.expectEqual(@as(usize, 2), result.num_communities);
}

test "LPA on empty graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.num_communities);
}

test "LPA on star graph converges to single community" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Star centered at 0.
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(3, 0, {});
    _ = try g.addEdge(0, 4, {});
    _ = try g.addEdge(4, 0, {});

    var result = try detectWithOptions(allocator, g, .{ .max_iterations = 200, .seed = 123 });
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.num_communities);
}

test "LPA on GraphMap (u32 nodes)" {
    const allocator = std.testing.allocator;
    const GM = @import("../models/graph_map.zig").GraphMap;
    const Direction = @import("../models/graph_map.zig").Direction;
    const Storage = @import("../models/graph_map.zig").Storage;

    var g = GM(u32, void, void, Direction.undirected, Storage.single).init(allocator);
    defer g.deinit();

    try g.addNode(0, {});
    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});

    try g.addEdge(0, 1, {});
    try g.addEdge(1, 2, {});
    try g.addEdge(2, 3, {});

    var result = try detect(allocator, g);
    defer result.deinit();

    // A path should collapse to a single community.
    try std.testing.expectEqual(@as(usize, 1), result.num_communities);
}

test "LPA parallel on disconnected graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Triangle 0-1-2
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    // Triangle 3-4-5
    _ = try g.addEdge(3, 4, {});
    _ = try g.addEdge(4, 3, {});
    _ = try g.addEdge(4, 5, {});
    _ = try g.addEdge(5, 4, {});
    _ = try g.addEdge(5, 3, {});
    _ = try g.addEdge(3, 5, {});

    var result = try detectParallel(allocator, g, .{ .max_iterations = 100, .seed = 42 }, 2);
    defer result.deinit();

    // Should find exactly 2 communities.
    try std.testing.expectEqual(@as(usize, 2), result.num_communities);
}

test "LPA parallel on star graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});
    _ = try g.addNode({});

    // Star centered at 0.
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(0, 2, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 3, {});
    _ = try g.addEdge(3, 0, {});
    _ = try g.addEdge(0, 4, {});
    _ = try g.addEdge(4, 0, {});

    var result = try detectParallel(allocator, g, .{ .max_iterations = 200, .seed = 123 }, 2);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.num_communities);
}
