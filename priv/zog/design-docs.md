# NIF Design for Yog via Zog (Zig)

> **Status:** Active implementation. Betweenness NIF is working.  
> **Scope:** Accelerating `Yog.Centrality` and `Yog.Community` algorithms via Zigler NIFs backed by Zog's `ArrayGraph`.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Why Zig / Zog?](#2-why-zig--zog)
3. [NIF Architectural Patterns](#3-nif-architectural-patterns)
4. [Mapping Yog.Graph to Zog ArrayGraph](#4-mapping-yoggraph-to-zog-arraygraph)
5. [The ArrayGraph Resource (Future)](#5-the-arraygraph-resource-future)
6. [Conversion: Elixir → Zig](#6-conversion-elixir--zig)
7. [Algorithm NIF: Betweenness Centrality](#7-algorithm-nif-betweenness-centrality)
8. [Algorithm NIF: Louvain Communities](#8-algorithm-nif-louvain-communities)
9. [Weighted vs. Unweighted Graphs](#9-weighted-vs-unweighted-graphs)
10. [The Elixir `Yog.Zog` Module](#10-the-elixir-yogzog-module)
11. [Build Integration](#11-build-integration)
12. [Scheduler Safety & Dirty NIFs](#12-scheduler-safety--dirty-nifs)
13. [Resource Lifecycle](#13-resource-lifecycle)
14. [Recommended Rollout Plan](#14-recommended-rollout-plan)

---

## 1. Executive Summary

The `Yog.Graph` struct is a pure-Elixir adjacency-list representation. For algorithms like **Betweenness Centrality** and **Louvain Community Detection**, the BEAM's strengths (lightweight processes, fault tolerance) are outweighed by its limitations (no mutable arrays, no dense cache-friendly memory layouts).

**Zog** (the Zig graph library in `priv/zog/`) already provides a high-performance **Structure-of-Arrays** `ArrayGraph` and implementations of the expensive algorithms. **Zigler** bridges Zog into Elixir as NIFs.

What the Zig stack provides:

- **Dense integer-indexed graphs** (`ArrayGraph`) for cache-friendly traversal.
- **Algorithms already implemented** in Zog (Brandes, Louvain, PageRank, etc.).
- **Very fast compile times** — NIF rebuilds in ~1 second during development.
- **Dirty NIF scheduling** so long computations don't freeze the BEAM.

---

## 2. Why Zig / Zog?

| Factor | Rust + Rustler | Zig + Zigler + Zog |
|--------|----------------|--------------------|
| **NIF ecosystem** | Mature (`rustler`, `rustler_precompiled`). | Emerging (`zigler`). No precompiled release support yet. |
| **Graph library** | Write or import (`petgraph`). | **Zog already exists in this repo.** Zero algorithm rewrite. |
| **Compile times** | Slower. | **Very fast.** |
| **Binary size** | Larger. | **Smaller.** |
| **C interop** | Good via `bindgen`. | **Excellent** — imports C headers directly. |
| **Precompiled shipping** | `rustler_precompiled` handles it. | **Not available.** Users need Zig installed. |

**Trade-off:** You lose `rustler_precompiled` (users must have Zig to compile the NIF), but you gain **instant algorithm reuse** from Zog and sub-second NIF rebuilds.

**Mitigation:** Make `zigler` an `optional: true` dependency. Pure-Elixir Yog works out of the box; native acceleration is opt-in.

---

## 3. NIF Architectural Patterns

### Pattern 1: Copy-In / Copy-Out (Current)

Every NIF call serializes the graph into flat arrays, builds an `ArrayGraph`, runs the algorithm, and returns results.

```elixir
builder = Yog.Builder.Zog.directed()
|> Yog.Builder.Zog.add_edge("A", "B", 1.0)

# NIF rebuilds ArrayGraph on every call
Yog.Zog.Centrality.betweenness_unweighted(builder)
```

- **Pro:** Dead simple, no resource management.
- **Con:** For large graphs, the `O(V+E)` copy overhead dominates if you run many algorithms.

### Pattern 2: Resource Objects (Recommended for Expansion)

Create the native graph **once**, store it as a NIF **resource** (an opaque pointer managed by the BEAM), and pass a reference to subsequent NIF calls.

```elixir
builder = Yog.Builder.Zog.from_graph(my_yog_graph)

# One-time conversion
native = Yog.Zog.NativeGraph.from_builder(builder)

# Many cheap algorithm calls
Yog.Zog.Centrality.betweenness(native)
Yog.Zog.Community.louvain(native, 1.0)
Yog.Zog.Centrality.pagerank(native)

# Resource auto-freed when GC'd
```

- **Pro:** Pay conversion cost once. Optimal native memory layout.
- **Con:** If the graph is mutable, you must re-convert on every mutation.

**Yog.Graph is immutable**, so Pattern 2 is a natural fit for multi-algorithm workflows.

---

## 4. Mapping Yog.Graph to Zog ArrayGraph

Your struct:

```elixir
%Yog.Graph{
  kind: :directed | :undirected,
  nodes: %{node_id() => any()},           # labels / data
  out_edges: %{node_id() => %{node_id() => number()}},
  in_edges:  %{node_id() => %{node_id() => number()}}
}
```

**Key challenge:** `node_id` is `term()` — any Elixir value. Zog's `ArrayGraph` needs **dense integer indices** (`u32`) for cache efficiency.

**Solution:** `Yog.Builder.Zog` builds the bi-directional mapping at conversion time.

```
Elixir node_id  <->  Zog NodeIndex (u32)
   "Alice"    <->      0
   "Bob"      <->      1
   :node_3    <->      2
```

All internal Zog algorithms operate on `u32` indices. Only the Elixir boundary layer maps back to original terms.

### Zog ArrayGraph (SoA Design)

Zog's `ArrayGraph(NodeData, EdgeData)` (`priv/zog/src/models/array_graph.zig`) is exactly the dense SoA representation the Rust plan described:

```zig
pub fn ArrayGraph(comptime NodeData: type, comptime EdgeData: type) type {
    return struct {
        pub const NodeIndex = u32;
        pub const EdgeIndex = u32;

        pub const Node = struct {
            data: NodeData,
            first_edge: ?EdgeIndex = null,
            is_deleted: bool = false,
        };

        pub const Edge = struct {
            to: NodeIndex,
            data: EdgeData,
            next_edge: ?EdgeIndex = null,
            is_deleted: bool = false,
        };

        nodes: std.MultiArrayList(Node),
        edges: std.MultiArrayList(Edge),
        // ...
    };
}
```

**Why SoA beats Elixir's nested maps:**

| Concern | Elixir `%Yog.Graph{}` | Zog `ArrayGraph` |
|---|---|---|
| **Memory layout** | Nested maps, scattered buckets | Contiguous `MultiArrayList` per field |
| **Cache** | Hash + map lookup per edge | Prefetcher-friendly sequential scan |
| **Iteration** | `Map.get` + tuple creation | Direct field-slice index: `edges.items(.to)[i]` |
| **Resize** | Each inner map may rehash independently | Bulk pre-allocation at graph build time |

> **No tombstoning needed:** Unlike Zog's general `ArrayGraph` which supports `removeNode`/`removeEdge`, the NIF graph is **read-only** after conversion from Elixir. Iterators skip tombstone checks for maximum speed.

> **Dual storage:** Zog's `ArrayGraph` stores outgoing edges only. Algorithms that need predecessors (PageRank, Katz) call `utils.buildInNeighbors` to construct a temporary reverse map. This mirrors the Rust plan's `node_first_in` / `edge_next_in`, but computed on-demand instead of stored.

---

## 5. Conversion: Elixir → Zig

The conversion happens in **pure Elixir** inside `Yog.Builder.Zog`, not in a NIF. This keeps the NIF boundary extremely simple: plain `[]u32` and `[]f64` arrays that Zigler auto-marshals.

```elixir
# lib/yog/builder/zog.ex

def from_graph(%Yog.Graph{kind: kind, nodes: nodes, out_edges: out_edges}) do
  node_ids = nodes |> Map.keys() |> Enum.sort()
  label_to_id = node_ids |> Enum.with_index() |> Map.new()

  edges =
    for {src, dsts} <- out_edges,
        {dst, weight} <- dsts,
        reduce: [] do
      acc ->
        src_idx = Map.fetch!(label_to_id, src)
        dst_idx = Map.fetch!(label_to_id, dst)
        [{src_idx, dst_idx, to_float(weight)} | acc]
    end

  %__MODULE__{
    kind: kind,
    label_to_id: label_to_id,
    id_to_label: invert_map(label_to_id),
    nodes: node_ids,
    edges: Enum.reverse(edges),
    next_id: length(node_ids)
  }
end
```

**Complexity:** `O(V + E)`. Single pass. No NIF call overhead during conversion.

**NIF-facing extraction:**

```elixir
def to_edge_arrays(%__MODULE__{edges: edges}) do
  ordered = Enum.reverse(edges)
  froms   = for {f, _, _} <- ordered, do: f
  tos     = for {_, t, _} <- ordered, do: t
  weights = for {_, _, w} <- ordered, do: w
  {froms, tos, weights}
end
```

---

## 6. Algorithm NIF: Betweenness Centrality

Zog already implements Brandes' algorithm. The NIF is a thin wrapper:

```zig
const std = @import("std");
const beam = @import("beam");
const zog = @import("zog");

const ArrayGraph = zog.models.ArrayGraph;

pub fn betweenness_unweighted(node_count: usize, from: []u32, to: []u32) ![]f64 {
    const allocator = beam.allocator;

    var g = ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    try g.nodes.ensureTotalCapacity(allocator, node_count);
    try g.edges.ensureTotalCapacity(allocator, from.len);

    for (0..node_count) |_| { _ = try g.addNode({}); }
    for (from, to) |f, t| { _ = try g.addEdge(f, t, 1.0); }

    var result = try zog.centrality.betweennessUnweighted(allocator, g);
    defer result.deinit();

    var scores = try allocator.alloc(f64, node_count);
    errdefer allocator.free(scores);

    for (0..node_count) |i| {
        scores[i] = result.get(@intCast(i));
    }

    return scores;
}
```

**Key difference from a Rust implementation:** There is no hand-rolled Brandes algorithm. We call `zog.centrality.betweennessUnweighted` directly.

**Critical:** Marked with `concurrency: :dirty_cpu` in the `use Zig` options so it runs on the BEAM's dirty scheduler thread pool.

---

## 7. Algorithm NIF: Louvain Communities

Zog's Louvain is in `priv/zog/src/community/louvain.zig`. The NIF wrapper follows the exact same pattern as Betweenness:

```zig
pub fn louvain_detect(node_count: usize, from: []u32, to: []u32) ![]usize {
    const allocator = beam.allocator;

    var g = ArrayGraph(void, f64).init(allocator);
    defer g.deinit();

    for (0..node_count) |_| { _ = try g.addNode({}); }
    for (from, to) |f, t| { _ = try g.addEdge(f, t, 1.0); }

    var result = try zog.community.louvain.detect(allocator, g);
    defer result.deinit();

    var assignments = try allocator.alloc(usize, node_count);
    errdefer allocator.free(assignments);

    for (0..node_count) |i| {
        assignments[i] = result.assignments.get(@intCast(i)) orelse 0;
    }

    return assignments;
}
```

> **Note:** Zog's Louvain internally hardcodes `ArrayGraph(void, f64)` for its Phase 2 aggregation meta-graph. Feeding it an `ArrayGraph` from the start avoids a generic-to-concrete conversion step inside the algorithm.

---

## 8. Weighted vs. Unweighted Graphs

The simplest unified approach: **always store `f64` weights.**

- **Weighted graph:** Store the actual weights in `Yog.Builder.Zog.add_edge/4`.
- **Unweighted graph:** Store `1.0` for every edge.

This avoids maintaining two parallel graph types in Zig.

For algorithms that are strictly unweighted (e.g., betweenness unweighted), the weight value is ignored:

```zig
for (from, to) |f, t| {
    _ = try g.addEdge(f, t, 1.0);
}
```

For weighted algorithms, pass the real weights:

```zig
pub fn betweenness_weighted(
    node_count: usize,
    from: []u32,
    to: []u32,
    weight: []f64,
) ![]f64 {
    // ...
    for (from, to, weight) |f, t, w| {
        _ = try g.addEdge(f, t, w);
    }
    var result = try zog.centrality.betweennessF64(allocator, g);
    // ...
}
```

**Memory optimization:** If you have massive unweighted graphs and the `f64` per edge matters, pass `void` as `EdgeData` and use unweighted Zog algorithm variants. This saves 8 bytes per edge.

---

## 9. The Elixir `Yog.Zog` Module

```elixir
# lib/yog/zog.ex
defmodule Yog.Zog do
  @moduledoc """
  Native graph algorithms via Zog (Zig) and Zigler.
  """

  def from_graph(graph), do: Yog.Builder.Zog.from_graph(graph)
  def from_labeled(labeled), do: Yog.Builder.Zog.from_labeled(labeled)
  def to_graph(builder), do: Yog.Builder.Zog.to_graph(builder)
end
```

### Example Public API Module with Threshold Dispatch

```elixir
# lib/yog/centrality/betweenness.ex
defmodule Yog.Centrality.Betweenness do
  alias Yog.Zog.Centrality, as: ZogCentrality

  @nif_threshold 500

  @spec compute(Yog.graph()) :: %{Yog.node_id() => float()}
  def compute(%Yog.Graph{} = graph) do
    if Yog.Model.order(graph) >= @nif_threshold do
      graph
      |> Yog.Builder.Zog.from_graph()
      |> ZogCentrality.betweenness_unweighted()
    else
      compute_elixir(graph)
    end
  end

  defp compute_elixir(graph) do
    # existing pure-Elixir Brandes implementation
    Yog.Centrality.Betweenness.Pure.compute(graph)
  end
end
```

**Why threshold dispatch matters:** For small graphs, the `O(V+E)` NIF copy overhead plus dirty-scheduler thread handoff can exceed the runtime of a pure-Elixir implementation. Profile first, NIF second.

---

## 10. Build Integration

Add to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps ...
    {:zigler, "~> 0.15.2", runtime: false, optional: true}
  ]
end
```

Pin Zig version in `mise.toml` (or your version manager):

```toml
[tools]
elixir = "latest"
zig = "0.15.2"
```

> **Zig version constraint:** zigler 0.15.2 requires Zig 0.15.x. Do not use Zig 0.16.0 until zigler releases a compatible version.

---

## 11. Scheduler Safety & Dirty NIFs

| Algorithm | Typical Runtime | NIF Type |
|-----------|----------------|----------|
| Betweenness Centrality | 100ms – 60s | `:dirty_cpu` |
| Louvain | 50ms – 30s | `:dirty_cpu` |
| Label Propagation | 10ms – 5s | `:dirty_cpu` |
| Graph conversion | 1ms – 100ms | `:synchronous` |

A regular NIF runs on a BEAM scheduler thread. If it takes longer than ~1ms, it blocks that scheduler from running other processes. **Always use `:dirty_cpu`** for graph algorithms.

In Zigler:

```elixir
use Zig,
  otp_app: :yog_ex,
  extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
  nifs: [
    ...,
    betweenness_unweighted: [concurrency: :dirty_cpu],
    louvain_detect: [concurrency: :dirty_cpu]
  ]
```

If your NIF does file I/O or blocking syscalls, use `:dirty_io` instead.

---

## 12. Resource Lifecycle (Pattern 2)

Zigler supports BEAM resources via the `resources` option in `use Zig`:

```elixir
use Zig,
  otp_app: :yog_ex,
  resources: [:native_graph]
```

```zig
const std = @import("std");
const zog = @import("zog");
const ArrayGraph = zog.models.ArrayGraph;

pub const NativeGraph = ArrayGraph(void, f64);

pub fn native_graph_new(node_count: usize, from: []u32, to: []u32, weight: []f64) !*NativeGraph {
    const allocator = beam.allocator;
    var g = try allocator.create(NativeGraph);
    g.* = NativeGraph.init(allocator);

    for (0..node_count) |_| { _ = try g.addNode({}); }
    for (from, to, weight) |f, t, w| { _ = try g.addEdge(f, t, w); }

    return g;
}

pub fn betweenness_on_resource(graph: *NativeGraph) ![]f64 {
    const allocator = beam.allocator;
    var result = try zog.centrality.betweennessUnweighted(allocator, graph.*);
    defer result.deinit();

    var scores = try allocator.alloc(f64, graph.nodeCount());
    // ... copy scores ...
    return scores;
}
```

The resource is garbage-collected by the BEAM when no Elixir term references it. Zog's `ArrayGraph.deinit()` frees the `MultiArrayList` buffers.

> **Thread safety:** Resources are read-only in our design. Multiple Elixir processes can safely share a `NativeGraph` resource. Do not mutate the graph from NIF calls unless you protect it with a `std.Thread.Mutex`.

---

## 13. Prioritized NIF Roadmap

This roadmap is based on algorithmic complexity and the gap between Elixir's map-based performance and what Zog's dense SoA delivers.

> **Guiding principle:** NIFs are for algorithms where the **data structure overhead** (map lookups, tuple allocations, process scheduling) dominates the actual computation. `O(V+E)` algorithms rarely need NIFs. `O(V²)`, `O(V³)`, `O(VE)`, and iterative algorithms do.

---

### Tier 1 — Immediate (Proof of Concept)

**Goal:** Validate the NIF stack, measure speedup, and establish the SoA resource pattern.

| Algorithm | Module | Complexity | Why First? |
|---|---|---|---|
| **Betweenness Centrality** | `Yog.Zog.Centrality` | `O(VE)` | Classic Brandes. Already working. |
| **Louvain Communities** | `Yog.Zog.Community` | `O(E × phases)` | Zog has `community.louvain.detect`. Phase 2 aggregation already hardcodes `ArrayGraph`. |

**Deliverables:**
- `Yog.Builder.Zog` conversion module ✅
- `betweenness_unweighted/1` NIF (`:dirty_cpu`) ✅
- `louvain_detect/1` NIF (`:dirty_cpu`) — next
- Benchmark suite comparing pure-Elixir vs. NIF on `:karate_club`, 5k-node random, and 50k-node random graphs

---

### Tier 2 — High-Impact Expansion

**Goal:** Cover the algorithms that users actually run on large graphs and feel the pain.

| Algorithm | Module | Complexity | NIF Case |
|---|---|---|---|
| **Label Propagation** | `Yog.Zog.Community` | `O(iterations × E)` | Simple but iterative. Each pass scans all edges. |
| **PageRank** | `Yog.Zog.Centrality` | `O(iterations × (V+E))` | Power iteration. In Elixir, each pass rebuilds rank maps. In Zog: two `Vec<f64>` swaps and a single edge-array pass. |
| **Eigenvector Centrality** | `Yog.Zog.Centrality` | `O(iterations × (V+E))` | Same sparse mat-vec pattern as PageRank. |
| **Katz Centrality** | `Yog.Zog.Centrality` | `O(iterations × (V+E))` | Attenuated walk counts. Same pattern. |

**Notes:**
- All of these are **read-only** on the graph, so they share the same `NativeGraph` resource (once Pattern 2 is implemented).
- The centrality NIFs are natural to group in a single Zigler module since they share the same `ArrayGraph(void, f64)` build primitive.

---

### Tier 3 — All-Pairs and Flow

**Goal:** Algorithms with heavy inner loops that operate on dense or semi-dense data.

| Algorithm | Module | Complexity | NIF Case |
|---|---|---|---|
| **Floyd-Warshall** | `Yog.Zog.Pathfinding` | `O(V³)` | The classic dense DP. Three nested loops over a `V×V` matrix. |
| **Johnson's APSP** | `Yog.Zog.Pathfinding` | `O(V² log V + VE)` | `V × Dijkstra`. Repeated priority queue overhead in Elixir adds up. |
| **Push-Relabel Max Flow** | `Yog.Zog.Flow` | `O(V³)` | Relabel-to-front with gap heuristic. Tight inner loops on residual capacities. |

**Notes:**
- Floyd-Warshall is the highest-value NIF in this tier. It's `O(V³)` with simple arithmetic — the gap between map-based Elixir and dense-array Zig is enormous.
- Max flow is trickier because it **mutates** the graph (residual capacities). You'd either clone the `ArrayGraph` into a mutable internal struct or add a mutable capacity layer on top of the read-only base graph.

---

### Tier 4 — Expensive / Exponential Algorithms

**Goal:** Make the intractable tractable for medium-sized graphs.

| Algorithm | Module | Complexity | NIF Case |
|---|---|---|---|
| **Girvan-Newman** | `Yog.Zog.Community` | `O(E²V)` or `O(E³)` | Repeatedly computes edge betweenness and removes the highest edge. A full NIF could keep the graph mutable in Zig and avoid `V+E` conversions per iteration. |
| **Bron-Kerbosch (cliques)** | `Yog.Zog.Property` | `O(3^(V/3))` | Exponential backtracking. The NIF win isn't algorithmic complexity — it's eliminating MapSet/map overhead in the recursive set operations. Zig `std.bit_set` over `u32` indices is far more compact than Elixir MapSets. |
| **Weisfeiler-Lehman** | `Yog.Zog.Property` | `O(iterations × (V+E))` | Hashing and relabeling neighborhoods repeatedly. In Zig, neighborhood hashes can be `u64` values computed with a single pass over `edge_to`. |

**Notes:**
- These are **specialized**. Only NIF them if users are asking for larger instances.
- Bron-Kerbosch with a `std.bit_set.IntegerBitSet` (one `u64` block per 64 nodes) is a particularly sweet spot for Zig.

---

### Tier 5 — Probably Not Worth It

These are either fast enough in Elixir or don't benefit from dense arrays:

| Algorithm | Module | Complexity | Why Skip? |
|---|---|---|---|
| **BFS / DFS** | `Yog.Traversal` | `O(V+E)` | The BEAM handles this fine. Maps are fast enough. |
| **Dijkstra (single-source)** | `Yog.Pathfinding` | `O((V+E) log V)` | Fine for one-off queries. Only NIF if wrapped in Johnson's APSP. |
| **A-Star** | `Yog.Pathfinding` | Same | Heuristic-guided; rarely the bottleneck. |
| **Kruskal / Prim / Boruvka** | `Yog.MST` | `O(E log E)` | MST is rarely the bottleneck in practice. |
| **K-Core decomposition** | `Yog.Connectivity` | `O(V+E)` | Linear time with bucket queues. BEAM handles it. |
| **SCC (Tarjan/Kosaraju)** | `Yog.Connectivity` | `O(V+E)` | Single DFS pass. |
| **Degree Centrality** | `Yog.Centrality` | `O(V+E)` | Trivial. |
| **Closeness / Harmonic** | `Yog.Centrality` | `O(V × (V+E))` | If you have the NIF for Johnson's APSP, you get these "for free" as post-processing. |

---

### What About `Yog.Approximate`?

Your `Yog.Approximate` module already provides sampling-based fast versions of expensive algorithms:

| Approximate Algorithm | Exact NIF? | Strategy |
|---|---|---|
| `diameter/2` | No exact NIF planned | Multi-sweep BFS is already `O(k(V+E))`. Keep in Elixir. |
| `betweenness/2` | **Yes** (Tier 1) | Once exact Brandes is a NIF, the approximate version may become unnecessary for many use cases. Or keep both: NIF for exact, Elixir for sampled. |
| `average_path_length/2` | Indirect (Johnson NIF) | Exact via Johnson's NIF; approximate stays in Elixir for huge graphs. |
| `transitivity/2` | No | Wedge sampling is `O(k)`. Fine in Elixir. |
| `max_clique/1` | **Yes** (Tier 4) | Bron-Kerbosch NIF for exact; approximate stays for very large graphs. |
| `treewidth_upper_bound/2` | **Yes** (Tier 4) | Heuristic elimination ordering in Zig. |

---

### Summary: Priority Order

```
1. Betweenness + Louvain          (validate the NIF stack)
2. Label Prop + PageRank + Katz   (expand coverage, shared primitives)
3. Floyd-Warshall + Johnson's     (all-pairs shortest path)
4. Push-Relabel / Dinic           (max flow)
5. Girvan-Newman + Walktrap       (slow community algorithms)
6. Bron-Kerbosch + Weisfeiler-Lehman  (NP-hard / exponential)
7. Everything else                (only if profiling demands it)
```

The golden rule: **profile first, NIF second.** If an Elixir algorithm finishes in <100ms on your target graph size, don't touch it. If it takes seconds or minutes, it's a NIF candidate.

---

## Appendix: File Layout

```
yog_ex/
├── lib/
│   ├── yog/
│   │   ├── builder/
│   │   │   └── zog.ex              # ZogBuilder (flat arrays, label mapping)
│   │   ├── zog.ex                  # Conversion helpers
│   │   ├── zog/
│   │   │   ├── centrality.ex       # Zigler NIF module
│   │   │   ├── community.ex        # Zigler NIF module
│   │   │   └── native_graph.ex     # Resource wrapper (Pattern 2, TODO)
│   │   └── ...
│   └── yog.ex
├── priv/
│   └── zog/                        # Your existing Zig library
│       ├── src/
│       │   ├── models/array_graph.zig
│       │   ├── centrality.zig
│       │   ├── community/louvain.zig
│       │   └── ...
│       └── design-docs.md          # this document
├── mix.exs
└── mise.toml                       # zig = "0.15.2"
```

---

*Document adapted from the Rust NIF design plan for the Zig/Zog implementation.*
