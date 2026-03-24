defmodule Yog.DAG do
  @moduledoc """
  Directed Acyclic Graph (DAG) data structure.

  A DAG is a wrapper around a `Yog.Graph` that guarantees acyclicity at the type level.
  This enables total functions (functions that always succeed) for operations like
  topological sorting that would be partial for general graphs.

  ## Examples

      iex> graph = Yog.Graph.new(:directed)
      iex> {:ok, dag} = Yog.DAG.from_graph(graph)
      iex> is_struct(dag, Yog.DAG)
      true

  ## Protocols

  `Yog.DAG` implements the `Enumerable` and `Inspect` protocols:

  - **Enumerable**: Iterates over nodes as `{id, data}` tuples via the underlying graph
  - **Inspect**: Compact representation showing node and edge counts
  """
  alias Yog.Property.Cyclicity

  @type t :: %__MODULE__{
          graph: Yog.Graph.t()
        }

  @enforce_keys [:graph]
  defstruct [:graph]

  @doc """
  Creates a new empty DAG.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      graph: Yog.Graph.new(:directed)
    }
  end

  @doc """
  Attempts to create a DAG from a graph.

  Validates that the graph is directed and contains no cycles.
  """
  @spec from_graph(Yog.Graph.t()) :: {:ok, t()} | {:error, :cycle_detected}
  def from_graph(%Yog.Graph{kind: :undirected}) do
    {:error, :cycle_detected}
  end

  def from_graph(%Yog.Graph{} = graph) do
    if Cyclicity.acyclic?(graph) do
      {:ok, %__MODULE__{graph: graph}}
    else
      {:error, :cycle_detected}
    end
  end

  @doc """
  Unwraps a DAG back into a regular Graph.
  """
  @spec to_graph(t()) :: Yog.Graph.t()
  def to_graph(%__MODULE__{graph: graph}), do: graph
end

defimpl Enumerable, for: Yog.DAG do
  @moduledoc """
  Enumerable implementation for `Yog.DAG`.

  Iterates over nodes as `{id, data}` tuples via the underlying graph.

  ## Examples

      iex> {:ok, dag} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.DAG.from_graph()
      iex> Enum.to_list(dag)
      [{1, "A"}, {2, "B"}]

      iex> Enum.count(dag)
      2
  """

  def count(%Yog.DAG{graph: graph}) do
    Enumerable.count(graph)
  end

  def member?(%Yog.DAG{graph: graph}, element) do
    Enumerable.member?(graph, element)
  end

  def reduce(%Yog.DAG{graph: graph}, acc, fun) do
    Enumerable.reduce(graph, acc, fun)
  end

  def slice(%Yog.DAG{graph: graph}) do
    Enumerable.slice(graph)
  end
end

defimpl Inspect, for: Yog.DAG do
  @moduledoc """
  Inspect implementation for `Yog.DAG`.

  Provides a compact representation showing node and edge counts.

  ## Examples

      iex> {:ok, dag} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.DAG.from_graph()
      iex> inspect(dag)
      "#Yog.DAG<1 node, 0 edges>"
  """

  import Inspect.Algebra

  def inspect(%Yog.DAG{graph: graph}, _opts) do
    node_count = map_size(graph.nodes)
    edge_count = Yog.Graph.edge_count(graph)

    node_str = if node_count == 1, do: "node", else: "nodes"
    edge_str = if edge_count == 1, do: "edge", else: "edges"

    concat([
      "#Yog.DAG<",
      "#{node_count} #{node_str}, ",
      "#{edge_count} #{edge_str}",
      ">"
    ])
  end
end
