defmodule Yog.Traversal do
  @moduledoc """
  Graph traversal algorithms - systematic exploration of graph structure.

  This module provides fundamental graph traversal algorithms for visiting nodes
  in a specific order. Traversals are the foundation for most graph algorithms
  including pathfinding, connectivity analysis, and cycle detection.

  ## Traversal Orders

  | Order | Strategy | Best For |
  |-------|----------|----------|
  | [BFS](https://en.wikipedia.org/wiki/Breadth-first_search) | Level-by-level | Shortest path (unweighted), finding neighbors |
  | [DFS](https://en.wikipedia.org/wiki/Depth-first_search) | Deep exploration | Cycle detection, topological sort, connectivity |

  ## Core Functions

  - `walk/1` / `walk/3`: Simple traversals returning visited nodes in order
  - `fold_walk/1`: Generic traversal with custom fold function and metadata
  - `topological_sort/1`: Ordering for DAGs (uses Kahn's algorithm)
  - `cyclic?/1` / `acyclic?/1`: Cycle detection

  ## Walk Control

  The `fold_walk` function provides fine-grained control:
  - `:continue` - Explore this node's neighbors normally
  - `:stop` - Skip this node's neighbors but continue traversal
  - `:halt` - Stop the entire traversal immediately

  ## Time Complexity

  All traversals run in **O(V + E)** linear time, visiting each node and edge
  at most once.

  ## References

  - [Wikipedia: Graph Traversal](https://en.wikipedia.org/wiki/Graph_traversal)
  - [CP-Algorithms: DFS/BFS](https://cp-algorithms.com/graph/breadth-first-search.html)
  - [Wikipedia: Topological Sorting](https://en.wikipedia.org/wiki/Topological_sorting)

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.Model
  alias Yog.PriorityQueue, as: PQ

  @typedoc """
  Traversal order for graph walking algorithms.

  - `:breadth_first` - Breadth-First Search: visit all neighbors before going deeper.
  - `:depth_first` - Depth-First Search: visit as deep as possible before backtracking.
  """
  @type order :: :breadth_first | :depth_first

  @typedoc """
  Control flow for fold_walk traversal.

  - `:continue` - Continue exploring from this node's successors.
  - `:stop` - Stop exploring from this node (but continue with other queued nodes).
  - `:halt` - Halt the entire traversal immediately and return the accumulator.
  """
  @type walk_control :: :continue | :stop | :halt

  @typedoc """
  Metadata provided during fold_walk / implicit_fold traversal.

  - `:depth` - Distance from the start node (number of edges traversed).
  - `:parent` - The parent node that led to this node (nil for the start node).
  """
  @type walk_metadata :: %{depth: integer(), parent: Yog.node_id() | nil}

  @doc """
  Breadth-First Search order constant.

  Visit all neighbors at the current depth before going deeper.

  ## Example
      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.walk(in: graph, from: 1, using: Yog.Traversal.breadth_first())
      [1, 2, 3]
  """
  @spec breadth_first() :: :breadth_first
  def breadth_first, do: :breadth_first

  @doc """
  Depth-First Search order constant.

  Visit as deep as possible before backtracking.

  ## Example
      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.walk(in: graph, from: 1, using: Yog.Traversal.depth_first())
      [1, 2, 3]
  """
  @spec depth_first() :: :depth_first
  def depth_first, do: :depth_first

  @doc """
  Continue control constant for fold_walk.

  Use to continue exploring from the current node's successors.
  """
  @spec continue() :: :continue
  def continue, do: :continue

  @doc """
  Stop control constant for fold_walk.

  Use to stop exploring from this node (but continue with other queued nodes).
  """
  @spec stop() :: :stop
  def stop, do: :stop

  @doc """
  Halt control constant for fold_walk.

  Use to halt the entire traversal immediately and return the accumulator.
  """
  @spec halt() :: :halt
  def halt, do: :halt

  @doc """
  Walks the graph starting from the given node, visiting all reachable nodes.

  Returns a list of node IDs in the order they were visited.
  Uses successors to follow directed paths.

  ## Options

  - `:from` - Starting node ID
  - `:in` - The graph to traverse
  - `:using` - Traversal order (`:breadth_first` or `:depth_first`)

  ## Examples

  ### BFS traversal

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first)
      [1, 2, 3]

  ### DFS traversal

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "Root")
      ...>   |> Yog.add_node(2, "Left")
      ...>   |> Yog.add_node(3, "Right")
      ...>   |> Yog.add_node(4, "LL")
      ...>   |> Yog.add_edges([{1, 2, 1}, {1, 3, 1}, {2, 4, 1}])
      iex> result = Yog.Traversal.walk(in: graph, from: 1, using: :depth_first)
      iex> hd(result)
      1
  """
  @spec walk(keyword()) :: [Yog.node_id()]
  def walk(opts) do
    from = Keyword.fetch!(opts, :from)
    graph = Keyword.fetch!(opts, :in)
    order = Keyword.fetch!(opts, :using)

    fold_walk(
      over: graph,
      from: from,
      using: order,
      initial: [],
      with: fn acc, node_id, _meta -> {:continue, [node_id | acc]} end
    )
    |> Enum.reverse()
  end

  @doc """
  Walks the graph with explicit positional arguments.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 1)
      iex> Yog.Traversal.walk(graph, 1, :breadth_first)
      [1, 2]
  """
  @spec walk(Yog.graph(), Yog.node_id(), order()) :: [Yog.node_id()]
  def walk(graph, from, order) do
    walk(in: graph, from: from, using: order)
  end

  @doc """
  Walks the graph but stops early when a condition is met.

  Traverses the graph until `until` returns `true` for a node.
  Returns all nodes visited including the one that stopped traversal.

  ## Options

  - `:from` - Starting node ID
  - `:in` - The graph to traverse
  - `:using` - Traversal order (`:breadth_first` or `:depth_first`)
  - `:until` - Predicate function that returns `true` to stop

  ## Examples

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> # Stop when we find node 3
      iex> Yog.Traversal.walk_until(in: graph, from: 1, using: :breadth_first, until: fn node -> node == 3 end)
      [1, 2, 3]
  """
  @spec walk_until(keyword()) :: [Yog.node_id()]
  def walk_until(opts) do
    from = Keyword.fetch!(opts, :from)
    graph = Keyword.fetch!(opts, :in)
    order = Keyword.fetch!(opts, :using)
    should_stop = Keyword.fetch!(opts, :until)

    fold_walk(
      over: graph,
      from: from,
      using: order,
      initial: [],
      with: fn acc, node_id, _meta ->
        new_acc = [node_id | acc]

        if should_stop.(node_id) do
          {:halt, new_acc}
        else
          {:continue, new_acc}
        end
      end
    )
    |> Enum.reverse()
  end

  @doc """
  Walks the graph with explicit positional arguments until a condition is met.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.walk_until(graph, 1, :breadth_first, fn node -> node == 3 end)
      [1, 2, 3]
  """
  @spec walk_until(Yog.graph(), Yog.node_id(), order(), (Yog.node_id() -> boolean())) ::
          [Yog.node_id()]
  def walk_until(graph, from, order, should_stop) do
    walk_until(in: graph, from: from, using: order, until: should_stop)
  end

  @doc """
  Folds over nodes during graph traversal, accumulating state with metadata.

  This function combines traversal with state accumulation, providing metadata
  about each visited node (depth and parent). The folder function controls the
  traversal flow:

  - `:continue` - Explore successors of the current node normally
  - `:stop` - Skip successors of this node, but continue processing other queued nodes
  - `:halt` - Stop the entire traversal immediately and return the accumulator

  **Time Complexity:** O(V + E) for both BFS and DFS

  ## Options

  - `:over` - The graph to traverse
  - `:from` - Starting node ID
  - `:using` - `:breadth_first` or `:depth_first`
  - `:initial` - Initial accumulator value
  - `:with` - Folder function `(acc, node_id, metadata) -> {control, acc}`

  The `metadata` is a map with `:depth` and `:parent` keys.

  ## Examples

  ### Find all nodes within distance 3 from start

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> nearby = Yog.Traversal.fold_walk(
      ...>   over: graph,
      ...>   from: 1,
      ...>   using: :breadth_first,
      ...>   initial: [],
      ...>   with: fn acc, node_id, meta ->
      ...>     if meta.depth <= 2 do
      ...>       {:continue, [node_id | acc]}
      ...>     else
      ...>       {:stop, acc}
      ...>     end
      ...>   end
      ...> )
      iex> Enum.sort(nearby)
      [1, 2, 3]

  ### Stop immediately when target is found (like walk_until)

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "Start")
      ...>   |> Yog.add_node(2, "Middle")
      ...>   |> Yog.add_node(3, "Target")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> target = 3
      iex> path = Yog.Traversal.fold_walk(
      ...>   over: graph,
      ...>   from: 1,
      ...>   using: :breadth_first,
      ...>   initial: [],
      ...>   with: fn acc, node_id, _meta ->
      ...>     new_acc = [node_id | acc]
      ...>     if node_id == target do
      ...>       {:halt, new_acc}
      ...>     else
      ...>       {:continue, new_acc}
      ...>     end
      ...>   end
      ...> )
      iex> hd(path)
      3

  ### Build a parent map for path reconstruction

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> parents = Yog.Traversal.fold_walk(
      ...>   over: graph,
      ...>   from: 1,
      ...>   using: :breadth_first,
      ...>   initial: %{},
      ...>   with: fn acc, node_id, meta ->
      ...>     new_acc = if meta.parent, do: Map.put(acc, node_id, meta.parent), else: acc
      ...>     {:continue, new_acc}
      ...>   end
      ...> )
      iex> parents[3]
      2

  ## Use Cases

  - Finding nodes within a certain distance
  - Building shortest path trees (parent pointers)
  - Collecting nodes with custom filtering logic
  - Computing statistics during traversal (depth distribution, etc.)
  - BFS/DFS with early termination based on accumulated state
  """
  @spec fold_walk(keyword()) :: any()
  def fold_walk(opts) do
    graph = Keyword.fetch!(opts, :over)
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    folder = Keyword.fetch!(opts, :with)

    start_metadata = %{depth: 0, parent: nil}

    case order do
      :breadth_first ->
        do_fold_walk_bfs(
          graph,
          :queue.in({from, start_metadata}, :queue.new()),
          MapSet.new(),
          initial,
          folder
        )

      :depth_first ->
        do_fold_walk_dfs(
          graph,
          [{from, start_metadata}],
          MapSet.new(),
          initial,
          folder
        )
    end
  end

  @doc """
  Folds over the graph with explicit positional arguments.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edge(1, 2, 1)
      iex> Yog.Traversal.fold_walk(graph, 1, :breadth_first, 0, fn acc, _node, _meta ->
      ...>   {:continue, acc + 1}
      ...> end)
      2
  """
  @spec fold_walk(
          Yog.graph(),
          Yog.node_id(),
          order(),
          acc,
          (acc, Yog.node_id(), walk_metadata() -> {walk_control(), acc})
        ) :: acc
        when acc: var
  def fold_walk(graph, from, order, initial, folder) do
    fold_walk(over: graph, from: from, using: order, initial: initial, with: folder)
  end

  @doc """
  Traverse implicit graphs using BFS or DFS without materializing a `Graph`.

  Unlike `fold_walk`, this does not require a materialised `Graph` value.
  Instead, you supply a `successors_of` function that computes neighbours
  on the fly — ideal for infinite grids, state-space search, or any
  graph that is too large or expensive to build upfront.

  ## Options

  - `:from` - Starting state
  - `:using` - `:breadth_first` or `:depth_first`
  - `:initial` - Initial accumulator value
  - `:successors_of` - `fn state -> [state]`
  - `:with` - Folder `(acc, state, metadata) -> {control, acc}`

  The metadata map has `:depth` and `:parent` keys.

  ## Example

      iex> # BFS shortest path in an implicit chain
      iex> successors = fn n -> if n < 5, do: [n + 1], else: [] end
      iex> result = Yog.Traversal.implicit_fold(
      ...>   from: 1,
      ...>   using: :breadth_first,
      ...>   initial: [],
      ...>   successors_of: successors,
      ...>   with: fn acc, node, _meta -> {:continue, [node | acc]} end
      ...> )
      iex> Enum.sort(result)
      [1, 2, 3, 4, 5]
  """
  @spec implicit_fold(keyword()) :: any()
  def implicit_fold(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    start_meta = %{depth: 0, parent: nil}

    case order do
      :breadth_first ->
        do_implicit_bfs(
          :queue.in({from, start_meta}, :queue.new()),
          MapSet.new(),
          initial,
          successors,
          folder
        )

      :depth_first ->
        do_implicit_dfs(
          [{from, start_meta}],
          MapSet.new(),
          initial,
          successors,
          folder
        )
    end
  end

  @doc """
  Like `implicit_fold/1`, but deduplicates visited nodes by a custom key.

  This is essential when your node type carries extra state beyond what
  defines "identity". For example, in state-space search you might have
  `{position, mask}` nodes, but only want to visit each `position` once —
  the `mask` is just carried state, not part of the identity.

  The `visited_by` function extracts the deduplication key from each node.
  Internally, a `MapSet` tracks which keys have been visited, but the
  full node value (with all its state) is still passed to your folder.

  **Time Complexity:** O(V + E) for both BFS and DFS, where V and E are
  measured in terms of unique *keys* (not unique nodes).

  ## Options

  - `:from` - Starting state
  - `:using` - `:breadth_first` or `:depth_first`
  - `:initial` - Initial accumulator value
  - `:successors_of` - `fn state -> [state]`
  - `:visited_by` - `fn state -> key` for deduplication
  - `:with` - Folder `(acc, state, metadata) -> {control, acc}`

  ## Example

      iex> # Search with state that includes extra data
      iex> successors = fn {pos, _extra} ->
      ...>   if pos < 3, do: [{pos + 1, :new_data}], else: []
      ...> end
      iex> visited_by = fn {pos, _} -> pos end
      iex> result = Yog.Traversal.implicit_fold_by(
      ...>   from: {1, :initial},
      ...>   using: :breadth_first,
      ...>   initial: [],
      ...>   successors_of: successors,
      ...>   visited_by: visited_by,
      ...>   with: fn acc, {pos, _}, _meta -> {:continue, [pos | acc]} end
      ...> )
      iex> Enum.sort(result)
      [1, 2, 3]
  """
  @spec implicit_fold_by(keyword()) :: any()
  def implicit_fold_by(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    key_fn = Keyword.fetch!(opts, :visited_by)
    folder = Keyword.fetch!(opts, :with)

    start_meta = %{depth: 0, parent: nil}

    case order do
      :breadth_first ->
        do_implicit_bfs_by(
          :queue.in({from, start_meta}, :queue.new()),
          MapSet.new(),
          initial,
          successors,
          key_fn,
          folder
        )

      :depth_first ->
        do_implicit_dfs_by(
          [{from, start_meta}],
          MapSet.new(),
          initial,
          successors,
          key_fn,
          folder
        )
    end
  end

  @doc """
  Determines if a graph contains any cycles.

  For directed graphs, a cycle exists if there is a path from a node back to itself
  (evaluated efficiently via Kahn's algorithm).

  A cycle in an undirected graph is a path that starts and ends at the same vertex,
  traverses edges only once, and contains at least three vertices, or has a self-loop.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.Traversal.cyclic?(graph)
      true
  """
  @spec cyclic?(Yog.graph()) :: boolean()
  def cyclic?(graph) do
    case graph.kind do
      :directed ->
        case topological_sort(graph) do
          {:error, :contains_cycle} -> true
          _ -> false
        end

      :undirected ->
        nodes = Model.all_nodes(graph)
        do_has_undirected_cycle(graph, nodes, MapSet.new())
    end
  end

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
      iex> Yog.Traversal.acyclic?(graph)
      true
  """
  @spec acyclic?(Yog.graph()) :: boolean()
  def acyclic?(graph) do
    not cyclic?(graph)
  end

  @doc """
  Performs a topological sort on a directed graph using Kahn's algorithm.

  Returns a linear ordering of nodes such that for every directed edge (u, v),
  node u comes before node v in the ordering.

  Returns `{:error, :contains_cycle}` if the graph contains a cycle.

  **Time Complexity:** O(V + E) where V is vertices and E is edges

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.topological_sort(graph)
      {:ok, [1, 2, 3]}

      iex> # Graph with cycle
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}])
      iex> Yog.Traversal.topological_sort(graph)
      {:error, :contains_cycle}
  """
  @spec topological_sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    all_nodes = Model.all_nodes(graph)
    %Yog.Graph{in_edges: in_edges} = graph

    in_degrees =
      Enum.map(all_nodes, fn id ->
        degree =
          case Map.fetch(in_edges, id) do
            {:ok, inner} -> map_size(inner)
            :error -> 0
          end

        {id, degree}
      end)
      |> Map.new()

    queue =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _} -> id end)

    do_kahn(graph, queue, in_degrees, [], length(all_nodes))
  end

  @doc """
  Finds the shortest path between two nodes using BFS.

  Returns a list of node IDs representing the path from `from` to `to`,
  or `nil` if no path exists.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Traversal.find_path(graph, 1, 3)
      [1, 2, 3]

      iex> # No path exists
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      iex> Yog.Traversal.find_path(graph, 1, 2)
      nil

      iex> # Same node
      iex> graph = Yog.directed() |> Yog.add_node(1, "A")
      iex> Yog.Traversal.find_path(graph, 1, 1)
      [1]
  """
  @spec find_path(Yog.graph(), Yog.node_id(), Yog.node_id()) :: [Yog.node_id()] | nil
  def find_path(graph, from, to) do
    parents =
      fold_walk(
        over: graph,
        from: from,
        using: :breadth_first,
        initial: %{},
        with: fn acc, node_id, meta ->
          new_acc =
            if meta.parent && !Map.has_key?(acc, node_id) do
              Map.put(acc, node_id, meta.parent)
            else
              acc
            end

          if node_id == to do
            {:halt, new_acc}
          else
            {:continue, new_acc}
          end
        end
      )

    cond do
      from == to ->
        [from]

      !Map.has_key?(parents, to) ->
        nil

      true ->
        # Reconstruct path
        reconstruct_path(parents, to, [to])
    end
  end

  defp reconstruct_path(_parents, node, acc) when node == nil, do: acc

  defp reconstruct_path(parents, node, acc) do
    case Map.get(parents, node) do
      nil -> acc
      parent -> reconstruct_path(parents, parent, [parent | acc])
    end
  end

  @doc """
  Traverse an implicit weighted graph using Dijkstra's algorithm.

  Like `implicit_fold` but uses a priority queue so nodes are visited
  cheapest-first. Ideal for shortest-path problems on implicit state spaces
  where edge costs vary.

  ## Options

  - `:from` - Starting node
  - `:initial` - Initial accumulator value
  - `:successors_of` - `fn node -> [{neighbor, cost}]`
  - `:with` - Folder `(acc, node, cost_so_far) -> {control, acc}`

  ## Example

      iex> # Shortest path in an implicit chain
      iex> successors = fn n ->
      ...>   if n < 5, do: [{n + 1, 10}], else: []
      ...> end
      iex> result = Yog.Traversal.implicit_dijkstra(
      ...>   from: 1,
      ...>   initial: -1,
      ...>   successors_of: successors,
      ...>   with: fn _acc, node, cost ->
      ...>     if node == 5, do: {:halt, cost}, else: {:continue, -1}
      ...>   end
      ...> )
      iex> # Path: 1->2->3->4->5 = 4 edges * 10 = 40
      iex> result
      40
  """
  @spec implicit_dijkstra(keyword()) :: any()
  def implicit_dijkstra(opts) do
    from = Keyword.fetch!(opts, :from)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    # Priority queue using pairing heap: min-heap ordered by cost
    frontier =
      PQ.new(fn {cost_a, _}, {cost_b, _} -> cost_a <= cost_b end)
      |> PQ.push({0, from})

    best = %{}

    do_implicit_dijkstra_pq(frontier, best, initial, successors, folder)
  end

  defp do_implicit_dijkstra_pq(pq, best, acc, successors, folder) do
    if PQ.empty?(pq) do
      acc
    else
      {:ok, {cost, node}, rest_pq} = PQ.pop(pq)

      # Skip if we've already found a better path to this node
      case Map.get(best, node) do
        nil ->
          new_best = Map.put(best, node, cost)
          {control, new_acc} = folder.(acc, node, cost)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_dijkstra_pq(rest_pq, new_best, new_acc, successors, folder)

            :continue ->
              next_pq =
                Enum.reduce(successors.(node), rest_pq, fn {nb_node, edge_cost}, acc_pq ->
                  new_cost = cost + edge_cost

                  # Only add if we haven't seen this node or found a better path
                  case Map.get(new_best, nb_node) do
                    nil -> PQ.push(acc_pq, {new_cost, nb_node})
                    prev_cost when prev_cost <= new_cost -> acc_pq
                    _ -> PQ.push(acc_pq, {new_cost, nb_node})
                  end
                end)

              do_implicit_dijkstra_pq(next_pq, new_best, new_acc, successors, folder)
          end

        prev_cost when prev_cost < cost ->
          # Stale entry - skip
          do_implicit_dijkstra_pq(rest_pq, best, acc, successors, folder)

        _ ->
          # Same or better cost already recorded
          do_implicit_dijkstra_pq(rest_pq, best, acc, successors, folder)
      end
    end
  end

  @doc """
  Performs a lexicographically smallest topological sort.

  Uses a priority queue (pairing heap) version of Kahn's algorithm to ensure
  that when multiple nodes have in-degree 0, the smallest one (according to
  `compare_nodes`) is chosen first.

  The comparison function operates on **node data**, not node IDs.

  Returns `{:error, :contains_cycle}` if the graph contains a cycle.

  **Time Complexity:** O(V log V + E) due to heap operations

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "c")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "b")
      ...>   |> Yog.add_edges!([{1, 3, 1}, {2, 3, 1}])
      iex> Yog.Traversal.lexicographical_topological_sort(graph, fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      {:ok, [2, 1, 3]}  # "a" comes before "c"
  """
  @spec lexicographical_topological_sort(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_topological_sort(graph, compare_nodes) do
    all_nodes = Model.all_nodes(graph)
    %Yog.Graph{nodes: nodes, in_edges: in_edges} = graph

    in_degrees =
      Enum.map(all_nodes, fn id ->
        degree =
          case Map.fetch(in_edges, id) do
            {:ok, inner} -> map_size(inner)
            :error -> 0
          end

        {id, degree}
      end)
      |> Map.new()

    # Create a priority queue with custom comparator based on node data
    # We store {node_data, node_id} pairs and compare by node_data
    pq_compare = fn {data_a, id_a}, {data_b, id_b} ->
      compare_nodes.(data_a, data_b) == :lt or
        (compare_nodes.(data_a, data_b) == :eq and id_a <= id_b)
    end

    pq = PQ.new(pq_compare)

    initial_pq =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _} -> {Map.get(nodes, id), id} end)
      |> Enum.reduce(pq, fn item, acc -> PQ.push(acc, item) end)

    do_lexical_kahn_pq(graph, initial_pq, in_degrees, [], length(all_nodes), nodes)
  end

  defp do_lexical_kahn_pq(_graph, _pq, _in_degrees, acc, total_count, _nodes)
       when total_count == 0 do
    if Enum.empty?(acc) do
      {:ok, []}
    else
      {:ok, Enum.reverse(acc)}
    end
  end

  defp do_lexical_kahn_pq(graph, pq, in_degrees, acc, total_count, nodes) do
    if PQ.empty?(pq) do
      if length(acc) == total_count do
        {:ok, Enum.reverse(acc)}
      else
        {:error, :contains_cycle}
      end
    else
      {:ok, {_, head}, rest_pq} = PQ.pop(pq)
      do_lexical_kahn_pq_step(graph, rest_pq, in_degrees, [head | acc], total_count, nodes)
    end
  end

  defp do_lexical_kahn_pq_step(graph, pq, in_degrees, acc, total_count, nodes) do
    head = hd(acc)
    neighbors = Model.successor_ids(graph, head)

    {next_pq, next_in_degrees} =
      Enum.reduce(neighbors, {pq, in_degrees}, fn neighbor, {acc_pq, degrees} ->
        current_degree = Map.get(degrees, neighbor, 0)
        new_degree = current_degree - 1
        new_degrees = Map.put(degrees, neighbor, new_degree)

        updated_pq =
          if new_degree == 0 do
            neighbor_data = Map.get(nodes, neighbor)
            PQ.push(acc_pq, {neighbor_data, neighbor})
          else
            acc_pq
          end

        {updated_pq, new_degrees}
      end)

    do_lexical_kahn_pq(graph, next_pq, next_in_degrees, acc, total_count, nodes)
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  # BFS with fold and metadata
  defp do_fold_walk_bfs(graph, q, visited, acc, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_bfs(graph, rest, visited, acc, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_bfs(graph, rest, new_visited, new_acc, folder)

            :continue ->
              next_nodes = Model.successor_ids(graph, node_id)

              next_queue =
                Enum.reduce(next_nodes, rest, fn next_id, current_queue ->
                  next_meta = %{
                    depth: metadata.depth + 1,
                    parent: node_id
                  }

                  :queue.in({next_id, next_meta}, current_queue)
                end)

              do_fold_walk_bfs(graph, next_queue, new_visited, new_acc, folder)
          end
        end
    end
  end

  # DFS with fold and metadata
  defp do_fold_walk_dfs(graph, stack, visited, acc, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_dfs(graph, tail, visited, acc, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_dfs(graph, tail, new_visited, new_acc, folder)

            :continue ->
              next_nodes = Model.successor_ids(graph, node_id)

              next_stack =
                Enum.reduce(Enum.reverse(next_nodes), tail, fn next_id, current_stack ->
                  next_meta = %{
                    depth: metadata.depth + 1,
                    parent: node_id
                  }

                  [{next_id, next_meta} | current_stack]
                end)

              do_fold_walk_dfs(graph, next_stack, new_visited, new_acc, folder)
          end
        end
    end
  end

  # Implicit BFS: same as do_fold_walk_bfs but uses a successors function
  defp do_implicit_bfs(q, visited, acc, successors, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        if MapSet.member?(visited, node_id) do
          do_implicit_bfs(rest, visited, acc, successors, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_bfs(rest, new_visited, new_acc, successors, folder)

            :continue ->
              next_queue =
                Enum.reduce(successors.(node_id), rest, fn next_id, q2 ->
                  :queue.in(
                    {next_id, %{depth: metadata.depth + 1, parent: node_id}},
                    q2
                  )
                end)

              do_implicit_bfs(next_queue, new_visited, new_acc, successors, folder)
          end
        end
    end
  end

  # Implicit DFS: same as do_fold_walk_dfs but uses a successors function
  defp do_implicit_dfs(stack, visited, acc, successors, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        if MapSet.member?(visited, node_id) do
          do_implicit_dfs(tail, visited, acc, successors, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_dfs(tail, new_visited, new_acc, successors, folder)

            :continue ->
              next_stack =
                Enum.reduce(Enum.reverse(successors.(node_id)), tail, fn next_id, stk ->
                  [{next_id, %{depth: metadata.depth + 1, parent: node_id}} | stk]
                end)

              do_implicit_dfs(next_stack, new_visited, new_acc, successors, folder)
          end
        end
    end
  end

  # Implicit BFS with custom key function for deduplication
  defp do_implicit_bfs_by(q, visited, acc, successors, key_fn, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        node_key = key_fn.(node_id)

        if MapSet.member?(visited, node_key) do
          do_implicit_bfs_by(rest, visited, acc, successors, key_fn, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_key)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_bfs_by(rest, new_visited, new_acc, successors, key_fn, folder)

            :continue ->
              next_queue =
                Enum.reduce(successors.(node_id), rest, fn next_id, q2 ->
                  :queue.in(
                    {next_id, %{depth: metadata.depth + 1, parent: node_id}},
                    q2
                  )
                end)

              do_implicit_bfs_by(next_queue, new_visited, new_acc, successors, key_fn, folder)
          end
        end
    end
  end

  # Implicit DFS with custom key function for deduplication
  defp do_implicit_dfs_by(stack, visited, acc, successors, key_fn, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        node_key = key_fn.(node_id)

        if MapSet.member?(visited, node_key) do
          do_implicit_dfs_by(tail, visited, acc, successors, key_fn, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_key)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_dfs_by(tail, new_visited, new_acc, successors, key_fn, folder)

            :continue ->
              next_stack =
                Enum.reduce(Enum.reverse(successors.(node_id)), tail, fn next_id, stk ->
                  [{next_id, %{depth: metadata.depth + 1, parent: node_id}} | stk]
                end)

              do_implicit_dfs_by(next_stack, new_visited, new_acc, successors, key_fn, folder)
          end
        end
    end
  end

  # Kahn's algorithm for topological sort
  defp do_kahn(_graph, [], _in_degrees, acc, total_count) do
    if length(acc) == total_count do
      {:ok, Enum.reverse(acc)}
    else
      {:error, :contains_cycle}
    end
  end

  defp do_kahn(graph, [head | tail], in_degrees, acc, total_count) do
    neighbors = Model.successor_ids(graph, head)

    {next_queue, next_in_degrees} =
      Enum.reduce(neighbors, {tail, in_degrees}, fn neighbor, {q, degrees} ->
        current_degree = Map.get(degrees, neighbor, 0)
        new_degree = current_degree - 1
        new_degrees = Map.put(degrees, neighbor, new_degree)

        new_q =
          if new_degree == 0 do
            [neighbor | q]
          else
            q
          end

        {new_q, new_degrees}
      end)

    do_kahn(graph, next_queue, next_in_degrees, [head | acc], total_count)
  end

  # Check for cycles in undirected graphs
  defp do_has_undirected_cycle(_graph, [], _visited), do: false

  defp do_has_undirected_cycle(graph, [node | rest], visited) do
    if MapSet.member?(visited, node) do
      do_has_undirected_cycle(graph, rest, visited)
    else
      {cycle?, new_visited} = check_undirected_cycle(graph, node, nil, visited)

      if cycle? do
        true
      else
        do_has_undirected_cycle(graph, rest, new_visited)
      end
    end
  end

  defp check_undirected_cycle(graph, node, parent, visited) do
    new_visited = MapSet.put(visited, node)
    neighbors = Model.successor_ids(graph, node)

    Enum.reduce_while(neighbors, {false, new_visited}, fn neighbor, {_, current_visited} ->
      if MapSet.member?(current_visited, neighbor) do
        is_parent = parent == neighbor

        if is_parent do
          {:cont, {false, current_visited}}
        else
          {:halt, {true, current_visited}}
        end
      else
        {has_cycle?, next_visited} =
          check_undirected_cycle(graph, neighbor, node, current_visited)

        if has_cycle? do
          {:halt, {true, next_visited}}
        else
          {:cont, {false, next_visited}}
        end
      end
    end)
  end
end
