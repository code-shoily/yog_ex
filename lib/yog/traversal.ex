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
  - `is_cyclic/1` / `is_acyclic/1`: Cycle detection

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
  """

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

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.walk(graph, from, gleam_order)
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
    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.walk(graph, from, gleam_order)
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

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.walk_until(graph, from, gleam_order, should_stop)
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
    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.walk_until(graph, from, gleam_order, should_stop)
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

    # Wrap the Elixir folder to bridge the Gleam WalkMetadata type
    gleam_folder = fn acc, node_id, walk_metadata ->
      # WalkMetadata is {:walk_metadata, depth, parent}
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node_id, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.fold_walk(graph, from, gleam_order, initial, gleam_folder)
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
    gleam_folder = fn acc, node_id, walk_metadata ->
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node_id, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.fold_walk(graph, from, gleam_order, initial, gleam_folder)
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

    gleam_folder = fn acc, node, walk_metadata ->
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    :yog@traversal.implicit_fold(from, order, initial, successors, gleam_folder)
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

      iex> # Search where nodes carry both value and step count
      iex> # but we only want to visit each value once (first-visit wins)
      iex> successors = fn {pos, steps} ->
      ...>   if pos < 5, do: [{pos + 1, steps + 1}], else: []
      ...> end
      iex> result = Yog.Traversal.implicit_fold_by(
      ...>   from: {1, 0},
      ...>   using: :breadth_first,
      ...>   initial: [],
      ...>   successors_of: successors,
      ...>   visited_by: fn {pos, _steps} -> pos end,
      ...>   with: fn acc, {pos, _steps}, _meta -> {:continue, [pos | acc]} end
      ...> )
      iex> Enum.sort(result)
      [1, 2, 3, 4, 5]

  ## Use Cases

  - **Puzzle solving**: `{board_state, moves}` → dedupe by `board_state`
  - **Path finding with budget**: `{pos, fuel_left}` → dedupe by `pos`
  - **Game state search**: `{position, inventory}` → dedupe by `position`
  - **Graph search with metadata**: `{node_id, path_history}` → dedupe by `node_id`

  ## Comparison to `implicit_fold`

  - `implicit_fold`: Deduplicates by the entire node value
  - `implicit_fold_by`: Deduplicates by `visited_by(node)` but keeps full node

  Similar to SQL's `DISTINCT ON(key)` or Python's `key=` parameter.
  """
  @spec implicit_fold_by(keyword()) :: any()
  def implicit_fold_by(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    visited_by = Keyword.fetch!(opts, :visited_by)
    folder = Keyword.fetch!(opts, :with)

    gleam_folder = fn acc, node, walk_metadata ->
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    :yog@traversal.implicit_fold_by(from, order, initial, successors, visited_by, gleam_folder)
  end

  @doc """
  Traverses an *implicit* weighted graph using Dijkstra's algorithm,
  folding over visited nodes in order of increasing cost.

  Like `implicit_fold` but uses a priority queue so nodes are visited
  cheapest-first. Ideal for shortest-path problems on implicit state spaces
  where edge costs vary — e.g., state-space search with Manhattan moves, or
  multi-robot coordination where multiple robots share a key-bitmask state.

  - `successors_of`: Given a node, return `[{neighbor, edge_cost}]`.
    Include only valid transitions (filtering here avoids dead states).
  - `with`: Called once per node, with `(acc, node, cost_so_far)`.
    Return `{:halt, result}` to stop immediately, `{:stop, acc}` to skip
    expanding this node's successors, or `{:continue, acc}` to continue.

  Internally maintains a map of best-known costs;
  stale priority-queue entries are automatically skipped.

  ## Options

  - `:from` - Starting state
  - `:initial` - Initial accumulator value
  - `:successors_of` - `fn state -> [{neighbor, cost}]` returns neighbors with edge costs
  - `:with` - Folder function `(acc, node, cost_so_far) -> {control, acc}`

  The folder receives the accumulated cost to reach the node as the third argument.
  Control values: `:continue`, `:stop`, `:halt`.

  ## Examples

      iex> # Find shortest path cost to target
      iex> successors = fn n ->
      ...>   if n < 5 do
      ...>     [{n + 1, 10}]
      ...>   else
      ...>     []
      ...>   end
      ...> end
      iex> result = Yog.Traversal.implicit_dijkstra(
      ...>   from: 1,
      ...>   initial: -1,
      ...>   successors_of: successors,
      ...>   with: fn _acc, node, cost ->
      ...>     if node == 5 do
      ...>       {:halt, cost}
      ...>     else
      ...>       {:continue, -1}
      ...>     end
      ...>   end
      ...> )
      iex> result
      40

  ### Two paths to goal: expensive direct vs cheap indirect

      iex> successors = fn pos ->
      ...>   case pos do
      ...>     1 -> [{2, 100}, {3, 10}]
      ...>     2 -> [{4, 1}]
      ...>     3 -> [{2, 5}]
      ...>     _ -> []
      ...>   end
      ...> end
      iex> result = Yog.Traversal.implicit_dijkstra(
      ...>   from: 1,
      ...>   initial: -1,
      ...>   successors_of: successors,
      ...>   with: fn _acc, node, cost ->
      ...>     if node == 2 do
      ...>       {:halt, cost}
      ...>     else
      ...>       {:continue, -1}
      ...>     end
      ...>   end
      ...> )
      iex> result
      15
  """
  @spec implicit_dijkstra(keyword()) :: any()
  def implicit_dijkstra(opts) do
    from = Keyword.fetch!(opts, :from)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    gleam_folder = fn acc, node, cost ->
      case folder.(acc, node, cost) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    :yog@traversal.implicit_dijkstra(from, initial, successors, gleam_folder)
  end

  @doc """
  Determines if a graph contains any cycles.

  For directed graphs, a cycle exists if there is a path from a node back to itself
  (evaluated efficiently via Kahn's algorithm).

  A cycle in an undirected graph is a path that starts and ends at the same vertex,
  traverses edges only once, and contains at least three vertices, or has a self-loop.

  **Time Complexity:** O(V + E)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.Traversal.is_cyclic(graph)
      true
  """
  @spec is_cyclic(Yog.graph()) :: boolean()
  defdelegate is_cyclic(graph), to: :yog@traversal

  @doc """
  Determines if a graph is acyclic (contains no cycles).

  This is the logical opposite of `is_cyclic`. For directed graphs, returning
  `true` means the graph is a Directed Acyclic Graph (DAG).

  **Time Complexity:** O(V + E)

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.is_acyclic(graph)
      true
  """
  @spec is_acyclic(Yog.graph()) :: boolean()
  defdelegate is_acyclic(graph), to: :yog@traversal

  @doc """
  Performs a topological sort on a directed graph using Kahn's algorithm.

  Returns a linear ordering of nodes such that for every directed edge (u, v),
  node u comes before node v in the ordering.

  Returns `{:error, :contains_cycle}` if the graph contains a cycle.

  **Time Complexity:** O(V + E) where V is vertices and E is edges

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.topological_sort(graph)
      {:ok, [1, 2, 3]}

  iex> # Cycle detection
  iex> {:ok, cyclic_graph} =
  ...>   Yog.directed()
  ...>   |> Yog.add_node(1, "A")
  ...>   |> Yog.add_node(2, "B")
  ...>   |> Yog.add_edges([{1, 2, 1}, {2, 1, 1}])
  iex> Yog.Traversal.topological_sort(cyclic_graph)
  {:error, :contains_cycle}
  """
  @spec topological_sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    case :yog@traversal.topological_sort(graph) do
      {:ok, order} -> {:ok, order}
      {:error, nil} -> {:error, :contains_cycle}
    end
  end

  @doc """
  Performs a lexicographical topological sort.

  When multiple nodes are available to be placed next in the sorted order, this
  variant strictly prefers the node with the "smallest" value based on the provided
  `compare` function, which operates on **node data** (not node IDs).

  Uses a heap-based version of Kahn's algorithm to ensure that when multiple
  nodes have in-degree 0, the smallest one (according to `compare_nodes`) is chosen first.

  The comparison function operates on **node data**, not node IDs, allowing intuitive
  comparisons like alphabetical ordering for strings.

  Returns `{:error, :contains_cycle}` if the graph contains a cycle.

  **Time Complexity:** O(V log V + E) due to heap operations

  ## Examples

  ### Get alphabetical ordering by node data

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "charlie")
      ...>   |> Yog.add_node(2, "alpha")
      ...>   |> Yog.add_node(3, "bravo")
      ...>   |> Yog.add_edges([{1, 3, 1}, {3, 2, 1}])
      iex> {:ok, order} = Yog.Traversal.lexicographical_topological_sort(graph, &<=/2)
      iex> order
      [1, 3, 2]

  ### Custom comparison by priority

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, %{priority: 3})
      ...>   |> Yog.add_node(2, %{priority: 1})
      ...>   |> Yog.add_node(3, %{priority: 2})
      ...>   |> Yog.add_edges([{2, 3, 1}, {3, 1, 1}])
      iex> {:ok, order} = Yog.Traversal.lexicographical_topological_sort(
      ...>   graph,
      ...>   fn a, b -> a.priority <= b.priority end
      ...> )
      iex> order
      [2, 3, 1]
  """
  @spec lexicographical_topological_sort(Yog.graph(), (any(), any() -> boolean())) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_topological_sort(graph, compare_fn) do
    case :yog@traversal.lexicographical_topological_sort(graph, compare_fn) do
      {:ok, order} -> {:ok, order}
      {:error, nil} -> {:error, :contains_cycle}
    end
  end

  @doc """
  Finds the shortest path between two nodes in an unweighted graph using BFS.

  Returns a list of node IDs forming the path, or `nil` if no path exists.

  This is an Elixir-specific helper function that builds on `fold_walk`.

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.find_path(graph, 1, 3)
      [1, 2, 3]

  ### No path exists

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      iex> Yog.Traversal.find_path(graph, 1, 2)
      nil

  ### Self path

      iex> graph = Yog.directed() |> Yog.add_node(1, "A")
      iex> Yog.Traversal.find_path(graph, 1, 1)
      [1]
  """
  @spec find_path(Yog.graph(), Yog.node_id(), Yog.node_id()) :: [Yog.node_id()] | nil
  def find_path(graph, from, to) do
    if from == to do
      [from]
    else
      # We use fold_walk to build a parent map using BFS (shortest path for unweighted).
      parents =
        fold_walk(
          over: graph,
          from: from,
          using: :breadth_first,
          initial: %{},
          with: fn acc, node, meta ->
            acc = if meta.parent, do: Map.put(acc, node, meta.parent), else: acc

            if node == to do
              {:halt, acc}
            else
              {:continue, acc}
            end
          end
        )

      if Map.has_key?(parents, to) do
        reconstruct_path(parents, from, to, [to])
      else
        nil
      end
    end
  end

  defp reconstruct_path(_parents, start, start, path), do: path

  defp reconstruct_path(parents, start, target, path) do
    parent = Map.get(parents, target)
    reconstruct_path(parents, start, parent, [parent | path])
  end
end
