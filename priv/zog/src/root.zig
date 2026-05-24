const std = @import("std");

pub const models = struct {
    pub const GraphMap = @import("models/graph_map.zig").GraphMap;
    pub const ArrayGraph = @import("models/array_graph.zig").ArrayGraph;
    pub const Direction = @import("models/graph_map.zig").Direction;
    pub const Storage = @import("models/graph_map.zig").Storage;
};

pub const traversal = struct {
    pub const bfs = @import("traversal.zig").bfs;
    pub const dfs = @import("traversal.zig").dfs;
    pub const bestFirstSearch = @import("traversal.zig").bestFirstSearch;
    pub const randomWalk = @import("traversal.zig").randomWalk;
    pub const topologicalSort = @import("traversal.zig").topologicalSort;
};

pub const pathfinding = struct {
    pub const sssp = @import("pathfinding/sssp.zig");
    pub const apsp = @import("pathfinding/apsp.zig");
};

pub const property = @import("property.zig");
pub const connectivity = @import("connectivity.zig");
pub const metrics = @import("metrics.zig");
pub const centrality = @import("centrality.zig");
pub const utils = @import("utils.zig");

pub const flow = struct {
    pub const max_flow = @import("flow/max_flow.zig");
    pub const min_cut = @import("flow/min_cut.zig");
};

pub const community = struct {
    pub const metrics = @import("community/metrics.zig");
    pub const louvain = @import("community/louvain.zig");
};

test {
    std.testing.refAllDecls(@This());

    // Explicitly reference all submodules so their tests are discovered.
    _ = @import("models/graph_map.zig");
    _ = @import("models/array_graph.zig");
    _ = @import("traversal.zig");
    _ = @import("pathfinding/sssp.zig");
    _ = @import("pathfinding/apsp.zig");
    _ = @import("connectivity.zig");
    _ = @import("metrics.zig");
    _ = @import("centrality.zig");
    _ = @import("utils.zig");
    _ = @import("flow/max_flow.zig");
    _ = @import("flow/min_cut.zig");
    _ = @import("property.zig");
    _ = @import("community/metrics.zig");
    _ = @import("community/louvain.zig");
}
