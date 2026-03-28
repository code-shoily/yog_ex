defmodule Yog.Traversal do
  @moduledoc """
  Graph traversal algorithms - systematic exploration of graph structure.

  This module provides a unified API for fundamental graph traversal algorithms.

  ## Submodules

  - `Yog.Traversal.Walk` — BFS/DFS walking, fold traversal, and path finding.
  - `Yog.Traversal.Sort` — Topological sorting (Kahn's and lexicographic).
  - `Yog.Traversal.Cycle` — Cycle detection for directed and undirected graphs.
  - `Yog.Traversal.Implicit` — Implicit graph traversal (BFS, DFS, Dijkstra) on
    graphs defined by successor functions.

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
  """

  alias Yog.Traversal.Cycle
  alias Yog.Traversal.Implicit
  alias Yog.Traversal.Sort
  alias Yog.Traversal.Walk

  @type order :: Walk.order()
  @type walk_control :: Walk.walk_control()
  @type walk_metadata :: Walk.walk_metadata()

  # ============= Constants =============

  @doc """
  Breadth-First Search order constant.

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

  @doc "Continue control constant for fold_walk."
  @spec continue() :: :continue
  def continue, do: :continue

  @doc "Stop control constant for fold_walk."
  @spec stop() :: :stop
  def stop, do: :stop

  @doc "Halt control constant for fold_walk."
  @spec halt() :: :halt
  def halt, do: :halt

  # ============= Walk =============

  @doc """
  Walks the graph starting from the given node, visiting all reachable nodes.

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
  defdelegate walk(opts), to: Walk

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
  defdelegate walk(graph, from, order), to: Walk

  @doc """
  Walks the graph but stops early when a condition is met.

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
  defdelegate walk_until(opts), to: Walk

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
  defdelegate walk_until(graph, from, order, should_stop), to: Walk

  @doc """
  Folds over nodes during graph traversal, accumulating state with metadata.

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
  """
  @spec fold_walk(keyword()) :: any()
  defdelegate fold_walk(opts), to: Walk

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
  defdelegate fold_walk(graph, from, order, initial, folder), to: Walk

  @doc """
  Finds the shortest path between two nodes using BFS.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
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
  defdelegate find_path(graph, from, to), to: Walk

  @doc """
  Checks if there is a path from the starting node to the target node.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil)
      iex> Yog.Traversal.reachable?(graph, 1, 2)
      true
      iex> Yog.Traversal.reachable?(graph, 2, 1)
      false
  """
  @spec reachable?(Yog.graph(), Yog.node_id(), Yog.node_id()) :: boolean()
  defdelegate reachable?(graph, from, to), to: Walk

  # ============= Cycle Detection =============

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
  @spec cyclic?(Yog.graph()) :: boolean()
  defdelegate cyclic?(graph), to: Cycle

  @doc """
  Determines if a graph is acyclic (contains no cycles).

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
  defdelegate acyclic?(graph), to: Cycle

  # ============= Topological Sort =============

  @doc """
  Performs a topological sort on a directed graph using Kahn's algorithm.

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
  defdelegate topological_sort(graph), to: Sort

  @doc """
  Performs a lexicographically smallest topological sort.

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
  defdelegate lexicographical_topological_sort(graph, compare_nodes), to: Sort

  # ============= Implicit Traversal =============

  @doc """
  Traverse implicit graphs using BFS or DFS without materializing a `Graph`.

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
  defdelegate implicit_fold(opts), to: Implicit

  @doc """
  Like `implicit_fold/1`, but deduplicates visited nodes by a custom key.

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
  defdelegate implicit_fold_by(opts), to: Implicit

  @doc """
  Traverse an implicit weighted graph using Dijkstra's algorithm.

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
  defdelegate implicit_dijkstra(opts), to: Implicit
end
