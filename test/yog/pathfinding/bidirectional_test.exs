defmodule Yog.Pathfinding.BidirectionalTest do
  use ExUnit.Case

  alias Yog.Pathfinding.Bidirectional
  alias Yog.Pathfinding.Dijkstra

  doctest Bidirectional

  test "shortest_path returns error for unreachable path" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)

    assert :error ==
             Bidirectional.shortest_path(
               in: graph,
               from: 1,
               to: 2
             )
  end

  test "shortest_path_unweighted on directed graph with single path" do
    # 1 -> 2 -> 3 -> 4 (no reverse edges)
    # The old bug used out_edges for both directions, so backward search
    # from 4 could not walk backwards.
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    assert {:ok, path} = Bidirectional.shortest_path_unweighted(graph, 1, 4)
    assert path.nodes == [1, 2, 3, 4]
    assert path.weight == 3
  end

  test "shortest_path_unweighted same node" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)

    assert {:ok, path} = Bidirectional.shortest_path_unweighted(graph, 1, 1)
    assert path.nodes == [1]
    assert path.weight == 0
  end

  test "shortest_path_unweighted on undirected graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

    assert {:ok, path} = Bidirectional.shortest_path_unweighted(graph, 1, 3)
    assert path.nodes == [1, 2, 3]
    assert path.weight == 2

    assert {:ok, reverse} = Bidirectional.shortest_path_unweighted(graph, 3, 1)
    assert reverse.nodes == [3, 2, 1]
    assert reverse.weight == 2
  end

  test "shortest_path_unweighted diamond pattern" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    assert {:ok, path} = Bidirectional.shortest_path_unweighted(graph, 1, 4)
    assert path.weight == 2
  end

  test "shortest_path weighted directed graph" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {1, 2, 5},
        {2, 3, 10},
        {1, 3, 20}
      ])

    assert {:ok, path} =
             Bidirectional.shortest_path(graph, 1, 3, 0, &+/2, &Yog.Utils.compare/2)

    assert path.nodes == [1, 2, 3]
    assert path.weight == 15
  end

  test "shortest_path agrees with standard Dijkstra" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {1, 2, 4},
        {1, 3, 2},
        {2, 4, 5},
        {3, 4, 8},
        {3, 5, 10},
        {4, 5, 2}
      ])

    assert {:ok, bi_path} =
             Bidirectional.shortest_path(graph, 1, 5, 0, &+/2, &Yog.Utils.compare/2)

    assert {:ok, std_path} =
             Dijkstra.shortest_path(graph, 1, 5, 0, &+/2, &Yog.Utils.compare/2)

    assert bi_path.weight == std_path.weight
  end
end
