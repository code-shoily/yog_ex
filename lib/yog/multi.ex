defmodule Yog.Multi do
  @moduledoc """
  Unified facade for multigraph operations.

  Multigraphs allow multiple (parallel) edges between the same pair of nodes.
  This module provides creation, modification, traversal, and algorithmic
  analysis for multigraphs by delegating to specialized submodules.
  """

  alias Yog.Multi.{Eulerian, Model, Traversal}

  # ============= Creation =============

  @doc "Creates a new empty multigraph of the given type."
  defdelegate new(kind), to: Model

  @doc "Creates a new empty directed multigraph."
  defdelegate directed(), to: Model

  @doc "Creates a new empty undirected multigraph."
  defdelegate undirected(), to: Model

  # ============= Modification =============

  @doc "Adds a node to the multigraph."
  defdelegate add_node(graph, id, data), to: Model

  @doc "Removes a node and all edges connected to it."
  defdelegate remove_node(graph, id), to: Model

  @doc "Adds an edge to the multigraph, returning {updated_graph, edge_id}."
  defdelegate add_edge(graph, from, to, data), to: Model

  @doc "Removes a single edge by its EdgeId."
  defdelegate remove_edge(graph, edge_id), to: Model

  # ============= Query =============

  @doc "Returns all node IDs in the multigraph."
  defdelegate all_nodes(graph), to: Model

  @doc "Returns the number of nodes."
  defdelegate order(graph), to: Model

  @doc "Returns all edge IDs in the graph."
  defdelegate all_edge_ids(graph), to: Model

  @doc "Returns the total number of edges."
  defdelegate size(graph), to: Model

  @doc "Returns the out-degree of a node."
  defdelegate out_degree(graph, id), to: Model

  @doc "Returns the in-degree of a node."
  defdelegate in_degree(graph, id), to: Model

  @doc "Returns all parallel edges between from and to as [{edge_id, data}]."
  defdelegate edges_between(graph, from, to), to: Model

  @doc "Returns all outgoing edges from id as [{to_node, edge_id, data}]."
  defdelegate successors(graph, id), to: Model

  @doc "Returns all incoming edges to id as [{from_node, edge_id, data}]."
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

  # ============= Conversion =============

  @doc "Collapses the multigraph into a simple graph using a combining function."
  defdelegate to_simple_graph(graph, combine_fn), to: Model
end
