defprotocol Yog.Model.Protocol do
  @moduledoc """
  Protocol for graph data structures.

  Any struct implementing this protocol can be used with Yog algorithms
  (Pathfinding, Community, Centrality, etc.).

  ## Implementations

  - `Yog.Graph` - Standard adjacency list graph (built-in)
  - `Yog.Multi.Graph` - Multigraph with edge IDs (built-in)
  - `Yog.DAG` - Directed acyclic graph wrapper (built-in)
  - Custom structs - Third-party graph implementations

  ## Example Custom Implementation

      defmodule MyLib.CSRGraph do
        defstruct [:n, :row_ptr, :col_idx, :weights, :directed]
      end

      defimpl Yog.Model, for: MyLib.CSRGraph do
        def type(%{directed: true}), do: :directed
        def type(%{directed: false}), do: :undirected

        def all_nodes(g), do: 0..(g.n - 1)
        def successors(g, node), do: csr_successors(g, node)
        # ... etc
      end

  ## Usage

  Once implemented, use with any Yog algorithm:

      graph = %MyLib.CSRGraph{...}
      Yog.Pathfinding.shortest_path(in: graph, from: :a, to: :b)
      Yog.Community.louvain(graph)
      Yog.Centrality.betweenness(graph)
  """

  @typedoc """
  Any term implementing the Yog.Model protocol.
  """
  @type t :: term()

  # =============================================================================
  # Graph Properties
  # =============================================================================

  @doc """
  Returns the type of the graph: `:directed` or `:undirected`.
  """
  @spec type(t()) :: :directed | :undirected
  def type(graph)

  @doc """
  Returns the number of nodes in the graph.
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(graph)

  @doc """
  Alias for `node_count/1`. Returns the order (number of nodes) of the graph.
  """
  @spec order(t()) :: non_neg_integer()
  def order(graph)

  @doc """
  Returns the number of edges in the graph.

  For undirected graphs, each edge is counted once.
  For directed graphs, each directed edge is counted once.
  """
  @spec edge_count(t()) :: non_neg_integer()
  def edge_count(graph)

  # =============================================================================
  # Node Queries
  # =============================================================================

  @doc """
  Returns a list of all node IDs in the graph.
  """
  @spec all_nodes(t()) :: [Yog.node_id()]
  def all_nodes(graph)

  @doc """
  Returns all nodes as a map: `%{node_id => data}`.
  """
  @spec nodes(t()) :: %{Yog.node_id() => any()}
  def nodes(graph)

  @doc """
  Returns the data associated with a node, or `nil` if the node doesn't exist.
  """
  @spec node(t(), Yog.node_id()) :: any() | nil
  def node(graph, id)

  @doc """
  Returns `true` if the graph contains the given node ID.
  """
  @spec has_node?(t(), Yog.node_id()) :: boolean()
  def has_node?(graph, id)

  # =============================================================================
  # Edge Queries
  # =============================================================================

  @doc """
  Returns a list of `{neighbor_id, weight}` tuples for all outgoing edges from `id`.
  """
  @spec successors(t(), Yog.node_id()) :: [{Yog.node_id(), any()}]
  def successors(graph, id)

  @doc """
  Returns a list of `{neighbor_id, weight}` tuples for all incoming edges to `id`.
  """
  @spec predecessors(t(), Yog.node_id()) :: [{Yog.node_id(), any()}]
  def predecessors(graph, id)

  @doc """
  Returns a list of neighbor IDs for outgoing edges from `id`.
  """
  @spec successor_ids(t(), Yog.node_id()) :: [Yog.node_id()]
  def successor_ids(graph, id)

  @doc """
  Returns a list of neighbor IDs for incoming edges to `id`.
  """
  @spec predecessor_ids(t(), Yog.node_id()) :: [Yog.node_id()]
  def predecessor_ids(graph, id)

  @doc """
  Returns a list of all neighbors (both incoming and outgoing) for undirected graphs,
  or all successors and predecessors for directed graphs.
  """
  @spec neighbors(t(), Yog.node_id()) :: [{Yog.node_id(), any()}]
  def neighbors(graph, id)

  @doc """
  Returns a list of all neighbor IDs.
  """
  @spec neighbor_ids(t(), Yog.node_id()) :: [Yog.node_id()]
  def neighbor_ids(graph, id)

  @doc """
  Returns `true` if an edge exists from `src` to `dst`.
  """
  @spec has_edge?(t(), Yog.node_id(), Yog.node_id()) :: boolean()
  def has_edge?(graph, src, dst)

  @doc """
  Returns the weight/data associated with an edge, or `nil` if the edge doesn't exist.
  """
  @spec edge_data(t(), Yog.node_id(), Yog.node_id()) :: any() | nil
  def edge_data(graph, src, dst)

  @doc """
  Returns all edges as a list of `{from, to, weight}` tuples.
  """
  @spec all_edges(t()) :: [{Yog.node_id(), Yog.node_id(), any()}]
  def all_edges(graph)

  # =============================================================================
  # Degree Queries
  # =============================================================================

  @doc """
  Returns the out-degree (number of outgoing edges) of a node.
  """
  @spec out_degree(t(), Yog.node_id()) :: non_neg_integer()
  def out_degree(graph, id)

  @doc """
  Returns the in-degree (number of incoming edges) of a node.
  """
  @spec in_degree(t(), Yog.node_id()) :: non_neg_integer()
  def in_degree(graph, id)

  @doc """
  Returns the total degree of a node.

  For undirected graphs, this is the number of adjacent edges (self-loops count as 2).
  For directed graphs, this is `in_degree + out_degree`.
  """
  @spec degree(t(), Yog.node_id()) :: non_neg_integer()
  def degree(graph, id)
end
