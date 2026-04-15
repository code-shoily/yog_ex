# Algorithm Catalog

Complete reference of all algorithms implemented in YogEx, organized by category.

## Pathfinding

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Dijkstra | `Yog.Pathfinding.Dijkstra` | Single-source shortest path (non-negative weights) | O((V+E) log V) | O(V) |
| A* | `Yog.Pathfinding.AStar` | Heuristic-guided shortest path | O((V+E) log V) | O(V) |
| Bellman-Ford | `Yog.Pathfinding.BellmanFord` | Shortest path with negative weights, cycle detection | O(VE) | O(V) |
| Floyd-Warshall | `Yog.Pathfinding.FloydWarshall` | All-pairs shortest paths | O(V³) | O(V²) |
| Johnson's | `Yog.Pathfinding.Johnson` | All-pairs shortest paths in sparse graphs | O(V² log V + VE) | O(V²) |
| Bidirectional Dijkstra | `Yog.Pathfinding.Bidirectional` | Faster single-pair shortest path | O((V+E) log V) | O(V) |
| Bidirectional BFS | `Yog.Pathfinding.Bidirectional` | Unweighted shortest path | O(V+E) | O(V) |
| Yen's K-Shortest | `Yog.Pathfinding.Yen` | k shortest loopless paths | O(k·N·(E+V log V)) | O(kV) |
| Widest Path | `Yog.Pathfinding` | Maximum bottleneck capacity path | O((V+E) log V) | O(V) |
| Unweighted SSSP | `Yog.Pathfinding` | BFS shortest path (no heap) | O(V+E) | O(V) |
| LCA (Binary Lifting) | `Yog.Pathfinding.LCA` | Lowest common ancestor in trees | O(V log V) preprocess, O(log V) query | O(V log V) |

## Flow & Cuts

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Edmonds-Karp | `Yog.Flow.MaxFlow` | Maximum flow (BFS augmenting paths) | O(VE²) | O(V+E) |
| Dinic's | `Yog.Flow.MaxFlow` | Maximum flow (blocking flow) | O(V²E) | O(V+E) |
| Capacity Scaling | `Yog.Flow.MaxFlow` | Maximum flow (scaling) | O(E² log U) | O(V+E) |
| Dinic's | `Yog.Flow.MaxFlow` | Maximum flow (blocking flow) | O(V²E) | O(V+E) |
| Successive Shortest Path | `Yog.Flow.SuccessiveShortestPath` | Min-cost max-flow | O(F · E log V) | O(V+E) |
| Stoer-Wagner | `Yog.Flow.MinCut` | Global minimum cut | O(V³) | O(V²) |

## Spanning Tree

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Kruskal's | `Yog.MST` | MST via edge sorting | O(E log E) | O(V) |
| Prim's | `Yog.MST` | MST via vertex growing | O(E log V) | O(V) |
| Borůvka's | `Yog.MST` | Parallel MST | O(E log V) | O(V) |
| Edmonds' | `Yog.MST` | Minimum Spanning Arborescence (Directed) | O(VE) | O(V) |
| Wilson's | `Yog.MST` | Uniform Spanning Tree (Probabilistic) | O(V) hit time | O(V) |
| **Max Spanning Tree** | `Yog.MST` | Maximum weight tree | O(E log E) | O(V) |

## Matching

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Hopcroft-Karp | `Yog.Matching` | Maximum bipartite matching | O(E√V) | O(V) |

## Connectivity & Components

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Tarjan's SCC | `Yog.Connectivity` | Strongly connected components | O(V+E) | O(V) |
| Kosaraju's SCC | `Yog.Connectivity` | Strongly connected components (two-pass) | O(V+E) | O(V) |
| Connected Components | `Yog.Connectivity` | Undirected connected components | O(V+E) | O(V) |
| Tarjan's Bridges | `Yog.Connectivity.Bridge` | Bridge edges | O(V+E) | O(V) |
| Tarjan's Articulation | `Yog.Connectivity.Articulation` | Articulation points | O(V+E) | O(V) |
| K-Core | `Yog.Connectivity.KCore` | Core decomposition | O(V+E) | O(V) |
| Reachability Exact | `Yog.Connectivity.Reachability` | Ancestor/descendant counting | O(V+E) | O(V²) |
| Reachability HLL | `Yog.Connectivity.Reachability` | HyperLogLog reachability estimation | O(V+E) | O(V) |

## Centrality Measures

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Degree Centrality | `Yog.Centrality` | Simple connectivity importance | O(V+E) | O(V) |
| Closeness Centrality | `Yog.Centrality` | Distance-based importance | O(VE + V² log V) | O(V) |
| Harmonic Centrality | `Yog.Centrality` | Distance-based (handles infinite) | O(VE + V² log V) | O(V) |
| Betweenness Centrality | `Yog.Centrality` | Bridge/gatekeeper detection | O(VE) or O(V³) | O(V²) |
| PageRank | `Yog.Centrality` | Link-quality importance | O(k(V+E)) | O(V) |
| Eigenvector Centrality | `Yog.Centrality` | Influence from neighbors | O(k(V+E)) | O(V) |
| Katz Centrality | `Yog.Centrality` | Attenuated influence propagation | O(k(V+E)) | O(V) |
| Alpha Centrality | `Yog.Centrality` | External influence model | O(k(V+E)) | O(V) |

## Community Detection

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Louvain | `Yog.Community.Louvain` | Modularity optimization | O(E log V) | O(V) |
| Leiden | `Yog.Community.Leiden` | Quality-guaranteed communities | O(E log V) | O(V) |
| Label Propagation | `Yog.Community.LabelPropagation` | Very large graphs, speed | O(kE) | O(V) |
| Walktrap | `Yog.Community.Walktrap` | Random-walk communities | O(V² log V) | O(V²) |
| Infomap | `Yog.Community.Infomap` | Information-theoretic | O(kE) | O(V) |
| Girvan-Newman | `Yog.Community.GirvanNewman` | Hierarchical edge betweenness | O(E²V) | O(V²) |
| Clique Percolation | `Yog.Community.CliquePercolation` | Overlapping communities | O(3^(V/3)) | O(V²) |
| Fluid Communities | `Yog.Community.FluidCommunities` | Exact k partitions | O(kE) | O(V) |
| Local Community | `Yog.Community.LocalCommunity` | Seed expansion | O(S × E_S) | O(S) |

## Community Metrics

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Transitivity | `Yog.Community.Metrics` | Global clustering coefficient | O(Δ²E) | O(V) |

## Traversal & Search

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| BFS | `Yog.Traversal` | Breadth-first exploration | O(V+E) | O(V) |
| DFS | `Yog.Traversal` | Depth-first exploration | O(V+E) | O(V) |
| Topological Sort | `Yog.Traversal` | DAG vertex ordering | O(V+E) | O(V) |
| Find Path | `Yog.Traversal` | Any path between nodes | O(V+E) | O(V) |
| Implicit Search | `Yog.Traversal.Implicit` | On-demand graph traversal | O((V+E) log V) | O(V) |

## Graph Transformations

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Transpose | `Yog.Transform` | Reverse edge directions | O(1) | O(1) |
| Subgraph | `Yog.Transform` | Induced subgraph by node IDs | O(V+E) | O(V+E) |
| Ego Graph | `Yog.Transform` | k-hop neighborhood subgraph | O(V+E) | O(V+E) |
| Transitive Closure | `Yog.Transform` | Reachability matrix | O(V³) | O(V²) |
| Transitive Reduction | `Yog.Transform` | Minimal equivalent DAG | O(V³) | O(V²) |
| Quotient Graph | `Yog.Transform` | Partition-based contraction | O(V+E) | O(V+E) |
| Contract | `Yog.Transform` | Merge two nodes | O(deg(u)+deg(v)) | O(V+E) |
| Filter Nodes | `Yog.Transform` | Predicate-based subgraph | O(V+E) | O(V+E) |
| Filter Edges | `Yog.Transform` | Predicate-based edge removal | O(E) | O(E) |

## Graph Properties

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Bipartite Check | `Yog.Property.Bipartite` | 2-colorability test | O(V+E) | O(V) |
| Bipartite Partition | `Yog.Property.Bipartite` | Two-color assignment | O(V+E) | O(V) |
| Max Bipartite Matching | `Yog.Property.Bipartite` | Maximum matching | O(VE) | O(V) |
| Stable Marriage | `Yog.Property.Bipartite` | Gale-Shapley stable matching | O(V²) | O(V) |
| Acyclicity Test | `Yog.Property.Cyclicity` | Cycle detection | O(V+E) | O(V) |
| Eulerian Circuit | `Yog.Property.Eulerian` | Eulerian cycle existence | O(V+E) | O(V) |
| Eulerian Path | `Yog.Property.Eulerian` | Eulerian path existence | O(V+E) | O(V) |
| Bron-Kerbosch | `Yog.Property.Clique` | All maximal cliques | O(3^(V/3)) | O(V) |
| Max Clique | `Yog.Property.Clique` | Largest clique | O(3^(V/3)) | O(V) |
| Complete Graph | `Yog.Property.Structure` | Kₙ detection | O(V²) | O(1) |
| Tree Check | `Yog.Property.Structure` | Tree verification | O(V+E) | O(V) |
| Forest Check | `Yog.Property.Structure` | Disjoint trees | O(V+E) | O(V) |
| Branching Check | `Yog.Property.Structure` | Directed forest | O(V+E) | O(V) |
| Planarity Test | `Yog.Property.Structure` | Exact LR-test planarity | O(V²) | O(V) |
| Planar Embedding | `Yog.Property.Structure` | Combinatorial embedding | O(V²) | O(V) |
| Kuratowski Witness | `Yog.Property.Structure` | Non-planar subgraph | O(V²) | O(V) |
| Chordality Test | `Yog.Property.Structure` | Chordal graph verification | O(V+E) | O(V) |
| Isomorphism | `Yog.Property` | Weisfeiler-Lehman equality | O(k(V+E)) | O(V) |
| Graph Hash | `Yog.Property` | Structural fingerprint | O(k(V+E)) | O(V) |

## DAG Algorithms

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Longest Path | `Yog.DAG.Algorithm` | Critical path in weighted DAG | O(V+E) | O(V) |
| Shortest Path | `Yog.DAG.Algorithm` | Shortest path in DAG | O(V+E) | O(V) |
| Transitive Closure | `Yog.Transform` | Reachability matrix | O(V³) | O(V²) |
| Transitive Reduction | `Yog.Transform` | Minimal equivalent DAG | O(V³) | O(V²) |
| LCA | `Yog.Pathfinding.LCA` | Lowest common ancestors | O(V log V) preprocess, O(log V) query | O(V log V) |

## Graph Operations

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Union | `Yog.Operation` | Graph union | O(V+E) | O(V+E) |
| Intersection | `Yog.Operation` | Graph intersection | O(V+E) | O(V+E) |
| Difference | `Yog.Operation` | Graph difference | O(V+E) | O(V+E) |
| Symmetric Difference | `Yog.Operation` | XOR of graphs | O(V+E) | O(V+E) |
| Cartesian Product | `Yog.Operation` | Graph product | O(V₁V₂ + E₁E₂) | O(V₁V₂) |
| Power Graph | `Yog.Operation` | k-th power | O(k(V+E)) | O(V+E) |
| Line Graph | `Yog.Operation` | Edge-to-vertex dual | O(V+E) | O(E) |
| Transpose | `Yog.Operation` | Reverse all edges | O(V+E) | O(V+E) |
| Isomorphism | `Yog.Operation` | Graph equality | O(V!) worst | O(V) |
| Subgraph | `Yog.Operation` | Induced subgraph | O(V+E) | O(V+E) |
| Subgraph Check | `Yog.Operation` | Subgraph relationship | O(V+E) | O(V+E) |

## Multigraph

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Eulerian Circuit | `Yog.Multi.Eulerian` | Hierholzer with edge IDs | O(V+E) | O(V+E) |
| Eulerian Path | `Yog.Multi.Eulerian` | Open Eulerian walk | O(V+E) | O(V+E) |
| BFS | `Yog.Multi.Traversal` | Edge-ID aware BFS | O(V+E) | O(V) |
| DFS | `Yog.Multi.Traversal` | Edge-ID aware DFS | O(V+E) | O(V) |
| Fold Walk | `Yog.Multi.Traversal` | Stateful traversal | O(V+E) | O(V) |

## Health Metrics

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Diameter | `Yog.Health` | Longest shortest path | O(V(V+E)) | O(V) |
| Radius | `Yog.Health` | Minimum eccentricity | O(V(V+E)) | O(V) |
| Eccentricity | `Yog.Health` | Max distance from node | O(V+E) | O(V) |
| Assortativity | `Yog.Health` | Degree correlation | O(E) | O(1) |
| APL | `Yog.Health` | Average path length | O(V(V+E)) | O(V) |
| Global Efficiency | `Yog.Health` | Inverse mean distance | O(V(V+E)) | O(V) |
| Local Efficiency | `Yog.Health` | Neighborhood efficiency | O(V(V+E)) | O(V) |

## Data Structures

| Structure | Module | Purpose | Operations | Space |
|-----------|--------|---------|------------|-------|
| Pairing Heap | `Yog.PriorityQueue` | Priority queue for Dijkstra/Prim | insert: O(1), delete-min: O(log n) amortized | O(n) |
| Disjoint Set | `Yog.DisjointSet` | Union-Find for Kruskal/SCC | find: O(α(n)), union: O(α(n)) | O(n) |
| HyperLogLog | `Yog.Connectivity.Reachability` | Cardinality estimation | add: O(1), count: O(1) | O(1) fixed |
| :queue | Erlang stdlib | FIFO for BFS | enqueue/dequeue: O(1) | O(n) |

## Maze Generation

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Lollipop | `Yog.Generator.Classic` | Kₘ connected to Pₙ | O(m+n) | O(m+n) |
| Barbell | `Yog.Generator.Classic` | Two cliques + path | O(m+n) | O(m+n) |
| Tutte Graph | `Yog.Generator.Classic` | Non-Hamiltonian polyhedral | O(1) | O(1) |
| Sedgewick Maze | `Yog.Generator.Classic` | Classic 8-node maze | O(1) | O(1) |
| Binary Tree | `Yog.Generator.Maze` | Simplest, fastest | O(N) | O(1) |
| Sidewinder | `Yog.Generator.Maze` | Vertical corridors | O(N) | O(cols) |
| Recursive Backtracker | `Yog.Generator.Maze` | Classic "roguelike" passages | O(N) | O(N) |
| Hunt-and-Kill | `Yog.Generator.Maze` | Organic, winding | O(N²) | O(1) |
| Aldous-Broder | `Yog.Generator.Maze` | Uniform spanning tree | O(N²) | O(N) |
| Wilson's | `Yog.Generator.Maze` | Efficient uniform tree | O(N) avg | O(N) |

## Approximation Algorithms

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Diameter | `Yog.Approximate` | Multi-sweep lower bound | O(k(V+E)) | O(V) |
| Betweenness | `Yog.Approximate` | Sampled Brandes | O(k(V+E)) | O(V) |
| Avg Path Length | `Yog.Approximate` | Pivot sampling | O(k(V+E)) | O(V) |
| Global Efficiency | `Yog.Approximate` | Pivot sampling | O(k(V+E)) | O(V) |
| Transitivity | `Yog.Approximate` | Wedge sampling | O(k) | O(V) |
| Vertex Cover | `Yog.Approximate` | Greedy 2-approximation | O(V+E) | O(V) |
| Max Clique | `Yog.Approximate` | Greedy heuristic | O(V²) | O(V) |
| Kruskal's | `Yog.Generator.Maze` | Balanced, randomized | O(N log N) | O(N) |
| Prim's | `Yog.Generator.Maze` | Radial, many dead ends | O(N log N) | O(N) |
| Eller's | `Yog.Generator.Maze` | Infinite height potential | O(N) | O(cols) |
| Growing Tree | `Yog.Generator.Maze` | Meta-algorithm (versatile) | O(N) | O(N) |
| Recursive Division | `Yog.Generator.Maze` | Fractal, room-based | O(N log N) | O(log N) |

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

## Legend

- **V**: Number of vertices/nodes
- **E**: Number of edges
- **k**: Number of iterations (for iterative algorithms)
- **α(n)**: Inverse Ackermann function (effectively constant < 5)
- **O(V!)**: Factorial worst case (isomorphism via brute force)

## Algorithm Selection Guide

### Shortest Path

| Scenario | Algorithm |
|----------|-----------|
| Non-negative weights, single pair | Dijkstra |
| Non-negative weights, all pairs | Johnson's (sparse) or Floyd-Warshall (dense) |
| Negative weights allowed | Bellman-Ford |
| Negative cycle detection | Bellman-Ford or Floyd-Warshall |
| Heuristic available | A* |
| Unweighted graph | BFS or Bidirectional BFS |

### Community Detection

| Scenario | Algorithm |
|----------|-----------|
| Large graph, speed priority | Label Propagation |
| Quality guarantee needed | Leiden |
| Modularity optimization | Louvain |
| Overlapping communities | Clique Percolation |
| Exact k partitions | Fluid Communities |
| Hierarchical structure | Girvan-Newman |

### Flow Problems

| Scenario | Algorithm |
|----------|-----------|
| Max flow, general case | Dinic's or Capacity Scaling |
| Min-cost max-flow | Successive Shortest Path |
| Global min cut | Stoer-Wagner |
| Network optimization | Network Simplex |

### Centrality

| Scenario | Measure |
|----------|---------|
| Simple importance | Degree |
| Distance-based | Closeness or Harmonic |
| Bridge detection | Betweenness |
| Link quality | PageRank |
