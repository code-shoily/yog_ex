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
  # Construction Helpers
  # ============================================================

  @doc """
  Creates a DAG from a list of edges.

  Each edge is a tuple `{from, to}` or `{from, to, weight}`.
  Returns `{:ok, dag}` if the graph is acyclic, otherwise `{:error, :cycle_detected}`.

  ## Examples

      iex> {:ok, dag} = Yog.DAG.from_edges([{:a, :b}, {:b, :c}])
      iex> Yog.DAG.topological_sort(dag)
      [:a, :b, :c]

      iex> Yog.DAG.from_edges([{:a, :b}, {:b, :a}])
      {:error, :cycle_detected}
  """
  @spec from_edges([{Yog.node_id(), Yog.node_id()} | {Yog.node_id(), Yog.node_id(), any()}]) ::
          {:ok, t()} | {:error, :cycle_detected}
  def from_edges(edges) do
    Model.from_edges(edges)
  end

  @doc """
  Creates a DAG from a list of edges with a default weight.

  ## Examples

      iex> {:ok, dag} = Yog.DAG.from_edges([{:a, :b}, {:b, :c}], 10)
      iex> graph = Yog.DAG.to_graph(dag)
      iex> Yog.Model.edge_data(graph, :a, :b)
      10
  """
  @spec from_edges([{Yog.node_id(), Yog.node_id()}], any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def from_edges(edges, default_weight) do
    Model.from_edges(edges, default_weight)
  end

  # ============================================================
  # Query
  # ============================================================

  @doc "Checks if a node exists in the DAG."
  def has_node?(dag, id), do: Yog.Model.has_node?(dag.graph, id)

  @doc "Checks if an edge exists in the DAG."
  def has_edge?(dag, from, to), do: Yog.Model.has_edge?(dag.graph, from, to)

  @doc "Returns the number of nodes in the DAG."
  def node_count(dag), do: Yog.Model.node_count(dag.graph)

  @doc "Returns the number of edges in the DAG."
  def edge_count(dag), do: Yog.Graph.edge_count(dag.graph)

  @doc "Returns all node IDs in the DAG."
  def nodes(dag), do: Yog.Model.all_nodes(dag.graph)

  @doc "Returns all outgoing edges from a node as [{to, weight}]."
  def successors(dag, id), do: Yog.Model.successors(dag.graph, id)

  @doc "Returns all incoming edges to a node as [{from, weight}]."
  def predecessors(dag, id), do: Yog.Model.predecessors(dag.graph, id)

  @doc "Returns the in-degree of a node."
  def in_degree(dag, id), do: Yog.Model.in_degree(dag.graph, id)

  @doc "Returns the out-degree of a node."
  def out_degree(dag, id), do: Yog.Model.out_degree(dag.graph, id)

  @doc "Checks if `from` can reach `to` in the DAG."
  def reachable?(dag, from, to), do: Yog.Traversal.reachable?(dag.graph, from, to)

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

  @doc "Returns all source nodes (in-degree 0)."
  defdelegate sources(dag), to: Yog.DAG.Algorithm

  @doc "Returns all sink nodes (out-degree 0)."
  defdelegate sinks(dag), to: Yog.DAG.Algorithm

  @doc "Returns all ancestors of a node (includes the node itself)."
  defdelegate ancestors(dag, node), to: Yog.DAG.Algorithm

  @doc "Returns all descendants of a node (includes the node itself)."
  defdelegate descendants(dag, node), to: Yog.DAG.Algorithm

  @doc "Computes single-source shortest distances to all reachable nodes."
  defdelegate single_source_distances(dag, from), to: Yog.DAG.Algorithm

  @doc "Finds the longest path between two specific nodes."
  defdelegate longest_path(dag, from, to), to: Yog.DAG.Algorithm

  @doc "Counts the number of distinct paths between two nodes."
  defdelegate path_count(dag, from, to), to: Yog.DAG.Algorithm
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
