# NetworkX Oracle Test Suite

> **Purpose:** Verify YogEx algorithm outputs against [NetworkX](https://networkx.org/) — the de-facto reference implementation for graph algorithms in Python — using property-based testing.

## Overview

The oracle suite treats NetworkX as a ground-truth oracle.  For every property test, a random graph is generated, fed to both YogEx and NetworkX, and the results are compared.  If YogEx disagrees with NetworkX, the property fails and StreamData prints a deterministic seed so the failure is reproducible.

This is not a replacement for unit tests (those live in `test/yog/`) — it is a *cross-implementation parity* layer that catches semantic drift, edge-case mishandling, and subtle bugs that unit tests alone rarely reach.

## Methodology

### Harness Architecture

```
┌─────────────────┐     JSON payload      ┌──────────────────────┐
│  Elixir test    │ ─────────────────────>│  Python dispatcher   │
│  (ExUnit +      │  (graph + algorithm   │  (run_algorithm.py)  │
│   StreamData)   │   + options)          │                      │
│                 │                       │  ┌───────────────┐   │
│  YogEx result   │ <─────────────────────│  │  NetworkX     │   │
│     vs          │     JSON result       │  │  adapter      │   │
│  NetworkX result│                       │  └───────────────┘   │
└─────────────────┘                       └──────────────────────┘
```

1. **Graph marshalling** — `Yog.Oracle.NetworkX.encode_graph/1` serialises a `Yog.Graph` to JSON, preserving node-ID types (integer, atom, string) via prefixed strings (`"i:42"`, `"a:foo"`, `"s:hello"`).
2. **Subprocess dispatch** — `System.cmd/3` spawns `python3 run_algorithm.py <tmpfile>`.  Each call is isolated, debuggable, and avoids NIF complexity.
3. **Result decoding** — `decode_result/2` reverses the encoding and normalises shapes (e.g. `"__Inf__"` → `:infinity`, nested dicts → `%{node_id => value}`).
4. **Property assertion** — ExUnit compares the decoded NetworkX result against the YogEx result.

### Adapter Health Check

Before any oracle property runs, the harness executes **10 round-trip self-tests** (`NetworkX.adapter_health/0`):

| # | Test | Validates |
|---|------|-----------|
| 1 | Empty graph | Zero nodes, zero edges |
| 2 | Single node, no edges | Node presence without edges |
| 3 | Single directed edge | Directed edge round-trip |
| 4 | Self-loop (directed) | Self-loop encoding |
| 5 | Self-loop (undirected) | Undirected self-loop encoding |
| 6 | Disconnected components | Multiple components survive JSON |
| 7 | Atom node IDs | `:foo` → `"foo"` → `:foo` |
| 8 | String node IDs | `"alice"` round-trip |
| 9 | Integer node IDs | `42` round-trip |
| 10 | Weighted floats (negative) | `-3.5` round-trip |

If any self-test fails, the entire oracle suite is skipped with a clear reason — never a silent pass.

## NetworkX vs YogEx Parity Matrix

| Category | Algorithm | YogEx Module | NetworkX Equivalent | Parity Type | Properties | Status |
|----------|-----------|--------------|---------------------|-------------|------------|--------|
| **Pathfinding** | Dijkstra SSSP | `Yog.Pathfinding.Dijkstra` | `nx.single_source_dijkstra_path_length` | Exact distance maps | 2 | ✅ |
| | A* shortest path | `Yog.Pathfinding.AStar` | `nx.astar_path` | Exact path length | 1 | ✅ |
| | Bellman-Ford | `Yog.Pathfinding.BellmanFord` | `nx.bellman_ford_path_length` | Exact path + error cases | 1 | ✅ |
| | Floyd-Warshall | `Yog.Pathfinding.FloydWarshall` | `nx.floyd_warshall` | Exact all-pairs distances | 1 | ✅ |
| | Johnson's | `Yog.Pathfinding.Johnson` | `nx.johnson` | Exact all-pairs distances | 1 | ✅ |
| | Bidirectional Dijkstra | `Yog.Pathfinding.Bidirectional` | `nx.bidirectional_dijkstra` | Exact path + length | 1 | ✅ |
| | Bidirectional BFS | `Yog.Pathfinding.Bidirectional` | `nx.bidirectional_shortest_path` | Exact unweighted path | 1 | ✅ |
| | Yen k-shortest | `Yog.Pathfinding.Yen` | `nx.shortest_simple_paths` | Exact k paths | 0 | ⏸️ |
| **Flow & Cuts** | Edmonds-Karp max flow | `Yog.Flow.MaxFlow` | `nx.maximum_flow_value` (EK) | Exact flow value | 1 | ✅ |
| | Dinic max flow | `Yog.Flow.MaxFlow` | `nx.maximum_flow_value` (Dinic) | Exact flow value | 1 | ✅ |
| | Stoer-Wagner min cut | `Yog.Flow.MinCut` | `nx.stoer_wagner` | Exact cut value | 1 | ✅ |
| **Spanning Tree** | Kruskal MST | `Yog.MST` | `nx.minimum_spanning_tree` (Kruskal) | Exact total weight | 1 | ✅ |
| | Prim MST | `Yog.MST` | `nx.minimum_spanning_tree` (Prim) | Exact total weight | 1 | ✅ |
| | Borůvka MST | `Yog.MST` | `nx.minimum_spanning_tree` (Borůvka) | Exact total weight | 1 | ✅ |
| | Maximum ST (Kruskal) | `Yog.MST` | `nx.maximum_spanning_tree` | Exact total weight | 1 | ✅ |
| | Min Arborescence | `Yog.MST` | `nx.minimum_spanning_arborescence` | Exact total weight | 0 | 🔴 |
| **Matching** | Hopcroft-Karp | `Yog.Matching` | `nx.bipartite.maximum_matching` | Exact cardinality | 1 | ✅ |
| | Blossom (general) | `Yog.Matching` | `nx.max_weight_matching` | Exact cardinality | 1 | ✅ |
| | Hungarian (min) | `Yog.Matching` | `nx.bipartite.minimum_weight_full_matching` | Exact optimal weight | 1 | ✅ |
| | Hungarian (max) | `Yog.Matching` | `nx.bipartite.minimum_weight_full_matching` (negated) | Exact optimal weight | 1 | ✅ |
| **Connectivity** | SCC (Tarjan) | `Yog.Connectivity.SCC` | `nx.strongly_connected_components` | Exact component sets | 1 | ✅ |
| | Connected Components | `Yog.Connectivity` | `nx.connected_components` | Exact component sets | 1 | ✅ |
| | Weakly CC | `Yog.Connectivity.Components` | `nx.weakly_connected_components` | Exact component sets | 1 | ✅ |
| **Properties** | Bipartite check | `Yog.Property.Bipartite` | `nx.is_bipartite` | Exact boolean | 1 | ✅ |
| | Tree check | `Yog.Property.Structure` | `nx.is_tree` | Exact boolean | 1 | ✅ |
| | Forest check | `Yog.Property.Structure` | `nx.is_forest` | Exact boolean | 1 | ✅ |
| | DAG check | `Yog.Property.Cyclicity` | `nx.is_directed_acyclic_graph` | Exact boolean | 1 | ✅ |
| | Clique number | `Yog.Property.Clique` | `nx.find_cliques` + max size | Exact size | 1 | ✅ |
| **Traversal** | BFS layers | `Yog.Traversal` | `nx.bfs_layers` | Exact level sets | 1 | ✅ |
| | Lexicographic topo-sort | `Yog.Traversal.Sort` | `nx.lexicographical_topological_sort` | Exact ordering | 1 | ✅ |
| | Topological generations | `Yog.DAG.Algorithm` | `nx.topological_generations` | Exact generation lists | 1 | ✅ |
| **Centrality** | Degree centrality | `Yog.Centrality` | `nx.degree_centrality` | Exact values | 1 | ✅ |
| | In-degree centrality | `Yog.Centrality` | `nx.in_degree_centrality` | Exact values | 1 | ✅ |
| | Out-degree centrality | `Yog.Centrality` | `nx.out_degree_centrality` | Exact values | 1 | ✅ |
| | Closeness centrality | `Yog.Centrality` | `nx.closeness_centrality` | Exact values | 0 | ⏸️ |
| | Harmonic centrality | `Yog.Centrality` | `nx.harmonic_centrality` | Exact values | 0 | ⏸️ |
| | Betweenness centrality | `Yog.Centrality` | `nx.betweenness_centrality` | Exact values | 0 | ⏸️ |
| | PageRank | `Yog.Centrality` | `nx.pagerank` | Tolerance-based | 0 | ⏸️ |
| | HITS | `Yog.Centrality` | `nx.hits` | Tolerance-based | 0 | ⏸️ |
| | Katz centrality | `Yog.Centrality` | `nx.katz_centrality` | Tolerance-based | 0 | ⏸️ |
| | Eigenvector centrality | `Yog.Centrality` | `nx.eigenvector_centrality` | Tolerance-based | 0 | ⏸️ |
| **Community** | Louvain | `Yog.Community.Louvain` | `nx.community.louvain_communities` | NMI ≥ 0.85 | 1 | ✅ |
| | Leiden | `Yog.Community.Leiden` | `nx.community.louvain_communities`* | NMI ≥ 0.90 | 1 | ✅ |
| | Label Propagation | `Yog.Community.LabelPropagation` | `nx.community.label_propagation_communities` | NMI ≥ 0.70 | 1 | ✅ |

\* *Leiden uses Louvain as the NetworkX proxy because NetworkX does not ship a native Leiden implementation.*

### Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Committed to suite, passing |
| ⏸️ | Deferred — known convention or stability gaps (see [Centrality deferral](#centrality-deferral)) |
| 🔴 | Documented divergence — comparison is invalid by design (e.g. Min Arborescence: NetworkX picks its own root, so total-weight parity is meaningless) |

## Outcome

### Current Suite Statistics

| Metric | Value |
|--------|-------|
| Total oracle-style properties | **36** |
| Exact-parity properties | **33** |
| Quality-floor properties | **3** (Louvain, Leiden, Label Propagation) |
| Adapter health tests | **1** (10 round-trip checks) |
| Fast-suite runtime | ~5 s (3 700+ tests) |
| Oracle-suite runtime | ~160 s |

### Known Semantic Differences

These are intentional or documented divergences where YogEx and NetworkX use different conventions.  The oracle adapters normalise where possible; otherwise the test generators avoid the divergence.

| Topic | YogEx | NetworkX | Oracle strategy |
|-------|-------|----------|-----------------|
| **Self-loop degree** | Counts as +1 (one outgoing entry) | Counts as +2 (in + out) | Avoid self-loops in degree-centrality tests |
| **Transitive closure weights** | New edges get weight `1` | New edges have no `weight` attribute | Compare edge existence only |
| **Transitive reduction weights** | Preserves original weights | Strips weights to `{}` | Compare edge existence only |
| **Disconnected pathfinding** | Returns `{:error, :no_path}` | Raises `NetworkXNoPath` | Adapter catches and normalises to `{:error, :no_path}` |
| **Negative cycles (Bellman-Ford)** | Returns `{:error, :negative_cycle}` | Raises `NetworkXUnbounded` | Adapter catches and normalises |

### Centrality Deferral

The centrality category is split into two piles for the next re-engagement pass:

1. **Numeric convention deltas** — both sides terminate, but values differ by a documented factor or normalization option.  Tractable with adapter-side flags or Elixir-side normalization.
   - *Closeness* on disconnected graphs (Wasserman-Faust correction)
   - *Harmonic* on isolated nodes
   - *Betweenness* normalization options

2. **Convergence / stability failures** — one side raises or values disagree non-deterministically.  Requires the input generator to exclude pathological inputs.
   - *Eigenvector* on dominant-eigenvalue ambiguity
   - *Katz* when `α · ρ(A) ≥ 1`
   - *PageRank* on dangling nodes

## Running the Oracle Suite

### Prerequisites

```bash
# Python dependencies
pip install -r test/oracle/scripts/requirements.txt
# Contents: networkx==3.6.1, numpy>=1.24, scipy>=1.11
```

### Fast suite (excludes oracle)

```bash
mix test
```

### Oracle suite only

```bash
mix test --include oracle test/oracle/
```

### Single oracle module

```bash
mix test --include oracle test/oracle/pathfinding_oracle_test.exs
```

### CI Configuration

The project uses a split CI strategy:

| Workflow | File | Tags | Runtime |
|----------|------|------|---------|
| Main CI | `.github/workflows/ci.yml` | Excludes `:oracle` | ~5 s |
| Nightly | `.github/workflows/nightly.yml` | Includes `:oracle` | ~160 s |

## File Layout

```shell
test/oracle/
├── README.md                       # This file
├── nx_oracle.ex                    # Elixir harness (marshal, spawn, decode)
├── nx_oracle_test.exs              # Adapter health check (10 self-tests)
├── pathfinding_oracle_test.exs     # 8 properties
├── flow_oracle_test.exs            # 3 properties
├── mst_oracle_test.exs             # 4 properties (arborescence deferred — 🔴 divergent root choice)
├── centrality_oracle_test.exs      # 3 properties (degree exact; rest deferred)
├── connectivity_oracle_test.exs    # 3 properties
├── properties_oracle_test.exs      # 5 properties
├── matching_oracle_test.exs        # 4 properties
├── traversal_oracle_test.exs       # 3 properties
└── scripts/
    ├── run_algorithm.py            # Python entry point
    ├── requirements.txt            # Pinned Python deps
    └── adapters/
        ├── __init__.py             # Dispatch table
        ├── centrality.py
        ├── connectivity.py
        ├── flow.py
        ├── matching.py
        ├── mst.py
        ├── pathfinding.py
        ├── properties.py
        └── traversal.py
```

## Adding a New Oracle Property

1. **Add the NetworkX adapter** in `test/oracle/scripts/adapters/<category>.py`:
   ```python
   def my_algorithm(graph, options):
       return nx.my_algorithm(graph, **options)
   ```
   Register it in the module's `DISPATCH` dict and in `adapters/__init__.py`.

2. **Add the Elixir property** in `test/oracle/<category>_oracle_test.exs`:
   ```elixir
   @tag :oracle
   property "P-ORAC-CAT-NNN My algorithm agrees with NetworkX" do
     check all(graph <- my_generator(), max_runs: 50) do
       yog_result = Yog.MyModule.my_algorithm(graph)
       nx_result  = NetworkX.run("my_algorithm", graph, [])
       assert yog_result == nx_result
     end
   end
   ```

3. **Run the suite**:
   ```bash
   mix test --include oracle test/oracle/<category>_oracle_test.exs
   ```

## References

- [NetworkX Documentation](https://networkx.org/documentation/stable/)
- [StreamData Property-Based Testing](https://hexdocs.pm/stream_data/ExUnitProperties.html)
- [ALGORITHMS.md](../../ALGORITHMS.md) — YogEx algorithm catalog
