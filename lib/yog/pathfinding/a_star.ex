defmodule Yog.Pathfinding.AStar do
  @moduledoc """
  A* (A-Star) search algorithm for optimal pathfinding with heuristic guidance.

  A* combines Dijkstra's algorithm with a heuristic function to efficiently find
  the shortest path in weighted graphs. It prioritizes exploration toward the goal
  using the evaluation function: f(n) = g(n) + h(n).

  ## Algorithm Characteristics

  - **Time Complexity**: O((V + E) log V) with a good heuristic
  - **Space Complexity**: O(V)
  - **Requirements**: Non-negative edge weights, admissible heuristic
  - **Optimality**: Optimal if heuristic is admissible (never overestimates)

  ## The Heuristic Function

  The heuristic `h(n)` estimates the cost from node `n` to the goal. For A* to be
  optimal, the heuristic must be:
  - **Admissible**: Never overestimates the true cost
  - **Consistent**: h(n) ≤ c(n,n') + h(n') for all edges

  ## When to Use

  - When you have a good heuristic (e.g., Euclidean distance on grids)
  - Pathfinding in games and robotics
  - When the goal is known and you want faster search than Dijkstra

  ## Examples

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=record, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    A [label="{A|h=6}"]; B [label="{B|h=4}"]; C [label="{C|h=6}"];
    D [label="{D|h=4}"]; E [label="{E|h=2}"]; F [label="{F|h=4}"];
    G [label="{G|h=0}"];
    A -> B [label="2", color="#ff5555", penwidth=2.5];
    A -> C [label="2"];
    B -> D [label="2", color="#ff5555", penwidth=2.5];
    C -> D [label="3"];
    B -> E [label="5"];
    D -> E [label="2", color="#ff5555", penwidth=2.5];
    D -> F [label="2"];
    E -> G [label="2", color="#ff5555", penwidth=2.5];
    F -> G [label="4"];
  }
  </div>

      iex> alias Yog.Pathfinding.AStar
      iex> graph = Yog.from_edges(:directed, [
      ...>   {"A", "B", 2}, {"A", "C", 2}, {"B", "D", 2},
      ...>   {"C", "D", 3}, {"B", "E", 5}, {"D", "E", 2},
      ...>   {"D", "F", 2}, {"E", "G", 2}, {"F", "G", 4}
      ...> ])
      iex> h = %{"A" => 6, "B" => 4, "C" => 6, "D" => 4, "E" => 2, "F" => 4, "G" => 0}
      iex> heuristic = fn n, _goal -> Map.get(h, n) end
      iex> {:ok, path} = AStar.a_star(graph, "A", "G", heuristic)
      iex> path.nodes
      ["A", "B", "D", "E", "G"]
      iex> path.weight
      8
  """

  alias Yog.PairingHeap, as: PQ
  alias Yog.Pathfinding.Path

  @typedoc "Result type for shortest path queries"
  @type path_result :: {:ok, Path.t()} | :error

  # ============================================================
  # Keyword-style API (for Pathfinding module delegation)
  # ============================================================

  @doc """
  Find shortest path using A* with keyword options.

  ## Options

    * `:in` - The graph to search
    * `:from` - Starting node
    * `:to` - Target node
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights (`:lt`, `:eq`, `:gt`)
    * `:heuristic` - Function estimating cost to goal: `fn(node, goal) -> cost`

  ## Examples

      Yog.Pathfinding.AStar.a_star(
        in: graph,
        from: :a,
        to: :c,
        zero: 0,
        add: &(&1 + &2),
        compare: &Integer.compare/2,
        heuristic: fn node -> estimate_to_goal(node) end
      )
  """
  @spec a_star(keyword()) :: path_result()
  def a_star(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    heuristic = Keyword.fetch!(opts, :heuristic)

    a_star(graph, from, to, heuristic, zero, add, compare)
  end

  @doc """
  Implicit A* using keyword options.

  ## Options

    * `:from` - Starting state
    * `:successors_with_cost` - Function returning neighbors with costs
    * `:is_goal` - Function to check if a state is the goal
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights
    * `:heuristic` - Function estimating cost to goal: `fn(state) -> cost`

  ## Examples

      Yog.Pathfinding.AStar.implicit_a_star(
        from: 1,
        successors_with_cost: fn n -> [{n+1, 1}] end,
        is_goal: fn n -> n == 10 end,
        zero: 0,
        add: &(&1 + &2),
        compare: &Integer.compare/2,
        heuristic: fn n -> 10 - n end
      )
  """
  @spec implicit_a_star(keyword()) :: {:ok, any()} | :error
  def implicit_a_star(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    heuristic = Keyword.fetch!(opts, :heuristic)

    implicit_a_star(from, successors, is_goal, heuristic, zero, add, compare)
  end

  @doc """
  Implicit A* with key function using keyword options.

  ## Options

    * `:from` - Starting state
    * `:successors_with_cost` - Function returning neighbors with costs
    * `:visited_by` - Function to extract a key for visited tracking
    * `:is_goal` - Function to check if a state is the goal
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights
    * `:heuristic` - Function estimating cost to goal: `fn(state) -> cost`

  ## Examples

      iex> successors = fn {x, y, _dir} ->
      ...>   next = []
      ...>   next = if x < 3, do: [{{x + 1, y, :east}, 1} | next], else: next
      ...>   next = if y < 3, do: [{{x, y + 1, :south}, 1} | next], else: next
      ...>   next
      ...> end
      iex> key_fn = fn {x, y, _dir} -> {x, y} end
      iex> h = fn {x, y, _} -> (3 - x) + (3 - y) end
      iex> goal_fn = fn {x, y, _} -> x == 3 and y == 3 end
      iex> Yog.Pathfinding.AStar.implicit_a_star_by(
      ...>   from: {0, 0, :north},
      ...>   successors_with_cost: successors,
      ...>   visited_by: key_fn,
      ...>   is_goal: goal_fn,
      ...>   heuristic: h
      ...> )
      {:ok, 6}
  """
  @spec implicit_a_star_by(keyword()) :: {:ok, any()} | :error
  def implicit_a_star_by(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    visited_by = Keyword.fetch!(opts, :visited_by)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    heuristic = Keyword.fetch!(opts, :heuristic)

    implicit_a_star_by(from, successors, visited_by, is_goal, heuristic, zero, add, compare)
  end

  # ============================================================
  # Direct API
  # ============================================================

  @doc """
  Find the shortest path using A* with a heuristic function.

  ## Parameters

    * `graph` - The graph to search
    * `from` - Starting node
    * `to` - Target node
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights (`:lt`, `:eq`, `:gt`)
    * `heuristic` - Function `fn(node, goal) -> cost` estimating cost to goal, use closure if node data stores info

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
      iex> # Admissible heuristic (never overestimates)
      iex> h = fn _, _ -> 0 end  # Zero heuristic = Dijkstra
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, path} = Yog.Pathfinding.AStar.a_star(graph, :a, :c, h, 0, &(&1 + &2), compare)
      iex> path.nodes
      [:a, :b, :c]
      iex> path.weight
      5

      iex> # Grid with Manhattan distance heuristic - node ID stores info
      iex> grid = Yog.directed()
      ...> |> Yog.add_edge_ensure({0,0}, {1,0}, 1)
      ...> |> Yog.add_edge_ensure({1,0}, {2,0}, 1)
      iex> manhattan = fn {x1, y1}, {x2, y2} -> abs(x1-x2) + abs(y1-y2) end
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, path} = Yog.Pathfinding.AStar.a_star(grid, {0,0}, {2,0}, manhattan, 0, &(&1+&2), compare)
      iex> path.nodes
      [{0,0}, {1,0}, {2,0}]
      iex> path.weight
      2

      iex> # Grid with Manhattan distance heuristic - node data stores info
      iex> grid = Yog.directed()
      ...> |> Yog.add_node(0, {0, 0})
      ...> |> Yog.add_node(1, {1, 0})
      ...> |> Yog.add_node(2, {2, 0})
      ...> |> Yog.add_edge!(0, 1, 1)
      ...> |> Yog.add_edge!(1, 2, 1)
      iex> manhattan = fn graph ->
      ...>  fn a, b ->
      ...>     {x1, y1} = Yog.Model.node(graph, a)
      ...>     {x2, y2} = Yog.Model.node(graph, b)
      ...>     abs(x1-x2) + abs(y1-y2)
      ...>  end
      ...> end
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, path} = Yog.Pathfinding.AStar.a_star(grid, 0, 2, manhattan.(grid), 0, &(&1+&2), compare)
      iex> path.nodes
      [0, 1, 2]
      iex> path.weight
      2
  """
  @spec a_star(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          (Yog.node_id(), Yog.node_id() -> weight),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: path_result()
        when weight: var
  def a_star(
        graph,
        from,
        to,
        heuristic,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    h0 = heuristic.(from, to)

    initial_queue =
      PQ.new(fn {f1, _, _}, {f2, _, _} -> compare.(f1, f2) != :gt end)
      |> PQ.push({add.(zero, h0), zero, from})

    initial_g_scores = %{from => zero}
    initial_predecessors = %{}

    do_a_star(
      graph,
      initial_queue,
      to,
      add,
      compare,
      heuristic,
      initial_g_scores,
      initial_predecessors
    )
  end

  @doc """
  Run A* on an implicit (generated) graph.

  Similar to implicit Dijkstra, but uses a heuristic to guide search toward the goal.

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights
    * `heuristic` - Function `fn(state) -> cost` estimating cost to goal

  ## Returns

    * `{:ok, cost}` - Minimum cost to reach goal
    * `:error` - Goal is unreachable

  ## Examples

      # Search with heuristic guidance
      iex> successors = fn
      ...>   1 -> [{2, 1}]
      ...>   2 -> [{3, 2}]
      ...>   3 -> [{4, 3}]
      ...>   4 -> []
      ...> end
      iex> # Heuristic: distance to goal (node 4)
      iex> h = fn n -> 4 - n end
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, cost} = Yog.Pathfinding.AStar.implicit_a_star(
      ...>   1, successors, fn x -> x == 4 end, h,
      ...>   0, &(&1 + &2), compare
      ...> )
      iex> cost
      6
  """
  @spec implicit_a_star(
          state,
          (state -> [{state, cost}]),
          (state -> boolean),
          (state -> cost),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: {:ok, cost} | :error
        when state: var, cost: var
  def implicit_a_star(
        from,
        successors,
        is_goal,
        heuristic,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    implicit_a_star_by(from, successors, fn x -> x end, is_goal, heuristic, zero, add, compare)
  end

  @doc """
  Implicit A* with a key function for visited state tracking.

  Similar to `implicit_a_star/7`, but uses a key function for visited tracking.

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `key_fn` - Function `state -> key` for visited tracking
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights
    * `heuristic` - Function `fn(state) -> cost` estimating cost to goal

  ## Examples

      iex> successors = fn {x, y, _dir} ->
      ...>   next = []
      ...>   next = if x < 10, do: [{{x + 1, y, :east}, 1} | next], else: next
      ...>   next = if y < 10, do: [{{x, y + 1, :south}, 1} | next], else: next
      ...>   next
      ...> end
      iex> key_fn = fn {x, y, _dir} -> {x, y} end
      iex> h = fn {x, y, _} -> (10 - x) + (10 - y) end
      iex> goal_fn = fn {x, y, _} -> x == 10 and y == 10 end
      iex> Yog.Pathfinding.AStar.implicit_a_star_by(
      ...>   {0, 0, :north},
      ...>   successors,
      ...>   key_fn,
      ...>   goal_fn,
      ...>   h
      ...> )
      {:ok, 20}
  """
  @spec implicit_a_star_by(
          state,
          (state -> [{state, cost}]),
          (state -> term()),
          (state -> boolean),
          (state -> cost),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: {:ok, cost} | :error
        when state: var, cost: var
  def implicit_a_star_by(
        from,
        successors,
        key_fn,
        is_goal,
        heuristic,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    h0 = heuristic.(from)

    initial_queue =
      PQ.new(fn {f1, _, _}, {f2, _, _} ->
        compare.(f1, f2) != :gt
      end)
      |> PQ.push({add.(zero, h0), zero, from})

    initial_g_scores = %{key_fn.(from) => zero}

    do_implicit_a_star(
      initial_queue,
      successors,
      key_fn,
      is_goal,
      add,
      compare,
      heuristic,
      initial_g_scores
    )
  end

  # ============================================================
  # Helper functions
  # ============================================================

  # Main A* implementation for materialized graphs
  defp do_a_star(graph, queue, to, add, compare, heuristic, g_scores, predecessors) do
    case PQ.pop(queue) do
      :error ->
        :error

      {:ok, {_f, g, node}, rest} ->
        maybe_expand_node(
          graph,
          node,
          g,
          rest,
          to,
          add,
          compare,
          heuristic,
          g_scores,
          predecessors
        )
    end
  end

  defp maybe_expand_node(graph, node, g, rest, to, add, compare, heuristic, g_scores, preds) do
    case Map.get(g_scores, node) do
      best_g when not is_nil(best_g) ->
        if compare.(g, best_g) == :gt do
          do_a_star(graph, rest, to, add, compare, heuristic, g_scores, preds)
        else
          expand_node(graph, node, g, rest, to, add, compare, heuristic, g_scores, preds)
        end

      nil ->
        # Should not happen if correctly initialized
        do_a_star(graph, rest, to, add, compare, heuristic, g_scores, preds)
    end
  end

  defp expand_node(graph, node, g, rest, to, add, compare, heuristic, g_scores, preds) do
    if node == to do
      path = reconstruct_path(preds, to, [to])
      {:ok, Path.new(path, g, :a_star)}
    else
      # Direct edge access for performance
      successors = Map.get(graph.out_edges, node, %{})

      {new_queue, new_g_scores, new_predecessors} =
        Enum.reduce(successors, {rest, g_scores, preds}, fn {neighbor, cost}, acc ->
          relax_neighbor(acc, node, neighbor, cost, g, to, add, compare, heuristic)
        end)

      do_a_star(
        graph,
        new_queue,
        to,
        add,
        compare,
        heuristic,
        new_g_scores,
        new_predecessors
      )
    end
  end

  defp relax_neighbor({q, gs, preds}, node, neighbor, cost, g, to, add, compare, heuristic) do
    new_g = add.(g, cost)
    existing_g = Map.get(gs, neighbor)

    if is_nil(existing_g) or compare.(new_g, existing_g) == :lt do
      h = heuristic.(neighbor, to)
      f = add.(new_g, h)

      {PQ.push(q, {f, new_g, neighbor}), Map.put(gs, neighbor, new_g),
       Map.put(preds, neighbor, node)}
    else
      {q, gs, preds}
    end
  end

  # Reconstruct path by backtracking through predecessors
  defp reconstruct_path(predecessors, node, acc) do
    case Map.get(predecessors, node) do
      nil -> acc
      parent -> reconstruct_path(predecessors, parent, [parent | acc])
    end
  end

  defp do_implicit_a_star(queue, successors, key_fn, is_goal, add, compare, heuristic, g_scores) do
    case PQ.pop(queue) do
      :error ->
        :error

      {:ok, {_f, g, state}, rest} ->
        maybe_expand_implicit_node(
          rest,
          state,
          g,
          successors,
          key_fn,
          is_goal,
          add,
          compare,
          heuristic,
          g_scores
        )
    end
  end

  defp maybe_expand_implicit_node(
         rest,
         state,
         g,
         successors,
         key_fn,
         is_goal,
         add,
         compare,
         heuristic,
         g_scores
       ) do
    key = key_fn.(state)

    case Map.get(g_scores, key) do
      best_g when not is_nil(best_g) ->
        if compare.(g, best_g) == :gt do
          do_implicit_a_star(rest, successors, key_fn, is_goal, add, compare, heuristic, g_scores)
        else
          expand_implicit_node(
            rest,
            state,
            g,
            successors,
            key_fn,
            is_goal,
            add,
            compare,
            heuristic,
            g_scores
          )
        end

      nil ->
        do_implicit_a_star(rest, successors, key_fn, is_goal, add, compare, heuristic, g_scores)
    end
  end

  defp expand_implicit_node(
         rest,
         state,
         g,
         successors,
         key_fn,
         is_goal,
         add,
         compare,
         heuristic,
         g_scores
       ) do
    if is_goal.(state) do
      {:ok, g}
    else
      next_states = successors.(state)

      {new_queue, new_g_scores} =
        Enum.reduce(next_states, {rest, g_scores}, fn {next_state, cost}, acc ->
          relax_implicit_neighbor(acc, next_state, cost, g, key_fn, add, compare, heuristic)
        end)

      do_implicit_a_star(
        new_queue,
        successors,
        key_fn,
        is_goal,
        add,
        compare,
        heuristic,
        new_g_scores
      )
    end
  end

  defp relax_implicit_neighbor({q, gs}, next_state, cost, g, key_fn, add, compare, heuristic) do
    new_g = add.(g, cost)
    key = key_fn.(next_state)
    existing_g = Map.get(gs, key)

    if is_nil(existing_g) or compare.(new_g, existing_g) == :lt do
      h = heuristic.(next_state)
      f = add.(new_g, h)
      {PQ.push(q, {f, new_g, next_state}), Map.put(gs, key, new_g)}
    else
      {q, gs}
    end
  end
end
