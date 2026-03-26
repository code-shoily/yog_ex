# Yog.Functional

> Functional inductive graphs for Elixir researchers and learners.

This package provides an **inductive graph representation** based on Martin Erwig's [Functional Graph Library (FGL)](https://web.engr.oregonstate.edu/~erwig/fgl/). Unlike the traditional adjacency-list approach used in `Yog.Graph`, these graphs are defined recursively, enabling algorithms to be written as pure, recursive functions without explicit "visited" sets.

## Philosophy: The Inductive Principle

An inductive graph is defined by two constructors:
1.  **Empty**: A graph with no nodes.
2.  **Embed**: Formed by adding a node context to an existing graph. This is the inverse of `match/2`.

### The Inductive Duality: Match and Embed

-   **Match (`Decompose`)**: Extracts a node and its context. The resulting **remaining graph** is the new "shrunken" world view. The node and all its incident edges are gone, so the graph is structurally smaller.
-   **Embed (`Compose`)**: The inverse. It takes a context and a graph to produce a new (larger) graph.

```elixir
alias Yog.Functional.Model

# Match node 1
{:ok, context, shrunken_graph} = Model.match(graph, 1)

# Embed it back (potentially into a transformed graph)
new_graph = Model.embed(shrunken_graph, context)
```

### Pattern Matching Friendly

Just as lists are defined as `[head | tail]`, these graphs are defined as `context & remaining`. Every recursive step handles these as "head" and "tail", allowing for code that reads like pattern matching:

1.  Base case: `Model.empty()` (the empty graph).
2.  Recursive case: `match(graph, id)` gives you the context (head) and the shrunken world view (tail).

Every time you recurse with the `shrunken_graph`, you are operating on a self-contained "sub-universe" where the earlier nodes simply do not exist.

By working with `remaining_graph`, algorithms naturally prevent revisits: once a node is matched, it and all its edges are gone from the perspective of the recursion. The algorithm terminates when `Model.empty?(graph)` is true.

## Data Example: Shrinking the Graph

Consider a simple directed graph: `1 -> 2 -> 3`.

1.  **Initial Graph**: Represents the full structure `{1, 2, 3}`.
2.  **Match 1**: 
    -   **Context**: `id: 1, label: "A", out_edges: %{2 => nil}`
    -   **Remaining**: A graph containing only `2 -> 3`. Node 1 and the edge `1 -> 2` have been structurally removed.
3.  **Match 2** (on the remaining graph):
    -   **Context**: `id: 2, label: "B", out_edges: %{3 => nil}`
    -   **Remaining**: A graph containing only the isolated node `3`.
4.  **Match 3**:
    -   **Context**: `id: 3, label: "C"`
    -   **Remaining**: `Model.empty()`.

## The Build/Burn Pattern: Context as State

The fundamental pattern for working with inductive graphs is what we call **build/burn** — alternating between deconstructing (burning) and reconstructing (building) the graph. The **context** is your handle on the current "focus" of the graph.

### Deconstruction (Burn): `match/2`

When you `match` a node, you receive:
1. **The Context** — the node's ID, label, and all its incident edges
2. **The Remaining Graph** — the graph with this node *burned away*, edges and all

```elixir
alias Yog.Functional.Model

graph = Model.empty()
|> Model.put_node(1, "Alice")
|> Model.put_node(2, "Bob")
|> Model.put_node(3, "Carol")
|> Model.add_edge!(1, 2, :follows)
|> Model.add_edge!(2, 3, :follows)

# Burn node 1 — extract it from the graph
{:ok, ctx, remaining} = Model.match(graph, 1)

# ctx.id == 1
# ctx.label == "Alice"
# ctx.out_edges == %{2 => :follows}
# ctx.in_edges == %{} (no one follows Alice in this graph)

# remaining contains nodes 2 and 3, but NO edge from 1->2
# because node 1 and all its edges have been burned away
```

### Construction (Build): `embed/2`

The inverse operation restores a context into a graph. This enables **transform-then-rebuild** workflows:

```elixir
# Transform the context (e.g., increment a counter in the label)
new_ctx = %{ctx | label: %{ctx.label | visits: ctx.label.visits + 1}}

# Build it back into a (possibly different) graph
restored_graph = Model.embed(new_ctx, remaining)
```

### Traversal Example: Finding All Nodes with a Property

Here's how you traverse by burning through the graph, collecting matches:

```elixir
def find_influencers(graph, min_followers, acc \\ []) do
  # Try to match any remaining node
  case Model.match_any(graph) do
    {:error, :empty} ->
      # Base case: graph is burned away completely
      Enum.reverse(acc)
      
    {:ok, ctx, remaining} ->
      # ctx is our "current state" — we have full info about this node
      follower_count = map_size(ctx.in_edges)
      
      # Decide based on context, then continue burning the rest
      new_acc = if follower_count >= min_followers do
        [{ctx.id, ctx.label, follower_count} | acc]
      else
        acc
      end
      
      # Recurse on the BURNED graph — ctx.id is gone, so we can't revisit
      find_influencers(remaining, min_followers, new_acc)
  end
end

# Usage:
# find_influencers(social_graph, 1000, [])
# => [{2, "Bob", 1500}, {5, "Eve", 2300}]
```

### Key Insight: The Context *is* Your Iterator

In traditional graphs, you iterate over node IDs and look up data. In FGL:

- **The context bundles identity, data, AND connectivity** — you have everything needed to decide "what next" without additional lookups
- **The remaining graph IS your visited set** — burned nodes simply don't exist anymore
- **No back-edges possible** — once you `match` a node, it cannot be reached from any future recursive call

This makes algorithms like DFS trivially correct without explicit cycle detection:

```elixir
def dfs(graph, []), do: []
def dfs(graph, [v | vs]) do
  case Model.match(graph, v) do
    {:ok, ctx, remaining} ->
      # ctx.out_edges tells us where to go next
      # remaining ensures we never come back to ctx.id
      neighbors = Map.keys(ctx.out_edges)
      [ctx | dfs(remaining, neighbors ++ vs)]
      
    {:error, :not_found} ->
      # Already burned — skip
      dfs(graph, vs)
  end
end
```

## Features

-   **Memory Efficiency**: Leverages Elixir's persistent data structures (Maps) to represent the recursive decomposition efficiently.
-   **Algorithm Suite**: Includes Topological Sort, SCC (Kosaraju), Dijkstra, Prim's MST, and Dominators.
-   **Interop**: Convert to and from the adjacency-based `Yog.Graph` model using `Model.from_adjacency_graph/1`.

## References

-   **Martin Erwig (2001)**: [Inductive Graphs and Functional Graph Algorithms](https://web.engr.oregonstate.edu/~erwig/papers/InductiveGraphs_JFP01.pdf) - The foundational paper.
-   **Haskell FGL**: [hackage.haskell.org/package/fgl](https://hackage.haskell.org/package/fgl) - The industry-standard functional graph library.
-   **Programming in Haskell (Graham Hutton)**: Chapter on functional graph algorithms.

---

**Note**: This module is primarily for **research and educational purposes**. For high-performance production workloads involving millions of edges, the ephemeral `Yog.Graph` is generally recommended.
