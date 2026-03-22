defmodule Yog.Builder.Labeled do
  @moduledoc """
  Build graphs using arbitrary labels instead of integer IDs.

  This module provides a convenient way to build graphs when your nodes are
  naturally identified by strings, atoms, or other types, rather than integers.

  ## Example Usage (Not a doctest - delegates to Erlang)

      # Build a graph with string labels
      builder = Yog.Builder.Labeled.directed()
        |> Yog.Builder.Labeled.add_edge("home", "work", 10)
        |> Yog.Builder.Labeled.add_edge("work", "gym", 5)

      # Convert to a Graph to use with algorithms
      graph = Yog.Builder.Labeled.to_graph(builder)

      # Get the node ID for a label
      {:ok, home_id} = Yog.Builder.Labeled.get_id(builder, "home")

      # Use with pathfinding
      case Yog.Pathfinding.shortest_path(
        in: graph,
        from: home_id,
        to: gym_id,
        zero: 0,
        add: &Kernel.+/2,
        compare: &Integer.compare/2
      ) do
        {:some, path} -> path
        :none -> :no_path
      end

  ## Batch Construction

  For building from existing data, use the `from_list` functions:

      # edges = [{"A", "B", 5}, {"B", "C", 3}, {"A", "C", 10}]
      # builder = Yog.Builder.Labeled.from_list(:directed, edges)
      # graph = Yog.Builder.Labeled.to_graph(builder)
  """

  @typedoc "Opaque builder type"
  @type builder :: term()

  @typedoc "Any type can be used as a label"
  @type label :: term()

  # ============= Constructors =============

  @doc """
  Creates a new labeled directed graph builder.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      iex> is_tuple(builder)
      true
  """
  @spec directed() :: builder()
  defdelegate directed(), to: :yog@builder@labeled

  @doc """
  Creates a new labeled undirected graph builder.

  ## Examples

      iex> builder = Yog.Builder.Labeled.undirected()
      iex> is_tuple(builder)
      true
  """
  @spec undirected() :: builder()
  defdelegate undirected(), to: :yog@builder@labeled

  @doc """
  Creates a new labeled graph builder of the specified type.

  ## Examples

      iex> builder = Yog.Builder.Labeled.new(:directed)
      iex> is_tuple(builder)
      true
  """
  @spec new(Yog.graph_type()) :: builder()
  defdelegate new(graph_type), to: :yog@builder@labeled

  # ============= Node Operations =============

  @doc """
  Adds a node with the given label.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_node("Node A")
      iex> Yog.Builder.Labeled.all_labels(builder)
      ["Node A"]
  """
  @spec add_node(builder(), label()) :: builder()
  defdelegate add_node(builder, label), to: :yog@builder@labeled

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
  @spec ensure_node(builder(), label()) :: {builder(), Yog.node_id()}
  defdelegate ensure_node(builder, label), to: :yog@builder@labeled

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
  @spec add_edge(builder(), label(), label(), term()) :: builder()
  defdelegate add_edge(builder, from, to, weight), to: :yog@builder@labeled

  @doc """
  Adds an unweighted edge between two labeled nodes.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_unweighted_edge("A", "B")
      iex> {:ok, [{"B", nil}]} = Yog.Builder.Labeled.successors(builder, "A")
  """
  @spec add_unweighted_edge(builder(), label(), label()) :: builder()
  defdelegate add_unweighted_edge(builder, from, to), to: :yog@builder@labeled

  @doc """
  Adds a simple edge with no weight data between two labeled nodes.

  Unlike `add_unweighted_edge/3` which stores weight as 1, this stores no weight.

  ## Examples

      iex> Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_simple_edge("A", "B")
      ...> |> is_tuple()
      true
  """
  @spec add_simple_edge(builder(), label(), label()) :: builder()
  defdelegate add_simple_edge(builder, from, to), to: :yog@builder@labeled

  # ============= Batch Construction =============

  @doc """
  Creates a builder from a list of labeled edges.

  ## Examples

      iex> edges = [{"A", "B", 5}, {"B", "C", 3}]
      iex> builder = Yog.Builder.Labeled.from_list(:directed, edges)
      iex> {:ok, [{"B", 5}]} = Yog.Builder.Labeled.successors(builder, "A")
  """
  @spec from_list(Yog.graph_type(), [{label(), label(), term()}]) :: builder()
  defdelegate from_list(graph_type, edges), to: :yog@builder@labeled

  @doc """
  Creates a builder from a list of unweighted labeled edges.

  ## Examples

      iex> edges = [{"A", "B"}, {"B", "C"}]
      iex> builder = Yog.Builder.Labeled.from_unweighted_list(:directed, edges)
      iex> {:ok, [{"B", nil}]} = Yog.Builder.Labeled.successors(builder, "A")
  """
  @spec from_unweighted_list(Yog.graph_type(), [{label(), label()}]) :: builder()
  defdelegate from_unweighted_list(graph_type, edges), to: :yog@builder@labeled

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
  @spec to_graph(builder()) :: Yog.graph()
  defdelegate to_graph(builder), to: :yog@builder@labeled

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
  @spec to_registry(builder()) :: %{label() => Yog.node_id()}
  defdelegate to_registry(builder), to: :yog@builder@labeled

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
  @spec get_id(builder(), label()) :: {:ok, Yog.node_id()} | {:error, nil}
  def get_id(builder, label) do
    case :yog@builder@labeled.get_id(builder, label) do
      {:ok, id} -> {:ok, id}
      {:error, _} -> {:error, nil}
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
  @spec all_labels(builder()) :: [label()]
  defdelegate all_labels(builder), to: :yog@builder@labeled

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
  @spec next_id(builder()) :: Yog.node_id()
  defdelegate next_id(builder), to: :yog@builder@labeled

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
  @spec successors(builder(), label()) :: {:ok, [{label(), term()}]} | {:error, nil}
  def successors(builder, label) do
    case :yog@builder@labeled.successors(builder, label) do
      {:ok, edges} -> {:ok, edges}
      {:error, _} -> {:error, nil}
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
  @spec predecessors(builder(), label()) :: {:ok, [{label(), term()}]} | {:error, nil}
  def predecessors(builder, label) do
    case :yog@builder@labeled.predecessors(builder, label) do
      {:ok, edges} -> {:ok, edges}
      {:error, _} -> {:error, nil}
    end
  end
end
