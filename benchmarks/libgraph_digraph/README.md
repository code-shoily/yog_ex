# Libgraph vs Digraph vs Yog Benchmarks

Individual benchmark files for comparing performance between Yog, libgraph, and :digraph.

## Running Individual Benchmarks

```bash
# Run a specific benchmark
mix run benchmarks/libgraph_digraph/01_graph_creation.exs
mix run benchmarks/libgraph_digraph/02_topological_sort.exs
mix run benchmarks/libgraph_digraph/05_shortest_path_dijkstra.exs
```

## Available Benchmarks

| # | File | Algorithm/Operation | Libraries Compared |
|---|------|---------------------|-------------------|
| 01 | `01_graph_creation.exs` | Graph Creation & Memory | Yog, libgraph, :digraph |
| 02 | `02_topological_sort.exs` | Topological Sort | Yog (Kahn), libgraph (DFS), :digraph (DFS) |
| 03 | `03_connected_components.exs` | Connected Components | Yog, libgraph, :digraph |
| 04 | `04_strongly_connected_components.exs` | SCC | Yog (Kosaraju), libgraph, :digraph |
| 05 | `05_shortest_path_dijkstra.exs` | Dijkstra | Yog, libgraph, :digraph |
| 06 | `06_shortest_path_bellman_ford.exs` | Bellman-Ford | Yog, libgraph |
| 07 | `07_shortest_path_a_star.exs` | A* | Yog, libgraph |
| 08 | `08_k_core.exs` | K-Core Decomposition | Yog, libgraph |
| 09 | `09_reachability.exs` | Reachability | Yog, libgraph, :digraph |
| 10 | `10_arborescence.exs` | Arborescence Check | Yog, libgraph |
| 11 | `11_cliques.exs` | Clique Detection | Yog, libgraph |

## Running All Benchmarks

```bash
# Run all benchmarks in sequence
for f in benchmarks/libgraph_digraph/*.exs; do
  echo "Running: $f"
  mix run "$f"
  echo ""
done
```

## Benchmark Structure

Each benchmark:
1. Generates comparable test graphs for all libraries
2. Warms up the JIT compiler
3. Runs Benchee for statistically significant results
4. Cleans up resources (:digraph needs manual cleanup)

## Interpreting Results

- **IPS** (Iterations Per Second): Higher is better
- **Average**: Mean execution time
- **Deviation**: Statistical variance
- **Comparison**: Relative performance ratio
