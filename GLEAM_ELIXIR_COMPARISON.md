# Yog: Gleam vs Elixir (YogEx) Implementation Comparison

This document compares the Gleam and Elixir (YogEx) implementations of the Yog graph algorithm library.

## Quick Summary

| Aspect | Gleam (Yog) | Elixir (YogEx) |
| -------- | ------- | ----- |
| **Repository** | [code-shoily/yog](https://github.com/code-shoily/yog) | [code-shoily/yog_ex](https://github.com/code-shoily/yog_ex) |
| **Language** | Gleam (BEAM/Erlang VM) | Elixir (BEAM/Erlang VM) |
| **Package** | [hex.pm/packages/yog](https://hex.pm/packages/yog) | [hex.pm/packages/yog_ex](https://hex.pm/packages/yog_ex) |
| **Documentation** | [HexDocs](https://hexdocs.pm/yog/) | [HexDocs](https://hexdocs.pm/yog_ex/) |
| **Status** | Stable 5.0.0+ | Beta 0.95.x (pre-1.0) |
| **Total Algorithms** | 60+ | 65+ |
| **Lines of Code** | ~13,000 | ~18,000 |
| **Test Coverage** | 1,500+ tests | 1,450+ tests |

## Core Data Structures

| Feature | Gleam | Elixir | Notes |
| --------- | ------- | ----- | ------- |
| **Graph&lt;'n, 'e>** | ✅ | ✅ | Directed/Undirected with generic node/edge data |
| **MultiGraph** | ✅ | ✅ | Parallel edges between nodes |
| **DAG (Directed Acyclic Graph)** | ✅ | ✅ | Type-safe wrapper with cycle prevention |
| **Disjoint Set (Union-Find)** | ✅ | ✅ | Path compression and union by rank |
| **Functional Graphs (FGL)** | ❌ | ✅ | **Elixir only** - Pure inductive graph library |

## Pathfinding Algorithms

| Algorithm | Gleam | Elixir | Complexity |
| ----------- | ------- | ----- | ------------ |
| **Dijkstra** | ✅ | ✅ | O((V+E) log V) |
| **A\*** | ✅ | ✅ | O((V+E) log V) |
| **Bellman-Ford** | ✅ | ✅ | O(VE) |
| **Floyd-Warshall** | ✅ | ✅ | O(V³) |
| **Johnson's** | ❌ | ✅ | **Elixir only** - All-pairs with reweighting |
| **Distance Matrix** | ✅ | ✅ | All-pairs distances |
| **Implicit Pathfinding** | ✅ | ✅ | State-space search |

**Status**: ✅ Elixir has Johnson's algorithm for sparse all-pairs shortest paths

## Graph Traversal

| Algorithm | Gleam | Elixir | Notes |
| ----------- | ------- | ----- | ------- |
| **BFS** | ✅ | ✅ | Breadth-first search |
| **DFS** | ✅ | ✅ | Depth-first search |
| **Early Termination** | ✅ | ✅ | Stop on goal found |
| **Implicit Traversal** | ✅ | ✅ | On-demand graph exploration |
| **Topological Sort** | ✅ | ✅ | Kahn's algorithm |
| **Lexicographical Topo Sort** | ✅ | ✅ | Stable ordering |
| **Cycle Detection** | ✅ | ✅ | For directed & undirected graphs |

**Status**: ✅ Feature parity

## Flow & Optimization

| Algorithm | Gleam | Elixir | Status |
| ----------- | ------- | ----- | -------- |
| **Edmonds-Karp** (Max Flow) | ✅ | ✅ | Both fully functional |
| **Min Cut from Max Flow** | ✅ | ✅ | Both fully functional |
| **Stoer-Wagner** (Global Min Cut) | ✅ | ✅ | Both fully functional |
| **Network Simplex** (Min Cost Flow) | ✅ | ✅ | Both complete implementations |
| **Successive Shortest Path** | ❌ | ✅ | **Elixir only** |
| **Capacity Scaling** | ❌ | ✅ | **Elixir only** |

**Status**: ✅ Elixir has additional flow algorithms (Successive Shortest Path, Capacity Scaling)

## Graph Properties & Analysis

| Feature | Gleam | Elixir | Notes |
| --------- | ------- | ----- | ------- |
| **Connectivity** | ✅ | ✅ | |
| - Bridges | ✅ | ✅ | Tarjan's algorithm |
| - Articulation Points | ✅ | ✅ | Tarjan's algorithm |
| - Strong Components (SCC) | ✅ | ✅ | Tarjan's & Kosaraju's |
| - K-Core / Degeneracy | ✅ | ✅ | Bucket-based decomposition |
| **Cyclicity** | ✅ | ✅ | Cycle detection |
| **Eulerian Paths/Circuits** | ✅ | ✅ | Hierholzer's algorithm |
| **Bipartite Graphs** | ✅ | ✅ | Detection & max matching |
| **Stable Marriage** | ✅ | ✅ | Gale-Shapley algorithm |
| **Cliques** | ✅ | ✅ | Bron-Kerbosch algorithm |
| **Line Graph** | ❌ | ✅ | **Elixir only** |
| **Graph Complement** | ❌ | ✅ | **Elixir only** |
| **Block Cut Tree** | ❌ | ✅ | **Elixir only** - Biconnected component tree |

**Status**: ✅ Elixir has additional structural analysis (Line Graph, Complement, Block Cut Tree)

## Centrality Measures

| Measure | Gleam | Elixir | Notes |
| --------- | ------- | ----- | ------- |
| **Degree Centrality** | ✅ | ✅ | |
| **Betweenness Centrality** | ✅ | ✅ | Int & Float variants |
| **Closeness Centrality** | ✅ | ✅ | Int & Float variants |
| **Harmonic Centrality** | ✅ | ✅ | Int & Float variants |
| **PageRank** | ✅ | ✅ | Iterative algorithm |
| **Eigenvector Centrality** | ✅ | ✅ | Power iteration |
| **Katz Centrality** | ✅ | ✅ | |
| **Alpha Centrality** | ✅ | ✅ | |

**Status**: ✅ Feature parity - All 8 centrality measures in both

## Community Detection

| Algorithm | Gleam | Elixir | Notes |
| --------- | ------- | ----- | ------- |
| **Louvain** | ✅ | ✅ | Fast modularity optimization |
| **Leiden** | ✅ | ✅ | Quality guaranteed partitions |
| **Label Propagation** | ✅ | ✅ | Near-linear time scaling |
| **Girvan-Newman** | ✅ | ✅ | Hierarchical edge betweenness |
| **Walktrap** | ✅ | ✅ | Random walk distances |
| **Infomap** | ✅ | ✅ | Information-theoretic flow |
| **Clique Percolation** | ✅ | ✅ | Overlapping communities |
| **Local Community** | ✅ | ✅ | Massive graphs, seed expansion |
| **Fluid Communities** | ✅ | ✅ | Exact `k` partitions, fast |
| **Metrics & Modularity** | ✅ | ✅ | Quality evaluation |
| **SBM Generator** | ❌ | ✅ | **Elixir only** - Stochastic Block Model for testing |

**Status**: ✅ Feature parity + Elixir has SBM generator for community testing

## Minimum Spanning Trees

| Algorithm | Gleam | Elixir | Notes |
| ----------- | ------- | ----- | ------- |
| **Kruskal's MST** | ✅ | ✅ | O(E log E) |
| **Prim's MST** | ✅ | ✅ | O(E log V) |

**Status**: ✅ Elixir has additional MST algorithms

## Graph Generators

### Classic Deterministic Graphs

| Generator | Gleam | Elixir | Description |
| ----------- | ------- | ----- | ------------- |
| **Complete (K_n)** | ✅ | ✅ | Every node connected |
| **Cycle (C_n)** | ✅ | ✅ | Ring structure |
| **Path (P_n)** | ✅ | ✅ | Linear chain |
| **Star (S_n)** | ✅ | ✅ | Hub with spokes |
| **Wheel (W_n)** | ✅ | ✅ | Cycle + center hub |
| **Grid 2D** | ✅ | ✅ | Rectangular lattice |
| **Binary Tree** | ✅ | ✅ | Complete binary tree |
| **Complete Bipartite** | ✅ | ✅ | K_{m,n} |
| **Petersen Graph** | ✅ | ✅ | Famous 10-node graph |
| **Empty Graph** | ✅ | ✅ | Isolated nodes |

**Status**: ✅ Elixir has additional classic generators

### Random Network Models

| Generator | Gleam | Elixir | Description |
| ----------- | ------- | ----- | ------------- |
| **Erdős-Rényi G(n,p)** | ✅ | ✅ | Edge probability p |
| **Erdős-Rényi G(n,m)** | ✅ | ✅ | Exactly m edges |
| **Barabási-Albert** | ✅ | ✅ | Scale-free networks |
| **Watts-Strogatz** | ✅ | ✅ | Small-world networks |
| **Random Trees** | ✅ | ✅ | Uniformly random spanning trees |
| **Stochastic Block Model** | ❌ | ✅ | **Elixir only** - Planted communities |

**Status**: ✅ Elixir has additional random graph models

## Graph Operations

| Operation | Gleam | Elixir | Notes |
| ----------- | ------- | ----- | ------- |
| **Union** | ✅ | ✅ | Combine node/edge sets |
| **Intersection** | ✅ | ✅ | Common nodes/edges |
| **Difference** | ✅ | ✅ | Subtract graphs |
| **Cartesian Product** | ✅ | ✅ | Graph product |
| **Power Graph** | ✅ | ✅ | k-th power |
| **Graph Isomorphism** | ✅ | ✅ | VF2 algorithm |
| **O(1) Transpose** | ✅ | ✅ | Edge reversal |
| **Subgraph** | ✅ | ✅ | Extract by node set |
| **Merge** | ✅ | ✅ | Combine graphs |
| **Contract Edges** | ✅ | ✅ | Merge nodes |

**Status**: ✅ Elixir has additional graph products

## I/O & Visualization

| Format | Gleam | Elixir | Purpose |
| -------- | ------- | ----- | --------- |
| **DOT (Graphviz)** | ✅ | ✅ | Professional visualization |
| **JSON** | Extension Package | ✅ | Built-in with optional :jason |
| **Mermaid** | ✅ | ✅ | Markdown diagrams |
| **GraphML** | 🔶 Planned | ✅ | XML format for Gephi, yEd, Cytoscape |
| **GDF** | 🔶 Planned | ✅ | Gephi lightweight format |
| **Pajek (.net)** | ❌ | ✅ | **Elixir only** - Net files |
| **LEDA (.gw)** | ❌ | ✅ | **Elixir only** - GraphWin format |
| **TGF** | ❌ | ✅ | **Elixir only** - Trivial Graph Format |
| **ASCII Rendering** | ❌ | ✅ | **Elixir only** - Terminal visualization |
| **Libgraph** | ❌ | ✅ | **Elixir only** - Libgraph conversion |

**Status**: ✅ Elixir has broader I/O format support

## DAG-Specific Algorithms

| Feature | Gleam | Elixir | Notes |
| --------- | ------- | ----- | ------- |
| **Type-safe DAG wrapper** | ✅ | ✅ | Compile-time cycle prevention |
| **Longest Path** | ✅ | ✅ | Critical path analysis |
| **Topological Sort** | ✅ | ✅ | Guaranteed success on DAG |
| **Transitive Closure** | ✅ | ✅ | Reachability matrix |
| **Transitive Reduction** | ✅ | ✅ | Minimal equivalent DAG |

**Status**: ✅ Elixir has chain decomposition for DAGs

## MultiGraph Support

| Feature | Gleam | Elixir | Notes |
| --------- | ------- | ----- | ------- |
| **Parallel Edges** | ✅ | ✅ | Multiple edges between nodes |
| **Edge IDs** | ✅ | ✅ | Unique identification |
| **Eulerian for MultiGraphs** | ✅ | ✅ | Specialized implementation |
| **MultiGraph Traversal** | ✅ | ✅ | BFS/DFS with edge IDs |
| **MultiGraph Operations** | ✅ | ✅ | Union, intersection, etc. |

**Status**: ✅ Feature parity

## Special Features

### Elixir Only

| Feature | Description |
| ------- | ----------- |
| **Functional Graphs (FGL)** | Pure inductive graph library based on Martin Erwig's FGL |
| **HyperLogLog** | Probabilistic cardinality estimation for massive graphs |
| **Temporal Graphs** | Time-evolving graph structures |
| **SBM Generator** | Stochastic Block Model for community detection testing |
| **Johnson's Algorithm** | All-pairs shortest paths for sparse graphs |
| **Line Graph** | Convert edges to nodes |
| **Block Cut Tree** | Biconnected component tree structure |
| **ASCII Rendering** | Terminal-based graph visualization |
| **Extensive I/O** | GraphML, GDF, Pajek, LEDA, TGF support |

### Gleam Only

| Feature | Description |
| ------- | ----------- |
| **Stable 5.0.0 Release** | Battle-tested, production-ready |
| **Simpler API Surface** | More focused, easier to learn |

## Performance Characteristics

Both run on BEAM VM with similar performance characteristics:

| Aspect | Gleam | Elixir |
| -------- | ------- | ----- |
| **Runtime** | BEAM/Erlang VM | BEAM/Erlang VM |
| **Concurrency** | Actor model (OTP) | Actor model (OTP/GenServer) |
| **Graph Size** | 10,000+ nodes | 10,000+ nodes |
| **Hot Code Reloading** | ✅ | ✅ |
| **Fault Tolerance** | ✅ OTP | ✅ OTP |

**Note**: Elixir has undergone extensive optimization using `List.foldl` instead of `Enum.reduce` in hot loops and direct struct field access, achieving significant speedups in community detection and traversal algorithms.

## Testing & Quality

| Aspect | Gleam | Elixir |
| -------- | ------- | ----- |
| **Unit Tests** | ✅ Extensive | ✅ Extensive |
| **Property-Based Tests** | ✅ qcheck | ✅ StreamData |
| **Doctests** | ✅ | ✅ |
| **Test Count** | 1,500+ | 1,450+ |
| **Property Count** | 150+ | 150+ |
| **CI/CD** | ✅ GitHub Actions | ✅ GitHub Actions |
| **Code Coverage** | High | High |

## Language & Ecosystem

| Aspect | Gleam | Elixir |
| -------- | ------- | ----- |
| **Paradigm** | Functional, Statically Typed | Functional, Dynamically Typed |
| **Type System** | Static with type inference | Dynamic with optional types (Dialyzer) |
| **Pattern Matching** | Exhaustive | Flexible with guards |
| **Pipe Operator** | `|>` (left-to-right) | `|>` (left-to-right) |
| **OTP Integration** | ✅ Full | ✅ Full (native) |
| **Phoenix Integration** | Via Erlang interop | Native |
| **Documentation** | Excellent | Excellent (ExDoc) |
| **Learning Curve** | Moderate (new language) | Moderate (Ruby-like syntax) |

## Code Example Comparison

### Creating a Graph and Finding Shortest Path

**Gleam:**
```gleam
import yog/graph
import yog/pathfinding/dijkstra

let g =
  graph.new_directed()
  |> graph.add_node(1, "A")
  |> graph.add_node(2, "B")
  |> graph.add_node(3, "C")
  |> graph.add_edge(1, 2, 5)
  |> graph.add_edge(2, 3, 3)
  |> graph.add_edge(1, 3, 10)

// Returns: Option(Path(Int, Int, String))
let result = dijkstra.shortest_path(g, 1, 3)
```

**Elixir:**
```elixir
alias Yog.Pathfinding

graph =
  Yog.directed()
  |> Yog.add_node(1, "A")
  |> Yog.add_node(2, "B")
  |> Yog.add_node(3, "C")
  |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
  |> Yog.add_edge_ensure(from: 2, to: 3, with: 3)
  |> Yog.add_edge_ensure(from: 1, to: 3, with: 10)

# Returns: {:ok, %Yog.Pathfinding.Path{}} | :error
result = Pathfinding.shortest_path(in: graph, from: 1, to: 3)
```

### Community Detection

**Gleam:**
```gleam
import yog/community/louvain

// Returns: Communities(Int, String)
let communities = louvain.detect(graph)
```

**Elixir:**
```elixir
alias Yog.Community.Louvain

# Returns: %Yog.Community.Result{}
communities = Louvain.detect(graph)
```

## Migration Guide

### Gleam → Elixir

**Mostly straightforward**, but note:

- ✅ Elixir uses keyword arguments for many functions (`in:`, `from:`, `to:`)
- ✅ Return values use `{:ok, result}` / `:error` tuples instead of `Option`/`Result`
- ✅ Elixir has additional algorithms not present in Gleam (Johnson's, SBM, etc.)
- ✅ I/O modules are built-in with optional dependencies (:jason, :saxy)

### Elixir → Gleam

**Straightforward migration**, but watch for:

- ⚠️ Gleam has stricter static typing - some runtime errors become compile-time errors
- ✅ All core algorithms present and tested
- ⚠️ Elixir-specific features (FGL, HyperLogLog, Temporal Graphs) not available in Gleam

## Recommendations

## Version History

| Version | Gleam | Elixir |
| --------- | ------- | ----- |
| **Latest** | 5.0.0+ | 0.95.x |
| **First Release** | 2024 | 2025 |
| **Stability** | Stable | Beta (approaching 1.0) |

## Roadmap

### Gleam Planned

- [ ] GraphML Export/Import
- [ ] GDF Export
- [ ] Johnson's Algorithm
- [ ] HyperLogLog support
- [ ] FGL-style inductive graphs
- [ ] Additional random graph models (SBM, Chung-Lu)

### Elixir Planned

- [ ] **1.0.0 Stable Release** - API stabilization
- [ ] Performance benchmarks
- [ ] Additional centrality measures
- [ ] Graph isomorphism detection
- [ ] Graph coloring algorithms
- [ ] GPU-accelerated algorithms (via Nx)

### Both

- [ ] Streaming graph algorithms
- [ ] Dynamic graph updates
- [ ] Parallel algorithm variants
- [ ] Graph database adapters

## Summary

Both implementations are **high-quality, feature-rich graph libraries** running on the BEAM VM with excellent documentation and test coverage.

**Algorithm Coverage**: ~85% feature parity with Elixir having ~20% more algorithms
**Quality**: Both production-ready (Gleam more mature, Elixir more feature-complete)
**Documentation**: Excellent in both
**Community**: Active maintenance in both

### Key Differentiators

**Elixir (YogEx) Strengths:**

- ✅ **More algorithms** (65+ vs 60+)
- ✅ **Functional Graphs (FGL)** - Pure inductive graph library
- ✅ **HyperLogLog** - Probabilistic cardinality estimation
- ✅ **Extensive I/O** - GraphML, GDF, Pajek, LEDA, TGF, ASCII
- ✅ **Additional MST algorithms** - Borůvka, Reverse-Delete
- ✅ **Phoenix/OTP native** - Seamless integration with Elixir ecosystem
- ✅ **More graph products** - Join, Corona, Lexicographic

**Gleam (Yog) Strengths:**

- ✅ **Static typing** - Compile-time guarantees
- ✅ **Stable release** - Battle-tested 5.0.0+
- ✅ **Simpler API** - More focused, easier to learn
- ✅ **Type-safe** - Cycles prevented at compile time for DAGs

**Recommended Use:**

- **Elixir/Phoenix projects**: Choose YogEx
- **Type safety critical**: Choose Gleam Yog
- **Maximum algorithm coverage**: Choose YogEx
- **Stable production release**: Choose Gleam Yog (now) or wait for YogEx 1.0
- **Teaching functional programming**: Both excellent choices

---

**Last Updated**: April 2025
**Gleam Version**: 5.0.0
**Elixir Version**: 0.95.0
