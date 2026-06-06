const std = @import("std");

pub const models = struct {
    pub const ArrayGraph = @import("models/array_graph.zig").ArrayGraph;
};

pub const pathfinding = @import("pathfinding.zig");
pub const property = @import("property.zig");
pub const metrics = @import("metrics.zig");
pub const centrality = @import("centrality.zig");
pub const connectivity = @import("connectivity.zig");
pub const utils = @import("utils.zig");

pub const flow = struct {
    pub const max_flow = @import("flow/max_flow.zig");
    pub const min_cut = @import("flow/min_cut.zig");
};

pub const community = struct {
    pub const metrics = @import("community/metrics.zig");
    pub const louvain = @import("community/louvain.zig");
    pub const leiden = @import("community/leiden.zig");
};

test {
    std.testing.refAllDecls(@This());

    // Explicitly reference all submodules so their tests are discovered.
    _ = @import("models/array_graph.zig");
    _ = @import("pathfinding.zig");
    _ = @import("metrics.zig");
    _ = @import("centrality.zig");
    _ = @import("connectivity.zig");
    _ = @import("utils.zig");
    _ = @import("flow/max_flow.zig");
    _ = @import("flow/min_cut.zig");
    _ = @import("property.zig");
    _ = @import("community/metrics.zig");
    _ = @import("community/louvain.zig");
    _ = @import("community/leiden.zig");
}
