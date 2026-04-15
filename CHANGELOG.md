# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

#### Added

#### Core API
- `Yog.Model.add_nodes_from/2` and `Yog.add_nodes_from/2` - Add multiple nodes from an iterable (list of IDs, `{id, data}` tuples, a map, or another `Yog.Graph`).
- `Yog.from_nodes/2` - Create a new graph from a list of nodes, symmetric to `Yog.from_edges/2`.

#### DAG Algorithms
- `Yog.DAG.Algorithm.topological_generations/1` and `Yog.DAG.topological_generations/1` - Returns a list of topological generations (layers) of a DAG.
  - Optimized to strict **O(V + E)** using a propagating waitlist to avoid $O(V^2)$ scanning overhead.
  - Nodes within a generation are mutually independent, enabling parallel `Task.async_stream` batch execution.

#### Transformations
- `Yog.Transform.quotient_graph/4` - Constructs a quotient graph from a partition map.
  - Now supports an optional `combine_data` parameter for deterministic node payload aggregation.
  - Optimized memory footprint by avoiding $O(E)$ heap allocation spikes during edge projection.
  - Uses `Yog.Utils.map_fold/3` for high-performance iteration.
- `Yog.Transform.ego_graph/4` - Returns the ego graph of a node (the subgraph induced by the node and all nodes within `radius` hops).
  - Supports configurable `:mode` option for directed graphs: `:successors` (default, follows outgoing edges) and `:neighbors` (follows both directions).

#### Pathfinding
- `Yog.Pathfinding.LCA` - Efficient Lowest Common Ancestor (LCA) implementation using binary lifting.
  - `preprocess/1` - Precomputes binary lifting tables and depths in $O(V \log V)$.
  - `lca/3` - Queries the lowest common ancestor of two nodes in $O(\log V)$.

#### Property & Structure
- Graph Coloring Suite in `Yog.Property.Coloring`:
  - `coloring_greedy/1` — Welsh-Powell greedy coloring (O(V²)).
  - `coloring_dsatur/1` — DSatur heuristic, usually better than greedy.
  - `coloring_exact/2` — Backtracking exact coloring with optional timeout, finding the chromatic number for small graphs.
- Exact Planarity Suite in `Yog.Property.Structure`:
  - `planar?/1` - Robust, exact planarity testing using the LR-test algorithm (O(V²) implementation).
  - `planar_embedding/1` - Extracts a combinatorial embedding (clockwise cyclic adjacency lists) for planar graphs.
  - `kuratowski_witness/1` - Identifies a minimal non-planar subgraph witness (subdivision of $K_5$ or $K_{3,3}$).
- `Yog.Property.forest?/1` - Predicate for undirected cycle-free disjoint trees.
- `Yog.Property.branching?/1` - Predicate for directed forests (acyclic with in-degree ≤ 1).
- `Yog.Property.isomorphic?/2` - Fast topological equality checking using Weisfeiler-Lehman.
- `Yog.Property.hash/2` - Structural graph hashing.

#### Network Flow
* `Yog.Flow.MaxFlow.dinic/3` - Dinic's algorithm for maximum flow.

#### Matching
* `Yog.Matching.hopcroft_karp/1` - Hopcroft-Karp algorithm for maximum cardinality matching in bipartite graphs.
  - O(E√V) time complexity via BFS layering and DFS augmentation.
  - Returns a bidirectional map for easy partner lookup.
  - Raises `ArgumentError` if the graph is not bipartite.

#### Approximation Algorithms
* `Yog.Approximate.treewidth_upper_bound/2` — Min-degree and min-fill heuristic upper bounds for treewidth.
* `Yog.Approximate.tree_decomposition/2` — Builds a valid tree decomposition from an elimination ordering.
* `Yog.Approximate` - New module providing fast approximation algorithms for expensive graph properties:
  - `diameter/2` - Multi-sweep BFS/Dijkstra lower-bound estimation.
  - `betweenness/2` - Sampled Brandes algorithm for approximate betweenness centrality.
  - `average_path_length/2` - Pivot sampling for approximate mean shortest-path distance.
  - `global_efficiency/2` - Pivot sampling for approximate global efficiency.
  - `transitivity/2` - Wedge sampling for approximate clustering coefficient.
  - `vertex_cover/1` - Greedy 2-approximation for minimum vertex cover.
  - `max_clique/1` - Greedy degree-ordering heuristic for large cliques.

#### Classic Graph Generators
- **Lollipop Graph** (`Yog.Generator.Classic.lollipop/2`): $K_m$ connected to $P_n$ — extremal example for random walks.
- **Barbell Graph** (`Yog.Generator.Classic.barbell/2`): Two $K_{m1}$ cliques joined by a path of $m2$ nodes.
- **Sedgewick Maze** (`Yog.Generator.Classic.sedgewick_maze/0`): Small 8-node maze with a cycle from Sedgewick's *Algorithms*.
- **Tutte Graph** (`Yog.Generator.Classic.tutte/0`): 46-vertex cubic non-Hamiltonian polyhedral graph.

#### I/O
- **`Yog.IO.Graph6`**: Read and write graphs in the compact graph6 format.
  - `parse/1` - Parse a graph6 string into a `Yog.Graph`.
  - `read/1` - Read a graph6 file.
  - `write/2` - Write one or more graphs to a graph6 file.
- **`Yog.IO.Sparse6`**: Read and write graphs in the sparse6 format for space-efficient storage of sparse graphs.
  - `parse/1` - Parse a sparse6 string into a `Yog.Graph`.
  - `read/1` - Read a sparse6 file.
  - `write/2` - Write one or more graphs to a sparse6 file.

### Optimized

#### Performance & Memory
- **Yen's Algorithm**: 
  - Reduced memory pressure by swapping `Enum.take/2` for `List.starts_with?/2` during path prefix validation.
  - Optimized target node propagation and fixed `PairingHeap` comparator binding for custom weights.
- **HITS Centrality**:
  - Reduced iteration complexity from $O(V \log V)$ to $O(V)$ by utilizing pre-computed flat adjacency lists.
  - Standardized convergence check to use L2 norm in line with metric documentation.
- **Health Metrics**:
  - Optimized `average_local_efficiency/2` by performing graph reweighting once ($O(V)$) instead of per-node ($O(V^2)$).
  - Added `safe_inverse` handling to prevent division errors in disconnected topologies.

## 0.96.0 - 2026-04-12

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
- **Yen's K-Shortest Paths** (#88): Added `Yog.Pathfinding.Yen.k_shortest_paths/5` - finds the k shortest loopless paths between two nodes.
  - Natural extension of Dijkstra for backup routing, logistics, and network design
  - Time Complexity: O(k · N · (E + V log V))
  - Supports weighted directed and undirected graphs with custom weight functions
  - Returns `{:ok, [%Path{}, ...]}` sorted by total weight, or `:error` if no path exists
- **Widest Path (Maximum Capacity Path)** (#95): Added `Yog.Pathfinding.widest_path/3` - finds the path with maximum bottleneck capacity between two nodes.
  - Maximizes the minimum edge weight along the path (the bottleneck)
  - Algorithm: Modified Dijkstra with `min` for capacity combination and `Yog.Utils.compare_desc/2` for priority
  - Returns `{:ok, %Path{}}` with `algorithm: :widest_path` and the bottleneck capacity as `weight`
  - Returns `:error` when no path exists between the nodes
- **Maximum Spanning Tree**: Added `Yog.MST.maximum_spanning_tree/2`, `kruskal_max/2`, and `prim_max/2` - connects all nodes with maximum total edge weight.
  - Useful for finding all-pairs widest paths and network reliability problems
  - Implemented as variations of Kruskal's and Prim's algorithms using descending edge weight sorting
- **Borůvka's Algorithm**: Added `Yog.MST.boruvka/2` - the oldest MST algorithm, efficient for parallelization.
  - Works by repeatedly finding the cheapest edge connecting each component to another component
  - **Time Complexity:** O(E log V) - efficient for large sparse graphs
  - Particularly useful for distributed/parallel MST computation
- **Single-Pair Shortest Path (Unweighted)**: Added `Yog.Pathfinding.shortest_path_unweighted/3` - finds the shortest path between two nodes in unweighted graphs using BFS with early termination. More efficient than Dijkstra for unweighted graphs (no heap overhead) and uses predecessor map for memory-efficient path reconstruction instead of storing full paths in the queue.
  - Returns `{:ok, [node_id]}` with the path from source to target
  - Returns `{:error, :no_path}` when target is unreachable
  - Validates source/target existence before searching
  - Works with both directed and undirected graphs

#### Community Metrics
- **Transitivity (Global Clustering Coefficient)** (#89): Added `Yog.Community.Metrics.transitivity/1` - measures the ratio of triangles to connected triples in the graph.
  - Formula: T = 3 × triangles / connected_triples
  - Range: [0.0, 1.0]; 1.0 means every connected triple is closed (graph is union of disjoint cliques)
  - Differs from average clustering coefficient - transitivity is weighted by node degree
  - Returns 0.0 for graphs with no connected triples (e.g., trees, paths)

#### Centrality
- **HITS Algorithm** (#94): Added `Yog.Centrality.hits/2` — Hyperlink-Induced Topic Search for hub and authority scores in directed graphs.
  - Returns `%{hubs: %{...}, authorities: %{...}}` with L2-normalized scores
  - Converges via iterative power method with configurable `max_iterations` and `tolerance`
  - Supports both directed and undirected graphs

#### Health Metrics
- **Network Efficiency** (Latora-Marchiori): Added efficiency metrics to `Yog.Health`:
  - `efficiency/4` - Pairwise efficiency between two nodes (1/distance, 0.0 if unreachable).
  - `global_efficiency/2` - Average efficiency over all ordered pairs of distinct nodes.
    - Well-defined for disconnected graphs (unreachable pairs contribute 0.0 instead of `nil`).
    - Parallelized via `Task.async_stream`.
  - `local_efficiency/3` - Global efficiency of the subgraph induced by a node's neighbors.
  - `average_local_efficiency/2` - Mean local efficiency across all nodes.

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
