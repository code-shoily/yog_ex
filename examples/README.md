# YogEx Examples

This directory contains practical examples demonstrating various features of the YogEx graph library.

## Table of Contents

- [Pathfinding](#pathfinding) - Shortest path algorithms
- [Community Detection](#community-detection) - Finding clusters in graphs
- [Graph Generators](#graph-generators) - Creating graphs programmatically
- [Grid Builder](#grid-builder) - Maze solving with 2D grids
- [Labeled Graph Builder](#labeled-graph-builder) - Human-readable node labels
- [Centrality Analysis](#centrality-analysis) - Measuring node importance
- [Graph I/O](#graph-io) - Importing and exporting graphs
- [Functional Graphs](#functional-graphs) - Pure functional graph operations
- [Running Examples](#running-examples)

---

## Pathfinding

Find the shortest path between nodes using Dijkstra's algorithm.

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

**Related file**: `gps_navigation.exs`

---

## Community Detection

Identify natural clusters in a social network using the Louvain algorithm.

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

**Related files**: `zacharys_karate_club.exs`, `social_network_analysis.exs`

---

## Graph Generators

Create common graph patterns and random graphs for testing and benchmarking.

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

**Related file**: `graph_generation_showcase.exs`

---

## Grid Builder

Solve mazes and pathfinding problems on 2D grids.

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

**Related file**: `maze_solver.exs`

---

## Labeled Graph Builder

Work with human-readable labels instead of integer IDs.

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

**Related file**: `gps_navigation.exs`

---

## Centrality Analysis

Measure the importance of nodes in a network.

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

**Related file**: `zacharys_karate_club.exs`

---

## Graph I/O

Import and export graphs in various formats.

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

**Related files**: `render_dot.exs`, `render_json.exs`, `render_mermaid.exs`

---

## Functional Graphs

Use pure functional graph operations with inductive decomposition (Experimental).

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

See the [Functional Graphs README](../lib/yog/functional/README.md) for a deep dive into the build/burn pattern, context-based traversal, and the philosophy of inductive graph decomposition.

**Related file**: `functional_example.exs`

---

## Running Examples

To run any example:

```sh
# From the project root
mix run examples/gps_navigation.exs
mix run examples/network_bandwidth.exs
mix run examples/maze_solver.exs
# etc.
```

## Available Example Files

| File | Description |
|------|-------------|
| `gps_navigation.exs` | Shortest path with labeled cities using Dijkstra |
| `network_bandwidth.exs` | Maximum flow for network optimization |
| `social_network_analysis.exs` | Finding strong components in social graphs |
| `zacharys_karate_club.exs` | Louvain community detection on Karate Club dataset |
| `maze_solver.exs` | Solving a grid maze using BFS/DFS |
| `maze_solver_directional.exs` | Solving a grid maze with directional constraints |
| `graph_creation.exs` | Manually building and querying graphs |
| `graph_generation_showcase.exs` | Showcasing classic generators (cliques, cycles, grids) |
| `functional_example.exs` | Pure functional graph operations (experimental) |
| `render_dot.exs` | Exporting graphs to Graphviz DOT format |
| `render_json.exs` | Serializing/deserializing graphs to JSON |
| `render_mermaid.exs` | Rendering graphs using Mermaid.js syntax |
| `ascii_maze.exs` | Generating and printing ASCII mazes |
| `bridges_of_konigsberg.exs` | Modeling the Seven Bridges of Königsberg |
| `cave_path_counting.exs` | Custom backtracking DFS path counting |
| `city_distance_matrix.exs` | Shortest paths matrix on city networks |
| `flood_fill.exs` | BFS-based grid flood fill example |
| `global_min_cut.exs` | Computing global min-cut on flow networks |
| `job_assignment.exs` | Bipartite matching for job assignment |
| `job_matching.exs` | Stable marriage/matching with Gale-Shapley |
| `medical_residency.exs` | Gale-Shapley matching for residency matching |
| `maze_gallery.exs` | Maze generator comparison and generation |
| `network_cable_layout.exs` | Spanning trees for cable layouts |
| `number_of_islands.exs` | BFS-based grid island counting |
| `task_ordering.exs` | Resolving dependencies with topological sort |
| `task_scheduling.exs` | Critical path method for scheduling |

---

For more information, see the [main README](../README.md) or the [API documentation](https://hexdocs.pm/yog_ex/).
