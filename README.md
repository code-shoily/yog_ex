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

Yog is a set of Graph and Network algorithms and data structures implemented in Elixir and packaged as a common API.

It started off as a wrapper around the Gleam [Yog](https://hex.pm/packages/yog) library, but now YogEx is now fully implemented in Elixir and a superset of the original Gleam version.
 
> [!WARNING]
> **API Stability**: Until the version reaches `1.0.0`, there may be breaking changes. While I'll try my best to keep the API stable, there's no guarantee. The primary focus is on **performance**, **documentation**, and **bugfixes**.

## Features

YogEx provides comprehensive graph algorithms organized into modules:

### Core Capabilities

**[Pathfinding & Flow](https://hexdocs.pm/yog_ex/Yog.Pathfinding.html)** — Shortest paths (Dijkstra, A*, Bellman-Ford, Floyd-Warshall, Johnson's), maximum flow (Edmonds-Karp), min-cut (Stoer-Wagner), and implicit state-space search for on-demand graphs.

**[Network Analysis](https://hexdocs.pm/yog_ex/Yog.Centrality.html)** — Centrality measures (PageRank, betweenness, closeness, eigenvector, Katz), community detection (Louvain, Leiden, Infomap, Walktrap), and network health metrics.

**[Connectivity & Structure](https://hexdocs.pm/yog_ex/Yog.Connectivity.html)** — SCCs (Tarjan/Kosaraju), bridges, articulation points, K-core decomposition, and reachability analysis with exact and HyperLogLog-based estimation.

**[Graph Operations](https://hexdocs.pm/yog_ex/Yog.Operation.html)** — Union, intersection, difference, Cartesian product, power, isomorphism, and O(1) transpose.

### Developer Experience

**[Generators & Builders](https://hexdocs.pm/yog_ex/Yog.Generator.Classic.html)** — Classic patterns (complete, cycle, grid, Petersen) and random models (Erdős-Rényi, Barabási-Albert, Watts-Strogatz) with labeled and grid builders.

**[I/O & Visualization](https://hexdocs.pm/yog_ex/Yog.IO.GraphML.html)** — GraphML, GDF, Pajek, LEDA, TGF, JSON serialization plus ASCII, DOT, and Mermaid rendering.

**[Functional Graphs](https://hexdocs.pm/yog_ex/Yog.Functional.html)** *(Experimental)* — Pure inductive graph library (FGL) for elegant recursive algorithms.

**[Complete Algorithm Catalog](ALGORITHMS.md)** — See all 60+ algorithms, underlying data structures (Pairing Heap, Union-Find, HyperLogLog), and selection guidance with Big-O complexities.

## Installation

### Basic Installation

Add YogEx to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:yog_ex, "~> 0.80.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### Livebook

For livebook, add the following:

```elixir
Mix.install(
  {:yog_ex, "~> 0.80.0"}
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
