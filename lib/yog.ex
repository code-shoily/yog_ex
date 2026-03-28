defmodule Yog do
  @moduledoc """
  Yog - A comprehensive graph algorithm library for Elixir.

  Provides efficient implementations of classic graph algorithms with a
  clean, functional API.

  ## Quick Start

  ```elixir
  # Find shortest path using Dijkstra's algorithm
  {:ok, graph} =
    Yog.directed()
    |> Yog.add_node(1, "Start")
    |> Yog.add_node(2, "Middle")
    |> Yog.add_node(3, "End")
    |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])

  case Yog.Pathfinding.Dijkstra.shortest_path(
         graph,
         from: 1,
         to: 3,
         with_zero: 0,
         with_add: &Kernel.+/2,
         with_compare: &Kernel.<=/2
       ) do
    {:ok, path} ->
      # Path: %{nodes: [1, 2, 3], total_weight: 8}
      IO.puts("Shortest path found!")

    _ ->
      IO.puts("No path exists")
  end
  ```

  ## Modules

  ### Core
  - `Yog.Model` - Graph data structures and basic operations
      - Create directed/undirected graphs
      - Add nodes and edges
      - Query successors, predecessors, neighbors

  - `Yog.Builder.Labeled` - Build graphs with arbitrary labels
      - Use strings or any type as node identifiers
      - Automatically maps labels to internal integer IDs
      - Convert to standard Graph for use with all algorithms

  ### Algorithms
  - `Yog.Pathfinding` - Shortest path algorithms
      - Dijkstra's algorithm (non-negative weights)
      - A* search (with heuristics)
      - Bellman-Ford (negative weights, cycle detection)

  - `Yog.Traversal` - Graph traversal
      - Breadth-First Search (BFS)
      - Depth-First Search (DFS)
      - Early termination support

  - `Yog.MST` - Minimum Spanning Tree
      - Kruskal's algorithm with Union-Find
      - Prim's algorithm with priority queue

  - `Yog.DAG` - Topological ordering
      - Kahn's algorithm
      - Lexicographical variant (heap-based)

  - `Yog.Connectivity` - Connected components
      - Tarjan's algorithm for Strongly Connected Components (SCC)
      - Kosaraju's algorithm for SCC (two-pass with transpose)

  - `Yog.Connectivity` - Graph connectivity analysis
      - Tarjan's algorithm for bridges and articulation points

  - `Yog.Flow` / `Yog.MinCut` - Minimum cut algorithms
      - Stoer-Wagner algorithm for global minimum cut

  - `Yog.Eulerian` - Eulerian paths and circuits
      - Detection of Eulerian paths and circuits
      - Hierholzer's algorithm for finding paths
      - Works on both directed and undirected graphs

  - `Yog.Bipartite` - Bipartite graph detection and matching
      - Bipartite detection (2-coloring)
      - Partition extraction (independent sets)
      - Maximum matching (augmenting path algorithm)

  ### Data Structures
  - `Yog.DisjointSet` - Union-Find / Disjoint Set
      - Path compression and union by rank
      - O(α(n)) amortized operations (practically constant)
      - Dynamic connectivity queries
      - Generic over any type

  ### Transformations
  - `Yog.Transform` - Graph transformations
      - Transpose (O(1) edge reversal!)
      - Map and update nodes/edges
      - Filter nodes with auto-pruning
      - Merge and subgraph extraction
      - Transitive closure and reduction
      - Complement and contraction

  ## Features

  - **Functional and Immutable**: All operations return new graphs
  - **Generic**: Works with any node/edge data types
  - **Type-Safe**: Leverages Elixir's type system
  - **Well-Tested**: 494+ tests covering all algorithms and data structures
  - **Efficient**: Optimal data structures (pairing heaps, union-find)
  - **Documented**: Every function has examples
  """
  alias Yog.Connectivity
  alias Yog.Graph
  alias Yog.Model
  alias Yog.Transform
  alias Yog.Traversal

  # Re-exporting core types
  @type t() :: Graph.t()
  @type node_id() :: integer()
  @type graph_type() :: :directed | :undirected
  @type edge_tuple() :: {node_id(), node_id(), any()}
  @type graph() :: any()
  @type order() :: :breadth_first | :depth_first
  @type walk_control() :: :continue | :stop | :halt

  # Re-export type constants for traversal order
  @doc """
  Order constant for breadth-first traversal.

  ## Example
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.walk(graph, 1, Yog.breadth_first())
      [1, 2, 3]
  """
  @spec breadth_first() :: :breadth_first
  def breadth_first, do: :breadth_first

  @doc """
  Order constant for depth-first traversal.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.walk(graph, 1, Yog.depth_first())
      [1, 2, 3]
  """
  @spec depth_first() :: :depth_first
  def depth_first, do: :depth_first

  # Re-export walk control constants
  @doc """
  Control constant to continue walking during traversal.
  """
  @spec continue() :: :continue
  def continue, do: :continue

  @doc """
  Control constant to stop the current branch during traversal.
  """
  @spec stop() :: :stop
  def stop, do: :stop

  @doc """
  Control constant to halt traversal completely.
  """
  @spec halt() :: :halt
  def halt, do: :halt

  @doc """
  Returns true if the given value is a Yog graph.

  ## Example

      iex> graph = Yog.directed()
      iex> Yog.graph?(graph)
      true
      iex> Yog.graph?("not a graph")
      false
  """
  @spec graph?(any()) :: boolean()
  def graph?(%Yog.Graph{}), do: true
  def graph?(_), do: false

  # ============= Creation =============

  @doc """
  Creates a new empty directed graph.

  This is a convenience function that's equivalent to `Yog.new(:directed)`,
  but requires only a single import.

  ## Example

      iex> graph = Yog.directed()
      iex> Yog.graph?(graph)
      true
  """
  @spec directed() :: graph()
  def directed, do: Model.new(:directed)

  @doc """
  Creates a new empty undirected graph.

  This is a convenience function that's equivalent to `Yog.new(:undirected)`,
  but requires only a single import.

  ## Example

      iex> graph = Yog.undirected()
      iex> Yog.graph?(graph)
      true
  """
  @spec undirected() :: graph()
  def undirected, do: Model.new(:undirected)

  @doc """
  Creates a new empty graph of the specified type.

  ## Example

      iex> graph = Yog.new(:directed)
      iex> Yog.graph?(graph)
      true

      iex> graph = Yog.new(:undirected)
      iex> Yog.graph?(graph)
      true
  """
  @spec new(:directed | :undirected) :: graph()
  def new(type) do
    Model.new(type)
  end

  # ============= Modification =============

  @doc """
  Adds a node to the graph with the given ID and label.
  If a node with this ID already exists, its data will be replaced.

  ## Example

      iex> graph = Yog.directed()
      iex> graph = Yog.add_node(graph, 1, "Node A")
      iex> graph = Yog.add_node(graph, 2, "Node B")
      iex> Yog.all_nodes(graph) |> Enum.sort()
      [1, 2]
  """
  @spec add_node(graph(), node_id(), any()) :: graph()
  defdelegate add_node(graph, id, data), to: Model

  @doc """
  Adds an edge to the graph.

  For directed graphs, adds a single edge from `from` to `to`.
  For undirected graphs, adds edges in both directions.

  Returns `{:ok, graph}` or `{:error, reason}`.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(from: 1, to: 2, with: 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]

  ## With pattern matching for chaining

      iex> graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      iex> {:ok, graph} = Yog.add_edge(graph, from: 1, to: 2, with: 10)
      iex> {:ok, graph} = Yog.add_edge(graph, from: 2, to: 1, with: 5)
      iex> Yog.successors(graph, 2)
      [{1, 5}]
  """
  @spec add_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    Model.add_edge(graph, from, to, weight)
  end

  @doc """
  Raw binding for add_edge with positional arguments.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      iex> {:ok, graph} = Yog.add_edge(graph, 1, 2, 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge(graph(), node_id(), node_id(), any()) :: {:ok, graph()} | {:error, String.t()}
  defdelegate add_edge(graph, from, to, weight), to: Model

  @doc """
  Adds an edge to the graph, raising on error.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      iex> graph = Yog.add_edge!(graph, from: 1, to: 2, with: 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge!(graph(), keyword()) :: graph()
  def add_edge!(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    Model.add_edge!(graph, from, to, weight)
  end

  @doc """
  Adds an edge to the graph with positional arguments, raising on error.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      iex> graph = Yog.add_edge!(graph, 1, 2, 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  defdelegate add_edge!(graph, from, to, weight), to: Model

  @doc """
  Ensures both endpoint nodes exist, then adds an edge.

  If `from` or `to` is not already in the graph, it is created with
  the supplied `default` node data. Existing nodes are left unchanged.

  Always succeeds and returns a `Graph` (never fails).
  Use this when you want to build graphs quickly without pre-creating nodes.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10, default: "anon")
      iex> # Nodes 1 and 2 are auto-created with data "anon"
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge_ensure(graph(), keyword()) :: graph()
  def add_edge_ensure(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    default = Keyword.get(opts, :default, nil)
    Model.add_edge_ensure(graph, from, to, weight, default)
  end

  @doc """
  Ensures both endpoint nodes exist with positional arguments, then adds an edge.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 10, "anon")
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  defdelegate add_edge_ensure(graph, from, to, weight, default \\ nil), to: Model

  @doc """
  Adds an edge with a function to create default node data if nodes don't exist.

  If `from` or `to` is not already in the graph, it is created by
  calling the `default_fn` function with the node ID to generate the node data.
  Existing nodes are left unchanged.

  Always succeeds and returns a `Graph` (never fails).

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_edge_with(1, 2, 10, fn id -> "Node\#{id}" end)
      iex> # Nodes 1 and 2 are auto-created with "Node1" and "Node2"
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec add_edge_with(graph(), node_id(), node_id(), any(), (node_id() -> any())) :: graph()
  defdelegate add_edge_with(graph, from, to, weight, default_fn), to: Model

  @doc """
  Adds an unweighted edge to the graph.

  This is a convenience function for graphs where edges have no meaningful weight.
  Uses `nil` as the edge data type.

  Returns `{:ok, graph}` or `{:error, reason}` if either endpoint node doesn't exist.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_unweighted_edge(from: 1, to: 2)
      iex> Yog.successors(graph, 1)
      [{2, nil}]
  """
  @spec add_unweighted_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_unweighted_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    Model.add_edge(graph, from, to, nil)
  end

  @doc """
  Adds an unweighted edge with positional arguments.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_unweighted_edge(1, 2)
      iex> Yog.successors(graph, 1)
      [{2, nil}]
  """
  @spec add_unweighted_edge(graph(), node_id(), node_id()) ::
          {:ok, graph()} | {:error, String.t()}
  def add_unweighted_edge(graph, from, to) do
    Model.add_edge(graph, from, to, nil)
  end

  @doc """
  Adds an unweighted edge to the graph, raising on error.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_unweighted_edge!(from: 1, to: 2)
      iex> Yog.successors(graph, 1)
      [{2, nil}]
  """
  def add_unweighted_edge!(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    Model.add_edge!(graph, from, to, nil)
  end

  def add_unweighted_edge!(graph, from, to) do
    Model.add_edge!(graph, from, to, nil)
  end

  @doc """
  Adds a simple edge with weight 1.

  This is a convenience function for graphs with integer weights where
  a default weight of 1 is appropriate (e.g., unweighted graphs, hop counts).

  Returns `{:ok, graph}` or `{:error, reason}` if either endpoint node doesn't exist.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_simple_edge(from: 1, to: 2)
      iex> Yog.successors(graph, 1)
      [{2, 1}]
  """
  @spec add_simple_edge(graph(), keyword()) :: {:ok, graph()} | {:error, String.t()}
  def add_simple_edge(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    Model.add_edge(graph, from, to, 1)
  end

  @doc """
  Adds a simple edge with positional arguments (weight = 1).

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_simple_edge(1, 2)
      iex> Yog.successors(graph, 1)
      [{2, 1}]
  """
  @spec add_simple_edge(graph(), node_id(), node_id()) :: {:ok, graph()} | {:error, String.t()}
  def add_simple_edge(graph, from, to) do
    Model.add_edge(graph, from, to, 1)
  end

  @doc """
  Adds a simple edge with weight 1, raising on error.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_simple_edge!(from: 1, to: 2)
      iex> Yog.successors(graph, 1)
      [{2, 1}]
  """
  def add_simple_edge!(graph, opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    Model.add_edge!(graph, from, to, 1)
  end

  def add_simple_edge!(graph, from, to) do
    Model.add_edge!(graph, from, to, 1)
  end

  @doc """
  Adds multiple edges to the graph.

  Fails fast on the first edge that references non-existent nodes.
  Returns `{:error, reason}` if any endpoint node doesn't exist.

  This is more ergonomic than chaining multiple `add_edge` calls
  as it only requires unwrapping a single result.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}, {1, 3, 15}])
      iex> length(Yog.successors(graph, 1))
      2
  """
  @spec add_edges(graph(), [edge_tuple()]) :: {:ok, graph()} | {:error, String.t()}
  defdelegate add_edges(graph, edges), to: Model

  @doc """
  Adds multiple edges to the graph, raising on error.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}])
      iex> length(Yog.successors(graph, 1))
      1
  """
  def add_edges!(graph, edges) do
    case add_edges(graph, edges) do
      {:ok, graph} -> graph
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Adds multiple simple edges (weight = 1).

  Fails fast on the first edge that references non-existent nodes.
  Convenient for unweighted graphs where all edges have weight 1.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_simple_edges([{1, 2}, {2, 3}, {1, 3}])
      iex> length(Yog.successors(graph, 1))
      2
  """
  @spec add_simple_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  defdelegate add_simple_edges(graph, edges), to: Model

  @doc """
  Adds multiple unweighted edges (weight = nil).

  Fails fast on the first edge that references non-existent nodes.
  Convenient for graphs where edges carry no weight information.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_unweighted_edges([{1, 2}, {2, 3}, {1, 3}])
      iex> length(Yog.successors(graph, 1))
      2
  """
  @spec add_unweighted_edges(graph(), [{node_id(), node_id()}]) ::
          {:ok, graph()} | {:error, String.t()}
  defdelegate add_unweighted_edges(graph, edges), to: Model

  # ============= Query =============

  @doc """
  Gets nodes you can travel TO from the given node (successors).
  Returns a list of tuples containing the destination node ID and edge data.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> Yog.successors(graph, 1)
      [{2, 10}]
  """
  @spec successors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate successors(graph, id), to: Model

  @doc """
  Gets nodes you came FROM to reach the given node (predecessors).
  Returns a list of tuples containing the source node ID and edge data.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> Yog.predecessors(graph, 2)
      [{1, 10}]
  """
  @spec predecessors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate predecessors(graph, id), to: Model

  @doc """
  Gets node IDs you can travel TO from the given node.
  Convenient for traversal algorithms that only need the IDs.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge_ensure(1, 2, 10)
      ...>   |> Yog.add_edge_ensure(1, 3, 20)
      iex> Yog.successor_ids(graph, 1) |> Enum.sort()
      [2, 3]
  """
  @spec successor_ids(graph(), node_id()) :: [node_id()]
  defdelegate successor_ids(graph, id), to: Model

  @doc """
  Returns all neighbor node IDs (without weights).
  """
  @spec neighbor_ids(graph(), node_id()) :: [node_id()]
  defdelegate neighbor_ids(graph, id), to: Model

  @doc """
  Gets all nodes connected to the given node, regardless of direction.
  For undirected graphs, this is equivalent to successors.
  For directed graphs, this combines successors and predecessors.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge_ensure(1, 2, 10)
      ...>   |> Yog.add_edge_ensure(3, 1, 20)
      iex> length(Yog.neighbors(graph, 1))
      2
  """
  @spec neighbors(graph(), node_id()) :: [{node_id(), term()}]
  defdelegate neighbors(graph, id), to: Model

  @doc """
  Returns all unique node IDs that have edges in the graph.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> Yog.all_nodes(graph) |> Enum.sort()
      [1, 2]
  """
  @spec all_nodes(graph()) :: [node_id()]
  defdelegate all_nodes(graph), to: Model

  @doc """
  Returns all node IDs in the graph.
  """
  @spec node_ids(graph()) :: [node_id()]
  defdelegate node_ids(graph), to: Model, as: :all_nodes

  @doc """
  Returns all edges in the graph as triplets `{from, to, weight}`.
  """
  @spec all_edges(graph()) :: [{node_id(), node_id(), any()}]
  defdelegate all_edges(graph), to: Model

  @doc """
  Returns the number of nodes in the graph.
  """
  @spec node_count(graph()) :: integer()
  defdelegate node_count(graph), to: Model

  @doc """
  Returns the number of edges in the graph.
  """
  @spec edge_count(graph()) :: integer()
  defdelegate edge_count(graph), to: Model

  @doc """
  Gets the data associated with a node.
  """
  @spec node(graph(), node_id()) :: term() | nil
  defdelegate node(graph, id), to: Model

  @doc """
  Checks if the graph contains a node with the given ID.
  """
  @spec has_node?(graph(), node_id()) :: boolean()
  defdelegate has_node?(graph, id), to: Model

  @doc """
  Checks if the graph contains an edge between `src` and `dst`.
  """
  @spec has_edge?(graph(), node_id(), node_id()) :: boolean()
  defdelegate has_edge?(graph, src, dst), to: Model

  # ============= Analysis =============

  @doc """
  Determines if a graph contains any cycles.

  For directed graphs, a cycle exists if there is a path from a node back to itself.
  For undirected graphs, a cycle exists if there is a path of length >= 3 from a node back to itself,
  or a self-loop.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.cyclic?(graph)
      true
  """
  @spec cyclic?(graph()) :: boolean()
  defdelegate cyclic?(graph), to: Traversal

  @doc """
  Returns true if the graph is a tree (undirected, connected, and acyclic).
  """
  @spec tree?(graph()) :: boolean()
  defdelegate tree?(graph), to: Yog.Property.Structure

  @doc """
  Returns true if the graph is an arborescence (directed tree with a unique root).
  """
  @spec arborescence?(graph()) :: boolean()
  defdelegate arborescence?(graph), to: Yog.Property.Structure

  @doc """
  Returns the root of an arborescence, or nil if it's not an arborescence.
  """
  @spec arborescence_root(graph()) :: node_id() | nil
  defdelegate arborescence_root(graph), to: Yog.Property.Structure

  @doc """
  Returns true if the graph is complete (every pair of distinct nodes is connected).
  """
  @spec complete?(graph()) :: boolean()
  defdelegate complete?(graph), to: Yog.Property.Structure

  @doc """
  Returns true if the graph is k-regular (every node has degree exactly k).
  """
  @spec regular?(graph(), integer()) :: boolean()
  defdelegate regular?(graph, k), to: Yog.Property.Structure

  @doc """
  Extracts the k-core of a graph (maximal subgraph with minimum degree k).
  """
  @spec k_core(graph(), integer()) :: graph()
  defdelegate k_core(graph, k), to: Connectivity

  @doc """
  Determines if a graph is acyclic (contains no cycles).

  This is the logical opposite of `cyclic?`. For directed graphs, returning
  `true` means the graph is a Directed Acyclic Graph (DAG).

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.acyclic?(graph)
      true
  """
  @spec acyclic?(graph()) :: boolean()
  defdelegate acyclic?(graph), to: Traversal

  # ============= Transform =============

  @doc """
  Returns a graph where all edges have been reversed.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> transposed = Yog.transpose(graph)
      iex> Yog.successors(transposed, 2)
      [{1, 10}]
  """
  @spec transpose(graph()) :: graph()
  defdelegate transpose(graph), to: Transform

  @doc """
  Creates a new graph where node labels are transformed.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "a")
      ...>   |> Yog.add_node(2, "b")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> mapped = Yog.map_nodes(graph, &String.upcase/1)
      iex> mapped.nodes[1]
      "A"
  """
  @spec map_nodes(graph(), (any() -> any())) :: graph()
  defdelegate map_nodes(graph, func), to: Transform

  @doc """
  Creates a new graph where edge weights are transformed.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> doubled = Yog.map_edges(graph, fn w -> w * 2 end)
      iex> Yog.successors(doubled, 1)
      [{2, 20}]
  """
  @spec map_edges(graph(), (term() -> term())) :: graph()
  defdelegate map_edges(graph, func), to: Transform

  @doc """
  Updates a specific node's data using an updater function.
  """
  @spec update_node(graph(), node_id(), term(), (term() -> term())) :: graph()
  defdelegate update_node(graph, id, default, fun), to: Transform

  @doc """
  Updates a specific edge's weight/metadata.
  """
  @spec update_edge(graph(), node_id(), node_id(), term(), (term() -> term())) :: graph()
  defdelegate update_edge(graph, u, v, default, fun), to: Transform

  @doc """
  Filter nodes by a predicate. Removes nodes that don't match the predicate
  and all edges connected to them.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "keep")
      ...>   |> Yog.add_node(2, "remove")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> filtered = Yog.filter_nodes(graph, fn label -> label == "keep" end)
      iex> Yog.all_nodes(filtered)
      [1]
  """
  @spec filter_nodes(graph(), (any() -> boolean())) :: graph()
  defdelegate filter_nodes(graph, predicate), to: Transform

  @doc """
  Filter edges by a predicate. Removes edges that don't match the predicate.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 10}, {1, 3, 20}])
      iex> filtered = Yog.filter_edges(graph, fn _src, _dst, w -> w > 15 end)
      iex> Yog.successors(filtered, 1)
      [{3, 20}]
  """
  @spec filter_edges(graph(), (node_id(), node_id(), any() -> boolean())) :: graph()
  defdelegate filter_edges(graph, predicate), to: Transform

  @doc """
  Returns the complement of the graph (edges that don't exist in the original).

  The complement has edges between all pairs of nodes that are NOT connected
  in the original graph.

  ## Parameters

    * `graph` - The input graph
    * `default_weight` - Weight to assign to new edges in the complement

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> complement = Yog.complement(graph, 1)
      iex> # The complement has an edge from 2 to 1 (which didn't exist)
      iex> Yog.successors(complement, 2)
      [{1, 1}]
  """
  @spec complement(graph(), any()) :: graph()
  defdelegate complement(graph, default_weight), to: Transform

  @doc """
  Merges two graphs. Combines nodes and edges from both graphs.

  ## Example

      iex> {:ok, g1} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> {:ok, g2} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge(2, 3, 20)
      iex> merged = Yog.merge(g1, g2)
      iex> length(Yog.all_nodes(merged))
      3
  """
  @spec merge(graph(), graph()) :: graph()
  defdelegate merge(base, other), to: Transform

  @doc """
  Extracts a subgraph keeping only the specified nodes.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 20}])
      iex> subgraph = Yog.subgraph(graph, [1, 2])
      iex> Yog.all_nodes(subgraph)
      [1, 2]
  """
  @spec subgraph(graph(), [node_id()]) :: graph()
  defdelegate subgraph(graph, ids), to: Transform

  @doc """
  Converts an undirected graph to directed.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 10)
      iex> directed = Yog.to_directed(graph)
      iex> Yog.successors(directed, 1)
      [{2, 10}]
  """
  @spec to_directed(graph()) :: graph()
  defdelegate to_directed(graph), to: Transform

  @doc """
  Converts a directed graph to undirected.

  When there are edges in both directions, the `resolve_fn` is called
  to combine the weights.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 1, 20}])
      iex> undirected = Yog.to_undirected(graph, fn a, b -> min(a, b) end)
      iex> length(Yog.successors(undirected, 1))
      1
  """
  @spec to_undirected(graph(), (any(), any() -> any())) :: graph()
  defdelegate to_undirected(graph, resolve_fn), to: Transform

  @doc """
  Contracts (merges) two nodes into a single node.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 3, 10}, {2, 3, 20}])
      iex> contracted = Yog.contract(graph, 1, 2, fn a, b -> a + b end)
      iex> length(Yog.all_nodes(contracted))
      2
  """
  @spec contract(graph(), node_id(), node_id(), (any(), any() -> any())) :: graph()
  defdelegate contract(graph, merge_a, merge_b, combine_fn), to: Transform

  # ============= Construction from various formats =============

  @doc """
  Creates a graph from a list of edges.

  Auto-creates nodes with `nil` data as needed.

  ## Example

      iex> edges = [{1, 2, 10}, {2, 3, 20}]
      iex> graph = Yog.from_edges(:directed, edges)
      iex> length(Yog.successors(graph, 1))
      1
  """
  @spec from_edges(:directed | :undirected, [{node_id(), node_id(), any()}]) :: graph()
  def from_edges(type, edges) do
    Enum.reduce(edges, new(type), fn {src, dst, weight}, g ->
      Model.add_edge_ensure(g, src, dst, weight, nil)
    end)
  end

  @doc """
  Creates a graph from a list of unweighted edges (weight will be nil).

  ## Example

      iex> edges = [{1, 2}, {2, 3}]
      iex> graph = Yog.from_unweighted_edges(:directed, edges)
      iex> Yog.successors(graph, 1)
      [{2, nil}]
  """
  @spec from_unweighted_edges(:directed | :undirected, [{node_id(), node_id()}]) :: graph()
  def from_unweighted_edges(type, edges) do
    Enum.reduce(edges, new(type), fn {src, dst}, g ->
      Model.add_edge_ensure(g, src, dst, nil, nil)
    end)
  end

  # ============= Adjacency Matrix =============

  @doc """
  Creates a graph from an adjacency matrix.

  Delegates to `Yog.IO.Matrix.from_matrix/2`.

  ## Example

      iex> matrix = [[0, 1, 1], [1, 0, 0], [1, 0, 0]]
      iex> graph = Yog.from_adjacency_matrix(:undirected, matrix)
      iex> Yog.Model.order(graph)
      3
  """
  defdelegate from_adjacency_matrix(type, matrix), to: Yog.IO.Matrix, as: :from_matrix

  @doc """
  Exports a graph to an adjacency matrix representation.

  Delegates to `Yog.IO.Matrix.to_matrix/1`.

  ## Example

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> {_nodes, matrix} = Yog.to_adjacency_matrix(graph)
      iex> matrix
      [[0, 5], [5, 0]]
  """
  defdelegate to_adjacency_matrix(graph), to: Yog.IO.Matrix, as: :to_matrix

  # ============= Adjacency List (Facade) =============

  @doc """
  Creates a graph from an adjacency list.

  Delegates to `Yog.IO.List.from_list/2`.

  ## Example

      iex> entries = [{1, [{2, 1}, {3, 1}]}, {2, [{3, 1}]}, {3, []}]
      iex> graph = Yog.from_adjacency_list(:undirected, entries)
      iex> Yog.Model.order(graph)
      3
  """
  defdelegate from_adjacency_list(type, entries), to: Yog.IO.List, as: :from_list

  @doc """
  Creates a graph from an adjacency list string.

  Delegates to `Yog.IO.List.from_string/3`.

  ## Example

      iex> text = \"1: 2 3\\n2: 3\\n3:\"
      iex> graph = Yog.from_adjacency_list_string(:undirected, text)
      iex> Yog.Model.order(graph)
      3
  """
  defdelegate from_adjacency_list_string(type, string, opts \\ []),
    to: Yog.IO.List,
    as: :from_string

  @doc """
  Exports a graph to an adjacency list.

  Delegates to `Yog.IO.List.to_list/1`.

  ## Example

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> Yog.to_adjacency_list(graph)
      [{1, [{2, 5}]}, {2, [{1, 5}]}]
  """
  defdelegate to_adjacency_list(graph), to: Yog.IO.List, as: :to_list

  @doc """
  Exports a graph to an adjacency list string.

  Delegates to `Yog.IO.List.to_string/2`.

  ## Example

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> Yog.to_adjacency_list_string(graph)
      "1: 2\\n2: 1"
  """
  defdelegate to_adjacency_list_string(graph, opts \\ []), to: Yog.IO.List, as: :to_string

  # ============= Walk =============

  @doc """
  Walks the graph from a starting node.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.walk(graph, 1, :breadth_first)
      [1, 2, 3]
  """
  @spec walk(graph(), node_id(), :breadth_first | :depth_first) :: [node_id()]
  defdelegate walk(graph, start_id, order), to: Traversal

  @doc """
  Walks the graph until a condition is met.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> # Walk until we find node 3
      iex> Yog.walk_until(graph, 1, :breadth_first, fn node -> node == 3 end)
      [1, 2, 3]
  """
  @spec walk_until(graph(), node_id(), :breadth_first | :depth_first, (node_id() -> boolean())) ::
          [node_id()]
  defdelegate walk_until(graph, start_id, order, condition), to: Traversal

  @doc """
  Folds over the graph during a walk with full control.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> # Count nodes during traversal
      iex> Yog.fold_walk(graph, 1, :breadth_first, 0, fn acc, _node, _meta ->
      ...>   {Yog.continue(), acc + 1}
      ...> end)
      3
  """
  @spec fold_walk(
          graph(),
          node_id(),
          :breadth_first | :depth_first,
          acc,
          (acc, node_id(), map() -> {walk_control(), acc})
        ) :: acc
        when acc: var
  defdelegate fold_walk(graph, start_id, order, initial, folder), to: Traversal
end
