# Property-Based Testing Catalog

This document lists the algorithmic invariants (hypotheses) verified by `Yog`'s property-based testing suite. We use `StreamData` to generate thousands of random graph structures to ensure these properties hold across all possible edge cases, including sparse, dense, disconnected, and cyclic graphs.

## Connectivity and Components
- **SCC Partitioning**: Strongly Connected Components must partition the set of all nodes exactly. Every node belongs to one and only one SCC.
- **k-core Degree**: Every node in a $k$-core must have degree at least $k$ within that subgraph.
- **Core Number Consistency**: A node with core number $k$ must exist in the $k$-core but not in the $(k+1)$-core.
- **Complete Graph Core**: A complete graph $K_n$ has a $(n-1)$-core containing all nodes.
- **Bipartite Verification**: Graphs identified as bipartite must be 2-colorable with no monochromatic edges.
- **Eulerian Continuity**: Eulerian circuits/paths must use every edge exactly once and maintain vertex degree parity.
- **Articulation Point Analysis**: Removing an articulation point must increase the count of connected components.

## Pathfinding and Flow
- **Max-Flow Min-Cut Theorem**: The maximum flow value between source and sink must equal the minimum cut capacity.
- **Flow Conservation**: At every node except source and sink, total in-flow must equal total out-flow.
- **Shortest Path Consistency**: Dijkstra, BFS (unweighted), and A* must agree on the shortest path distance when weights are non-negative.
- **Bellman-Ford Correctness**: Bellman-Ford must correctly identify graphs containing reachable negative cycles and fail gracefully.
- **Bidirectional Correctness**: Bidirectional Dijkstra must yield the same path distance as standard Dijkstra.
- **A* Admissibility**: A* with a consistent/admissible heuristic must always find the optimal path.

## Centrality Measures
- **Star Graph Centrality**: In a star graph, the center node must have strictly higher centrality (Degree, Closeness, Betweenness, Closeness, PageRank, etc.) than any leaf node.
- **PageRank Unity**: The sum of PageRank scores across all nodes must be exactly 1.0 (Unity Law).
- **Betweenness Symmetry**: Betweenness scores should be symmetric in symmetric graphs (like cycles or paths).

## Graph Operations and Transformations
- **Transpose Involutivity**: `transpose(transpose(G)) == G`.
- **Map-Nodes Identity**: `map_nodes(G, id) == G`.
- **Map-Nodes Composition**: `map(f) . map(g) == map(f . g)`.
- **Filter-Nodes Consistency**: Filtering nodes must correctly remove associated edges and preserve the relative structure of remaining nodes.
- **Union/Intersection Invariants**: Standard set-theoretic invariants for graph unions and intersections (e.g., $V(G_1 \cup G_2) = V(G_1) \cup V(G_2)$).
- **Isomorphism Invariants**: Re-indexing a graph must result in a structure identified as isomorphic to the original.

## Structural Properties
- **Tree Characterization**: Generated trees must be connected, acyclic, and have exactly $V-1$ edges.
- **Arborescence Validity**: Directed trees must have a unique root and satisfy in-degree constraints ($0$ for root, $1$ for others).
- **Complete Graph ($K_n$)**: A graph $K_n$ must be $(n-1)$-regular and have $n(n-1)/2$ edges (undirected).
- **Topological Order**: For any edge $(u, v)$ in a DAG, $u$ must appear before $v$ in the topological sort.
- **Acyclicity**: Graphs generated specifically as DAGs must be identified as acyclic by depth-first search.

## Community Detection
- **Partitioning Invariants**: Partitioning algorithms (Louvain, Leiden, Infomap, etc.) must assign every node to exactly one community (or multiple for overlapping ones).
- **Component Separation**: Community detection on disconnected components must never merge nodes from different components into the same community.
- **Cliques as Communities**: A maximal clique must often be identified as a core part of a community.
- **Girvan-Newman Quality**: Iteratively removing high-betweenness edges should lead to increased modularity until optimal partitioning.
