defmodule Yog.DAG.Model do
  @moduledoc """
  Core Directed Acyclic Graph (DAG) type and basic operations.

  This module provides the `Yog.DAG` struct that wraps a regular directed `Yog.Graph`
  and guarantees acyclicity at the type level. Unlike a general graph, a DAG allows
  for specialized algorithms like topological sorting and critical path analysis
  to be total functions.

  ## Design Goals

  - **Safety**: Ensure acyclicity at creation and during all edge insertions.
  - **Efficiency**: Use targeted path checks for O(V+E) validation on insertion.
  - **Interoperability**: Easy conversion to and from regular `Yog.Graph` structures.

  ## Example

      iex> dag = Yog.DAG.Model.new(:directed)
      iex> {:ok, dag} = Yog.DAG.Model.add_edge(dag, 1, 2, "depends")
      iex> Yog.DAG.Model.add_edge(dag, 2, 1, "cycle")
      {:error, :cycle_detected}
  """

  alias Yog.DAG
  alias Yog.Property.Cyclicity

  @typedoc """
  An opaque wrapper around a `Graph` that guarantees acyclicity at the type level.

  Unlike a regular `Graph`, a `DAG` is statically proven to contain no cycles,
  enabling total functions for operations like topological sorting.
  """
  @type t :: %DAG{graph: Yog.Graph.t()}

  @typedoc "Error type representing why a graph cannot be treated as a DAG."
  @type error :: :cycle_detected

  @doc """
  Creates a new, empty DAG. Only `:directed` graphs are supported.

  ## Example

      iex> dag = Yog.DAG.Model.new(:directed)
      iex> Yog.Graph.node_count(Yog.DAG.Model.to_graph(dag))
      0
  """
  @spec new(Yog.Model.graph_type()) :: t()
  def new(:directed) do
    %DAG{graph: Yog.Graph.new(:directed)}
  end

  def new(:undirected) do
    raise ArgumentError, "DAG must be directed; received :undirected"
  end

  @doc """
  Creates a DAG from a list of edges.

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_edges([{1, 2}, {2, 3}])
      iex> Yog.DAG.Model.to_graph(dag) |> Yog.Model.has_edge?(1, 2)
      true
  """
  @spec from_edges([{Yog.node_id(), Yog.node_id()} | {Yog.node_id(), Yog.node_id(), any()}]) ::
          {:ok, t()} | {:error, :cycle_detected}
  def from_edges(edges) do
    edges
    |> Enum.reduce(Yog.Graph.new(:directed), fn
      {from, to}, g -> Yog.add_edge_ensure(g, from, to, 1)
      {from, to, weight}, g -> Yog.add_edge_ensure(g, from, to, weight)
    end)
    |> from_graph()
  end

  @doc """
  Creates a DAG from a list of edges with a default weight.

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_edges([{1, 2}, {2, 3}], 10)
      iex> Yog.DAG.Model.to_graph(dag) |> Yog.Model.edge_data(1, 2)
      10
  """
  @spec from_edges([{Yog.node_id(), Yog.node_id()}], any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def from_edges(edges, default_weight) do
    edges
    |> Enum.reduce(Yog.Graph.new(:directed), fn {from, to}, g ->
      Yog.add_edge_ensure(g, from, to, default_weight)
    end)
    |> from_graph()
  end

  @doc """
  Attempts to create a `DAG` from a regular `Graph`.

  Validates that the graph contains no cycles. If validation passes, returns
  `{:ok, dag}`; otherwise returns `{:error, :cycle_detected}`.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.from_unweighted_edges(:directed, [{1, 2}, {2, 3}])
      iex> {:ok, dag} = Yog.DAG.Model.from_graph(graph)
      iex> Yog.DAG.Model.to_graph(dag) == graph
      true

      iex> graph = Yog.from_unweighted_edges(:directed, [{1, 2}, {2, 1}])
      iex> Yog.DAG.Model.from_graph(graph)
      {:error, :cycle_detected}
  """
  @spec from_graph(Yog.graph()) :: {:ok, t()} | {:error, :cycle_detected}
  def from_graph(%Yog.Graph{kind: :undirected}) do
    {:error, :cycle_detected}
  end

  def from_graph(%Yog.Graph{} = graph) do
    if Cyclicity.acyclic?(graph) do
      {:ok, %DAG{graph: graph}}
    else
      {:error, :cycle_detected}
    end
  end

  @doc """
  Unwraps a `DAG` back into a regular `Graph`.

  This is useful when you need to use operations that work on any graph type,
  or when you want to export the DAG to formats that accept general graphs.

  ## Example

      iex> dag = Yog.DAG.Model.new(:directed)
      iex> graph = Yog.DAG.Model.to_graph(dag)
      iex> Yog.graph?(graph)
      true
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph(%DAG{graph: graph}), do: graph

  @doc """
  Adds a node to the DAG.

  Adding a node cannot create a cycle, so this operation is infallible.

  **Time Complexity:** O(1)

  ## Example

      iex> dag = Yog.DAG.Model.new(:directed) |> Yog.DAG.Model.add_node(1, "A")
      iex> Yog.DAG.Model.to_graph(dag) |> Yog.node(1)
      "A"
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node(%DAG{graph: graph}, id, data) do
    %DAG{graph: Yog.Model.add_node(graph, id, data)}
  end

  @doc """
  Removes a node and all its connected edges from the DAG.

  Removing nodes/edges cannot create a cycle, so this operation is infallible.

  **Time Complexity:** O(deg(v)) - proportional to the number of edges
  connected to the node.

  ## Example

      iex> dag = Yog.DAG.Model.new(:directed) |> Yog.DAG.Model.add_node(1, "A")
      iex> dag = Yog.DAG.Model.remove_node(dag, 1)
      iex> Yog.DAG.Model.to_graph(dag) |> Yog.has_node?(1)
      false
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  def remove_node(%DAG{graph: graph}, id) do
    %DAG{graph: Yog.Model.remove_node(graph, id)}
  end

  @doc """
  Removes an edge from the DAG.

  Removing edges cannot create a cycle, so this operation is infallible.

  **Time Complexity:** O(1)

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.new(:directed) |> Yog.DAG.Model.add_edge(1, 2, 10)
      iex> dag = Yog.DAG.Model.remove_edge(dag, 1, 2)
      iex> Yog.DAG.Model.to_graph(dag) |> Yog.has_edge?(1, 2)
      false
  """
  @spec remove_edge(t(), Yog.node_id(), Yog.node_id()) :: t()
  def remove_edge(%DAG{graph: graph}, from, to) do
    %DAG{graph: Yog.Model.remove_edge(graph, from, to)}
  end

  @doc """
  Adds an edge to the DAG.

  Because adding an edge can potentially create a cycle, this operation must
  validate the resulting graph. Returns `{:ok, dag}` if no cycle is created,
  and `{:error, :cycle_detected}` otherwise.

  **Time Complexity:** O(V + E) (due to required cycle check on insertion).

  ## Example

      iex> dag = Yog.DAG.Model.new(:directed)
      iex> {:ok, dag} = Yog.DAG.Model.add_edge(dag, 1, 2, 10)
      iex> Yog.DAG.Model.add_edge(dag, 2, 1, 5)
      {:error, :cycle_detected}
  """
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def add_edge(%DAG{graph: graph}, from, to, weight) do
    # An edge from A to B creates a cycle ONLY if there's already a path from B to A.
    # We use a targeted BFS (reachable?) which terminates early to avoid full O(V+E)
    # Kahn's topological sort checking per edge.
    if Yog.Traversal.reachable?(graph, to, from) do
      {:error, :cycle_detected}
    else
      new_graph = Yog.Model.add_edge_ensure(graph, from, to, weight)
      {:ok, %DAG{graph: new_graph}}
    end
  end
end
