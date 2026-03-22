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

      compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      BellmanFord.bellman_ford(graph, :a, :c, 0, &(&1+&2), compare)
      #=> {:shortest_path, {:path, [:a, :b, :c], 1}}
  """

  alias Yog.Pathfinding.Utils

  @typedoc "Result type for Bellman-Ford shortest path queries"
  @type result(weight) ::
          {:shortest_path, Utils.path(weight)} | :negative_cycle | :no_path

  @typedoc "Result type for implicit Bellman-Ford queries"
  @type implicit_result(weight) ::
          {:found_goal, weight} | :detected_negative_cycle | :no_goal

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

      Pathfinding.bellman_ford(
        in: graph,
        from: :a,
        to: :c,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      )
  """
  @spec bellman_ford(keyword()) :: result(any())
  def bellman_ford(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

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

  ## Examples

      Pathfinding.implicit_bellman_ford(
        from: 1,
        successors_with_cost: fn n -> [{n+1, -1}] end,
        is_goal: fn n -> n == 10 end,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      )
  """
  @spec implicit_bellman_ford(keyword()) :: implicit_result(any())
  def implicit_bellman_ford(opts) do
    from = Keyword.fetch!(opts, :from)
    successors = Keyword.fetch!(opts, :successors_with_cost)
    is_goal = Keyword.fetch!(opts, :is_goal)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    implicit_bellman_ford(from, successors, is_goal, zero, add, compare)
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
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

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

    * `{:shortest_path, path}` - A `Path` struct containing the nodes and weight
    * `:negative_cycle` - A negative cycle was detected
    * `:no_path` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_node(:c, nil)
      ...> |> Yog.add_edge!(:a, :b, 4)
      ...> |> Yog.add_edge!(:b, :c, -3)
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      iex> BellmanFord.bellman_ford(graph, :a, :c, 0, &(&1 + &2), compare)
      {:shortest_path, {:path, [:a, :b, :c], 1}}

      iex> # Graph with negative cycle
      iex> bad_graph = Yog.directed()
      ...> |> Yog.add_node(:a, nil)
      ...> |> Yog.add_node(:b, nil)
      ...> |> Yog.add_edge!(:a, :b, 1)
      ...> |> Yog.add_edge!(:b, :a, -3)
      iex> compare = fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      iex> BellmanFord.bellman_ford(bad_graph, :a, :b, 0, &(&1 + &2), compare)
      :negative_cycle
  """
  @spec bellman_ford(
          Yog.t(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: result(weight)
        when weight: var
  def bellman_ford(graph, from, to, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    case :yog@pathfinding@bellman_ford.bellman_ford(graph, from, to, zero, add, gleam_compare) do
      {:shortest_path, {:path, nodes, weight}} ->
        {:shortest_path, Utils.path(nodes, weight)}

      :negative_cycle ->
        :negative_cycle

      :no_path ->
        :no_path
    end
  end

  @doc """
  Find shortest path using Bellman-Ford with integer weights.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(1, 2, 4)
      ...> |> Yog.add_edge!(2, 3, -3)
      iex> BellmanFord.bellman_ford_int(graph, 1, 3)
      {:shortest_path, {:path, [1, 2, 3], 1}}
  """
  @spec bellman_ford_int(Yog.t(), Yog.node_id(), Yog.node_id()) :: result(integer())
  def bellman_ford_int(graph, from, to) do
    :yog@pathfinding@bellman_ford.bellman_ford_int(graph, from, to)
    |> wrap_result()
  end

  @doc """
  Find shortest path using Bellman-Ford with float weights.

  Convenience function for float weights.
  """
  @spec bellman_ford_float(Yog.t(), Yog.node_id(), Yog.node_id()) :: result(float())
  def bellman_ford_float(graph, from, to) do
    :yog@pathfinding@bellman_ford.bellman_ford_float(graph, from, to)
    |> wrap_result()
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
  def relaxation_passes(graph, from, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    all_nodes = :yog@model.all_nodes(graph)
    node_count = length(all_nodes)
    initial_distances = :gleam@dict.from_list([{from, zero}])
    initial_predecessors = :gleam@dict.new()

    {distances, _predecessors} =
      :yog@pathfinding@bellman_ford.relaxation_passes(
        graph,
        all_nodes,
        initial_distances,
        initial_predecessors,
        node_count - 1,
        add,
        gleam_compare
      )

    distances
    |> :gleam@dict.to_list()
    |> Map.new()
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
  def has_negative_cycle?(graph, from, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@bellman_ford.has_negative_cycle(graph, from, zero, add, gleam_compare)
  end

  @doc """
  Reconstructs a path from the predecessor map returned by Bellman-Ford.
  """
  @spec reconstruct_path(%{Yog.node_id() => Yog.node_id()}, Yog.node_id(), Yog.node_id(), any()) ::
          Utils.path(any())
  def reconstruct_path(predecessors, from, to, weight) do
    # Convert Elixir map to Gleam dict
    gleam_pred =
      predecessors
      |> Map.to_list()
      |> :gleam@dict.from_list()

    {:path, nodes, weight} =
      :yog@pathfinding@bellman_ford.reconstruct_path(gleam_pred, from, to, weight)

    Utils.path(nodes, weight)
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

    * `{:found_goal, cost}` - Minimum cost to reach goal
    * `:detected_negative_cycle` - A negative cycle was found
    * `:no_goal` - Goal is unreachable

  ## Examples

      # Search with negative weights
      iex> successors = fn
      ...>   1 -> [{2, -1}]
      ...>   2 -> [{3, -2}]
      ...>   3 -> [{4, -3}]
      ...>   4 -> []
      ...> end
      iex> BellmanFord.implicit_bellman_ford(
      ...>   1, successors, fn x -> x == 4 end,
      ...>   0, &(&1 + &2), fn a, b when a < b -> :lt; a, b when a > b -> :gt; _, _ -> :eq end
      ...> )
      {:found_goal, -6}
  """
  @spec implicit_bellman_ford(
          state,
          (state -> [{state, cost}]),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: implicit_result(cost)
        when state: var, cost: var
  def implicit_bellman_ford(from, successors, is_goal, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@bellman_ford.implicit_bellman_ford(
      from,
      successors,
      is_goal,
      zero,
      add,
      gleam_compare
    )
  end

  @doc """
  Implicit Bellman-Ford with a key function for visited state tracking.

  Similar to `implicit_bellman_ford/6`, but uses a key function for visited tracking.

  ## Parameters

    * `from` - Starting state
    * `successors` - Function `state -> [{neighbor, cost}]`
    * `key_fn` - Function `state -> key` for visited tracking
    * `is_goal` - Function `state -> boolean` to check if goal reached
    * `zero` - Identity value for the weight type
    * `add` - Function to add two weights
    * `compare` - Function to compare weights
  """
  @spec implicit_bellman_ford_by(
          state,
          (state -> [{state, cost}]),
          (state -> term()),
          (state -> boolean),
          cost,
          (cost, cost -> cost),
          (cost, cost -> :lt | :eq | :gt)
        ) :: implicit_result(cost)
        when state: var, cost: var
  def implicit_bellman_ford_by(from, successors, key_fn, is_goal, zero, add, compare) do
    gleam_compare = fn a, b ->
      case compare.(a, b) do
        :lt -> :lt
        :eq -> :eq
        :gt -> :gt
      end
    end

    :yog@pathfinding@bellman_ford.implicit_bellman_ford_by(
      from,
      successors,
      key_fn,
      is_goal,
      zero,
      add,
      gleam_compare
    )
  end

  # Private helper to wrap Gleam result
  defp wrap_result({:shortest_path, {:path, nodes, weight}}) do
    {:shortest_path, Utils.path(nodes, weight)}
  end

  defp wrap_result(:negative_cycle), do: :negative_cycle
  defp wrap_result(:no_path), do: :no_path
end
