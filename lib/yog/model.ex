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

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.Graph

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

  This is an alias for `Yog.Graph.t()`.
  """
  @type graph :: Graph.t()

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
  def add_edge_ensure(graph, src, dst, weight, default) do
    graph
    |> ensure_node(src, default)
    |> ensure_node(dst, default)
    |> add_edge_unchecked(src, dst, weight)
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
  def successors(%Graph{out_edges: out_edges}, id) do
    case Map.fetch(out_edges, id) do
      {:ok, inner} -> Map.to_list(inner)
      :error -> []
    end
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
  def predecessors(%Graph{in_edges: in_edges}, id) do
    case Map.fetch(in_edges, id) do
      {:ok, inner} -> Map.to_list(inner)
      :error -> []
    end
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
  def neighbors(%Graph{kind: :undirected} = graph, id) do
    successors(graph, id)
  end

  def neighbors(%Graph{kind: :directed} = graph, id) do
    outgoing = successors(graph, id)

    case Map.fetch(graph.in_edges, id) do
      {:ok, inner} ->
        out_ids = successor_ids(graph, id)
        incoming_to_add = inner |> Map.drop(out_ids) |> Map.to_list()
        outgoing ++ incoming_to_add

      :error ->
        outgoing
    end
  end

  @doc """
  Returns all neighbor node IDs (without weights).

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 10)
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 20)
      iex> Yog.Model.neighbor_ids(graph, 1) |> Enum.sort()
      [2, 3]
  """
  @spec neighbor_ids(graph(), node_id()) :: [node_id()]
  def neighbor_ids(%Graph{kind: :undirected} = graph, id) do
    successor_ids(graph, id)
  end

  def neighbor_ids(%Graph{kind: :directed} = graph, id) do
    out_ids = successor_ids(graph, id)
    in_ids = predecessor_ids(graph, id)
    Enum.uniq(out_ids ++ in_ids)
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
  def successor_ids(%Graph{out_edges: out_edges}, id) do
    case Map.fetch(out_edges, id) do
      {:ok, inner} -> Map.keys(inner)
      :error -> []
    end
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
  def predecessor_ids(%Graph{in_edges: in_edges}, id) do
    case Map.fetch(in_edges, id) do
      {:ok, inner} -> Map.keys(inner)
      :error -> []
    end
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
  def all_nodes(%Graph{nodes: nodes}) do
    Map.keys(nodes)
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
  def order(%Graph{nodes: nodes}) do
    map_size(nodes)
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
  """
  @spec node_count(graph()) :: integer()
  def node_count(graph) do
    order(graph)
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
  """
  @spec edge_count(graph()) :: integer()
  def edge_count(%Graph{kind: :directed, out_edges: out_edges}) do
    Enum.reduce(out_edges, 0, fn {_src, targets}, acc ->
      acc + map_size(targets)
    end)
  end

  def edge_count(%Graph{kind: :undirected, out_edges: out_edges}) do
    {total, self_loops} =
      Enum.reduce(out_edges, {0, 0}, fn {src, targets}, {acc_total, acc_self} ->
        new_total = acc_total + map_size(targets)
        new_self = if Map.has_key?(targets, src), do: acc_self + 1, else: acc_self
        {new_total, new_self}
      end)

    div(total - self_loops, 2) + self_loops
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
  Gets the type of the graph (`:directed` or `:undirected`).

  ## Example

      iex> graph = Yog.Model.new(:directed)
      iex> Yog.Model.type(graph)
      :directed
  """
  @spec type(graph()) :: graph_type()
  def type(%Graph{kind: kind}) do
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
  def nodes(%Graph{nodes: nodes}) do
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
    graph |> nodes() |> Map.get(id)
  end

  @doc """
  Checks if the graph contains a node with the given ID.

  **Time Complexity:** O(1)
  """
  @spec has_node?(graph(), node_id()) :: boolean()
  def has_node?(%Graph{nodes: nodes}, id) do
    Map.has_key?(nodes, id)
  end

  @doc """
  Checks if the graph contains an edge between `src` and `dst`.

  Returns `true` if an edge exists, `false` otherwise.

  **Time Complexity:** O(1)
  """
  @spec has_edge?(graph(), node_id(), node_id()) :: boolean()
  def has_edge?(%Graph{out_edges: out}, src, dst) do
    case Map.fetch(out, src) do
      {:ok, inner} -> Map.has_key?(inner, dst)
      :error -> false
    end
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
  def edge_data(%Graph{out_edges: out}, src, dst) do
    case Map.fetch(out, src) do
      {:ok, inner} -> Map.get(inner, dst)
      :error -> nil
    end
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
  def all_edges(%Graph{kind: kind, out_edges: out_edges}) do
    if kind == :directed do
      for {from, dests} <- out_edges,
          {to, weight} <- dests do
        {from, to, weight}
      end
    else
      # For undirected graphs, deduplicate by only taking edges where from <= to
      for {from, dests} <- out_edges,
          {to, weight} <- dests,
          from <= to do
        {from, to, weight}
      end
    end
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
