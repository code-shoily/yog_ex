# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
> **Versioning Scheme**: Starting from `0.51.0`, YogEx versions map to upstream Yog versions as follows: `Yog A.B._` maps to `YogEx 0.AB.0`. Internal YogEx fixes increment the patch version (e.g., `0.51.1`). This will continue until YogEx reaches parity/confidence with upstream versioning.

## [0.51.0] - Unreleased

### Added
- **`Yog.Pathfinding`**: New facade module providing a unified keyword-based API for `Dijkstra`, `AStar`, `BellmanFord`, and `FloydWarshall`.
- **`Yog.Connectivity`**: Support for `connected_components/1` and `weakly_connected_components/1` via `defdelegate`.
- **I/O Integration**: Support for multiple graph formats via `yog_io`: `GDF`, `GraphML`, `JSON`, `LEDA`, `Pajek`, and `TGF`.
- **Documentation**: Comprehensive `@moduledoc`, `@doc`, and doctests for `Yog.Connectivity` and `Yog.Pathfinding`.

### Changed
- **DAG Modules**: Renamed for Elixir consistency: `Yog.DAG.Models` -> `Yog.DAG.Model` and `Yog.DAG.Algorithms` -> `Yog.DAG.Algorithm`.
- **Examples**: Updated all example files to use `add_edge!` (and variants) when chaining to handle the `Result` type correctly.
- **Module Names**: Corrected outdated module references in examples (`Yog.Components` -> `Yog.Connectivity`, `Yog.TopologicalSort` -> `Yog.Traversal`).
- **Dependencies**: Updated `yog` to `~> 5.1` and `yog_io` to `>= 1.0.0` with `override: true`.

## [2.0.0] - 2026-03-04

### Breaking

- **`Yog.Pathfinding.floyd_warshall/1`**: Return type changed from nested `%{src => %{dst => weight}}` to flat `%{{src, dst} => weight}` to match Yog 2.0.0 upstream change.

### Added

- **`Yog.Clique`** module: `max_clique/1`, `all_maximal_cliques/1`, `k_cliques/2` (Bron-Kerbosch)
- **`Yog.Model.add_edge_ensured/5`**: Auto-creates missing endpoint nodes with default data
- **`Yog.MST.prim/1`**: Prim's algorithm for MST
- **`Yog.Components.kosaraju/1`**: Kosaraju's SCC algorithm
- **`Yog.Traversal`**: `fold_walk/1`, `implicit_fold/1`, `implicit_fold_by/1`, `is_cyclic/1`, `is_acyclic/1`
- **`Yog.Pathfinding`**: `distance_matrix/1`, `implicit_dijkstra/1`, `implicit_dijkstra_by/1`, `implicit_a_star/1`, `implicit_a_star_by/1`, `implicit_bellman_ford/1`, `implicit_bellman_ford_by/1`
- **`Yog.Transform`**: `filter_edges/2`, `complement/2`, `to_directed/1`, `to_undirected/2`, `contract/4`
- **`Yog.Builder.Grid`**: `from_2d_list_with_topology/4`, `rook/0`, `bishop/0`, `queen/0`, `knight/0`, `walkable/1`, `always/0`, `find_node/2`
- **`Yog` facade**: `is_cyclic/1`, `is_acyclic/1`, `add_edge_ensured/4`

### Changed

- **`Yog.TopologicalSort.lexicographical_sort/2`**: Compare function now operates on node data (not node IDs), matching Yog 2.0.0
- Synced with Yog 2.2.0 (upstream fixes to MST Prim, min-cut, DFS ordering)

## [0.1.0] - 2026-02-27

### Added
- Initial mapping of Gleam Yog 1.2.5
