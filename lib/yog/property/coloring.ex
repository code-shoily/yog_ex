defmodule Yog.Property.Coloring do
  @moduledoc """
  Graph coloring algorithms for finding valid colorings and estimating the chromatic number.

  Graph coloring assigns colors to vertices such that no two adjacent vertices share the
  same color. The minimum number of colors needed is called the *chromatic number* χ(G).

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Greedy coloring | [Welsh-Powell](https://en.wikipedia.org/wiki/Graph_coloring#Greedy_coloring) | `coloring_greedy/1` | O(V²) |
  | DSatur heuristic | [Degree of Saturation](https://en.wikipedia.org/wiki/DSatur) | `coloring_dsatur/1` | O(V²) |
  | Exact coloring | Backtracking with pruning | `coloring_exact/2` | O(k^V) worst case |

  ## Key Concepts

  - **Proper Coloring**: No adjacent vertices share the same color
  - **Chromatic Number χ(G)**: Minimum number of colors needed
  - **Upper Bound**: Any valid coloring gives an upper bound on χ(G)
  - **Greedy Coloring**: Fast but not optimal; bound depends on vertex ordering
  - **DSatur**: Usually produces better colorings than simple greedy
  - **Exact**: Finds optimal coloring via backtracking (practical for V < 30)

  ## Use Cases

  - **Scheduling**: Conflicting tasks get different time slots
  - **Register allocation**: Variables that overlap need different registers
  - **Map coloring**: Adjacent regions get different colors
  - **Frequency assignment**: Nearby transmitters use different frequencies
  - **Exam scheduling**: Courses with shared students need different times

  ## Examples

      iex> alias Yog.Property.Coloring
      iex> graph = Yog.Generator.Classic.complete(3)
      iex> {upper, colors} = Coloring.coloring_greedy(graph)
      iex> upper
      3
      iex> colors
      %{0 => 1, 1 => 2, 2 => 3}
      iex> {:ok, chi, _exact_colors} = Coloring.coloring_exact(graph)
      iex> chi
      3

  ## References

  - [Wikipedia: Graph Coloring](https://en.wikipedia.org/wiki/Graph_coloring)
  - [Wikipedia: DSatur](https://en.wikipedia.org/wiki/DSatur)
  - [CP-Algorithms: Graph Coloring](https://cp-algorithms.com/graph/bipartite-check.html)
  """

  alias Yog.Model

  @typedoc """
  A coloring result consisting of the chromatic upper bound and a node-to-color map.
  Colors are positive integers starting from 1.
  """
  @type coloring_result :: {non_neg_integer(), %{Yog.node_id() => pos_integer()}}

  @typedoc """
  Result of exact coloring: either an optimal solution or a timeout with the best found.
  """
  @type exact_result ::
          {:ok, pos_integer(), %{Yog.node_id() => pos_integer()}}
          | {:timeout, coloring_result()}

  # ============= Greedy Coloring (Welsh-Powell) =============

  @doc """
  Greedy graph coloring using Welsh-Powell ordering.

  Nodes are sorted by degree in descending order, then each node is assigned the
  smallest available color not used by any of its already-colored neighbors.

  ## Examples

      iex> graph = Yog.Generator.Classic.complete(3)
      iex> {upper, colors} = Yog.Property.Coloring.coloring_greedy(graph)
      iex> upper == 3
      true
      iex> colors[0] != colors[1]
      true

      iex> empty = Yog.Generator.Classic.empty(3)
      iex> {upper, _colors} = Yog.Property.Coloring.coloring_greedy(empty)
      iex> upper == 1
      true

  ## Time Complexity

  O(V²) in the worst case; O(V log V + E) with more efficient structures.
  """
  @spec coloring_greedy(Yog.graph()) :: coloring_result()
  def coloring_greedy(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      {0, %{}}
    else
      sorted = Enum.sort_by(nodes, &(-Model.degree(graph, &1)))

      {coloring, max_color} =
        Enum.reduce(sorted, {%{}, 0}, fn node, {coloring, max_color} ->
          neighbor_colors =
            Model.neighbor_ids(graph, node)
            |> Enum.map(&Map.get(coloring, &1))
            |> Enum.reject(&is_nil/1)
            |> MapSet.new()

          color = smallest_available_color(neighbor_colors, 1)
          {Map.put(coloring, node, color), max(max_color, color)}
        end)

      {max_color, coloring}
    end
  end

  # ============= DSatur (Degree of Saturation) =============

  @doc """
  DSatur heuristic for graph coloring.

  At each step, the uncolored node with the highest "saturation degree" (number of
  distinct colors among its colored neighbors) is chosen. Ties are broken by total
  degree. This usually produces better colorings than simple greedy ordering.

  ## Examples

      iex> graph = Yog.Generator.Classic.cycle(5)
      iex> {upper, _colors} = Yog.Property.Coloring.coloring_dsatur(graph)
      iex> upper == 3
      true

  ## Time Complexity

  O(V²) for this implementation.
  """
  @spec coloring_dsatur(Yog.graph()) :: coloring_result()
  def coloring_dsatur(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      {0, %{}}
    else
      adj = Map.new(nodes, fn node -> {node, MapSet.new(Model.neighbor_ids(graph, node))} end)
      degrees = Map.new(nodes, fn node -> {node, Model.degree(graph, node)} end)

      do_dsatur(nodes, adj, degrees, %{}, 0)
    end
  end

  defp do_dsatur([], _adj, _degrees, coloring, max_color), do: {max_color, coloring}

  defp do_dsatur(uncolored, adj, degrees, coloring, max_color) do
    node = select_dsatur_node(uncolored, adj, coloring, degrees)
    rest = List.delete(uncolored, node)

    neighbor_colors =
      adj[node]
      |> Enum.map(&Map.get(coloring, &1))
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    color = smallest_available_color(neighbor_colors, 1)

    do_dsatur(
      rest,
      adj,
      degrees,
      Map.put(coloring, node, color),
      max(max_color, color)
    )
  end

  defp select_dsatur_node(uncolored, adj, coloring, degrees) do
    Enum.max_by(uncolored, fn node ->
      saturation =
        adj[node]
        |> Enum.map(&Map.get(coloring, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> length()

      {saturation, degrees[node]}
    end)
  end

  # ============= Exact Coloring (Backtracking) =============

  @doc """
  Exact graph coloring using backtracking with pruning and an optional timeout.

  Tries to find the optimal (minimum) number of colors. For small graphs
  (roughly V < 30), this is usually fast enough. A timeout prevents the algorithm
  from hanging on larger or pathological instances.

  Returns `{:ok, chromatic_number, coloring}` on success, or `{:timeout, best_result}`
  if the timeout is reached, where `best_result` is the best valid coloring found so far.

  ## Examples

      iex> graph = Yog.Generator.Classic.complete(4)
      iex> {:ok, chi, _colors} = Yog.Property.Coloring.coloring_exact(graph)
      iex> chi == 4
      true

      iex> bipartite = Yog.Generator.Classic.complete_bipartite(3, 3)
      iex> {:ok, chi, _b_colors} = Yog.Property.Coloring.coloring_exact(bipartite)
      iex> chi == 2
      true

  ## Time Complexity

  Exponential in the worst case. Intended for small graphs only.
  """
  @spec coloring_exact(Yog.graph(), pos_integer()) :: exact_result()
  def coloring_exact(graph, timeout_ms \\ 5000) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      {:ok, 0, %{}}
    else
      adj = Map.new(nodes, fn node -> {node, Model.neighbor_ids(graph, node)} end)

      # Get an initial upper bound from DSatur
      {upper_bound, initial_coloring} = coloring_dsatur(graph)

      ordered_nodes = Enum.sort_by(nodes, &(-length(adj[&1])))

      deadline = System.monotonic_time(:millisecond) + timeout_ms

      state = %{
        adj: adj,
        ordered_nodes: ordered_nodes,
        best_chromatic: upper_bound,
        best_coloring: initial_coloring,
        deadline: deadline,
        timed_out: false
      }

      result = exact_backtrack(ordered_nodes, %{}, 0, state)

      if result.timed_out do
        {:timeout, {result.best_chromatic, result.best_coloring}}
      else
        {:ok, result.best_chromatic, result.best_coloring}
      end
    end
  end

  defp exact_backtrack([], coloring, max_used, state) do
    if max_used < state.best_chromatic do
      %{state | best_chromatic: max_used, best_coloring: coloring}
    else
      state
    end
  end

  defp exact_backtrack([node | rest], coloring, max_used, state) do
    if System.monotonic_time(:millisecond) > state.deadline do
      %{state | timed_out: true}
    else
      neighbors = state.adj[node]

      neighbor_colors =
        neighbors
        |> Enum.map(&Map.get(coloring, &1))
        |> Enum.reject(&is_nil/1)
        |> MapSet.new()

      # Try existing colors first, then one new color if it could improve the bound
      max_existing = if max_used == 0, do: 0, else: max_used

      state_after_existing =
        try_existing_colors(
          node,
          rest,
          coloring,
          max_used,
          state,
          neighbor_colors,
          1,
          max_existing
        )

      if state_after_existing.timed_out do
        state_after_existing
      else
        # Try introducing a new color only if it might lead to a better solution
        new_color = max_used + 1

        if new_color < state_after_existing.best_chromatic and
             not MapSet.member?(neighbor_colors, new_color) do
          new_coloring = Map.put(coloring, node, new_color)
          new_state = exact_backtrack(rest, new_coloring, new_color, state_after_existing)

          if new_state.timed_out do
            new_state
          else
            new_state
          end
        else
          state_after_existing
        end
      end
    end
  end

  defp try_existing_colors(_node, _rest, _coloring, _max_used, state, _forbidden, current, max)
       when current > max do
    state
  end

  defp try_existing_colors(node, rest, coloring, max_used, state, forbidden, current, max) do
    if MapSet.member?(forbidden, current) do
      try_existing_colors(node, rest, coloring, max_used, state, forbidden, current + 1, max)
    else
      new_coloring = Map.put(coloring, node, current)
      new_max = max(max_used, current)

      # Prune: if current max already >= best, skip this branch
      if new_max >= state.best_chromatic do
        try_existing_colors(node, rest, coloring, max_used, state, forbidden, current + 1, max)
      else
        new_state = exact_backtrack(rest, new_coloring, new_max, state)

        if new_state.timed_out do
          new_state
        else
          try_existing_colors(
            node,
            rest,
            coloring,
            max_used,
            new_state,
            forbidden,
            current + 1,
            max
          )
        end
      end
    end
  end

  # ============= Helpers =============

  defp smallest_available_color(forbidden_colors, candidate) do
    if MapSet.member?(forbidden_colors, candidate) do
      smallest_available_color(forbidden_colors, candidate + 1)
    else
      candidate
    end
  end
end
