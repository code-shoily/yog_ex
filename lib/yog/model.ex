defmodule Yog.Model do
  @moduledoc """
  Graph operations and the `Yog.Model` protocol.

  This module provides:
  1. The `Yog.Model` protocol for graph implementations (see `Yog.Model.Protocol`)
  2. Mutation functions that operate on `Yog.Graph` structs
  3. Convenience delegations to the protocol for querying any graph type

  ## The Protocol

  The `Yog.Model` protocol defines the interface that all graph implementations
  must satisfy. This enables algorithms to work with:

  - `Yog.Graph` - Standard adjacency list (built-in)
  - `Yog.Multi.Graph` - Multigraph with edge IDs (built-in)
  - `Yog.DAG` - Directed acyclic graph wrapper (built-in)
  - Custom implementations - See `Yog.Model.Protocol` for details

  ## Query vs Mutation

  **Query functions** (read-only) work with ANY graph implementation via the protocol:
  - `successors/2`, `predecessors/2`, `all_nodes/1`
  - `out_degree/2`, `in_degree/2`, `degree/2`
  - `type/1`, `node_count/1`, `edge_count/1`

  **Mutation functions** create and modify `Yog.Graph` structs:
  - `new/1`, `add_node/3`, `add_edge/3`
  - `remove_node/2`, `remove_edge/3`

  ## Quick Start

      iex> graph =
      ...>   Yog.Model.new(:undirected)
      ...>   |> Yog.Model.add_node(1, "Alice")
      ...>   |> Yog.Model.add_node(2, "Bob")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> {:ok, g} = graph
      iex> Yog.Model.successors(g, 1)
      [{2, 10}]

  ## Custom Graph Implementations

  Implement the `Yog.Model` protocol for your own graph struct:

      defmodule MyGraph do
        defstruct [:data]
      end

      defimpl Yog.Model, for: MyGraph do
        def type(_), do: :directed
        def all_nodes(g), do: ...
        def successors(g, node), do: ...
        # ... implement all protocol functions
      end

  Then use with any Yog algorithm:

      graph = %MyGraph{...}
      Yog.Pathfinding.shortest_path(in: graph, from: :a, to: :b)
      Yog.Community.louvain(graph)
  """

  alias Yog.Graph

  @typedoc """
  Unique identifier for a node in the graph.
  """
  @type node_id :: term()

  @typedoc """
  The type of graph: `:directed` or `:undirected`.
  """
  @type graph_type :: :directed | :undirected

  @typedoc """
  A graph data structure.

  This is any term that implements the `Yog.Model` protocol,
  typically `Yog.Graph.t()` or `Yog.Multi.Graph.t()`.
  """
  @type graph :: Yog.Model.Protocol.t()

  # =============================================================================
  # CREATE/UPDATE GRAPH
  # =============================================================================

  @doc """
  Creates a new empty graph of the specified type.

  ## Example

      iex> graph = Yog.Model.new(:directed)
      iex> Yog.Model.order(graph)
      0
  """
  @spec new(graph_type()) :: graph()
  def new(graph_type) do
    Graph.new(graph_type)
  end

  @doc """
  Adds a node to the graph with the given ID and data.
  If a node with this ID already exists, its data will be replaced.

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "Node A")
      ...>   |> Yog.Model.add_node(2, "Node B")
      iex> Yog.Model.order(graph)
      2
  """
  @spec add_node(graph(), node_id(), term()) :: graph()
  def add_node(%Graph{} = graph, id, data) do
    %{graph | nodes: Map.put(graph.nodes, id, data)}
  end

  @doc """
  Adds an edge to the graph with the given weight.

  For directed graphs, adds a single edge from `src` to `dst`.
  For undirected graphs, adds edges in both directions.

  Returns `{:error, reason}` if either endpoint node doesn't exist in `graph.nodes`.
  Use `add_edge_ensure/5` to auto-create missing nodes with a default value,
  or `add_node/3` to explicitly add nodes before adding edges.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.successors(graph, 1)
      [{2, 10}]

      iex> # Error when nodes don't exist
      iex> Yog.Model.new(:directed) |> Yog.Model.add_edge(1, 2, 10)
      {:error, "Nodes 1 and 2 do not exist"}
  """
  @spec add_edge(graph(), node_id(), node_id(), term()) :: {:ok, graph()} | {:error, String.t()}
  def add_edge(%Graph{nodes: nodes} = graph, src, dst, weight) do
    has_src = Map.has_key?(nodes, src)
    has_dst = Map.has_key?(nodes, dst)

    cond do
      has_src and has_dst ->
        {:ok, add_edge_unchecked(graph, src, dst, weight)}

      not has_src and not has_dst ->
        {:error, "Nodes #{src} and #{dst} do not exist"}

      not has_src ->
        {:error, "Node #{src} does not exist"}

      true ->
        {:error, "Node #{dst} does not exist"}
    end
  end

  @doc """
  Same as `add_edge/4` but raises on error.

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge!(1, 2, 10)
      iex> Yog.Model.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge!(graph(), node_id(), node_id(), term()) :: graph()
  def add_edge!(graph, from, to, weight) do
    case add_edge(graph, from, to, weight) do
      {:ok, g} -> g
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Adds an edge to the graph.

  For directed graphs, adds a single edge from `from` to `to`.
  For undirected graphs, adds edges in both directions.

  Returns `{:ok, graph}` or `{:error, reason}`.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(from: 1, to: 2, with: 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]

  ## With pattern matching for chaining

      iex> graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      iex> {:ok, graph} = Yog.add_edge(graph, from: 1, to: 2, with: 10)
      iex> {:ok, graph} = Yog.add_edge(graph, from: 2, to: 1, with: 5)
      iex> Yog.successors(graph, 2)
      [{1, 5}]
  """
  @spec add_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    add_edge(graph, from, to, weight)
  end

  @doc """
  Adds an edge to the graph, raising on error.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      iex> graph = Yog.add_edge!(graph, from: 1, to: 2, with: 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge!(graph(), keyword()) :: graph()
  def add_edge!(graph, opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    add_edge!(graph, from, to, weight)
  end

  @doc """
  Ensures both endpoint nodes exist, then adds an edge.

  If `from` or `to` is not already in the graph, it is created with
  the supplied `default` node data. Existing nodes are left unchanged.

  Always succeeds and returns a `Graph` (never fails).
  Use this when you want to build graphs quickly without pre-creating nodes.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10, default: "anon")
      iex> # Nodes 1 and 2 are auto-created with data "anon"
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge_ensure(graph(), keyword()) :: graph()
  def add_edge_ensure(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    default = Keyword.get(opts, :default, nil)
    add_edge_ensure(graph, from, to, weight, default)
  end

  @doc """
  Ensures both endpoint nodes exist, then adds an edge.

  If `src` or `dst` is not already in the graph, it is created with
  the supplied `default` node data before the edge is added. Nodes
  that already exist are left unchanged.

  Always succeeds and returns a `Graph` (never fails).

  ## Example

      iex> # Nodes 1 and 2 are created automatically with data "unknown"
      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_edge_ensure(1, 2, 10, "unknown")
      iex> Yog.Model.node(graph, 1)
      "unknown"

      iex> # Existing nodes keep their data; only missing ones get the default
      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "Alice")
      ...>   |> Yog.Model.add_edge_ensure(1, 2, 5, "anon")
      iex> # Node 1 is still "Alice", node 2 is "anon"
      iex> {Yog.Model.node(graph, 1), Yog.Model.node(graph, 2)}
      {"Alice", "anon"}
  """
  @spec add_edge_ensure(graph(), node_id(), node_id(), term(), term()) :: graph()
  def add_edge_ensure(graph, src, dst, weight, default \\ nil) do
    graph
    |> ensure_node(src, default)
    |> ensure_node(dst, default)
    |> add_edge_unchecked(src, dst, weight)
  end

  @doc """
  Adds an unweighted edge to the graph.

  This is a convenience function for graphs where edges have no meaningful weight.
  Uses `nil` as the edge data type.

  Returns `{:ok, graph}` or `{:error, reason}` if either endpoint node doesn't exist.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_unweighted_edge(from: 1, to: 2)
      iex> Yog.successors(graph, 1)
      [{2, nil}]
  """
  @spec add_unweighted_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_unweighted_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    add_edge(graph, from, to, nil)
  end

  @doc """
  Ensures both endpoint nodes exist using a callback, then adds an edge.

  If `src` or `dst` is not already in the graph, it is created by
  calling the `by` function with the node ID to generate the node data.
  Nodes that already exist are left unchanged.

  Always succeeds and returns a `Graph` (never fails).

  ## Example

      iex> # Nodes 1 and 2 are created automatically with value that's the same as NodeId
      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_edge_with(1, 2, 10, fn x -> x end)
      iex> Yog.Model.node(graph, 1)
      1

      iex> # Existing nodes keep their data; only missing ones get generated data
      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "1")
      ...>   |> Yog.Model.add_edge_with(1, 2, 5, fn n -> to_string(n) <> ":new" end)
      iex> # Node 1 is still "1", node 2 is "2:new"
      iex> {Yog.Model.node(graph, 1), Yog.Model.node(graph, 2)}
      {"1", "2:new"}
  """
  @spec add_edge_with(graph(), node_id(), node_id(), term(), (node_id() -> term())) :: graph()
  def add_edge_with(graph, src, dst, weight, make_fn) do
    graph
    |> ensure_node_with(src, make_fn)
    |> ensure_node_with(dst, make_fn)
    |> add_edge_unchecked(src, dst, weight)
  end

  @doc """
  Adds multiple edges to the graph in a single operation.

  Fails fast on the first edge that references non-existent nodes.
  Returns `{:error, reason}` if any endpoint node doesn't exist.

  This is more ergonomic than chaining multiple `add_edge` calls
  as it only requires unwrapping a single `Result`.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_node(3, "C")
      ...>   |> Yog.Model.add_edges([{1, 2, 10}, {2, 3, 5}, {1, 3, 15}])
      iex> length(Yog.Model.successors(graph, 1))
      2
  """
  @spec add_edges(graph(), [{node_id(), node_id(), term()}]) ::
          {:ok, graph()} | {:error, String.t()}
  def add_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn {src, dst, weight}, {:ok, g} ->
      case add_edge(g, src, dst, weight) do
        {:ok, new_g} -> {:cont, {:ok, new_g}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Adds multiple edges to the graph, raising on error.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}])
      iex> length(Yog.successors(graph, 1))
      1
  """
  def add_edges!(graph, edges) do
    case add_edges(graph, edges) do
      {:ok, graph} -> graph
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Adds multiple simple edges (weight = 1) to the graph.

  Fails fast on the first edge that references non-existent nodes.
  Convenient for unweighted graphs where all edges have weight 1.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_node(3, "C")
      ...>   |> Yog.Model.add_simple_edges([{1, 2}, {2, 3}, {1, 3}])
      iex> Yog.Model.successors(graph, 1) |> Enum.sort()
      [{2, 1}, {3, 1}]
  """
  @spec add_simple_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  def add_simple_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn {src, dst}, {:ok, g} ->
      case add_edge(g, src, dst, 1) do
        {:ok, new_g} -> {:cont, {:ok, new_g}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Adds multiple unweighted edges (weight = nil) to the graph.

  Fails fast on the first edge that references non-existent nodes.
  Convenient for graphs where edges carry no weight information.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_node(3, "C")
      ...>   |> Yog.Model.add_unweighted_edges([{1, 2}, {2, 3}, {1, 3}])
      iex> Yog.Model.successors(graph, 1) |> Enum.sort()
      [{2, nil}, {3, nil}]
  """
  @spec add_unweighted_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  def add_unweighted_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn {src, dst}, {:ok, g} ->
      case add_edge(g, src, dst, nil) do
        {:ok, new_g} -> {:cont, {:ok, new_g}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Adds an edge, but if an edge already exists between `src` and `dst`,
  it combines the new weight with the existing one using `with_combine`.

  The combine function receives `(existing_weight, new_weight)` and should
  return the combined weight.

  Returns `{:error, reason}` if either endpoint node doesn't exist in `graph.nodes`.

  **Time Complexity:** O(1)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> {:ok, graph} = Yog.Model.add_edge_with_combine(graph, 1, 2, 5, &Kernel.+/2)
      iex> # Edge 1->2 now has weight 15 (10 + 5)
      iex> Yog.Model.successors(graph, 1)
      [{2, 15}]

  ## Use Cases

  - **Edge contraction** in graph algorithms (Stoer-Wagner min-cut)
  - **Multi-graph support** (adding parallel edges with combined weights)
  - **Incremental graph building** (accumulating weights from multiple sources)
  """
  @spec add_edge_with_combine(graph(), node_id(), node_id(), term(), (term(), term() -> term())) ::
          {:ok, graph()} | {:error, String.t()}
  def add_edge_with_combine(%Graph{nodes: nodes} = graph, src, dst, weight, with_combine) do
    has_src = Map.has_key?(nodes, src)
    has_dst = Map.has_key?(nodes, dst)

    cond do
      has_src and has_dst ->
        graph = do_add_directed_combine(graph, src, dst, weight, with_combine)

        result =
          case graph.kind do
            :directed ->
              graph

            :undirected ->
              do_add_directed_combine(graph, dst, src, weight, with_combine)
          end

        {:ok, result}

      not has_src and not has_dst ->
        {:error, "Nodes #{src} and #{dst} do not exist"}

      not has_src ->
        {:error, "Node #{src} does not exist"}

      true ->
        {:error, "Node #{dst} does not exist"}
    end
  end

  @doc """
  Same as `add_edge_with_combine/5` but raises on error.

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge!(1, 2, 10)
      ...>   |> Yog.Model.add_edge_with_combine!(1, 2, 5, &Kernel.+/2)
      iex> Yog.Model.successors(graph, 1)
      [{2, 15}]
  """
  @spec add_edge_with_combine!(graph(), node_id(), node_id(), term(), (term(), term() -> term())) ::
          graph()
  def add_edge_with_combine!(graph, src, dst, weight, with_combine) do
    case add_edge_with_combine(graph, src, dst, weight, with_combine) do
      {:ok, g} -> g
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Removes a node and all its connected edges (incoming and outgoing).

  **Time Complexity:** O(deg(v)) - proportional to the number of edges
  connected to the node, not the whole graph.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_node(3, "C")
      ...>   |> Yog.Model.add_edges([{1, 2, 10}, {2, 3, 20}])
      iex> graph = Yog.Model.remove_node(graph, 2)
      iex> # Node 2 is removed, along with edges 1->2 and 2->3
      iex> Yog.Model.order(graph)
      2
  """
  @spec remove_node(graph(), node_id()) :: graph()
  def remove_node(%Graph{} = graph, id) do
    target_ids = successor_ids(graph, id)
    source_ids = predecessor_ids(graph, id)

    new_nodes = Map.delete(graph.nodes, id)
    new_out = Map.delete(graph.out_edges, id)

    new_in_cleaned =
      Enum.reduce(target_ids, graph.in_edges, fn target_id, acc_in ->
        Map.replace_lazy(acc_in, target_id, &Map.delete(&1, id))
      end)

    new_in = Map.delete(new_in_cleaned, id)

    new_out_cleaned =
      Enum.reduce(source_ids, new_out, fn source_id, acc_out ->
        Map.replace_lazy(acc_out, source_id, &Map.delete(&1, id))
      end)

    %{graph | nodes: new_nodes, out_edges: new_out_cleaned, in_edges: new_in}
  end

  @doc """
  Removes a directed edge from `src` to `dst`.

  For **directed graphs**, this removes the single directed edge from `src` to `dst`.
  For **undirected graphs**, this removes the edges in both directions
  (from `src` to `dst` and from `dst` to `src`).

  **Time Complexity:** O(1)

  ## Example

      iex> # Directed graph - removes single directed edge
      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> graph = Yog.Model.remove_edge(graph, 1, 2)
      iex> # Edge 1->2 is removed
      iex> Yog.Model.successors(graph, 1)
      []

      iex> # Undirected graph - removes both directions
      iex> {:ok, graph} =
      ...>   Yog.Model.new(:undirected)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> graph = Yog.Model.remove_edge(graph, 1, 2)
      iex> # Edge between 1 and 2 is fully removed
      iex> Yog.Model.successors(graph, 1)
      []
  """
  @spec remove_edge(graph(), node_id(), node_id()) :: graph()
  def remove_edge(%Graph{kind: :directed} = graph, src, dst) do
    do_remove_directed_edge(graph, src, dst)
  end

  def remove_edge(%Graph{kind: :undirected} = graph, src, dst) do
    graph
    |> do_remove_directed_edge(src, dst)
    |> do_remove_directed_edge(dst, src)
  end

  # =============================================================================
  # GRAPH QUERIES
  # =============================================================================

  @doc """
  Gets nodes you can travel TO from the given node (successors).
  Returns a list of tuples containing the destination node ID and edge data.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.successors(graph, 1)
      [{2, 10}]
  """
  @spec successors(graph(), node_id()) :: [{node_id(), term()}]
  def successors(graph, id) do
    Yog.Model.Protocol.successors(graph, id)
  end

  @doc """
  Gets nodes you came FROM to reach the given node (predecessors).
  Returns a list of tuples containing the source node ID and edge data.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.predecessors(graph, 2)
      [{1, 10}]
  """
  @spec predecessors(graph(), node_id()) :: [{node_id(), term()}]
  def predecessors(graph, id) do
    Yog.Model.Protocol.predecessors(graph, id)
  end

  @doc """
  Gets all nodes connected to the given node, regardless of direction.
  Useful for algorithms like finding "connected components".

  For undirected graphs, this is equivalent to successors.
  For directed graphs, this combines successors and predecessors without duplicates.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_node(3, "C")
      ...>   |> Yog.Model.add_edges([{1, 2, 10}, {3, 1, 20}])
      iex> Yog.Model.neighbors(graph, 1) |> Enum.sort()
      [{2, 10}, {3, 20}]
  """
  @spec neighbors(graph(), node_id()) :: [{node_id(), term()}]
  def neighbors(graph, id) do
    Yog.Model.Protocol.neighbors(graph, id)
  end

  @doc """
  Returns all neighbor node IDs (without weights).

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 20)
      iex> Yog.Model.neighbor_ids(graph, 1) |> Enum.sort()
      [2, 3]
  """
  @spec neighbor_ids(graph(), node_id()) :: [node_id()]
  def neighbor_ids(graph, id) do
    Yog.Model.Protocol.neighbor_ids(graph, id)
  end

  @doc """
  Returns all successor node IDs (without weights).

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.successor_ids(graph, 1)
      [2]
  """
  @spec successor_ids(graph(), node_id()) :: [node_id()]
  def successor_ids(graph, id) do
    Yog.Model.Protocol.successor_ids(graph, id)
  end

  @doc """
  Returns all predecessor node IDs (without weights).

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.predecessor_ids(graph, 2)
      [1]
  """
  @spec predecessor_ids(graph(), node_id()) :: [node_id()]
  def predecessor_ids(graph, id) do
    Yog.Model.Protocol.predecessor_ids(graph, id)
  end

  @doc """
  Returns all node IDs in the graph.
  This includes all nodes, even isolated nodes with no edges.

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      iex> Yog.Model.all_nodes(graph)
      [1, 2]
  """
  @spec all_nodes(graph()) :: [node_id()]
  def all_nodes(graph) do
    Yog.Model.Protocol.all_nodes(graph)
  end

  @doc """
  Returns the number of nodes in the graph (graph order).

  **Time Complexity:** O(1)

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      iex> Yog.Model.order(graph)
      2
  """
  @spec order(graph()) :: integer()
  def order(graph) do
    Yog.Model.Protocol.order(graph)
  end

  @doc """
  Returns the number of nodes in the graph.
  Equivalent to `order/1`.

  **Time Complexity:** O(1)

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      iex> Yog.Model.node_count(graph)
      2

  Delegates to the `Yog.Model` protocol.
  """
  @spec node_count(graph()) :: integer()
  def node_count(graph) do
    Yog.Model.Protocol.node_count(graph)
  end

  @doc """
  Returns the number of edges in the graph.

  For undirected graphs, each edge is counted once (the pair {u, v}).
  For directed graphs, each directed edge (u -> v) is counted once.

  **Time Complexity:** O(V)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.edge_count(graph)
      1

  Delegates to the `Yog.Model` protocol.
  """
  @spec edge_count(graph()) :: integer()
  def edge_count(graph) do
    Yog.Model.Protocol.edge_count(graph)
  end

  @doc """
  Returns the out-degree of a node (number of outgoing edges).

  For undirected graphs, this returns the total degree (same as `in_degree/2`).

  **Time Complexity:** O(1)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.out_degree(graph, 1)
      1
      iex> Yog.Model.out_degree(graph, 2)
      0

  """
  @spec out_degree(graph(), node_id()) :: non_neg_integer()
  def out_degree(graph, id) do
    Yog.Model.Protocol.out_degree(graph, id)
  end

  @doc """
  Returns the in-degree of a node (number of incoming edges).

  For undirected graphs, this returns the total degree (same as `out_degree/2`).

  **Time Complexity:** O(1)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.in_degree(graph, 2)
      1
      iex> Yog.Model.in_degree(graph, 1)
      0

  """
  @spec in_degree(graph(), node_id()) :: non_neg_integer()
  def in_degree(graph, id) do
    Yog.Model.Protocol.in_degree(graph, id)
  end

  @doc """
  Returns the total degree of a node.

  For directed graphs, this is the sum of in-degree and out-degree.
  For undirected graphs, this counts each edge once (self-loops count as 2).

  **Time Complexity:** O(1) for undirected, O(1) for directed

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:undirected)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> Yog.Model.degree(graph, 1)
      1

  """
  @spec degree(graph(), node_id()) :: non_neg_integer()
  def degree(graph, id) do
    Yog.Model.Protocol.degree(graph, id)
  end

  @doc """
  Gets the type of the graph (`:directed` or `:undirected`).

  ## Example

      iex> graph = Yog.Model.new(:directed)
      iex> Yog.Model.type(graph)
      :directed
  """
  @spec type(graph()) :: graph_type()
  def type(graph) do
    Yog.Model.Protocol.type(graph)
  end

  @doc """
  Returns all nodes in the graph as a map.

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      iex> nodes = Yog.Model.nodes(graph)
      iex> nodes[1]
      "A"
  """
  @spec nodes(graph()) :: map()
  def nodes(graph) do
    Yog.Model.Protocol.nodes(graph)
  end

  @doc """
  Gets the data associated with a node.

  Returns `nil` if the node doesn't exist.

  ## Example

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      iex> Yog.Model.node(graph, 1)
      "A"
  """
  @spec node(graph(), node_id()) :: term() | nil
  def node(graph, id) do
    Yog.Model.Protocol.node(graph, id)
  end

  @doc """
  Checks if the graph contains a node with the given ID.

  ## Example

      iex> graph = Yog.undirected() |> Yog.add_node(1, nil)
      iex> Yog.Model.has_node?(graph, 1)
      true
      iex> Yog.Model.has_node?(graph, 2)
      false

  **Time Complexity:** O(1)
  """
  @spec has_node?(graph(), node_id()) :: boolean()
  def has_node?(graph, id) do
    Yog.Model.Protocol.has_node?(graph, id)
  end

  @doc """
  Checks if the graph contains an edge between `src` and `dst`.

  Returns `true` if an edge exists, `false` otherwise.

  ## Examples

      iex> graph = Yog.from_edges(:directed, [{1, 2, 10}, {1, 3, 20}, {3, 4, 2}])
      iex> Yog.Model.has_edge?(graph, 1, 2)
      true
      iex> Yog.Model.has_edge?(graph, 2, 1)
      false

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 10}, {1, 3, 20}])
      iex> Yog.Model.has_edge?(graph, 2, 1)
      true
      iex> Yog.Model.has_edge?(graph, 2, 4)
      false

  **Time Complexity:** O(1)
  """
  @spec has_edge?(graph(), node_id(), node_id()) :: boolean()
  def has_edge?(graph, src, dst) do
    Yog.Model.Protocol.has_edge?(graph, src, dst)
  end

  @doc """
  Gets the weight/data of an edge between two nodes.
  Returns `nil` if the edge doesn't exist.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 10, nil)
      iex> Yog.Model.edge_data(graph, 1, 2)
      10
  """
  @spec edge_data(graph(), node_id(), node_id()) :: term() | nil
  def edge_data(graph, src, dst) do
    Yog.Model.Protocol.edge_data(graph, src, dst)
  end

  @doc """
  Gets the weight/data of an edge between two nodes, raising if not found.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 10, nil)
      iex> Yog.Model.edge_data!(graph, 1, 2)
      10
  """
  @spec edge_data!(graph(), node_id(), node_id()) :: term()
  def edge_data!(%Graph{out_edges: out} = graph, src, dst) do
    case Map.fetch(out, src) do
      {:ok, inner} ->
        case Map.fetch(inner, dst) do
          {:ok, data} -> data
          :error -> raise "Edge not found: #{src} -> #{dst}"
        end

      :error ->
        raise "Edge source node not found: #{src} in #{inspect(graph)}"
    end
  end

  @doc """
  Returns all edges in the graph as triplets `{from, to, weight}`.

  For directed graphs, returns all edges.
  For undirected graphs, returns each edge only once (where `from <= to`).

  This is particularly useful for graph export formats.

  ## Examples

      iex> graph =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, nil)
      ...>   |> Yog.Model.add_node(2, nil)
      ...>   |> Yog.Model.add_edge!(1, 2, 5)
      iex> Yog.Model.all_edges(graph)
      [{1, 2, 5}]

      iex> graph =
      ...>   Yog.Model.new(:undirected)
      ...>   |> Yog.Model.add_node(1, nil)
      ...>   |> Yog.Model.add_node(2, nil)
      ...>   |> Yog.Model.add_edge!(1, 2, 5)
      iex> edges = Yog.Model.all_edges(graph)
      iex> length(edges)
      1
  """
  @spec all_edges(graph()) :: [{node_id(), node_id(), number()}]
  def all_edges(graph) do
    Yog.Model.Protocol.all_edges(graph)
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  # Adds an edge without checking if nodes exist (internal use).
  # For directed graphs, adds a single edge from src to dst.
  # For undirected graphs, adds edges in both directions.
  defp add_edge_unchecked(%Graph{kind: :directed} = graph, src, dst, weight) do
    new_out = do_add_directed_edge_out(graph.out_edges, src, dst, weight)
    new_in = do_add_directed_edge_in(graph.in_edges, src, dst, weight)
    %{graph | out_edges: new_out, in_edges: new_in}
  end

  defp add_edge_unchecked(%Graph{kind: :undirected} = graph, src, dst, weight) do
    # Add src -> dst
    new_out = do_add_directed_edge_out(graph.out_edges, src, dst, weight)
    new_in = do_add_directed_edge_in(graph.in_edges, src, dst, weight)
    # Add dst -> src (for undirected)
    new_out2 = do_add_directed_edge_out(new_out, dst, src, weight)
    new_in2 = do_add_directed_edge_in(new_in, dst, src, weight)
    %{graph | out_edges: new_out2, in_edges: new_in2}
  end

  # Helper to add outgoing edge
  defp do_add_directed_edge_out(out_edges, src, dst, weight) do
    Map.update(out_edges, src, %{dst => weight}, fn inner ->
      Map.put(inner, dst, weight)
    end)
  end

  # Helper to add incoming edge
  defp do_add_directed_edge_in(in_edges, src, dst, weight) do
    Map.update(in_edges, dst, %{src => weight}, fn inner ->
      Map.put(inner, src, weight)
    end)
  end

  # Adds a node only if it doesn't already exist.
  defp ensure_node(%Graph{} = graph, id, data) do
    if Map.has_key?(graph.nodes, id) do
      graph
    else
      %{graph | nodes: Map.put(graph.nodes, id, data)}
    end
  end

  # Adds a node only if it doesn't already exist, using a function to create the node data.
  defp ensure_node_with(%Graph{} = graph, id, make_fn) do
    if Map.has_key?(graph.nodes, id) do
      graph
    else
      %{graph | nodes: Map.put(graph.nodes, id, make_fn.(id))}
    end
  end

  # Removes a directed edge from src to dst (internal helper).
  defp do_remove_directed_edge(%Graph{} = graph, src, dst) do
    new_out =
      case Map.fetch(graph.out_edges, src) do
        {:ok, targets} -> Map.put(graph.out_edges, src, Map.delete(targets, dst))
        :error -> graph.out_edges
      end

    new_in =
      case Map.fetch(graph.in_edges, dst) do
        {:ok, sources} -> Map.put(graph.in_edges, dst, Map.delete(sources, src))
        :error -> graph.in_edges
      end

    %{graph | out_edges: new_out, in_edges: new_in}
  end

  # Adds a directed edge with weight combination (internal helper).
  defp do_add_directed_combine(%Graph{} = graph, src, dst, weight, with_combine) do
    # Update out_edges
    new_out =
      Map.update(graph.out_edges, src, %{dst => weight}, fn inner ->
        new_weight =
          case Map.fetch(inner, dst) do
            {:ok, existing} -> with_combine.(existing, weight)
            :error -> weight
          end

        Map.put(inner, dst, new_weight)
      end)

    # Update in_edges
    new_in =
      Map.update(graph.in_edges, dst, %{src => weight}, fn inner ->
        new_weight =
          case Map.fetch(inner, src) do
            {:ok, existing} -> with_combine.(existing, weight)
            :error -> weight
          end

        Map.put(inner, src, new_weight)
      end)

    %{graph | out_edges: new_out, in_edges: new_in}
  end
end
