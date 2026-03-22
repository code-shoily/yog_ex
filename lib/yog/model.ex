defmodule Yog.Model do
  @moduledoc """
  Core graph data structures and basic operations for the yog library.

  This module defines the fundamental `Graph` type and provides all basic operations
  for creating and manipulating graphs. The graph uses an adjacency list representation
  with dual indexing (both outgoing and incoming edges) for efficient traversal in both
  directions.

  ## Graph Types

  - **Directed Graph**: Edges have a direction (one-way relationships)
  - **Undirected Graph**: Edges are bidirectional (mutual relationships)

  ## Type Parameters

  - `node_data`: The type of data stored at each node (e.g., `String`, `City`, `Task`)
  - `edge_data`: The type of data stored on edges, typically weights (e.g., `Int`, `Float`)

  ## Quick Start

      iex> graph =
      ...>   Yog.Model.new(:undirected)
      ...>   |> Yog.Model.add_node(1, "Alice")
      ...>   |> Yog.Model.add_node(2, "Bob")
      ...>   |> Yog.Model.add_edge(1, 2, 10)
      iex> {:ok, g} = graph
      iex> Yog.Model.successors(g, 1)
      [{2, 10}]

  ## Design Notes

  The dual-map representation enables O(1) edge existence checks and O(1) transpose
  operations, at the cost of increased memory usage and slightly more complex edge
  updates.
  """

  @typedoc """
  Unique identifier for a node in the graph.
  """
  @type node_id :: integer()

  @typedoc """
  The type of graph: `:directed` or `:undirected`.
  """
  @type graph_type :: :directed | :undirected

  @typedoc """
  A simple graph data structure that can be directed or undirected.

  - `kind`: The graph type (`:directed` or `:undirected`)
  - `nodes`: A map of node IDs to node data
  - `out_edges`: A map of source node IDs to maps of destination node IDs to edge data
  - `in_edges`: A map of destination node IDs to maps of source node IDs to edge data
  """
  @type graph :: {:graph, graph_type(), map(), map(), map()}

  @doc """
  Creates a new empty graph of the specified type.

  ## Example

      iex> graph = Yog.Model.new(:directed)
      iex> Yog.Model.order(graph)
      0
  """
  @spec new(graph_type()) :: graph()
  def new(graph_type) do
    :yog@model.new(
      case graph_type do
        :directed -> :directed
        :undirected -> :undirected
      end
    )
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
  defdelegate add_node(graph, id, data), to: :yog@model

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
  def add_edge(graph, from, to, weight) do
    case :yog@model.add_edge(graph, from, to, weight) do
      {:ok, g} -> {:ok, g}
      {:error, reason} -> {:error, reason}
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
  defdelegate add_edge_ensure(graph, from, to, weight, default), to: :yog@model

  @doc """
  Deprecated compatibility alias for `add_edge_ensure/5`.
  """
  @deprecated "Use add_edge_ensure/5 instead"
  defdelegate add_edge_ensured(graph, from, to, weight, default),
    to: __MODULE__,
    as: :add_edge_ensure

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
  defdelegate add_edge_with(graph, from, to, weight, by), to: :yog@model

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
  defdelegate add_edges(graph, edges), to: :yog@model

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
      iex> Yog.Model.successors(graph, 1)
      [{2, 1}, {3, 1}]
  """
  @spec add_simple_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  defdelegate add_simple_edges(graph, edges), to: :yog@model

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
      iex> Yog.Model.successors(graph, 1)
      [{2, nil}, {3, nil}]
  """
  @spec add_unweighted_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  defdelegate add_unweighted_edges(graph, edges), to: :yog@model

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
  defdelegate successors(graph, id), to: :yog@model

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
  defdelegate predecessors(graph, id), to: :yog@model

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
      iex> length(Yog.Model.neighbors(graph, 1))
      2
  """
  @spec neighbors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate neighbors(graph, id), to: :yog@model

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
  defdelegate all_nodes(graph), to: :yog@model

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
  defdelegate order(graph), to: :yog@model

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
  """
  @spec node_count(graph()) :: integer()
  defdelegate node_count(graph), to: :yog@model

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
  """
  @spec edge_count(graph()) :: integer()
  defdelegate edge_count(graph), to: :yog@model

  @doc """
  Returns just the NodeIds of successors (without edge weights).
  Convenient for traversal algorithms that only need the IDs.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.Model.new(:directed)
      ...>   |> Yog.Model.add_node(1, "A")
      ...>   |> Yog.Model.add_node(2, "B")
      ...>   |> Yog.Model.add_node(3, "C")
      ...>   |> Yog.Model.add_edges([{1, 2, 10}, {1, 3, 20}])
      iex> Yog.Model.successor_ids(graph, 1) |> Enum.sort()
      [2, 3]
  """
  @spec successor_ids(graph(), node_id()) :: [node_id()]
  defdelegate successor_ids(graph, id), to: :yog@model

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
  defdelegate remove_node(graph, id), to: :yog@model

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
  defdelegate remove_edge(graph, src, dst), to: :yog@model

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
  def add_edge_with_combine(graph, src, dst, weight, with_combine) do
    case :yog@model.add_edge_with_combine(graph, src, dst, weight, with_combine) do
      {:ok, g} -> {:ok, g}
      {:error, reason} -> {:error, reason}
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
  Gets the type of the graph (`:directed` or `:undirected`).

  ## Example

      iex> graph = Yog.Model.new(:directed)
      iex> Yog.Model.type(graph)
      :directed
  """
  @spec type(graph()) :: graph_type()
  def type(graph) do
    {:graph, kind, _, _, _} = graph
    kind
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
    {:graph, _, nodes, _, _} = graph
    nodes
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
    nodes = nodes(graph)
    Map.get(nodes, id)
  end
end
