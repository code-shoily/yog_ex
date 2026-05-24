const std = @import("std");

/// Disjoint Set Union (Union-Find) with path compression and union by rank.
///
/// Generic over element type. Uses hash maps for parent and rank tracking.
pub fn DisjointSet(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        parents: std.AutoHashMap(T, T),
        ranks: std.AutoHashMap(T, usize),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .parents = std.AutoHashMap(T, T).init(allocator),
                .ranks = std.AutoHashMap(T, usize).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.parents.deinit();
            self.ranks.deinit();
        }

        /// Adds a new singleton set. No-op if element already exists.
        pub fn add(self: *Self, element: T) !void {
            if (self.parents.contains(element)) return;
            try self.parents.put(element, element);
            try self.ranks.put(element, 0);
        }

        /// Finds the representative of the set containing `element`.
        /// Automatically adds the element if not present.
        /// Uses iterative path compression (two-pass) to avoid stack overflow.
        pub fn find(self: *Self, element: T) !T {
            if (!self.parents.contains(element)) {
                try self.add(element);
                return element;
            }

            // Pass 1: walk to root
            var root = element;
            while (true) {
                const parent = self.parents.get(root) orelse break;
                if (std.meta.eql(parent, root)) break;
                root = parent;
            }

            // Pass 2: path compression — point all nodes on the path directly to root
            var current = element;
            while (!std.meta.eql(current, root)) {
                const parent = self.parents.get(current).?;
                try self.parents.put(current, root);
                current = parent;
            }

            return root;
        }

        /// Merges the sets containing `x` and `y`. Returns true if merged, false if already same set.
        pub fn merge(self: *Self, x: T, y: T) !bool {
            const root_x = try self.find(x);
            const root_y = try self.find(y);

            if (std.meta.eql(root_x, root_y)) return false;

            const rank_x = self.ranks.get(root_x) orelse 0;
            const rank_y = self.ranks.get(root_y) orelse 0;

            if (rank_x < rank_y) {
                try self.parents.put(root_x, root_y);
            } else if (rank_x > rank_y) {
                try self.parents.put(root_y, root_x);
            } else {
                try self.parents.put(root_y, root_x);
                try self.ranks.put(root_x, rank_x + 1);
            }

            return true;
        }

        /// Checks if two elements are in the same set.
        pub fn connected(self: *Self, x: T, y: T) !bool {
            const root_x = try self.find(x);
            const root_y = try self.find(y);
            return std.meta.eql(root_x, root_y);
        }

        /// Returns the number of elements.
        pub fn size(self: Self) usize {
            return self.parents.count();
        }
    };
}

// --- Tests ---

test "DisjointSet: basic add and find" {
    const allocator = std.testing.allocator;
    var dsu = DisjointSet(u32).init(allocator);
    defer dsu.deinit();

    try dsu.add(1);
    try dsu.add(2);

    try std.testing.expectEqual(@as(u32, 1), try dsu.find(1));
    try std.testing.expectEqual(@as(u32, 2), try dsu.find(2));
}

test "DisjointSet: union merges sets" {
    const allocator = std.testing.allocator;
    var dsu = DisjointSet(u32).init(allocator);
    defer dsu.deinit();

    _ = try dsu.merge(1, 2);
    _ = try dsu.merge(2, 3);

    try std.testing.expect(try dsu.connected(1, 3));
    try std.testing.expect(try dsu.connected(1, 2));
    try std.testing.expect(try dsu.connected(2, 3));
}

test "DisjointSet: union returns false for same set" {
    const allocator = std.testing.allocator;
    var dsu = DisjointSet(u32).init(allocator);
    defer dsu.deinit();

    _ = try dsu.merge(1, 2);
    const merged = try dsu.merge(1, 2);

    try std.testing.expect(!merged);
}

test "DisjointSet: path compression" {
    const allocator = std.testing.allocator;
    var dsu = DisjointSet(u32).init(allocator);
    defer dsu.deinit();

    _ = try dsu.merge(1, 2);
    _ = try dsu.merge(2, 3);
    _ = try dsu.merge(3, 4);

    // After find(1), all nodes on the path should point directly to root
    _ = try dsu.find(1);

    // All should still be connected
    try std.testing.expect(try dsu.connected(1, 4));
}

test "DisjointSet: auto-add on find" {
    const allocator = std.testing.allocator;
    var dsu = DisjointSet(u32).init(allocator);
    defer dsu.deinit();

    const root = try dsu.find(42);
    try std.testing.expectEqual(@as(u32, 42), root);
    try std.testing.expectEqual(@as(usize, 1), dsu.size());
}


