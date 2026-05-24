const std = @import("std");
const Allocator = std.mem.Allocator;

/// ArrayGraph is a high-performance graph implementation using contiguous arrays.
/// It is inspired by petgraph's main Graph struct.
///
/// Uses Structure-of-Arrays (SoA) storage via `std.MultiArrayList` for cache
/// efficiency: traversals only load the fields they need (e.g. `to` and
/// `next_edge`) without pulling `EdgeData` into cache.
///
/// Instead of a custom NodeId, it uses NodeIndex (an integer) returned when
/// you add a node.
pub fn ArrayGraph(comptime NodeData: type, comptime EdgeData: type) type {
    return struct {
        const Self = @This();

        /// We use u32 for indices to save memory (up to 4 billion nodes/edges).
        pub const NodeIndex = u32;
        pub const EdgeIndex = u32;

        pub const Node = struct {
            data: NodeData,
            /// The index of the first outgoing edge in the 'edges' array.
            first_edge: ?EdgeIndex = null,
            is_deleted: bool = false,
        };

        pub const Edge = struct {
            to: NodeIndex,
            data: EdgeData,
            /// The index of the next outgoing edge for the same source node.
            next_edge: ?EdgeIndex = null,
            is_deleted: bool = false,
        };

        allocator: Allocator,
        nodes: std.MultiArrayList(Node),
        edges: std.MultiArrayList(Edge),
        live_nodes: usize,
        live_edges: usize,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .nodes = .{},
                .edges = .{},
                .live_nodes = 0,
                .live_edges = 0,
            };
        }

        /// Pre-size internal buffers for batch ingestion.
        pub fn initCapacity(allocator: Allocator, node_count: usize, edge_count: usize) !Self {
            var self = init(allocator);
            try self.nodes.ensureTotalCapacity(allocator, node_count);
            try self.edges.ensureTotalCapacity(allocator, edge_count);
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit(self.allocator);
            self.edges.deinit(self.allocator);
        }

        /// Adds a node and returns its index.
        pub fn addNode(self: *Self, data: NodeData) !NodeIndex {
            const index = @as(NodeIndex, @intCast(self.nodes.len));
            try self.nodes.append(self.allocator, .{
                .data = data,
                .first_edge = null,
                .is_deleted = false,
            });
            self.live_nodes += 1;
            return index;
        }

        pub const Error = error{
            NodeNotFound,
            OutOfMemory,
        };

        /// Adds an edge between two nodes.
        ///
        /// Returns `error.NodeNotFound` if either index is out of bounds.
        ///
        /// Uses index-only access (no `&node` pointer) to avoid the dangling-
        /// pointer hazard if the underlying array were to resize.
        pub fn addEdge(self: *Self, from: NodeIndex, to: NodeIndex, data: EdgeData) Error!EdgeIndex {
            if (!self.hasNode(from) or !self.hasNode(to)) return error.NodeNotFound;

            const edge_idx = @as(EdgeIndex, @intCast(self.edges.len));

            // Capture the previous first edge before appending.
            const prev_first = self.nodes.items(.first_edge)[from];

            try self.edges.append(self.allocator, .{
                .to = to,
                .data = data,
                .next_edge = prev_first,
                .is_deleted = false,
            });

            // Update the node's head-of-list pointer directly by field slice.
            self.nodes.items(.first_edge)[from] = edge_idx;

            self.live_edges += 1;
            return edge_idx;
        }

        pub fn removeEdge(self: *Self, from: NodeIndex, to: NodeIndex) Error!void {
            if (!self.hasNode(from) or !self.hasNode(to)) return error.NodeNotFound;

            var curr = self.nodes.items(.first_edge)[from];
            while (curr) |edge_idx| {
                const is_del = self.edges.items(.is_deleted)[edge_idx];
                const dest = self.edges.items(.to)[edge_idx];
                if (!is_del and dest == to) {
                    self.edges.items(.is_deleted)[edge_idx] = true;
                    self.live_edges -= 1;
                    // Note: We don't splice out the linked list link because that would
                    // require modifying prev.next_edge. Since iterators skip deleted
                    // edges, just marking it is sufficient.
                }
                curr = self.edges.items(.next_edge)[edge_idx];
            }
        }

        pub fn removeNode(self: *Self, id: NodeIndex) Error!void {
            if (!self.hasNode(id)) return error.NodeNotFound;

            // Mark node as deleted
            self.nodes.items(.is_deleted)[id] = true;
            self.live_nodes -= 1;

            // Mark all outgoing edges as deleted
            var curr = self.nodes.items(.first_edge)[id];
            while (curr) |edge_idx| {
                if (!self.edges.items(.is_deleted)[edge_idx]) {
                    self.live_edges -= 1;
                }
                self.edges.items(.is_deleted)[edge_idx] = true;
                curr = self.edges.items(.next_edge)[edge_idx];
            }

            // ArrayGraph is single-storage directed. We must scan all edges in the entire graph
            // to find incoming edges to 'id' and delete them.
            for (self.edges.items(.to), 0..) |to, idx| {
                if (to == id and !self.edges.items(.is_deleted)[idx]) {
                    self.edges.items(.is_deleted)[idx] = true;
                    self.live_edges -= 1;
                }
            }
        }

        // --- Iterators ---

        /// An iterator over the successors of a node.
        pub const SuccessorIterator = struct {
            graph: *const Self,
            next_edge: ?EdgeIndex,

            pub fn next(it: *SuccessorIterator) ?Edge {
                while (it.next_edge) |idx| {
                    const edge = it.graph.edges.get(idx);
                    it.next_edge = edge.next_edge;
                    if (!edge.is_deleted and !it.graph.nodes.items(.is_deleted)[edge.to]) {
                        return edge;
                    }
                }
                return null;
            }
        };

        pub fn successors(self: *const Self, id: NodeIndex) SuccessorIterator {
            return .{
                .graph = self,
                .next_edge = self.nodes.items(.first_edge)[id],
            };
        }

        // --- Queries ---

        pub fn nodeCount(self: Self) usize {
            return self.live_nodes;
        }

        pub fn edgeCount(self: Self) usize {
            return self.live_edges;
        }

        /// Returns the raw capacity of the node array (including tombstoned entries).
        /// Use this for workspace sizing where arrays are indexed by NodeIndex.
        pub fn nodeCapacity(self: Self) usize {
            return self.nodes.len;
        }

        pub fn hasNode(self: Self, id: NodeIndex) bool {
            if (id >= self.nodes.len) return false;
            return !self.nodes.items(.is_deleted)[id];
        }

        pub fn outDegree(self: *const Self, id: NodeIndex) usize {
            var count: usize = 0;
            var it = self.successors(id);
            while (it.next()) |_| count += 1;
            return count;
        }

        pub fn nodeData(self: Self, id: NodeIndex) ?*const NodeData {
            if (!self.hasNode(id)) return null;
            return &self.nodes.items(.data)[id];
        }

        pub fn nodeDataMut(self: *Self, id: NodeIndex) ?*NodeData {
            if (!self.hasNode(id)) return null;
            return &self.nodes.items(.data)[id];
        }

        pub fn edgeCountForNode(self: Self, id: NodeIndex) usize {
            var count: usize = 0;
            var current = self.nodes.items(.first_edge)[id];
            while (current) |edge_idx| {
                count += 1;
                current = self.edges.items(.next_edge)[edge_idx];
            }
            return count;
        }

        pub fn transpose(self: *const Self, alloc: Allocator) !Self {
            var new_graph = Self.init(alloc);
            errdefer new_graph.deinit();

            // Copy nodes (including tombstoned ones to preserve indices)
            for (0..self.nodes.len) |i| {
                const id = @as(NodeIndex, @intCast(i));
                _ = try new_graph.addNode(self.nodes.items(.data)[id]);
                if (self.nodes.items(.is_deleted)[id]) {
                    new_graph.nodes.items(.is_deleted)[id] = true;
                }
            }

            var edge_it = self.allEdges();
            while (edge_it.next()) |edge| {
                _ = try new_graph.addEdge(edge.to, edge.from, edge.data);
            }

            return new_graph;
        }

        // --- Node iteration ---

        pub const NodeIdIterator = struct {
            graph: *const Self,
            i: usize,

            pub fn next(it: *NodeIdIterator) ?NodeIndex {
                while (it.i < it.graph.nodes.len) {
                    const id = @as(NodeIndex, @intCast(it.i));
                    it.i += 1;
                    if (!it.graph.nodes.items(.is_deleted)[id]) return id;
                }
                return null;
            }
        };

        pub fn nodeIds(self: *const Self) NodeIdIterator {
            return .{ .graph = self, .i = 0 };
        }

        pub const EdgeIterator = struct {
            graph: *const Self,
            node_i: usize,
            edge_i: ?EdgeIndex,

            pub const Item = struct {
                from: NodeIndex,
                to: NodeIndex,
                data: EdgeData,
            };

            pub fn next(it: *EdgeIterator) ?Item {
                while (true) {
                    if (it.edge_i) |idx| {
                        const edge = it.graph.edges.get(idx);
                        it.edge_i = edge.next_edge;
                        if (!edge.is_deleted and !it.graph.nodes.items(.is_deleted)[edge.to]) {
                            return .{
                                .from = @as(NodeIndex, @intCast(it.node_i - 1)),
                                .to = edge.to,
                                .data = edge.data,
                            };
                        }
                    } else {
                        // find next valid node
                        while (it.node_i < it.graph.nodes.len) {
                            const id = @as(NodeIndex, @intCast(it.node_i));
                            it.node_i += 1;
                            if (!it.graph.nodes.items(.is_deleted)[id]) {
                                it.edge_i = it.graph.nodes.items(.first_edge)[id];
                                break;
                            }
                        } else {
                            return null;
                        }
                    }
                }
            }
        };

        pub fn allEdges(self: *const Self) EdgeIterator {
            return .{
                .graph = self,
                .node_i = 0,
                .edge_i = null,
            };
        }
    };
}

// --- Tests ---

test "ArrayGraph: Basic structure" {
    const allocator = std.testing.allocator;
    var g = ArrayGraph([]const u8, f64).init(allocator);
    defer g.deinit();

    const n1 = try g.addNode("Alice");
    const n2 = try g.addNode("Bob");

    _ = try g.addEdge(n1, n2, 1.0);

    var it = g.successors(n1);
    const first = it.next().?;
    try std.testing.expectEqual(n2, first.to);
    try std.testing.expect(it.next() == null);
}

test "ArrayGraph: Query methods" {
    const allocator = std.testing.allocator;
    var g = ArrayGraph([]const u8, f64).init(allocator);
    defer g.deinit();

    try std.testing.expectEqual(@as(usize, 0), g.nodeCount());
    try std.testing.expectEqual(@as(usize, 0), g.edgeCount());

    const n1 = try g.addNode("Alice");
    const n2 = try g.addNode("Bob");

    try std.testing.expectEqual(@as(usize, 2), g.nodeCount());
    try std.testing.expect(g.hasNode(n1));
    try std.testing.expect(g.hasNode(n2));
    try std.testing.expect(!g.hasNode(99));

    try std.testing.expectEqualStrings("Alice", g.nodeData(n1).?.*);
    try std.testing.expectEqualStrings("Bob", g.nodeData(n2).?.*);
    try std.testing.expect(g.nodeData(99) == null);

    _ = try g.addEdge(n1, n2, 1.0);
    _ = try g.addEdge(n2, n1, 2.0);

    try std.testing.expectEqual(@as(usize, 2), g.edgeCount());
    try std.testing.expectEqual(@as(usize, 1), g.edgeCountForNode(n1));
    try std.testing.expectEqual(@as(usize, 1), g.edgeCountForNode(n2));
}

test "ArrayGraph: initCapacity" {
    const allocator = std.testing.allocator;
    var g = try ArrayGraph(u32, f64).initCapacity(allocator, 100, 200);
    defer g.deinit();

    // Should not need to reallocate during this batch.
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = try g.addNode(i);
    }

    // Add edges in a star pattern.
    i = 1;
    while (i < 100) : (i += 1) {
        _ = try g.addEdge(0, i, @as(f64, @floatFromInt(i)));
    }

    try std.testing.expectEqual(@as(usize, 100), g.nodeCount());
    try std.testing.expectEqual(@as(usize, 99), g.edgeCount());
}

test "ArrayGraph: Multi-edge linked list" {
    const allocator = std.testing.allocator;
    var g = ArrayGraph(void, u32).init(allocator);
    defer g.deinit();

    const n0 = try g.addNode({});
    const n1 = try g.addNode({});
    const n2 = try g.addNode({});

    // n0 -> n1, n2, n1 (multi-edge)
    _ = try g.addEdge(n0, n1, 10);
    _ = try g.addEdge(n0, n2, 20);
    const e2 = try g.addEdge(n0, n1, 30);

    try std.testing.expectEqual(@as(usize, 3), g.edgeCountForNode(n0));

    // Walk the linked list and collect edge indices.
    var it = g.successors(n0);
    const edge_a = it.next().?;
    try std.testing.expectEqual(e2, g.edgeCount() - 1); // e2 is the last added
    try std.testing.expectEqual(n1, edge_a.to);

    const edge_b = it.next().?;
    try std.testing.expectEqual(n2, edge_b.to);

    const edge_c = it.next().?;
    try std.testing.expectEqual(n1, edge_c.to);

    try std.testing.expect(it.next() == null);
}

test "ArrayGraph: SoA field slices are correct" {
    const allocator = std.testing.allocator;
    var g = ArrayGraph(u8, f64).init(allocator);
    defer g.deinit();

    const n0 = try g.addNode(100);
    const n1 = try g.addNode(200);

    _ = try g.addEdge(n0, n1, 1.5);
    _ = try g.addEdge(n1, n0, 2.5);

    // Direct SoA access: nodes.items(.data) gives a []u8 slice.
    const node_data_slice = g.nodes.items(.data);
    try std.testing.expectEqual(@as(u8, 100), node_data_slice[n0]);
    try std.testing.expectEqual(@as(u8, 200), node_data_slice[n1]);

    // Direct SoA access: edges.items(.to) gives a []u32 slice.
    const edge_to_slice = g.edges.items(.to);
    try std.testing.expectEqual(@as(u32, n1), edge_to_slice[0]);
    try std.testing.expectEqual(@as(u32, n0), edge_to_slice[1]);
}

test "ArrayGraph: nodeCount and edgeCount reflect live entries after deletion" {
    const allocator = std.testing.allocator;
    var g = ArrayGraph(void, void).init(allocator);
    defer g.deinit();

    const n0 = try g.addNode({});
    const n1 = try g.addNode({});
    const n2 = try g.addNode({});
    _ = try g.addEdge(n0, n1, {});
    _ = try g.addEdge(n1, n2, {});
    _ = try g.addEdge(n2, n0, {});

    // Before deletion: 3 nodes, 3 edges.
    try std.testing.expectEqual(@as(usize, 3), g.nodeCount());
    try std.testing.expectEqual(@as(usize, 3), g.edgeCount());
    // nodeCapacity includes all slots.
    try std.testing.expectEqual(@as(usize, 3), g.nodeCapacity());

    // Remove an edge.
    try g.removeEdge(n0, n1);
    try std.testing.expectEqual(@as(usize, 3), g.nodeCount());
    try std.testing.expectEqual(@as(usize, 2), g.edgeCount());
    try std.testing.expectEqual(@as(usize, 3), g.nodeCapacity());

    // Remove a node — should also remove its incoming/outgoing edges.
    // n1 has incoming edge from nobody now (n0->n1 was removed), outgoing n1->n2.
    // Also n2->n0 is unaffected.
    try g.removeNode(n1);
    try std.testing.expectEqual(@as(usize, 2), g.nodeCount());
    try std.testing.expectEqual(@as(usize, 1), g.edgeCount()); // only n2->n0 remains
    // nodeCapacity still includes the tombstoned slot.
    try std.testing.expectEqual(@as(usize, 3), g.nodeCapacity());

    // The remaining edge n2->n0 should be traversable.
    var it = g.successors(n2);
    const edge = it.next();
    try std.testing.expect(edge != null);
    try std.testing.expectEqual(n0, edge.?.to);
    try std.testing.expect(it.next() == null);
}
