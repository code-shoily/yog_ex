# YogEx 🌳

> **যোগ** • (*jōg*)
> *noun*
> 1. connection, link, union
> 2. addition, sum

```text
                    λ
                   /|\
                  / | \
                 /  |  \
                Y   |   O--------G
               /    |    \      /
              /     |     \    /
             /      |      \  /
            যো------+-------গ
           / \      |      / \
          /   \     |     /   \
         /     \    |    /     \
        ✦       ✦   |   ✦       ✦
                   
```

[![Hex Version](https://img.shields.io/hexpm/v/yog_ex.svg)](https://hex.pm/packages/yog_ex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/yog_ex/)
[![CI](https://github.com/code-shoily/yog_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/code-shoily/yog_ex/actions)
[![Coverage Status](https://coveralls.io/repos/github/code-shoily/yog_ex/badge.svg?branch=main)](https://coveralls.io/github/code-shoily/yog_ex?branch=main)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Yog is a set of Graph and Network algorithms and data structures implemented in Elixir and packaged as a common API.

It started off as a wrapper around the Gleam [Yog](https://hex.pm/packages/yog) library, but now YogEx is fully implemented in Elixir and a superset of the original Gleam version.

> [!WARNING]
> **API Stability**: Until the version reaches 0.98.0 ~~1.0.0~~, there may be ~~breaking changes. While I'll try my best to keep the API stable, there's no guarantee~~ some hiccups in performance, and documentation quality maybe less than optimal. Before version 0.99.0 is released in **12-12-2026**, the primary focus is on **performance**, **documentation**, and **bugfixes**. From v0.97.0 onwards, there will be no breaking changes until v2.0 (No plans for that).

## Features

YogEx provides comprehensive graph algorithms organized into modules:

### Core Capabilities

**[Pathfinding & Flow](https://hexdocs.pm/yog_ex/Yog.Pathfinding.html)** — Shortest paths (Dijkstra, A*, Bellman-Ford, Floyd-Warshall, Johnson's), maximum flow (Edmonds-Karp), min-cut (Stoer-Wagner), and implicit state-space search for on-demand graphs.

**[Network Analysis](https://hexdocs.pm/yog_ex/Yog.Centrality.html)** — Centrality measures (PageRank, betweenness, closeness, eigenvector, Katz), community detection (Louvain, Leiden, Infomap, Walktrap), and network health metrics.

**[Connectivity & Structure](https://hexdocs.pm/yog_ex/Yog.Connectivity.html)** — SCCs (Tarjan/Kosaraju), bridges, articulation points, K-core decomposition, and reachability analysis with exact and HyperLogLog-based estimation.

**[Graph Operations](https://hexdocs.pm/yog_ex/Yog.Operation.html)** — Union, intersection, difference, Cartesian product, power, isomorphism, and O(1) transpose.

### Developer Experience

**[Generators & Builders](https://hexdocs.pm/yog_ex/Yog.Generator.Classic.html)** — Classic patterns (complete, cycle, grid, Petersen), random models (SBM, R-MAT), and a comprehensive **Maze Generation** suite (Recursive Backtracker, Wilson's, Kruskal's, Eller's, etc.) with labeled and grid builders.

**[I/O & Visualization](https://hexdocs.pm/yog_ex/Yog.IO.GraphML.html)** — GraphML, GDF, Pajek, LEDA, TGF, JSON serialization plus ASCII, DOT, and Mermaid rendering.

**[Functional Graphs](https://hexdocs.pm/yog_ex/Yog.Functional.html)** *(Experimental)* — Pure inductive graph library (FGL) for elegant recursive algorithms.

**[Complete Algorithm Catalog](ALGORITHMS.md)** — See all 60+ algorithms, underlying data structures (Pairing Heap, Union-Find, HyperLogLog), and selection guidance with Big-O complexities.

## Installation

### Basic Installation

Add YogEx to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:yog_ex, "~> 0.98.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### Optional Dependencies

YogEx includes several optional dependencies that enable additional I/O and interoperability features:

| Dependency | Module | Purpose |
|------------|--------|---------|
| [`:saxy`](https://hex.pm/packages/saxy) | `Yog.IO.GraphML` | Fast streaming XML parser for GraphML files (3-4x faster than default `:xmerl`) |
| [`:jason`](https://hex.pm/packages/jason) | `Yog.IO.JSON` | JSON serialization/deserialization for D3.js, Cytoscape, vis.js, NetworkX formats |
| [`:libgraph`](https://hex.pm/packages/libgraph) | `Yog.IO.Libgraph` | Bidirectional conversion with libgraph library |

To use these features, add the optional dependencies to your `mix.exs`:

```elixir
def deps do
  [
    {:yog_ex, "~> 0.98.0"},
    {:saxy, "~> 1.5"},       # For fast GraphML/XML parsing
    {:jason, "~> 1.4"},      # For JSON import/export
    {:libgraph, "~> 0.16"}   # For libgraph interoperability
  ]
end
```

#### XML/GraphML with Saxy

```elixir
# Reading large GraphML files is significantly faster with saxy
{:ok, graph} = Yog.IO.GraphML.read("large_network.graphml")

# Writing GraphML
Yog.IO.GraphML.write("output.graphml", graph)
```

#### JSON Serialization with Jason

```elixir
# Export to various JSON formats
json = Yog.IO.JSON.to_json(graph, Yog.IO.JSON.export_options_for(:d3_force))

# Import from JSON
{:ok, graph} = Yog.IO.JSON.from_json(json_string)
```

#### Libgraph Interoperability

```elixir
# Convert Yog graph to libgraph
libgraph = Yog.IO.Libgraph.to_libgraph(graph)

# Convert libgraph back to Yog
{:ok, yog_graph} = Yog.IO.Libgraph.from_libgraph(libgraph)
```

### Livebook

For livebook, add the following:

```elixir
Mix.install(
  {:yog_ex, "~> 0.98.0"}
)
```

There is a [Kino App](https://github.com/code-shoily/kino_yog) that can be used to explore the library and create and render graphs.

### Usage

```elixir
alias Yog.Pathfinding

# Create a directed graph
graph =
  Yog.directed()
  |> Yog.add_node(1, "Start")
  |> Yog.add_node(2, "Middle")
  |> Yog.add_node(3, "End")
  |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
  |> Yog.add_edge_ensure(from: 2, to: 3, with: 3)
  |> Yog.add_edge_ensure(from: 1, to: 3, with: 10)

# Find shortest path using Dijkstra (uses :ok/:error tuples and Path struct)
case Pathfinding.shortest_path(
  in: graph,
  from: 1,
  to: 3
) do
  {:ok, path} ->
    IO.puts("Found path with weight: #{path.weight}")
  :error ->
    IO.puts("No path found")
end
# => Found path with weight: 8
```

## Examples

Detailed examples are located in the [examples/](https://github.com/code-shoily/yog_ex/tree/main/examples) directory

### Advent of Code Solutions

YogEx is used to solve [Advent of Code](https://adventofcode.com/) challenges. 

See all Advent of Code solutions tagged with `graph` that demonstrate usage of YogEx algorithms in the [Advent of Code repository](https://github.com/code-shoily/advent_of_code).

## Projects Using Yog

Yog powers the following open-source libraries that build domain-specific abstractions on top of its graph engine:

### [Choreo](https://github.com/code-shoily/choreo) — Domain-Specific Diagram Builders

Analysis-first diagramming for Elixir. Instead of drawing static pictures, you model systems and get live answers — reachability, cycles, bottlenecks, threat generation, and more.

- **Choreo** — Infrastructure architecture diagrams (databases, caches, services, queues)
- **Choreo.FSM** — Finite state machines with determinism checks and shortest accepting paths
- **Choreo.Dataflow** — Pipeline diagrams with throughput simulation and backpressure detection
- **Choreo.Dependency** — Software dependency graphs with cycle detection and layer enforcement
- **Choreo.DecisionTree** — Classification trees with feature importance and pruning
- **Choreo.MindMap** — Concept mapping with orphan detection and root-to-leaf paths
- **Choreo.ThreatModel** — STRIDE threat modeling with auto-generated severity scoring
- **Choreo.Workflow** — Task orchestration with critical-path analysis and Saga-pattern compensations

### [Tapestry](https://github.com/code-shoily/tapestry) — Graph-Native Domain Engine

Model structured domains as typed multigraphs. Kanban boards, timelines, dependency networks, and structural analysis are all projections of the same underlying graph.

- Project management with milestones, tasks, users, and labels
- Query what blocks a task, what's ready to start, and who's the bottleneck
- Critical-path analysis and transitive dependency tracking
- Renders natively to Mermaid for GitHub, Notion, and Obsidian

### [Meridian](https://github.com/code-shoily/meridian) — Spatial Graphs

Projection-aware spatial graphs for Elixir. Brings geography into graph theory with coordinate-reference-system safety, map ingestion, and spatial algorithms.

- Build graphs from H3 hex grids and geohash rectangles
- Ingest and render GeoJSON for road networks and geographic data
- Spatially-informed A*, Dijkstra, and widest-path routing
- CRS-aware edge weights with earth-distance heuristics

## Development

### Running Tests

```sh
mix test
```

Run tests for a specific module:

```sh
mix test test/yog/pathfinding/dijkstra_test.exs
```

### Project Structure

- `lib/yog/` — Core graph library modules (pure Elixir)
- `test/` — Unit tests and doctests
- `examples/` — Real-world usage examples

## Property-Based Testing

This library uses property-based testing (PBT) via `StreamData` to ensure that algorithms hold up against a wide range of automatically generated graph structures. 

See the [PROPERTIES.md](PROPERTIES.md) for a complete catalog of all algorithmic invariants (hypotheses) verified by the test suite.

## AI Assistance

Parts of this project were developed with the assistance of AI coding tools. All AI-generated code has been reviewed, tested, and validated by the maintainer.
