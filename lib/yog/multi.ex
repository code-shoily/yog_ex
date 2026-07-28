defmodule Yog.Multi do
  @moduledoc """
  Unified facade for multigraph operations.

  A multigraph allows multiple (parallel) edges between the same pair of nodes.
  This module provides creation, modification, query, traversal, conversion, and algorithmic
  analysis for multigraphs by delegating to specialized submodules (`Yog.Multi.Model`,
  `Yog.Multi.Traversal`, `Yog.Multi.Eulerian`).

  ## Multigraph Representation & Edge IDs

  Unlike simple graphs where edges are uniquely identified by their `{from, to}` endpoints,
  multigraph edges are assigned unique sequential non-negative integer `EdgeId` identifiers
  starting from `0`.

  Adding an edge via `add_edge/4` returns a `{updated_graph, edge_id}` tuple:

      iex> multi = Yog.Multi.directed()
      iex> {multi, e1} = Yog.Multi.add_edge(multi, :a, :b, "route 1")
      iex> {multi, e2} = Yog.Multi.add_edge(multi, :a, :b, "route 2")
      iex> Yog.Multi.edge_count(multi, :a, :b)
      2
      iex> e1 != e2
      true

  ## Collapsing to Simple Graphs

  Multigraphs can be collapsed into simple `Yog.Graph` structures using `to_simple_graph/1`,
  `to_simple_graph/2`, `to_simple_graph_min_edges/1`, `to_simple_graph_max_edges/1`, or
  `to_simple_graph_sum_edges/1`.

  ## Directed vs Undirected Multigraphs

  - **Directed**: Edges have a specific direction (`from` -> `to`). In-degree and out-degree are separate.
  - **Undirected**: Edges operate bidirectionally. Incident self-loops contribute 2 to node degree.
  """

  alias Yog.Multi.{Eulerian, Model, Traversal}
  alias Yog.Property.Cyclicity
  alias Yog.Traversal.Sort

  @type graph :: Model.t()
  @type edge_id :: Model.edge_id()

  # ============= Creation =============

  @doc "Creates a new empty multigraph of the given type (`:directed` or `:undirected`)."
  defdelegate new(kind), to: Model

  @doc "Creates a new empty directed multigraph."
  defdelegate directed(), to: Model

  @doc "Creates a new empty undirected multigraph."
  defdelegate undirected(), to: Model

  @doc "Returns the type of the multigraph (`:directed` or `:undirected`)."
  defdelegate type(graph), to: Model

  @doc "Synonym for `type/1`."
  defdelegate kind(graph), to: Model

  # ============= Modification =============

  @doc "Adds a node to the multigraph with optional custom payload."
  defdelegate add_node(graph, id, data \\ nil), to: Model

  @doc "Removes a node and all incident edges connected to it."
  defdelegate remove_node(graph, id), to: Model

  @doc "Adds an edge to the multigraph, returning `{updated_graph, edge_id}`."
  defdelegate add_edge(graph, from, to, data), to: Model

  @doc "Removes a single edge by its `EdgeId`."
  defdelegate remove_edge(graph, edge_id), to: Model

  # ============= Query =============

  @doc "Checks if a node ID exists in the multigraph."
  defdelegate has_node?(graph, id), to: Model

  @doc "Returns data associated with a node, or `nil` if not found."
  defdelegate node(graph, id), to: Model

  @doc "Fetches node data for a given node ID as `{:ok, data}` or `:error`."
  defdelegate fetch_node(graph, id), to: Model

  @doc "Synonym for `node/2`."
  defdelegate node_data(graph, id), to: Model

  @doc "Returns all node IDs in the multigraph."
  defdelegate all_nodes(graph), to: Model

  @doc "Returns the number of nodes (order) in the multigraph."
  defdelegate order(graph), to: Model

  @doc "Synonym for `order/1`."
  defdelegate node_count(graph), to: Model

  @doc "Returns all edge IDs in the graph."
  defdelegate all_edge_ids(graph), to: Model

  @doc "Returns all edges as `[{edge_id, from, to, data}]` sorted by `edge_id`."
  defdelegate all_edges(graph), to: Model

  @doc "Returns the total number of physical edges (size) in the multigraph."
  defdelegate size(graph), to: Model

  @doc "Synonym for `size/1`."
  defdelegate edge_count(graph), to: Model

  @doc "Returns the out-degree of a node."
  defdelegate out_degree(graph, id), to: Model

  @doc "Returns the in-degree of a node."
  defdelegate in_degree(graph, id), to: Model

  @doc "Returns the total degree of a node."
  defdelegate degree(graph, id), to: Model

  @doc "Checks if a specific `EdgeId` exists in the multigraph."
  defdelegate has_edge(graph, edge_id), to: Model

  @doc "Predicate synonym for `has_edge/2`."
  defdelegate has_edge?(graph, edge_id), to: Model

  @doc "Fetches details for an `EdgeId` as `{:ok, {from, to, data}}` or `:error`."
  defdelegate fetch_edge(graph, edge_id), to: Model

  @doc "Returns `{from, to, data}` for an `EdgeId`, or `nil` if not found."
  defdelegate edge(graph, edge_id), to: Model

  @doc "Returns edge data payload for an `EdgeId`, or `nil` if not found."
  defdelegate edge_data(graph, edge_id), to: Model

  @doc "Checks if at least one edge exists between `from` and `to`."
  defdelegate has_edge_between?(graph, from, to), to: Model

  @doc "Synonym for `has_edge_between?/3`."
  defdelegate has_edge_between(graph, from, to), to: Model

  @doc "Returns the number of parallel edges between `from` and `to`."
  defdelegate edge_count(graph, from, to), to: Model

  @doc "Returns all parallel edges between `from` and `to` as `[{edge_id, data}]`."
  defdelegate edges_between(graph, from, to), to: Model

  @doc "Returns all outgoing edges from `id` as `[{to_node, edge_id, data}]`."
  defdelegate successors(graph, id), to: Model

  @doc "Returns all incoming edges to `id` as `[{from_node, edge_id, data}]`."
  defdelegate predecessors(graph, id), to: Model

  # ============= Traversal =============

  @doc "Performs a Breadth-First Search from source."
  defdelegate bfs(graph, source), to: Traversal

  @doc "Performs a Depth-First Search from source."
  defdelegate dfs(graph, source), to: Traversal

  @doc "Folds over nodes during multigraph traversal with metadata."
  defdelegate fold_walk(graph, from, initial, folder), to: Traversal

  # ============= Eulerian =============

  @doc "Checks if the multigraph has an Eulerian circuit."
  defdelegate has_eulerian_circuit?(graph), to: Eulerian

  @doc "Checks if the multigraph has an Eulerian path."
  defdelegate has_eulerian_path?(graph), to: Eulerian

  @doc "Finds an Eulerian circuit using Hierholzer's algorithm."
  defdelegate find_eulerian_circuit(graph), to: Eulerian

  @doc "Finds an Eulerian path using Hierholzer's algorithm."
  defdelegate find_eulerian_path(graph), to: Eulerian

  # ============= Algorithms =============

  @doc """
  Checks if the multigraph contains at least one cycle.

  Collapses parallel edges internally before checking.
  """
  @spec has_cycle?(graph()) :: boolean()
  def has_cycle?(graph) do
    graph |> Model.to_simple_graph() |> Cyclicity.cyclic?()
  end

  @doc """
  Returns a topological ordering of nodes (directed multigraphs only).

  Collapses parallel edges internally, then applies Kahn's algorithm.
  Returns `{:ok, [node_id]}` or `{:error, :contains_cycle}`.
  """
  @spec topological_sort(graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    graph |> Model.to_simple_graph() |> Sort.topological_sort()
  end

  # ============= Conversion =============

  @doc "Collapses the multigraph into a simple graph, keeping the earliest edge between each pair."
  defdelegate to_simple_graph(graph), to: Model

  @doc "Collapses the multigraph into a simple graph using a combining function."
  defdelegate to_simple_graph(graph, combine_fn), to: Model

  @doc "Collapses parallel edges, keeping the minimum weight."
  defdelegate to_simple_graph_min_edges(graph), to: Model

  @doc "Collapses parallel edges, keeping the maximum weight."
  defdelegate to_simple_graph_max_edges(graph), to: Model

  @doc "Collapses parallel edges, summing weights."
  defdelegate to_simple_graph_sum_edges(graph), to: Model

  @doc "Collapses parallel edges, combining weights with the provided function."
  defdelegate to_simple_graph_sum_edges(graph, add), to: Model
end
