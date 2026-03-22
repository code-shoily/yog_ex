defmodule Yog.Pathfinding.Bidirectional do
  @moduledoc """
  Bidirectional search algorithms that meet in the middle for dramatic speedups.

  These algorithms start two simultaneous searches — one from the source
  and one from the target — that meet in the middle. This can dramatically
  reduce the search space compared to single-direction search.

  For a graph with branching factor `b` and depth `d`:
  - **Standard BFS**: `O(b^d)` nodes explored
  - **Bidirectional BFS**: `O(2 × b^(d/2))` nodes explored (up to 500x faster for long paths)

  ## Requirements

  - Target node must be known in advance (unlike Dijkstra, which can route many at once).
  - Designed for point-to-point queries.
  """

  alias Yog.Pathfinding.Utils

  @doc """
  Finds the shortest path in an unweighted graph using bidirectional BFS.

  This runs BFS from both source and target simultaneously, stopping when
  the frontiers meet.

  ## Options

    * `:in` - The graph
    * `:from` - The starting node ID
    * `:to` - The target node ID

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Pathfinding.Bidirectional.shortest_path_unweighted(in: graph, from: 1, to: 3)
      {:some, {:path, [1, 2, 3], 2}}
      iex> Yog.Pathfinding.Bidirectional.shortest_path_unweighted(in: graph, from: 1, to: 99)
      :none

  """
  @spec shortest_path_unweighted(keyword()) :: {:some, Utils.path(integer())} | :none
  def shortest_path_unweighted(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    :yog@pathfinding@bidirectional.shortest_path_unweighted(graph, from, to)
  end

  @doc """
  Finds the shortest path in a weighted graph using bidirectional Dijkstra.

  ## Options

    * `:in` - The graph
    * `:from` - The starting node ID
    * `:to` - The target node ID
    * `:zero` - The identity element for weights (e.g. `0`)
    * `:add` - Weight addition function (e.g. `fn a, b -> a + b end`)
    * `:compare` - Comparison function (e.g. `&Yog.Pathfinding.Utils.compare/2`)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 5)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 10)
      iex> Yog.Pathfinding.Bidirectional.shortest_path(
      ...>   in: graph, from: 1, to: 3,
      ...>   zero: 0, add: &+/2, compare: &Yog.Pathfinding.Utils.compare/2
      ...> )
      {:some, {:path, [1, 2, 3], 15}}
  """
  @spec shortest_path(keyword()) :: {:some, Utils.path(any())} | :none
  def shortest_path(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.get(opts, :compare, &Utils.compare/2)

    :yog@pathfinding@bidirectional.shortest_path(graph, from, to, zero, add, compare)
  end

  @doc """
  Finds the shortest path using bidirectional Dijkstra with integer weights.

  Convenience wrapper over `shortest_path/1` for graphs with integer weights.

  ## Options

    * `:in` - The graph
    * `:from` - The starting node ID
    * `:to` - The target node ID

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 5)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 10)
      iex> Yog.Pathfinding.Bidirectional.shortest_path_int(in: graph, from: 1, to: 3)
      {:some, {:path, [1, 2, 3], 15}}
  """
  @spec shortest_path_int(keyword()) :: {:some, Utils.path(integer())} | :none
  def shortest_path_int(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    :yog@pathfinding@bidirectional.shortest_path_int(graph, from, to)
  end

  @doc """
  Finds the shortest path using bidirectional Dijkstra with float weights.

  Convenience wrapper over `shortest_path/1` for graphs with float weights.

  ## Options

    * `:in` - The graph
    * `:from` - The starting node ID
    * `:to` - The target node ID

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 5.5)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 10.1)
      iex> Yog.Pathfinding.Bidirectional.shortest_path_float(in: graph, from: 1, to: 3)
      {:some, {:path, [1, 2, 3], 15.6}}
  """
  @spec shortest_path_float(keyword()) :: {:some, Utils.path(float())} | :none
  def shortest_path_float(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    :yog@pathfinding@bidirectional.shortest_path_float(graph, from, to)
  end
end
