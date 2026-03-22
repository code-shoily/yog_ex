defmodule Yog.Pathfinding do
  @moduledoc """
  Facade for pathfinding algorithms.

  Provides a unified keyword-based API for various pathfinding algorithms.
  """

  alias Yog.Pathfinding.Dijkstra
  alias Yog.Pathfinding.AStar
  alias Yog.Pathfinding.BellmanFord
  alias Yog.Pathfinding.FloydWarshall

  @doc """
  Finds the shortest path between two nodes using Dijkstra's algorithm.

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Zero value for weights
    * `:add` - Addition function for weights
    * `:compare` - Comparison function for weights (:lt, :eq, :gt)
  """
  def shortest_path(opts), do: Dijkstra.shortest_path(opts)

  @doc """
  Finds the shortest path using A* search with a heuristic.

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Zero value for weights
    * `:add` - Addition function for weights
    * `:compare` - Comparison function for weights
    * `:heuristic` - Heuristic function `(node, goal) -> weight`
  """
  def a_star(opts), do: AStar.a_star(opts)

  @doc """
  Alias for `a_star/1`.
  """
  def astar(opts), do: a_star(opts)

  @doc """
  Finds the shortest path using Bellman-Ford (supports negative weights).

  ## Options
    * `:in` - The graph to search
    * `:from` - Starting node ID
    * `:to` - Target node ID
    * `:zero` - Identity value for weights
    * `:add` - Addition function
    * `:compare` - Comparison function
  """
  def bellman_ford(opts), do: BellmanFord.bellman_ford(opts)

  @doc """
  Computes the distance matrix for all pairs of nodes using Floyd-Warshall.

  ## Options
    * `:in` - The graph to search
    * `:zero` - Identity element
    * `:add` - Addition function
    * `:compare` - Comparison function
  """
  def floyd_warshall(opts) do
    graph = Keyword.fetch!(opts, :in)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    FloydWarshall.floyd_warshall(graph, zero, add, compare)
  end
end
