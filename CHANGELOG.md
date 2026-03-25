# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
