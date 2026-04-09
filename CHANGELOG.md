# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Classic Graph Generators
- **Platonic Solids** (#102): Added all five Platonic solid generators in `Yog.Generator.Classic`:
  - `tetrahedron/0` - Complete graph K₄ (4 vertices, 6 edges)
  - `cube/0` - 3D hypercube Q₃ (8 vertices, 12 edges)
  - `octahedron/0` - Dual of cube (6 vertices, 12 edges)
  - `dodecahedron/0` - 20 vertices, 30 edges, golden ratio embedding
  - `icosahedron/0` - Dual of dodecahedron (12 vertices, 30 edges)
- **General Tree Generators** (#103): Added k-ary tree and related generators:
  - `kary_tree/2` - Complete k-ary tree of given depth with configurable arity
  - `complete_kary/2` - Complete m-ary tree with exactly n nodes
  - `caterpillar/2` - Caterpillar tree with configurable spine length
- **Circular and Möbius Ladders** (#104): Added ladder graph variants:
  - `circular_ladder/1` - Prism graph CL_n = C_n × K_2 (Cartesian product)
  - `mobius_ladder/1` - Möbius ladder ML_n with twist topology
  - `prism/1` - Alias for `circular_ladder/1`
- **Friendship and Windmill Graphs** (#105): Added friendship theorem graphs:
  - `friendship/1` - Friendship graph F_n with n triangles sharing a common vertex
  - `windmill/2` - Generalized windmill graph W_n^{(k)} with configurable clique size
  - `book/1` - Book graph B_n with triangles sharing a common edge (spine)
- **Crown Graph** (#106): Added `crown/1` - Crown graph S_n^0 = K_{n,n} minus perfect matching
- **Maze Generators** (#120): Expanded `Yog.Generator.Maze` with several classic algorithms:
  - `aldous_broder/3` - Random-walk based uniform spanning tree
  - `wilson/3` - Loop-erased random walk for efficient uniform mazes
  - `kruskal/3` - randomized MST-based generation using Disjoint Sets
  - `ellers/3` - Row-by-row generation with O(cols) memory
  - `growing_tree/3` - Versatile generator supporting LIFO, FIFO, and random strategies
  - `recursive_division/3` - Fractal, chamber-based generation
  - `prim_simplified/3` & `prim_true/3` - Frontier-based randomized growing

#### Random Graph Generators
- **Configuration Model** (#110): Added configurable random graph generators:
  - `configuration_model/2` - Stub matching with rejection sampling for simple graphs
  - `randomize_degree_sequence/2` - Degree sequence randomization preserving distribution
  - `power_law_graph/2` - Scale-free networks using power-law degree distribution
- **Kronecker Graphs** (#109): Added recursive matrix-based generators:
  - `kronecker/3` - Kronecker graph generator with initiator matrix
  - `rmat/7` - R-MAT (Recursive Matrix) generator for realistic networks
  - `kronecker_general/3` - Generalized Kronecker with arbitrary initiator
- **Geometric Graphs** (#107): Added spatial network generators:
  - `geometric/2` - 2D geometric random graph with distance threshold
  - `geometric_nd/2` - N-dimensional geometric graph
  - `waxman/2` - Waxman model with distance-probabilistic edge formation

#### Pathfinding
- **Widest Path (Maximum Capacity Path)** (#95): Added `Yog.Pathfinding.widest_path/3` - finds the path with maximum bottleneck capacity between two nodes. Useful for network bandwidth routing, finding reliable paths, and max-min fair allocation problems.
  - Maximizes the minimum edge weight along the path (the bottleneck)
  - Algorithm: Modified Dijkstra with `min` for capacity combination and reverse comparison to prioritize higher capacities
  - Returns `{:ok, %Path{}}` with `algorithm: :widest_path` and the bottleneck capacity as `weight`
  - Returns `:error` when no path exists between the nodes
  - **Complexity**: O((V + E) log V) time, O(V) space
- **Single-Pair Shortest Path (Unweighted)**: Added `Yog.Pathfinding.shortest_path_unweighted/3` - finds the shortest path between two nodes in unweighted graphs using BFS with early termination. More efficient than Dijkstra for unweighted graphs (no heap overhead) and uses predecessor map for memory-efficient path reconstruction instead of storing full paths in the queue.
  - Returns `{:ok, [node_id]}` with the path from source to target
  - Returns `{:error, :no_path}` when target is unreachable
  - Validates source/target existence before searching
  - Works with both directed and undirected graphs

#### Other Changes
- **Pathfinding**: Added `Johnson's algorithm` to Matrix auto-selection for non-negative weights on sparse graphs with many POIs. Previously Johnson's was only used with negative weights; now it's also selected for sparse graphs (E < V²/4) with many POIs (P > V/3) instead of Floyd-Warshall.

### Changed

- **Dijkstra Implementation**: `Yog.Pathfinding.Dijkstra` now delegates `shortest_path/6`, `implicit_dijkstra/6`, and `implicit_dijkstra_by/7` to `Yog.Pathfinding.AStar` with a zero heuristic (`fn _, _ -> 0 end`). This reduces code duplication since Dijkstra's algorithm is mathematically equivalent to A* with zero heuristic. `single_source_distances/5` retains its native implementation as A* requires a goal node.
- **Bellman-Ford Optimization**: Added early termination optimization. If no distances change during a relaxation pass, the algorithm stops early instead of completing all V-1 iterations.
  - **Performance improvement**: 13-24x faster on typical graphs that converge quickly
  - Small graphs (50 nodes): 64 μs → 5.5 μs
  - Medium graphs (100 nodes): 471 μs → 35 μs
- **Bidirectional BFS Optimization**: Fixed O(n) `length/1` queue size check by tracking sizes separately (O(1)). Replaced list-based queue with `:queue` module for proper O(1) enqueue/dequeue operations.
- **Johnson's Algorithm Optimization**: Added early termination to the Bellman-Ford phase (same optimization as standalone Bellman-Ford module).
- **Bidirectional Dijkstra**: Now uses a proper implementation with two priority queues (forward and backward search) instead of delegating to regular Dijkstra. Implementation includes meeting point detection and optimal path reconstruction.

### Breaking

- **Removed `Yog.Pathfinding.Utils` module**. Its functions have been merged into `Yog.Pathfinding.Path`:
  - `Utils.path(nodes, weight)` → Use `Path.new(nodes, weight)`
  - `Utils.nodes(path)` → Use `path.nodes` directly
  - `Utils.total_weight(path)` → Use `path.weight` directly

## [0.95.0] - 2026-04-04

### Added

- **Pathfinding**: Added `all_pair_shortest_path_unweighted/1` - computes shortest path distances between all pairs of nodes in unweighted graphs using BFS.
- **Operations**: Added `Yog.Operation.line_graph/2` - constructs the line graph (or line digraph) of a graph, where each edge becomes a node and adjacency is determined by shared endpoints (undirected) or head-to-tail matching (directed).
- **I/O**: Added `Yog.IO.Libgraph` module for bidirectional conversion with the [libgraph](https://hex.pm/packages/libgraph) library. Supports automatic type detection (Graph, Multi.Graph, DAG) based on graph structure.

### Changed

- **Priority Queue Restructure**: Split `Yog.PriorityQueue` into two separate modules with distinct performance characteristics:
  - `Yog.PairingHeap` - O(1) push, O(log n) amortized pop, pure Elixir (faster for Dijkstra/A* pathfinding)
  - `Yog.BalancedTree` - O(log n) push/pop, uses `:gb_trees` (better for balanced workloads)
  - Both modules share the same API for drop-in replacement in pathfinding algorithms
- **Generators**: Add `Yog.Generator.Random.sbm/5` and `Yog.Generator.Random.sbm_with_labels/5` to generate graphs using the Stochastic Block Model (SBM).
- **MST Result Struct**: `Yog.MST.kruskal/2` and `Yog.MST.prim/2` now return `{:ok, %Yog.MST.Result{}}` instead of a raw edge list. The struct contains `edges`, `total_weight`, `node_count`, `edge_count`, and `algorithm` fields.
- **Prim's `:from` option**: `Yog.MST.prim/1` now accepts a `:from` keyword to specify the starting node.
- **Renamed `Yog.Flow.NetworkSimplex` to `Yog.Flow.SuccessiveShortestPath`** to accurately reflect the implemented algorithm (Successive Shortest Path, not Network Simplex).
- **Flow Algorithms**: `Yog.Flow.SuccessiveShortestPath.min_cost_flow/4` now uses Dijkstra with node potentials instead of Bellman-Ford on every iteration, improving complexity from O(F · V · E) to O(F · (E + V log V)).
- **Transform**: Major performance optimization for `Yog.Transform.contract/4` — replaced repeated `Model.add_edge_with_combine` / `Model.remove_node` calls with direct map surgery, eliminating per-edge node-existence checks and redundant graph struct reconstructions.

- **MinCut Algorithm Performance Optimization**
  - Complete rewrite of `Yog.Flow.MinCut.global_min_cut/1` for significant performance improvements
  - Eliminated redundant `O(V)` `total_nodes` recomputation inside the Stoer-Wagner loop by calculating it once and passing it as a constant parameter
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
- `Yog.Traversal.Cycle` module has been removed. Use `Yog.Property.Cyclicity` instead.
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
