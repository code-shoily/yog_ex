const std = @import("std");

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

// --- Tests ---

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

/// Saturation degree-based greedy graph coloring (DSatur).
/// Returns an allocated slice of colors (1-indexed), where 0 means uncolored.
pub fn dsatur(allocator: std.mem.Allocator, graph: anytype) ![]u32 {
    const V = graph.nodeCount();
    const colors = try allocator.alloc(u32, V);
    @memset(colors, 0);

    if (V == 0) return colors;

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

    var forbidden_colors = try allocator.alloc(std.DynamicBitSet, V);
    defer allocator.free(forbidden_colors);
    for (0..V) |i| {
        forbidden_colors[i] = try std.DynamicBitSet.initEmpty(allocator, V + 2);
    }
    defer {
        for (0..V) |i| {
            forbidden_colors[i].deinit();
        }
    }

    var saturation = try allocator.alloc(u32, V);
    @memset(saturation, 0);
    defer allocator.free(saturation);

    var colored_count: usize = 0;
    var uncolored = try std.DynamicBitSet.initFull(allocator, V);
    defer uncolored.deinit();

    while (colored_count < V) {
        var best_node: ?usize = null;
        var max_sat: u32 = 0;
        var max_deg: u32 = 0;

        var it = uncolored.iterator(.{});
        while (it.next()) |u| {
            const sat = saturation[u];
            const deg = degrees[u];
            if (best_node == null or sat > max_sat or (sat == max_sat and deg > max_deg)) {
                best_node = u;
                max_sat = sat;
                max_deg = deg;
            }
        }

        const u = best_node.?;
        uncolored.unset(u);

        var color: u32 = 1;
        while (forbidden_colors[u].isSet(color)) {
            color += 1;
        }

        colors[u] = color;
        colored_count += 1;

        for (adj[u].items) |v| {
            if (!forbidden_colors[v].isSet(color)) {
                forbidden_colors[v].set(color);
                saturation[v] += 1;
            }
        }
    }

    return colors;
}

const ExactColoringState = struct {
    V: usize,
    adj: []std.ArrayList(u32),
    ordered_nodes: []u32,
    colors: []u32,
    best_coloring: []u32,
    best_chromatic: u32,
    deadline_ms: i64,
    timed_out: bool,
    steps: u64,
    forbidden_matrix: []bool,

    fn backtrack(self: *@This(), node_idx: usize, max_used: u32) void {
        if (self.timed_out) return;

        self.steps += 1;
        if (self.steps % 1024 == 0) {
            if (std.time.milliTimestamp() > self.deadline_ms) {
                self.timed_out = true;
                return;
            }
        }

        if (node_idx == self.V) {
            if (max_used < self.best_chromatic) {
                self.best_chromatic = max_used;
                @memcpy(self.best_coloring, self.colors);
            }
            return;
        }

        const u = self.ordered_nodes[node_idx];

        const offset = node_idx * (self.V + 2);
        const forbidden = self.forbidden_matrix[offset .. offset + (self.V + 2)];
        @memset(forbidden, false);

        for (self.adj[u].items) |v| {
            const c = self.colors[v];
            if (c > 0) {
                forbidden[c] = true;
            }
        }

        const max_existing = if (max_used == 0) @as(u32, 0) else max_used;
        var c: u32 = 1;
        while (c <= max_existing) : (c += 1) {
            if (!forbidden[c]) {
                const new_max = @max(max_used, c);
                if (new_max < self.best_chromatic) {
                    self.colors[u] = c;
                    self.backtrack(node_idx + 1, new_max);
                    self.colors[u] = 0;
                }
            }
        }

        const new_color = max_used + 1;
        if (new_color < self.best_chromatic and !forbidden[new_color]) {
            self.colors[u] = new_color;
            self.backtrack(node_idx + 1, new_color);
            self.colors[u] = 0;
        }
    }
};

/// Exact graph coloring using backtracking with pruning.
pub fn exactColoring(allocator: std.mem.Allocator, graph: anytype, timeout_ms: u64) !struct { chi: u32, colors: []u32, timed_out: bool } {
    const V = graph.nodeCount();
    if (V == 0) {
        const empty_colors = try allocator.alloc(u32, 0);
        return .{ .chi = 0, .colors = empty_colors, .timed_out = false };
    }

    var adj = try allocator.alloc(std.ArrayList(u32), V);
    defer allocator.free(adj);
    for (0..V) |i| {
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
                }
            }
        }
    }

    const initial_colors = try dsatur(allocator, graph);
    defer allocator.free(initial_colors);

    var max_color: u32 = 0;
    for (initial_colors) |c| {
        if (c > max_color) max_color = c;
    }

    const DegreeNode = struct {
        id: u32,
        deg: u32,
    };
    var degree_nodes = try allocator.alloc(DegreeNode, V);
    defer allocator.free(degree_nodes);
    for (0..V) |i| {
        degree_nodes[i] = .{
            .id = @intCast(i),
            .deg = @intCast(adj[i].items.len),
        };
    }

    const sortFn = struct {
        fn cmp(context: void, a: DegreeNode, b: DegreeNode) bool {
            _ = context;
            return a.deg > b.deg;
        }
    }.cmp;
    std.mem.sort(DegreeNode, degree_nodes, {}, sortFn);

    var ordered_nodes = try allocator.alloc(u32, V);
    defer allocator.free(ordered_nodes);
    for (0..V) |i| {
        ordered_nodes[i] = degree_nodes[i].id;
    }

    const colors = try allocator.alloc(u32, V);
    @memset(colors, 0);
    defer allocator.free(colors);

    const best_coloring = try allocator.alloc(u32, V);
    @memcpy(best_coloring, initial_colors);

    const forbidden_matrix = try allocator.alloc(bool, V * (V + 2));
    defer allocator.free(forbidden_matrix);
    @memset(forbidden_matrix, false);

    const deadline_ms = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));

    var state = ExactColoringState{
        .V = V,
        .adj = adj,
        .ordered_nodes = ordered_nodes,
        .colors = colors,
        .best_coloring = best_coloring,
        .best_chromatic = max_color,
        .deadline_ms = deadline_ms,
        .timed_out = false,
        .steps = 0,
        .forbidden_matrix = forbidden_matrix,
    };

    state.backtrack(0, 0);

    return .{
        .chi = state.best_chromatic,
        .colors = state.best_coloring,
        .timed_out = state.timed_out,
    };
}

test "dsatur & exactColoring: cycle graph" {
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
    _ = try g.addEdge(3, 4, {}); _ = try g.addEdge(4, 3, {});
    _ = try g.addEdge(4, 0, {}); _ = try g.addEdge(0, 4, {});

    const dsatur_colors = try dsatur(allocator, g);
    defer allocator.free(dsatur_colors);

    var max_dsatur: u32 = 0;
    for (dsatur_colors) |c| {
        if (c > max_dsatur) max_dsatur = c;
    }
    try std.testing.expect(max_dsatur >= 3);

    const exact_res = try exactColoring(allocator, g, 5000);
    defer allocator.free(exact_res.colors);

    try std.testing.expectEqual(@as(u32, 3), exact_res.chi);
}

