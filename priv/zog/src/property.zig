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
