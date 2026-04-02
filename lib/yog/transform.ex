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

  Async variants added in v0.60.1.
  """

  use Yog.Algorithm
  alias Yog.Transformable

  defp mutate!(result), do: Yog.Utils.unwrap_mutate!(result)

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
  def transpose(graph) do
    Transformable.transpose(graph)
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
  def map_nodes(graph, fun) do
    Transformable.map_nodes(graph, fun)
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
  def map_edges(graph, fun) do
    Transformable.map_edges(graph, fun)
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

    # Flatten edges and chunk them to avoid data skew on high-degree nodes
    # Process chunks in parallel for better load balancing
    all_out_edges =
      for {src, inner} <- graph.out_edges,
          {dst, weight} <- inner,
          do: {:out, src, dst, weight}

    all_in_edges =
      for {dst, inner} <- graph.in_edges,
          {src, weight} <- inner,
          do: {:in, dst, src, weight}

    all_edges = all_out_edges ++ all_in_edges

    # Process edges in parallel and collect results
    processed_edges =
      all_edges
      |> Task.async_stream(
        fn
          {:out, src, dst, weight} -> {:out, src, dst, fun.(weight)}
          {:in, dst, src, weight} -> {:in, dst, src, fun.(weight)}
        end,
        stream_opts
      )
      |> Enum.reduce({%{}, %{}}, fn {:ok, edge}, {out_acc, in_acc} ->
        case edge do
          {:out, src, dst, new_weight} ->
            new_inner = Map.get(out_acc, src, %{}) |> Map.put(dst, new_weight)
            {Map.put(out_acc, src, new_inner), in_acc}

          {:in, dst, src, new_weight} ->
            new_inner = Map.get(in_acc, dst, %{}) |> Map.put(src, new_weight)
            {out_acc, Map.put(in_acc, dst, new_inner)}
        end
      end)

    {new_out_edges, new_in_edges} = processed_edges

    %{
      graph
      | out_edges: new_out_edges,
        in_edges: new_in_edges
    }
  end

  @doc """
  Transforms edge weights using a function that also takes the source and destination IDs.

  ## Example

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> result = Yog.Transform.map_edges_indexed(graph, fn u, v, w -> u + v + w end)
      iex> Yog.successors(result, 1)
      [{2, 13}] # 1 + 2 + 10
  """
  @spec map_edges_indexed(Yog.graph(), (Yog.node_id(), Yog.node_id(), term() -> term())) ::
          Yog.graph()
  def map_edges_indexed(%Yog.Graph{} = graph, fun) do
    new_out =
      Map.new(graph.out_edges, fn {src, inner} ->
        {src, Map.new(inner, fn {dst, weight} -> {dst, fun.(src, dst, weight)} end)}
      end)

    new_in =
      Map.new(graph.in_edges, fn {dst, inner} ->
        {dst, Map.new(inner, fn {src, weight} -> {src, fun.(src, dst, weight)} end)}
      end)

    %{graph | out_edges: new_out, in_edges: new_in}
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
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
  def filter_nodes(graph, predicate) do
    # 1. Filter and collect kept node IDs
    kept_nodes =
      Model.all_nodes(graph)
      |> Enum.filter(fn id -> predicate.(Model.node(graph, id)) end)
      |> MapSet.new()

    # 2. Create new graph and add nodes
    init = Transformable.empty(graph)

    graph_with_nodes =
      Enum.reduce(kept_nodes, init, fn id, acc ->
        Mutator.add_node(acc, id, Model.node(graph, id))
      end)

    # 3. Filter and add edges where both endpoints are kept
    edges =
      Model.all_edges(graph)
      |> Enum.filter(fn {u, v, _w} ->
        MapSet.member?(kept_nodes, u) and MapSet.member?(kept_nodes, v)
      end)

    Mutator.add_edges(graph_with_nodes, edges) |> mutate!()
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
  def filter_edges(graph, predicate) do
    # 1. Start with empty graph
    init = Transformable.empty(graph)

    # 2. Add all nodes first (preserving all nodes as per documentation)
    graph_with_nodes =
      Enum.reduce(Model.all_nodes(graph), init, fn id, acc ->
        Mutator.add_node(acc, id, Model.node(graph, id))
      end)

    # 3. Filter and add edges
    edges =
      Model.all_edges(graph)
      |> Enum.filter(fn {u, v, w} -> predicate.(u, v, w) end)

    Mutator.add_edges(graph_with_nodes, edges) |> mutate!()
  end

  @doc """
  Updates a specific node's data using an updater function.

  Similar to `Map.update/4`, it takes an initial value if the node doesn't exist,
  but since this is a graph transformation, it is typically used on existing nodes.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_node(1, 100)
      iex> updated = Yog.Transform.update_node(graph, 1, 0, fn x -> x + 50 end)
      iex> Yog.Model.node(updated, 1)
      150

      iex> graph = Yog.directed()
      iex> updated = Yog.Transform.update_node(graph, 1, 5, fn x -> x + 5 end)
      iex> Yog.Model.node(updated, 1)
      5
  """
  @spec update_node(Yog.graph(), Yog.node_id(), term(), (term() -> term())) :: Yog.graph()
  def update_node(graph, id, default, fun) do
    data = Model.node(graph, id)
    new_data = if data, do: fun.(data), else: default
    Mutator.add_node(graph, id, new_data)
  end

  @doc """
  Updates a specific edge's weight/metadata.

  This is the "safe" way to perform the update, ensuring that
  both `in_edges` and `out_edges` stay in sync. It also handles undirected graphs
  properly.

  If either node `u` or `v` does not exist in the graph, the original graph
  is returned unchanged.

  ## Example

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> updated = Yog.Transform.update_edge(graph, 1, 2, 0, fn w -> w + 5 end)
      iex> Yog.successors(updated, 1)
      [{2, 15}]

      iex> {:ok, graph} = Yog.undirected()
      ...>   |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> updated = Yog.Transform.update_edge(graph, 1, 2, 0, fn w -> w * 2 end)
      iex> Yog.successors(updated, 1)
      [{2, 20}]
      iex> Yog.successors(updated, 2)
      [{1, 20}]
  """
  @spec update_edge(Yog.graph(), Yog.node_id(), Yog.node_id(), term(), (term() -> term())) ::
          Yog.graph()
  def update_edge(graph, u, v, default, fun) do
    if Model.has_node?(graph, u) and Model.has_node?(graph, v) do
      weight = Model.edge_data(graph, u, v)
      new_weight = if weight, do: fun.(weight), else: default
      Mutator.add_edge(graph, u, v, new_weight) |> mutate!()
    else
      graph
    end
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
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
  def complement(graph, default_weight) do
    nodes = Model.all_nodes(graph)
    init = Transformable.empty(graph)

    # 1. Add all nodes
    graph_with_nodes =
      Enum.reduce(nodes, init, fn id, acc ->
        Mutator.add_node(acc, id, Model.node(graph, id))
      end)

    # 2. Add edges where they DON'T exist
    # Optimization: pre-calculate type to avoid redundant protocol calls
    type = Model.type(graph)

    Enum.reduce(nodes, graph_with_nodes, fn u, acc_outer ->
      Enum.reduce(nodes, acc_outer, fn v, acc_inner ->
        cond do
          u == v ->
            acc_inner

          type == :undirected and u > v ->
            # Only process each pair once for undirected
            acc_inner

          not Model.has_edge?(graph, u, v) ->
            Mutator.add_edge(acc_inner, u, v, default_weight) |> mutate!()

          true ->
            acc_inner
        end
      end)
    end)
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      iex> other =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "Updated")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 20)
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
  def merge(graph1, graph2) do
    # 1. Start with empty graph of base type
    init = Transformable.empty(graph1)

    # 2. Add all from graph 1
    g1_nodes = Model.nodes(graph1)

    graph_with_g1 =
      Enum.reduce(g1_nodes, init, fn {id, data}, acc ->
        Mutator.add_node(acc, id, data)
      end)
      |> Mutator.add_edges(Model.all_edges(graph1))
      |> mutate!()

    # 3. Add all from graph 2 (overwrites conflicts)
    g2_nodes = Model.nodes(graph2)

    Enum.reduce(g2_nodes, graph_with_g1, fn {id, data}, acc ->
      Mutator.add_node(acc, id, data)
    end)
    |> Mutator.add_edges(Model.all_edges(graph2))
    |> mutate!()
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
  def subgraph(graph, ids) do
    id_set = MapSet.new(ids)
    init = Transformable.empty(graph)

    # 1. Add valid nodes
    graph_with_nodes =
      Enum.reduce(ids, init, fn id, acc ->
        if Model.has_node?(graph, id) do
          Mutator.add_node(acc, id, Model.node(graph, id))
        else
          acc
        end
      end)

    # 2. Add qualifying edges
    edges =
      Model.all_edges(graph)
      |> Enum.filter(fn {u, v, _w} ->
        MapSet.member?(id_set, u) and MapSet.member?(id_set, v)
      end)

    Mutator.add_edges(graph_with_nodes, edges) |> mutate!()
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 20)
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 5)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)
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
  def contract(graph, a, b, combine_weight) do
    if Model.has_node?(graph, a) and Model.has_node?(graph, b) do
      # Redirect and merge edges generically
      init = Transformable.empty(graph)

      # 1. Add all nodes except 'b'
      # Node 'a' gets merged data
      graph_with_nodes =
        Enum.reduce(Model.all_nodes(graph), init, fn id, acc ->
          cond do
            id == b ->
              acc

            id == a ->
              Mutator.add_node(acc, a, Model.node(graph, a))

            true ->
              Mutator.add_node(acc, id, Model.node(graph, id))
          end
        end)

      # 2. Add and redirect all edges
      # If endpoint is 'b', change to 'a'. Remove self-loops.
      edges =
        Model.all_edges(graph)
        |> Enum.map(fn {u, v, w} ->
          new_u = if u == b, do: a, else: u
          new_v = if v == b, do: a, else: v
          {new_u, new_v, w}
        end)
        |> Enum.reject(fn {u, v, _w} -> u == v end)

      # 3. Use combine version if supported or handle duplicates
      # Since we want to merge weights for same neighbor, we use add_edge_with_combine
      Enum.reduce(edges, graph_with_nodes, fn {u, v, w}, acc ->
        Mutator.add_edge_with_combine(acc, u, v, w, combine_weight) |> mutate!()
      end)
    else
      graph
    end
  end

  @doc """
  Computes the transitive closure of the graph.

  The transitive closure adds an edge from node A to node C whenever there is
  a path from A to C. For a DAG, this uses a topological sorting optimization.
  For graphs with cycles, it uses a general path-reaching approach.

  **Time Complexity:** O(V × (V + E))

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      iex> closure = Yog.Transform.transitive_closure(graph)
      iex> Yog.Model.has_edge?(closure, 1, 3)
      true
  """
  @spec transitive_closure(Yog.graph()) :: Yog.graph()
  def transitive_closure(graph) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        # Fast DAG-based closure
        reachable_map = solve_transitive_reachability(graph, Enum.reverse(sorted))

        Enum.reduce(reachable_map, graph, fn {node, targets}, g_acc ->
          Enum.reduce(targets, g_acc, fn target, g ->
            if Model.has_edge?(g, node, target) do
              g
            else
              Mutator.add_edge_ensure(g, node, target, 1, nil)
            end
          end)
        end)

      {:error, :contains_cycle} ->
        # General closure using BFS/DFS from each node
        Enum.reduce(Model.all_nodes(graph), graph, fn src, g_acc ->
          reachable = Yog.Traversal.walk(in: graph, from: src, using: :breadth_first) |> tl()

          Enum.reduce(reachable, g_acc, fn dst, g ->
            if Model.has_edge?(g, src, dst) do
              g
            else
              Mutator.add_edge_ensure(g, src, dst, 1, nil)
            end
          end)
        end)
    end
  end

  defp solve_transitive_reachability(graph, sorted_nodes) do
    Enum.reduce(sorted_nodes, %{}, fn node, acc ->
      successors = Model.successor_ids(graph, node)

      all_reachable =
        Enum.reduce(successors, MapSet.new(successors), fn child, set_acc ->
          child_reachable = Map.get(acc, child, MapSet.new())
          MapSet.union(set_acc, child_reachable)
        end)

      Map.put(acc, node, all_reachable)
    end)
  end

  @doc """
  Computes the transitive reduction of a DAG.

  Transitive reduction removes redundant edges that are implied by transitivity.
  For Directed Acyclic Graphs (DAGs), the result is unique and minimal.

  If the graph contains cycles, this returns an error as transitive reduction
  is not uniquely defined for general graphs with cycles.

  **Time Complexity:** O(V × (V + E))

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_edge_ensure(:a, :b, 1, nil)
      ...> |> Yog.add_edge_ensure(:b, :c, 1, nil)
      ...> |> Yog.add_edge_ensure(:a, :c, 1, nil)
      iex> reduction = Yog.Transform.transitive_reduction(graph)
      iex> {:ok, red} = reduction
      iex> # Edge a->c is redundant because a->b->c exists
      iex> Yog.Model.has_edge?(red, :a, :c)
      false
  """
  @spec transitive_reduction(Yog.graph()) :: {:ok, Yog.graph()} | {:error, :contains_cycle}
  def transitive_reduction(graph) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, _sorted} ->
        nodes = Model.all_nodes(graph)

        edges_to_remove =
          for node <- nodes,
              {target, _weight} <- Model.successors(graph, node),
              has_indirect_path?(graph, node, target),
              do: {node, target}

        new_graph =
          Enum.reduce(edges_to_remove, graph, fn {from, to}, g ->
            Mutator.remove_edge(g, from, to)
          end)

        {:ok, new_graph}

      {:error, :contains_cycle} ->
        {:error, :contains_cycle}
    end
  end

  defp has_indirect_path?(graph, from, to) do
    # To check for an indirect path from 'from' to 'to', we look for any
    # path that doesn't use the direct edge (from -> to).
    # We do this by checking if any successor of 'from' (other than 'to') can reach 'to'.
    Model.successor_ids(graph, from)
    |> Enum.reject(&(&1 == to))
    |> Enum.any?(fn successor ->
      Yog.Traversal.reachable?(graph, successor, to)
    end)
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      iex> directed = Yog.Transform.to_directed(undirected)
      iex> # Has edges: 1->2 and 2->1 (both with weight 10)
      iex> directed.kind
      :directed
  """
  @spec to_directed(Yog.graph()) :: Yog.graph()
  def to_directed(graph) do
    if Model.type(graph) == :directed do
      graph
    else
      # Rebuild as directed using the implementation's empty directed graph
      init = Transformable.empty(graph, :directed)

      graph_with_nodes =
        Enum.reduce(Model.nodes(graph), init, fn {id, data}, acc ->
          Mutator.add_node(acc, id, data)
        end)

      Enum.reduce(Model.all_edges(graph), graph_with_nodes, fn {u, v, w}, acc ->
        # For undirected input, we must add both directions to preserve connectivity in directed form
        acc
        |> Mutator.add_edge_ensure(u, v, w, nil)
        |> Mutator.add_edge_ensure(v, u, w, nil)
      end)
    end
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> undirected = Yog.Transform.to_undirected(directed, &min/2)
      iex> # Edge exists in both directions with weight 5
      iex> Enum.sort(Yog.successors(undirected, 1))
      [{2, 5}]
  """
  @spec to_undirected(Yog.graph(), (term(), term() -> term())) :: Yog.graph()
  def to_undirected(graph, resolve) do
    if Model.type(graph) == :undirected do
      graph
    else
      # Rebuild as undirected
      init = Transformable.empty(graph, :undirected)

      # 1. Add all nodes
      graph_with_nodes =
        Enum.reduce(Model.nodes(graph), init, fn {id, data}, acc ->
          Mutator.add_node(acc, id, data)
        end)

      # 2. Add edges with resolving logic
      Enum.reduce(Model.all_edges(graph), graph_with_nodes, fn {u, v, w}, acc ->
        Mutator.add_edge_with_combine(acc, u, v, w, resolve) |> mutate!()
      end)
    end
  end
end
