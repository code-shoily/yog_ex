defmodule Yog.Pathfinding.YenTest do
  use ExUnit.Case

  alias Yog.Pathfinding.Yen
  doctest Yen

  # =============================================================================
  # Basic functionality
  # =============================================================================

  test "k=1 returns Dijkstra shortest path" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

    {:ok, [path]} = Yen.k_shortest_paths(graph, 1, 3, 1)
    assert path.nodes == [1, 2, 3]
    assert path.weight == 2
  end

  test "Yen example from documentation" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 2},
        {2, 3, 1},
        {2, 4, 3},
        {3, 4, 1},
        {3, 5, 4},
        {4, 5, 1}
      ])

    {:ok, paths} = Yen.k_shortest_paths(graph, 1, 5, 3)
    assert length(paths) == 3

    [p1, p2, p3] = paths
    assert p1.nodes == [1, 3, 4, 5]
    assert p1.weight == 4

    assert p2.nodes == [1, 2, 3, 4, 5]
    assert p2.weight == 4

    assert p3.nodes == [1, 2, 4, 5]
    assert p3.weight == 5
  end

  test "returns fewer paths when k exceeds possible paths" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

    {:ok, paths} = Yen.k_shortest_paths(graph, 1, 3, 10)
    assert length(paths) == 1
  end

  test "disconnected graph returns :error" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)

    assert Yen.k_shortest_paths(graph, 1, 3, 3) == :error
  end

  test "works on undirected graphs" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 3},
        {2, 3, 1},
        {2, 4, 2},
        {3, 4, 1}
      ])

    {:ok, paths} = Yen.k_shortest_paths(graph, 1, 4, 3)
    assert length(paths) == 3

    weights = Enum.map(paths, & &1.weight)
    assert weights == [3, 3, 4]
  end

  test "all returned paths are loopless" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1},
        {3, 2, 1},
        {3, 4, 1}
      ])

    {:ok, paths} = Yen.k_shortest_paths(graph, 1, 4, 3)

    for path <- paths do
      assert path.nodes == Enum.uniq(path.nodes),
             "Path #{inspect(path.nodes)} contains a loop"
    end
  end

  test "grid graph produces k distinct shortest paths" do
    # 2x2 grid:
    # 1 -- 2
    # |    |
    # 3 -- 4
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    {:ok, paths} = Yen.k_shortest_paths(graph, 1, 4, 2)
    assert length(paths) == 2

    [p1, p2] = paths
    assert p1.weight == 2
    assert p2.weight == 2
    assert p1.nodes != p2.nodes
  end

  test "weighted graph with custom opts" do
    graph =
      Yog.directed()
      |> Yog.add_node(:a, nil)
      |> Yog.add_node(:b, nil)
      |> Yog.add_node(:c, nil)
      |> Yog.add_edges!([
        {:a, :b, 10},
        {:b, :c, 10},
        {:a, :c, 25}
      ])

    opts = [with: fn w -> w * 2 end]
    {:ok, [path]} = Yen.k_shortest_paths(graph, :a, :c, 1, opts)
    assert path.weight == 40
  end

  test "facade delegation through Yog.Pathfinding" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

    {:ok, [path]} = Yog.Pathfinding.k_shortest_paths(graph, 1, 3, 1)
    assert path.nodes == [1, 2, 3]
  end

  test "empty graph returns :error" do
    graph = Yog.directed()
    assert Yen.k_shortest_paths(graph, 1, 2, 3) == :error
  end

  test "single node graph with source == target, k=1" do
    graph = Yog.directed() |> Yog.add_node(1, nil)
    {:ok, [path]} = Yen.k_shortest_paths(graph, 1, 1, 1)
    assert path.nodes == [1]
    assert path.weight == 0
  end
end
