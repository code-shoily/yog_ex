# YogEx 🌳

```text
                    ★
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

A graph algorithm library for Elixir, providing implementations of classic graph algorithms with a functional API. It acts as an ergonomic wrapper around the core implementation built in Gleam ([Yog](https://hex.pm/packages/yog)).

🔷 **Powered by [Yog](https://hex.pm/packages/yog)** — The same graph engine, with idiomatic Elixir APIs

## Features

- **Graph Data Structures**: Directed and undirected graphs with generic node and edge data
- **Pathfinding Algorithms**: Dijkstra, A*, Bellman-Ford, Floyd-Warshall, Johnson's, and **Implicit Variants** (state-space search)
- **Maximum Flow**: Highly optimized Edmonds-Karp algorithm with flat dictionary residuals
- **Graph Generators**: Create classic patterns (complete, cycle, path, star, wheel, bipartite, trees, grids) and random graphs (Erdős-Rényi, Barabási-Albert, Watts-Strogatz)
- **Graph Traversal**: BFS and DFS with early termination and path finding
- **Graph Transformations**: Transpose (O(1)!), map, filter, merge, subgraph extraction, edge contraction
- **Graph Operations**: Union, intersection, difference, Cartesian product, graph power, isomorphism
- **Graph Serialization & I/O**: First-class support for GraphML, GDF, JSON, LEDA, Pajek, and TGF allowing interoperability with standard tools via `Yog.IO.*`
- **Graph Visualization**: ASCII, Mermaid, and DOT (Graphviz) rendering
- **Minimum Spanning Tree**: Kruskal's and Prim's algorithms with Union-Find and Priority Queues
- **Minimum Cut**: Stoer-Wagner algorithm for global min-cut
- **Network Health**: Diameter, radius, eccentricity, assortativity, average path length
- **Centrality Measures**: PageRank, betweenness, closeness, harmonic, eigenvector, Katz, degree
- **Community Detection**: Louvain, Leiden, Label Propagation, Girvan-Newman, Infomap, Walktrap, Clique Percolation, Local Community, Fluid Communities
- **Community Metrics**: Modularity, clustering coefficients, density, triangle counts
- **DAG Operations**: Type-safe wrapper for directed acyclic graphs with longest path, LCA, transitive closure/reduction
- **Topological Sorting**: Kahn's algorithm with lexicographical variant
- **Strongly Connected Components**: Tarjan's and Kosaraju's algorithms
- **Maximum Clique**: Bron-Kerbosch algorithm for maximal and all maximal cliques
- **Connectivity**: Bridge and articulation point detection
- **Eulerian Paths & Circuits**: Detection and finding using Hierholzer's algorithm
- **Bipartite Graphs**: Detection, maximum matching, and stable marriage (Gale-Shapley)
- **Minimum Cost Flow (MCF)**: Global optimization using the robust Network Simplex algorithm
- **Graph Builders**: Grid builders (regular & toroidal), labeled builders, live/incremental builders
- **Disjoint Set (Union-Find)**: With path compression and union by rank
- **Efficient Data Structures**: Pairing heap for priority queues, two-list queue for BFS

## Installation

### Basic Installation

Add YogEx to your list of dependencies in `mix.exs` (or `Mix.install([...])` for LiveBook or Scripts):

```elixir
def deps do
  [
    {:yog_ex, "~> 0.52.3"},
    {:yog, "~> 5.1.1", manager: :rebar3, override: true},
    {:gleam_stdlib, "~> 0.69", manager: :rebar3, override: true},
  ]
end
```

Then run:

```bash
mix deps.get
```

### Graph I/O Support

YogEx includes comprehensive graph I/O modules (`Yog.IO.*`) for popular formats:

- **GraphML** - XML-based format (Gephi, yEd, Cytoscape, NetworkX)
- **GDF** - GUESS Graph Format (Gephi)
- **Pajek** - Social network analysis (.net format)
- **LEDA** - Library of Efficient Data types and Algorithms
- **TGF** - Trivial Graph Format
- **JSON** - Adjacency list and matrix formats

**All I/O modules are implemented in pure Elixir** and work out of the box with the base YogEx installation. No additional dependencies are required.

The previous `yog_io` Gleam package is no longer needed and has been fully replaced with native Elixir implementations.

## Quick Start

### Shortest Path

```elixir
# Create a directed graph
graph =
  Yog.directed()
  |> Yog.add_node(1, "Start")
  |> Yog.add_node(2, "Middle")
  |> Yog.add_node(3, "End")
  |> Yog.add_edge!(from: 1, to: 2, with: 5)
  |> Yog.add_edge!(from: 2, to: 3, with: 3)
  |> Yog.add_edge!(from: 1, to: 3, with: 10)

# Define a comparison function (Gleam-compatible)
compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end

# Find shortest path using Dijkstra
case Yog.Pathfinding.shortest_path(
  in: graph,
  from: 1,
  to: 3,
  zero: 0,
  add: &(&1 + &2),
  compare: compare
) do
  {:some, {:path, _nodes, total_weight}} ->
    IO.puts("Found path with weight: #{total_weight}")
    # => Found path with weight: 8

  :none ->
    IO.puts("No path found")
end
```

### Community Detection

```elixir
# Build a graph with two communities
graph =
  Yog.undirected()
  |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
  |> Yog.add_node(4, nil) |> Yog.add_node(5, nil) |> Yog.add_node(6, nil)
  |> Yog.add_edge!(from: 1, to: 2, with: 1)
  |> Yog.add_edge!(from: 2, to: 3, with: 1)
  |> Yog.add_edge!(from: 1, to: 3, with: 1)   # Triangle: 1-2-3
  |> Yog.add_edge!(from: 4, to: 5, with: 1)
  |> Yog.add_edge!(from: 5, to: 6, with: 1)
  |> Yog.add_edge!(from: 4, to: 6, with: 1)   # Triangle: 4-5-6
  |> Yog.add_edge!(from: 3, to: 4, with: 1)   # Bridge between communities

# Detect communities with Louvain
communities = Yog.Community.Louvain.detect(graph)
IO.puts("Found #{communities.num_communities} communities")

# Analyze community quality
modularity = Yog.Community.modularity(graph, communities)
IO.puts("Modularity: #{modularity}")
```

### Graph Generators

```elixir
# Classic graph patterns
complete = Yog.Generator.Classic.complete(10)       # K₁₀ complete graph
cycle = Yog.Generator.Classic.cycle(20)              # C₂₀ cycle graph
petersen = Yog.Generator.Classic.petersen()           # The famous Petersen graph
grid = Yog.Generator.Classic.grid_2d(5, 5)           # 5×5 grid lattice

# Random graph models
sparse = Yog.Generator.Random.erdos_renyi_gnp(100, 0.05)    # G(n,p) model
scale_free = Yog.Generator.Random.barabasi_albert(1000, 3)   # Preferential attachment
small_world = Yog.Generator.Random.watts_strogatz(100, 6, 0.1)  # Small-world
```

### Grid Builder (Maze Solving)

```elixir
# Build a maze from a 2D grid
maze = [
  [".", ".", "#", "."],
  [".", "#", "#", "."],
  [".", ".", ".", "."]
]

grid = Yog.Builder.Grid.from_2d_list(maze, :undirected, Yog.Builder.Grid.walkable("."))
graph = Yog.Builder.Grid.to_graph(grid)

# Find start and goal
{:ok, start} = Yog.Builder.Grid.find_node(grid, fn cell -> cell == "." end)

# Use Manhattan distance heuristic with A*
h = fn from_id, to_id ->
  Yog.Builder.Grid.manhattan_distance(from_id, to_id, 4)
end
```

### Labeled Graph Builder

```elixir
# Build graphs with meaningful labels instead of integer IDs
builder =
  Yog.Builder.Labeled.directed()
  |> Yog.Builder.Labeled.add_edge("London", "Paris", 450)
  |> Yog.Builder.Labeled.add_edge("Paris", "Berlin", 878)
  |> Yog.Builder.Labeled.add_edge("London", "Berlin", 930)

# Convert to graph for algorithms
graph = Yog.Builder.Labeled.to_graph(builder)

# Look up IDs by label
{:ok, london_id} = Yog.Builder.Labeled.get_id(builder, "London")
{:ok, berlin_id} = Yog.Builder.Labeled.get_id(builder, "Berlin")
```

### Graph Operations

```elixir
# Set-theoretic operations
union = Yog.Operation.union(graph_a, graph_b)
common = Yog.Operation.intersection(graph_a, graph_b)
diff = Yog.Operation.difference(graph_a, graph_b)

# Structural comparison
Yog.Operation.isomorphic?(triangle1, triangle2)  # => true
Yog.Operation.subgraph?(sub, full)                # => true

# Cartesian product (generates grid-like structures)
product = Yog.Operation.cartesian_product(path3, path4, 0, 0)
```

### Centrality Analysis

```elixir
graph =
  Yog.undirected()
  |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
  |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {1, 3, 1}])

# Various centrality measures
pagerank = Yog.Centrality.pagerank(graph)
betweenness = Yog.Centrality.betweenness(graph)
closeness = Yog.Centrality.closeness(graph)
degree = Yog.Centrality.degree(graph)
```

### Graph I/O & Interoperability

```elixir
# Create graph
graph =
  Yog.directed()
  |> Yog.add_node(1, "Alice")
  |> Yog.add_node(2, "Bob")
  |> Yog.add_edge!(from: 1, to: 2, with: "follows")

# Serialize to popular formats like GraphML, TGF, LEDA, Pajek, JSON, or GDF
graphml_string = Yog.IO.GraphML.serialize(graph)
json_string = Yog.IO.JSON.serialize(graph)
pajek_string = Yog.IO.Pajek.serialize(graph)

# Parse from string or read from file
{:ok, {:graphml_result, loaded_graph, _warnings}} = Yog.IO.GraphML.parse(graphml_string)

# Read directly from file
# {:ok, loaded} = Yog.IO.Pajek.read("network.net")
```

## Examples

Detailed examples are located in the [examples/](https://github.com/code-shoily/yog_ex/tree/main/examples) directory:

### Pathfinding & Optimization
- [GPS Navigation](examples/gps_navigation.exs) - Shortest path using A* and heuristics
- [City Distance Matrix](examples/city_distance_matrix.exs) - Floyd-Warshall for all-pairs shortest paths
- [Network Bandwidth](examples/network_bandwidth.exs) - ⭐ Max flow for bandwidth optimization with bottleneck analysis
- [Network Cable Layout](examples/network_cable_layout.exs) - Minimum Spanning Tree using Kruskal's

### Matching & Assignment
- [Job Matching](examples/job_matching.exs) - ⭐ Max flow for bipartite matching and assignment problems
- [Job Assignment](examples/job_assignment.exs) - Bipartite maximum matching
- [Medical Residency](examples/medical_residency.exs) - Stable marriage matching (Gale-Shapley algorithm)

### Graph Analysis
- [Social Network Analysis](examples/social_network_analysis.exs) - Finding communities using SCCs
- [Global Minimum Cut](examples/global_min_cut.exs) - Stoer-Wagner algorithm
- [Bridges of Königsberg](examples/bridges_of_konigsberg.exs) - Eulerian circuit and path detection

### Ordering & Scheduling
- [Task Scheduling](examples/task_scheduling.exs) - Basic topological sorting
- [Task Ordering](examples/task_ordering.exs) - Lexicographical topological sort

### Traversal & Exploration
- [Cave Path Counting](examples/cave_path_counting.exs) - Custom DFS with backtracking
- [Flood Fill](examples/flood_fill.exs) - BFS-based region exploration
- [Number of Islands](examples/number_of_islands.exs) - Connected component counting

### Graph Construction & Visualization
- [Graph Creation](examples/graph_creation.exs) - Comprehensive guide to 10+ ways of creating graphs
- [Graph Generation Showcase](examples/graph_generation_showcase.exs) - ⭐ All classic graph patterns with statistics
- [DOT rendering](examples/render_dot.exs) - Exporting graphs to Graphviz format
- [Mermaid rendering](examples/render_mermaid.exs) - Generating Mermaid diagrams
- [Graph I/O](examples/render_json.exs) - Exporting matrices and objects to JSON and other formats for interoperability

### Running Examples

```sh
mix run examples/gps_navigation.exs
mix run examples/network_bandwidth.exs
# etc.
```

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
| **Louvain** | Modularity optimization, large graphs | O(E log V) |
| **Leiden** | Quality guarantee, well-connected communities | O(E log V) |
| **Label Propagation** | Very large graphs, extreme speed | O(E) per iter |
| **Infomap** | Information-theoretic flow tracking | O(E) per iter |
| **Walktrap** | Random-walk structural communities | O(V² log V) |
| **Girvan-Newman** | Hierarchical edge betweenness | O(E²V) |
| **Clique Percolation** | Overlapping community discovery | O(3^(V/3)) |
| **Local Community** | Massive/infinite graphs, seed expansion | O(S × E_S) |
| **Fluid Communities** | Exact `k` partitions, fast | O(E) per iter |

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

## Performance Characteristics

- **Graph storage**: O(V + E)
- **Transpose**: O(1) — dramatically faster than typical O(E) implementations
- **Dijkstra/A***: O(V) for visited set and pairing heap
- **Maximum Flow**: Flat dictionary residuals with O(1) amortized BFS queue operations
- **Graph Generators**: O(V²) for complete graphs, O(V) or O(VE) for others
- **Stable Marriage**: O(n²) Gale-Shapley with deterministic proposal ordering
- **Test Suite**: 1000+ tests including doctests ensuring equivalence to the core Gleam suite

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

- `lib/yog/` — Core graph library modules (Elixir wrappers around Gleam)
- `test/` — Unit tests and doctests
- `examples/` — Real-world usage examples

### Publishing to Hex (For Maintainers)

Due to Gleam package requirements, publishing to Hex requires a special environment configuration.

**Pre-publishing checklist:**
1. Update version in `mix.exs` (`@version`)
2. Update `CHANGELOG.md` with release date and changes
3. Ensure version is consistent in README.md examples
4. Run `mix test` - all tests must pass
5. Run `mix credo --strict` - no issues
6. Update git: `git add .` and commit changes

**Publishing command:**
```sh
MIX_ENV=publish mix hex.publish package
```

**Why `MIX_ENV=publish`?**
- The `:publish` environment uses a simplified dependency configuration without `manager: :rebar3`
- Hex.pm doesn't allow `manager`, `app`, or `override` flags in published packages
- Local development (`:dev`, `:test`) still uses the full configuration with `manager: :rebar3, app: false, override: true`
- This is defined in `mix.exs` using `defp deps(env)` with pattern matching

**Documentation:** HexDocs automatically builds and publishes documentation from your package source code. No separate docs publishing step is needed - your docs will be available at `https://hexdocs.pm/yog_ex` shortly (5-15 minutes) after publishing the package.

**After publishing:**
1. Verify package: `mix hex.info yog_ex`
2. Check package page: https://hex.pm/packages/yog_ex
3. Wait for docs to build: https://hexdocs.pm/yog_ex
4. Tag the release: `git tag v0.52.2 && git push --tags`

## AI Assistance

Parts of this project were developed with the assistance of AI coding tools. All AI-generated code has been reviewed, tested, and validated by the maintainer.

---

**YogEx** — Graph algorithms for Elixir 🌳
