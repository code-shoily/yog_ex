# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## UNRELEASED

### Added

### Fixed

- **`Yog.Pathfinding.LCA` Audit** — Audited Lowest Common Ancestor tree processor for root/node existence, cycles, disconnected components, and single-node trees.
- **`Yog.Pathfinding.Matrix` Options & Node Validation** — Hardened distance matrix solver by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options) and filtering out points of interest that are not in the graph.
- **`Yog.Pathfinding.Path` Audit** — Audited path helper utilities and added unit tests for `empty?/1`, `length/1`, `start/1`, `finish/1`, `reverse/1`, `contains?/2`, and `at/2` for comprehensive test coverage.
- **`Yog.Pathfinding.ChinesePostman` Audit** — Audited Route Inspection solver for Eulerian, disconnected, empty, and single-node graphs.
- **`Yog.Pathfinding.Disjoint` Options & Node Validation** — Hardened Suurballe's disjoint path search by validating keyword list options in the pathfinding facade (raising `ArgumentError` for unknown options) and early-returning `:error` for missing source or target nodes in the graph.
- **`Yog.Pathfinding.Yen` Options & Node Validation** — Hardened Yen's k-shortest paths by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options) and early-returning `:error` for missing source or target nodes in the graph, resolving edge cases like empty and disconnected graphs.
- **`Yog.Pathfinding.Bidirectional` Options & Node Validation** — Hardened bidirectional search by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options) and early-returning `:error` for missing source or target nodes in the graph, resolving edge cases like empty and disconnected graphs.
- **`Yog.Pathfinding.Johnson` Options Validation** — Hardened Johnson's search facade by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options).
- **`Yog.Pathfinding.FloydWarshall` Options Validation** — Hardened Floyd-Warshall search facade by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options).
- **`Yog.Pathfinding.BellmanFord` Options & Node Validation** — Hardened Bellman-Ford search by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options), and adding early-return checks for missing source or target nodes in the graph, resolving edge cases like empty and disconnected graphs.
- **`Yog.Pathfinding.Dijkstra` Options & Node Validation** — Hardened Dijkstra search by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options), resolving edge cases like empty and disconnected graphs via delegated node existence checks.
- **`Yog.Pathfinding.AStar` Options & Node Validation** — Hardened A* search by validating keyword list options (raising `KeyError` for missing required options and `ArgumentError` for unknown options) and early-returning `:error` for missing source or target nodes in the graph, resolving edge cases like empty and disconnected graphs.
- **`Yog.Functional.Model.embed/2` Direction Preservation** — Fixed `embed/2` to preserve the target functional graph's direction (`:directed` or `:undirected`) when rebuilding a graph from a matched context, and clarified the inductive graph documentation around match/embed semantics.
- **Data Structure & Utility Audit** — Hardened `Yog.Utils.compare/2` with explicit `:infinity` sentinel handling, normalized `Yog.Utils.fisher_yates/2` seed handling, clarified shuffle documentation, and reviewed `Yog.DisjointSet` and `Yog.PairingHeap` coverage/performance for the pre-1.0 audit wave.

### Changed


## [0.99.1] - 2026-07-10

### Added

- **`Yog.Layout` Geometry Helpers** — Added `Yog.Layout.Geometry` (exposed as `Yog.Layout.rects/2`, `Yog.Layout.anchor/2`, and `Yog.Layout.edge_endpoints/3`) for converting center-based position maps into bounding rectangles, computing anchor points on rect edges (`:top`, `:bottom`, `:left`, `:right`, corners, and `:center`), and calculating connector endpoints between nodes. Supports per-node size callbacks, making the helpers suitable as a renderer-agnostic geometry layer for Excalidraw, SVG, or any rect-based diagram system.
- **Controlled Placement Layout Guide** — Expanded `livebooks/how_to/layout_guide.livemd` to comprehensively document using `Yog.Layout` as a deterministic coordinate backend. Covers manual placement, grid layout, multipartite spacing, transform/fit pipelines, DOT fixed-position output, GraphViz layout import, geometry helpers, and a prose guide on when to use GraphViz rank controls vs explicit coordinates.
- **`Yog.Layout.graphviz/2` — GraphViz Layout Import** — Added `Yog.Layout.GraphViz.layout/2` (exposed as `Yog.Layout.graphviz/2`) to shell out to an installed GraphViz engine (`:dot`, `:neato`, `:fdp`, `:circo`, etc.) and import the computed node coordinates back as a `Yog.Layout` position map. Supports both simple (`Yog.Graph`) and multi-graphs (`Yog.Multi.Graph`), configurable coordinate scaling, custom DOT options, and clear error handling when the GraphViz CLI is not found.
- **DOT Renderer Position Support** — Added options (`:positions`, `:pin`, `:position_scale`, `:position_unit`) to `Yog.Render.DOT` and `Yog.Multi.DOT` to output GraphViz `pos` and `pin` attributes from `Yog.Layout` coordinate maps.
- **`Yog.Layout.pack/2` & `Yog.Layout.merge_position_maps/1`** — Added layout composition and packing helpers. `pack/2` places multiple coordinate maps side-by-side (horizontally) or stacked (vertically) with a custom gap, and `merge_position_maps/1` merges disjoint coordinate maps while raising clean errors for duplicate node IDs.
- **`Yog.Layout.multipartite/3` Enhancements** — Extended the multipartite layout algorithm with spacing and direction controls. Callers can now specify `:direction` (`:left_to_right`, `:right_to_left`, `:top_to_bottom`, or `:bottom_to_top`), custom gaps (`:layer_gap` and `:node_gap`), layout `:origin` offset, node alignment (`:align_nodes` as `:start`, `:center`, or `:end`), and sorting options (`:order_by`).
- **`Yog.Layout.grid/2`** — Added deterministic grid layout algorithm (`Yog.Layout.Grid.layout/2`) for placing nodes in a 2D row- or column-based matrix. Supports cell dimensions, custom grid origins, and validation for duplicate or missing node IDs, and handles empty cells via placeholders (`nil` or `:_`).
- **`Yog.Layout.manual/3`** — Implemented manual layout algorithm for explicit node placement. Callers can supply known coordinate maps, validate nodes in strict mode, filter out extra coordinates, and customize strategies (`:center`, `:random`, `:ignore`, `:error`, or generator functions) for filling in missing node coordinates.
- **`Yog.Layout` Coordinate Transform Utilities** — Added `bounds/1`, `translate/3`, `scale/2`, `scale/3`, `center/2`, and `fit/2` helpers in `Yog.Layout` to translate, scale, center, and fit layout coordinate maps, and refactored `Yog.Layout.Spring` to reuse them.
- **`mix yog.test_livebooks` Task** — Added a Mix task and CI action to automatically validate the execution of Elixir code blocks inside all project Livebooks in a headless environment.

### Fixed

- **`Yog.Layout.fit/2` Division by Zero** — Resolved a potential arithmetic division-by-zero crash when fitting layouts where all nodes align perfectly on a single horizontal or vertical line.
- **Robust GraphViz Layout Tests** — GraphViz layout unit tests now check for the presence of the `dot` and `neato` executables and skip gracefully if they are missing from the system's `PATH`.
- **`Yog.MatchingTest` Timeout** — Fixed an exponential DFS backtracking timeout in `hopcroft_karp_large_random_bipartite_test` by implementing a linear-time BFS search in `maximal_matching?/2`.
- **Optional Dependency Warnings** — Silenced compile-time warnings generated when compiling without optional dependencies (`saxy` and `libgraph`). Wrapped Saxy handler behaviours in compile-time checks, removed `@impl` callback annotations from optional integration handlers, moved the `YogGraph` alias within the compile-time block in `Yog.IO.Libgraph`, and removed the duplicate `@moduledoc` tag.
- **`Yog.Layout.Spring` Partial Initial Positions** — `initial_pos` may now be partial: missing graph nodes are initialized randomly instead of being silently omitted from the returned layout, extra nodes are ignored, and `:seed` is honored when filling missing positions.
- **`Yog.Layout.Spring` Barnes-Hut Correctness** — Fixed Barnes-Hut quadtree mass accounting and prevented approximation of cells containing the target node, eliminating self-force leakage in approximate repulsion calculations.
- **`Yog.Layout` Input Validation** — Added duplicate-node validation for Tutte boundary nodes, Shell shell membership, and Multipartite layer membership to avoid ambiguous layouts caused by overwriting coordinates in the result map.
- **Release Documentation Version Snippets** — Normalized stale dependency examples in `Yog.IO.Libgraph` docs and Livebooks to use `{:yog_ex, "~> 0.99.1"}` consistently.

### Changed

- **Portable Livebook Dependencies** — Normalized all `.livemd` files under the `livebooks/` directory to reference the local `yog_ex` package via relative paths (`path: "../.."`) rather than remote Hex versions, enabling clean local development without dependency conflicts.


## [0.99.0] - 2026-07-03

### Added

- **`Yog.Layout`** — Implemented pure Elixir layout calculation algorithms: `Yog.Layout.circular/2` (circular placement), `Yog.Layout.random/2` (random uniform boundary placement), `Yog.Layout.spring/2` (Fruchterman-Reingold force-directed simulation), `Yog.Layout.tutte/3` (Tutte barycentric embedding via Gauss-Seidel relaxation), `Yog.Layout.shell/3` (concentric shells), and `Yog.Layout.multipartite/3` (parallel layers/columns). All layouts return a `%{node_id => {x, y}}` coordinate map where coordinates are represented as `{float, float}` tuples.
- **Barnes-Hut Simulation** — Implemented Barnes-Hut quadtree-based spatial approximation for `Yog.Layout.Spring` (activated via the `:barnes_hut` and `:theta` options). This reduces repulsive force computation complexity from $O(V^2)$ to $O(V \log V)$, facilitating fast force-directed layout computation on large graphs.
- **`Yog.Render.SVG`** — Implemented a pure Elixir SVG renderer supporting simple graphs, directed graphs, and multigraphs. It computes parallel edge indices and multiplicities to render parallel edges as distinct curved quadratic Bézier curves, self-loops as cubic Bézier loops, and directed arrowheads with boundary-offset truncation math to keep arrowheads visible at the node borders.
- **Livebook Layout Guide** — Created `livebooks/how_to/layout_guide.livemd` showcasing circular, spring, tutte, shell, and multipartite layouts rendered using interactive Kino SVG (`Kino.HTML.new/1`).
- **`Yog.Pathfinding.Disjoint`** — Added `suurballe/4` implementing Suurballe's algorithm for finding two edge-disjoint shortest paths of minimum total cost in directed and undirected graphs. Supports custom weight functions, addition, subtraction, and comparison operations.
- **`Yog.Flow.NetworkSimplex`** — Implemented the primal Network Simplex algorithm for solving the Minimum Cost Flow (MCF) problem (`Yog.Flow.NetworkSimplex.min_cost_flow/4`). It supports demand/supply balances on nodes and capacity limits and cost values on edges, and handles infeasible, unbounded, or unbalanced flow networks correctly.
- **Network Simplex Oracle Property** — Added oracle parity test `P-ORAC-FLOW-005` in `test/oracle/flow_oracle_test.exs` to verify cost parity between Yog and NetworkX on randomly generated flow networks, including edge cases and error conditions.

### Fixed

- **Compile-time Circular Dependencies** — Resolved compile-time and export-time circular dependencies across several core modules (`Yog.MST`, `Yog.DAG`, and `Yog.Connectivity.KCore`) to clean up module dependencies and improve build speeds.
- **`Yog.Render.SVG` Parentheses Sigil Bug** — Resolved a compiler syntax error caused by nested parentheses inside `~s(marker-end="url(#arrow)")` by changing the sigil delimiters to square brackets `~s[...]`.
- **`Yog.Community.Walktrap`** — Corrected hierarchical merging logic by resolving a key mismatch bug (where community IDs were indices but caches were keyed by original node IDs). Also corrected the random walk probability merges to be degree-weighted and added Ward's size-weighting factor during the clustering step.

### Changed

- **Semiring Parameter Ordering** — Standardized the positional parameter ordering of all graph algorithms that accept custom semiring parameters. Now, all algorithms use the consistent order **`zero, add, compare, subtract`**. This affects positional calls to:
  - `Yog.Pathfinding.johnson/5` / `Yog.Pathfinding.Johnson.johnson/5`
  - `Yog.Flow.MaxFlow.edmonds_karp/8`
  - `Yog.Flow.MaxFlow.dinic/8`
  - `Yog.Flow.MaxFlow.push_relabel/8`
  - Internal helper functions within `Matrix` and `MaxFlow`.
  This is a breaking change for direct positional calls to these low-level functions, but does not affect options-based facade calls.

## 0.98.5 - 2026-06-14

### Fixed

- **`Yog.IO.GEXF`** — Fixed a parser crash that occurred when encountering invalid/malformed integer attributes, replacing unsafe `String.to_integer/1` calls with `Integer.parse/1` fallbacks in both the `Saxy` and `xmerl` parsing backends.
- **`Yog.Property.Clique.all_maximal_cliques/1`** — Self-loop edges no longer cause the node to appear as its own neighbour in the Bron–Kerbosch adjacency map. Previously a single node with a self-loop was incorrectly counted as a 2-clique.
- **`Yog.Connectivity.Reachability.counts_estimate/2`** now works for large graphs. `phash2` has explicity range passed.
- **`Yog.Flow.MinCost.ssp/4`** — Rewrote residual graph representation to use unique edge IDs in the Successive Shortest Path (SSP) min-cost flow algorithm, preventing antiparallel edges from overwriting each other.
- **`Yog.Community.Leiden`** — Corrected refinement target community selection, candidate filtering, and self-loop exclusion.

### Added

- **NetworkX Comparative Benchmarks** — Added a comparative benchmark suite (`benchmarks/networkx/`) comparing YogEx performance to NetworkX across various algorithms (topological sort, connected components, shortest paths, centrality measures, community detection, max flow, MST, etc.).
- **Centrality Oracle Tests** — Added oracle parity tests for centrality measures (PageRank, Betweenness, Closeness, Harmonic, Katz, and Eigenvector centrality) to verify agreement between Yog and NetworkX.
- **Priority 1 Oracle Tests** — Implemented oracle tests for Successive Shortest Path (Min-Cost Flow), Graph Isomorphism, Weisfeiler-Lehman (WL) Hash, and Tarjan's Bridges & Articulation Points.
- **NetworkX Oracle Test Suite** — Property-based cross-implementation parity tests that treat NetworkX as a ground-truth oracle. Every test generates a random graph, dispatches it to a Python subprocess running NetworkX, and compares the decoded result against YogEx. 37 properties covering:
  - **Pathfinding** (8 properties): Dijkstra SSSP, A*, Bellman-Ford, Floyd-Warshall, Johnson, Bidirectional Dijkstra, Bidirectional BFS, Yen k-shortest.
  - **Flow & Cuts** (3 properties): Edmonds-Karp, Dinic, Stoer-Wagner.
  - **Spanning Tree** (5 properties): Kruskal, Prim, Borůvka, Maximum ST, Minimum Arborescence.
  - **Matching** (4 properties): Hopcroft-Karp cardinality, Blossom maximum cardinality, Hungarian min/max weight.
  - **Connectivity** (3 properties): SCC (Tarjan), Connected Components, Weakly Connected Components.
  - **Graph Properties** (5 properties): Bipartite, Tree, Forest, DAG, Clique number.
  - **Traversal** (3 properties): BFS layers, Lexicographical topological sort, Topological generations.
  - **Centrality** (3 properties): Degree, In-degree, Out-degree (exact).
  - **Community Quality** (3 properties): Louvain, Leiden, and Label Propagation NMI floors on well-separated SBM.
- **`test/oracle/README.md`** — Full documentation of the oracle harness architecture, parity matrix, known semantic differences, running instructions, and guide for adding new oracle properties. Registered in `ex_doc` under *Testing & Verification*.
- **`Yog.Community.Metrics.nmi/2`** — Normalized Mutual Information for comparing detected communities against ground truth.

### Changed

- **Leiden Community Detection** — Refactored the Leiden algorithm (`Yog.Community.Leiden`) to use true stochastic refinement.
- **Weighted Centrality** — Updated centrality functions to support and utilize edge weights.
- **CI split** — Fast main CI (`mix test`) excludes `:oracle` tags and finishes in ~5 s. Oracle parity tests run nightly via a separate workflow.
- **`test/oracle/scripts/requirements.txt`** — Now pins `scipy>=1.11` alongside `numpy>=1.24` and `networkx==3.6.1` (required for Hungarian and PageRank/HITS adapters).

### Fixed (Test Hygiene)

- **Centrality Unit Tests** — Added unit tests verifying default options for PageRank, HITS, Eigenvector, Katz, and Alpha centrality.
- **Weisfeiler-Lehman (WL) Hash Oracle Tests** — Restricted the WL hash equivalence oracle test to undirected graphs.
- **Community quality floors** — Louvain, Leiden, and Label Propagation are all sensitive to random node-visit ordering. A single bad seed can trap the algorithm in a poor local optimum. Quality-floor tests now run each algorithm with 5 different random seeds and take the best NMI, eliminating flakiness without weakening regression signal.
- **Oracle test hygiene** (ORC-001–ORC-013 audit): fixed `length` variable shadowing in bidirectional Dijkstra, replaced silent `assert true` no-ops with `:ok`, replaced `String.to_atom/1` on Python error strings with an explicit mapping, removed dead `alpha` parameter from HITS adapter, moved inline `__import__("itertools")` to a top-level import, replaced `float('inf')` literal with `math.isinf`, guarded `nx.bipartite.color` against disconnected graphs, replaced non-reproducible `:rand.uniform/0` and `Enum.shuffle/1` with StreamData primitives, and short-circuited `weight_list_gen(0, _range)` to avoid `0..-1` range warnings.

## 0.98.3 - 2026-06-09

### Fixed

- **`Yog.Community.Walktrap.detect/1`** — Now selects the modularity-maximizing level from the dendrogram instead of the trivial all-merged level. The default partition is meaningful for typical graphs.
- **`Yog.Multi.Model.degree/2`, `out_degree/2`, `in_degree/2`** — Now correctly count undirected self-loops as contributing 2 to a node's degree (matching standard graph theory). This also fixes false-negative Eulerian path/circuit detection on undirected multigraphs containing self-loops.
- **`Yog.Multi.Eulerian.has_eulerian_circuit?/1`, `has_eulerian_path?/1`, `find_eulerian_circuit/1`, `find_eulerian_path/1`** — Now correctly tolerate isolated nodes (nodes with zero degree). Connectivity is checked over non-isolated nodes only, and start-node selection skips isolated nodes, matching standard Eulerian theory and NetworkX's behavior.
- **`Yog.Community.Louvain.detect/1`** — Now runs full hierarchical Louvain (phase 1 + aggregation + recursion) instead of phase 1 only. The returned partition may differ from previous versions on graphs without strong community structure (e.g., scale-free networks) — both partitions are valid modularity local optima but the new one is the standard Louvain output.
- **`Yog.Community.Louvain.detect_hierarchical/1`** — Now stores raw community IDs at each level so that the dendrogram can be correctly flattened back to original node IDs. See `Yog.Community.Dendrogram.flatten_to_original/1`.
- **`Yog.Community.Leiden.detect_hierarchical/1`** — Updated docstrings to point at `Yog.Community.Dendrogram.flatten_to_original/1` for obtaining final partitions over original node IDs. The dendrogram structure was already compatible after the Louvain fix.
- **`Yog.Community.Infomap.detect/1`** — Rewrote to implement the actual Map Equation optimization (Rosvall & Bergstrom 2008). Previously ran a single greedy pass with a flow heuristic that did not compute description length. Now computes L(M) = q_↷ H(Q) + Σ p_↻^i H(P^i), iterates to convergence, and minimizes description length as documented.
- **`Yog.Community.GirvanNewman.detect/1`** — Now defaults to the modularity-maximizing partition across the dendrogram instead of the trivial all-singletons partition. For users who specifically want the all-singletons partition, pass `target_communities: Yog.node_count(graph)` explicitly.

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
