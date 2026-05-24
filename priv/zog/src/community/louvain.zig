const std = @import("std");
const utils = @import("../utils.zig");

// =============================================================================
// Types
// =============================================================================

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

/// Options for the Louvain algorithm.
pub const LouvainOptions = struct {
    /// Stop moving nodes when the best modularity gain is below this threshold.
    min_modularity_gain: f64 = 0.000001,
    /// Maximum iterations per phase.
    max_iterations: usize = 100,
    /// Random seed for node shuffling.
    seed: u64 = 42,
};

/// Statistics from a Louvain run.
pub const LouvainStats = struct {
    /// Number of phases executed.
    num_phases: usize,
    /// Final modularity achieved.
    final_modularity: f64,
};

// =============================================================================
// Public API
// =============================================================================

/// Detects communities using the Louvain algorithm with default options.
///
/// Louvain is a greedy modularity-optimization algorithm that works in two
/// repeating phases:
/// 1. **Local optimization** — each node moves to the neighbor community that
///    maximizes modularity gain.
/// 2. **Aggregation** — communities become super-nodes in a new aggregated
///    graph, and the process repeats.
///
/// **Time Complexity:** O(E × phases) — typically near-linear in practice.
pub fn detect(allocator: std.mem.Allocator, graph: anytype) !Communities(utils.NodeId(@TypeOf(graph))) {
    return detectWithOptions(allocator, graph, .{});
}

/// Detects communities with custom options (unweighted).
pub fn detectWithOptions(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LouvainOptions,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    const EdgeData = @TypeOf(@as(@TypeOf(graph).Edge, undefined).data);
    const S = struct {
        fn weight(_: EdgeData) f64 {
            return 1.0;
        }
    };
    return detectWeightedWithOptions(allocator, graph, options, S.weight);
}

/// Detects communities with a custom weight function and default options.
pub fn detectWeighted(
    allocator: std.mem.Allocator,
    graph: anytype,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    return detectWeightedWithOptions(allocator, graph, .{}, weightFn);
}

/// Detects communities with full control over options and edge weights.
pub fn detectWeightedWithOptions(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LouvainOptions,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    const NodeId = utils.NodeId(@TypeOf(graph));

    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    if (nodes.items.len == 0) {
        const empty = std.AutoHashMap(NodeId, usize).init(allocator);
        return .{ .assignments = empty, .num_communities = 0 };
    }

    var node_map: ?std.AutoHashMap(NodeId, usize) = null;
    if (NodeId != u32 and NodeId != usize) {
        node_map = std.AutoHashMap(NodeId, usize).init(allocator);
        for (nodes.items, 0..) |node, i| {
            try node_map.?.put(node, i);
        }
    }
    defer if (node_map) |*m| m.deinit();

    // Phase 1 on the original graph.
    var state = try LouvainState(NodeId).init(allocator, nodes.items.len, graph, weightFn, nodes.items);
    defer state.deinit();

    const improved = try phase1LocalOptimize(allocator, graph, &state, options, weightFn, nodes.items, node_map);

    if (!improved or state.numCommunities() <= 1) {
        return state.toCommunities(nodes.items);
    }

    // Phase 2: aggregate communities into a meta-graph and recurse.
    try state.normalizeAssignments();

    var agg_graph = try aggregateGraph(allocator, graph, &state, weightFn, node_map);
    defer agg_graph.deinit();

    const Identity = struct {
        fn weight(w: f64) f64 {
            return w;
        }
    };
    var agg_result = try doLouvainArrayGraph(allocator, agg_graph, options, Identity.weight);
    defer agg_result.deinit();

    // Map aggregated communities back to original nodes.
    var final_assignments = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer final_assignments.deinit();

    for (nodes.items, 0..) |node, i| {
        const comm0 = state.assignments[i];
        const comm1 = agg_result.assignments.get(@intCast(comm0)) orelse 0;
        try final_assignments.put(node, comm1);
    }

    return .{
        .assignments = final_assignments,
        .num_communities = agg_result.num_communities,
    };
}

// =============================================================================
// LouvainState
// =============================================================================

fn LouvainState(comptime NodeId: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        assignments: []usize,
        node_weights: []f64,
        community_totals: []f64,
        node_counts: []usize,
        total_weight: f64,
        num_nodes: usize,
        active_communities: usize,

        pub fn init(
            allocator: std.mem.Allocator,
            num_nodes: usize,
            graph: anytype,
            weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
            node_list: []const NodeId,
        ) !Self {
            const assignments = try allocator.alloc(usize, num_nodes);
            errdefer allocator.free(assignments);
            const node_weights = try allocator.alloc(f64, num_nodes);
            errdefer allocator.free(node_weights);
            const community_totals = try allocator.alloc(f64, num_nodes);
            errdefer allocator.free(community_totals);
            const node_counts = try allocator.alloc(usize, num_nodes);
            errdefer allocator.free(node_counts);

            var total_weight: f64 = 0.0;

            for (node_list, 0..) |node, i| {
                var ki: f64 = 0.0;
                var sit = graph.successors(node);
                while (sit.next()) |edge| {
                    ki += weightFn(edge.data);
                }
                assignments[i] = i;
                node_weights[i] = ki;
                community_totals[i] = ki;
                node_counts[i] = 1;
                total_weight += ki;
            }

            return .{
                .allocator = allocator,
                .assignments = assignments,
                .node_weights = node_weights,
                .community_totals = community_totals,
                .node_counts = node_counts,
                .total_weight = total_weight,
                .num_nodes = num_nodes,
                .active_communities = num_nodes,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.assignments);
            self.allocator.free(self.node_weights);
            self.allocator.free(self.community_totals);
            self.allocator.free(self.node_counts);
        }

        pub fn moveNode(self: *Self, node_idx: usize, from_comm: usize, to_comm: usize) void {
            const ki = self.node_weights[node_idx];

            self.community_totals[from_comm] -= ki;
            self.node_counts[from_comm] -= 1;
            if (self.node_counts[from_comm] == 0) self.active_communities -= 1;

            if (self.node_counts[to_comm] == 0) self.active_communities += 1;
            self.community_totals[to_comm] += ki;
            self.node_counts[to_comm] += 1;

            self.assignments[node_idx] = to_comm;
        }

        pub fn numCommunities(self: *Self) usize {
            return self.active_communities;
        }

        pub fn normalizeAssignments(self: *Self) !void {
            var remap = try self.allocator.alloc(usize, self.num_nodes);
            defer self.allocator.free(remap);
            @memset(remap, std.math.maxInt(usize));

            var next_id: usize = 0;
            for (self.assignments) |comm| {
                if (remap[comm] == std.math.maxInt(usize)) {
                    remap[comm] = next_id;
                    next_id += 1;
                }
            }

            const new_totals = try self.allocator.alloc(f64, self.num_nodes);
            @memset(new_totals, 0.0);
            const new_counts = try self.allocator.alloc(usize, self.num_nodes);
            @memset(new_counts, 0);

            for (self.assignments, 0..) |*comm, i| {
                const new_comm = remap[comm.*];
                comm.* = new_comm;
                new_totals[new_comm] += self.node_weights[i];
                new_counts[new_comm] += 1;
            }

            self.allocator.free(self.community_totals);
            self.allocator.free(self.node_counts);
            self.community_totals = new_totals;
            self.node_counts = new_counts;
            self.active_communities = next_id;
        }

        pub fn toCommunities(self: *Self, node_list: []const NodeId) !Communities(NodeId) {
            var result = std.AutoHashMap(NodeId, usize).init(self.allocator);
            errdefer result.deinit();
            for (node_list, 0..) |node, i| {
                try result.put(node, self.assignments[i]);
            }
            return .{
                .assignments = result,
                .num_communities = self.numCommunities(),
            };
        }
    };
}
fn phase1LocalOptimize(
    allocator: std.mem.Allocator,
    graph: anytype,
    state: anytype,
    options: LouvainOptions,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
    node_list: []const utils.NodeId(@TypeOf(graph)),
    node_map: anytype, // ?std.AutoHashMap(NodeId, usize)
) !bool {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const num_nodes = node_list.len;
    if (num_nodes == 0) return false;

    const shuffled_indices = try allocator.alloc(usize, num_nodes);
    defer allocator.free(shuffled_indices);
    for (0..num_nodes) |i| shuffled_indices[i] = i;

    var prng = std.Random.DefaultPrng.init(options.seed);
    prng.random().shuffle(usize, shuffled_indices);

    // Pre-allocated flat arrays for O(1) community weight accumulation.
    // comm_weights[c] holds the accumulated weight to community c.
    // comm_seen[c] tracks whether c has been touched this node (for fast reset).
    // active_comms records the order in which communities were first seen.
    const comm_weights = try allocator.alloc(f64, num_nodes);
    defer allocator.free(comm_weights);
    @memset(comm_weights, 0.0);

    const comm_seen = try allocator.alloc(bool, num_nodes);
    defer allocator.free(comm_seen);
    @memset(comm_seen, false);

    const active_comms = try allocator.alloc(usize, num_nodes);
    defer allocator.free(active_comms);

    var improved = false;
    var iteration: usize = 0;
    const two_m = state.total_weight;
    if (two_m == 0.0) return false;

    while (iteration < options.max_iterations) : (iteration += 1) {
        var local_improved = false;

        for (shuffled_indices) |i| {
            const node = node_list[i];
            const current_comm = state.assignments[i];
            const ki = state.node_weights[i];
            if (ki == 0.0) continue;

            // Accumulate edge weights from this node to each neighbor community.
            var active_count: usize = 0;

            var sit = graph.successors(node);
            while (sit.next()) |edge| {
                const neighbor = edge.to;
                const neighbor_idx: usize = if (NodeId == u32 or NodeId == usize)
                    @intCast(neighbor)
                else
                    node_map.?.get(neighbor).?;

                const neighbor_comm = state.assignments[neighbor_idx];
                const w = weightFn(edge.data);

                if (!comm_seen[neighbor_comm]) {
                    comm_seen[neighbor_comm] = true;
                    active_comms[active_count] = neighbor_comm;
                    active_count += 1;
                }
                comm_weights[neighbor_comm] += w;
            }

            const ki_in_C = if (comm_seen[current_comm]) comm_weights[current_comm] else 0.0;
            const sigma_tot_C = state.community_totals[current_comm];

            // Find the best community to move to.
            var best_comm = current_comm;
            var best_gain: f64 = 0.0;

            for (0..active_count) |j| {
                const target_comm = active_comms[j];
                if (target_comm == current_comm) continue;

                const ki_in_D = comm_weights[target_comm];
                const sigma_tot_D = state.community_totals[target_comm];

                const gain = (ki_in_D - ki_in_C) / two_m +
                    ki * (sigma_tot_C - ki - sigma_tot_D) / (two_m * two_m);

                if (gain > best_gain) {
                    best_gain = gain;
                    best_comm = target_comm;
                }
            }

            // Fast reset: only clear the communities we touched.
            for (0..active_count) |j| {
                const c = active_comms[j];
                comm_weights[c] = 0.0;
                comm_seen[c] = false;
            }

            if (best_gain > options.min_modularity_gain and best_comm != current_comm) {
                state.moveNode(i, current_comm, best_comm);
                local_improved = true;
            }
        }

        if (!local_improved) break;
        improved = true;
    }

    return improved;
}

// =============================================================================
// Phase 2: Aggregation
// =============================================================================

fn aggregateGraph(
    allocator: std.mem.Allocator,
    graph: anytype,
    state: anytype,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
    node_map: anytype,
) !@import("../models/array_graph.zig").ArrayGraph(void, f64) {
    const AG = @import("../models/array_graph.zig").ArrayGraph;
    const NodeId = utils.NodeId(@TypeOf(graph));

    const num_comms = state.numCommunities();
    var agg = AG(void, f64).init(allocator);

    for (0..num_comms) |_| {
        _ = try agg.addNode({});
    }

    // O(E) aggregation using a hash map keyed by packed (from, to) u64.
    var edge_map = std.AutoHashMap(u64, f64).init(allocator);
    defer edge_map.deinit();

    var edge_it = graph.allEdges();
    while (edge_it.next()) |edge| {
        const u_idx: usize = if (NodeId == u32 or NodeId == usize)
            @intCast(edge.from)
        else
            node_map.?.get(edge.from).?;

        const v_idx: usize = if (NodeId == u32 or NodeId == usize)
            @intCast(edge.to)
        else
            node_map.?.get(edge.to).?;

        const u_comm = state.assignments[u_idx];
        const v_comm = state.assignments[v_idx];
        const w = weightFn(edge.data);

        const key = (@as(u64, @intCast(u_comm)) << 32) | @as(u64, @intCast(v_comm));
        const gop = try edge_map.getOrPut(key);
        if (!gop.found_existing) gop.value_ptr.* = 0.0;
        gop.value_ptr.* += w;
    }

    var map_it = edge_map.iterator();
    while (map_it.next()) |entry| {
        const key = entry.key_ptr.*;
        const from_comm: u32 = @intCast(key >> 32);
        const to_comm: u32 = @intCast(key & 0xFFFFFFFF);
        const w = entry.value_ptr.*;
        _ = try agg.addEdge(from_comm, to_comm, w);
    }

    return agg;
}

// =============================================================================
// Recursive Louvain on ArrayGraph
// =============================================================================

// =============================================================================

fn doLouvainArrayGraph(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LouvainOptions,
    weightFn: fn (f64) f64,
) !Communities(u32) {
    var nodes = try utils.collectNodes(allocator, graph);
    defer nodes.deinit(allocator);

    if (nodes.items.len == 0) {
        const empty = std.AutoHashMap(u32, usize).init(allocator);
        return .{ .assignments = empty, .num_communities = 0 };
    }

    var state = try LouvainState(u32).init(allocator, nodes.items.len, graph, weightFn, nodes.items);
    defer state.deinit();

    const improved = try phase1LocalOptimize(allocator, graph, &state, options, weightFn, nodes.items, null);

    if (!improved or state.numCommunities() <= 1) {
        return state.toCommunities(nodes.items);
    }

    try state.normalizeAssignments();

    var agg_graph = try aggregateGraph(allocator, graph, &state, weightFn, null);
    defer agg_graph.deinit();

    var agg_result = try doLouvainArrayGraph(allocator, agg_graph, options, weightFn);
    defer agg_result.deinit();

    var final_assignments = std.AutoHashMap(u32, usize).init(allocator);
    errdefer final_assignments.deinit();

    for (nodes.items, 0..) |node, i| {
        const comm0 = state.assignments[i];
        const comm1 = agg_result.assignments.get(@intCast(comm0)) orelse 0;
        try final_assignments.put(node, comm1);
    }

    return .{
        .assignments = final_assignments,
        .num_communities = agg_result.num_communities,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "louvain: two triangles with bridge" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    var i: u32 = 0;
    while (i < 6) : (i += 1) _ = try g.addNode({});

    // First triangle.
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    // Second triangle.
    _ = try g.addEdge(3, 4, {});
    _ = try g.addEdge(4, 3, {});
    _ = try g.addEdge(4, 5, {});
    _ = try g.addEdge(5, 4, {});
    _ = try g.addEdge(5, 3, {});
    _ = try g.addEdge(3, 5, {});

    // Bridge edge.
    _ = try g.addEdge(2, 3, {});
    _ = try g.addEdge(3, 2, {});

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expect(result.num_communities >= 2);
    try std.testing.expect(result.num_communities <= 4);
    try std.testing.expectEqual(@as(usize, 6), result.assignments.count());
}

test "louvain: complete graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    var i: u32 = 0;
    while (i < 5) : (i += 1) _ = try g.addNode({});

    // Complete graph K5 (bidirectional edges).
    var u: u32 = 0;
    while (u < 5) : (u += 1) {
        var v: u32 = u + 1;
        while (v < 5) : (v += 1) {
            _ = try g.addEdge(u, v, {});
            _ = try g.addEdge(v, u, {});
        }
    }

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expect(result.num_communities >= 1);
    try std.testing.expect(result.num_communities <= 3);
    try std.testing.expectEqual(@as(usize, 5), result.assignments.count());
}

test "louvain: two disjoint triangles" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;
    const metrics = @import("metrics.zig");

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    var i: u32 = 0;
    while (i < 6) : (i += 1) _ = try g.addNode({});

    // First triangle.
    _ = try g.addEdge(0, 1, {});
    _ = try g.addEdge(1, 0, {});
    _ = try g.addEdge(1, 2, {});
    _ = try g.addEdge(2, 1, {});
    _ = try g.addEdge(2, 0, {});
    _ = try g.addEdge(0, 2, {});

    // Second triangle.
    _ = try g.addEdge(3, 4, {});
    _ = try g.addEdge(4, 3, {});
    _ = try g.addEdge(4, 5, {});
    _ = try g.addEdge(5, 4, {});
    _ = try g.addEdge(5, 3, {});
    _ = try g.addEdge(3, 5, {});

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expect(result.num_communities >= 2);
    try std.testing.expect(result.num_communities <= 4);

    const q = try metrics.modularityUnweighted(allocator, g, result.assignments);
    try std.testing.expect(q > 0.0);
}

test "louvain: empty graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.num_communities);
    try std.testing.expectEqual(@as(usize, 0), result.assignments.count());
}

test "louvain: single node" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    _ = try g.addNode({});

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.num_communities);
    try std.testing.expectEqual(@as(usize, 1), result.assignments.count());
}

test "louvain: weighted graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, f64).init(allocator);
    defer g.deinit();

    var i: u32 = 0;
    while (i < 6) : (i += 1) _ = try g.addNode({});

    // Strong internal edges.
    _ = try g.addEdge(0, 1, 10.0);
    _ = try g.addEdge(1, 0, 10.0);
    _ = try g.addEdge(1, 2, 10.0);
    _ = try g.addEdge(2, 1, 10.0);
    _ = try g.addEdge(2, 0, 10.0);
    _ = try g.addEdge(0, 2, 10.0);

    _ = try g.addEdge(3, 4, 10.0);
    _ = try g.addEdge(4, 3, 10.0);
    _ = try g.addEdge(4, 5, 10.0);
    _ = try g.addEdge(5, 4, 10.0);
    _ = try g.addEdge(5, 3, 10.0);
    _ = try g.addEdge(3, 5, 10.0);

    // Weak bridge.
    _ = try g.addEdge(2, 3, 1.0);
    _ = try g.addEdge(3, 2, 1.0);

    var result = try detectWeighted(allocator, g, struct {
        fn weight(w: f64) f64 {
            return w;
        }
    }.weight);
    defer result.deinit();

    try std.testing.expect(result.num_communities >= 2);
    try std.testing.expect(result.num_communities <= 4);
}
