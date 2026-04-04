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

## Flow & Cuts

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Edmonds-Karp | `Yog.Flow.MaxFlow` | Maximum flow (BFS augmenting paths) | O(VE²) | O(V+E) |
| Dinic's | `Yog.Flow.MaxFlow` | Maximum flow (blocking flow) | O(V²E) | O(V+E) |
| Capacity Scaling | `Yog.Flow.MaxFlow` | Maximum flow (scaling) | O(E² log U) | O(V+E) |
| Successive Shortest Path | `Yog.Flow.SuccessiveShortestPath` | Min-cost max-flow | O(F · E log V) | O(V+E) |
| Network Simplex | `Yog.Flow.NetworkSimplex` | Global min-cost flow optimization | O(E) pivots | O(V+E) |
| Stoer-Wagner | `Yog.Flow.MinCut` | Global minimum cut | O(V³) | O(V²) |

## Minimum Spanning Tree

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Kruskal's | `Yog.MST` | MST via edge sorting | O(E log E) | O(V) |
| Prim's | `Yog.MST` | MST via vertex growing | O(E log V) | O(V) |
| Borůvka's | `Yog.MST` | Parallel MST | O(E log V) | O(V) |

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

## Traversal & Search

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| BFS | `Yog.Traversal` | Breadth-first exploration | O(V+E) | O(V) |
| DFS | `Yog.Traversal` | Depth-first exploration | O(V+E) | O(V) |
| Topological Sort | `Yog.Traversal` | DAG vertex ordering | O(V+E) | O(V) |
| Find Path | `Yog.Traversal` | Any path between nodes | O(V+E) | O(V) |
| Implicit Search | `Yog.Traversal.Implicit` | On-demand graph traversal | O((V+E) log V) | O(V) |

## Graph Properties

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Bipartite Check | `Yog.Property.Bipartite` | 2-colorability test | O(V+E) | O(V) |
| Bipartite Partition | `Yog.Property.Bipartite` | Two-color assignment | O(V+E) | O(V) |
| Max Bipartite Matching | `Yog.Property.Bipartite` | Maximum matching | O(VE) | O(V) |
| Acyclicity Test | `Yog.Property.Cyclicity` | Cycle detection | O(V+E) | O(V) |
| Eulerian Circuit | `Yog.Property.Eulerian` | Eulerian cycle existence | O(V+E) | O(V) |
| Eulerian Path | `Yog.Property.Eulerian` | Eulerian path existence | O(V+E) | O(V) |
| Bron-Kerbosch | `Yog.Property.Clique` | All maximal cliques | O(3^(V/3)) | O(V) |
| Max Clique | `Yog.Property.Clique` | Largest clique | O(3^(V/3)) | O(V) |
| Complete Graph | `Yog.Property.Structure` | Kₙ detection | O(V²) | O(1) |
| Tree Check | `Yog.Property.Structure` | Tree verification | O(V+E) | O(V) |
| Arborescence | `Yog.Property.Structure` | Directed tree check | O(V+E) | O(V) |

## DAG Algorithms

| Algorithm | Module | Purpose | Time Complexity | Space Complexity |
|-----------|--------|---------|-----------------|------------------|
| Longest Path | `Yog.DAG.Algorithm` | Critical path in weighted DAG | O(V+E) | O(V) |
| Shortest Path | `Yog.DAG.Algorithm` | Shortest path in DAG | O(V+E) | O(V) |
| Transitive Closure | `Yog.Transform` | Reachability matrix | O(V³) | O(V²) |
| Transitive Reduction | `Yog.Transform` | Minimal equivalent DAG | O(V³) | O(V²) |
| LCA | `Yog.DAG.Algorithm` | Lowest common ancestors | O(V(V+E)) | O(V) |

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

## Data Structures

| Structure | Module | Purpose | Operations | Space |
|-----------|--------|---------|------------|-------|
| Pairing Heap | `Yog.PriorityQueue` | Priority queue for Dijkstra/Prim | insert: O(1), delete-min: O(log n) amortized | O(n) |
| Disjoint Set | `Yog.DisjointSet` | Union-Find for Kruskal/SCC | find: O(α(n)), union: O(α(n)) | O(n) |
| HyperLogLog | `Yog.Connectivity.Reachability` | Cardinality estimation | add: O(1), count: O(1) | O(1) fixed |
| :queue | Erlang stdlib | FIFO for BFS | enqueue/dequeue: O(1) | O(n) |

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
