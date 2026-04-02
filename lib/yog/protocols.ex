defprotocol Yog.Queryable do
  @moduledoc """
  Protocol for read-only graph queries.

  This protocol defines the standard interface for extracting information from
  a graph without modifying its structure or data.
  """

  @doc "Gets nodes you can travel TO from the given node (successors)."
  def successors(graph, id)

  @doc "Gets nodes you came FROM to reach the given node (predecessors)."
  def predecessors(graph, id)

  @doc "Gets all nodes connected to the given node, regardless of direction."
  def neighbors(graph, id)

  @doc "Returns all successor node IDs (without weights)."
  def successor_ids(graph, id)

  @doc "Returns all predecessor node IDs (without weights)."
  def predecessor_ids(graph, id)

  @doc "Returns all neighbor node IDs (without weights)."
  def neighbor_ids(graph, id)

  @doc "Returns all node IDs in the graph."
  def all_nodes(graph)

  @doc "Returns the number of nodes in the graph (graph order)."
  def order(graph)

  @doc "Returns the number of nodes in the graph."
  def node_count(graph)

  @doc "Returns the number of edges in the graph."
  def edge_count(graph)

  @doc "Returns the out-degree of a node (number of outgoing edges)."
  def out_degree(graph, id)

  @doc "Returns the in-degree of a node (number of incoming edges)."
  def in_degree(graph, id)

  @doc "Returns the total degree of a node."
  def degree(graph, id)

  @doc "Checks if the graph contains a node with the given ID."
  def has_node?(graph, id)

  @doc "Checks if the graph contains an edge between src and dst."
  def has_edge?(graph, src, dst)

  @doc "Gets the data associated with a node."
  def node(graph, id)

  @doc "Returns all nodes in the graph as a map."
  def nodes(graph)

  @doc "Gets the weight/data of an edge between two nodes."
  def edge_data(graph, src, dst)

  @doc "Returns all edges in the graph as triplets {from, to, weight}."
  def all_edges(graph)

  @doc "Gets the type of the graph (:directed or :undirected)."
  def type(graph)
end

defprotocol Yog.Modifiable do
  @moduledoc """
  Protocol for graph modification operations.

  This protocol defines the standard interface for adding, removing, and
  updating nodes and edges within a graph.
  """

  @doc "Adds a node to the graph with the given ID and data."
  def add_node(graph, id, data)

  @doc "Removes a node and all its connected edges from the graph."
  def remove_node(graph, id)

  @doc "Adds an edge to the graph with the given weight."
  def add_edge(graph, src, dst, weight)

  @doc "Adds an edge to the graph using a keyword list of options."
  def add_edge(graph, opts)

  @doc "Removes an edge from the graph."
  def remove_edge(graph, src, dst)

  @doc """
  Ensures both endpoint nodes exist, then adds an edge.
  Returns a graph (never fails).
  """
  def add_edge_ensure(graph, src, dst, weight, default)

  @doc """
  Ensures both endpoint nodes exist, then adds an edge using options.
  """
  def add_edge_ensure(graph, opts)

  @doc """
  Ensures both endpoint nodes exist, then adds an edge, but if they don't, 
  calls the make_fn with the node ID to generate the data.
  """
  def add_edge_with(graph, src, dst, weight, make_fn)

  @doc "Adds an unweighted edge to the graph."
  def add_unweighted_edge(graph, opts)

  @doc "Adds multiple edges to the graph."
  def add_edges(graph, edges)

  @doc "Adds multiple simple edges (weight = 1) to the graph."
  def add_simple_edges(graph, edges)

  @doc "Adds multiple unweighted edges (weight = nil) to the graph."
  def add_unweighted_edges(graph, edges)

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
