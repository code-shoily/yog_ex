# YogEx 🌳

[![Hex Version](https://img.shields.io/hexpm/v/yog_ex.svg)](https://hex.pm/packages/yog_ex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/yog_ex/)

A graph algorithm library for Elixir, providing implementations of classic graph algorithms with a functional API. It acts as an ergonomic wrapper around the core implementation built in Gleam ([Yog](https://hex.pm/packages/yog)).

## Features

- **Graph Data Structures**: Directed and undirected graphs with generic node and edge data
- **Pathfinding Algorithms**: Dijkstra, A*, Bellman-Ford, Floyd-Warshall
- **Maximum Flow**: Highly optimized Edmonds-Karp algorithm with flat dictionary residuals
- **Graph Generators**: Create classic patterns (complete, cycle, path, star, wheel, bipartite, trees, grids) and random graphs (Erdős-Rényi, Barabási-Albert, Watts-Strogatz)
- **Graph Traversal**: BFS and DFS with early termination support
- **Graph Transformations**: Transpose (O(1)!), map, filter, merge, subgraph extraction, edge contraction
- **Graph Visualization**: Mermaid, DOT (Graphviz), and JSON rendering
- **Minimum Spanning Tree**: Kruskal's algorithm with Union-Find
- **Minimum Cut**: Stoer-Wagner algorithm for global min-cut
- **Topological Sorting**: Kahn's algorithm with lexicographical variant
- **Strongly Connected Components**: Tarjan's algorithm
- **Connectivity**: Bridge and articulation point detection
- **Eulerian Paths & Circuits**: Detection and finding using Hierholzer's algorithm
- **Bipartite Graphs**: Detection, maximum matching, and stable marriage (Gale-Shapley)
- **Disjoint Set (Union-Find)**: With path compression and union by rank
- **Efficient Data Structures**: Pairing heap for priority queues, two-list queue for BFS

## Installation

Add YogEx to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:yog_ex, "~> 1.1.0"}
  ]
end
```

## Quick Start

```elixir
defmodule GraphExample do
  def run do
    # Create a directed graph
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "Middle")
      |> Yog.add_node(3, "End")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 3)
      |> Yog.add_edge(from: 1, to: 3, with: 10)

    # Find shortest path
    result = Yog.Pathfinding.shortest_path(
      in: graph,
      from: 1,
      to: 3,
      zero: 0,
      add: &(&1 + &2),
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
    )
    
    case result do
      {:some, {:path, _nodes, total_weight}} ->
        IO.puts("Found path with weight: #{total_weight}")
      :none ->
        IO.puts("No path found")
    end
  end
end
```

## Examples

Detailed examples are located in the [examples/](https://github.com/code-shoily/yog_ex/tree/main/examples) directory:

- [Social Network Analysis](examples/social_network_analysis.exs) - Finding communities using SCCs.
- [Task Scheduling](examples/task_scheduling.exs) - Basic topological sorting.
- [GPS Navigation](examples/gps_navigation.exs) - Shortest path using A* and heuristics.
- [Network Cable Layout](examples/network_cable_layout.exs) - Minimum Spanning Tree using Kruskal's.
- [Network Bandwidth](examples/network_bandwidth.exs) - ⭐ Max flow for bandwidth optimization with bottleneck analysis.
- [Job Matching](examples/job_matching.exs) - ⭐ Max flow for bipartite matching and assignment problems.
- [Cave Path Counting](examples/cave_path_counting.exs) - Custom DFS with backtracking.
- [Task Ordering](examples/task_ordering.exs) - Lexicographical topological sort.
- [Bridges of Königsberg](examples/bridges_of_konigsberg.exs) - Eulerian circuit and path detection.
- [Global Minimum Cut](examples/global_min_cut.exs) - Stoer-Wagner algorithm.
- [Job Assignment](examples/job_assignment.exs) - Bipartite maximum matching.
- [Medical Residency](examples/medical_residency.exs) - Stable marriage matching (Gale-Shapley algorithm).
- [City Distance Matrix](examples/city_distance_matrix.exs) - Floyd-Warshall for all-pairs shortest paths.
- [Graph Generation Showcase](examples/graph_generation_showcase.exs) - ⭐ All 9 classic graph patterns with statistics.
- [DOT rendering](examples/render_dot.exs) - Exporting graphs to Graphviz format.
- [Mermaid rendering](examples/render_mermaid.exs) - Generating Mermaid diagrams.
- [JSON rendering](examples/render_json.exs) - Exporting graphs to JSON for web use.
- [Graph creation](examples/graph_creation.exs) - Comprehensive guide to 10+ ways of creating graphs.

## Algorithm Selection Guide

Detailed documentation for each algorithm can be found on [HexDocs](https://hexdocs.pm/yog_ex/).

| Algorithm | Use When | Time Complexity |
| ----------- | ---------- | ---------------- |
| **Dijkstra** | Non-negative weights, single shortest path | O((V+E) log V) |
| **A*** | Non-negative weights + good heuristic | O((V+E) log V) |
| **Bellman-Ford** | Negative weights OR cycle detection needed | O(VE) |
| **Floyd-Warshall** | All-pairs shortest paths, distance matrices | O(V³) |
| **Edmonds-Karp** | Maximum flow, bipartite matching, network optimization | O(VE²) |
| **BFS/DFS** | Unweighted graphs, exploring reachability | O(V+E) |
| **Kruskal's MST** | Finding minimum spanning tree | O(E log E) |
| **Stoer-Wagner** | Global minimum cut, graph partitioning | O(V³) |
| **Tarjan's SCC** | Finding strongly connected components | O(V+E) |
| **Tarjan's Connectivity** | Finding bridges and articulation points | O(V+E) |
| **Hierholzer** | Eulerian paths/circuits, route planning | O(V+E) |
| **Topological Sort** | Ordering tasks with dependencies | O(V+E) |
| **Gale-Shapley** | Stable matching, college admissions, medical residency | O(n²) |

## Performance Characteristics

- **Graph storage**: O(V + E)
- **Transpose**: O(1) - dramatically faster than typical O(E) implementations
- **Dijkstra/A***: O(V) for visited set and pairing heap
- **Maximum Flow**: Flat dictionary residuals with O(1) amortized BFS queue operations
- **Graph Generators**: O(V²) for complete graphs, O(V) or O(VE) for others
- **Stable Marriage**: O(n²) Gale-Shapley with deterministic proposal ordering
- **Test Suite**: Hundreds of tests ensuring equivalence to the core Gleam suite 

---

**YogEx** - Graph algorithms for Elixir 🌳
