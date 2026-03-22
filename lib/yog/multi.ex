defmodule Yog.Multi do
  @moduledoc """
  Multigraph operations for graphs with parallel edges.

  A multigraph allows multiple edges between the same pair of nodes.
  This is useful for modeling:
  - Transportation networks with different routes
  - Communication networks with multiple channels
  - Dependency graphs with different types of relationships
  - Any domain where parallel connections matter

  ## Edge IDs

  Unlike simple graphs, multigraphs use `EdgeId` (integers) to uniquely
  identify each edge. When adding an edge, you receive the new edge ID.

  ## Examples

      # Create a directed multigraph
      multi = Yog.Multi.directed()
      multi = Yog.Multi.add_node(multi, :a, "Node A")
      multi = Yog.Multi.add_node(multi, :b, "Node B")

      # Add parallel edges
      {multi, edge1} = Yog.Multi.add_edge(multi, :a, :b, "flight")
      {multi, edge2} = Yog.Multi.add_edge(multi, :a, :b, "train")
      {multi, edge3} = Yog.Multi.add_edge(multi, :a, :b, "bus")

      # Query parallel edges
      edges = Yog.Multi.edges_between(multi, :a, :b)
      #=> [{edge1, "flight"}, {edge2, "train"}, {edge3, "bus"}]

      # Convert to simple graph (combines parallel edges)
      simple = Yog.Multi.to_simple_graph_min_edges(multi)
  """

  alias Yog.Multi.{Eulerian, Model, Traversal}

  @typedoc "A multigraph that can hold multiple edges between nodes"
  @type t :: Model.t()

  @typedoc "Unique identifier for an edge in a multigraph"
  @type edge_id :: Model.edge_id()

  @typedoc "Control flow for fold_walk traversal"
  @type walk_control :: Traversal.walk_control()

  @typedoc "Metadata provided during fold_walk traversal"
  @type walk_metadata :: Traversal.walk_metadata()

  # ============================================================
  # Construction
  # ============================================================

  @doc """
  Creates a new, empty multigraph of the given type.

  ## Examples

      multi = Yog.Multi.new(:directed)
      multi = Yog.Multi.new(:undirected)
  """
  @spec new(Yog.graph_type()) :: t()
  def new(type) do
    Model.new(type)
  end

  @doc """
  Creates a new, empty directed multigraph.

  ## Examples

      multi = Yog.Multi.directed()
  """
  @spec directed() :: t()
  def directed, do: Model.directed()

  @doc """
  Creates a new, empty undirected multigraph.

  ## Examples

      multi = Yog.Multi.undirected()
  """
  @spec undirected() :: t()
  def undirected, do: Model.undirected()

  # ============================================================
  # Node Operations
  # ============================================================

  @doc """
  Adds a node with the given ID and data.

  If the node already exists, its data is replaced (edges are unaffected).

  ## Examples

      multi = Yog.Multi.add_node(multi, :a, "Node A")
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node(multi, id, data) do
    Model.add_node(multi, id, data)
  end

  @doc """
  Removes a node and all edges connected to it.

  ## Examples

      multi = Yog.Multi.remove_node(multi, :a)
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  def remove_node(multi, id) do
    Model.remove_node(multi, id)
  end

  @doc """
  Returns all node IDs in the multigraph.

  ## Examples

      nodes = Yog.Multi.all_nodes(multi)
      #=> [:a, :b, :c]
  """
  @spec all_nodes(t()) :: [Yog.node_id()]
  def all_nodes(multi) do
    Model.all_nodes(multi)
  end

  @doc """
  Returns the number of nodes (graph order).

  ## Examples

      count = Yog.Multi.order(multi)
      #=> 3
  """
  @spec order(t()) :: integer()
  def order(multi) do
    Model.order(multi)
  end

  # ============================================================
  # Edge Operations
  # ============================================================

  @doc """
  Adds an edge from `from` to `to` with the given data.

  Returns `{updated_multigraph, new_edge_id}` so you can reference
  this specific edge later (e.g., for `remove_edge`).

  For undirected graphs, a single `EdgeId` is issued and the reverse
  direction is indexed automatically.

  ## Examples

      {multi, e1} = Yog.Multi.add_edge(multi, :a, :b, "flight")
      {multi, e2} = Yog.Multi.add_edge(multi, :a, :b, "train")
      # e1 != e2 — two independent parallel edges
  """
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) :: {t(), edge_id()}
  def add_edge(multi, from, to, data) do
    Model.add_edge(multi, from, to, data)
  end

  @doc """
  Removes a single edge by its `EdgeId`.

  For undirected graphs, both direction entries are removed.

  ## Examples

      multi = Yog.Multi.remove_edge(multi, edge_id)
  """
  @spec remove_edge(t(), edge_id()) :: t()
  def remove_edge(multi, edge_id) do
    Model.remove_edge(multi, edge_id)
  end

  @doc """
  Returns `true` if an edge with this ID exists in the multigraph.

  ## Examples

      if Yog.Multi.has_edge?(multi, edge_id) do
        # Edge exists
      end
  """
  @spec has_edge?(t(), edge_id()) :: boolean()
  def has_edge?(multi, edge_id) do
    Model.has_edge(multi, edge_id)
  end

  @doc """
  Returns all edge IDs in the multigraph.

  ## Examples

      edge_ids = Yog.Multi.all_edge_ids(multi)
      #=> [0, 1, 2, 3]
  """
  @spec all_edge_ids(t()) :: [edge_id()]
  def all_edge_ids(multi) do
    Model.all_edge_ids(multi)
  end

  @doc """
  Returns the total number of edges (graph size).

  For undirected graphs, each physical edge is counted once.

  ## Examples

      count = Yog.Multi.size(multi)
      #=> 4
  """
  @spec size(t()) :: integer()
  def size(multi) do
    Model.size(multi)
  end

  @doc """
  Returns all parallel edges between `from` and `to`.

  Returns a list of `{edge_id, edge_data}` tuples.

  ## Examples

      edges = Yog.Multi.edges_between(multi, :a, :b)
      #=> [{edge1, "flight"}, {edge2, "train"}]
  """
  @spec edges_between(t(), Yog.node_id(), Yog.node_id()) :: [{edge_id(), any()}]
  def edges_between(multi, from, to) do
    Model.edges_between(multi, from, to)
  end

  @doc """
  Returns all outgoing edges from a node.

  Returns a list of `{to_node, edge_id, edge_data}` tuples.

  ## Examples

      edges = Yog.Multi.successors(multi, :a)
      #=> [{:b, edge1, "flight"}, {:c, edge2, "drive"}]
  """
  @spec successors(t(), Yog.node_id()) :: [{Yog.node_id(), edge_id(), any()}]
  def successors(multi, id) do
    Model.successors(multi, id)
  end

  @doc """
  Returns all incoming edges to a node.

  Returns a list of `{from_node, edge_id, edge_data}` tuples.

  ## Examples

      edges = Yog.Multi.predecessors(multi, :b)
      #=> [{:a, edge1, "flight"}, {:c, edge2, "connecting"}]
  """
  @spec predecessors(t(), Yog.node_id()) :: [{Yog.node_id(), edge_id(), any()}]
  def predecessors(multi, id) do
    Model.predecessors(multi, id)
  end

  @doc """
  Returns the out-degree of a node (number of outgoing edges).

  For undirected graphs, this equals the total degree.

  ## Examples

      degree = Yog.Multi.out_degree(multi, :a)
      #=> 3
  """
  @spec out_degree(t(), Yog.node_id()) :: integer()
  def out_degree(multi, id) do
    Model.out_degree(multi, id)
  end

  @doc """
  Returns the in-degree of a node (number of incoming edges).

  ## Examples

      degree = Yog.Multi.in_degree(multi, :a)
      #=> 2
  """
  @spec in_degree(t(), Yog.node_id()) :: integer()
  def in_degree(multi, id) do
    Model.in_degree(multi, id)
  end

  # ============================================================
  # Conversion
  # ============================================================

  @doc """
  Collapses the multigraph into a simple `Yog.graph()` by combining
  parallel edges with `combine_fn(existing, new)`.

  ## Examples

      # Keep minimum weight among parallel edges
      simple = Yog.Multi.to_simple_graph(multi, fn a, b -> min(a, b) end)
  """
  @spec to_simple_graph(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph(multi, combine_fn) do
    Model.to_simple_graph(multi, combine_fn)
  end

  @doc """
  Collapses parallel edges, keeping the minimum weight.

  ## Examples

      simple = Yog.Multi.to_simple_graph_min_edges(multi)
  """
  @spec to_simple_graph_min_edges(t()) :: Yog.graph()
  def to_simple_graph_min_edges(multi) do
    Model.to_simple_graph_min_edges(multi)
  end

  @doc """
  Collapses parallel edges, summing weights.

  ## Examples

      simple = Yog.Multi.to_simple_graph_sum_edges(multi)
  """
  @spec to_simple_graph_sum_edges(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph_sum_edges(multi, add_fn \\ &(&1 + &2)) do
    Model.to_simple_graph_sum_edges(multi, add_fn)
  end

  # ============================================================
  # Traversal
  # ============================================================

  @doc """
  Performs a Breadth-First Search from `source`, returning visited node IDs
  in BFS order.

  Unlike simple-graph BFS, this traversal uses edge IDs to correctly handle
  parallel edges — each **edge** is traversed at most once, but a node may be
  reached via multiple edges.

  ## Examples

      nodes = Yog.Multi.bfs(multi, :a)
      #=> [:a, :b, :c, :d]
  """
  @spec bfs(t(), Yog.node_id()) :: [Yog.node_id()]
  def bfs(multi, source) do
    Traversal.bfs(multi, source)
  end

  @doc """
  Performs a Depth-First Search from `source`, returning visited node IDs
  in DFS pre-order.

  ## Examples

      nodes = Yog.Multi.dfs(multi, :a)
      #=> [:a, :b, :d, :c]
  """
  @spec dfs(t(), Yog.node_id()) :: [Yog.node_id()]
  def dfs(multi, source) do
    Traversal.dfs(multi, source)
  end

  @doc """
  Folds over nodes during multigraph traversal, accumulating state with metadata.

  This function combines traversal with state accumulation, providing metadata
  about each visited node including which specific edge was used to reach it.

  The folder function controls the traversal flow:
  - `:continue` - Explore successors of the current node normally
  - `:stop` - Skip successors of this node, but continue with other queued nodes
  - `:halt` - Stop the entire traversal immediately and return the accumulator

  ## Examples

      # Build a parent map tracking which edge led to each node
      parents = Yog.Multi.fold_walk(multi, :a, %{}, fn acc, node_id, meta ->
        new_acc = case meta.parent do
          {parent_node, edge_id} -> Map.put(acc, node_id, {parent_node, edge_id})
          nil -> acc
        end
        {:continue, new_acc}
      end)

      # Find all nodes within distance 3
      nearby = Yog.Multi.fold_walk(multi, :a, [], fn acc, node_id, meta ->
        if meta.depth <= 3 do
          {:continue, [node_id | acc]}
        else
          {:stop, acc}
        end
      end)
  """
  @spec fold_walk(
          t(),
          Yog.node_id(),
          acc,
          (acc, Yog.node_id(), walk_metadata() -> {walk_control(), acc})
        ) :: acc
        when acc: var
  def fold_walk(multi, from, initial, folder) do
    Traversal.fold_walk(multi, from, initial, folder)
  end

  # ============================================================
  # Eulerian (delegated to Eulerian module)
  # ============================================================

  @doc """
  Returns `true` if the multigraph has an Eulerian circuit.

  A closed walk that traverses every edge exactly once.

  Conditions:
  - **Undirected:** all nodes have even degree and the graph is connected
  - **Directed:** every node has equal in-degree and out-degree

  ## Examples

      if Yog.Multi.eulerian_circuit?(multi) do
        circuit = Yog.Multi.find_eulerian_circuit(multi)
      end
  """
  @spec eulerian_circuit?(t()) :: boolean()
  def eulerian_circuit?(multi) do
    Eulerian.has_eulerian_circuit?(multi)
  end

  @doc """
  Returns `true` if the multigraph has an Eulerian path.

  An open walk that traverses every edge exactly once.

  ## Examples

      if Yog.Multi.eulerian_path?(multi) do
        path = Yog.Multi.find_eulerian_path(multi)
      end
  """
  @spec eulerian_path?(t()) :: boolean()
  def eulerian_path?(multi) do
    Eulerian.has_eulerian_path?(multi)
  end

  @doc """
  Finds an Eulerian circuit using Hierholzer's algorithm.

  Returns the circuit as a list of `EdgeId`s, or `:none` if no circuit exists.

  ## Examples

      case Yog.Multi.find_eulerian_circuit(multi) do
        {:some, edge_ids} -> traverse_circuit(edge_ids)
        :none -> :no_circuit
      end
  """
  @spec find_eulerian_circuit(t()) :: {:some, [edge_id()]} | :none
  def find_eulerian_circuit(multi) do
    Eulerian.find_eulerian_circuit(multi)
  end

  @doc """
  Finds an Eulerian path using Hierholzer's algorithm.

  Returns the path as a list of `EdgeId`s, or `:none` if no path exists.

  ## Examples

      case Yog.Multi.find_eulerian_path(multi) do
        {:some, edge_ids} -> traverse_path(edge_ids)
        :none -> :no_path
      end
  """
  @spec find_eulerian_path(t()) :: {:some, [edge_id()]} | :none
  def find_eulerian_path(multi) do
    Eulerian.find_eulerian_path(multi)
  end
end
