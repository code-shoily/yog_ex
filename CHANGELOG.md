# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **`Yog.Community.Walktrap.detect/1`** — Now selects the modularity-maximizing level from the dendrogram instead of the trivial all-merged level. The default partition is meaningful for typical graphs.
- **`Yog.Multi.Model.degree/2`, `out_degree/2`, `in_degree/2`** — Now correctly count undirected self-loops as contributing 2 to a node's degree (matching standard graph theory). This also fixes false-negative Eulerian path/circuit detection on undirected multigraphs containing self-loops.
- **`Yog.Multi.Eulerian.has_eulerian_circuit?/1`, `has_eulerian_path?/1`, `find_eulerian_circuit/1`, `find_eulerian_path/1`** — Now correctly tolerate isolated nodes (nodes with zero degree). Connectivity is checked over non-isolated nodes only, and start-node selection skips isolated nodes, matching standard Eulerian theory and NetworkX's behavior.
- **`Yog.Community.Louvain.detect/1`** — Now runs full hierarchical Louvain (phase 1 + aggregation + recursion) instead of phase 1 only. The returned partition may differ from previous versions on graphs without strong community structure (e.g., scale-free networks) — both partitions are valid modularity local optima but the new one is the standard Louvain output.
- **`Yog.Community.Louvain.detect_hierarchical/1`** — Now stores raw community IDs at each level so that the dendrogram can be correctly flattened back to original node IDs. See `Yog.Community.Dendrogram.flatten_to_original/1`.

### Added

- **`Yog.Community.Dendrogram.flatten_to_original/1`** — Folds per-level assignment maps into a single `Result.t()` over original-graph node ids.

## [0.98.2] - 2026-06-06

### Added

- **`Yog.Builder.Labeled.get_label/2` & `Yog.Builder.Live.get_label/2`** — Added reverse registry lookup to query the label of a given node ID.
- **`Yog.Builder.Live.add_node/2`** — Added support for registering standalone nodes during incremental live graph building.
- **`Yog.Approximate.closeness/2`** — Implemented closeness centrality approximation using Eppstein-Wang pivot sampling on the transposed graph.
- **`Yog.Approximate.harmonic/2`** — Implemented harmonic centrality approximation using Eppstein-Wang pivot sampling on the transposed graph.
- **`Yog.Operation.tensor_product/2`, `Yog.Operation.strong_product/4`, & `Yog.Operation.lexicographic_product/4`** — Added three standard graph product operations with optimized private helpers and performance complexity warning alerts.
- **`Yog.Operation` Property-Based Tests** — Added recursive mathematical invariants and edge/node count verification checks for all newly implemented graph products to the PBT suite.
- **`Yog.Transform.add_self_loops/2` & `Yog.Transform.remove_self_loops/1`** — Added convenience functions for managing self-loops in graphs, along with delegations in `Yog.add_self_loops/2` and `Yog.remove_self_loops/1`.
- **`Yog.PairingHeap.merge/2`** — Exposed the $O(1)$ priority queue merge operation as a public API.
- **`Yog.PairingHeap` Inspect Protocol** — Implemented the `Inspect` protocol for pairing heaps (`%Yog.PairingHeap.Node{}` and `%Yog.PairingHeap.Empty{}`), showing size and peek elements cleanly.
- **`Yog.Operation` Performance Warnings** — Added warning docstrings to potentially slow and scale-sensitive operations (`cartesian_product/4`, `line_graph/2`, `power/3`, and `isomorphic?/2`) to detail growth, space/time complexities, and caution users on large graphs.


### Changed

- **`Yog.Approximate` & `Yog.Health` Option Documentation** — Normalized `:to_float` documentation to match the parsed `:with_to_float` option key.
- **`Yog.Health` & `Yog.Approximate` Option Parsing** — DRYed up option parsing by sharing the internal `parse_metric_opts/1` helper.
- **`Yog.Builder.Grid` & `Yog.Builder.Toroidal`** — Extracted `add_grid_edge/5` helper to comply with Credo nesting rules and avoid deep function nesting.

- **`Yog.Utils` Optimizations** — Refactored `norm_diff/3` to be completely allocation-free by using direct map folds, eliminating intermediate key list concatenations and temporary map allocations.
- **`Yog.Transform` Optimizations** — Overhauled multiple transformer functions to eliminate dynamic protocol dispatch and intermediate list/tuple allocations during graph folding:
  - **`complement/2`**: Fetches the source node's out-edges once outside the inner loop (saving $O(V^2)$ lookups) and utilizes `List.foldl/3` / `Utils.map_fold/3`.
  - **`to_undirected/2`**: Replaced list-comprehension based reduction with nested `Utils.map_fold/3` loops.
  - **`relabel_nodes/2`**: Folds over nodes and out-edges directly via `Utils.map_fold/3`, avoiding full edge list allocations (`Model.all_edges/1`).
  - **`transitive_closure/1` & `redirect_neighbors/5`**: Updated to fold over adjacency and reachability maps using `Utils.map_fold/3` in-place.
- **`Yog.Operation` Optimizations** — Upgraded several core graph join and product builders to completely bypass dynamic enumerable dispatch and intermediate lists:
  - **`symmetric_difference/2`**: Rewritten as a single-pass edge collection on the symmetric difference of nodes, completely removing three intermediate subgraph copy and union allocations.
  - **`isomorphic?/2` (`mapping_valid?/5`)**: Replaced linear-time list search checks (`s in Map.keys(...)`) with $O(1)$ constant-time `Map.has_key?/2` lookups.
  - **`disjoint_union/2`**: Avoids flat-mapping/rebuilding intermediate edge lists by folding over out-edges directly via `Utils.map_fold/3`.
  - **`cartesian_product/4`**: Rewrote vertical, horizontal, and node product helpers to fold with `Utils.map_fold/3` and `List.foldl/3` instead of nested `Enum.reduce/3` on maps.
  - **`line_graph/2`**: Optimized unique undirected edge extraction to filter in $O(E)$ during fold, eliminating expensive `Enum.uniq_by/2` and `Enum.map/2` stages. Bypassed enumerable reduction in edge-incident traversals.
  - **`power/3`**: Refactored distance closure iterations to utilize fast `List.foldl/3` on lists.

- **`Yog.PairingHeap`** — Optimized the internal `combine` helper to bypass creating `%Empty{}` structs when matching even number of children (size $\ge 2$), reducing allocation overhead during restructuring.
- **`Yog.Model.add_node/3`** — Defaulted the `data` parameter to `nil`, allowing nodes to be added to graphs and multigraphs without a data payload (e.g., `Yog.add_node(graph, id)`). Updated delegations in `Yog.add_node/3` and `Yog.Multi.add_node/3`.
- **`Yog.DisjointSet`** — Optimized `find/2` and `find_root_readonly/2` to eliminate redundant struct allocations during recursion. `find_root_readonly/2` now operates directly on the `parents` map.

### Fixed

- **`Yog.Centrality.pagerank/2`** — Fixed `ArithmeticError` (division by zero) crash on empty and single-node graphs.
- **`Yog.Health.average_path_length/2`** — Added $O(V+E)$ connectivity fast-path check to avoid running parallel Dijkstra computations on disconnected graphs.
- **`Yog.Health.eccentricity/3`** — Replaced linear key list sizing checks with constant-time `$O(1)$` BIF `map_size/1`.
- **`Yog.Builder.Grid` & `Yog.Builder.Toroidal` Nil-cell Handling** — Replaced direct `to_data != nil` checks with `Model.has_node?/2` to support jagged grids while correctly handling nodes with `nil` payloads.
- **`Yog.Builder.Grid` & `Yog.Builder.Toroidal` Connection Topology** — Added `detect_topology/1` to dynamically identify and populate connection topology instead of always hardcoding `:rook`.
- **Property Tests** — Resolved flaky `StreamData.TooManyDuplicatesError` failures in `Yog.PBT.FlowTest` and `Yog.PBT.PathfindingTest` properties by pattern-matching directly on the generated node list to obtain distinct source/target nodes, instead of using `uniq_list_of/2` on `StreamData.member_of/1`.

## [0.98.1] - 2026-05-23

### Added

#### Multigraph Collapse Helpers

- **`Yog.Multi.Model.to_simple_graph_max_edges/1`** — New helper that collapses parallel edges keeping the maximum weight. Useful for widest-path and bottleneck algorithms.
- **`Yog.Multi.Model.to_simple_graph_sum_edges/1`** — New zero-argument helper that sums parallel edge weights using `&Kernel.+/2`. Complements the existing `to_simple_graph_sum_edges/2` which accepts a custom combine function.
- **`Yog.Multi`** — Added facade delegations for `to_simple_graph_max_edges/1` and `to_simple_graph_sum_edges/1`.

#### Documentation

- **`ALGORITHMS.md`** — Comprehensive audit and update:
  - Added missing algorithms: Brandes SSSP, Chinese Postman, Path Utilities, Distance Matrix, Hungarian matching, Blossom matching, Graph Coloring, Tree Decomposition, and maze generators (Kruskal's, Prim's simplified/true, Eller's, Growing Tree, Recursive Division).
  - Added missing categories: Random Graph Generation, Graph Builders, Functional Graphs (FGL-style), and Rendering.
  - Fixed incorrect module names: `Yog.PriorityQueue` → `Yog.PairingHeap`, `Yog.Connectivity.Bridge` / `Articulation` → `Yog.Connectivity.Analysis`.
  - Removed ghost algorithms: Capacity Scaling, Network Simplex.
  - Removed duplicate `Dinic's` entry in Flow & Cuts.
  - Moved maze generation algorithms out of Approximation Algorithms into Maze Generation.

### Fixed

- **`Yog.Multi.Model.to_simple_graph/1`** — Now deterministic. Edges are sorted by `edge_id` before collapsing, guaranteeing that the earliest-added edge is always kept. Previously, iteration order over the `edges` map was undefined, making the result non-deterministic.

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

#### Generators

- **`Yog.Generator.Classic`** — Added missing `_with_type` variant:
  - `prism_with_type/2` — Generate a prism (circular ladder) graph with a specified graph type.

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
- **Maze generator RNG state isolation** — All maze algorithms (`binary_tree/3`, `sidewinder/3`, `recursive_backtracker/3`, `hunt_and_kill/3`, `aldous_broder/3`, `wilson/3`, `kruskal/3`, `prim_simplified/3`, `prim_true/3`, `ellers/3`, `growing_tree/3`, `recursive_division/3`) now restore the global `:rand` state after seeding, matching the behavior of `Yog.Generator.Random`. Previously, passing `:seed` permanently altered the global RNG state.
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

