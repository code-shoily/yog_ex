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
      |> Yog.add_edge_ensure(:a, :b, 4)
      |> Yog.add_edge_ensure(:b, :c, 1)

      compare = &Yog.Utils.compare/2
      Dijkstra.shortest_path(graph, :a, :c, 0, &(&1 + &2), compare)
      #=> {:ok, {:path, [:a, :b, :c], 5}}

      # Find all distances from a source
      Dijkstra.single_source_distances(graph, :a, 0, &(&1 + &2), compare)
      #=> %{:a => 0, :b => 4, :c => 5}
  """

  alias Yog.Pathfinding.Path
  alias Yog.PriorityQueue, as: PQ
  alias Yog.Queryable, as: Model

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

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge_ensure(:a, :b, 4)
      ...> |> Yog.add_edge_ensure(:b, :c, 1)
      iex> compare = &Yog.Utils.compare/2
      iex> Dijkstra.shortest_path(graph, :a, :nonexistent, 0, &(&1 + &2), compare)
      :error
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
    case do_dijkstra(graph, from, to, zero, add, compare, true) do
      :error -> :error
      {path, weight} -> {:ok, Path.new(path, weight, :dijkstra)}
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
    case do_dijkstra(graph, from, nil, zero, add, compare, false) do
      :error -> %{}
      {_path, _weight, distances} -> distances
    end
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
    initial_queue =
      PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
      |> PQ.push({zero, from})

    initial_visited = %{key_fn.(from) => zero}

    do_implicit_dijkstra(
      initial_queue,
      successors,
      key_fn,
      is_goal,
      add,
      compare,
      initial_visited
    )
  end

  # Main Dijkstra implementation
  # Returns :error | {path, weight} if to is specified
  # Returns :error | {[], zero, distances} if to is nil (single source distances)
  defp do_dijkstra(graph, from, to, zero, add, compare, _return_path) do
    # Unified implementation using predecessor map for path reconstruction
    initial_queue =
      PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
      |> PQ.push({zero, from})

    initial_distances = %{from => zero}
    initial_predecessors = %{}

    do_dijkstra_loop(
      graph,
      initial_queue,
      to,
      add,
      compare,
      initial_distances,
      initial_predecessors
    )
  end

  defp do_dijkstra_loop(graph, queue, to, add, compare, distances, predecessors) do
    case PQ.pop(queue) do
      :error ->
        if to do
          :error
        else
          # For single source distances, return the distances map
          # The zero value is the distance of the source node (which is always present)
          zero_val = zero_from_distances(distances)
          {[], zero_val, distances}
        end

      {:ok, {dist, node}, rest} ->
        current_best = Map.get(distances, node)

        if current_best != nil and compare.(dist, current_best) == :gt do
          # Outdated entry, skip
          do_dijkstra_loop(graph, rest, to, add, compare, distances, predecessors)
        else
          # Check if we reached the target
          if node == to do
            extract_result(distances, predecessors, to, dist)
          else
            successors = Model.successors(graph, node)

            {new_queue, new_distances, new_predecessors} =
              Enum.reduce(successors, {rest, distances, predecessors}, fn {neighbor, weight},
                                                                          {q, d, p} ->
                new_dist = add.(dist, weight)

                case Map.fetch(d, neighbor) do
                  {:ok, current} ->
                    if compare.(new_dist, current) == :lt do
                      new_q = PQ.push(q, {new_dist, neighbor})
                      new_d = Map.put(d, neighbor, new_dist)
                      new_p = Map.put(p, neighbor, node)
                      {new_q, new_d, new_p}
                    else
                      {q, d, p}
                    end

                  :error ->
                    new_q = PQ.push(q, {new_dist, neighbor})
                    new_d = Map.put(d, neighbor, new_dist)
                    new_p = Map.put(p, neighbor, node)
                    {new_q, new_d, new_p}
                end
              end)

            do_dijkstra_loop(graph, new_queue, to, add, compare, new_distances, new_predecessors)
          end
        end
    end
  end

  # Extract the result: either a path to target or all distances
  defp extract_result(_distances, _predecessors, nil, _dist), do: {[], 0, %{}}

  defp extract_result(_distances, predecessors, target, dist) do
    path = reconstruct_path(predecessors, target, [target])
    {path, dist}
  end

  # Reconstruct path by backtracking through predecessors
  defp reconstruct_path(predecessors, node, acc) do
    case Map.get(predecessors, node) do
      nil -> acc
      parent -> reconstruct_path(predecessors, parent, [parent | acc])
    end
  end

  defp zero_from_distances(distances) do
    case Map.values(distances) do
      [z | _] -> z
      [] -> 0
    end
  end

  # Implicit Dijkstra implementation
  defp do_implicit_dijkstra(
         queue,
         successors,
         key_fn,
         is_goal,
         add,
         compare,
         visited
       ) do
    case PQ.pop(queue) do
      :error ->
        :error

      {:ok, {dist, state}, rest} ->
        key = key_fn.(state)
        current_best = Map.get(visited, key)

        if current_best != nil and compare.(dist, current_best) == :gt do
          # Skip outdated entry
          do_implicit_dijkstra(rest, successors, key_fn, is_goal, add, compare, visited)
        else
          if is_goal.(state) do
            {:ok, dist}
          else
            # Expand successors
            next_states = successors.(state)

            {new_queue, new_visited} =
              Enum.reduce(next_states, {rest, visited}, fn {next_state, cost}, {q, v} ->
                next_key = key_fn.(next_state)
                new_dist = add.(dist, cost)

                case Map.fetch(v, next_key) do
                  {:ok, current} ->
                    if compare.(new_dist, current) == :lt do
                      new_q = PQ.push(q, {new_dist, next_state})
                      new_v = Map.put(v, next_key, new_dist)
                      {new_q, new_v}
                    else
                      {q, v}
                    end

                  :error ->
                    new_q = PQ.push(q, {new_dist, next_state})
                    new_v = Map.put(v, next_key, new_dist)
                    {new_q, new_v}
                end
              end)

            do_implicit_dijkstra(
              new_queue,
              successors,
              key_fn,
              is_goal,
              add,
              compare,
              new_visited
            )
          end
        end
    end
  end
end
