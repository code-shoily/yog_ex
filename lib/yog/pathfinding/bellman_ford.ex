defmodule Yog.Pathfinding.BellmanFord do
  @moduledoc """
  Bellman-Ford algorithm for single-source shortest paths with negative weight support.

  Bellman-Ford can handle graphs with negative edge weights and detects negative
  cycles. It's slower than Dijkstra but more versatile.

  ## Algorithm Characteristics

  - **Time Complexity**: O(V × E)
  - **Space Complexity**: O(V)
  - **Requirements**: No negative cycles (detects them)
  - **Optimality**: Optimal for graphs without negative cycles

  ## When to Use

  - When edge weights may be negative
  - When you need to detect negative cycles
  - For all-pairs shortest paths (via V runs)
  - When Dijkstra's non-negative weight requirement can't be met

  ## Negative Cycles

  A negative cycle is a cycle whose total weight is negative. If one is reachable
  from the source, shortest paths are undefined (you can loop forever to decrease
  cost). Bellman-Ford detects this case.

  ## Examples

      # Graph with negative weights but no negative cycles
      graph = Yog.new()
      |> Yog.add_edge(:a, :b, 4)
      |> Yog.add_edge(:b, :c, -3)
      |> Yog.add_edge(:a, :c, 2)

      compare = &Yog.Utils.compare/2
      BellmanFord.bellman_ford(graph, :a, :c, 0, &(&1+&2), compare)
      #=> {:shortest_path, {:path, [:a, :b, :c], 1}}
  """

  alias Yog.Pathfinding.Path

  @typedoc "Result type for Bellman-Ford shortest path queries"
  @type result ::
          {:ok, Path.t()} | {:error, :negative_cycle} | {:error, :no_path}

  @typedoc "Result type for implicit Bellman-Ford queries"
  @type implicit_result(weight) ::
          {:ok, weight} | {:error, :negative_cycle} | {:error, :no_goal}

  # ============================================================
  # Keyword-style API (for Pathfinding module delegation)
  # ============================================================

  @doc """
  Find shortest path using Bellman-Ford with keyword options.

  ## Options

    * `:in` - The graph to search
    * `:from` - Starting node
    * `:to` - Target node
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights (`:lt`, `:eq`, `:gt`)

  ## Examples

      Pathfinding.BellmanFord.bellman_ford(
        in: graph,
        from: :a,
        to: :c,
        zero: 0,
        add: &(&1 + &2),
        compare: &Yog.Utils.compare/2
      )
  """
  @spec bellman_ford(keyword()) :: result()
  def bellman_ford(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    bellman_ford(graph, from, to, zero, add, compare)
  end

  @doc """
  Implicit Bellman-Ford using keyword options.

  ## Options

    * `:from` - Starting state
    * `:successors_with_cost` - Function returning neighbors with costs
    * `:is_goal` - Function to check if a state is the goal
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights
    * `:max_iterations` - Maximum iterations before giving up (default: 1000)

  ## Examples

      Pathfinding.implicit_bellman_ford(
        from: 1,
        successors_with_cost: fn n -> [{n+1, -1}] end,
        is_goal: fn n -> n == 10 end,
        zero: 0,
        add: &(&1 + &2),
        compare: &Yog.Utils.compare/2
      )
  """
  @spec implicit_bellman_ford(keyword()) :: implicit_result(any())
  def implicit_bellman_ford(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    max_iterations = Keyword.get(opts, :max_iterations, 1000)

    implicit_bellman_ford(from, successors, is_goal, zero, add, compare, max_iterations)
  end

  @doc """
  Implicit Bellman-Ford with key function using keyword options.

  ## Options

    * `:from` - Starting state
    * `:successors_with_cost` - Function returning neighbors with costs
    * `:visited_by` - Function to extract a key for visited tracking
    * `:is_goal` - Function to check if a state is the goal
    * `:zero` - Identity value for the weight type
    * `:add` - Function to add two weights
    * `:compare` - Function to compare weights
  """
  @spec implicit_bellman_ford_by(keyword()) :: implicit_result(any())
  def implicit_bellman_ford_by(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    visited_by = Keyword.fetch!(opts, :visited_by)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    implicit_bellman_ford_by(from, successors, visited_by, is_goal, zero, add, compare)
  end

  # ============================================================
  # Direct API
  # ============================================================

  @doc """
  Find the shortest path between two nodes using Bellman-Ford.

  ## Parameters

    * `graph` - The graph to search
    * `from` - Starting node
    * `to` - Target node
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights (`:lt`, `:eq`, `:gt`)

  ## Returns

    * `{:ok, path}` - A `Path` struct containing the nodes and weight
    * `{:error, :negative_cycle}` - A negative cycle was detected
    * `{:error, :no_path}` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge_ensure(:a, :b, 4)
      ...> |> Yog.add_edge_ensure(:b, :c, -3)
      iex> compare = &Yog.Utils.compare/2
      iex> {:ok, path} = BellmanFord.bellman_ford(graph, :a, :c, 0, &(&1 + &2), compare)
      iex> path.nodes
      [:a, :b, :c]
      iex> path.weight
      1

      iex> # Graph with negative cycle
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_edge_ensure(:a, :b, 1)
      ...> |> Yog.add_edge_ensure(:b, :a, -3)
      iex> compare = &Yog.Utils.compare/2
      iex> BellmanFord.bellman_ford(bad_graph, :a, :b, 0, &(&1 + &2), compare)
      {:error, :negative_cycle}
  """
  @spec bellman_ford(
          Yog.t(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: result()
        when weight: var
  def bellman_ford(
        graph,
        from,
        to,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    node_count = Yog.Model.order(graph)

    initial_distances = %{from => zero}
    initial_predecessors = %{}

    {distances, predecessors} =
      if node_count <= 1 do
        {initial_distances, initial_predecessors}
      else
        List.foldl(
          Enum.to_list(1..(node_count - 1)),
          {initial_distances, initial_predecessors},
          fn _, {dist, pred} ->
            relax_all_edges_from_graph(graph, dist, pred, add, compare)
          end
        )
      end

    {final_distances, _} =
      relax_all_edges_from_graph(graph, distances, predecessors, add, compare)

    if negative_cycle_detected?(graph.nodes, distances, final_distances, compare) do
      {:error, :negative_cycle}
    else
      case Map.fetch(distances, to) do
        {:ok, weight} ->
          path = reconstruct_path_from_predecessors(predecessors, from, to)
          {:ok, Path.new(path, weight, :bellman_ford)}

        :error ->
          {:error, :no_path}
      end
    end
  end

  @doc """
  Computes relaxation passes for all-pairs shortest paths.

  Returns a map of all node distances after V-1 relaxation passes.
  """
  @spec relaxation_passes(
          Yog.graph(),
          Yog.node_id(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: %{Yog.node_id() => any()}
  def relaxation_passes(
        graph,
        from,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    node_count = Yog.Model.order(graph)

    initial_distances = %{from => zero}
    initial_predecessors = %{}

    {distances, _} =
      List.foldl(
        Enum.to_list(1..(node_count - 1)),
        {initial_distances, initial_predecessors},
        fn _, {dist, pred} ->
          relax_all_edges_from_graph(graph, dist, pred, add, compare)
        end
      )

    distances
  end

  @doc """
  Checks if the graph contains a negative cycle reachable from the source.
  """
  @spec has_negative_cycle?(
          Yog.graph(),
          Yog.node_id(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt)
        ) :: boolean()
  def has_negative_cycle?(
        graph,
        from,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    node_count = Yog.Model.order(graph)

    initial_distances = %{from => zero}

    distances =
      List.foldl(Enum.to_list(1..(node_count - 1)), initial_distances, fn _, dist ->
        relax_all_edges_from_graph_no_pred(graph, dist, add, compare)
      end)

    final_distances = relax_all_edges_from_graph_no_pred(graph, distances, add, compare)

    negative_cycle_detected?(graph.nodes, distances, final_distances, compare)
  end

  @doc """
  Reconstructs a path from the predecessor map returned by Bellman-Ford.
  """
  @spec reconstruct_path(%{Yog.node_id() => Yog.node_id()}, Yog.node_id(), Yog.node_id(), any()) ::
          Path.t()
  def reconstruct_path(predecessors, from, to, weight) do
    path = reconstruct_path_from_predecessors(predecessors, from, to)
    Path.new(path, weight, :bellman_ford)
  end

  @doc """
  Run Bellman-Ford on an implicit (generated) graph.

  Similar to implicit Dijkstra, but supports negative edge weights and can
  detect negative cycles.

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights

  ## Returns

    * `{:ok, cost}` - Minimum cost to reach goal
    * `{:error, :negative_cycle}` - A negative cycle was found
    * `{:error, :no_goal}` - Goal is unreachable

  ## Examples

      # Search with negative weights
      iex> successors = fn
      ...>   1 -> [{2, -1}]
      ...>   2 -> [{3, -2}]
      ...>   3 -> [{4, -3}]
      ...>   4 -> []
      ...> end
      iex> {:ok, cost} = BellmanFord.implicit_bellman_ford(
      ...>   1, successors, fn x -> x == 4 end,
      ...>   0, &(&1 + &2), &Yog.Utils.compare/2
      ...> )
      iex> cost
      -6
  """
  @spec implicit_bellman_ford(
          state,
          (state -> [{state, cost}]),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt),
          non_neg_integer()
        ) :: implicit_result(cost)
        when state: var, cost: var
  def implicit_bellman_ford(
        from,
        successors,
        is_goal,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2,
        max_iterations \\ 1000
      ) do
    implicit_bellman_ford_by(
      from,
      successors,
      fn x -> x end,
      is_goal,
      zero,
      add,
      compare,
      max_iterations
    )
  end

  @doc """
  Implicit Bellman-Ford with a key function for visited state tracking.

  Similar to `implicit_bellman_ford/7`, but uses a key function for visited tracking.

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `key_fn` - Function `state -> key` for visited tracking
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights
    * `max_iterations` - Maximum iterations before giving up (default: 1000)
  """
  @spec implicit_bellman_ford_by(
          state,
          (state -> [{state, cost}]),
          (state -> term()),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt),
          non_neg_integer()
        ) :: implicit_result(cost)
        when state: var, cost: var
  def implicit_bellman_ford_by(
        from,
        successors,
        key_fn,
        is_goal,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2,
        max_iterations \\ 1000
      ) do
    initial_distances = %{key_fn.(from) => {from, zero}}

    do_implicit_bellman_ford(
      successors,
      key_fn,
      is_goal,
      add,
      compare,
      initial_distances,
      max_iterations
    )
  end

  # ============================================================
  # Helper functions
  # ============================================================

  defp relax_all_edges_from_graph(graph, distances, predecessors, add, compare) do
    out_edges = graph.out_edges

    :maps.fold(
      fn u, dist_u, {dist, pred} ->
        case Map.fetch(out_edges, u) do
          {:ok, edges} ->
            :maps.fold(
              fn v, weight, {d, p} ->
                new_dist_v = add.(dist_u, weight)

                case Map.fetch(d, v) do
                  {:ok, current_dist_v} ->
                    if compare.(new_dist_v, current_dist_v) == :lt do
                      {Map.put(d, v, new_dist_v), Map.put(p, v, u)}
                    else
                      {d, p}
                    end

                  :error ->
                    {Map.put(d, v, new_dist_v), Map.put(p, v, u)}
                end
              end,
              {dist, pred},
              edges
            )

          :error ->
            {dist, pred}
        end
      end,
      {distances, predecessors},
      distances
    )
  end

  # Relax all edges without tracking predecessors (protocol-compatible)
  defp relax_all_edges_from_graph_no_pred(graph, distances, add, compare) do
    out_edges = graph.out_edges

    :maps.fold(
      fn u, dist_u, dist ->
        case Map.fetch(out_edges, u) do
          {:ok, edges} ->
            :maps.fold(
              fn v, weight, d ->
                new_dist_v = add.(dist_u, weight)

                case Map.fetch(d, v) do
                  {:ok, current_dist_v} ->
                    if compare.(new_dist_v, current_dist_v) == :lt do
                      Map.put(d, v, new_dist_v)
                    else
                      d
                    end

                  :error ->
                    Map.put(d, v, new_dist_v)
                end
              end,
              dist,
              edges
            )

          :error ->
            dist
        end
      end,
      distances,
      distances
    )
  end

  defp negative_cycle_detected?(_nodes, old_distances, new_distances, compare) do
    :maps.fold(
      fn node, old_val, found? ->
        if found? do
          true
        else
          new_val = Map.get(new_distances, node)

          if new_val == nil do
            false
          else
            compare.(new_val, old_val) == :lt
          end
        end
      end,
      false,
      old_distances
    )
  end

  defp reconstruct_path_from_predecessors(predecessors, from, to) do
    reconstruct_path_recursive(predecessors, from, to, [to])
  end

  defp reconstruct_path_recursive(_predecessors, from, current, acc) when current == from do
    acc
  end

  defp reconstruct_path_recursive(predecessors, from, current, acc) do
    case Map.fetch(predecessors, current) do
      {:ok, prev} -> reconstruct_path_recursive(predecessors, from, prev, [prev | acc])
      # No path exists
      :error -> []
    end
  end

  defp do_implicit_bellman_ford(successors, key_fn, is_goal, add, compare, distances, max_iter) do
    # First, check if we've reached the goal
    goal_result =
      Enum.find_value(distances, fn {_, {state, dist}} ->
        if is_goal.(state) do
          {:ok, dist}
        else
          nil
        end
      end)

    if goal_result do
      goal_result
    else
      if max_iter <= 0 do
        # Too many iterations, likely a negative cycle
        {:error, :negative_cycle}
      else
        # Relax all edges from all current states
        # Relax all edges from all current states
        {next_distances, any_change} =
          :maps.fold(
            fn _, {state, state_dist}, {dists, changed} ->
              next_states = successors.(state)

              List.foldl(next_states, {dists, changed}, fn {next_state, cost}, {acc, ch} ->
                key = key_fn.(next_state)
                new_dist = add.(state_dist, cost)

                case Map.fetch(acc, key) do
                  {:ok, {_, current_dist}} ->
                    if compare.(new_dist, current_dist) == :lt do
                      {Map.put(acc, key, {next_state, new_dist}), true}
                    else
                      {acc, ch}
                    end

                  :error ->
                    {Map.put(acc, key, {next_state, new_dist}), true}
                end
              end)
            end,
            {distances, false},
            distances
          )

        if any_change do
          do_implicit_bellman_ford(
            successors,
            key_fn,
            is_goal,
            add,
            compare,
            next_distances,
            max_iter - 1
          )
        else
          {:error, :no_goal}
        end
      end
    end
  end
end
