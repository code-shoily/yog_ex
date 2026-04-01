# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Pathfinding**: Added `all_pair_shortest_path_unweighted/1` - computes shortest path distances between all pairs of nodes in unweighted graphs using BFS.

### Changed

- **MinCut Algorithm Performance Optimization**
  - Complete rewrite of `Yog.Flow.MinCut.global_min_cut/1` for significant performance improvements
  - Changed partition tracking from `MapSet` of node IDs to integer counts
    - **Before**: O(n) `MapSet.union/2` and `MapSet.difference/2` on every contraction
    - **After**: O(1) integer arithmetic (`s_size + t_size`)
  - Changed `Yog.Flow.MinCutResult` struct to store partition sizes instead of full node sets:
    - **Before**: `%MinCutResult{source_side: MapSet.t(), sink_side: MapSet.t(), cut_value: number()}`
    - **After**: `%MinCutResult{cut_value: number(), source_side_size: non_neg_integer(), sink_side_size: non_neg_integer(), algorithm: atom()}`
  - Uses `Yog.Transform.map_nodes/2` to initialize node weights to 1 (matching Gleam `yog` implementation)
  - Updated `Yog.Flow.MaxFlow.extract_min_cut/1` and `min_cut/3` to return the new struct format
  - Added helper functions:
    - `Yog.Flow.MinCutResult.partition_product/1` - product of partition sizes (common for AOC problems)
    - `Yog.Flow.MinCutResult.total_nodes/1` - total node count

### Breaking

- `Yog.Flow.MinCutResult` struct fields changed:
  - Removed: `source_side`, `sink_side` (MapSets)
  - Added: `source_side_size`, `sink_side_size` (integers)
- `Yog.Flow.MinCutResult.new/2` now returns struct with sizes computed from MapSets (backward compatibility shim)
- `Yog.Flow.MinCutResult.compute_cut_value/2` deprecated - use `cut_value` field directly

## [0.90.0] - 2026-03-30

This release mostly focuses on internal optimizations, mostly around community and centrality modules.

### Added

- Two functions in `Utils` - `fisher_yates` and `norm_diff`
- **Flow Algorithms**: Added `calculate/3` convenience wrapper for standard integer max flow computations.
- **Connectivity**: Added `counts_estimate/2` using HyperLogLog for O(V) memory reachability counting on large graphs (vs O(V²) for exact counts).

### Changed

- **MinCut Algorithm**
  - MAS now uses priority queue for O(V log V) per phase (was O(V²)).
  - Returns `MinCutResult` struct with actual node partitions (was plain map with counts).
- **MaxFlow Algorithm**
  - Tail-recursive Edmonds-Karp to prevent stack overflow on large graphs.
  - BFS uses `:queue` module for O(1) enqueue/dequeue (was O(N) list append).
  - Bottleneck capacity tracked during BFS discovery (single pass vs two passes).
  - Direct graph struct construction for residual graphs (faster bulk reconstruction).

### Breaking

- Remove `implicity_dijkstra` function from `Yog.Traversal`
- Remove `from_tuple` from `Yog.Pathfinding.Path` module - we have converted all tuple based data structure from path and will no longer be needing this.
- Change data type of `Yog.DisjointSet` from tuple to struct

## [0.80.0] - 2026-03-27

### Added
- **`Yog.Flow.MaxFlow`**: Refactored internal residual storage from a flat `{u, v}` map to a nested `u => %{v => capacity}` map, resulting in 30-50% performance improvement for Edmonds-Karp via O(1) successor lookups.
- **`Yog.Connectivity`**: New `shell_decomposition/1` operation for grouping nodes into k-shells (nodes with core number exactly k).
- **`Yog.Functional` Enhancements**:
  - Comprehensive `iex` doctests for all core functional modules (`Model`, `Analysis`, `Transform`, `Traversal`, `Algorithms`).
  - New `Traversal` operations: `preorder/2`, `postorder/2` (DFS finishing order), and `reachable/2`.
  - New `Analysis` algorithms: `transitive_closure/1` (reachability), `biconnected_components/1`, and `dominators/2` (immediate dominators).
  - New `Algorithms` operation: `distances/2` for all-node distance mapping from a source.
  - **Interop**: Added `from_adjacency_graph/1` and `to_adjacency_graph/1` to `Yog.Functional.Model` for seamless conversion between inductive and adjacency-based graph representations.
- **`Yog.Property`**: Added advanced structural analysis predicates: `connected?` (unified strong/weak connectivity), `planar?` (necessary condition verification), and `chordal?` (Maximum Cardinality Search based verification).

### Changed
- **Algorithm Optimization**:
  - `Yog.Flow.MaxFlow`: Replaced manual, recursive BFS implementation with the library's standardized `Yog.Traversal.Implicit.implicit_fold/1`.
  - `Yog.Connectivity.KCore`: Implemented "lazy deletion" in core number buckets to preserve O(V+E) complexity by avoiding costly O(N) list deletions.
- **Builder API Unification**: Removed legacy tuple-based builder types and function clauses from `Yog.Builder.Labeled` and `Yog.Builder.Live`. All builder APIs are now strictly struct-based (`t()`).
- **Documentation**: Updated `README.md` with Livebook installation guides and KinoYog integration details.
- **Benchmarking**: Updated performance statistics for GraphML parsing with `saxy` (12MB Slashdot dataset).
- **Algorithm Generalization**:
  - `transitive_closure/1` and `transitive_reduction/1` moved from `Yog.DAG.Algorithm` to `Yog.Transform`. Now generalized to support both cyclic and acyclic graphs (where applicable).
  - `count_reachability/2` moved from `Yog.DAG.Algorithm` to `Yog.Connectivity.reachability_counts/2`.
  - Added `Yog.Traversal.reachable?/3` helper for simple point-to-point reachability checks.
  - **Traversal Enhancements**:
    - Added `:best_first` (greedy) order for `walk`, `walk_until`, and `fold_walk` with user-defined priority functions.
    - Added `:random` order for randomized traversal (visits all reachable nodes in random order).
    - New `Yog.Traversal.Walk.random_walk/3` for fixed-step stochastic random walks.

### Removed
- **Deprecated APIs**: Removed `Yog.Model.add_edge_ensured/5`.
- **Redundant DAG Algorithms**: Removed `transitive_closure/1`, `transitive_reduction/1`, and `count_reachability/2` from `Yog.DAG.Algorithm`. Use `Yog.Transform` and `Yog.Connectivity` instead.

## [0.70.0] - 2026-03-26

Various performance improvements and examples.

## [0.60.0] - 2026-03-23

### Added
- **Pure Elixir Implementation**: Complete migration from Gleam wrapper to 100% pure Elixir implementation
  - All 58 modules now implemented in pure Elixir with zero Gleam dependencies
  - Removed all Gleam dependencies (`:yog`, `:gleam_stdlib`, `:gleam_json`, `:gleamy_structures`, `:gleamy_bench`)
  - Installation is now as simple as `{:yog_ex, "~> 0.60"}` with no additional configuration required

### Changed
- **Graph Structure**: Changed from tuple format `{:graph, kind, nodes, out_edges, in_edges}` to proper Elixir struct `%Yog.Graph{kind, nodes, out_edges, in_edges}`
- **Improved priority queue usage**: Now uses `Yog.PQ` (pairing heap) instead of sorted lists
  - `lexicographical_topological_sort`: O(V log V + E) vs O(V² + E) previously
  - `implicit_dijkstra`: O(E log V) vs O(E × V) previously
  - More efficient for large graphs
- **Module Reorganization**:
  - `Yog.Pathfinding` (facade) → Removed, use individual modules directly
  - `Yog.MaxFlow` → `Yog.Flow.MaxFlow`
  - `Yog.MinCut` → `Yog.Flow.MinCut`
  - `Yog.Render` modules → `Yog.Render.DOT`, `Yog.Render.Mermaid`, `Yog.Render.ASCII`
  - `Yog.Generators` → `Yog.Generator.Classic`, `Yog.Generator.Random`
  - `Yog.PQ` → `Yog.PriorityQueue` (filename also changed from `pq.ex` to `priority_queue.ex`)
- **API Updates**:
  - Pathfinding functions now return `%Yog.Pathfinding.Path{}` struct with `weight` field (was `total_weight`)
  - `edmonds_karp/8` compare function now expects boolean return (`<=` instead of `:lt/:eq/:gt`)
  - `floyd_warshall/4` uses positional arguments instead of keyword arguments
  - `global_min_cut/1` moved from `Yog.MinCut` to `Yog.Flow.MinCut`

### Migration Guide
- **Installation**: Remove all Gleam-related dependencies from your `mix.exs`, keep only `{:yog_ex, "~> 0.60"}`
- **Graph access**: Replace `elem(graph, 2)` with `graph.nodes`, `elem(graph, 1)` with `graph.kind`
- **Module names**: Update any `Yog.MaxFlow` calls to `Yog.Flow.MaxFlow`, etc.
- **Compare functions**: Update compare functions to return booleans instead of `:lt/:eq/:gt`

## [0.52.3] - 2026-03-22

### Fixed
- Fixed dependency configuration causing compilation failures in downstream projects:
  - Removed `app: false` from `yog` dependency (it has a valid OTP application file)
  - Added explicit Gleam dependencies (`gleam_stdlib`, `gleam_json`, `gleamy_structures`, `gleamy_bench`) that `yog` requires
- Users can now use YogEx with just `{:yog_ex, "~> 0.52.3"}` without any additional dependency configuration

## [0.52.2] - 2026-03-22

### Fixed
- Documentation now builds correctly on HexDocs (fixed ex_doc configuration in publish environment)

## [0.52.1] - 2026-03-22

### Changed
- **I/O Modules**: All graph I/O modules (`Yog.IO.GraphML`, `Yog.IO.GDF`, `Yog.IO.Pajek`, `Yog.IO.LEDA`, `Yog.IO.TGF`, `Yog.IO.JSON`) are now implemented in **pure Elixir** and work out of the box without any additional dependencies.
- **Dependencies**: Completely removed `yog_io` dependency. Users no longer need to manually add `yog_io` to their dependencies.
- **Installation**: Simplified installation - YogEx now works with all features using just `{:yog_ex, "~> 0.52.1"}`.

### Implementation Details
- **GraphML**: Implemented using Erlang's `:xmerl` library for XML parsing and serialization
- **GDF**: Pure Elixir CSV parser with support for duplicate column names and proper escaping
- **Pajek**: Case-insensitive parser with support for quoted/unquoted labels and comments
- **LEDA**: Native implementation supporting 1-indexed nodes and sequential ordering
- **TGF**: Simple text-based format parser
- **JSON**: Pure Elixir serialization for adjacency lists and matrices

### Fixed
- Resolved dependency conflicts that previously required users to manually configure `yog_io` with `manager: :rebar3, app: false, override: true`
- Eliminated Gleam package dependencies for I/O functionality

## [0.51.0] - 2026-03-22

### Added
- **`Yog.Pathfinding`**: New facade module providing a unified keyword-based API for `Dijkstra`, `AStar`, `BellmanFord`, and `FloydWarshall`.
- **`Yog.Connectivity`**: Support for `connected_components/1` and `weakly_connected_components/1` via `defdelegate`.
- **I/O Integration**: Support for multiple graph formats via `yog_io`: `GDF`, `GraphML`, `JSON`, `LEDA`, `Pajek`, and `TGF`.
- **Documentation**: Comprehensive `@moduledoc`, `@doc`, and doctests for `Yog.Connectivity` and `Yog.Pathfinding`.

### Changed
- **DAG Modules**: Renamed for Elixir consistency: `Yog.DAG.Models` -> `Yog.DAG.Model` and `Yog.DAG.Algorithms` -> `Yog.DAG.Algorithm`.
- **Examples**: Updated all example files to use `add_edge!` (and variants) when chaining to handle the `Result` type correctly.
- **Module Names**: Corrected outdated module references in examples (`Yog.Components` -> `Yog.Connectivity`, `Yog.TopologicalSort` -> `Yog.Traversal`).
- **Dependencies**: Updated `yog` to `~> 5.1`. **Breaking**: `yog_io` is now an **optional dependency** that users must add manually if they need I/O functionality (GraphML, GDF, JSON, LEDA, Pajek, TGF formats). This resolves dependency conflicts during hex publishing. See README installation guide for details.
- **Installation**: Added comprehensive installation guide explaining how to add `yog_io` for I/O support.
