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

  Time complexity: $\\mathcal{O}(1)$

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

  Time complexity: $\\mathcal{O}(V + E)$

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
  Creates a DAG from a graph, raising `ArgumentError` if a cycle is detected.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec from_graph!(Yog.Graph.t()) :: t()
  def from_graph!(graph), do: Model.from_graph!(graph)

  @doc """
  Unwraps a DAG back into a regular Graph.

  Time complexity: $\\mathcal{O}(1)$

  ## Example

      iex> dag = Yog.DAG.new()
      iex> graph = Yog.DAG.to_graph(dag)
      iex> Yog.graph?(graph)
      true
  """
  @spec to_graph(t()) :: Yog.Graph.t()
  def to_graph(%__MODULE__{graph: graph}), do: graph
  def to_graph(dag), do: Model.to_graph(dag)

  # ============================================================
  # Construction Helpers
  # ============================================================

  @doc """
  Creates a DAG from a list of edges.

  Each edge is a tuple `{from, to}` or `{from, to, weight}`.
  Returns `{:ok, dag}` if the graph is acyclic, otherwise `{:error, :cycle_detected}`.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Examples

      iex> {:ok, dag} = Yog.DAG.from_edges([{:a, :b}, {:b, :c}])
      iex> Yog.DAG.topological_sort(dag)
      [:a, :b, :c]

      iex> Yog.DAG.from_edges([{:a, :b}, {:b, :a}])
      {:error, :cycle_detected}
  """
  @spec from_edges([{Yog.node_id(), Yog.node_id()} | {Yog.node_id(), Yog.node_id(), any()}]) ::
          {:ok, t()} | {:error, :cycle_detected}
  def from_edges(edges), do: Model.from_edges(edges)

  @doc """
  Creates a DAG from a list of edges with a default weight.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Examples

      iex> {:ok, dag} = Yog.DAG.from_edges([{:a, :b}, {:b, :c}], 10)
      iex> graph = Yog.DAG.to_graph(dag)
      iex> Yog.Model.edge_data(graph, :a, :b)
      10
  """
  @spec from_edges([{Yog.node_id(), Yog.node_id()}], any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def from_edges(edges, default_weight), do: Model.from_edges(edges, default_weight)

  @doc """
  Creates a DAG from a list of edges, raising `ArgumentError` if a cycle is detected.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec from_edges!(
          [{Yog.node_id(), Yog.node_id()} | {Yog.node_id(), Yog.node_id(), any()}],
          any()
        ) :: t()
  def from_edges!(edges, default_weight \\ 1), do: Model.from_edges!(edges, default_weight)

  # ============================================================
  # Query
  # ============================================================

  @doc """
  Checks if a node exists in the DAG.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec has_node?(t(), Yog.node_id()) :: boolean()
  def has_node?(%__MODULE__{graph: g}, id), do: Yog.Model.has_node?(g, id)

  def has_node?(dag, _id),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Checks if an edge exists in the DAG.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec has_edge?(t(), Yog.node_id(), Yog.node_id()) :: boolean()
  def has_edge?(%__MODULE__{graph: g}, from, to), do: Yog.Model.has_edge?(g, from, to)

  def has_edge?(dag, _from, _to),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns the number of nodes in the DAG.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec node_count(t()) :: integer()
  def node_count(%__MODULE__{graph: g}), do: Yog.Model.node_count(g)
  def node_count(dag), do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns the number of edges in the DAG.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec edge_count(t()) :: integer()
  def edge_count(%__MODULE__{graph: g}), do: Yog.Graph.edge_count(g)
  def edge_count(dag), do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns all node IDs in the DAG.

  Time complexity: $\\mathcal{O}(V)$
  """
  @spec nodes(t()) :: [Yog.node_id()]
  def nodes(%__MODULE__{graph: g}), do: Yog.Model.all_nodes(g)
  def nodes(dag), do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns all outgoing edges from a node as `[{to, weight}]`.

  Time complexity: $\\mathcal{O}(\\text{deg}_{\\text{out}}(v))$
  """
  @spec successors(t(), Yog.node_id()) :: [{Yog.node_id(), any()}]
  def successors(%__MODULE__{graph: g}, id), do: Yog.Model.successors(g, id)

  def successors(dag, _id),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns all incoming edges to a node as `[{from, weight}]`.

  Time complexity: $\\mathcal{O}(\\text{deg}_{\\text{in}}(v))$
  """
  @spec predecessors(t(), Yog.node_id()) :: [{Yog.node_id(), any()}]
  def predecessors(%__MODULE__{graph: g}, id), do: Yog.Model.predecessors(g, id)

  def predecessors(dag, _id),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns the in-degree of a node.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec in_degree(t(), Yog.node_id()) :: non_neg_integer()
  def in_degree(%__MODULE__{graph: g}, id), do: Yog.Model.in_degree(g, id)

  def in_degree(dag, _id),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Returns the out-degree of a node.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec out_degree(t(), Yog.node_id()) :: non_neg_integer()
  def out_degree(%__MODULE__{graph: g}, id), do: Yog.Model.out_degree(g, id)

  def out_degree(dag, _id),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  @doc """
  Checks if `from` can reach `to` in the DAG.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec reachable?(t(), Yog.node_id(), Yog.node_id()) :: boolean()
  def reachable?(%__MODULE__{graph: g}, from, to), do: Yog.Traversal.reachable?(g, from, to)

  def reachable?(dag, _from, _to),
    do: raise(ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}")

  # ============================================================
  # Modification
  # ============================================================

  @doc """
  Adds a node to the DAG.

  Time complexity: $\\mathcal{O}(1)$

  ## Example

      iex> dag = Yog.DAG.new() |> Yog.DAG.add_node(1, "A")
      iex> Yog.DAG.to_graph(dag) |> Yog.node(1)
      "A"
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node(dag, id, data \\ nil), do: Model.add_node(dag, id, data)

  @doc """
  Removes a node and all its connected edges from the DAG.

  Time complexity: $\\mathcal{O}(\\text{deg}(v))$

  ## Example

      iex> dag = Yog.DAG.new() |> Yog.DAG.add_node(1, "A")
      iex> dag = Yog.DAG.remove_node(dag, 1)
      iex> Yog.DAG.to_graph(dag) |> Yog.has_node?(1)
      false
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  defdelegate remove_node(dag, id), to: Yog.DAG.Model

  @doc """
  Adds an edge to the DAG, validating for cycles.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> dag = Yog.DAG.new()
      iex> {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 10)
      iex> Yog.DAG.add_edge(dag, 2, 1, 5)
      {:error, :cycle_detected}
  """
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def add_edge(dag, from, to, weight \\ 1), do: Model.add_edge(dag, from, to, weight)

  @doc """
  Same as `add_edge/4` but raises `ArgumentError` on cycle detection.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec add_edge!(t(), Yog.node_id(), Yog.node_id(), any()) :: t()
  def add_edge!(dag, from, to, weight \\ 1), do: Model.add_edge!(dag, from, to, weight)

  @doc """
  Adds multiple edges to the DAG sequentially, returning `{:ok, dag}` or `{:error, :cycle_detected}`.

  Time complexity: $\\mathcal{O}(E \\cdot (V + E))$
  """
  @spec add_edges(
          t(),
          [{Yog.node_id(), Yog.node_id()} | {Yog.node_id(), Yog.node_id(), any()}]
        ) ::
          {:ok, t()} | {:error, :cycle_detected}
  def add_edges(%__MODULE__{} = dag, edges) when is_list(edges) do
    Enum.reduce_while(edges, {:ok, dag}, fn
      {from, to}, {:ok, acc} ->
        case add_edge(acc, from, to, 1) do
          {:ok, new_dag} -> {:cont, {:ok, new_dag}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      {from, to, weight}, {:ok, acc} ->
        case add_edge(acc, from, to, weight) do
          {:ok, new_dag} -> {:cont, {:ok, new_dag}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  def add_edges(dag, _edges) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Same as `add_edges/2` but raises `ArgumentError` if any edge creates a cycle.

  Time complexity: $\\mathcal{O}(E \\cdot (V + E))$
  """
  @spec add_edges!(
          t(),
          [{Yog.node_id(), Yog.node_id()} | {Yog.node_id(), Yog.node_id(), any()}]
        ) ::
          t()
  def add_edges!(dag, edges) do
    case add_edges(dag, edges) do
      {:ok, new_dag} -> new_dag
      {:error, :cycle_detected} -> raise ArgumentError, "cycle detected while adding edges"
    end
  end

  @doc """
  Removes an edge from the DAG.

  Time complexity: $\\mathcal{O}(1)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.new() |> Yog.DAG.add_edge(1, 2, 10)
      iex> dag = Yog.DAG.remove_edge(dag, 1, 2)
      iex> Yog.DAG.to_graph(dag) |> Yog.has_edge?(1, 2)
      false
  """
  @spec remove_edge(t(), Yog.node_id(), Yog.node_id()) :: t()
  defdelegate remove_edge(dag, from, to), to: Yog.DAG.Model

  # ============================================================
  # Algorithms
  # ============================================================

  @doc """
  Returns a topological ordering of all nodes in the DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.from_unweighted_edges(:directed, [{1, 2}, {2, 3}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.topological_sort(dag)
      [1, 2, 3]
  """
  @spec topological_sort(t()) :: [Yog.node_id()]
  defdelegate topological_sort(dag), to: Yog.DAG.Algorithm

  @doc """
  Finds the longest path (critical path) in a weighted DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.from_edges(:directed, [{1, 2, 5}, {2, 3, 3}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.longest_path(dag)
      [1, 2, 3]
  """
  @spec longest_path(t()) :: [Yog.node_id()]
  defdelegate longest_path(dag), to: Yog.DAG.Algorithm

  @doc """
  Returns the topological generations of a DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.from_unweighted_edges(:directed, [{1, 2}, {1, 3}, {2, 4}, {3, 4}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.topological_generations(dag)
      [[1], [2, 3], [4]]
  """
  @spec topological_generations(dag :: t()) :: [[Yog.node_id()]]
  defdelegate topological_generations(dag), to: Yog.DAG.Algorithm

  @doc """
  Finds the shortest path between two nodes in a weighted DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.from_edges(:directed, [{1, 2, 3}, {2, 3, 2}]) |> Yog.DAG.from_graph()
      iex> {:ok, path} = Yog.DAG.shortest_path(dag, 1, 3)
      iex> path.weight
      5
  """
  @spec shortest_path(t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, Yog.Pathfinding.Path.t()} | :error
  defdelegate shortest_path(dag, from, to), to: Yog.DAG.Algorithm

  @doc """
  Finds the lowest common ancestors (LCAs) of two nodes.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.from_unweighted_edges(:directed, [{1, 3}, {2, 3}]) |> Yog.DAG.from_graph()
      iex> Yog.DAG.lowest_common_ancestors(dag, 3, 3)
      [3]
  """
  @spec lowest_common_ancestors(t(), Yog.node_id(), Yog.node_id()) :: [Yog.node_id()]
  defdelegate lowest_common_ancestors(dag, node_a, node_b), to: Yog.DAG.Algorithm

  @doc """
  Returns all source nodes (in-degree 0).

  Time complexity: $\\mathcal{O}(V)$
  """
  @spec sources(t()) :: [Yog.node_id()]
  defdelegate sources(dag), to: Yog.DAG.Algorithm

  @doc """
  Returns all sink nodes (out-degree 0).

  Time complexity: $\\mathcal{O}(V)$
  """
  @spec sinks(t()) :: [Yog.node_id()]
  defdelegate sinks(dag), to: Yog.DAG.Algorithm

  @doc """
  Returns all ancestors of a node (includes the node itself).

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec ancestors(t(), Yog.node_id()) :: [Yog.node_id()]
  defdelegate ancestors(dag, node), to: Yog.DAG.Algorithm

  @doc """
  Returns all descendants of a node (includes the node itself).

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec descendants(t(), Yog.node_id()) :: [Yog.node_id()]
  defdelegate descendants(dag, node), to: Yog.DAG.Algorithm

  @doc """
  Computes single-source shortest distances to all reachable nodes.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec single_source_distances(t(), Yog.node_id()) :: %{Yog.node_id() => number()}
  defdelegate single_source_distances(dag, from), to: Yog.DAG.Algorithm

  @doc """
  Finds the longest path between two specific nodes.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec longest_path(t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, Yog.Pathfinding.Path.t()} | :error
  defdelegate longest_path(dag, from, to), to: Yog.DAG.Algorithm

  @doc """
  Counts the number of distinct paths between two nodes.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec path_count(t(), Yog.node_id(), Yog.node_id()) :: non_neg_integer()
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
