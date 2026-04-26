# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.97.1] - 2026-04-18

### Changed

- **Multigraph architecture unified**: `Yog.Multi.Graph` is now the single canonical multigraph struct (previously there were two incompatible structs: `Yog.Multi.Graph` and `Yog.Multi.Model.Graph`).
  - `Yog.Multi.Graph` defines the struct and implements `Enumerable` and `Inspect` protocols.
  - `Yog.Multi.Model` holds all operations (`add_node/3`, `add_edge/4`, `remove_node/2`, `successors/2`, `predecessors/2`, etc.) acting on `Yog.Multi.Graph`.
  - `Yog.Multi.DOT` now correctly renders graphs built via the `Yog.Multi` facade.
  - `Yog.IO.GEXF.Multi` and `Yog.IO.Libgraph` updated to pattern-match on `%Yog.Multi.Graph{}`.

## [0.97.0] - 2026-04-18

> **Note**: No more breaking changes. The focus will be on performance, documentation, and bug fixes in preparation for 1.0.0 in early 2027.

### Added

#### Core API
- `Yog.Model.add_nodes_from/2`, `Yog.add_nodes_from/2` — Add multiple nodes from an iterable (list of IDs, `{id, data}` tuples, a map, or another `Yog.Graph`).
- `Yog.from_nodes/2` — Create a new graph from a list of nodes.

#### DAG Algorithms
- `Yog.DAG.topological_generations/1` — Returns topological generations (layers) of a DAG in **O(V + E)** via propagating waitlist.

#### Transformations
- `Yog.Transform.quotient_graph/4` — Quotient graph from a partition map. Optional `combine_data` for deterministic payload aggregation. Optimized memory via `Yog.Utils.map_fold/3`.
- `Yog.Transform.ego_graph/4` — Ego graph within a given radius. Supports `:successors` and `:neighbors` modes for directed graphs.

#### Pathfinding
- `Yog.Pathfinding.chinese_postman/1` — Chinese Postman Problem for undirected graphs via odd-vertex matching + Eulerian circuit.
- `Yog.Pathfinding.LCA` — Lowest Common Ancestor via binary lifting (**O(V log V)** preprocess, **O(log V)** query).

#### Property & Structure
- `Yog.Property.Coloring` suite:
  - `coloring_greedy/1` — Welsh-Powell (**O(V²)**).
  - `coloring_dsatur/1` — DSatur heuristic.
  - `coloring_exact/2` — Backtracking exact coloring with optional timeout.
- `Yog.Property.Structure` planarity suite:
  - `planar?/1` — Exact LR-test (**O(V²)**).
  - `planar_embedding/1` — Combinatorial embedding.
  - `kuratowski_witness/1` — Minimal non-planar subgraph witness.
- `Yog.Property.forest?/1`, `branching?/1`, `isomorphic?/2`, `hash/2`.

#### Network Flow
- `Yog.Flow.MaxFlow.dinic/3` — Dinic's max-flow algorithm.
- `Yog.Flow.MinCut.gomory_hu_tree/1` — All-pairs min-cut tree via **V - 1** max-flow computations.
- `Yog.Flow.MinCut.min_cut_query/3` — Query min-cut value/partitions from a Gomory-Hu tree.
- `Yog.Flow.MinCut.karger_stein/2` — Randomized fast-cut with configurable iterations.
- `Yog.Flow.MinCut.global_min_cut/2` — Added `track_partitions: true` option (Stoer-Wagner).
- `Yog.Flow.MinCut.s_t_min_cut/3` — Wrapper for `:edmonds_karp`, `:dinic`, `:push_relabel`.
- `Yog.Flow.MinCutResult` — Extended with optional `source_side` / `sink_side` fields.
- `Yog.Flow.MaxFlow.min_cut/3` — Populates `source_side` / `sink_side` in result.

#### Matching
- `Yog.Matching.hopcroft_karp/1` — Maximum cardinality bipartite matching (**O(E√V)**). Bidirectional map return.
- `Yog.Matching.hungarian/2` — Weighted bipartite matching (**O(V³)**). Supports `:min`/`:max` optimization and rectangular partitions.

#### Rendering
- `Yog.Render.DOT.theme/1` — Presets: `:dark`, `:minimal`, `:presentation`.
- `Yog.Render.DOT` rank constraints via `ranks` option (`:same`, `:min`, `:max`, `:source`, `:sink`).
- `Yog.Render.DOT.mst_to_options/2`, `community_to_options/2`, `cut_to_options/2`, `matching_to_options/2`.

#### Approximation Algorithms
- `Yog.Approximate` module:
  - `treewidth_upper_bound/2`, `tree_decomposition/2`.
  - `diameter/2`, `betweenness/2`, `average_path_length/2`, `global_efficiency/2`, `transitivity/2`.
  - `vertex_cover/1`, `max_clique/1`.

#### Classic Graph Generators
- `Yog.Generator.Classic` additions:
  - `lollipop/2`, `barbell/2`, `sedgewick_maze/0`, `tutte/0`.

#### I/O
- `Yog.IO.Graph6` — Read/write graph6 format.
- `Yog.IO.Sparse6` — Read/write sparse6 format.
- `Yog.IO.GEXF` — GEXF serialization/deserialization (Gephi-compatible) with Saxy streaming + xmerl fallback.
- `Yog.IO.GEXF.Multi` — Multigraph GEXF support with parallel edge preservation.

### Fixed
- **Universal Safe Labeling**: Fixed `Protocol.UndefinedError` when rendering graphs with map metadata.
  - Added `Yog.Utils.to_label/2` and `to_weight_label/1`.
  - Updated `Mermaid`, `DOT`, `GraphML`, `GDF`, `Pajek`, `TGF`, `LEDA`, `MatrixMarket`, and `List` modules.

### Optimized
- **Yen's Algorithm**: Reduced memory pressure via `List.starts_with?/2` for path prefix validation. Fixed `PairingHeap` comparator binding.
- **HITS Centrality**: Reduced iteration from **O(V log V)** to **O(V)** via pre-computed flat adjacency lists.
- **Health Metrics**: `average_local_efficiency/2` reweights once (**O(V)**) instead of per-node (**O(V²)**).

## [0.96.0] - 2026-04-12

### Added

#### Classic Graph Generators
- **Platonic Solids** (#102): `tetrahedron/0`, `cube/0`, `octahedron/0`, `dodecahedron/0`, `icosahedron/0`.
- **General Trees** (#103): `kary_tree/2`, `complete_kary/2`, `caterpillar/2`.
- **Ladders** (#104): `circular_ladder/1` (prism), `mobius_ladder/1`, `prism/1`.
- **Friendship & Windmill** (#105): `friendship/1`, `windmill/2`, `book/1`.
- **Crown Graph** (#106): `crown/1`.
- **Maze Generators** (#120): `aldous_broder/3`, `wilson/3`, `kruskal/3`, `ellers/3`, `growing_tree/3`, `recursive_division/3`, `prim_simplified/3`, `prim_true/3`.

#### Random Graph Generators
- **Configuration Model** (#110): `configuration_model/2`, `randomize_degree_sequence/2`, `power_law_graph/2`.
- **Kronecker Graphs** (#109): `kronecker/3`, `rmat/7`, `kronecker_general/3`.
- **Geometric Graphs** (#107): `geometric/2`, `geometric_nd/2`, `waxman/2`.

#### Pathfinding
- **Yen's K-Shortest Paths** (#88): `Yog.Pathfinding.Yen.k_shortest_paths/5` — **O(k · N · (E + V log V))**.
- **Widest Path** (#95): `Yog.Pathfinding.widest_path/3` — Modified Dijkstra maximizing bottleneck capacity.
- **Maximum Spanning Tree**: `Yog.MST.maximum_spanning_tree/2`, `kruskal_max/2`, `prim_max/2`.
- **Borůvka's Algorithm**: `Yog.MST.boruvka/2` — **O(E log V)**, efficient for parallelization.
- **Unweighted Shortest Path**: `Yog.Pathfinding.shortest_path_unweighted/3` — BFS with early termination.

#### Community Metrics
- **Transitivity** (#89): `Yog.Community.Metrics.transitivity/1` — Global clustering coefficient.

#### Centrality
- **HITS** (#94): `Yog.Centrality.hits/2` — Hub/authority scores via power method.

#### Health Metrics
- **Network Efficiency**: `global_efficiency/2`, `local_efficiency/3`, `average_local_efficiency/2`.
  - Well-defined for disconnected graphs (unreachable pairs contribute 0.0).
  - Parallelized via `Task.async_stream`.

#### Other
- Johnson's algorithm added to Matrix auto-selection for sparse graphs with many POIs.

### Changed
- **Dijkstra**: Delegates `shortest_path/6` and `implicit_dijkstra/6` to `AStar` with zero heuristic.
- **Bellman-Ford**: Early termination when no distances change. **13-24x faster** on typical graphs.
- **Bidirectional BFS**: O(1) queue size tracking; uses `:queue` module.
- **Johnson's**: Early termination in Bellman-Ford phase.
- **Bidirectional Dijkstra**: Proper two-queue implementation with meeting point detection.

### Breaking
- Removed `Yog.Pathfinding.Utils`. Merged into `Yog.Pathfinding.Path`:
  - `Utils.path/2` → `Path.new/2`
  - `Utils.nodes/1` → `path.nodes`
  - `Utils.total_weight/1` → `path.weight`

## [0.95.0] - 2026-04-04

### Added
- `Yog.Pathfinding.all_pair_shortest_path_unweighted/1` — BFS-based APSP for unweighted graphs.
- `Yog.Operation.line_graph/2` — Line graph / line digraph construction.
- `Yog.IO.Libgraph` — Bidirectional conversion with the `libgraph` library.

### Changed
- **Priority Queue Restructure**: Split into `Yog.PairingHeap` (O(1) push) and `Yog.BalancedTree` (O(log n) both).
- **Generators**: Added `Yog.Generator.Random.sbm/5`, `sbm_with_labels/5` (Stochastic Block Model).
- **MST Result**: `kruskal/2` and `prim/2` now return `{:ok, %Yog.MST.Result{}}`.
- **Prim**: Added `:from` option for starting node.
- **Renamed**: `Yog.Flow.NetworkSimplex` → `Yog.Flow.SuccessiveShortestPath`.
- **Successive Shortest Path**: Uses Dijkstra with potentials instead of Bellman-Ford per iteration. Improved from **O(F · V · E)** to **O(F · (E + V log V))**.
- **Contract**: Major performance optimization via direct map surgery instead of per-edge `add_edge_with_combine`.
- **MinCut**: Complete rewrite of Stoer-Wagner.
  - Eliminated O(V) `total_nodes` recomputation.
  - Replaced `MapSet` partition tracking with O(1) integer counts.
  - `MinCutResult` struct: `source_side`/`sink_side` MapSets → `source_side_size`/`sink_side_size` integers.

### Breaking
- Removed `Yog.Traversal.Cycle`. Use `Yog.Property.Cyclicity`.
- `Yog.Flow.MinCutResult` struct fields changed (MapSets → integer counts).

## [0.90.0] - 2026-03-30

### Added
- `Yog.Flow.MaxFlow`: Refactored residual storage to nested map (30-50% faster Edmonds-Karp).
- `Yog.Connectivity.shell_decomposition/1` — k-shell grouping.
- `Yog.Functional` enhancements:
  - `preorder/2`, `postorder/2`, `reachable/2`.
  - `transitive_closure/1`, `biconnected_components/1`, `dominators/2`.
  - `distances/2`.
  - `from_adjacency_graph/1`, `to_adjacency_graph/1`.
- `Yog.Property`: `connected?/1`, `planar?/1`, `chordal?/1`.

### Changed
- **MaxFlow**: Replaced recursive BFS with `Yog.Traversal.Implicit.implicit_fold/1`.
- **KCore**: "Lazy deletion" preserving **O(V + E)** complexity.
- **Builder API**: Removed legacy tuple-based builders. All strictly struct-based.
- Moved `transitive_closure/1`, `transitive_reduction/1` to `Yog.Transform`; `count_reachability/2` to `Yog.Connectivity.reachability_counts/2`.
- **Traversal**: Added `:best_first` and `:random` orders; `Yog.Traversal.Walk.random_walk/3`.

### Breaking
- Removed `Yog.Model.add_edge_ensured/5`.
- Removed `transitive_closure/1`, `transitive_reduction/1`, `count_reachability/2` from `Yog.DAG.Algorithm`.

## [0.80.0] - 2026-03-27

### Added
- **Pure Elixir Implementation**: Complete migration from Gleam wrapper.
  - All 58 modules in pure Elixir; zero Gleam dependencies.
  - Installation: `{:yog_ex, "~> 0.60"}` only.

### Changed
- **Graph Structure**: Tuple `{:graph, kind, nodes, out_edges, in_edges}` → struct `%Yog.Graph{kind, nodes, out_edges, in_edges}`.
- **Priority Queue**: `Yog.PQ` (pairing heap) replaces sorted lists.
  - `lexicographical_topological_sort`: **O(V log V + E)** vs **O(V² + E)**.
  - `implicit_dijkstra`: **O(E log V)** vs **O(E × V)**.
- **Module Reorganization**:
  - `Yog.Pathfinding` facade removed.
  - `Yog.MaxFlow` → `Yog.Flow.MaxFlow`
  - `Yog.MinCut` → `Yog.Flow.MinCut`
  - `Yog.Render` → `Yog.Render.DOT`, `Yog.Render.Mermaid`, `Yog.Render.ASCII`
  - `Yog.Generators` → `Yog.Generator.Classic`, `Yog.Generator.Random`
  - `Yog.PQ` → `Yog.PriorityQueue`
- **API Updates**:
  - Pathfinding returns `%Yog.Pathfinding.Path{}` with `weight` field.
  - `edmonds_karp/8` compare function returns boolean.
  - `floyd_warshall/4` uses positional args.

## [0.70.0] - 2026-03-26

Various performance improvements and examples.

## [0.52.3] - 2026-03-22

### Fixed
- Removed `app: false` from `yog` dependency; added explicit Gleam deps.

## [0.52.2] - 2026-03-22

### Fixed
- Documentation builds correctly on HexDocs.

## [0.52.1] - 2026-03-22

### Changed
- All I/O modules now pure Elixir (`GraphML`, `GDF`, `Pajek`, `LEDA`, `TGF`, `JSON`).
- Removed `yog_io` dependency.

### Fixed
- Resolved dependency conflicts requiring manual `yog_io` configuration.

## [0.51.0] - 2026-03-22

### Added
- `Yog.Pathfinding` facade module (unified keyword-based API for Dijkstra, AStar, BellmanFord, FloydWarshall).
- `Yog.Connectivity` delegators: `connected_components/1`, `weakly_connected_components/1`.
- I/O integration via `yog_io`: `GDF`, `GraphML`, `JSON`, `LEDA`, `Pajek`, `TGF`.

### Changed
- Renamed `Yog.DAG.Models` → `Yog.DAG.Model`, `Yog.DAG.Algorithms` → `Yog.DAG.Algorithm`.
- Updated examples to use `add_edge!` for chaining.
- Updated `yog` to `~> 5.1`.
- `yog_io` is now an **optional dependency**.
