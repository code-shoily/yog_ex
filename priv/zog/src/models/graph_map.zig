const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Direction = enum {
    directed,
    undirected,
};

pub const Storage = enum {
    single, // Only out_edges
    dual, // Both out_edges and in_edges
};

/// GraphMap is a graph implementation that uses HashMaps to store nodes and edges.
/// It uses 'comptime' parameters to optimize memory based on the graph's needs.
pub fn GraphMap(
    comptime NodeId: type,
    comptime NodeData: type,
    comptime EdgeData: type,
    comptime dir: Direction,
    comptime storage: Storage,
) type {
    return struct {
        const Self = @This();

        pub const Error = error{
            NodeNotFound,
            OutOfMemory,
        };

        pub const Edge = struct {
            to: NodeId,
            data: EdgeData,
        };

        allocator: Allocator,
        nodes: std.AutoHashMap(NodeId, NodeData),
        out_edges: std.AutoHashMap(NodeId, std.ArrayListUnmanaged(Edge)),

        /// This field ONLY exists in memory if storage is .dual
        in_edges: if (storage == .dual) std.AutoHashMap(NodeId, std.ArrayListUnmanaged(Edge)) else void,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .nodes = std.AutoHashMap(NodeId, NodeData).init(allocator),
                .out_edges = std.AutoHashMap(NodeId, std.ArrayListUnmanaged(Edge)).init(allocator),
                .in_edges = if (storage == .dual) std.AutoHashMap(NodeId, std.ArrayListUnmanaged(Edge)).init(allocator) else {},
            };
        }

        pub fn deinit(self: *Self) void {
            var out_it = self.out_edges.valueIterator();
            while (out_it.next()) |list| list.deinit(self.allocator);
            self.out_edges.deinit();

            if (storage == .dual) {
                var in_it = self.in_edges.valueIterator();
                while (in_it.next()) |list| list.deinit(self.allocator);
                self.in_edges.deinit();
            }

            self.nodes.deinit();
        }

        pub fn addNode(self: *Self, id: NodeId, data: NodeData) !void {
            try self.nodes.put(id, data);
        }

        pub fn addEdge(self: *Self, from: NodeId, to: NodeId, data: EdgeData) Error!void {
            if (!self.nodes.contains(from) or !self.nodes.contains(to)) return error.NodeNotFound;

            try self.addInternal(&self.out_edges, from, to, data);

            if (dir == .undirected) {
                try self.addInternal(&self.out_edges, to, from, data);
            }

            if (storage == .dual) {
                try self.addInternal(&self.in_edges, to, from, data);
                if (dir == .undirected) {
                    try self.addInternal(&self.in_edges, from, to, data);
                }
            }
        }

        pub fn removeEdge(self: *Self, from: NodeId, to: NodeId) Error!void {
            if (!self.nodes.contains(from) or !self.nodes.contains(to)) return error.NodeNotFound;

            self.removeInternal(&self.out_edges, from, to);

            if (dir == .undirected) {
                self.removeInternal(&self.out_edges, to, from);
            }

            if (storage == .dual) {
                self.removeInternal(&self.in_edges, to, from);
                if (dir == .undirected) {
                    self.removeInternal(&self.in_edges, from, to);
                }
            }
        }

        pub fn removeNode(self: *Self, id: NodeId) Error!void {
            if (!self.nodes.contains(id)) return error.NodeNotFound;

            // Remove outgoing edges (clean up reverse links)
            if (self.out_edges.get(id)) |list| {
                for (list.items) |edge| {
                    if (storage == .dual) {
                        self.removeInternal(&self.in_edges, edge.to, id);
                    } else {
                        if (dir == .undirected) {
                            self.removeInternal(&self.out_edges, edge.to, id);
                        }
                    }
                }
            }

            // Remove incoming edges (clean up forward links)
            if (storage == .dual) {
                if (self.in_edges.get(id)) |list| {
                    for (list.items) |edge| {
                        self.removeInternal(&self.out_edges, edge.to, id);
                    }
                }
                if (self.in_edges.getPtr(id)) |list| {
                    list.deinit(self.allocator);
                }
                _ = self.in_edges.remove(id);
            } else {
                if (dir == .directed) {
                    var it = self.out_edges.valueIterator();
                    while (it.next()) |list| {
                        var i: usize = 0;
                        while (i < list.items.len) {
                            if (std.meta.eql(list.items[i].to, id)) {
                                _ = list.swapRemove(i);
                            } else {
                                i += 1;
                            }
                        }
                    }
                }
            }

            if (self.out_edges.getPtr(id)) |list| {
                list.deinit(self.allocator);
            }
            _ = self.out_edges.remove(id);

            _ = self.nodes.remove(id);
        }

        // --- Queries ---

        pub fn nodeCount(self: Self) usize {
            return self.nodes.count();
        }

        pub fn edgeCount(self: Self) usize {
            var count: usize = 0;
            var it = self.out_edges.valueIterator();
            while (it.next()) |list| {
                count += list.items.len;
            }
            return if (dir == .undirected) count / 2 else count;
        }

        pub fn outDegree(self: Self, id: NodeId) usize {
            if (self.out_edges.get(id)) |list| {
                return list.items.len;
            }
            return 0;
        }

        pub fn inDegree(self: Self, id: NodeId) usize {
            if (storage == .dual) {
                if (self.in_edges.get(id)) |list| {
                    return list.items.len;
                }
                return 0;
            } else {
                if (dir == .undirected) {
                    return self.outDegree(id);
                }
                var count: usize = 0;
                var it = self.out_edges.valueIterator();
                while (it.next()) |list| {
                    for (list.items) |edge| {
                        if (std.meta.eql(edge.to, id)) count += 1;
                    }
                }
                return count;
            }
        }

        pub fn hasNode(self: Self, id: NodeId) bool {
            return self.nodes.contains(id);
        }

        pub fn hasEdge(self: Self, from: NodeId, to: NodeId) bool {
            return self.edgeData(from, to) != null;
        }

        pub fn nodeData(self: Self, id: NodeId) ?NodeData {
            return self.nodes.get(id);
        }

        pub fn edgeData(self: Self, from: NodeId, to: NodeId) ?EdgeData {
            const list = self.out_edges.get(from) orelse return null;
            for (list.items) |edge| {
                if (std.meta.eql(edge.to, to)) return edge.data;
            }
            return null;
        }

        pub fn transpose(self: Self, alloc: Allocator) !Self {
            var new_graph = Self.init(alloc);
            errdefer new_graph.deinit();

            var node_it = self.nodes.iterator();
            while (node_it.next()) |entry| {
                try new_graph.addNode(entry.key_ptr.*, entry.value_ptr.*);
            }

            var edge_it = self.allEdges();
            while (edge_it.next()) |edge| {
                try new_graph.addEdge(edge.to, edge.from, edge.data);
            }

            return new_graph;
        }

        // --- Unified Iterators ---

        pub const EdgeIterator = struct {
            graph: *const Self,
            node_it: std.AutoHashMap(NodeId, std.ArrayListUnmanaged(Edge)).Iterator,
            current_from: ?NodeId = null,
            current_list: ?[]Edge = null,
            list_index: usize = 0,

            pub const Item = struct {
                from: NodeId,
                to: NodeId,
                data: EdgeData,
            };

            pub fn next(it: *EdgeIterator) ?Item {
                while (true) {
                    if (it.current_list) |list| {
                        if (it.list_index < list.len) {
                            const edge = list[it.list_index];
                            it.list_index += 1;
                            return .{ .from = it.current_from.?, .to = edge.to, .data = edge.data };
                        } else {
                            it.current_list = null;
                        }
                    }

                    if (it.node_it.next()) |entry| {
                        it.current_from = entry.key_ptr.*;
                        it.current_list = entry.value_ptr.items;
                        it.list_index = 0;
                    } else {
                        return null;
                    }
                }
            }
        };

        pub fn allEdges(self: *const Self) EdgeIterator {
            // We cast away const to get an iterator. In Zig 0.11+, HashMap iterators
            // can be created from const pointers or pass-by-value. We use a const cast
            // if needed, but value iterator should work.
            var m_self = @constCast(self);
            return .{
                .graph = self,
                .node_it = m_self.out_edges.iterator(),
            };
        }

        pub const SuccessorIterator = struct {
            items: []const Edge,
            index: usize = 0,

            pub fn next(it: *SuccessorIterator) ?Edge {
                if (it.index >= it.items.len) return null;
                const edge = it.items[it.index];
                it.index += 1;
                return edge;
            }
        };

        pub fn successors(self: Self, id: NodeId) SuccessorIterator {
            const list = self.out_edges.get(id);
            return .{ .items = if (list) |l| l.items else &.{} };
        }

        pub fn predecessors(self: Self, id: NodeId) SuccessorIterator {
            if (storage == .single) {
                @compileError("predecessors() is only available for .dual storage graphs");
            }
            const list = self.in_edges.get(id);
            return .{ .items = if (list) |l| l.items else &.{} };
        }

        // --- Node iteration ---

        pub const NodeIdIterator = struct {
            it: std.AutoHashMap(NodeId, NodeData).KeyIterator,

            pub fn next(self: *NodeIdIterator) ?NodeId {
                const key_ptr = self.it.next() orelse return null;
                return key_ptr.*;
            }
        };

        pub fn nodeIds(self: Self) NodeIdIterator {
            return .{ .it = self.nodes.keyIterator() };
        }

        fn addInternal(self: *Self, map: anytype, src: NodeId, dst: NodeId, data: EdgeData) !void {
            const gop = try map.getOrPut(src);
            if (!gop.found_existing) {
                gop.value_ptr.* = .empty;
            }
            try gop.value_ptr.append(self.allocator, .{ .to = dst, .data = data });
        }

        fn removeInternal(_: *Self, map: anytype, src: NodeId, dst: NodeId) void {
            if (map.getPtr(src)) |list| {
                var i: usize = 0;
                while (i < list.items.len) {
                    if (std.meta.eql(list.items[i].to, dst)) {
                        _ = list.swapRemove(i);
                    } else {
                        i += 1;
                    }
                }
            }
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "GraphMap: add and query nodes" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, []const u8, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, "alpha");
    try g.addNode(2, "beta");

    try std.testing.expect(g.hasNode(1));
    try std.testing.expect(g.hasNode(2));
    try std.testing.expect(!g.hasNode(3));
    try std.testing.expectEqual(@as(usize, 2), g.nodeCount());
    try std.testing.expectEqualStrings("alpha", g.nodeData(1).?);
    try std.testing.expectEqualStrings("beta", g.nodeData(2).?);
}

test "GraphMap: add and query edges (directed)" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, f64, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});
    try g.addEdge(1, 2, 1.5);
    try g.addEdge(2, 3, 2.5);

    try std.testing.expect(g.hasEdge(1, 2));
    try std.testing.expect(!g.hasEdge(2, 1)); // directed
    try std.testing.expectEqual(@as(f64, 1.5), g.edgeData(1, 2).?);
    try std.testing.expectEqual(@as(usize, 2), g.edgeCount());
}

test "GraphMap: add and query edges (undirected)" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, void, .undirected, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addEdge(1, 2, {});

    // Undirected adds both directions
    try std.testing.expect(g.hasEdge(1, 2));
    try std.testing.expect(g.hasEdge(2, 1));
    try std.testing.expectEqual(@as(usize, 1), g.edgeCount()); // counted once
}

test "GraphMap: remove edge" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addEdge(1, 2, {});
    try std.testing.expect(g.hasEdge(1, 2));

    try g.removeEdge(1, 2);
    try std.testing.expect(!g.hasEdge(1, 2));
    try std.testing.expectEqual(@as(usize, 0), g.edgeCount());
}

test "GraphMap: remove node" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});
    try g.addEdge(1, 2, {});
    try g.addEdge(2, 3, {});
    try g.addEdge(3, 1, {});

    try g.removeNode(2);
    try std.testing.expect(!g.hasNode(2));
    try std.testing.expectEqual(@as(usize, 2), g.nodeCount());
    // Edge 1->2 should be gone, edge 3->1 should remain
    try std.testing.expect(!g.hasEdge(1, 2));
    try std.testing.expect(g.hasEdge(3, 1));
}

test "GraphMap: dual storage predecessors" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, void, .directed, .dual).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addNode(3, {});
    try g.addEdge(1, 3, {});
    try g.addEdge(2, 3, {});

    // Node 3 should have predecessors 1 and 2
    var count: usize = 0;
    var it = g.predecessors(3);
    while (it.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(@as(usize, 2), g.inDegree(3));
}

test "GraphMap: successors and nodeIds iterators" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(10, {});
    try g.addNode(20, {});
    try g.addNode(30, {});
    try g.addEdge(10, 20, {});
    try g.addEdge(10, 30, {});

    // successors of 10 should be 20 and 30
    var succ_count: usize = 0;
    var sit = g.successors(10);
    while (sit.next()) |_| succ_count += 1;
    try std.testing.expectEqual(@as(usize, 2), succ_count);
    try std.testing.expectEqual(@as(usize, 2), g.outDegree(10));

    // nodeIds should yield all 3 nodes
    var node_count: usize = 0;
    var nit = g.nodeIds();
    while (nit.next()) |_| node_count += 1;
    try std.testing.expectEqual(@as(usize, 3), node_count);
}

test "GraphMap: transpose" {
    const allocator = std.testing.allocator;
    var g = GraphMap(u32, void, void, .directed, .single).init(allocator);
    defer g.deinit();

    try g.addNode(1, {});
    try g.addNode(2, {});
    try g.addEdge(1, 2, {});

    var t = try g.transpose(allocator);
    defer t.deinit();

    // Original: 1->2. Transpose: 2->1.
    try std.testing.expect(!t.hasEdge(1, 2));
    try std.testing.expect(t.hasEdge(2, 1));
}
