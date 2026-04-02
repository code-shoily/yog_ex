defmodule Yog.DAG do
  @moduledoc """
  Directed Acyclic Graph (DAG) data structure.

  A DAG is a wrapper around a `Yog.Graph` that guarantees acyclicity at the type level.
  This enables total functions (functions that always succeed) for operations like
  topological sorting that would be partial for general graphs.

  ## Examples

      iex> graph = Yog.Graph.new(:directed)
      iex> {:ok, dag} = Yog.DAG.from_graph(graph)
      iex> is_struct(dag, Yog.DAG.Graph)
      true

  ## Protocols

  `Yog.DAG.Graph` implements core graph protocols like `Yog.Queryable`, 
  `Yog.Modifiable`, `Enumerable`, and `Inspect`.
  """

  alias Yog.DAG.Graph
  alias Yog.DAG.Model

  @type t :: Graph.t()

  @doc """
  Creates a new empty DAG.
  """
  @spec new() :: t()
  def new, do: Model.new(:directed)

  @doc """
  Attempts to create a DAG from a graph.

  Validates that the graph is directed and contains no cycles.
  """
  @spec from_graph(Yog.Graph.t()) :: {:ok, t()} | {:error, :cycle_detected}
  defdelegate from_graph(graph), to: Model

  @doc """
  Unwraps a DAG back into a regular Graph.
  """
  @spec to_graph(dag :: t()) :: Yog.Graph.t()
  defdelegate to_graph(dag), to: Model

  # ============= Modification =============

  @doc "Adds a node to the DAG."
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  defdelegate add_node(dag, id, data), to: Model

  @doc "Removes a node and all its connected edges from the DAG."
  @spec remove_node(t(), Yog.node_id()) :: t()
  defdelegate remove_node(dag, id), to: Model

  @doc "Adds an edge to the DAG, validating for cycles."
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) ::
          {:ok, t()} | {:error, :cycle_detected | term()}
  defdelegate add_edge(dag, from, to, weight), to: Model

  @doc "Removes an edge from the DAG."
  @spec remove_edge(t(), Yog.node_id(), Yog.node_id()) :: t()
  defdelegate remove_edge(dag, from, to), to: Model

  # ============= Algorithms =============

  @doc "Returns a topological ordering of all nodes in the DAG."
  defdelegate topological_sort(dag), to: Yog.DAG.Algorithm

  @doc "Finds the longest path (critical path) in a weighted DAG."
  defdelegate longest_path(dag), to: Yog.DAG.Algorithm

  @doc "Finds the shortest path between two nodes in a weighted DAG."
  defdelegate shortest_path(dag, from, to), to: Yog.DAG.Algorithm

  @doc "Finds the lowest common ancestors (LCAs) of two nodes."
  defdelegate lowest_common_ancestors(dag, node_a, node_b), to: Yog.DAG.Algorithm
end
