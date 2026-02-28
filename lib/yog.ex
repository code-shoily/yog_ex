defmodule Yog do
  @moduledoc """
  Elixir wrapper for Yog - A comprehensive graph algorithm library.

  Yog provides efficient implementations of classic graph algorithms with a
  clean, functional API. Written in Gleam for type safety and performance,
  with zero-cost interoperability on the BEAM.

  ## Quick Start

      # Create a directed graph
      graph = Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)

      # Query the graph
      Yog.successors(graph, 1)
      #=> [{2, 10}]

  ## Modules

  - `Yog` - Core graph operations
  - `Yog.Labeled` - Build graphs with string/atom labels
  - `Yog.Pathfinding` - Shortest path algorithms
  - `Yog.Traversal` - BFS/DFS traversal
  - `Yog.Transform` - Graph transformations
  - `Yog.Render` - Visualization (Mermaid, DOT, JSON)

  ## Related

  For complete API documentation, see the [Gleam Yog docs](https://hexdocs.pm/yog).
  """

  @type graph :: term()
  @type node_id :: integer()
  @type graph_type :: :directed | :undirected

  # Core creation functions

  @doc """
  Creates a new empty directed graph.

  ## Examples

      iex> graph = Yog.directed()
      iex> Yog.graph?(graph)
      true
  """
  @spec directed() :: graph()
  defdelegate directed(), to: :yog

  @doc """
  Creates a new empty undirected graph.

  ## Examples

      iex> graph = Yog.undirected()
      iex> Yog.graph?(graph)
      true
  """
  @spec undirected() :: graph()
  defdelegate undirected(), to: :yog

  @doc """
  Creates a new empty graph of the specified type.

  ## Options

  - `:directed` - Creates a directed graph
  - `:undirected` - Creates an undirected graph

  ## Examples

      iex> graph = Yog.new(:directed)
      iex> Yog.graph?(graph)
      true
  """
  @spec new(graph_type()) :: graph()
  defdelegate new(graph_type), to: :yog

  @doc """
  Creates a graph from a list of edges `{src, dst, weight}`.
  """
  @spec from_edges(graph_type(), [{node_id(), node_id(), term()}]) :: graph()
  defdelegate from_edges(graph_type, edges), to: :yog

  @doc """
  Creates a graph from a list of unweighted edges `{src, dst}`.
  """
  @spec from_unweighted_edges(graph_type(), [{node_id(), node_id()}]) :: graph()
  defdelegate from_unweighted_edges(graph_type, edges), to: :yog

  @doc """
  Creates a graph from an adjacency list `{src, [{dst, weight}]}`.
  """
  @spec from_adjacency_list(graph_type(), [{node_id(), [{node_id(), term()}]}]) :: graph()
  defdelegate from_adjacency_list(graph_type, adj_list), to: :yog

  # Node operations

  @doc """
  Adds a node to the graph with the given ID and data.

  If a node with this ID already exists, its data will be replaced.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Node A")
      ...> |> Yog.add_node(2, "Node B")
  """
  @spec add_node(graph(), node_id(), term()) :: graph()
  defdelegate add_node(graph, id, data), to: :yog

  # Edge operations

  @doc """
  Adds an edge to the graph.

  For directed graphs, adds a single edge from `from` to `to`.
  For undirected graphs, adds edges in both directions.

  ## Options

  - `:from` - Source node ID
  - `:to` - Destination node ID
  - `:weight` - Edge weight/data

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_edge(from: 1, to: 2, weight: 10)
  """
  @spec add_edge(graph(), keyword()) :: graph()
  def add_edge(graph, opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :weight)
    :yog.add_edge(graph, from, to, weight)
  end

  @doc "Raw binding for add_edge/4"
  defdelegate add_edge(graph, from, to, weight), to: :yog

  @doc """
  Adds an unweighted edge to the graph (uses `nil` for weight).
  """
  @spec add_unweighted_edge(graph(), keyword()) :: graph()
  def add_unweighted_edge(graph, opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    :yog.add_unweighted_edge(graph, from, to)
  end

  @doc "Raw binding for add_unweighted_edge/3"
  defdelegate add_unweighted_edge(graph, from, to), to: :yog

  @doc """
  Adds a simple edge with weight 1.
  """
  @spec add_simple_edge(graph(), keyword()) :: graph()
  def add_simple_edge(graph, opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    :yog.add_simple_edge(graph, from, to)
  end

  @doc "Raw binding for add_simple_edge/3"
  defdelegate add_simple_edge(graph, from, to), to: :yog

  # Query operations

  @doc """
  Gets nodes you can travel TO from the given node (successors).

  Returns a list of tuples containing the destination node ID and edge data.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_edge(from: 1, to: 2, weight: 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec successors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate successors(graph, id), to: :yog

  @doc """
  Gets nodes you came FROM to reach the given node (predecessors).

  Returns a list of tuples containing the source node ID and edge data.
  """
  @spec predecessors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate predecessors(graph, id), to: :yog

  @doc """
  Gets all nodes connected to the given node, regardless of direction.
  """
  @spec neighbors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate neighbors(graph, id), to: :yog

  @doc """
  Returns all unique node IDs that have edges in the graph.
  """
  @spec all_nodes(graph()) :: [node_id()]
  defdelegate all_nodes(graph), to: :yog

  @doc """
  Returns just the NodeIds of successors (without edge data).
  """
  @spec successor_ids(graph(), node_id()) :: [node_id()]
  defdelegate successor_ids(graph, id), to: :yog

  # Type guards

  @doc """
  Returns true if the given term is a Yog graph.

  ## Examples

      iex> graph = Yog.directed()
      iex> Yog.graph?(graph)
      true

      iex> Yog.graph?("not a graph")
      false
  """
  def graph?(term) when is_tuple(term), do: elem(term, 0) == :graph
  def graph?(_), do: false
end
