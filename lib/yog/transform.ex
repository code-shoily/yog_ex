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

  alias Yog.Graph
  alias Yog.Model

  # =============================================================================
  # STRUCTURE TRANSFORMATIONS
  # =============================================================================

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
  @spec transpose(Graph.t()) :: Graph.t()
  def transpose(%Graph{} = graph) do
    %{graph | out_edges: graph.in_edges, in_edges: graph.out_edges}
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
  @spec to_directed(Graph.t()) :: Graph.t()
  def to_directed(%Graph{} = graph) do
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> undirected = Yog.Transform.to_undirected(directed, &min/2)
      iex> # Edge exists in both directions with weight 5
      iex> Enum.sort(Yog.successors(undirected, 1))
      [{2, 5}]
  """
  @spec to_undirected(Graph.t(), (term(), term() -> term())) :: Graph.t()
  def to_undirected(%Graph{kind: :undirected} = graph, _resolve) do
    graph
  end

  def to_undirected(%Graph{kind: :directed} = graph, resolve) do
    out_edges = graph.out_edges

    symmetric_out =
      :maps.fold(
        fn src, inner, acc_outer ->
          :maps.fold(
            fn dst, weight, acc ->
              dst_inner = Map.get(acc, dst, %{})

              updated_inner =
                case Map.fetch(dst_inner, src) do
                  {:ok, existing} -> Map.put(dst_inner, src, resolve.(existing, weight))
                  :error -> Map.put(dst_inner, src, weight)
                end

              Map.put(acc, dst, updated_inner)
            end,
            acc_outer,
            inner
          )
        end,
        out_edges,
        out_edges
      )

    %{graph | kind: :undirected, out_edges: symmetric_out, in_edges: symmetric_out}
  end

  # =============================================================================
  # NODE TRANSFORMATIONS
  # =============================================================================

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
  @spec map_nodes(Graph.t(), (term() -> term())) :: Graph.t()
  def map_nodes(%Graph{} = graph, fun) do
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
  @spec map_nodes_async(Graph.t(), (term() -> term()), keyword()) :: Graph.t()
  def map_nodes_async(%Graph{} = graph, fun, opts \\ []) do
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
  @spec update_node(Graph.t(), Yog.node_id(), term(), (term() -> term())) :: Graph.t()
  def update_node(%Graph{} = graph, id, default, fun) do
    %{graph | nodes: Map.update(graph.nodes, id, default, fun)}
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
  @spec filter_nodes(Graph.t(), (term() -> boolean())) :: Graph.t()
  def filter_nodes(%Graph{} = graph, predicate) do
    kept_nodes = Map.filter(graph.nodes, fn {_id, data} -> predicate.(data) end)

    %{
      graph
      | nodes: kept_nodes,
        out_edges: prune_edges(graph.out_edges, kept_nodes),
        in_edges: prune_edges(graph.in_edges, kept_nodes)
    }
  end

  # =============================================================================
  # EDGE TRANSFORMATIONS
  # =============================================================================

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
  @spec map_edges(Graph.t(), (term() -> term())) :: Graph.t()
  def map_edges(%Graph{} = graph, fun) do
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
  @spec map_edges_async(Graph.t(), (term() -> term()), keyword()) :: Graph.t()
  def map_edges_async(%Graph{} = graph, fun, opts \\ []) do
    default_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: 5000,
      ordered: false
    ]

    stream_opts = Keyword.merge(default_opts, opts)

    # Optimization: Use lazy streams to avoid building a massive list of all edges in memory
    all_out_edges =
      Stream.flat_map(graph.out_edges, fn {src, inner} ->
        Stream.map(inner, fn {dst, weight} -> {:out, src, dst, weight} end)
      end)

    all_in_edges =
      Stream.flat_map(graph.in_edges, fn {dst, inner} ->
        Stream.map(inner, fn {src, weight} -> {:in, dst, src, weight} end)
      end)

    all_edges = Stream.concat(all_out_edges, all_in_edges)

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
  @spec map_edges_indexed(Graph.t(), (Yog.node_id(), Yog.node_id(), term() -> term())) ::
          Graph.t()
  def map_edges_indexed(%Graph{} = graph, fun) do
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
  @spec update_edge(Graph.t(), Yog.node_id(), Yog.node_id(), term(), (term() -> term())) ::
          Graph.t()
  def update_edge(%Graph{} = graph, u, v, default, fun) do
    if Map.has_key?(graph.nodes, u) and Map.has_key?(graph.nodes, v) do
      update_directed = fn g, src, dst ->
        update_map = fn map, start, finish ->
          inner = Map.get(map, start, %{})
          new_inner = Map.update(inner, finish, default, fun)
          Map.put(map, start, new_inner)
        end

        %{
          g
          | out_edges: update_map.(g.out_edges, src, dst),
            in_edges: update_map.(g.in_edges, dst, src)
        }
      end

      case graph.kind do
        :directed ->
          update_directed.(graph, u, v)

        :undirected ->
          if u == v do
            update_directed.(graph, u, v)
          else
            graph
            |> update_directed.(u, v)
            |> update_directed.(v, u)
          end
      end
    else
      graph
    end
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
  @spec filter_edges(Graph.t(), (Yog.node_id(), Yog.node_id(), term() -> boolean())) ::
          Graph.t()
  def filter_edges(%Graph{} = graph, predicate) do
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

  # =============================================================================
  # GRAPH COMBINATIONS
  # =============================================================================

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
  @spec merge(Graph.t(), Graph.t()) :: Graph.t()
  def merge(%Graph{} = graph1, %Graph{} = graph2) do
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
  @spec complement(Graph.t(), term()) :: Graph.t()
  def complement(%Graph{kind: kind} = graph, default_weight) do
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
  @spec subgraph(Graph.t(), [Yog.node_id()]) :: Graph.t()
  def subgraph(%Graph{} = graph, ids) do
    id_set = MapSet.new(ids)

    filtered_nodes = Map.filter(graph.nodes, fn {id, _} -> MapSet.member?(id_set, id) end)

    %{
      graph
      | nodes: filtered_nodes,
        out_edges: prune_edges(graph.out_edges, id_set),
        in_edges: prune_edges(graph.in_edges, id_set)
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
          Graph.t(),
          Yog.node_id(),
          Yog.node_id(),
          (term(), term() -> term())
        ) :: Graph.t()
  def contract(%Graph{out_edges: out_edges, in_edges: in_edges} = graph, a, b, combine_weight) do
    b_in = Map.get(in_edges, b, %{})
    b_out = Map.get(out_edges, b, %{})

    a_out = merge_adjacent(Map.get(out_edges, a, %{}), b_out, combine_weight, a, b)

    out_edges =
      graph.out_edges
      |> redirect_neighbors(b_in, a, b, combine_weight)
      |> Map.put(a, a_out)
      |> Map.delete(b)

    if graph.kind == :undirected do
      %{graph | nodes: Map.delete(graph.nodes, b), out_edges: out_edges, in_edges: out_edges}
    else
      a_in = merge_adjacent(Map.get(in_edges, a, %{}), b_in, combine_weight, a, b)
      in_edges = redirect_neighbors(in_edges, b_out, a, b, combine_weight)
      in_edges = in_edges |> Map.put(a, a_in) |> Map.delete(b)

      %{graph | nodes: Map.delete(graph.nodes, b), out_edges: out_edges, in_edges: in_edges}
    end
  end

  # =============================================================================
  # REACHABILITY TRANSFORMATIONS
  # =============================================================================

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
  @spec transitive_closure(Graph.t()) :: Graph.t()
  def transitive_closure(%Graph{} = graph) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        reachability_map = solve_transitive_reachability(graph, Enum.reverse(sorted))

        List.foldl(Map.to_list(reachability_map), graph, fn {node, targets}, g ->
          add_closure_edges(g, node, targets)
        end)

      {:error, :contains_cycle} ->
        nodes = Map.keys(graph.nodes)

        List.foldl(nodes, graph, fn src, g_acc ->
          reachable = Yog.Traversal.walk(in: graph, from: src, using: :breadth_first) |> tl()

          List.foldl(reachable, g_acc, fn dst, g ->
            if Model.has_edge?(g, src, dst) do
              g
            else
              Model.add_edge!(g, src, dst, 1)
            end
          end)
        end)
    end
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
  @spec transitive_reduction(Graph.t()) :: {:ok, Graph.t()} | {:error, :contains_cycle}
  def transitive_reduction(%Graph{} = graph) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, _sorted} ->
        nodes = Map.keys(graph.nodes)
        out_edges = graph.out_edges

        edges_to_remove =
          List.foldl(nodes, [], fn node, acc ->
            case Map.fetch(out_edges, node) do
              {:ok, inner} ->
                List.foldl(Map.to_list(inner), acc, fn {target, _weight}, inner_acc ->
                  if has_indirect_path?(graph, node, target) do
                    [{node, target} | inner_acc]
                  else
                    inner_acc
                  end
                end)

              :error ->
                acc
            end
          end)

        new_graph =
          List.foldl(edges_to_remove, graph, fn {from, to}, g ->
            Model.remove_edge(g, from, to)
          end)

        {:ok, new_graph}

      {:error, :contains_cycle} ->
        {:error, :contains_cycle}
    end
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  # Prunes an edges map (out_edges or in_edges) so that only nodes present in
  # `allowed` (a map or MapSet) are kept, both in the outer and inner maps.
  defp prune_edges(outer_map, allowed) do
    outer_map
    |> Map.filter(fn {src, _} -> contains?(allowed, src) end)
    |> Map.new(fn {src, inner_map} ->
      {src, Map.filter(inner_map, fn {dst, _} -> contains?(allowed, dst) end)}
    end)
  end

  defp contains?(%MapSet{} = set, key), do: MapSet.member?(set, key)
  defp contains?(map, key) when is_map(map), do: Map.has_key?(map, key)

  # Merges b's edges into a's adjacency map and removes self-loops
  defp merge_adjacent(a_edges, b_edges, combine_weight, a, b) do
    Map.merge(a_edges, b_edges, fn _k, v1, v2 -> combine_weight.(v1, v2) end)
    |> Map.delete(a)
    |> Map.delete(b)
  end

  # Redirects edges pointing to b so they point to a instead
  defp redirect_neighbors(adj_map, edges_to_redirect, a, b, combine_weight) do
    List.foldl(Map.to_list(edges_to_redirect), adj_map, fn {nb, w}, acc ->
      if nb == a or nb == b do
        acc
      else
        Map.update(acc, nb, %{a => w}, fn nb_edges ->
          nb_edges
          |> Map.delete(b)
          |> Map.update(a, w, &combine_weight.(&1, w))
        end)
      end
    end)
  end

  defp solve_transitive_reachability(graph, sorted_nodes) do
    out_edges = graph.out_edges

    List.foldl(sorted_nodes, %{}, fn node, acc ->
      successors =
        case Map.fetch(out_edges, node) do
          {:ok, inner} -> Map.keys(inner)
          :error -> []
        end

      all_reachable =
        List.foldl(successors, MapSet.new(successors), fn child, set_acc ->
          child_reachable = Map.get(acc, child, MapSet.new())
          MapSet.union(set_acc, child_reachable)
        end)

      Map.put(acc, node, all_reachable)
    end)
  end

  defp add_closure_edges(graph, node, targets) do
    existing =
      case Map.fetch(graph.out_edges, node) do
        {:ok, edges} -> Map.keys(edges) |> MapSet.new()
        :error -> MapSet.new()
      end

    List.foldl(MapSet.to_list(targets), graph, fn target, g_acc ->
      if MapSet.member?(existing, target) do
        g_acc
      else
        Model.add_edge!(g_acc, node, target, 1)
      end
    end)
  end

  defp has_indirect_path?(graph, from, to) do
    successors =
      case Map.fetch(graph.out_edges, from) do
        {:ok, edges} -> Map.keys(edges)
        :error -> []
      end

    has_indirect? =
      List.foldl(successors, false, fn successor, found? ->
        if found? or successor == to do
          found?
        else
          Yog.Traversal.reachable?(graph, successor, to) or found?
        end
      end)

    has_indirect?
  end
end
