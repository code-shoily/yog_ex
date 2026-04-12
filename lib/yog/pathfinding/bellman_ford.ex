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

  cost). Bellman-Ford detects this case.

  ## Examples

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    S [label="S"]; A [label="A"]; B [label="B"]; C [label="C"]; D [label="D"];
    S -> A [label="4", color="#ff5555", penwidth=2.5];
    S -> B [label="3"];
    A -> B [label="-2", color="#ff5555", penwidth=2.5];
    A -> C [label="4"];
    B -> C [label="-3", color="#ff5555", penwidth=2.5];
    B -> D [label="1"];
    C -> D [label="2", color="#ff5555", penwidth=2.5];
  }
  </div>

      iex> alias Yog.Pathfinding.BellmanFord
      iex> graph = Yog.from_edges(:directed, [
      ...>   {"S", "A", 4}, {"S", "B", 3}, {"A", "B", -2},
      ...>   {"A", "C", 4}, {"B", "C", -3}, {"B", "D", 1}, {"C", "D", 2}
      ...> ])
      iex> {:ok, path} = BellmanFord.bellman_ford(graph, "S", "D")
      iex> path.nodes
      ["S", "A", "B", "C", "D"]
      iex> path.weight
      1
      iex> # Detect unreachable goal
      iex> BellmanFord.bellman_ford(graph, "S", "NONEXISTENT")
      {:error, :no_path}

  ### Negative Cycles

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    X [label="X"]; Y [label="Y"]; Z [label="Z"];
    X -> Y [label="1", color="#ff5555", penwidth=2.5];
    Y -> Z [label="1", color="#ff5555", penwidth=2.5];
    Z -> X [label="-3", color="#ff5555", penwidth=2.5];
  }
  </div>

      iex> cycle_graph = Yog.from_edges(:directed, [
      ...>   {"X", "Y", 1}, {"Y", "Z", 1}, {"Z", "X", -3}
      ...> ])
      iex> BellmanFord.bellman_ford(cycle_graph, "X", "Z")
      {:error, :negative_cycle}
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
    nodes = Map.keys(graph.nodes)
    node_count = length(nodes)

    initial_distances = %{from => zero}
    initial_predecessors = %{}

    {distances, predecessors} =
      if node_count <= 1 do
        {initial_distances, initial_predecessors}
      else
        do_relaxation_passes(
          graph,
          nodes,
          initial_distances,
          initial_predecessors,
          add,
          compare,
          node_count - 1
        )
      end

    {_final_distances, _, changed?} =
      relax_all_edges_from_graph(graph, distances, predecessors, add, compare)

    if changed? do
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
    nodes = Map.keys(graph.nodes)
    node_count = length(nodes)

    initial_distances = %{from => zero}
    initial_predecessors = %{}

    {distances, _} =
      do_relaxation_passes(
        graph,
        nodes,
        initial_distances,
        initial_predecessors,
        add,
        compare,
        node_count - 1
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
    nodes = Map.keys(graph.nodes)
    node_count = length(nodes)

    initial_distances = %{from => zero}

    distances =
      Enum.reduce(1..(node_count - 1), initial_distances, fn _, dist ->
        {new_dist, _} = relax_all_edges_from_graph_no_pred(graph, dist, add, compare)
        new_dist
      end)

    {final_distances, changed?} =
      relax_all_edges_from_graph_no_pred(graph, distances, add, compare)

    changed? or negative_cycle_detected?(nodes, distances, final_distances, compare)
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

  # Relax edges for V-1 iterations with early termination optimization
  # If no distances change in an iteration, we can stop early
  defp do_relaxation_passes(_graph, _nodes, distances, predecessors, _add, _compare, 0) do
    {distances, predecessors}
  end

  defp do_relaxation_passes(graph, nodes, distances, predecessors, add, compare, iterations_left) do
    {new_dist, new_pred, changed?} =
      relax_all_edges_from_graph(graph, distances, predecessors, add, compare)

    if changed? do
      do_relaxation_passes(graph, nodes, new_dist, new_pred, add, compare, iterations_left - 1)
    else
      {new_dist, new_pred}
    end
  end

  # Returns {distances, predecessors, changed?}
  defp relax_all_edges_from_graph(graph, distances, predecessors, add, compare) do
    nodes = Map.keys(graph.nodes)

    Enum.reduce(nodes, {distances, predecessors, false}, fn u, acc ->
      relax_node_edges(graph, u, acc, add, compare)
    end)
  end

  defp relax_node_edges(graph, u, {dist, pred, changed}, add, compare) do
    case Map.get(dist, u) do
      nil ->
        {dist, pred, changed}

      dist_u ->
        successors = Map.get(graph.out_edges, u, %{})

        Enum.reduce(successors, {dist, pred, changed}, fn {v, weight}, acc ->
          relax_edge(acc, u, v, weight, dist_u, add, compare)
        end)
    end
  end

  defp relax_edge({d, p, ch}, u, v, weight, dist_u, add, compare) do
    new_dist_v = add.(dist_u, weight)
    current_dist_v = Map.get(d, v)

    if is_nil(current_dist_v) or compare.(new_dist_v, current_dist_v) == :lt do
      {Map.put(d, v, new_dist_v), Map.put(p, v, u), true}
    else
      {d, p, ch}
    end
  end

  # Relax all edges without tracking predecessors (protocol-compatible)
  # Returns {distances, changed?}
  defp relax_all_edges_from_graph_no_pred(graph, distances, add, compare) do
    nodes = Map.keys(graph.nodes)

    Enum.reduce(nodes, {distances, false}, fn u, acc ->
      relax_node_edges_no_pred(graph, u, acc, add, compare)
    end)
  end

  defp relax_node_edges_no_pred(graph, u, {dist, changed}, add, compare) do
    case Map.get(dist, u) do
      nil ->
        {dist, changed}

      dist_u ->
        successors = Map.get(graph.out_edges, u, %{})

        Enum.reduce(successors, {dist, changed}, fn {v, weight}, acc ->
          relax_edge_no_pred(acc, v, weight, dist_u, add, compare)
        end)
    end
  end

  defp relax_edge_no_pred({d, ch}, v, weight, dist_u, add, compare) do
    new_dist_v = add.(dist_u, weight)
    current_dist_v = Map.get(d, v)

    if is_nil(current_dist_v) or compare.(new_dist_v, current_dist_v) == :lt do
      {Map.put(d, v, new_dist_v), true}
    else
      {d, ch}
    end
  end

  defp negative_cycle_detected?(nodes, old_distances, new_distances, compare) do
    Enum.any?(nodes, fn node ->
      old_val = Map.get(old_distances, node)
      new_val = Map.get(new_distances, node)

      not is_nil(old_val) and not is_nil(new_val) and compare.(new_val, old_val) == :lt
    end)
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
      :error -> []
    end
  end

  defp do_implicit_bellman_ford(successors, key_fn, is_goal, add, compare, distances, max_iter) do
    case find_implicit_goal(distances, is_goal) do
      {:ok, dist} ->
        {:ok, dist}

      nil ->
        if max_iter <= 0 do
          {:error, :negative_cycle}
        else
          perform_implicit_iteration(
            successors,
            key_fn,
            is_goal,
            add,
            compare,
            distances,
            max_iter
          )
        end
    end
  end

  defp find_implicit_goal(distances, is_goal) do
    Enum.find_value(distances, fn {_, {state, dist}} ->
      if is_goal.(state), do: {:ok, dist}, else: nil
    end)
  end

  defp perform_implicit_iteration(successors, key_fn, is_goal, add, compare, distances, max_iter) do
    {next_distances, any_change} =
      Enum.reduce(distances, {distances, false}, fn {_, {state, dist}}, acc ->
        relax_implicit_neighbors(acc, state, dist, successors, key_fn, add, compare)
      end)

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

  defp relax_implicit_neighbors(
         {dists, changed},
         state,
         state_dist,
         successors,
         key_fn,
         add,
         compare
       ) do
    next_states = successors.(state)

    Enum.reduce(next_states, {dists, changed}, fn {next_state, cost}, acc ->
      relax_implicit_edge(acc, next_state, cost, state_dist, key_fn, add, compare)
    end)
  end

  defp relax_implicit_edge({acc, ch}, next_state, cost, state_dist, key_fn, add, compare) do
    key = key_fn.(next_state)
    new_dist = add.(state_dist, cost)

    case Map.get(acc, key) do
      {_, current_dist} ->
        if compare.(new_dist, current_dist) == :lt do
          {Map.put(acc, key, {next_state, new_dist}), true}
        else
          {acc, ch}
        end

      nil ->
        {Map.put(acc, key, {next_state, new_dist}), true}
    end
  end
end
