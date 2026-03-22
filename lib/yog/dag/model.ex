defmodule Yog.DAG.Model do
  @moduledoc """
  Core DAG type and basic operations.

  This module provides the opaque `Yog.DAG` type that wraps a regular graph
  and guarantees acyclicity at the type level.
  """

  alias Yog.Property.Cyclicity

  @typedoc """
  An opaque wrapper around a `Graph` that guarantees acyclicity at the type level.

  Unlike a regular `Graph`, a `DAG` is statically proven to contain no cycles,
  enabling total functions for operations like topological sorting.
  """
  @type t :: {:dag, Yog.graph()}

  @typedoc "Error type representing why a graph cannot be treated as a DAG."
  @type error :: :cycle_detected

  @doc """
  Creates a new, empty DAG.
  """
  @spec new(Yog.graph_type()) :: t()
  def new(type) do
    {:dag, Yog.new(type)}
  end

  @doc """
  Attempts to create a `DAG` from a regular `Graph`.

  Validates that the graph contains no cycles. If validation passes, returns
  `{:ok, dag}`; otherwise returns `{:error, :cycle_detected}`.

  ## Time Complexity

  O(V + E)
  """
  @spec from_graph(Yog.graph()) :: {:ok, t()} | {:error, :cycle_detected}
  def from_graph(graph) do
    if Cyclicity.acyclic?(graph) do
      {:ok, {:dag, graph}}
    else
      {:error, :cycle_detected}
    end
  end

  @doc """
  Unwraps a `DAG` back into a regular `Graph`.

  This is useful when you need to use operations that work on any graph type,
  or when you want to export the DAG to formats that accept general graphs.
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph({:dag, graph}), do: graph

  @doc """
  Adds a node to the DAG.

  Adding a node cannot create a cycle, so this operation is infallible.

  ## Time Complexity

  O(1)
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node({:dag, graph}, id, data) do
    {:dag, Yog.add_node(graph, id, data)}
  end

  @doc """
  Removes a node and all its connected edges from the DAG.

  Removing nodes/edges cannot create a cycle, so this operation is infallible.

  ## Time Complexity

  O(V + E) in the worst case (removing all edges of the node).
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  def remove_node({:dag, graph}, id) do
    {:dag, :yog@model.remove_node(graph, id)}
  end

  @doc """
  Removes an edge from the DAG.

  Removing edges cannot create a cycle, so this operation is infallible.

  ## Time Complexity

  O(1)
  """
  @spec remove_edge(t(), Yog.node_id(), Yog.node_id()) :: t()
  def remove_edge({:dag, graph}, from, to) do
    {:dag, :yog@model.remove_edge(graph, from, to)}
  end

  @doc """
  Adds an edge to the DAG.

  Because adding an edge can potentially create a cycle, this operation must
  validate the resulting graph and returns a Result type.

  ## Time Complexity

  O(V + E) (due to required cycle check on insertion).
  """
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def add_edge({:dag, graph}, from, to, weight) do
    # add_edge! returns the graph directly (or raises on error like missing node)
    new_graph = Yog.add_edge!(graph, from, to, weight)

    if Cyclicity.acyclic?(new_graph) do
      {:ok, {:dag, new_graph}}
    else
      {:error, :cycle_detected}
    end
  end
end
