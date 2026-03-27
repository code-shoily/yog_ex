defmodule Yog.Test.Datasets do
  @moduledoc """
  Provdes canonical graph datasets for community detection and pathfinding benchmarks.
  """

  @doc """
  Zachary's Karate Club (34 nodes, 78 edges).
  A classic community detection benchmark. Successfully partitions into two main 
  factions (Officer side vs Mr. Hi side).
  """
  def karate_club do
    edges = [
      {1, 2},
      {1, 3},
      {1, 4},
      {1, 5},
      {1, 6},
      {1, 7},
      {1, 8},
      {1, 9},
      {1, 11},
      {1, 12},
      {1, 13},
      {1, 14},
      {1, 18},
      {1, 20},
      {1, 22},
      {1, 32},
      {2, 3},
      {2, 4},
      {2, 8},
      {2, 14},
      {2, 18},
      {2, 20},
      {2, 22},
      {2, 31},
      {3, 4},
      {3, 8},
      {3, 9},
      {3, 10},
      {3, 14},
      {3, 28},
      {3, 29},
      {3, 33},
      {4, 8},
      {4, 13},
      {4, 14},
      {5, 7},
      {5, 11},
      {6, 7},
      {6, 11},
      {6, 17},
      {7, 11},
      {9, 31},
      {9, 33},
      {9, 34},
      {10, 34},
      {14, 34},
      {15, 33},
      {15, 34},
      {16, 33},
      {16, 34},
      {19, 33},
      {19, 34},
      {20, 34},
      {21, 33},
      {21, 34},
      {23, 33},
      {23, 34},
      {24, 26},
      {24, 28},
      {24, 30},
      {24, 33},
      {24, 34},
      {25, 26},
      {25, 28},
      {25, 32},
      {26, 32},
      {27, 30},
      {27, 34},
      {28, 34},
      {29, 32},
      {29, 34},
      {30, 33},
      {30, 34},
      {31, 33},
      {31, 34},
      {32, 33},
      {32, 34},
      {33, 34}
    ]

    graph = Yog.undirected()

    Enum.reduce(edges, graph, fn {u, v}, acc ->
      Yog.add_edge_ensure(acc, u, v, 1, nil)
    end)
  end

  @doc """
  Small benchmark graph with exactly 2 known clusters.
  """
  def dual_cliques(n) do
    # Two cliques of size n connected by a single edge
    edges_a = for u <- 1..n, v <- 1..n, u < v, do: {u, v, 1}
    edges_b = for u <- (n + 1)..(2 * n), v <- (n + 1)..(2 * n), u < v, do: {u, v, 1}
    bridge = {n, n + 1, 1}

    graph = Yog.undirected()

    Enum.reduce(edges_a ++ edges_b ++ [bridge], graph, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w, nil)
    end)
  end
end
