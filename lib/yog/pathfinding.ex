defmodule Yog.Pathfinding do
  @moduledoc """
  Shortest path algorithms.

  Supports:
  - Dijkstra's algorithm (non-negative weights)
  - A* search (with heuristics)
  - Bellman-Ford (negative weights, cycle detection)

  ## Examples

      # Find shortest path with Dijkstra
      case Yog.Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &Kernel.+/2,
        compare: &Integer.compare/2
      ) do
        {:some, path} ->
          IO.puts("Found path with weight: \#{path.total_weight}")
        :none ->
          IO.puts("No path found")
      end
  """

  @doc """
  Finds the shortest path using Dijkstra's algorithm.

  Best for graphs with non-negative edge weights.

  ## Options

  - `:in` - The graph to search
  - `:from` - Starting node ID
  - `:to` - Goal node ID
  - `:zero` - Zero value for the weight type
  - `:add` - Function to add two weights
  - `:compare` - Function to compare two weights (returns `:lt`, `:eq`, or `:gt`)

  ## Returns

  - `{:some, path}` - Path with `.nodes` (list of node IDs) and `.total_weight`
  - `:none` - No path exists

  ## Examples

      case Yog.Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &Kernel.+/2,
        compare: &Integer.compare/2
      ) do
        {:some, path} -> path.total_weight
        :none -> :infinity
      end
  """
  @spec shortest_path(keyword()) :: {:some, term()} | :none
  def shortest_path(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    :yog@pathfinding.shortest_path(graph, from, to, zero, add, compare)
  end

  @doc """
  Finds the shortest path or raises an exception if none is found.
  See `shortest_path/1` for options.
  """
  @spec shortest_path!(keyword()) :: term()
  def shortest_path!(opts) do
    case shortest_path(opts) do
      {:some, path} -> path
      :none -> raise "No shortest path found from #{opts[:from]} to #{opts[:to]}"
    end
  end

  @doc """
  Finds the shortest path using A* search with a heuristic.

  Best for when you have a good heuristic estimate of remaining distance.

  ## Options

  - `:in` - The graph to search
  - `:from` - Starting node ID
  - `:to` - Goal node ID
  - `:zero` - Zero value for the weight type
  - `:add` - Function to add two weights
  - `:compare` - Function to compare two weights
  - `:heuristic` - Function that estimates cost from a node to the goal

  ## Examples

      # Manhattan distance heuristic for grid
      heuristic = fn node_id ->
        manhattan_distance(node_id, goal_id)
      end

      case Yog.Pathfinding.astar(
        in: graph,
        from: start,
        to: goal,
        zero: 0,
        add: &Kernel.+/2,
        compare: &Integer.compare/2,
        heuristic: heuristic
      ) do
        {:some, path} -> path
        :none -> :no_path
      end
  """
  @spec astar(keyword()) :: {:some, term()} | :none
  def astar(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    heuristic = Keyword.fetch!(opts, :heuristic)

    :yog@pathfinding.a_star(graph, from, to, zero, add, compare, heuristic)
  end

  @doc """
  Finds the shortest path using A* search or raises an exception if none is found.
  See `astar/1` for options.
  """
  @spec astar!(keyword()) :: term()
  def astar!(opts) do
    case astar(opts) do
      {:some, path} -> path
      :none -> raise "No A* path found from #{opts[:from]} to #{opts[:to]}"
    end
  end

  @doc """
  Finds the shortest path using Bellman-Ford algorithm.

  Supports negative edge weights and detects negative cycles.

  ## Options

  - `:in` - The graph to search
  - `:from` - Starting node ID
  - `:to` - Goal node ID
  - `:zero` - Zero value for the weight type
  - `:add` - Function to add two weights
  - `:compare` - Function to compare two weights

  ## Returns

  - `{:ok, {:some, path}}` - Path found
  - `{:ok, :none}` - No path exists
  - `{:error, :negative_cycle}` - Graph contains a negative cycle

  ## Examples

      case Yog.Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &Kernel.+/2,
        compare: &Integer.compare/2
      ) do
        {:ok, {:some, path}} -> path.total_weight
        {:ok, :none} -> :no_path
        {:error, :negative_cycle} -> :cycle_detected
      end
  """
  @spec bellman_ford(keyword()) :: {:ok, {:some, term()} | :none} | {:error, :negative_cycle}
  def bellman_ford(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    :yog@pathfinding.bellman_ford(graph, from, to, zero, add, compare)
  end

  @doc """
  Finds the shortest path using Bellman-Ford algorithms or raises an exception.
  Raises on negative cycles or if no path is found.
  See `bellman_ford/1` for options.
  """
  @spec bellman_ford!(keyword()) :: term()
  def bellman_ford!(opts) do
    case bellman_ford(opts) do
      {:ok, {:some, path}} -> path
      {:ok, :none} -> raise "No Bellman-Ford path found from #{opts[:from]} to #{opts[:to]}"
      {:error, :negative_cycle} -> raise "Negative cycle detected in graph!"
    end
  end

  @doc """
  Finds all-pairs shortest paths using the Floyd-Warshall algorithm.

  ## Options

  - `:in` - The graph to search
  - `:zero` - Zero value for the weight type
  - `:add` - Function to add two weights
  - `:compare` - Function to compare two weights

  ## Returns

  A nested map `%{start_node_id => %{end_node_id => distance}}`.
  """
  @spec floyd_warshall(keyword()) :: {:ok, %{Yog.node_id() => %{Yog.node_id() => term()}}} | {:error, term()}
  def floyd_warshall(opts) do
    graph = Keyword.fetch!(opts, :in)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    # Gleam dicts are returned as process dicts or special tuples, let's map them to Elixir maps
    case :yog@pathfinding.floyd_warshall(graph, zero, add, compare) do
      {:ok, dict_of_dicts} -> {:ok, unwrap_gleam_dict_of_dicts(dict_of_dicts)}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Computes single-source distances to all reachable nodes without tracking paths.
  
  ## Options

  - `:in` - The graph to search
  - `:from` - Starting node ID
  - `:zero` - Zero value for the weight type
  - `:add` - Function to add two weights
  - `:compare` - Function to compare two weights
  """
  @spec single_source_distances(keyword()) :: %{Yog.node_id() => term()}
  def single_source_distances(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)

    result = :yog@pathfinding.single_source_distances(graph, from, zero, add, compare)
    unwrap_gleam_dict(result)
  end

  # Helpers to unwrap Gleam Dicts into Elixir maps
  defp unwrap_gleam_dict(dict) do
    dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end
  
  defp unwrap_gleam_dict_of_dicts(dict_of_dicts) do
    dict_of_dicts
    |> :gleam@dict.to_list()
    |> Map.new(fn {k, inner_dict} -> {k, unwrap_gleam_dict(inner_dict)} end)
  end
end
