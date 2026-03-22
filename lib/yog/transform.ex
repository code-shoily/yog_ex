defmodule Yog.Transform do
  @moduledoc """
  Graph transformations and mappings - functor operations on graphs.

  This module provides operations that transform graphs while preserving their structure.
  These are useful for adapting graph data types, creating derived graphs, and
  preparing graphs for specific algorithms.

  ## Available Transformations

  | Transformation | Function | Complexity | Use Case |
  |----------------|----------|------------|----------|
  | Transpose | `transpose/1` | O(1) | Reverse edge directions |
  | Map Nodes | `map_nodes/2` | O(V) | Transform node data |
  | Map Edges | `map_edges/2` | O(E) | Transform edge weights |
  | Filter Nodes | `filter_nodes/2` | O(V) | Subgraph extraction |
  | Filter Edges | `filter_edges/2` | O(E) | Remove unwanted edges |

  ## The O(1) Transpose Operation

  Due to yog's dual-map representation (storing both outgoing and incoming edges),
  transposing a graph is a single pointer swap - dramatically faster than O(E)
  implementations in traditional adjacency list libraries.

  ## Functor Laws

  The mapping operations satisfy functor laws:
  - Identity: `map_nodes(g, fn(x) { x }) == g`
  - Composition: `map_nodes(map_nodes(g, f), h) == map_nodes(g, fn(x) { h(f(x)) })`

  ## Use Cases

  - **Kosaraju's Algorithm**: Requires transposed graph for SCC finding
  - **Type Conversion**: Changing node/edge data types for algorithm requirements
  - **Subgraph Extraction**: Working with portions of large graphs
  - **Weight Normalization**: Preprocessing edge weights
  """

  @doc """
  Reverses the direction of every edge in the graph (graph transpose).

  Due to the dual-map representation (storing both out_edges and in_edges),
  this is an **O(1) operation** - just a pointer swap! This is dramatically
  faster than most graph libraries where transpose is O(E).

  **Time Complexity:** O(1)

  **Property:** `transpose(transpose(G)) = G`

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 20}])
      iex> reversed = Yog.Transform.transpose(graph)
      iex> # Now has edges: 2->1 and 3->2
      iex> Yog.successors(reversed, 2)
      [{1, 10}]

  ## Use Cases

  - Computing strongly connected components (Kosaraju's algorithm)
  - Finding all nodes that can reach a target node
  - Reversing dependencies in a DAG
  """
  @spec transpose(Yog.graph()) :: Yog.graph()
  defdelegate transpose(graph), to: :yog@transform

  @doc """
  Transforms node data using a function, preserving graph structure.

  This is a functor operation - it applies a function to every node's data
  while keeping all edges and the graph structure unchanged.

  **Time Complexity:** O(V) where V is the number of nodes

  **Functor Law:** `map_nodes(map_nodes(g, f), h) == map_nodes(g, fn x -> h.(f.(x)) end)`

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "alice")
      ...>   |> Yog.add_node(2, "bob")
      iex> uppercased = Yog.Transform.map_nodes(graph, &String.upcase/1)
      iex> # Nodes now contain "ALICE" and "BOB"
      iex> elem(uppercased, 2)[1]
      "ALICE"

  ## Type Changes

  Can change the node data type:

      iex> # Convert string node data to integers
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "5")
      ...>   |> Yog.add_node(2, "10")
      iex> int_graph = Yog.Transform.map_nodes(graph, fn s -> String.to_integer(s) end)
      iex> elem(int_graph, 2)[1]
      5
  """
  @spec map_nodes(Yog.graph(), (term() -> term())) :: Yog.graph()
  defdelegate map_nodes(graph, fun), to: :yog@transform

  @doc """
  Transforms edge weights using a function, preserving graph structure.

  This is a functor operation - it applies a function to every edge's weight/data
  while keeping all nodes and the graph topology unchanged.

  **Time Complexity:** O(E) where E is the number of edges

  **Functor Law:** `map_edges(map_edges(g, f), h) == map_edges(g, fn x -> h.(f.(x)) end)`

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 20}])
      iex> # Double all weights
      iex> doubled = Yog.Transform.map_edges(graph, fn w -> w * 2 end)
      iex> # Edges now have weights 20 and 40
      iex> Yog.successors(doubled, 1)
      [{2, 20}]

  ## Type Changes

  Can change the edge weight type:

      iex> # Convert integer weights to floats
      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> float_graph = Yog.Transform.map_edges(graph, fn w -> w * 1.0 end)
      iex> Yog.successors(float_graph, 1)
      [{2, 10.0}]

      iex> # Convert weights to labels
      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 5)
      iex> labeled = Yog.Transform.map_edges(graph, fn w ->
      ...>   if w < 10, do: "short", else: "long"
      ...> end)
      iex> Yog.successors(labeled, 1)
      [{2, "short"}]
  """
  @spec map_edges(Yog.graph(), (term() -> term())) :: Yog.graph()
  defdelegate map_edges(graph, fun), to: :yog@transform

  @doc """
  Filters nodes by a predicate, automatically pruning connected edges.

  Returns a new graph containing only nodes whose data satisfies the predicate.
  All edges connected to removed nodes (both incoming and outgoing) are
  automatically removed to maintain graph consistency.

  **Time Complexity:** O(V + E) where V is nodes and E is edges

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "apple")
      ...>   |> Yog.add_node(2, "banana")
      ...>   |> Yog.add_node(3, "apricot")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 2)
      iex> # Keep only nodes starting with 'a'
      iex> filtered = Yog.Transform.filter_nodes(graph, fn s ->
      ...>   String.starts_with?(s, "a")
      ...> end)
      iex> # Result has nodes 1 and 3, edge 1->2 is removed (node 2 gone)
      iex> map_size(elem(filtered, 2))
      2

  ## Use Cases

  - Extract subgraphs based on node properties
  - Remove inactive/disabled nodes from a network
  - Filter by node importance/centrality
  """
  @spec filter_nodes(Yog.graph(), (term() -> boolean())) :: Yog.graph()
  defdelegate filter_nodes(graph, predicate), to: :yog@transform

  @doc """
  Filters edges by a predicate, preserving all nodes.

  Returns a new graph with the same nodes but only the edges where the
  predicate returns `true`. The predicate receives `(src, dst, weight)`.

  **Time Complexity:** O(E) where E is the number of edges

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 5}, {1, 3, 15}, {2, 3, 3}])
      iex> # Keep only edges with weight >= 10
      iex> heavy = Yog.Transform.filter_edges(graph, fn _src, _dst, w -> w >= 10 end)
      iex> # Result: edges [1->3 (15)], edges 1->2 and 2->3 removed
      iex> Yog.successors(heavy, 1)
      [{3, 15}]

  ## Use Cases

  - Pruning low-weight edges in weighted networks
  - Removing self-loops: `filter_edges(g, fn(s, d, _) -> s != d end)`
  - Threshold-based graph sparsification
  """
  @spec filter_edges(Yog.graph(), (Yog.node_id(), Yog.node_id(), term() -> boolean())) ::
          Yog.graph()
  defdelegate filter_edges(graph, predicate), to: :yog@transform

  @doc """
  Creates the complement of a graph.

  The complement contains the same nodes but connects all pairs of nodes
  that are **not** connected in the original graph, and removes all edges
  that **are** present. Each new edge gets the supplied `default_weight`.

  Self-loops are never added in the complement.

  **Time Complexity:** O(V² + E)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> comp = Yog.Transform.complement(graph, 100)
      iex> # Original: 1-2 connected, 1-3 and 2-3 not
      iex> # Complement: 1-3 and 2-3 connected, 1-2 not
      iex> {1, 100} in Yog.successors(comp, 3)
      true

  ## Use Cases

  - Finding independent sets (cliques in the complement)
  - Graph coloring via complement analysis
  - Testing graph density (sparse ↔ dense complement)
  """
  @spec complement(Yog.graph(), term()) :: Yog.graph()
  defdelegate complement(graph, default_weight), to: :yog@transform

  @doc """
  Combines two graphs, with the second graph's data taking precedence on conflicts.

  Merges nodes, out_edges, and in_edges from both graphs. When a node exists in
  both graphs, the node data from `other` overwrites `base`. When the same edge
  exists in both graphs, the edge weight from `other` overwrites `base`.

  Importantly, edges from different nodes are combined - if `base` has edges
  1->2 and 1->3, and `other` has edges 1->4 and 1->5, the result will have
  all four edges from node 1.

  The resulting graph uses the `kind` (Directed/Undirected) from the base graph.

  **Time Complexity:** O(V + E) for both graphs combined

  ## Example

      iex> base =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "Original")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 10)
      iex> other =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "Updated")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 20)
      iex> merged = Yog.Transform.merge(base, other)
      iex> # Node 1 has "Updated" (from other)
      iex> # Node 1 has edges to: 2 and 3 (all edges combined)
      iex> length(Yog.successors(merged, 1))
      2

  ## Use Cases

  - Combining disjoint subgraphs
  - Applying updates/patches to a graph
  - Building graphs incrementally from multiple sources
  """
  @spec merge(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate merge(base, other), to: :yog@transform

  @doc """
  Extracts a subgraph containing only the specified nodes and their connecting edges.

  Returns a new graph with only the nodes whose IDs are in the provided list,
  along with any edges that connect nodes within this subset. Nodes not in the
  list are removed, and all edges touching removed nodes are pruned.

  **Time Complexity:** O(V + E) where V is nodes and E is edges

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 20}, {3, 4, 30}])
      iex> # Extract only nodes 2 and 3
      iex> sub = Yog.Transform.subgraph(graph, [2, 3])
      iex> # Result has nodes 2, 3 and edge 2->3
      iex> # Edges 1->2 and 3->4 are removed (endpoints outside subgraph)
      iex> Yog.successors(sub, 2)
      [{3, 20}]

  ## Use Cases

  - Extracting connected components found by algorithms
  - Analyzing k-hop neighborhoods around specific nodes
  - Working with strongly connected components (extract each SCC)
  - Removing nodes found by some criteria (keep the inverse set)
  - Visualizing specific portions of large graphs

  ## Comparison with `filter_nodes/2`

  - `filter_nodes/2` - Filters by predicate on node data (e.g., "keep active users")
  - `subgraph/2` - Filters by explicit node IDs (e.g., "keep nodes [1, 5, 7]")
  """
  @spec subgraph(Yog.graph(), [Yog.node_id()]) :: Yog.graph()
  defdelegate subgraph(graph, keeping), to: :yog@transform

  @doc """
  Contracts an edge by merging node `b` into node `a`.

  Node `b` is removed from the graph, and all edges connected to `b` are
  redirected to `a`. If both `a` and `b` had edges to the same neighbor,
  their weights are combined using `with_combine`.

  Self-loops (edges from a node to itself) are removed during contraction.

  **Important for undirected graphs:** Since undirected edges are stored
  bidirectionally, each logical edge is processed twice during contraction,
  causing weights to be combined twice. For example, if edge weights represent
  capacities, this effectively doubles them. Consider dividing weights by 2
  or using a custom combine function if this behavior is undesired.

  **Time Complexity:** O(deg(a) + deg(b)) - proportional to the combined
  degree of both nodes.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 10)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 20)
      iex> contracted = Yog.Transform.contract(graph, 1, 2, fn w1, w2 -> w1 + w2 end)
      iex> # Result: nodes [1, 3], edge 1->3 with weight 20
      iex> # Node 2 is merged into node 1
      iex> Yog.successors(contracted, 1)
      [{3, 20}]

  ## Combining Weights

  When both `a` and `b` have edges to the same neighbor `c`:

      iex> # Before: a->c (5), b->c (10)
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 5)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 10)
      iex> contracted = Yog.Transform.contract(graph, 1, 2, fn w1, w2 -> w1 + w2 end)
      iex> # After: a->c (15) (5 + 10)
      iex> Yog.successors(contracted, 1)
      [{3, 15}]

  ## Use Cases

  - **Stoer-Wagner algorithm** for minimum cut
  - **Graph simplification** by merging strongly connected nodes
  - **Community detection** by contracting nodes in the same community
  - **Karger's algorithm** for minimum cut (randomized)
  """
  @spec contract(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          (term(), term() -> term())
        ) :: Yog.graph()
  defdelegate contract(graph, a, b, combine_weight), to: :yog@transform

  @doc """
  Converts an undirected graph to a directed graph.

  Since yog internally stores undirected edges as bidirectional directed edges,
  this is essentially free — it just changes the `kind` flag. The resulting
  directed graph has two directed edges (A→B and B→A) for each original
  undirected edge.

  If the graph is already directed, it is returned unchanged.

  **Time Complexity:** O(1)

  ## Example

      iex> undirected =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 10)
      iex> directed = Yog.Transform.to_directed(undirected)
      iex> # Has edges: 1->2 and 2->1 (both with weight 10)
      iex> elem(directed, 1)
      :directed
  """
  @spec to_directed(Yog.graph()) :: Yog.graph()
  defdelegate to_directed(graph), to: :yog@transform

  @doc """
  Converts a directed graph to an undirected graph.

  For each directed edge A→B, ensures B→A also exists. If both A→B and B→A
  already exist with different weights, the `resolve` function decides which
  weight to keep.

  If the graph is already undirected, it is returned unchanged.

  **Time Complexity:** O(E) where E is the number of edges

  ## Examples

  ### When both directions exist, keep the smaller weight

      iex> directed =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edges!([{1, 2, 10}, {2, 1, 20}])
      iex> undirected = Yog.Transform.to_undirected(directed, &min/2)
      iex> # Edge 1-2 has weight 10 (min of 10 and 20)
      iex> Yog.successors(undirected, 1)
      [{2, 10}]

  ### One-directional edges get mirrored automatically

      iex> directed =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 5)
      iex> undirected = Yog.Transform.to_undirected(directed, &min/2)
      iex> # Edge exists in both directions with weight 5
      iex> Enum.sort(Yog.successors(undirected, 1))
      [{2, 5}]
  """
  @spec to_undirected(Yog.graph(), (term(), term() -> term())) :: Yog.graph()
  defdelegate to_undirected(graph, resolve), to: :yog@transform
end
