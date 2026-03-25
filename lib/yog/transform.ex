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
  | Map Nodes Async | `map_nodes_async/2` | O(V/cores) | Parallel node transforms |
  | Map Edges | `map_edges/2` | O(E) | Transform edge weights |
  | Map Edges Async | `map_edges_async/2` | O(E/cores) | Parallel edge transforms |
  | Filter Nodes | `filter_nodes/2` | O(V) | Subgraph extraction |
  | Filter Edges | `filter_edges/2` | O(E) | Remove unwanted edges |

  ## Parallel Transformations

  The `_async` variants use `Task.async_stream/3` for parallel processing on multi-core
  systems. They're beneficial for:
  - Large graphs (10K+ nodes, 100K+ edges)
  - Expensive transformation functions (I/O, complex computations)
  - Multi-core environments where parallelism outweighs overhead

  For small graphs or trivial transforms, use the sequential versions to avoid task overhead.

  ## The O(1) Transpose Operation

  Due to yog's dual-map representation (storing both outgoing and incoming edges),
  transposing a graph is a single pointer swap - dramatically faster than O(E)
  implementations in traditional adjacency list libraries.

  ## Functor Laws

  The mapping operations satisfy functor laws:
  - Identity: `map_nodes(g, fn x -> x end) == g`
  - Composition: `map_nodes(map_nodes(g, f), h) == map_nodes(g, fn x -> h.(f.(x)) end)`

  ## Use Cases

  - **Kosaraju's Algorithm**: Requires transposed graph for SCC finding
  - **Type Conversion**: Changing node/edge data types for algorithm requirements
  - **Subgraph Extraction**: Working with portions of large graphs
  - **Weight Normalization**: Preprocessing edge weights
  - **Parallel Processing**: Large-scale data transformations on multi-core systems

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged. Async variants added in v0.60.1.
  """

  alias Yog.Model

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
  def transpose(%Yog.Graph{} = graph) do
    %{graph | out_edges: graph.in_edges, in_edges: graph.out_edges}
  end

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
      iex> uppercased.nodes[1]
      "ALICE"

  ## Type Changes

  Can change the node data type:

      iex> # Convert string node data to integers
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "5")
      ...>   |> Yog.add_node(2, "10")
      iex> int_graph = Yog.Transform.map_nodes(graph, fn s -> String.to_integer(s) end)
      iex> int_graph.nodes[1]
      5
  """
  @spec map_nodes(Yog.graph(), (term() -> term())) :: Yog.graph()
  def map_nodes(%Yog.Graph{} = graph, fun) do
    new_nodes = Map.new(graph.nodes, fn {id, data} -> {id, fun.(data)} end)
    %{graph | nodes: new_nodes}
  end

  @doc """
  Transforms node data using a function in parallel, preserving graph structure.

  This is the async version of `map_nodes/2` that uses `Task.async_stream/3` to
  process node transformations concurrently. For large graphs with expensive
  transformation functions, this can provide significant speedups on multi-core systems.

  **Time Complexity:** O(V/cores) amortized, where V is the number of nodes

  **When to use:**
  - Large graphs (10,000+ nodes)
  - Expensive transformation functions (I/O, complex computations)
  - Multi-core systems where parallelism benefits outweigh overhead

  **When NOT to use:**
  - Small graphs (< 1,000 nodes) - overhead dominates
  - Trivial transformations - spawning tasks costs more than the work
  - Already in a parallel context - avoid nested parallelism

  ## Options

  - `:max_concurrency` - Maximum concurrent tasks (default: `System.schedulers_online()`)
  - `:timeout` - Task timeout in milliseconds (default: 5000)
  - `:ordered` - Preserve order (default: false, faster unordered)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "alice")
      ...>   |> Yog.add_node(2, "bob")
      iex> uppercased = Yog.Transform.map_nodes_async(graph, &String.upcase/1)
      iex> uppercased.nodes[1]
      "ALICE"

  ## Custom Options

      iex> graph = Yog.directed() |> Yog.add_node(1, "test")
      iex> opts = [max_concurrency: 4, timeout: 10_000]
      iex> result = Yog.Transform.map_nodes_async(graph, &String.upcase/1, opts)
      iex> result.nodes[1]
      "TEST"

  ## Performance Example

      # Sequential map_nodes on 1M nodes with moderate computation: ~6 seconds
      graph |> Yog.Transform.map_nodes(fn x -> expensive_function(x) end)

      # Parallel map_nodes_async on 8-core system: ~1 second
      graph |> Yog.Transform.map_nodes_async(fn x -> expensive_function(x) end)
  """
  @spec map_nodes_async(Yog.graph(), (term() -> term()), keyword()) :: Yog.graph()
  def map_nodes_async(%Yog.Graph{} = graph, fun, opts \\ []) do
    default_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: 5000,
      ordered: false
    ]

    stream_opts = Keyword.merge(default_opts, opts)

    new_nodes =
      graph.nodes
      |> Task.async_stream(
        fn {id, data} -> {id, fun.(data)} end,
        stream_opts
      )
      |> Enum.reduce(%{}, fn {:ok, {id, new_data}}, acc ->
        Map.put(acc, id, new_data)
      end)

    %{graph | nodes: new_nodes}
  end

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
  def map_edges(%Yog.Graph{} = graph, fun) do
    transform_inner = fn inner_map ->
      Map.new(inner_map, fn {dst, weight} -> {dst, fun.(weight)} end)
    end

    transform_outer = fn outer_map ->
      Map.new(outer_map, fn {src, inner_map} -> {src, transform_inner.(inner_map)} end)
    end

    %{
      graph
      | out_edges: transform_outer.(graph.out_edges),
        in_edges: transform_outer.(graph.in_edges)
    }
  end

  @doc """
  Transforms edge weights using a function in parallel, preserving graph structure.

  This is the async version of `map_edges/2` that uses `Task.async_stream/3` to
  process edge transformations concurrently. For large graphs with expensive
  transformation functions, this can provide significant speedups on multi-core systems.

  The parallelization strategy processes nodes (and their outgoing edges) in parallel,
  transforming all edges from each node concurrently.

  **Time Complexity:** O(E/cores) amortized, where E is the number of edges

  **When to use:**
  - Large graphs (100,000+ edges)
  - Expensive transformation functions (I/O, database lookups, complex calculations)
  - Multi-core systems where parallelism benefits outweigh overhead

  **When NOT to use:**
  - Small graphs (< 10,000 edges) - overhead dominates
  - Trivial transformations (arithmetic) - spawning tasks costs more
  - Already in a parallel context - avoid nested parallelism

  ## Options

  - `:max_concurrency` - Maximum concurrent tasks (default: `System.schedulers_online()`)
  - `:timeout` - Task timeout in milliseconds (default: 5000)
  - `:ordered` - Preserve order (default: false, faster unordered)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> doubled = Yog.Transform.map_edges_async(graph, fn w -> w * 2 end)
      iex> Yog.successors(doubled, 1)
      [{2, 20}]

  ## Custom Options

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 5)
      iex> opts = [max_concurrency: 8, timeout: 10_000]
      iex> result = Yog.Transform.map_edges_async(graph, fn w -> w * 3 end, opts)
      iex> Yog.successors(result, 1)
      [{2, 15}]

  ## Performance Example

      # Sequential map_edges on 1M edges with moderate computation: ~6 seconds
      graph |> Yog.Transform.map_edges(fn w -> expensive_transform(w) end)

      # Parallel map_edges_async on 8-core system: ~1 second
      graph |> Yog.Transform.map_edges_async(fn w -> expensive_transform(w) end)
  """
  @spec map_edges_async(Yog.graph(), (term() -> term()), keyword()) :: Yog.graph()
  def map_edges_async(%Yog.Graph{} = graph, fun, opts \\ []) do
    default_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: 5000,
      ordered: false
    ]

    stream_opts = Keyword.merge(default_opts, opts)

    transform_outer_async = fn outer_map ->
      outer_map
      |> Task.async_stream(
        fn {src, inner_map} ->
          new_inner = Map.new(inner_map, fn {dst, weight} -> {dst, fun.(weight)} end)
          {src, new_inner}
        end,
        stream_opts
      )
      |> Enum.reduce(%{}, fn {:ok, {src, new_inner}}, acc ->
        Map.put(acc, src, new_inner)
      end)
    end

    %{
      graph
      | out_edges: transform_outer_async.(graph.out_edges),
        in_edges: transform_outer_async.(graph.in_edges)
    }
  end

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
      iex> map_size(filtered.nodes)
      2

  ## Use Cases

  - Extract subgraphs based on node properties
  - Remove inactive/disabled nodes from a network
  - Filter by node importance/centrality
  """
  @spec filter_nodes(Yog.graph(), (term() -> boolean())) :: Yog.graph()
  def filter_nodes(%Yog.Graph{} = graph, predicate) do
    kept_nodes = Map.filter(graph.nodes, fn {_id, data} -> predicate.(data) end)

    prune_edges = fn outer_map ->
      outer_map
      |> Map.filter(fn {src, _} -> Map.has_key?(kept_nodes, src) end)
      |> Map.new(fn {src, inner_map} ->
        {src, Map.filter(inner_map, fn {dst, _} -> Map.has_key?(kept_nodes, dst) end)}
      end)
    end

    %{
      graph
      | nodes: kept_nodes,
        out_edges: prune_edges.(graph.out_edges),
        in_edges: prune_edges.(graph.in_edges)
    }
  end

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
  def filter_edges(%Yog.Graph{} = graph, predicate) do
    new_out =
      for {src, inner_map} <- graph.out_edges, reduce: %{} do
        acc ->
          filtered_inner =
            Map.filter(inner_map, fn {dst, weight} -> predicate.(src, dst, weight) end)

          if map_size(filtered_inner) > 0 do
            Map.put(acc, src, filtered_inner)
          else
            acc
          end
      end

    new_in =
      for {dst, inner_map} <- graph.in_edges, reduce: %{} do
        acc ->
          filtered_inner =
            Map.filter(inner_map, fn {src, weight} -> predicate.(src, dst, weight) end)

          if map_size(filtered_inner) > 0 do
            Map.put(acc, dst, filtered_inner)
          else
            acc
          end
      end

    %{graph | out_edges: new_out, in_edges: new_in}
  end

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
  def complement(%Yog.Graph{kind: kind} = graph, default_weight) do
    node_ids = Map.keys(graph.nodes)

    out_edges =
      for src <- node_ids, reduce: %{} do
        acc_outer ->
          inner =
            for dst <- node_ids, src != dst, reduce: %{} do
              acc_inner ->
                has_edge =
                  case Map.fetch(graph.out_edges, src) do
                    {:ok, old_inner} -> Map.has_key?(old_inner, dst)
                    :error -> false
                  end

                if has_edge do
                  acc_inner
                else
                  Map.put(acc_inner, dst, default_weight)
                end
            end

          if map_size(inner) > 0 do
            Map.put(acc_outer, src, inner)
          else
            acc_outer
          end
      end

    in_edges =
      if kind == :directed do
        for {src, inners} <- out_edges, {dst, weight} <- inners, reduce: %{} do
          acc_in ->
            inner = Map.get(acc_in, dst, %{}) |> Map.put(src, weight)
            Map.put(acc_in, dst, inner)
        end
      else
        out_edges
      end

    %{graph | out_edges: out_edges, in_edges: in_edges}
  end

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
  def merge(%Yog.Graph{} = graph1, %Yog.Graph{} = graph2) do
    merge_inner = fn m1, m2 -> Map.merge(m1, m2) end

    merge_outer = fn outer1, outer2 ->
      Map.merge(outer1, outer2, fn _src, inner1, inner2 ->
        merge_inner.(inner1, inner2)
      end)
    end

    %{
      graph1
      | nodes: Map.merge(graph1.nodes, graph2.nodes),
        out_edges: merge_outer.(graph1.out_edges, graph2.out_edges),
        in_edges: merge_outer.(graph1.in_edges, graph2.in_edges)
    }
  end

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
  def subgraph(%Yog.Graph{} = graph, ids) do
    id_set = MapSet.new(ids)

    filtered_nodes = Map.filter(graph.nodes, fn {id, _} -> MapSet.member?(id_set, id) end)

    prune = fn outer ->
      outer
      |> Map.filter(fn {src, _} -> MapSet.member?(id_set, src) end)
      |> Map.new(fn {src, inner} ->
        {src, Map.filter(inner, fn {dst, _} -> MapSet.member?(id_set, dst) end)}
      end)
    end

    %{
      graph
      | nodes: filtered_nodes,
        out_edges: prune.(graph.out_edges),
        in_edges: prune.(graph.in_edges)
    }
  end

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
  def contract(%Yog.Graph{} = graph, a, b, combine_weight) do
    b_out = Map.get(graph.out_edges, b, %{})

    graph_with_out_edges =
      Enum.reduce(b_out, graph, fn {neighbor, weight}, acc_g ->
        if neighbor == a || neighbor == b do
          acc_g
        else
          {:ok, g} = Model.add_edge_with_combine(acc_g, a, neighbor, weight, combine_weight)
          g
        end
      end)

    final_graph =
      case graph.kind do
        :undirected ->
          graph_with_out_edges

        :directed ->
          b_in = Map.get(graph_with_out_edges.in_edges, b, %{})

          Enum.reduce(b_in, graph_with_out_edges, fn {neighbor, weight}, acc_g ->
            if neighbor == a || neighbor == b do
              acc_g
            else
              {:ok, g} = Model.add_edge_with_combine(acc_g, neighbor, a, weight, combine_weight)
              g
            end
          end)
      end

    Model.remove_node(final_graph, b)
  end

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
      iex> directed.kind
      :directed
  """
  @spec to_directed(Yog.graph()) :: Yog.graph()
  def to_directed(%Yog.Graph{} = graph) do
    %{graph | kind: :directed}
  end

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
  def to_undirected(%Yog.Graph{kind: :undirected} = graph, _resolve) do
    graph
  end

  def to_undirected(%Yog.Graph{kind: :directed} = graph, resolve) do
    symmetric_out =
      Enum.reduce(graph.out_edges, graph.out_edges, fn {src, inner}, acc_outer ->
        Enum.reduce(inner, acc_outer, fn {dst, weight}, acc ->
          dst_inner = Map.get(acc, dst, %{})

          updated_inner =
            case Map.fetch(dst_inner, src) do
              {:ok, existing} -> Map.put(dst_inner, src, resolve.(existing, weight))
              :error -> Map.put(dst_inner, src, weight)
            end

          Map.put(acc, dst, updated_inner)
        end)
      end)

    %{graph | kind: :undirected, out_edges: symmetric_out, in_edges: symmetric_out}
  end
end
