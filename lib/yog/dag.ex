defmodule Yog.DAG do
  @moduledoc """
  Directed Acyclic Graph (DAG) data structure.

  A DAG is a wrapper around a `Yog.Graph` that guarantees acyclicity at the type level.
  This enables total functions (functions that always succeed) for operations like
  topological sorting that would be partial for general graphs.

  ## Example

      iex> graph = Yog.Graph.new(:directed)
      iex> {:ok, dag} = Yog.DAG.from_graph(graph)
      iex> is_struct(dag, Yog.DAG)
      true

  ## Protocols

  `Yog.DAG` implements the `Enumerable` and `Inspect` protocols:

  - **Enumerable**: Iterates over nodes as `{id, data}` tuples via the underlying graph
  - **Inspect**: Compact representation showing node and edge counts
  """
  alias Yog.DAG.Model

  @type t :: %__MODULE__{
          graph: Yog.Graph.t()
        }

  @enforce_keys [:graph]
  defstruct [:graph]

  @doc """
  Creates a new empty DAG.

  ## Example

      iex> dag = Yog.DAG.new()
      iex> Yog.Model.node_count(Yog.DAG.to_graph(dag))
      0
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

  ## Example

      iex> graph = Yog.from_unweighted_edges(:directed, [{1, 2}, {2, 3}])
      iex> {:ok, dag} = Yog.DAG.from_graph(graph)
      iex> Yog.DAG.to_graph(dag) == graph
      true

      iex> graph = Yog.from_unweighted_edges(:directed, [{1, 2}, {2, 1}])
      iex> Yog.DAG.from_graph(graph)
      {:error, :cycle_detected}
  """
  @spec from_graph(Yog.Graph.t()) :: {:ok, t()} | {:error, :cycle_detected}
  def from_graph(graph), do: Model.from_graph(graph)

  @doc """
  Unwraps a DAG back into a regular Graph.

  ## Example

      iex> dag = Yog.DAG.new()
      iex> graph = Yog.DAG.to_graph(dag)
      iex> Yog.graph?(graph)
      true
  """
  @spec to_graph(t()) :: Yog.Graph.t()
  def to_graph(%__MODULE__{graph: graph}), do: graph

  # ============================================================
  # Modification
  # ============================================================

  @doc """
  Adds a node to the DAG.

  ## Example

      iex> dag = Yog.DAG.new() |> Yog.DAG.add_node(1, "A")
      iex> Yog.DAG.to_graph(dag) |> Yog.node(1)
      "A"
  """
  defdelegate add_node(dag, id, data), to: Yog.DAG.Model

  @doc """
  Removes a node and all its connected edges from the DAG.

  ## Example

      iex> dag = Yog.DAG.new() |> Yog.DAG.add_node(1, "A")
      iex> dag = Yog.DAG.remove_node(dag, 1)
      iex> Yog.DAG.to_graph(dag) |> Yog.has_node?(1)
      false
  """
  defdelegate remove_node(dag, id), to: Yog.DAG.Model

  @doc """
  Adds an edge to the DAG, validating for cycles.

  ## Example

      iex> dag = Yog.DAG.new()
      iex> {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 10)
      iex> Yog.DAG.add_edge(dag, 2, 1, 5)
      {:error, :cycle_detected}
  """
  defdelegate add_edge(dag, from, to, weight), to: Yog.DAG.Model

  @doc """
  Removes an edge from the DAG.

  ## Example

      iex> {:ok, dag} = Yog.DAG.new() |> Yog.DAG.add_edge(1, 2, 10)
      iex> dag = Yog.DAG.remove_edge(dag, 1, 2)
      iex> Yog.DAG.to_graph(dag) |> Yog.has_edge?(1, 2)
      false
  """
  defdelegate remove_edge(dag, from, to), to: Yog.DAG.Model

  # ============================================================
  # Algorithms
  # ============================================================

  @doc """
  Returns a topological ordering of all nodes in the DAG.

  ## Example

      iex> {:ok, dag} = Yog.from_unweighted_edges(:directed, [{1, 2}, {2, 3}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.topological_sort(dag)
      [1, 2, 3]
  """
  defdelegate topological_sort(dag), to: Yog.DAG.Algorithm

  @doc """
  Finds the longest path (critical path) in a weighted DAG.

  ## Example

      iex> {:ok, dag} = Yog.from_edges(:directed, [{1, 2, 5}, {2, 3, 3}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.longest_path(dag)
      [1, 2, 3]
  """
  defdelegate longest_path(dag), to: Yog.DAG.Algorithm

  @doc """
  Returns the topological generations of a DAG.

  ## Example

      iex> {:ok, dag} = Yog.from_unweighted_edges(:directed, [{1, 2}, {1, 3}, {2, 4}, {3, 4}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.topological_generations(dag)
      [[1], [2, 3], [4]]
  """
  defdelegate topological_generations(dag), to: Yog.DAG.Algorithm

  @doc """
  Finds the shortest path between two nodes in a weighted DAG.

  ## Example

      iex> {:ok, dag} = Yog.from_edges(:directed, [{1, 2, 3}, {2, 3, 2}]) |> Yog.DAG.from_graph()
      iex> {:ok, path} = Yog.DAG.shortest_path(dag, 1, 3)
      iex> path.weight
      5
  """
  defdelegate shortest_path(dag, from, to), to: Yog.DAG.Algorithm

  @doc """
  Finds the lowest common ancestors (LCAs) of two nodes.

  ## Example

      iex> {:ok, dag} = Yog.from_unweighted_edges(:directed, [{1, 3}, {2, 3}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.lowest_common_ancestors(dag, 3, 3)
      [3]
  """
  defdelegate lowest_common_ancestors(dag, node_a, node_b), to: Yog.DAG.Algorithm
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
    node_count = Yog.Model.node_count(graph)
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
