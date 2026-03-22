# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
> **Versioning Scheme**: Starting from `0.51.0`, YogEx versions map to upstream Yog versions as follows: `Yog A.B._` maps to `YogEx 0.AB.0`. Internal YogEx fixes increment the patch version (e.g., `0.51.1`). This will continue until YogEx reaches parity/confidence with upstream versioning.

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
