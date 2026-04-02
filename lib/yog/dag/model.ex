defmodule Yog.DAG.Model do
  @moduledoc """
  Core DAG type and basic operations.

  This module provides the `Yog.DAG` struct that wraps a regular graph
  and guarantees acyclicity at the type level.
  """

  alias Yog.Modifiable, as: Mutator
  alias Yog.Property.Cyclicity

  @typedoc """
  An opaque wrapper around a `Graph` that guarantees acyclicity at the type level.

  Unlike a regular `Graph`, a `DAG` is statically proven to contain no cycles,
  enabling total functions for operations like topological sorting.
  """
  @type t :: Yog.DAG.Graph.t()

  @typedoc "Error type representing why a graph cannot be treated as a DAG."
  @type error :: :cycle_detected

  @doc """
  Creates a new, empty DAG.
  """
  @spec new(:directed | :undirected) :: t()
  def new(_type) do
    %Yog.DAG.Graph{graph: Yog.Graph.new(:directed)}
  end

  @doc """
  Attempts to create a `DAG` from a regular `Graph`.

  Validates that the graph contains no cycles. If validation passes, returns
  `{:ok, dag}`; otherwise returns `{:error, :cycle_detected}`.

  ## Time Complexity

  O(V + E)
  """
  @spec from_graph(Yog.graph()) :: {:ok, t()} | {:error, :cycle_detected}
  def from_graph(%Yog.Graph{kind: :undirected}) do
    {:error, :cycle_detected}
  end

  def from_graph(%Yog.Graph{} = graph) do
    if Cyclicity.acyclic?(graph) do
      {:ok, %Yog.DAG.Graph{graph: graph}}
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
  def to_graph(%Yog.DAG.Graph{graph: graph}), do: graph

  @doc """
  Adds a node to the DAG.

  Adding a node cannot create a cycle, so this operation is infallible.

  ## Time Complexity

  O(1)
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node(%Yog.DAG.Graph{graph: graph}, id, data) do
    %Yog.DAG.Graph{graph: Mutator.add_node(graph, id, data)}
  end

  @doc """
  Removes a node and all its connected edges from the DAG.

  Removing nodes/edges cannot create a cycle, so this operation is infallible.

  ## Time Complexity

  O(V + E) in the worst case (removing all edges of the node).
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  def remove_node(%Yog.DAG.Graph{graph: graph}, id) do
    %Yog.DAG.Graph{graph: Mutator.remove_node(graph, id)}
  end

  @doc """
  Removes an edge from the DAG.

  Removing edges cannot create a cycle, so this operation is infallible.

  ## Time Complexity

  O(1)
  """
  @spec remove_edge(t(), Yog.node_id(), Yog.node_id()) :: t()
  def remove_edge(%Yog.DAG.Graph{graph: graph}, from, to) do
    %Yog.DAG.Graph{graph: Mutator.remove_edge(graph, from, to)}
  end

  @doc """
  Adds an edge to the DAG.

  Because adding an edge can potentially create a cycle, this operation must
  validate the resulting graph. Returns `{:ok, dag}` or `{:error, :cycle_detected}`.

  ## Time Complexity

  O(V + E) (due to required cycle check on insertion).
  """
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) ::
          {:ok, t()} | {:error, :cycle_detected | term()}
  def add_edge(%Yog.DAG.Graph{graph: graph}, from, to, weight) do
    case Mutator.add_edge(graph, from, to, weight) do
      {:ok, new_graph} ->
        if Cyclicity.acyclic?(new_graph) do
          {:ok, %Yog.DAG.Graph{graph: new_graph}}
        else
          {:error, :cycle_detected}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Adds multiple edges to the DAG, failing if any edge would create a cycle.
  """
  @spec add_edges(t(), [Yog.edge_tuple()]) :: {:ok, t()} | {:error, term()}
  def add_edges(dag, edges) do
    Enum.reduce_while(edges, {:ok, dag}, fn {from, to, weight}, {:ok, d} ->
      case add_edge(d, from, to, weight) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Adds multiple simple edges (weight = 1).
  """
  @spec add_simple_edges(t(), [{Yog.node_id(), Yog.node_id()}]) :: {:ok, t()} | {:error, term()}
  def add_simple_edges(dag, edges) do
    triplets = Enum.map(edges, fn {src, dst} -> {src, dst, 1} end)
    add_edges(dag, triplets)
  end

  @doc """
  Adds multiple unweighted edges (weight = nil).
  """
  @spec add_unweighted_edges(t(), [{Yog.node_id(), Yog.node_id()}]) ::
          {:ok, t()} | {:error, term()}
  def add_unweighted_edges(dag, edges) do
    triplets = Enum.map(edges, fn {src, dst} -> {src, dst, nil} end)
    add_edges(dag, triplets)
  end

  @doc """
  Ensures nodes exist then adds an edge.
  Returns updated DAG or raises if a cycle is created.
  (Protocol Modifiable says "never fails", but DAG must maintain invariant)
  """
  def add_edge_ensure(dag, from, to, weight, default) do
    new_graph =
      dag.graph
      |> Yog.Model.add_edge_ensure(from, to, weight, default)

    if Cyclicity.acyclic?(new_graph) do
      %Yog.DAG.Graph{graph: new_graph}
    else
      raise "Adding edge {#{from}, #{to}} would create a cycle in DAG"
    end
  end

  @doc """
  Ensures nodes exist using keyword options.
  """
  def add_edge_ensure(dag, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    default = Keyword.get(opts, :default)
    add_edge_ensure(dag, from, to, weight, default)
  end

  @doc """
  Ensures nodes exist with data generator then adds an edge.
  """
  def add_edge_with(dag, from, to, weight, make_fn) do
    new_graph =
      dag.graph
      |> Yog.Model.add_edge_with(from, to, weight, make_fn)

    if Cyclicity.acyclic?(new_graph) do
      %Yog.DAG.Graph{graph: new_graph}
    else
      raise "Adding edge {#{from}, #{to}} would create a cycle in DAG"
    end
  end
end
