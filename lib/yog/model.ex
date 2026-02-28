defmodule Yog.Model do
  @moduledoc """
  Core graph data structure and basic operations.

  Many of these operations are also available via the main `Yog` module.
  """

  @type graph :: Yog.graph()
  @type node_id :: Yog.node_id()
  @type graph_type :: Yog.graph_type()

  @doc """
  Creates a new empty graph of the specified type.
  """
  @spec new(graph_type()) :: graph()
  defdelegate new(graph_type), to: :yog@model

  @doc """
  Adds a node to the graph with the given ID and data.
  """
  @spec add_node(graph(), node_id(), term()) :: graph()
  defdelegate add_node(graph, id, data), to: :yog@model

  @doc """
  Adds an edge to the graph with the given weight.
  """
  @spec add_edge(graph(), node_id(), node_id(), term()) :: graph()
  defdelegate add_edge(graph, from, to, weight), to: :yog@model

  @doc """
  Gets nodes you can travel TO from the given node (successors).
  """
  @spec successors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate successors(graph, id), to: :yog@model

  @doc """
  Gets nodes you came FROM to reach the given node (predecessors).
  """
  @spec predecessors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate predecessors(graph, id), to: :yog@model

  @doc """
  Gets all nodes connected to the given node, regardless of direction.
  """
  @spec neighbors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate neighbors(graph, id), to: :yog@model

  @doc """
  Returns all unique node IDs that have edges in the graph.
  """
  @spec all_nodes(graph()) :: [node_id()]
  defdelegate all_nodes(graph), to: :yog@model

  @doc """
  Returns the number of nodes in the graph (graph order).
  """
  @spec order(graph()) :: integer()
  defdelegate order(graph), to: :yog@model

  @doc """
  Returns just the NodeIds of successors (without edge weights).
  """
  @spec successor_ids(graph(), node_id()) :: [node_id()]
  defdelegate successor_ids(graph, id), to: :yog@model

  @doc """
  Removes a node and all its connected edges (incoming and outgoing).
  """
  @spec remove_node(graph(), node_id()) :: graph()
  defdelegate remove_node(graph, id), to: :yog@model

  @doc """
  Adds an edge, but if an edge already exists between `src` and `dst`,
  it combines the new weight with the existing one using `with_combine`.
  """
  @spec add_edge_with_combine(graph(), node_id(), node_id(), term(), (term(), term() -> term())) ::
          graph()
  defdelegate add_edge_with_combine(graph, src, dst, weight, with_combine), to: :yog@model
end
