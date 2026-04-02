defprotocol Yog.Queryable do
  @moduledoc """
  Minimal protocol for read-only graph queries.

  This protocol defines only the essential functions needed to query a graph.
  All other query operations can be derived from these core functions using
  `Yog.Queryable.Defaults`. Implementations should override defaults for efficiency.

  ## Required Functions (7)

  Implementations MUST provide these:
  - `successors/2` - nodes reachable from given node as [{id, weight}]
  - `predecessors/2` - nodes that can reach given node as [{id, weight}]
  - `type/1` - :directed or :undirected
  - `node/2` - data associated with a node (nil if not found)
  - `all_nodes/1` - list of all node IDs
  - `order/1` - number of nodes
  - `edge_count/1` - number of edges

  ## Optional Functions (with defaults)

  These have working default implementations in `Yog.Queryable.Defaults`:
  - `out_degree/2` - defaults to length(successors)
  - `in_degree/2` - defaults to length(predecessors)
  - `degree/2` - defaults to out_degree + in_degree
  - `successor_ids/2`, `predecessor_ids/2`, `neighbor_ids/2`
  - `neighbors/2` - merged successors and predecessors
  - `has_node?/2`, `has_edge?/3`
  - `nodes/1`, `all_edges/1`, `edge_data/3`
  - `node_count/1` - alias for order

  ## Example: Minimal Implementation

      defimpl Yog.Queryable, for: MyGraph do
        def successors(graph, id), do: ...
        def predecessors(graph, id), do: ...
        def type(graph), do: ...
        def node(graph, id), do: ...
        def all_nodes(graph), do: ...
        def order(graph), do: ...
        def edge_count(graph), do: ...

        # Override defaults for efficiency
        def out_degree(graph, id), do: Map.get(graph.degrees, id, 0)
        defdelegate has_edge?(g, s, d), to: Yog.Queryable.Defaults
        # ... etc
      end
  """

  # Core required functions
  def successors(graph, id)
  def predecessors(graph, id)
  def type(graph)
  def node(graph, id)
  def all_nodes(graph)
  def order(graph)
  def edge_count(graph)

  # Optional with defaults
  def out_degree(graph, id)
  def in_degree(graph, id)
  def degree(graph, id)
  def successor_ids(graph, id)
  def predecessor_ids(graph, id)
  def neighbors(graph, id)
  def neighbor_ids(graph, id)
  def has_node?(graph, id)
  def has_edge?(graph, src, dst)
  def nodes(graph)
  def all_edges(graph)
  def edge_data(graph, src, dst)
  def node_count(graph)
end

defprotocol Yog.Modifiable do
  @moduledoc """
  Protocol for graph modification operations.

  This protocol defines the minimal interface for adding, removing, and
  updating nodes and edges within a graph. Convenience functions for common
  patterns (unweighted edges, batch operations, etc.) are provided by the
  main API modules (`Yog`, `Yog.Model`) and delegate to these core functions.

  ## Core Operations (7 functions)

  - `add_node/3`, `remove_node/2` - Node lifecycle
  - `add_edge/4`, `add_edges/2`, `remove_edge/3` - Edge lifecycle
  - `add_edge_ensure/5` - Edge with auto-created nodes
  - `add_edge_with_combine/5` - Edge with weight merging

  ## Convenience Alternatives

  For `add_unweighted_edge/2`, `add_simple_edges/2`, `add_unweighted_edges/2`,
  use the corresponding functions in `Yog` or `Yog.Model` modules which
  delegate to the protocol functions above.
  """

  @doc "Adds a node to the graph with the given ID and data."
  def add_node(graph, id, data)

  @doc "Removes a node and all its connected edges from the graph."
  def remove_node(graph, id)

  @doc "Adds an edge to the graph with the given weight."
  def add_edge(graph, src, dst, weight)

  @doc "Adds multiple edges to the graph for batch efficiency."
  def add_edges(graph, edges)

  @doc "Removes an edge from the graph."
  def remove_edge(graph, src, dst)

  @doc """
  Ensures both endpoint nodes exist (creating them with default data if needed),
  then adds an edge. Returns a graph (never fails).
  """
  def add_edge_ensure(graph, src, dst, weight, default_data)

  @doc """
  Adds an edge, but if an edge already exists, combines the new weight
  with the existing one using the provided function.
  """
  def add_edge_with_combine(graph, src, dst, weight, with_combine)
end

defprotocol Yog.Transformable do
  @moduledoc """
  Protocol for structural graph transformations.

  This protocol defines operations that transform a graph while preserving or
  systematically altering its structure. Implementations can provide optimized
  versions of these operations (e.g., O(1) transpose).
  """

  @doc """
  Returns an empty graph of the same implementation as the template.
  The new graph will have the same kind (:directed or :undirected) as the template.
  """
  def empty(graph)

  @doc """
  Returns an empty graph of the same implementation as the template with the specified kind.
  """
  def empty(graph, kind)

  @doc """
  Reverses the direction of every edge in the graph (graph transpose).
  """
  def transpose(graph)

  @doc """
  Transforms node data using a function, preserving graph structure.
  """
  def map_nodes(graph, fun)

  @doc """
  Transforms edge weights using a function, preserving graph structure.
  """
  def map_edges(graph, fun)
end
