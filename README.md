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

### 🛠️ Developer Experience

**[Generators & Builders](https://hexdocs.pm/yog_ex/Yog.Generator.Classic.html)** — Classic patterns (complete, cycle, grid, Petersen) and random models (Erdős-Rényi, Barabási-Albert, Watts-Strogatz) with labeled and grid builders.

**[I/O & Visualization](https://hexdocs.pm/yog_ex/Yog.IO.GraphML.html)** — GraphML, GDF, Pajek, LEDA, TGF, JSON serialization plus ASCII, DOT, and Mermaid rendering.

**[Functional Graphs](https://hexdocs.pm/yog_ex/Yog.Functional.html)** *(Experimental)* — Pure inductive graph library (FGL) for elegant recursive algorithms.

📖 **[Complete Algorithm Catalog](#algorithm-selection-guide)** — See all 60+ algorithms with time complexities and selection guidance.

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

### Graph I/O Support

YogEx includes comprehensive graph I/O modules (`Yog.IO.*`) for popular formats:

- **GraphML** - XML-based format (Gephi, yEd, Cytoscape, NetworkX)
- **GDF** - GUESS Graph Format (Gephi)
- **Pajek** - Social network analysis (.net format)
- **LEDA** - Library of Efficient Data types and Algorithms
- **TGF** - Trivial Graph Format
- **JSON** - Adjacency list and matrix formats

## Quick Start

### Shortest Path

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

### Community Detection

```elixir
alias Yog.Community

# Build a graph with two communities
graph =
  Yog.undirected()
  |> Yog.add_edge_with(1, 2, 1, & &1)
  |> Yog.add_edge_with(2, 3, 1, & &1)
  |> Yog.add_edge_with(1, 3, 1, & &1)   # Triangle: 1-2-3
  |> Yog.add_edge_with(4, 5, 1, & &1)
  |> Yog.add_edge_with(5, 6, 1, & &1)
  |> Yog.add_edge_with(4, 6, 1, & &1)   # Triangle: 4-5-6
  |> Yog.add_edge_with(3, 4, 1, & &1)   # Bridge between communities

communities = Community.Louvain.detect(graph)
IO.puts("Found #{communities.num_communities} communities")
# => Found 2 communities

modularity = Community.modularity(graph, communities)
IO.puts("Modularity: #{modularity}")
# => Modularity: 0.35714285714285715
```

### Graph Generators

```elixir
alias Yog.Generator.{Classic, Random}
# Classic graph patterns
complete = Classic.complete(10)       # K₁₀ complete graph
cycle = Classic.cycle(20)              # C₂₀ cycle graph
petersen = Classic.petersen()           # The famous Petersen graph
grid = Classic.grid_2d(5, 5)           # 5×5 grid lattice

# Random graph models
sparse = Random.erdos_renyi_gnp(100, 0.05)    # G(n,p) model
scale_free = Random.barabasi_albert(1000, 3)   # Preferential attachment
small_world = Random.watts_strogatz(100, 6, 0.1)  # Small-world
```

### Grid Builder (Maze Solving)

```elixir
alias Yog.Builderr.Grid
alias Yog.Pathfinding
alias Yog.Render.ASCII

# Build a maze from a 2D grid
maze = [
  [".", "#", "#", "."],
  [".", ".", "#", "#"],
  ["#", ".", ".", "."],
  ["#", "#", "#", "."],
  ["#", ".", "#", "."],
]

# Create grid with walkable predicate
grid = Grid.from_2d_list(maze, :undirected, Grid.including(["."]))

IO.puts(ASCII.grid_to_string(grid, %{0 => "S", 19 => "E"}))

# Prints the Maze:
#
#  +---+---+---+---+
#  | S |   |   |   |
#  +   +---+---+---+
#  |       |   |   |
#  +---+   +---+---+
#  |   |           |
#  +---+---+---+   +
#  |   |   |   |   |
#  +---+---+---+   +
#  |   |   |   | E |
#  +---+---+---+---+
#

```

### Labeled Graph Builder

```elixir
alias Yog.Builder.Labeled
alias Yog.Pathfinding

# Build graphs with meaningful labels instead of integer IDs
builder =
  Labeled.directed()
  |> Labeled.add_edge("London", "Paris", 450)
  |> Labeled.add_edge("Paris", "Berlin", 878)
  |> Labeled.add_edge("London", "Berlin", 930)

# Convert to graph for algorithms
graph = Labeled.to_graph(builder)

# Look up internal IDs by label
{:ok, london_id} = Labeled.get_id(builder, "London")
{:ok, berlin_id} = Labeled.get_id(builder, "Berlin")

# Find shortest path using integer IDs
case Pathfinding.shortest_path(in: graph, from: london_id, to: berlin_id) do
  {:ok, path} ->
    labeled_path = Enum.map(path.nodes, fn id ->
      graph.nodes[id]
    end)
    IO.puts("Route: #{Enum.join(labeled_path, " -> ")}, Distance: #{path.weight} km")
end
# => Route: London -> Berlin, Distance: 930 km
```

### Centrality Analysis

```elixir
alias Yog.Centrality

graph =
  Yog.directed()
  |> Yog.add_node(1, nil) 
  |> Yog.add_node(2, nil) 
  |> Yog.add_node(3, nil)
  |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {1, 3, 1}])

# Various centrality measures
pagerank = Centrality.pagerank(graph)
# => %{1 => 0.19757597883790196, 2 => 0.2815434776603495, 3 => 0.5208805435017486}
betweenness = Centrality.betweenness(graph)
# => %{1 => 0.0, 2 => 0.0, 3 => 0.0}
closeness = Centrality.closeness(graph)
# => %{1 => 1.0, 2 => 0.0, 3 => 0.0}
degree = Centrality.degree(graph, :out_degree)
# => %{1 => 1.0, 2 => 0.5, 3 => 0.0}
```

### Graph I/O & Interoperability

```elixir
alias Yog.IO.{GDF, GraphML, Pajek}
# Create graph
graph =
  Yog.directed()
  |> Yog.add_node(1, "Alice")
  |> Yog.add_node(2, "Bob")
  |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

# Serialize to popular formats like GraphML, TGF, LEDA, Pajek, JSON, or GDF
gdf_string = GDF.serialize(graph)
graphml_string = GraphML.serialize(graph)
pajek_string = Pajek.serialize(graph)

# Parse from string or read from file
{:ok, graph} = GraphML.deserialize(graphml_string)

# Read directly from file
# {:ok, loaded} = GraphML.read("slashdot.xml")
```

### Functional Inductive Graphs (Experimental)

YogEx includes an experimental implementation of Martin Erwig's Functional Graph Library (FGL) natively in Elixir under `Yog.Functional`. This provides a purely functional approach to graph algorithms using inductive decomposition (`match/2`).

```elixir
alias Yog.Functional.{Algorithms, Model}

# Create an inductive functional graph
graph =
  Model.empty()
  |> Model.put_node(1, "A")
  |> Model.put_node(2, "B")
  |> Model.put_node(3, "C")
  |> Model.add_edge!(1, 2, 1)
  |> Model.add_edge!(2, 3, 2)

# Inductive Top-Sort - consumes the graph naturally, no mutable visited sets!
{:ok, order} = Algorithms.topsort(graph)
# => [1, 2, 3]

# Inductive Dijkstra
Algorithms.shortest_path(graph, 1, 3)
# => {:ok, [1, 2, 3], 3}
```

See the [Functional Graphs README](lib/yog/functional/README.md) for a deep dive into the build/burn pattern, context-based traversal, and the philosophy of inductive graph decomposition.

## Examples

Detailed examples are located in the [examples/](https://github.com/code-shoily/yog_ex/tree/main/examples) directory

### Running Examples

```sh
mix run examples/gps_navigation.exs
mix run examples/network_bandwidth.exs
# etc.
```

### Advent of Code Solutions

YogEx is used to solve [Advent of Code](https://adventofcode.com/) challenges. 

See all Advent of Code solutions tagged with `graph` that demonstrate usage of YogEx algorithms in the [Advent of Code repository](https://github.com/code-shoily/advent_of_code).

## Algorithm Selection Guide

Detailed documentation for each algorithm can be found on [HexDocs](https://hexdocs.pm/yog_ex/).

| Algorithm | Use When | Time Complexity |
| --------- | -------- | --------------- |
| **Dijkstra** | Non-negative weights, single shortest path | O((V+E) log V) |
| **A*** | Non-negative weights + good heuristic | O((V+E) log V) |
| **Bellman-Ford** | Negative weights OR cycle detection needed | O(VE) |
| **Floyd-Warshall** | All-pairs shortest paths, distance matrices | O(V³) |
| **Johnson's** | All-pairs shortest paths in sparse graphs with negative weights | O(V² log V + VE) |
| **Edmonds-Karp** | Maximum flow, bipartite matching, network optimization | O(VE²) |
| **Network Simplex** | Global minimum cost flow optimization | O(E) pivots |
| **BFS/DFS** | Unweighted graphs, exploring reachability | O(V+E) |
| **Kruskal's MST** | Finding minimum spanning tree | O(E log E) |
| **Prim's MST** | Minimum spanning tree (starts from node) | O(E log V) |
| **Stoer-Wagner** | Global minimum cut, graph partitioning | O(V³) |
| **Tarjan's SCC** | Finding strongly connected components | O(V+E) |
| **Kosaraju's SCC** | Strongly connected components (two-pass) | O(V+E) |
| **Tarjan's Connectivity** | Finding bridges and articulation points | O(V+E) |
| **Hierholzer** | Eulerian paths/circuits, route planning | O(V+E) |
| **Topological Sort** | Ordering tasks with dependencies | O(V+E) |
| **Gale-Shapley** | Stable matching, college admissions | O(n²) |
| **Bron-Kerbosch** | Maximum and all maximal cliques | O(3^(n/3)) |
| **Implicit Search** | Pathfinding/Traversal on on-demand graphs | O((V+E) log V) |
| **PageRank** | Link-quality node importance | O(V+E) per iter |
| **Betweenness** | Bridge/gatekeeper detection | O(VE) or O(V³) |
| **Closeness / Harmonic** | Distance-based importance | O(VE log V) |
| **Eigenvector / Katz** | Influence based on neighbor centrality | O(V+E) per iter |
| **Harmonic Centrality** | Distance-based importance (infinite distance handling) | O(VE log V) |
| **Degree Centrality** | Simple connectivity importance | O(V) |
| **Louvain** | Modularity optimization, large graphs | O(E log V) |
| **Leiden** | Quality guarantee, well-connected communities | O(E log V) |
| **Label Propagation** | Very large graphs, extreme speed | O(E) per iter |
| **Infomap** | Information-theoretic flow tracking | O(E) per iter |
| **Walktrap** | Random-walk structural communities | O(V² log V) |
| **Girvan-Newman** | Hierarchical edge betweenness | O(E²V) |
| **Clique Percolation** | Overlapping community discovery | O(3^(V/3)) |
| **Local Community** | Massive/infinite graphs, seed expansion | O(S × E_S) |
| **Fluid Communities** | Exact `k` partitions, fast | O(E) per iter |
| **K-Core Decomposition** | Finding core-periphery structure | O(V + E) |
| **Reachability Counting** | Ancestor/descendant counting | O(V + E) |
| **Reachability Estimation** | HyperLogLog-based counting (O(V) memory) | O(V + E) |

## Underlying Algorithms & Data Structures

Beyond graph algorithms, YogEx implements several fundamental computer science techniques:

### Probabilistic Data Structures

| Technique | Used In | Purpose |
|-----------|---------|---------|
| **HyperLogLog** | `Reachability.counts_estimate/2` | Memory-efficient cardinality estimation (O(V) vs O(V²)) for reachability counting with ~3% error |

### Data Structures

| Structure | Used In | Purpose |
|-----------|---------|---------|
| **Pairing Heap** | `Yog.PriorityQueue` | O(1) insert, O(log n) amortized delete-min for Dijkstra, A*, Prim's |
| **:queue (Erlang)** | BFS in `MaxFlow`, `Reachability` | O(1) enqueue/dequeue for FIFO operations |
| **Binary-based HLL** | `Reachability` | 1024-byte fixed-size registers for cardinality estimation |

## Module Overview

| Module | Description |
| ------ | ----------- |
| `Yog` | Core graph creation, manipulation, and querying |
| `Yog.Pathfinding.*` | Dijkstra, A*, Bellman-Ford, Floyd-Warshall, Johnson's |
| `Yog.Flow.*` | Max flow (Edmonds-Karp), min cut (Stoer-Wagner), network simplex |
| `Yog.Community.*` | Louvain, Leiden, Label Propagation, Girvan-Newman, Infomap, and more |
| `Yog.Centrality` | PageRank, betweenness, closeness, eigenvector, degree, Katz |
| `Yog.Generator.*` | Classic patterns and random graph models |
| `Yog.Builder.*` | Grid, toroidal grid, labeled, and live/incremental builders |
| `Yog.Operation` | Union, intersection, difference, Cartesian product, isomorphism |
| `Yog.Property.*` | Bipartite, clique, cyclicity, Eulerian detection |
| `Yog.Traversal` | BFS, DFS, path finding with early termination |
| `Yog.Model` | Graph introspection (order, edge count, type, degree) |
| `Yog.Health` | Network health metrics (diameter, radius, eccentricity) |
| `Yog.Transform` | SCC (Tarjan/Kosaraju), topological sort, connectivity |
| `Yog.MST` | Minimum spanning trees (Kruskal's, Prim's) |
| `Yog.Dag.*` | DAG-specific algorithms (longest path, LCA, transitive closure) |
| `Yog.Render.*` | ASCII, DOT, Mermaid visualization |
| `Yog.IO.*` | Serialization to/from GraphML, GDF, JSON, LEDA, Pajek, and TGF |
| `Yog.DisjointSet` | Union-Find with path compression and union by rank |
| `Yog.Functional.*` | Experimental pure inductive graphs (FGL) |

## Property-Based Testing

This library uses property-based testing (PBT) via `StreamData` to ensure that algorithms hold up against a wide range of automatically generated graph structures. 

See the [PROPERTIES.md](PROPERTIES.md) for a complete catalog of all algorithmic invariants (hypotheses) verified by the test suite.

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

## AI Assistance

Parts of this project were developed with the assistance of AI coding tools. All AI-generated code has been reviewed, tested, and validated by the maintainer.
