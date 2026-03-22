defmodule Yog.Pathfinding.Dijkstra do
  @moduledoc """
  Dijkstra's algorithm for single-source shortest paths.

  Dijkstra's algorithm finds the shortest path from a source node to all other
  reachable nodes in a graph with non-negative edge weights.

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

      # Find shortest path between two nodes
      graph = Yog.directed()
      |> Yog.add_node(:a, nil)
      |> Yog.add_node(:b, nil)
      |> Yog.add_node(:c, nil)
      |> Yog.add_edge!(:a, :b, 4)
      |> Yog.add_edge!(:b, :c, 1)

      compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      Dijkstra.shortest_path(graph, :a, :c, 0, &(&1 + &2), compare)
      #=> {:some, {:path, [:a, :b, :c], 5}}

      # Find all distances from a source
      Dijkstra.single_source_distances(graph, :a, 0, &(&1 + &2), compare)
      #=> %{:a => 0, :b => 4, :c => 5}
  """

  alias Yog.Pathfinding.Utils

  @typedoc "Result type for shortest path queries"
  @type path_result(weight) :: {:some, Utils.path(weight)} | :none

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
        compare: fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      )
  """
  @spec shortest_path(keyword()) :: path_result(any())
  def shortest_path(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    shortest_path(graph, from, to, zero, add, compare)
  end

  @doc """
  Find shortest path using keyword options (alias for `shortest_path/1`).
  """
  @spec shortest_path_int(keyword()) :: path_result(integer())
  def shortest_path_int(opts) do
    shortest_path(opts)
  end

  @doc """
  Find shortest path using keyword options (alias for `shortest_path/1`).
  """
  @spec shortest_path_float(keyword()) :: path_result(float())
  def shortest_path_float(opts) do
    shortest_path(opts)
  end

  @doc """
  Single-source distances using keyword options.

  ## Options

    * `:in` - The graph to search
    * `:from` - Starting node
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights

  ## Examples

      Pathfinding.single_source_distances(
        in: graph,
        from: :a,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      )
  """
  @spec single_source_distances(keyword()) :: %{Yog.node_id() => any()}
  def single_source_distances(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

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
        compare: fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      )
  """
  @spec implicit_dijkstra(keyword()) :: {:some, any()} | :none
  def implicit_dijkstra(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

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
  @spec implicit_dijkstra_by(keyword()) :: {:some, any()} | :none
  def implicit_dijkstra_by(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    visited_by = Keyword.fetch!(opts, :visited_by)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    implicit_dijkstra_by(from, successors, visited_by, is_goal, zero, add, compare)
  end

  # ============================================================
  # Direct API
  # ============================================================

  @doc """
  Find the shortest path between two nodes using custom numeric operations.

  ## Parameters

    * `graph` - The graph to search
    * `from` - Starting node
    * `to` - Target node
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights: `(weight, weight) -> weight`
    * `compare` - Function to compare weights, returns `:lt`, `:eq`, or `:gt`

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
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      iex> Dijkstra.shortest_path(graph, :a, :c, 0, &(&1 + &2), compare)
      {:some, {:path, [:a, :b, :c], 5}}

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge!(:a, :b, 4)
      ...> |> Yog.add_edge!(:b, :c, 1)
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      iex> Dijkstra.shortest_path(graph, :a, :nonexistent, 0, &(&1 + &2), compare)
      :none
  """
  @spec shortest_path(
          Yog.t(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: path_result(weight)
        when weight: var
  def shortest_path(graph, from, to, zero, add, compare) do
    # Convert Elixir compare function to Gleam Order type
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    case :yog@pathfinding@dijkstra.shortest_path(graph, from, to, zero, add, gleam_compare) do
      :none ->
        :none

      {:some, {:path, nodes, weight}} ->
        {:some, Utils.path(nodes, weight)}
    end
  end

  @doc """
  Find the shortest path using integer weights.

  Uses built-in integer arithmetic for efficient computation.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(1, 2, 4)
      ...> |> Yog.add_edge!(2, 3, 1)
      iex> Dijkstra.shortest_path_int(graph, 1, 3)
      {:some, {:path, [1, 2, 3], 5}}
  """
  @spec shortest_path_int(Yog.t(), Yog.node_id(), Yog.node_id()) :: path_result(integer())
  def shortest_path_int(graph, from, to) do
    case :yog@pathfinding@dijkstra.shortest_path_int(graph, from, to) do
      :none ->
        :none

      {:some, {:path, nodes, weight}} ->
        {:some, Utils.path(nodes, weight)}
    end
  end

  @doc """
  Find the shortest path using float weights.

  Uses built-in float arithmetic for efficient computation.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(1, 2, 4.5)
      ...> |> Yog.add_edge!(2, 3, 1.5)
      iex> Dijkstra.shortest_path_float(graph, 1, 3)
      {:some, {:path, [1, 2, 3], 6.0}}
  """
  @spec shortest_path_float(Yog.t(), Yog.node_id(), Yog.node_id()) :: path_result(float())
  def shortest_path_float(graph, from, to) do
    case :yog@pathfinding@dijkstra.shortest_path_float(graph, from, to) do
      :none ->
        :none

      {:some, {:path, nodes, weight}} ->
        {:some, Utils.path(nodes, weight)}
    end
  end

  @doc """
  Calculate single-source shortest distances to all reachable nodes.

  Returns a map of node IDs to their shortest distance from the source.

  ## Parameters

    * `graph` - The graph to search
    * `from` - Source node
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge!(:a, :b, 4)
      ...> |> Yog.add_edge!(:a, :c, 2)
      ...> |> Yog.add_edge!(:b, :c, 1)
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
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
  def single_source_distances(graph, from, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@dijkstra.single_source_distances(graph, from, zero, add, gleam_compare)
    |> :gleam@dict.to_list()
    |> Map.new()
  end

  @doc """
  Run Dijkstra on an implicit (generated) graph.

  Instead of storing all edges explicitly, provide a successor function that
  generates neighbors on demand. This is useful for:
  - Infinite or very large graphs
  - Grid-based pathfinding with dynamic obstacles
  - Game state spaces

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights

  ## Returns

    * `{:some, cost}` - Minimum cost to reach goal
    * `:none` - Goal is unreachable

  ## Examples

      # Search on a linear chain: 1->2->3->4 with costs 1,2,3
      iex> successors = fn
      ...>   1 -> [{2, 1}]
      ...>   2 -> [{3, 2}]
      ...>   3 -> [{4, 3}]
      ...>   4 -> []
      ...> end
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      iex> Dijkstra.implicit_dijkstra(
      ...>   1, successors, fn x -> x == 4 end,
      ...>   0, &(&1 + &2), compare
      ...> )
      {:some, 6}
  """
  @spec implicit_dijkstra(
          state,
          (state -> [{state, cost}]),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: {:some, cost} | :none
        when state: var, cost: var
  def implicit_dijkstra(from, successors, is_goal, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@dijkstra.implicit_dijkstra(
      from,
      successors,
      is_goal,
      zero,
      add,
      gleam_compare
    )
  end

  @doc """
  Implicit Dijkstra with a key function for visited state tracking.

  Similar to `implicit_dijkstra/6`, but uses a key function to determine
  when states should be considered "visited". This allows:
  - Efficient pruning of equivalent states
  - Custom equivalence relations beyond simple equality

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `key_fn` - Function `state -> key` for visited tracking
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights

  ## Examples

      iex> successors = fn
      ...>   {pos, _dir} when pos < 3 -> [{{pos + 1, :fwd}, 1}]
      ...>   _ -> []
      ...> end
      iex> key_fn = fn {pos, _dir} -> pos end
      iex> goal_fn = fn {pos, _dir} -> pos == 3 end
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      iex> Dijkstra.implicit_dijkstra_by(
      ...>   {0, :start}, successors, key_fn,
      ...>   goal_fn, 0, &(&1 + &2), compare
      ...> )
      {:some, 3}
  """
  @spec implicit_dijkstra_by(
          state,
          (state -> [{state, cost}]),
          (state -> term()),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: {:some, cost} | :none
        when state: var, cost: var
  def implicit_dijkstra_by(from, successors, key_fn, is_goal, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@dijkstra.implicit_dijkstra_by(
      from,
      successors,
      key_fn,
      is_goal,
      zero,
      add,
      gleam_compare
    )
  end
end
