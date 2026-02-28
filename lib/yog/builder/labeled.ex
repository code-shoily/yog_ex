defmodule Yog.Builder.Labeled do
  @moduledoc """
  Build graphs using arbitrary labels instead of integer IDs.

  This module provides a convenient way to build graphs when your nodes are
  naturally identified by strings, atoms, or other types, rather than integers.

  ## Examples

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
  """

  @type builder :: term()
  @type label :: term()

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
  @spec new(atom()) :: builder()
  defdelegate new(graph_type), to: :yog@builder@labeled

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
  Adds an edge between two labeled nodes.

  If either node doesn't exist, it will be created automatically.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_edge("A", "B", 10)
      iex> {:ok, successors} = Yog.Builder.Labeled.successors(builder, "A")
      iex> successors
      [{"B", 10}]
  """
  @spec add_edge(builder(), label(), label(), term()) :: builder()
  def add_edge(builder, from, to, weight) do
    :yog@builder@labeled.add_edge(builder, from, to, weight)
  end

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
  @spec get_id(builder(), label()) :: {:ok, integer()} | {:error, nil}
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

  @doc """
  Gets or creates a node for the given label, returning the builder and node ID.

  If a node with this label already exists, returns its ID without modification.
  If it doesn't exist, creates a new node with the label as its data.

  ## Examples

      iex> builder = Yog.Builder.Labeled.directed()
      iex> {_builder, id} = Yog.Builder.Labeled.ensure_node(builder, "A")
      iex> is_integer(id)
      true
  """
  @spec ensure_node(builder(), label()) :: {builder(), integer()}
  defdelegate ensure_node(builder, label), to: :yog@builder@labeled
end
