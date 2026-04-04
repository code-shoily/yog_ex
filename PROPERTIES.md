# Property-Based Testing Catalog

This document lists the algorithmic invariants (hypotheses) verified by `Yog`'s property-based testing suite. We use `StreamData` to generate thousands of random graph structures to ensure these properties hold across all possible edge cases, including sparse, dense, disconnected, and cyclic graphs.

**Location**: All property-based tests are in `test/yog/pbt/`.

## Connectivity and Components

**File**: `test/yog/pbt/component_test.exs`

- **SCC Partitioning**: Strongly Connected Components must partition the set of all nodes exactly. Every node belongs to one and only one SCC.
- **MST Algorithm Agreement**: Kruskal and Prim algorithms must produce the same total weight for connected undirected graphs.

**File**: `test/yog/pbt/k_core_test.exs`

- **k-core Degree**: Every node in a $k$-core must have degree at least $k$ within that subgraph.
- **Core Number Consistency**: A node with core number $k$ must exist in the $k$-core but not in the $(k+1)$-core.
- **Complete Graph Core**: A complete graph $K_n$ has a $(n-1)$-core containing all nodes.

**File**: `test/yog/pbt/bipartite_test.exs`

- **Bipartite Verification**: Graphs identified as bipartite must be 2-colorable with no monochromatic edges.
- **Matching Bound**: Maximum matching size cannot exceed the minimum partition size.

**File**: `test/yog/pbt/clique_test.exs`

- **Disjoint Cliques**: Generated disjoint cliques produce the expected number of maximal cliques.

---

## Pathfinding and Flow

**File**: `test/yog/pbt/pathfinding_test.exs`

- **Dijkstra-BFS Agreement**: Dijkstra agrees with BFS on the shortest path distance for unweighted graphs.
- **Algorithm Consistency**: Dijkstra, Bellman-Ford, and A* (with zero heuristic) must agree on shortest path weights for non-negative weights.
- **Negative Cycle Detection**: Bellman-Ford correctly identifies graphs containing reachable negative cycles.
- **Bidirectional Correctness**: Bidirectional Dijkstra yields the same path distance as standard Dijkstra.
- **Floyd-Warshall Agreement**: Floyd-Warshall agrees with repeated Dijkstra runs for all-pairs shortest paths.
- **All-Pairs Unweighted Self-Distances**: Self-distances are always zero.
- **All-Pairs Unweighted Symmetry**: Distances are symmetric in undirected graphs.
- **All-Pairs Unweighted Triangle Inequality**: $d(a,c) \leq d(a,b) + d(b,c)$ for all reachable triples.
- **All-Pairs Unweighted BFS Consistency**: All-pairs results match single-source BFS distances.
- **All-Pairs Unweighted Floyd-Warshall Consistency**: All-pairs results match Floyd-Warshall on unit weights.
- **All-Pairs Reachability Transitivity**: If $a$ reaches $b$ and $b$ reaches $c$, then $a$ reaches $c$.

**File**: `test/yog/pbt/flow_test.exs`

- **Max-Flow Min-Cut Theorem**: The maximum flow value equals the minimum cut capacity.
- **Flow Conservation**: At every node except source and sink, total in-flow equals total out-flow.
- **Integrality**: Integer capacities yield integer max flow.
- **Residual Graph Termination**: After max flow, no augmenting path exists in the residual graph.
- **Zero Flow on Disconnected**: Max flow is zero between disconnected components.

---

## Centrality Measures

**File**: `test/yog/pbt/centrality_test.exs`

- **Star Graph Centrality**: In a star graph, the center node has strictly higher centrality (Degree, Closeness, Betweenness, PageRank, Eigenvector) than any leaf node.
- **PageRank Unity**: The sum of PageRank scores across all nodes equals exactly 1.0.

---

## Graph Operations

**File**: `test/yog/pbt/operation_test.exs`

- **Union**: Union contains all nodes and edges from both graphs.
- **Intersection Idempotence**: Intersection of a graph with itself equals the graph.
- **Difference Annihilation**: Difference of a graph with itself is empty.
- **Disjoint Union Re-indexing**: Disjoint union correctly re-indexes to avoid collisions.
- **Isomorphism Reflexivity**: A graph is isomorphic to itself.
- **Power Identity**: Power of a graph to 1 equals the graph.
- **Cartesian Product Order**: Node count equals product of operand node counts.
- **Subgraph Reflexivity**: Subgraph relation is reflexive.
- **Symmetric Difference Commutativity**: Symmetric difference is commutative.
- **Symmetric Difference Exclusivity**: Resulting edges are in exactly one input graph.
- **Line Graph Node Count**: Equals edge count of original graph.
- **Line Graph Edge Count**: Matches theoretical formula for undirected and directed graphs.

**File**: `test/yog/pbt/transform_test.exs`

- **Transpose Involutivity**: `transpose(transpose(G)) == G`.
- **Map-Nodes Identity**: `map_nodes(G, id) == G`.
- **Map-Nodes Composition**: `map(f) . map(g) == map(g . f)`.
- **Map-Nodes Topology Preservation**: Node and edge counts are preserved.
- **Map-Edges Identity**: `map_edges(G, id) == G`.
- **Filter-Nodes Consistency**: Filtering removes associated edges and preserves remaining structure.
- **Merge Idempotence**: `merge(G, G) == G`.
- **Subgraph Invariants**: All edges connect nodes within the subset.
- **Filter-Edges Consistency**: Node count preserved, edge count non-increasing.
- **Complement Invariants**: Same nodes, complement of complement (minus self-loops) equals original.
- **To-Directed/Undirected Invariants**: Type conversion preserves node counts.
- **Contract Node Reduction**: Contracting two distinct nodes reduces count by 1.
- **Transitive Closure/Reduction Round-trip**: `reduction(closure(G)) == G` for transitively reduced DAGs.
- **Transitive Closure Idempotence**: `closure(reduction(G)) == closure(G)`.
- **Transitive Reduction Idempotence**: `reduction(closure(G)) == reduction(G)`.

---

## Traversal

**File**: `test/yog/pbt/traversal_test.exs`

- **BFS Uniqueness**: BFS visits each reachable node exactly once.
- **DFS-BFS Node Agreement**: DFS and BFS visit the same set of reachable nodes.
- **Find-Path Connectivity**: Found paths are valid (connected edges) when target is reachable.
- **Implicit-Explicit DFS Agreement**: Implicit and explicit DFS visit the same nodes.
- **Topological Order**: For any edge $(u,v)$ in a DAG, $u$ appears before $v$ in topological sort.
- **Cyclicity Consistency**: A graph is either cyclic or acyclic (exclusive or).

---

## Minimum Spanning Tree

**File**: `test/yog/pbt/mst_test.exs`

- **Kruskal-Prim Agreement**: Both algorithms produce the same total weight.
- **MST Edge Count**: Equals $V - c$ where $c$ is the number of connected components.
- **MST Cycle-Free**: No duplicate undirected edges in the result.
- **MST Non-Negative**: Total weight is non-negative for non-negative input weights.
- **MST of Tree**: The MST of a tree is the tree itself.

---

## Structural Properties

**File**: `test/yog/pbt/structural_test.exs`

- **Transpose Involutivity**: `transpose(transpose(G)) == G`.
- **Undirected Symmetry**: All edges have reverse counterparts.
- **Edge Count Consistency**: `Yog.edge_count/1` matches `length(Yog.all_edges/1)`.
- **To-Undirected Symmetry**: Creates symmetric edge structure.

**File**: `test/yog/pbt/structure_test.exs`

- **Tree Characterization**: Generated trees are connected, acyclic, and have exactly $V-1$ edges.
- **Arborescence Validity**: Directed trees have a unique root with in-degree 0, others in-degree 1.
- **Complete Graph**: $K_n$ is complete and $(n-1)$-regular.

**File**: `test/yog/pbt/cyclicity_test.exs`

- **DAG Generation**: Numeric-order edge generation produces acyclic graphs.

---

## Eulerian Paths

**File**: `test/yog/pbt/eulerian_test.exs`

- **Circuit Consistency**: `has_eulerian_circuit?` agrees with `eulerian_circuit` result.
- **Circuit Closure**: Eulerian circuits start and end at the same node.
- **Path Consistency**: `has_eulerian_path?` agrees with `eulerian_path` result.

---

## Community Detection

**File**: `test/yog/pbt/community_test.exs`

- **Partitioning Coverage**: All nodes are assigned to exactly one community.
- **Community ID Consistency**: Number of communities matches unique assignment IDs.
- **Disjoint Component Separation**: Communities from different disconnected components are not merged.
- **Local Community Contains Seed**: Local community detection always includes the seed node.

---

## Data Structures

**File**: `test/yog/pbt/disjoint_set_test.exs`

- **Reflexivity**: Every element is connected to itself.
- **Symmetry**: Connectedness is bidirectional.
- **Transitivity**: If $x$ is connected to $y$ and $y$ to $z$, then $x$ is connected to $z$.
- **Union Set Count**: Union reduces set count by 1 for distinct sets, 0 for same set.
- **Partitioning Coverage**: `to_lists` produces disjoint sets covering all elements.

**File**: `test/yog/pbt/priority_queue_test.exs`

- **Heap Ordering**: Popping all elements returns a sorted list.
- **Custom Comparison**: Works with custom comparators (max-heap).
- **Peek-Pop Agreement**: `peek` returns the same as first `pop`.
- **Size Invariant**: Push/pop accurately track element count.
- **Merge Order**: Merging preserves overall sorted order.

---

## Graph Generators

**File**: `test/yog/pbt/generator_test.exs`

### Classic Generators

- **Complete Graph**: `complete(n)` has $n$ nodes, $n(n-1)/2$ edges, degree $n-1$.
- **Cycle Graph**: `cycle(n)` has $n$ nodes, $n$ edges, degree 2.
- **Path Graph**: `path(n)` has $n$ nodes, $\max(0, n-1)$ edges.
- **Star Graph**: `star(n)` has $n$ nodes, $n-1$ edges, center degree $n-1$.
- **Wheel Graph**: `wheel(n)` has $n$ nodes, $2(n-1)$ edges.
- **Binary Tree**: `binary_tree(d)` has $2^{d+1}-1$ nodes, $2^{d+1}-2$ edges.
- **Petersen Graph**: Has exactly 10 nodes, 15 edges, degree 3.
- **Empty Graph**: `empty(n)` has $n$ nodes, 0 edges.
- **Grid 2D**: `grid_2d(r,c)` has $r \times c$ nodes, $(r-1)c + r(c-1)$ edges.
- **Complete Bipartite**: `complete_bipartite(m,n)` has $m+n$ nodes, $m \times n$ edges.
- **Hypercube**: `hypercube(n)` has $2^n$ nodes, $n \cdot 2^{n-1}$ edges, degree $n$.
- **Ladder Graph**: `ladder(n)` has $2n$ nodes, $3n-2$ edges.

### Random Generators

- **Erdős-Rényi GNP**: `erdos_renyi_gnp(n,p)` has exactly $n$ nodes.
- **Erdős-Rényi GNM**: `erdos_renyi_gnm(n,m)` has exactly $n$ nodes, at most $m$ edges.
- **Random Tree**: `random_tree(n)` has $n$ nodes, $n-1$ edges.
- **Random Regular**: `random_regular(n,d)` has $n$ nodes, $nd/2$ edges, degree $d$.
- **Seed Reproducibility**: Same seed produces identical graphs.
- **SBM Node Count**: Stochastic Block Model has exactly $n$ nodes.
- **SBM Community Validity**: Community assignments are in valid range $[0, k)$.

---

## Graph Health Metrics

**File**: `test/yog/pbt/health_test.exs`

### Distance Metrics

- **Path Diameter**: Diameter of $P_n$ is $n-1$.
- **Path Radius**: Radius of $P_n$ is $\lfloor n/2 \rfloor$.
- **Cycle Diameter**: Diameter of $C_n$ is $\lfloor n/2 \rfloor$.
- **Complete Graph Diameter**: Diameter and radius of $K_n$ are both 1.
- **Complete Graph Eccentricity**: All nodes have eccentricity 1 in $K_n$.

### Assortativity

- **Regular Graph Assortativity**: Regular graphs have assortativity 0.0.
- **Star Graph Assortativity**: Star graphs have negative assortativity.

### Average Path Length

- **Complete Graph APL**: Average path length of $K_n$ is 1.0.
- **Star Graph APL**: Average path length of $S_n$ is $2 - 2/n$.
- **Disconnected APL**: Disconnected graphs have nil APL.

---

## I/O Roundtrip

**File**: `test/yog/pbt/io_test.exs`

- **TGF Roundtrip**: Serialize then parse preserves node and edge counts.
- **JSON Roundtrip**: Serialize then parse preserves graph structure.
- **Pajek Roundtrip**: Serialize then parse preserves node and edge counts.

---

## Test Summary

- **Total PBT Files**: 21
- **Total Properties**: 145+
- **Test Location**: `test/yog/pbt/`

### File Listing

| File | Description |
|------|-------------|
| `bipartite_test.exs` | Bipartite verification and matching |
| `centrality_test.exs` | Centrality measure properties |
| `clique_test.exs` | Clique detection properties |
| `community_test.exs` | Community detection algorithms |
| `component_test.exs` | Connected components and SCC |
| `cyclicity_test.exs` | Acyclicity detection |
| `disjoint_set_test.exs` | Union-Find data structure |
| `eulerian_test.exs` | Eulerian paths and circuits |
| `flow_test.exs` | Max-flow min-cut and flow algorithms |
| `generator_test.exs` | Graph generator correctness |
| `health_test.exs` | Graph health metrics |
| `io_test.exs` | I/O format roundtrip |
| `k_core_test.exs` | K-core decomposition |
| `mst_test.exs` | Minimum spanning tree |
| `operation_test.exs` | Graph operations (union, intersect, etc.) |
| `pathfinding_test.exs` | Shortest path algorithms |
| `priority_queue_test.exs` | Priority queue data structure |
| `structural_test.exs` | Graph structure properties |
| `structure_test.exs` | Tree and arborescence properties |
| `transform_test.exs` | Graph transformations |
| `traversal_test.exs` | Graph traversal algorithms |
