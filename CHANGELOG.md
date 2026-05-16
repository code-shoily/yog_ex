# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.98.0] - 2026-05-16

### Added

#### Builder Modules

- **`Yog.Builder.Labeled`** — Added convenience query functions:
  - `has_label?/2` — Check if a label is registered.
  - `has_edge?/3` — Check if an edge exists between two labels.
  - `node_count/1` — Number of registered nodes.
  - `edge_count/1` — Number of edges in the underlying graph.
- **`Yog.Builder.Live`** — Added `has_label?/2` for registry membership checks.

#### DAG Modules

- **`Yog.DAG`** — Filled facade gaps and added DAG-native algorithms. The DAG modules are now feature-complete:
  - **Query functions**: `has_node?/2`, `has_edge?/3`, `node_count/1`, `edge_count/1`, `nodes/1`, `successors/2`, `predecessors/2`, `in_degree/2`, `out_degree/2`, `reachable?/3`.
  - **Convenience constructors**: `from_edges/1` and `from_edges/2` — create a DAG directly from edge tuples without manually building a `Yog.Graph` first.
  - **`Yog.DAG.Algorithm.sources/1`** — Returns all source nodes (in-degree 0).
  - **`Yog.DAG.Algorithm.sinks/1`** — Returns all sink nodes (out-degree 0).
  - **`Yog.DAG.Algorithm.ancestors/2`** — Returns all ancestors of a node (includes the node itself).
  - **`Yog.DAG.Algorithm.descendants/2`** — Returns all descendants of a node (includes the node itself).
  - **`Yog.DAG.Algorithm.single_source_distances/2`** — O(V+E) single-source shortest distances (faster than Dijkstra for DAGs).
  - **`Yog.DAG.Algorithm.longest_path/3`** — Longest path between two specific nodes.
  - **`Yog.DAG.Algorithm.path_count/3`** — Counts distinct paths between two nodes via DP.
  - **Safety fix**: `topological_sort/1` now raises `RuntimeError` if a cycle is somehow detected, instead of silently returning `[]`.

#### Multigraph Facade

- **`Yog.Multi`** — Filled facade gaps and added multigraph-native algorithms:
  - `has_edge/2` — Check if a specific `edge_id` exists.
  - `edge_count/3` — Count parallel edges between a node pair.
  - `degree/2` — Total degree (in + out for directed, out-degree for undirected).
  - `has_cycle?/1` — Detect cycles without manual collapsing.
  - `topological_sort/1` — Returns `{:ok, [node_id]}` or `{:error, :contains_cycle}`.
  - `to_simple_graph/1` — Collapse keeping only the first edge between each pair.
  - `to_simple_graph_min_edges/1` — Collapse parallel edges keeping the minimum weight.
  - `to_simple_graph_sum_edges/2` — Collapse parallel edges summing weights via a custom function.

#### Rendering

- **`Yog.Multi.Mermaid`** — New Mermaid.js renderer for multigraphs (`Yog.Multi.Graph`).
  - Supports parallel edges between the same pair of nodes.
  - `edge_id`-based callbacks (`edge_label/2`, `edge_attributes/4`) for per-edge customization.
  - Highlighting by `edge_id` or `{from, to}` tuple.
  - Subgraphs, per-node styling, and all node shapes/directions.
  - `theme/1` with `:default`, `:dark`, `:minimal`, `:presentation` presets.
  - Algorithm helpers: `path_to_options/2`, `mst_to_options/2`, `community_to_options/2`, `cut_to_options/2`, `matching_to_options/2`.
  - `default_options_with_edge_formatter/1`, `default_options_with/1`, `default_options_without_labels/0`.
- **`Yog.Multi.DOT`** — Feature parity with `Yog.Render.DOT`:
  - `theme/1` with all presets.
  - Algorithm helpers: `path_to_options/2`, `mst_to_options/2`, `community_to_options/2`, `cut_to_options/2`, `matching_to_options/2`.
  - `default_options_with_edge_formatter/1`, `default_options_with/1`, `default_options_without_labels/0`.
- **`Yog.Render.Mermaid` parity with `Yog.Render.DOT`**:
  - `node_attributes/2` callback for per-node inline styling (`style node_id fill:...,stroke:...`).
  - `edge_attributes/3` callback for per-edge styling via `linkStyle index ...`.
  - `subgraphs` option for Mermaid `subgraph ... end` blocks.
  - `theme/1` — Presets: `:default`, `:dark`, `:minimal`, `:presentation`.
  - `mst_to_options/2`, `community_to_options/2`, `cut_to_options/2`, `matching_to_options/2`.
  - `default_options_with_edge_formatter/1` and `default_options_with/1`.
  - Internal `MapSet` conversion for O(1) highlight membership checks.
- **`Yog.Utils`** — Extracted shared rendering helpers to eliminate Credo duplication:
  - `generate_palette/1`, `hsl_to_hex/3`, `mst_highlights/1`, `matching_highlights/1`, `path_to_edges/1`.

### Fixed

- **Mermaid themes** now apply globally to all nodes/edges via `classDef default` and `linkStyle` (previously only affected highlighted elements).
- **Mermaid dark mode readability** — Added `default_font_color` option for white text on dark backgrounds.
- **Mermaid undirected edge labels** — Fixed invalid `---|1|` syntax to correct `-- 1 ---`.
- **Mermaid per-node shapes** — `node_shape` now accepts `(id, data) -> shape` function in addition to atom values.
- Credo alias warnings in `Yog.Multi.Mermaid`.
- Removed accidental `IO.puts` debug output from `test/yog/multi/dot_test.exs`.

#### Builders

- **`Yog.Builder.Live.sync_multi/2`** — New function to sync pending changes to a multigraph (`Yog.Multi.Graph`).
  - `add_edge` creates parallel edges rather than overwriting existing ones.
  - `remove_edge` removes all parallel edges between the given node pair.
  - Supports incremental sync, unweighted/simple edges, node removal, and both directed/undirected multigraphs.

#### Documentation & Livebooks

- **All 11 livebooks reviewed and improved** with better content and code coverage:
  - **`gallery/graph_catalog`** — Added Mermaid rendering, property checks (regularity, connectivity, diameter, girth), hypercube and binary tree generators.
  - **`guides/getting_started`** — Added `Yog.Builder.Live` example, community detection, Mermaid export, and more query examples.
  - **`guides/dag_analysis`** — Added cycle detection, transitive reduction with visualization, Mermaid rendering, and `Yog.acyclic?/1`.
  - **`guides/graph_properties`** — Fixed coloring visualization (now actually applies colors to DOT), added DSatur comparison, exact coloring, K3,3 planarity, and planar embedding.
  - **`guides/network_analysis`** — Fixed community detection API (`.assignments` instead of `.communities`), added degree/closeness centrality, articulation point/bridge visualization with per-element styling.
  - **`guides/network_flow`** — Added global min-cut (Stoer-Wagner), fixed bipartite matching example, removed broken min-cost max-flow placeholder.
  - **`guides/traversals_and_pathfinding`** — Added Bellman-Ford with negative weights, real A* grid example using `Yog.Builder.GridGraph`, Johnson's mention.
  - **`how_to/customizing_visualizations`** — Fixed old API usage (`node_attributes` as function, not keyword list), added Mermaid themes, per-node/edge styling, subgraphs, and algorithm helpers (`path_to_options`, `mst_to_options`, `community_to_options`, `cut_to_options`).
  - **`how_to/import_export`** — Added Graph6 and GDF format coverage.
  - **`how_to/maze_generation`** — Added Wilson's algorithm demonstration, algorithm property comparison table, path length analysis across algorithms.
  - **`how_to/multigraphs_and_collapsing`** — Added multigraph visualization (`Yog.Multi.DOT` and `Yog.Multi.Mermaid`), `Yog.Builder.Live.sync_multi/2` example, per-edge styled rendering, Eulerian circuits on multigraphs, BFS/DFS traversals.

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
