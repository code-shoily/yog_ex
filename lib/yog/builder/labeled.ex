defmodule Yog.Builder.Labeled do
  @moduledoc """
  Build graphs using arbitrary labels instead of integer IDs.

  This module provides a convenient way to build graphs when your nodes are
  naturally identified by strings, atoms, or other types, rather than integers.

  ## Example Usage

      # Build a graph with string labels
      builder = Yog.Builder.Labeled.directed()
        |> Yog.Builder.Labeled.add_edge("home", "work", 10)
        |> Yog.Builder.Labeled.add_edge("work", "gym", 5)

      # Convert to a Graph to use with algorithms
      graph = Yog.Builder.Labeled.to_graph(builder)

      # Get the node ID for a label
      {:ok, home_id} = Yog.Builder.Labeled.get_id(builder, "home")

      # Use with pathfinding
      case Yog.Pathfinding.Dijkstra.shortest_path(
        in: graph,
        from: home_id,
        to: gym_id,
        zero: 0,
        add: &Kernel.+/2,
        compare: &Integer.compare/2
      ) do
        {:ok, path} -> path
        _ -> :no_path
      end

  ## Batch Construction

  For building from existing data, use the `from_list` functions:

      edges = [{"A", "B", 5}, {"B", "C", 3}, {"A", "C", 10}]
      builder = Yog.Builder.Labeled.from_list(:directed, edges)
      graph = Yog.Builder.Labeled.to_graph(builder)

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.Model

  @enforce_keys [:graph]
  defstruct [:kind, :graph, label_to_id: %{}, next_id: 0]

  @typedoc "Labeled builder struct"
  @type t :: %__MODULE__{
          kind: Model.graph_type(),
          graph: Yog.graph(),
          label_to_id: %{label() => Yog.node_id()},
          next_id: integer()
        }

  @typedoc "Any type can be used as a label"
  @type label :: term()

  # ============= Constructors =============

  @doc """
  Creates a new labeled directed graph builder.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      iex> is_struct(builder, Yog.Builder.Labeled)
      true
  """
  @spec directed() :: t()
  def directed, do: new(:directed)

  @doc """
  Creates a new labeled undirected graph builder.

  ## Examples

      iex> builder = Yog.Builder.Labeled.undirected()
      iex> is_struct(builder, Yog.Builder.Labeled)
      true
  """
  @spec undirected() :: t()
  def undirected, do: new(:undirected)

  @doc """
  Creates a new labeled graph builder of the specified type.

  ## Examples

      iex> builder = Yog.Builder.Labeled.new(:directed)
      iex> is_struct(builder, Yog.Builder.Labeled)
      true
  """
  @spec new(Model.graph_type()) :: t()
  def new(graph_type) do
    %__MODULE__{
      kind: graph_type,
      graph: Model.new(graph_type),
      label_to_id: %{},
      next_id: 0
    }
  end

  # ============= Node Operations =============

  @doc """
  Adds a node with the given label.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_node("Node A")
      iex> Yog.Builder.Labeled.all_labels(builder)
      ["Node A"]
  """
  @spec add_node(t(), label()) :: t()
  def add_node(builder, label) do
    {new_builder, _id} = ensure_node(builder, label)
    new_builder
  end

  @doc """
  Gets or creates a node for the given label.

  If a node with this label already exists, returns its existing ID.
  If it doesn't exist, creates a new node and returns the new ID.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      iex> {_builder, id} = Yog.Builder.Labeled.ensure_node(builder, "A")
      iex> is_integer(id)
      true
  """
  @spec ensure_node(t(), label()) :: {t(), Yog.node_id()}
  def ensure_node(
        %__MODULE__{graph: graph, label_to_id: label_to_id, next_id: next_id} = builder,
        label
      ) do
    case Map.fetch(label_to_id, label) do
      {:ok, id} ->
        {builder, id}

      :error ->
        id = next_id
        new_graph = Model.add_node(graph, id, label)
        new_mapping = Map.put(label_to_id, label, id)
        new_builder = %{builder | graph: new_graph, label_to_id: new_mapping, next_id: id + 1}
        {new_builder, id}
    end
  end

  # ============= Edge Operations =============

  @doc """
  Adds an edge between two labeled nodes with a weight.

  If either node doesn't exist, it will be created automatically.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_edge("A", "B", 10)
      iex> {:ok, successors} = Yog.Builder.Labeled.successors(builder, "A")
      iex> successors
      [{"B", 10}]
  """
  @spec add_edge(t(), label(), label(), term()) :: t()
  def add_edge(builder, from, to, weight) do
    {builder_with_src, src_id} = ensure_node(builder, from)
    {builder_with_both, dst_id} = ensure_node(builder_with_src, to)

    %__MODULE__{graph: graph} = builder_with_both
    {:ok, new_graph} = Model.add_edge(graph, src_id, dst_id, weight)

    %{builder_with_both | graph: new_graph}
  end

  @doc """
  Adds an unweighted edge between two labeled nodes.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_unweighted_edge("A", "B")
      iex> {:ok, [{"B", nil}]} = Yog.Builder.Labeled.successors(builder, "A")
  """
  @spec add_unweighted_edge(t(), label(), label()) :: t()
  def add_unweighted_edge(builder, from, to) do
    add_edge(builder, from, to, nil)
  end

  @doc """
  Adds a simple edge with weight 1 between two labeled nodes.

  Unlike `add_unweighted_edge/3` which stores weight as nil, this stores weight as 1.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_simple_edge("A", "B")
      iex> is_struct(builder, Yog.Builder.Labeled)
      true
  """
  @spec add_simple_edge(t(), label(), label()) :: t()
  def add_simple_edge(builder, from, to) do
    add_edge(builder, from, to, 1)
  end

  # ============= Batch Construction =============

  @doc """
  Creates a builder from a list of labeled edges.

  ## Examples

      iex> edges = [{"A", "B", 5}, {"B", "C", 3}]
      iex> builder = Yog.Builder.Labeled.from_list(:directed, edges)
      iex> {:ok, [{"B", 5}]} = Yog.Builder.Labeled.successors(builder, "A")
  """
  @spec from_list(Model.graph_type(), [{label(), label(), term()}]) :: t()
  def from_list(graph_type, edges) do
    Enum.reduce(edges, new(graph_type), fn {src, dst, weight}, builder ->
      add_edge(builder, src, dst, weight)
    end)
  end

  @doc """
  Creates a builder from a list of unweighted labeled edges.

  ## Examples

      iex> edges = [{"A", "B"}, {"B", "C"}]
      iex> builder = Yog.Builder.Labeled.from_unweighted_list(:directed, edges)
      iex> {:ok, [{"B", nil}]} = Yog.Builder.Labeled.successors(builder, "A")
  """
  @spec from_unweighted_list(Model.graph_type(), [{label(), label()}]) :: t()
  def from_unweighted_list(graph_type, edges) do
    Enum.reduce(edges, new(graph_type), fn {src, dst}, builder ->
      add_unweighted_edge(builder, src, dst)
    end)
  end

  # ============= Conversion =============

  @doc """
  Converts the builder to a standard Graph.

  The resulting graph can be used with all Yog algorithms.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_edge("A", "B", 5)
      iex> graph = Yog.Builder.Labeled.to_graph(builder)
      iex> Yog.graph?(graph)
      true
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph(%__MODULE__{graph: graph}), do: graph

  @doc """
  Gets the label-to-ID registry as a map.

  Returns a map where keys are labels and values are node IDs.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_node("A")
      iex> registry = Yog.Builder.Labeled.to_registry(builder)
      iex> Map.get(registry, "A")
      0
  """
  @spec to_registry(t()) :: %{label() => Yog.node_id()}
  def to_registry(%__MODULE__{label_to_id: label_to_id}), do: label_to_id

  # ============= Queries =============

  @doc """
  Looks up the internal node ID for a given label.

  Returns `{:ok, id}` if the label exists, `{:error, nil}` otherwise.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_node("A")
      iex> Yog.Builder.Labeled.get_id(builder, "A")
      {:ok, 0}

      iex> builder = Yog.Builder.Labeled.directed()
      iex> Yog.Builder.Labeled.get_id(builder, "NonExistent")
      {:error, nil}
  """
  @spec get_id(t(), label()) :: {:ok, Yog.node_id()} | {:error, nil}
  def get_id(%__MODULE__{label_to_id: label_to_id}, label) do
    do_get_id(label_to_id, label)
  end

  defp do_get_id(label_to_id, label) do
    case Map.fetch(label_to_id, label) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, nil}
    end
  end

  @doc """
  Returns all labels that have been added to the builder.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_node("A")
      ...> |> Yog.Builder.Labeled.add_node("B")
      iex> Yog.Builder.Labeled.all_labels(builder)
      ["A", "B"]
  """
  @spec all_labels(t()) :: [label()]
  def all_labels(%__MODULE__{label_to_id: label_to_id}), do: Map.keys(label_to_id)

  @doc """
  Gets the next available node ID.

  This is the ID that would be assigned to the next new node.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      iex> Yog.Builder.Labeled.next_id(builder)
      0
      iex> builder = Yog.Builder.Labeled.add_node(builder, "A")
      iex> Yog.Builder.Labeled.next_id(builder)
      1
  """
  @spec next_id(t()) :: Yog.node_id()
  def next_id(%__MODULE__{next_id: next_id}), do: next_id

  @doc """
  Gets the successors of a node by its label.

  Returns `{:ok, edges}` where edges is a list of `{label, weight}` tuples,
  or `{:error, nil}` if the label doesn't exist.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_edge("A", "B", 10)
      iex> Yog.Builder.Labeled.successors(builder, "A")
      {:ok, [{"B", 10}]}
  """
  @spec successors(t(), label()) :: {:ok, [{label(), term()}]} | {:error, nil}
  def successors(%__MODULE__{graph: graph, label_to_id: label_to_id}, label) do
    do_successors(graph, label_to_id, label)
  end

  defp do_successors(graph, label_to_id, label) do
    case Map.fetch(label_to_id, label) do
      {:ok, id} ->
        successor_edges = Model.successors(graph, id)
        labeled_edges = map_ids_to_labels(successor_edges, graph)
        {:ok, labeled_edges}

      :error ->
        {:error, nil}
    end
  end

  @doc """
  Gets the predecessors of a node by its label.

  Returns `{:ok, edges}` where edges is a list of `{label, weight}` tuples,
  or `{:error, nil}` if the label doesn't exist.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_edge("A", "B", 5)
      iex> Yog.Builder.Labeled.predecessors(builder, "B")
      {:ok, [{"A", 5}]}
  """
  @spec predecessors(t(), label()) :: {:ok, [{label(), term()}]} | {:error, nil}
  def predecessors(%__MODULE__{graph: graph, label_to_id: label_to_id}, label) do
    do_predecessors(graph, label_to_id, label)
  end

  defp do_predecessors(graph, label_to_id, label) do
    case Map.fetch(label_to_id, label) do
      {:ok, id} ->
        predecessor_edges = Model.predecessors(graph, id)
        labeled_edges = map_ids_to_labels(predecessor_edges, graph)
        {:ok, labeled_edges}

      :error ->
        {:error, nil}
    end
  end

  # ============= Private Helpers =============

  defp map_ids_to_labels(edges, graph) do
    Enum.flat_map(edges, fn {node_id, edge_data} ->
      case Model.node(graph, node_id) do
        nil -> []
        label -> [{label, edge_data}]
      end
    end)
  end
end
