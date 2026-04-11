defmodule Yog.Pathfinding.Dijkstra do
  @moduledoc """
  Dijkstra's algorithm for single-source shortest paths.

  Dijkstra's algorithm finds the shortest path from a source node to all other
  reachable nodes in a graph with non-negative edge weights.

  ## Implementation Notes

  This module uses a hybrid implementation:
  - `shortest_path/6`, `implicit_dijkstra/6`, and `implicit_dijkstra_by/7`
    delegate to `AStar` with a zero heuristic (`fn _, _ -> 0 end` or `fn _ -> 0 end`),
    since Dijkstra's algorithm is mathematically equivalent to A* with zero heuristic.
  - `single_source_distances/5` uses a native implementation since it computes
    distances to ALL nodes (A* requires a goal).

  ## Algorithm Characteristics

  - **Time Complexity**: O((V + E) log V) with a binary heap
  - **Space Complexity**: O(V)
  - **Requirements**: Non-negative edge weights
  - **Optimality**: Guaranteed optimal for graphs with non-negative weights

  ## When to Use

  - When all edge weights are non-negative
  - For single-source shortest path problems
  - When you need paths to all nodes from a source
  - As a baseline comparison for other algorithms

  ## Examples

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    A [label="A"]; B [label="B"]; C [label="C"];
    D [label="D"]; E [label="E"]; F [label="F"];
    A -> B [label="4"];
    A -> C [label="2", color="#ff5555", penwidth=2.5];
    B -> D [label="5", color="#ff5555", penwidth=2.5];
    C -> B [label="1", color="#ff5555", penwidth=2.5];
    C -> D [label="8"];
    C -> E [label="10"];
    D -> E [label="2", color="#ff5555", penwidth=2.5];
    D -> F [label="6"];
    E -> F [label="2", color="#ff5555", penwidth=2.5];
  }
  </div>

      # Complex graph with multiple paths
      graph = Yog.directed()
      |> Yog.add_edges([
        {:a, :b, 4}, {:a, :c, 2}, {:b, :d, 5},
        {:c, :b, 1}, {:c, :d, 8}, {:c, :e, 10},
        {:d, :e, 2}, {:d, :f, 6}, {:e, :f, 2}
      ])

      compare = &Yog.Utils.compare/2
      Dijkstra.shortest_path(graph, :a, :f, 0, &(&1 + &2), compare)
      #=> {:ok, %Yog.Pathfinding.Path{nodes: [:a, :c, :b, :d, :e, :f], weight: 12}}

      # Find all distances from a source
      Dijkstra.single_source_distances(graph, :a, 0, &(&1 + &2), compare)
      #=> %{a: 0, c: 2, b: 3, d: 8, e: 10, f: 12}
  """

  alias Yog.PairingHeap, as: PQ
  alias Yog.Pathfinding.AStar
  alias Yog.Pathfinding.Path

  @typedoc "Result type for shortest path queries"
  @type path_result :: {:ok, Path.t()} | :error

  # ============================================================
  # Keyword-style API (for Pathfinding module delegation)
  # ============================================================

  @doc """
  Find shortest path using keyword options.

  ## Options

    * `:in` - The graph to search
    * `:from` - Starting node
    * `:to` - Target node
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights (`:lt`, `:eq`, `:gt`)

  ## Examples

      Pathfinding.shortest_path(
        in: graph,
        from: :a,
        to: :c,
        zero: 0,
        add: &(&1 + &2),
        compare: &Yog.Utils.compare/2
      )
  """
  @spec shortest_path(keyword()) :: path_result()
  def shortest_path(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    shortest_path(graph, from, to, zero, add, compare)
  end

  @doc """
  Single-source distances using keyword options.

  ## Options

    * `:in` - The graph to search
    * `:from` - Source node
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights

  ## Examples

      Pathfinding.single_source_distances(
        in: graph,
        from: :a,
        zero: 0,
        add: &(&1 + &2),
        compare: &Yog.Utils.compare/2
      )
  """
  @spec single_source_distances(keyword()) :: %{Yog.node_id() => any()}
  def single_source_distances(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    single_source_distances(graph, from, zero, add, compare)
  end

  @doc """
  Implicit Dijkstra using keyword options.

  ## Options

    * `:from` - Starting state
    * `:successors_with_cost` - Function returning neighbors with costs
    * `:is_goal` - Function to check if a state is the goal
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights

  ## Examples

      Pathfinding.implicit_dijkstra(
        from: 1,
        successors_with_cost: fn n -> [{n+1, 1}] end,
        is_goal: fn n -> n == 10 end,
        zero: 0,
        add: &(&1 + &2),
        compare: &Yog.Utils.compare/2
      )
  """
  @spec implicit_dijkstra(keyword()) :: {:ok, any()} | :error
  def implicit_dijkstra(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    implicit_dijkstra(from, successors, is_goal, zero, add, compare)
  end

  @doc """
  Implicit Dijkstra with key function using keyword options.

  ## Options

    * `:from` - Starting state
    * `:successors_with_cost` - Function returning neighbors with costs
    * `:visited_by` - Function to extract a key for visited tracking
    * `:is_goal` - Function to check if a state is the goal
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights
  """
  @spec implicit_dijkstra_by(keyword()) :: {:ok, any()} | :error
  def implicit_dijkstra_by(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    visited_by = Keyword.fetch!(opts, :visited_by)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    implicit_dijkstra_by(from, successors, visited_by, is_goal, zero, add, compare)
  end

  # ============================================================
  # Direct API - Delegated to A* (Dijkstra = A* with zero heuristic)
  # ============================================================

  @doc """
  Find the shortest path between two nodes using Dijkstra's algorithm.

  This function delegates to `Yog.Pathfinding.AStar.a_star/7` with a zero
  heuristic (`fn _, _ -> 0 end`), since Dijkstra's algorithm is mathematically
  equivalent to A* with zero heuristic.

  ## Parameters

    * `graph` - The graph to search
    * `from` - Starting node
    * `to` - Target node
    * `zero` - Identity value for the weight type (default: 0)
    * `add` - Function to add two weights (default: `&Kernel.+/2`)
    * `compare` - Function to compare weights (default: `&Yog.Utils.compare/2`)

  ## Returns

    * `{:ok, path}` - A `Path` struct containing the nodes and total weight
    * `:error` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge_ensure(:a, :b, 4)
      ...> |> Yog.add_edge_ensure(:b, :c, 1)
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, path} = Dijkstra.shortest_path(graph, :a, :c, 0, &(&1 + &2), compare)
      iex> path.nodes
      [:a, :b, :c]
      iex> path.weight
      5
      iex> path.algorithm
      :dijkstra
  """
  @spec shortest_path(
          Yog.t(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: path_result()
        when weight: var
  def shortest_path(
        graph,
        from,
        to,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    # Dijkstra = A* with zero heuristic
    zero_heuristic = fn _, _ -> zero end

    case AStar.a_star(graph, from, to, zero_heuristic, zero, add, compare) do
      {:ok, path} -> {:ok, %{path | algorithm: :dijkstra}}
      :error -> :error
    end
  end

  @doc """
  Run Dijkstra on an implicit (generated) graph.

  Instead of storing all edges explicitly, provide a successor function that
  generates neighbors on demand. This is useful for:
  - Infinite or very large graphs
  - Grid-based pathfinding with dynamic obstacles
  - Game state spaces

  This function delegates to `Yog.Pathfinding.AStar.implicit_a_star/7` with
  a zero heuristic (`fn _ -> 0 end`).

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type (default: 0)
    * `add` - Function to add two weights (default: `&Kernel.+/2`)
    * `compare` - Function to compare weights (default: `&Yog.Utils.compare/2`)

  ## Returns

    * `{:ok, cost}` - Minimum cost to reach goal
    * `:error` - Goal is unreachable

  ## Examples

      # Search on a linear chain: 1->2->3->4 with costs 1,2,3
      iex> successors = fn
      ...>   1 -> [{2, 1}]
      ...>   2 -> [{3, 2}]
      ...>   3 -> [{4, 3}]
      ...>   4 -> []
      ...> end
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, cost} = Dijkstra.implicit_dijkstra(
      ...>   1, successors, fn x -> x == 4 end,
      ...>   0, &(&1 + &2), compare
      ...> )
      iex> cost
      6
  """
  @spec implicit_dijkstra(
          state,
          (state -> [{state, cost}]),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: {:ok, cost} | :error
        when state: var, cost: var
  def implicit_dijkstra(
        from,
        successors,
        is_goal,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    implicit_dijkstra_by(from, successors, fn x -> x end, is_goal, zero, add, compare)
  end

  @doc """
  Implicit Dijkstra with a key function for visited state tracking.

  Similar to `implicit_dijkstra/6`, but uses a key function to determine
  when states should be considered "visited". This allows:
  - Efficient pruning of equivalent states
  - Custom equivalence relations beyond simple equality

  This function delegates to `Yog.Pathfinding.AStar.implicit_a_star_by/8` with
  a zero heuristic (`fn _ -> 0 end`).

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `key_fn` - Function `state -> key` for visited tracking
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type (default: 0)
    * `add` - Function to add two weights (default: `&Kernel.+/2`)
    * `compare` - Function to compare weights (default: `&Yog.Utils.compare/2`)

  ## Examples

      iex> successors = fn
      ...>   {pos, _dir} when pos < 3 -> [{{pos + 1, :fwd}, 1}]
      ...>   _ -> []
      ...> end
      iex> key_fn = fn {pos, _dir} -> pos end
      iex> goal_fn = fn {pos, _dir} -> pos == 3 end
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, cost} = Dijkstra.implicit_dijkstra_by(
      ...>   {0, :start}, successors, key_fn,
      ...>   goal_fn, 0, &(&1 + &2), compare
      ...> )
      iex> cost
      3
  """
  @spec implicit_dijkstra_by(
          state,
          (state -> [{state, cost}]),
          (state -> term()),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: {:ok, cost} | :error
        when state: var, cost: var
  def implicit_dijkstra_by(
        from,
        successors,
        key_fn,
        is_goal,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    # Dijkstra = A* with zero heuristic for implicit graphs
    zero_heuristic = fn _state -> zero end

    AStar.implicit_a_star_by(
      from,
      successors,
      key_fn,
      is_goal,
      zero_heuristic,
      zero,
      add,
      compare
    )
  end

  # ============================================================
  # Native Implementation (single_source_distances needs this)
  # ============================================================

  @doc """
  Calculate single-source shortest distances to all reachable nodes.

  Returns a map of node IDs to their shortest distance from the source.

  This function uses a native implementation (not delegated to A*) because
  A* requires a goal node, but this function computes distances to ALL nodes.

  ## Parameters

    * `graph` - The graph to search
    * `from` - Source node
    * `zero` - Identity value for the weight type (default: 0)
    * `add` - Function to add two weights (default: `&Kernel.+/2`)
    * `compare` - Function to compare weights (default: `&Yog.Utils.compare/2`)

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge_ensure(:a, :b, 4)
      ...> |> Yog.add_edge_ensure(:a, :c, 2)
      ...> |> Yog.add_edge_ensure(:b, :c, 1)
      iex> compare = &Yog.Utils.compare/2
      iex> Dijkstra.single_source_distances(graph, :a, 0, &(&1 + &2), compare)
      %{a: 0, b: 4, c: 2}
  """
  @spec single_source_distances(
          Yog.t(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: %{Yog.node_id() => weight}
        when weight: var
  def single_source_distances(
        graph,
        from,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    if Yog.Model.has_node?(graph, from) do
      {_path, _weight, distances} = do_dijkstra(graph, from, zero, add, compare)
      distances
    else
      %{}
    end
  end

  # ============================================================
  # Helper functions (used by single_source_distances)
  # ============================================================

  # Main Dijkstra implementation for single_source_distances
  # Returns {[], zero, distances}
  defp do_dijkstra(graph, from, zero, add, compare) do
    initial_queue =
      PQ.new()
      |> PQ.push({zero, from})

    initial_distances = %{from => zero}
    initial_predecessors = %{}

    do_dijkstra_loop(
      graph,
      initial_queue,
      add,
      compare,
      initial_distances,
      initial_predecessors
    )
  end

  # Main Dijkstra implementation for single_source_distances
  defp do_dijkstra_loop(graph, queue, add, compare, distances, predecessors) do
    case PQ.pop(queue) do
      :error ->
        zero_val = zero_from_distances(distances)
        {[], zero_val, distances}

      {:ok, {dist, node}, rest} ->
        maybe_visit_node(graph, node, dist, rest, add, compare, distances, predecessors)
    end
  end

  defp maybe_visit_node(graph, node, dist, rest, add, compare, distances, predecessors) do
    current_best = Map.get(distances, node)

    if current_best != nil and compare.(dist, current_best) == :gt do
      do_dijkstra_loop(graph, rest, add, compare, distances, predecessors)
    else
      visit_node(graph, node, dist, rest, add, compare, distances, predecessors)
    end
  end

  defp visit_node(graph, node, dist, rest, add, compare, distances, predecessors) do
    successors = Map.get(graph.out_edges, node, %{})

    {new_queue, new_distances, new_predecessors} =
      Enum.reduce(successors, {rest, distances, predecessors}, fn {neighbor, weight}, acc ->
        relax_neighbor(acc, node, neighbor, weight, dist, add, compare)
      end)

    do_dijkstra_loop(graph, new_queue, add, compare, new_distances, new_predecessors)
  end

  defp relax_neighbor({q, d, p}, node, neighbor, weight, dist, add, compare) do
    new_dist = add.(dist, weight)
    current_best = Map.get(d, neighbor)

    if is_nil(current_best) or compare.(new_dist, current_best) == :lt do
      {PQ.push(q, {new_dist, neighbor}), Map.put(d, neighbor, new_dist),
       Map.put(p, neighbor, node)}
    else
      {q, d, p}
    end
  end

  # Reconstruct path by backtracking through predecessors
  # Note: Only used as safety net; shortest_path now delegates to A*

  defp zero_from_distances(distances) do
    case Map.values(distances) do
      [z | _] -> z
      [] -> 0
    end
  end

  # ============================================================
  # Widest Path (Maximum Capacity Path)
  # ============================================================

  @doc """
  Find the widest path (maximum capacity path) between two nodes.

  The widest path maximizes the minimum edge weight along the path (the bottleneck).
  This is useful for network bandwidth routing, finding reliable paths, and
  max-min fair allocation problems.

  This is a simple modification of Dijkstra's algorithm:
  - Initialize source capacity to `:infinity` (no bottleneck yet)
  - Use `min/2` to combine capacities (bottleneck is the minimum edge)
  - Use `>=` comparison to prioritize higher capacities (maximize)

  ## Parameters

    * `graph` - The graph to search
    * `from` - Starting node
    * `to` - Target node

  ## Returns

    * `{:ok, path}` - A `Path` struct containing the nodes and bottleneck capacity
    * `:error` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_node(:d, nil)
      ...> |> Yog.add_edge_ensure(:a, :b, 100)
      ...> |> Yog.add_edge_ensure(:a, :c, 50)
      ...> |> Yog.add_edge_ensure(:b, :d, 80)
      ...> |> Yog.add_edge_ensure(:c, :d, 200)
      iex> {:ok, path} = Dijkstra.widest_path(graph, :a, :d)
      iex> path.nodes
      [:a, :b, :d]
      iex> path.weight
      80
      iex> path.algorithm
      :widest_path

  ## Algorithm

  Standard Dijkstra minimizes: `dist[v] = min(dist[u] + weight(u,v))`
  Widest Path maximizes: `cap[v] = max(cap[v], min(cap[u], weight(u,v)))`

  The path's "width" is the minimum edge weight along it. We want to
  maximize this minimum (the bottleneck capacity).

  ## See Also

  - `shortest_path/6` - Standard Dijkstra for shortest paths
  - Wikipedia: https://en.wikipedia.org/wiki/Widest_path_problem
  """
  @spec widest_path(Yog.t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, Path.t()} | :error
  def widest_path(graph, from, to) do
    # Widest path = Dijkstra with modified semiring:
    # - Identity: :infinity (starting with infinite capacity)
    # - Combine: min/2 (bottleneck is the minimum edge along path)
    # - Compare: >= (maximize the bottleneck)

    zero_heuristic = fn _, _ -> :infinity end

    case AStar.a_star(
           graph,
           from,
           to,
           zero_heuristic,
           :infinity,
           &min/2,
           &Yog.Utils.compare_desc/2
         ) do
      {:ok, path} -> {:ok, %{path | algorithm: :widest_path}}
      :error -> :error
    end
  end
end
