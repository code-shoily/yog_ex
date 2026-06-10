# YogEx vs NetworkX Benchmarks

A comprehensive benchmark suite comparing the performance of `YogEx` (pure Elixir) and `NetworkX` (Python).

## Performance Comparison Methodology

To compare Python's NetworkX library with Elixir's YogEx fairly, we must avoid the process startup overhead of launching a Python interpreter on each iteration (which takes ~30-50ms). 

Instead, this suite uses a **persistent Python subprocess** launched as an Erlang Port and managed by an Elixir `GenServer`. This reduces communication latency to under **100 microseconds**, allowing `Benchee` to execute thousands of runs per second for both libraries and produce accurate, noise-free execution time measurements.

## Available Benchmarks

| File | Algorithm Category | Libraries/Implementations Compared |
|------|---------------------|-------------------|
| `01_topological_sort.exs` | Topological Sort | YogEx (Kahn) vs NetworkX |
| `02_connected_components.exs` | Connected Components | YogEx vs NetworkX |
| `03_strongly_connected_components.exs` | Strongly Connected Components | YogEx (Kosaraju) vs NetworkX |
| `04_shortest_path_dijkstra.exs` | Dijkstra SSSP | YogEx vs NetworkX |
| `05_shortest_path_bellman_ford.exs` | Bellman-Ford | YogEx vs NetworkX |
| `06_shortest_path_a_star.exs` | A* Pathfinding | YogEx vs NetworkX |
| `07_pagerank.exs` | PageRank Centrality | YogEx vs NetworkX |
| `08_betweenness_centrality.exs` | Betweenness Centrality | YogEx vs NetworkX |
| `09_closeness_centrality.exs` | Closeness Centrality | YogEx vs NetworkX |
| `10_louvain.exs` | Louvain Communities | YogEx vs NetworkX |
| `11_label_propagation.exs` | Label Propagation Communities | YogEx vs NetworkX |
| `12_max_flow.exs` | Edmonds-Karp & Dinic Max Flow | YogEx vs NetworkX |
| `13_mst.exs` | Kruskal & Prim MST | YogEx vs NetworkX |

## How to Run Individual Benchmarks

Ensure Python dependencies are installed first:
```bash
pip install -r test/oracle/scripts/requirements.txt
```

Run a specific benchmark using `mix run`:
```bash
mix run benchmarks/networkx/04_shortest_path_dijkstra.exs
mix run benchmarks/networkx/07_pagerank.exs
```

## How to Run All Benchmarks

To run all benchmarks in sequence:
```bash
for f in benchmarks/networkx/*.exs; do
  echo "Running: $f"
  mix run "$f"
  echo ""
done
```
