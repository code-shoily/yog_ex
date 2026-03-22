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

      # Grid pathfinding with Manhattan distance heuristic
      heuristic = fn {x1, y1}, {x2, y2} -> abs(x1-x2) + abs(y1-y2) end
      Yog.Pathfinding.AStar.a_star(graph, start, goal, 0, &(&1+&2), &Integer.compare/2, heuristic)
  """

  alias Yog.Pathfinding.Utils

  @typedoc "Result type for shortest path queries"
  @type path_result(weight) :: {:some, Utils.path(weight)} | :none

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
    * `:heuristic` - Function estimating cost to goal: `fn(node) -> cost`

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
  @spec a_star(keyword()) :: path_result(any())
  def a_star(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    heuristic = Keyword.fetch!(opts, :heuristic)

    a_star(graph, from, to, zero, add, compare, heuristic)
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
  @spec implicit_a_star(keyword()) :: {:some, any()} | :none
  def implicit_a_star(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    heuristic = Keyword.fetch!(opts, :heuristic)

    implicit_a_star(from, successors, is_goal, zero, add, compare, heuristic)
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
  """
  @spec implicit_a_star_by(keyword()) :: {:some, any()} | :none
  def implicit_a_star_by(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    visited_by = Keyword.fetch!(opts, :visited_by)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    heuristic = Keyword.fetch!(opts, :heuristic)

    implicit_a_star_by(from, successors, visited_by, is_goal, zero, add, compare, heuristic)
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
    * `heuristic` - Function `fn(node, goal) -> cost` estimating cost to goal

  ## Returns

    * `{:some, path}` - A `Path` struct containing the nodes and total weight
    * `:none` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge!(:a, :b, 4)
      ...> |> Yog.add_edge!(:b, :c, 1)
      iex> # Admissible heuristic (never overestimates)
      iex> h = fn _, _ -> 0 end  # Zero heuristic = Dijkstra
      iex> compare = fn a, b -> if a < b, do: :lt, else: (if a > b, do: :gt, else: :eq) end
      iex> Yog.Pathfinding.AStar.a_star(graph, :a, :c, 0, &(&1 + &2), compare, h)
      {:some, {:path, [:a, :b, :c], 5}}

      iex> # Grid with Manhattan distance heuristic
      iex> grid = Yog.directed()
      ...> |> Yog.add_edge!({0,0}, {1,0}, 1)
      ...> |> Yog.add_edge!({1,0}, {2,0}, 1)
      iex> manhattan = fn {x1, y1}, {x2, y2} -> abs(x1-x2) + abs(y1-y2) end
      iex> compare = fn a, b -> if a < b, do: :lt, else: (if a > b, do: :gt, else: :eq) end
      iex> Yog.Pathfinding.AStar.a_star(grid, {0,0}, {2,0}, 0, &(&1+&2), compare, manhattan)
      {:some, {:path, [{0,0}, {1,0}, {2,0}], 2}}
  """
  @spec a_star(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt),
          (Yog.node_id(), Yog.node_id() -> weight)
        ) :: path_result(weight)
        when weight: var
  def a_star(graph, from, to, zero, add, compare, heuristic) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    case :yog@pathfinding@a_star.a_star(graph, from, to, zero, add, gleam_compare, heuristic) do
      :none ->
        :none

      {:some, {:path, nodes, weight}} ->
        {:some, Utils.path(nodes, weight)}
    end
  end

  @doc """
  Find the shortest path using A* with integer weights.

  Uses built-in integer arithmetic for efficient computation.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(1, 2, 4)
      ...> |> Yog.add_edge!(2, 3, 1)
      iex> h = fn _, _ -> 0 end
      iex> Yog.Pathfinding.AStar.a_star_int(graph, 1, 3, h)
      {:some, {:path, [1, 2, 3], 5}}
  """
  @spec a_star_int(Yog.graph(), Yog.node_id(), Yog.node_id(), (Yog.node_id(), Yog.node_id() ->
                                                                 integer())) ::
          path_result(integer())
  def a_star_int(graph, from, to, heuristic) do
    case :yog@pathfinding@a_star.a_star_int(graph, from, to, heuristic) do
      :none ->
        :none

      {:some, {:path, nodes, weight}} ->
        {:some, Utils.path(nodes, weight)}
    end
  end

  @doc """
  Find the shortest path using A* with float weights.

  Uses built-in float arithmetic for efficient computation.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(1, 2, 4.5)
      ...> |> Yog.add_edge!(2, 3, 1.5)
      iex> h = fn _, _ -> 0.0 end
      iex> Yog.Pathfinding.AStar.a_star_float(graph, 1, 3, h)
      {:some, {:path, [1, 2, 3], 6.0}}
  """
  @spec a_star_float(Yog.graph(), Yog.node_id(), Yog.node_id(), (Yog.node_id(), Yog.node_id() ->
                                                                   float())) ::
          path_result(float())
  def a_star_float(graph, from, to, heuristic) do
    case :yog@pathfinding@a_star.a_star_float(graph, from, to, heuristic) do
      :none ->
        :none

      {:some, {:path, nodes, weight}} ->
        {:some, Utils.path(nodes, weight)}
    end
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

    * `{:some, cost}` - Minimum cost to reach goal
    * `:none` - Goal is unreachable

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
      iex> compare = fn a, b -> if a < b, do: :lt, else: (if a > b, do: :gt, else: :eq) end
      iex> Yog.Pathfinding.AStar.implicit_a_star(
      ...>   1, successors, fn x -> x == 4 end,
      ...>   0, &(&1 + &2), compare, h
      ...> )
      {:some, 6}
  """
  @spec implicit_a_star(
          state,
          (state -> [{state, cost}]),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt),
          (state -> cost)
        ) :: {:some, cost} | :none
        when state: var, cost: var
  def implicit_a_star(from, successors, is_goal, zero, add, compare, heuristic) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@a_star.implicit_a_star(
      from,
      successors,
      is_goal,
      heuristic,
      zero,
      add,
      gleam_compare
    )
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

      iex> successors = fn {x, y, _dir} -> [{{x + 1, y, :east}, 1}, {{x, y + 1, :south}, 1}] end
      iex> key_fn = fn {x, y, _dir} -> {x, y} end
      iex> h = fn {x, y, _} -> (10 - x) + (10 - y) end
      iex> goal_fn = fn {x, y, _} -> x == 10 and y == 10 end
      iex> compare = fn a, b -> if a < b, do: :lt, else: (if a > b, do: :gt, else: :eq) end
      iex> #Yog.Pathfinding.AStar.implicit_a_star_by(
      ...> #  {0, 0, :north}, successors, key_fn,
      ...> #  goal_fn, 0, &(&1 + &2), compare, h
      ...> #)
  """
  @spec implicit_a_star_by(
          state,
          (state -> [{state, cost}]),
          (state -> term()),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt),
          (state -> cost)
        ) :: {:some, cost} | :none
        when state: var, cost: var
  def implicit_a_star_by(from, successors, key_fn, is_goal, zero, add, compare, heuristic) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@a_star.implicit_a_star_by(
      from,
      successors,
      key_fn,
      is_goal,
      heuristic,
      zero,
      add,
      gleam_compare
    )
  end
end
