defmodule Yog do
  @moduledoc """
  The main entry point for the Yog graph library.

  This module provides the core graph data structures and basic operations.
  Most algorithms are available in submodules like `Yog.Pathfinding`,
  `Yog.Traversal`, etc.
  """

  # Re-exporting core types
  @type node_id() :: integer()
  @type edge_tuple() :: {node_id(), node_id(), any()}
  @type graph() :: any()

  @doc """
  Returns true if the given value is a Yog graph.
  """
  @spec graph?(any()) :: boolean()
  def graph?({:graph, _, _, _, _}), do: true
  def graph?(_), do: false

  # ============= Creation =============

  @doc """
  Creates a new empty directed graph.
  """
  @spec directed() :: graph()
  def directed, do: :yog.directed()

  @doc """
  Creates a new empty undirected graph.
  """
  @spec undirected() :: graph()
  def undirected, do: :yog.undirected()

  @doc """
  Creates a new graph of the specified type.
  """
  @spec new(:directed | :undirected) :: graph()
  def new(type) do
    case type do
      :directed -> :yog.new(:directed)
      :undirected -> :yog.new(:undirected)
    end
  end

  # ============= Modification =============

  @doc """
  Adds a node to the graph with the given ID and label.
  If a node with this ID already exists, its data will be replaced.
  """
  @spec add_node(graph(), node_id(), any()) :: graph()
  defdelegate add_node(graph, id, data), to: :yog

  @doc """
  Adds an edge to the graph.

  For directed graphs, adds a single edge from `from` to `to`.
  For undirected graphs, adds edges in both directions.

  Returns `{:ok, graph}` or `{:error, reason}`.
  """
  @spec add_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_edge(graph, opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    :yog.add_edge(graph, from, to, weight)
  end

  @doc """
  Adds an edge to the graph, raising on error.
  """
  @spec add_edge!(graph(), keyword()) :: graph()
  def add_edge!(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    :yog.add_edge_ensure(graph, from, to, weight, nil)
  end

  def add_edge!(graph, from, to, weight) do
    :yog.add_edge_ensure(graph, from, to, weight, nil)
  end

  @doc "Raw binding for add_edge/4"
  @spec add_edge(graph(), node_id(), node_id(), any()) :: {:ok, graph()} | {:error, String.t()}
  def add_edge(graph, from, to, weight) do
    :yog.add_edge(graph, from, to, weight)
  end

  @doc """
  Ensures both endpoint nodes exist, then adds an edge.
  """
  @spec add_edge_ensure(graph(), keyword()) :: graph()
  def add_edge_ensure(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    default = Keyword.get(opts, :default, nil)
    :yog.add_edge_ensure(graph, from, to, weight, default)
  end

  def add_edge_ensure(graph, from, to, weight, default) do
    :yog.add_edge_ensure(graph, from, to, weight, default)
  end

  @doc "Deprecated compatibility alias for `add_edge_ensure`"
  def add_edge_ensured(graph, from, to, weight, default) do
    add_edge_ensure(graph, from, to, weight, default)
  end

  @doc """
  Adds an edge with a function to create default node data if nodes don't exist.

  ## Example

      graph = Yog.add_edge_with(graph, 1, 2, 10, fn id -> "Node \#{id}" end)
  """
  @spec add_edge_with(graph(), node_id(), node_id(), any(), (node_id() -> any())) :: graph()
  def add_edge_with(graph, from, to, weight, default_fn) do
    :yog.add_edge_with(graph, from, to, weight, default_fn)
  end

  @doc """
  Adds an unweighted edge to the graph.
  """
  @spec add_unweighted_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_unweighted_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    :yog.add_unweighted_edge(graph, from, to)
  end

  @spec add_unweighted_edge(graph(), node_id(), node_id()) ::
          {:ok, graph()} | {:error, String.t()}
  def add_unweighted_edge(graph, from, to) do
    :yog.add_unweighted_edge(graph, from, to)
  end

  @doc """
  Adds an unweighted edge to the graph, raising on error.
  """
  def add_unweighted_edge!(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    :yog.add_edge_ensure(graph, from, to, nil, nil)
  end

  def add_unweighted_edge!(graph, from, to) do
    :yog.add_edge_ensure(graph, from, to, nil, nil)
  end

  @doc """
  Adds a simple edge with weight 1.
  """
  @spec add_simple_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_simple_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    :yog.add_simple_edge(graph, from, to)
  end

  @spec add_simple_edge(graph(), node_id(), node_id()) :: {:ok, graph()} | {:error, String.t()}
  def add_simple_edge(graph, from, to) do
    :yog.add_simple_edge(graph, from, to)
  end

  @doc """
  Adds a simple edge with weight 1, raising on error.
  """
  def add_simple_edge!(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    :yog.add_edge_ensure(graph, from, to, 1, nil)
  end

  def add_simple_edge!(graph, from, to) do
    :yog.add_edge_ensure(graph, from, to, 1, nil)
  end

  @doc """
  Adds multiple edges to the graph.
  """
  @spec add_edges(graph(), [edge_tuple()]) :: {:ok, graph()} | {:error, String.t()}
  defdelegate add_edges(graph, edges), to: :yog

  @doc """
  Adds multiple edges to the graph, raising on error.
  """
  def add_edges!(graph, edges) do
    case add_edges(graph, edges) do
      {:ok, graph} -> graph
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Adds multiple simple edges (weight 1).
  """
  @spec add_simple_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  defdelegate add_simple_edges(graph, edges), to: :yog

  @doc """
  Adds multiple unweighted edges (weight nil).
  """
  @spec add_unweighted_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  defdelegate add_unweighted_edges(graph, edges), to: :yog

  # ============= Query =============

  @doc """
  Gets nodes you can travel TO from the given node (successors).
  """
  @spec successors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate successors(graph, id), to: :yog

  @doc """
  Gets nodes you came FROM to reach the given node (predecessors).
  """
  @spec predecessors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate predecessors(graph, id), to: :yog

  @doc """
  Gets node IDs you can travel TO from the given node.
  """
  @spec successor_ids(graph(), node_id()) :: [node_id()]
  defdelegate successor_ids(graph, id), to: :yog

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

  # ============= Analysis =============

  @doc """
  Determines if a graph contains any cycles.
  """
  @spec cyclic?(graph()) :: boolean()
  defdelegate cyclic?(graph), to: :yog, as: :is_cyclic

  @doc """
  Determines if a graph is acyclic (contains no cycles).
  """
  @spec acyclic?(graph()) :: boolean()
  defdelegate acyclic?(graph), to: :yog, as: :is_acyclic

  # ============= Transform =============

  @doc """
  Returns a graph where all edges have been reversed.
  """
  @spec transpose(graph()) :: graph()
  defdelegate transpose(graph), to: :yog

  @doc """
  Creates a new graph where node labels are transformed.
  """
  @spec map_nodes(graph(), (any() -> any())) :: graph()
  defdelegate map_nodes(graph, func), to: :yog

  @doc """
  Creates a new graph where edge weights are transformed.
  """
  @spec map_edges(graph(), (any() -> any())) :: graph()
  defdelegate map_edges(graph, func), to: :yog

  @doc """
  Filter nodes by a predicate.
  """
  @spec filter_nodes(graph(), (any() -> boolean())) :: graph()
  defdelegate filter_nodes(graph, predicate), to: :yog

  @doc """
  Filter edges by a predicate.
  """
  @spec filter_edges(graph(), (node_id(), node_id(), any() -> boolean())) :: graph()
  defdelegate filter_edges(graph, predicate), to: :yog

  @doc """
  Merges two graphs.
  """
  @spec merge(graph(), graph()) :: graph()
  defdelegate merge(base, other), to: :yog

  @doc """
  Extracts a subgraph keeping only the specified nodes.
  """
  @spec subgraph(graph(), [node_id()]) :: graph()
  defdelegate subgraph(graph, ids), to: :yog

  @doc """
  Converts an undirected graph to directed or vice-versa.
  """
  @spec to_directed(graph()) :: graph()
  defdelegate to_directed(graph), to: :yog

  @spec to_undirected(graph(), (any(), any() -> any())) :: graph()
  defdelegate to_undirected(graph, resolve_fn), to: :yog

  # ============= Construction from various formats =============

  @doc """
  Creates a graph from a list of edges.

  ## Example

      edges = [{1, 2, 10}, {2, 3, 20}]
      graph = Yog.from_edges(:directed, edges)
  """
  @spec from_edges(:directed | :undirected, [{node_id(), node_id(), any()}]) :: graph()
  def from_edges(type, edges) do
    :yog.from_edges(type, edges)
  end

  @doc """
  Creates a graph from a list of unweighted edges (weight will be nil).

  ## Example

      edges = [{1, 2}, {2, 3}]
      graph = Yog.from_unweighted_edges(:directed, edges)
  """
  @spec from_unweighted_edges(:directed | :undirected, [{node_id(), node_id()}]) :: graph()
  def from_unweighted_edges(type, edges) do
    :yog.from_unweighted_edges(type, edges)
  end

  @doc """
  Creates a graph from an adjacency list.

  ## Example

      # adjacency_list: %{1 => [{2, 10}, {3, 20}], 2 => [{3, 30}]}
      graph = Yog.from_adjacency_list(:directed, adjacency_list)
  """
  @spec from_adjacency_list(:directed | :undirected, %{node_id() => [{node_id(), any()}]}) ::
          graph()
  def from_adjacency_list(type, adjacency_list) do
    # Convert Elixir map to Gleam dict
    gleam_dict =
      adjacency_list
      |> Map.to_list()
      |> Enum.map(fn {k, v} -> {k, v} end)
      |> :gleam@dict.from_list()

    :yog.from_adjacency_list(type, gleam_dict)
  end

  # ============= Walk =============

  @doc """
  Walks the graph from a starting node.
  """
  @spec walk(graph(), node_id(), :breadth_first | :depth_first) :: [node_id()]
  def walk(graph, start_id, order) do
    :yog.walk(graph, start_id, order)
  end

  @doc """
  Walks the graph until a condition is met.

  ## Example

      # Walk until we find node 5
      result = Yog.walk_until(graph, 1, :breadth_first, fn node -> node == 5 end)
  """
  @spec walk_until(graph(), node_id(), :breadth_first | :depth_first, (node_id() -> boolean())) ::
          [node_id()]
  def walk_until(graph, start_id, order, condition) do
    :yog.walk_until(graph, start_id, order, condition)
  end

  @doc """
  Folds over the graph during a walk.

  ## Example

      # Count nodes during traversal
      count = Yog.fold_walk(graph, 1, :breadth_first, 0, fn acc, node -> acc + 1 end)
  """
  @spec fold_walk(
          graph(),
          node_id(),
          :breadth_first | :depth_first,
          acc,
          (acc, node_id() -> acc)
        ) :: acc
        when acc: var
  def fold_walk(graph, start_id, order, initial, folder) do
    :yog.fold_walk(graph, start_id, order, initial, folder)
  end

  # ============= Graph Operations =============

  @doc """
  Returns the complement of the graph (edges that don't exist in the original).

  The complement has edges between all pairs of nodes that are NOT connected
  in the original graph.

  ## Parameters

    * `graph` - The input graph
    * `default_weight` - Weight to assign to new edges in the complement
  """
  @spec complement(graph(), any()) :: graph()
  defdelegate complement(graph, default_weight), to: :yog

  @doc """
  Contracts (merges) multiple nodes into a single node.

  ## Example

      # Contract nodes 1, 2, 3 into a single node with ID :contracted
      graph = Yog.contract(graph, [1, 2, 3], :contracted, fn labels -> 
        # Combine node labels
        Enum.join(labels, ",")
      end)
  """
  @spec contract(graph(), [node_id()], node_id(), ([any()] -> any())) :: graph()
  defdelegate contract(graph, ids, new_id, combine_fn), to: :yog
end
