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

/// Options for the Leiden algorithm.
pub const LeidenOptions = struct {
    /// Stop moving nodes when the best modularity gain is below this threshold.
    min_modularity_gain: f64 = 0.000001,
    /// Maximum iterations per phase.
    max_iterations: usize = 100,
    /// Random seed for node shuffling and probabilistic refinement moves.
    seed: u64 = 42,
    /// Temperature parameter for the probabilistic refinement phase.
    theta: f64 = 1.0,
};

// =============================================================================
// State Management
// =============================================================================

fn LeidenState(comptime NodeId: type) type {
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
            initial_assignments: ?[]const usize,
        ) !Self {
            const assignments = try allocator.alloc(usize, num_nodes);
            errdefer allocator.free(assignments);
            const node_weights = try allocator.alloc(f64, num_nodes);
            errdefer allocator.free(node_weights);
            const community_totals = try allocator.alloc(f64, num_nodes);
            errdefer allocator.free(community_totals);
            const node_counts = try allocator.alloc(usize, num_nodes);
            errdefer allocator.free(node_counts);

            @memset(community_totals, 0.0);
            @memset(node_counts, 0);

            var total_weight: f64 = 0.0;

            for (node_list, 0..) |node, i| {
                var ki: f64 = 0.0;
                var sit = graph.successors(node);
                while (sit.next()) |edge| {
                    ki += weightFn(edge.data);
                }
                node_weights[i] = ki;
                total_weight += ki;

                if (initial_assignments) |initial| {
                    assignments[i] = initial[i];
                } else {
                    assignments[i] = i;
                }
            }

            // Compute community totals and node counts
            var active_communities: usize = 0;
            for (0..num_nodes) |i| {
                const comm = assignments[i];
                if (node_counts[comm] == 0) {
                    active_communities += 1;
                }
                community_totals[comm] += node_weights[i];
                node_counts[comm] += 1;
            }

            return .{
                .allocator = allocator,
                .assignments = assignments,
                .node_weights = node_weights,
                .community_totals = community_totals,
                .node_counts = node_counts,
                .total_weight = total_weight,
                .num_nodes = num_nodes,
                .active_communities = active_communities,
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
    };
}

// =============================================================================
// Local Move Phase (Phase 1)
// =============================================================================

fn phase1LocalOptimize(
    allocator: std.mem.Allocator,
    graph: anytype,
    state: anytype,
    options: LeidenOptions,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
    node_list: []const utils.NodeId(@TypeOf(graph)),
    node_map: anytype,
) !bool {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const num_nodes = node_list.len;
    if (num_nodes == 0) return false;

    const shuffled_indices = try allocator.alloc(usize, num_nodes);
    defer allocator.free(shuffled_indices);
    for (0..num_nodes) |i| shuffled_indices[i] = i;

    var prng = std.Random.DefaultPrng.init(options.seed);
    prng.random().shuffle(usize, shuffled_indices);

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
// Refinement Phase (Phase 2)
// =============================================================================

fn phase1Refine(
    allocator: std.mem.Allocator,
    graph: anytype,
    local_state: anytype,
    options: LeidenOptions,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
    node_list: []const utils.NodeId(@TypeOf(graph)),
    node_map: anytype,
) ![]usize {
    const NodeId = utils.NodeId(@TypeOf(graph));
    const num_nodes = node_list.len;

    const refined_assignments = try allocator.alloc(usize, num_nodes);
    errdefer allocator.free(refined_assignments);
    for (0..num_nodes) |i| refined_assignments[i] = i;

    const refined_totals = try allocator.alloc(f64, num_nodes);
    defer allocator.free(refined_totals);
    @memcpy(refined_totals, local_state.node_weights);

    const refined_counts = try allocator.alloc(usize, num_nodes);
    defer allocator.free(refined_counts);
    @memset(refined_counts, 1);

    const shuffled_indices = try allocator.alloc(usize, num_nodes);
    defer allocator.free(shuffled_indices);
    for (0..num_nodes) |i| shuffled_indices[i] = i;

    var prng = std.Random.DefaultPrng.init(options.seed);
    prng.random().shuffle(usize, shuffled_indices);

    const comm_weights = try allocator.alloc(f64, num_nodes);
    defer allocator.free(comm_weights);
    @memset(comm_weights, 0.0);

    const comm_seen = try allocator.alloc(bool, num_nodes);
    defer allocator.free(comm_seen);
    @memset(comm_seen, false);

    const active_comms = try allocator.alloc(usize, num_nodes);
    defer allocator.free(active_comms);

    const candidate_comms = try allocator.alloc(usize, num_nodes);
    defer allocator.free(candidate_comms);

    const candidate_probs = try allocator.alloc(f64, num_nodes);
    defer allocator.free(candidate_probs);

    const two_m = local_state.total_weight;

    for (shuffled_indices) |i| {
        // A node can only be moved if it is still a singleton in the refined partition!
        const curr_comm = refined_assignments[i];
        if (refined_counts[curr_comm] > 1) continue;

        const node = node_list[i];
        const parent_comm = local_state.assignments[i];
        const ki = local_state.node_weights[i];
        if (ki == 0.0) continue;

        var active_count: usize = 0;

        var sit = graph.successors(node);
        while (sit.next()) |edge| {
            const neighbor = edge.to;
            const neighbor_idx: usize = if (NodeId == u32 or NodeId == usize)
                @intCast(neighbor)
            else
                node_map.?.get(neighbor).?;

            // Constraints: must belong to the same parent community!
            if (local_state.assignments[neighbor_idx] != parent_comm) continue;

            const neighbor_comm = refined_assignments[neighbor_idx];
            const w = weightFn(edge.data);

            if (!comm_seen[neighbor_comm]) {
                comm_seen[neighbor_comm] = true;
                active_comms[active_count] = neighbor_comm;
                active_count += 1;
            }
            comm_weights[neighbor_comm] += w;
        }

        // Staying as singleton is always a candidate
        var candidate_count: usize = 0;
        candidate_comms[candidate_count] = curr_comm;
        candidate_probs[candidate_count] = 1.0;
        candidate_count += 1;

        var sum_probs: f64 = 1.0;

        for (0..active_count) |j| {
            const target_comm = active_comms[j];
            if (target_comm == curr_comm) continue;

            const ki_in_D = comm_weights[target_comm];
            const sigma_tot_D = refined_totals[target_comm];

            // Modularity gain from singleton to community D
            const gain = ki_in_D / two_m - (ki * sigma_tot_D) / (two_m * two_m);

            if (gain >= 0.0) {
                const prob = std.math.exp(gain / options.theta);
                candidate_comms[candidate_count] = target_comm;
                candidate_probs[candidate_count] = prob;
                sum_probs += prob;
                candidate_count += 1;
            }
        }

        for (0..active_count) |j| {
            const c = active_comms[j];
            comm_weights[c] = 0.0;
            comm_seen[c] = false;
        }

        if (candidate_count > 1) {
            const r = prng.random().float(f64) * sum_probs;
            var cum_sum: f64 = 0.0;
            var chosen_comm = curr_comm;

            for (0..candidate_count) |j| {
                cum_sum += candidate_probs[j];
                if (r <= cum_sum) {
                    chosen_comm = candidate_comms[j];
                    break;
                }
            }

            if (chosen_comm != curr_comm) {
                refined_assignments[i] = chosen_comm;
                refined_totals[chosen_comm] += ki;
                refined_counts[chosen_comm] += 1;
                refined_counts[curr_comm] -= 1;
            }
        }
    }

    return refined_assignments;
}

// =============================================================================
// Graph Aggregation
// =============================================================================

fn aggregateGraphLeiden(
    allocator: std.mem.Allocator,
    graph: anytype,
    assignments: []const usize,
    num_comms: usize,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
    node_map: anytype,
) !@import("../models/array_graph.zig").ArrayGraph(void, f64) {
    const AG = @import("../models/array_graph.zig").ArrayGraph;
    const NodeId = utils.NodeId(@TypeOf(graph));

    var agg = AG(void, f64).init(allocator);

    for (0..num_comms) |_| {
        _ = try agg.addNode({});
    }

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

        const u_comm = assignments[u_idx];
        const v_comm = assignments[v_idx];
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
// Recursive Loops
// =============================================================================

fn runLeidenLoop(
    allocator: std.mem.Allocator,
    graph: anytype,
    node_list: []const utils.NodeId(@TypeOf(graph)),
    node_map: anytype,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
    options: LeidenOptions,
    out_assignments: []usize,
) !void {
    const num_nodes = node_list.len;

    // 1. Local move phase starting from singleton
    var state = try LeidenState(utils.NodeId(@TypeOf(graph))).init(allocator, num_nodes, graph, weightFn, node_list, null);
    defer state.deinit();

    const improved = try phase1LocalOptimize(allocator, graph, &state, options, weightFn, node_list, node_map);

    if (!improved or state.numCommunities() <= 1) {
        @memcpy(out_assignments, state.assignments);
        return;
    }

    // 2. Refinement phase
    const refined_partition = try phase1Refine(
        allocator,
        graph,
        &state,
        options,
        weightFn,
        node_list,
        node_map,
    );
    defer allocator.free(refined_partition);

    // Normalize refined assignments to be 0..num_refined_comms-1
    var refined_remap = try allocator.alloc(usize, num_nodes);
    defer allocator.free(refined_remap);
    @memset(refined_remap, std.math.maxInt(usize));

    var num_refined_comms: usize = 0;
    for (refined_partition) |comm| {
        if (refined_remap[comm] == std.math.maxInt(usize)) {
            refined_remap[comm] = num_refined_comms;
            num_refined_comms += 1;
        }
    }

    for (refined_partition) |*comm| {
        comm.* = refined_remap[comm.*];
    }

    // Stop if refinement did not merge any nodes (to prevent infinite loop)
    if (num_refined_comms == num_nodes) {
        @memcpy(out_assignments, state.assignments);
        return;
    }

    // 3. Aggregate graph based on refined partition
    const parent_comm_map = try allocator.alloc(usize, num_refined_comms);
    defer allocator.free(parent_comm_map);

    for (0..num_nodes) |i| {
        const refined_c = refined_partition[i];
        parent_comm_map[refined_c] = state.assignments[i];
    }

    var parent_remap = try allocator.alloc(usize, num_nodes);
    defer allocator.free(parent_remap);
    @memset(parent_remap, std.math.maxInt(usize));

    var num_parent_comms: usize = 0;
    for (parent_comm_map) |p_comm| {
        if (parent_remap[p_comm] == std.math.maxInt(usize)) {
            parent_remap[p_comm] = num_parent_comms;
            num_parent_comms += 1;
        }
    }

    for (parent_comm_map) |*p_comm| {
        p_comm.* = parent_remap[p_comm.*];
    }

    var agg_graph = try aggregateGraphLeiden(allocator, graph, refined_partition, num_refined_comms, weightFn, node_map);
    defer agg_graph.deinit();

    const agg_assignments = try allocator.alloc(usize, num_refined_comms);
    defer allocator.free(agg_assignments);

    try runLeidenLoopArrayGraph(
        allocator,
        agg_graph,
        options,
        parent_comm_map,
        agg_assignments,
    );

    for (0..num_nodes) |i| {
        const refined_c = refined_partition[i];
        out_assignments[i] = agg_assignments[refined_c];
    }
}

fn runLeidenLoopArrayGraph(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LeidenOptions,
    initial_assignments: []const usize,
    out_assignments: []usize,
) !void {
    const num_nodes = graph.nodeCount();

    var nodes = try allocator.alloc(u32, num_nodes);
    defer allocator.free(nodes);
    for (0..num_nodes) |i| nodes[i] = @intCast(i);

    const Identity = struct {
        fn weight(w: f64) f64 {
            return w;
        }
    };

    var state = try LeidenState(u32).init(allocator, num_nodes, graph, Identity.weight, nodes, initial_assignments);
    defer state.deinit();

    const improved = try phase1LocalOptimize(allocator, graph, &state, options, Identity.weight, nodes, null);

    if (!improved or state.numCommunities() <= 1) {
        @memcpy(out_assignments, state.assignments);
        return;
    }

    const refined_partition = try phase1Refine(
        allocator,
        graph,
        &state,
        options,
        Identity.weight,
        nodes,
        null,
    );
    defer allocator.free(refined_partition);

    var refined_remap = try allocator.alloc(usize, num_nodes);
    defer allocator.free(refined_remap);
    @memset(refined_remap, std.math.maxInt(usize));

    var num_refined_comms: usize = 0;
    for (refined_partition) |comm| {
        if (refined_remap[comm] == std.math.maxInt(usize)) {
            refined_remap[comm] = num_refined_comms;
            num_refined_comms += 1;
        }
    }

    for (refined_partition) |*comm| {
        comm.* = refined_remap[comm.*];
    }

    if (num_refined_comms == num_nodes) {
        @memcpy(out_assignments, state.assignments);
        return;
    }

    const parent_comm_map = try allocator.alloc(usize, num_refined_comms);
    defer allocator.free(parent_comm_map);

    for (0..num_nodes) |i| {
        const refined_c = refined_partition[i];
        parent_comm_map[refined_c] = state.assignments[i];
    }

    var parent_remap = try allocator.alloc(usize, num_nodes);
    defer allocator.free(parent_remap);
    @memset(parent_remap, std.math.maxInt(usize));

    var num_parent_comms: usize = 0;
    for (parent_comm_map) |p_comm| {
        if (parent_remap[p_comm] == std.math.maxInt(usize)) {
            parent_remap[p_comm] = num_parent_comms;
            num_parent_comms += 1;
        }
    }

    for (parent_comm_map) |*p_comm| {
        p_comm.* = parent_remap[p_comm.*];
    }

    var agg_graph = try aggregateGraphLeiden(allocator, graph, refined_partition, num_refined_comms, Identity.weight, null);
    defer agg_graph.deinit();

    const agg_assignments = try allocator.alloc(usize, num_refined_comms);
    defer allocator.free(agg_assignments);

    try runLeidenLoopArrayGraph(
        allocator,
        agg_graph,
        options,
        parent_comm_map,
        agg_assignments,
    );

    for (0..num_nodes) |i| {
        const refined_c = refined_partition[i];
        out_assignments[i] = agg_assignments[refined_c];
    }
}

// =============================================================================
// Public Entry Points
// =============================================================================

pub fn detect(allocator: std.mem.Allocator, graph: anytype) !Communities(utils.NodeId(@TypeOf(graph))) {
    return detectWithOptions(allocator, graph, .{});
}

pub fn detectWithOptions(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LeidenOptions,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    const EdgeData = @TypeOf(@as(@TypeOf(graph).Edge, undefined).data);
    const S = struct {
        fn weight(_: EdgeData) f64 {
            return 1.0;
        }
    };
    return detectWeightedWithOptions(allocator, graph, options, S.weight);
}

pub fn detectWeighted(
    allocator: std.mem.Allocator,
    graph: anytype,
    weightFn: fn (@TypeOf(@as(@TypeOf(graph).Edge, undefined).data)) f64,
) !Communities(utils.NodeId(@TypeOf(graph))) {
    return detectWeightedWithOptions(allocator, graph, .{}, weightFn);
}

pub fn detectWeightedWithOptions(
    allocator: std.mem.Allocator,
    graph: anytype,
    options: LeidenOptions,
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

    var current_assignments = try allocator.alloc(usize, nodes.items.len);
    defer allocator.free(current_assignments);
    for (0..nodes.items.len) |i| current_assignments[i] = i;

    try runLeidenLoop(
        allocator,
        graph,
        nodes.items,
        node_map,
        weightFn,
        options,
        current_assignments,
    );

    var final_assignments = std.AutoHashMap(NodeId, usize).init(allocator);
    errdefer final_assignments.deinit();

    var max_comm: usize = 0;
    for (nodes.items, 0..) |node, i| {
        const comm = current_assignments[i];
        try final_assignments.put(node, comm);
        if (comm > max_comm) max_comm = comm;
    }

    return .{
        .assignments = final_assignments,
        .num_communities = if (nodes.items.len > 0) max_comm + 1 else 0,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "leiden: two triangles with bridge" {
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

test "leiden: complete graph" {
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
    try std.testing.expect(result.num_communities <= 5);
    try std.testing.expectEqual(@as(usize, 5), result.assignments.count());
}

test "leiden: two disjoint triangles" {
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

    const q = try metrics.modularity(allocator, g, result.assignments, struct {
        fn weight(_: void) f64 {
            return 1.0;
        }
    }.weight);
    try std.testing.expect(q > 0.0);
}

test "leiden: empty graph" {
    const allocator = std.testing.allocator;
    const AG = @import("../models/array_graph.zig").ArrayGraph;

    var g = AG(void, void).init(allocator);
    defer g.deinit();

    var result = try detect(allocator, g);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.num_communities);
    try std.testing.expectEqual(@as(usize, 0), result.assignments.count());
}

test "leiden: single node" {
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
