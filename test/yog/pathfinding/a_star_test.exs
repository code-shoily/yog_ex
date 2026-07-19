defmodule Yog.Pathfinding.AStarTest do
  use ExUnit.Case
  alias Yog.Pathfinding.AStar

  doctest AStar

  # Helper functions for algorithms
  defp compare(a, b), do: if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq))
  defp add(a, b), do: a + b

  # ============= Zero Heuristic Tests (A* = Dijkstra) =============

  test "a_star_zero_heuristic_test" do
    # With h(n) = 0, A* should behave like Dijkstra
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 3, heuristic, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1, 2, 3]
    assert path.weight == 15
  end

  test "a_star_simple_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    # Simple heuristic
    heuristic = fn _current, goal ->
      if goal == 3, do: 0, else: 5
    end

    result = AStar.a_star(graph, 1, 3, heuristic, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.weight == 15
  end

  test "a_star_int_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 3, heuristic)

    assert {:ok, path} = result
    assert path.weight == 15
  end

  test "a_star_float_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5.5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10.5)

    heuristic = fn _, _ -> 0.0 end

    result = AStar.a_star(graph, 1, 3, heuristic)

    assert {:ok, path} = result
    assert path.weight == 16.0
  end

  test "a_star_no_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 2, heuristic, 0, &add/2, &compare/2)

    assert result == :error
  end

  test "a_star_same_start_and_goal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 1, heuristic, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1]
    assert path.weight == 0
  end

  # ============= Implicit A* Tests =============

  test "implicit_a_star_linear_path_test" do
    successors = fn
      1 -> [{2, 1}]
      2 -> [{3, 2}]
      3 -> [{4, 3}]
      _ -> []
    end

    heuristic = fn n -> 10 - n end

    result =
      AStar.implicit_a_star(
        1,
        successors,
        fn x -> x == 4 end,
        heuristic,
        0,
        &add/2,
        &compare/2
      )

    assert {:ok, 6} = result
  end

  test "implicit_a_star_no_path_test" do
    successors = fn
      1 -> [{2, 1}]
      2 -> [{3, 2}]
      _ -> []
    end

    heuristic = fn n -> 100 - n end

    result =
      AStar.implicit_a_star(
        1,
        successors,
        fn x -> x == 99 end,
        heuristic,
        0,
        &add/2,
        &compare/2
      )

    assert result == :error
  end

  test "implicit_a_star_start_is_goal_test" do
    successors = fn n -> [{n + 1, 1}] end
    heuristic = fn _ -> 0 end

    result =
      AStar.implicit_a_star(
        42,
        successors,
        fn x -> x == 42 end,
        heuristic,
        0,
        &add/2,
        &compare/2
      )

    assert {:ok, 0} = result
  end

  test "a_star_keyword_api_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

    result =
      AStar.a_star(
        in: graph,
        from: 1,
        to: 2,
        heuristic: fn _, _ -> 0 end
      )

    assert {:ok, path} = result
    assert path.weight == 5
  end

  test "implicit_a_star_keyword_api_test" do
    result =
      AStar.implicit_a_star(
        from: 1,
        successors_with_cost: fn n -> [{n + 1, 1}] end,
        is_goal: fn n -> n == 3 end,
        heuristic: fn n -> 3 - n end
      )

    assert {:ok, 2} = result
  end

  test "a_star and implicit_a_star default arguments" do
    # a_star with defaults
    graph =
      Yog.undirected()
      |> Yog.add_node(1)
      |> Yog.add_node(2)
      |> Yog.add_edge!(1, 2, 5)

    {:ok, path} = AStar.a_star(graph, 1, 2, fn _, _ -> 0 end)
    assert path.weight == 5

    # implicit_a_star with defaults
    assert {:ok, 2} =
             AStar.implicit_a_star(1, fn n -> [{n + 1, 1}] end, fn n -> n == 3 end, fn n ->
               3 - n
             end)

    # implicit_a_star_by with defaults
    assert {:ok, 2} =
             AStar.implicit_a_star_by(
               1,
               fn n -> [{n + 1, 1}] end,
               fn n -> n end,
               fn n -> n == 3 end,
               fn n -> 3 - n end
             )
  end

  test "a_star discards longer popped paths" do
    # Graph structure:
    # 1 -> 2 (10)
    # 1 -> 3 (1)
    # 3 -> 2 (1)
    # 2 -> 4 (100)
    # Target is 4. When 1 is processed, 2 gets queued with g=10, 3 gets queued with g=1.
    # 3 gets popped, relaxes 3 -> 2, updates 2's g to 2, queues 2 with g=2.
    # 2 with g=2 gets popped, relaxes 2 -> 4, updates 4's g to 102.
    # Now queue has 2 with g=10 (f = 10) and 4 with g=102 (f = 102).
    # 2 with g=10 gets popped. Its g (10) > best_g (2), so it is discarded.
    graph =
      Yog.undirected()
      |> Yog.add_node(1)
      |> Yog.add_node(2)
      |> Yog.add_node(3)
      |> Yog.add_node(4)
      |> Yog.add_edge!(1, 2, 10)
      |> Yog.add_edge!(1, 3, 1)
      |> Yog.add_edge!(3, 2, 1)
      |> Yog.add_edge!(2, 4, 100)

    {:ok, path} = AStar.a_star(graph, 1, 4, fn _, _ -> 0 end)
    assert path.weight == 102
    assert path.nodes == [1, 3, 2, 4]
  end

  test "implicit_a_star discards longer popped paths" do
    # Implicit version of the longer popped path test
    successors = fn
      1 -> [{2, 10}, {3, 1}]
      3 -> [{2, 1}]
      2 -> [{4, 100}]
      4 -> []
    end

    assert {:ok, 102} = AStar.implicit_a_star(1, successors, fn n -> n == 4 end, fn _ -> 0 end)
  end

  test "a_star error on missing from node" do
    graph = Yog.directed() |> Yog.add_node(2)
    assert AStar.a_star(graph, 1, 2, fn _, _ -> 0 end) == :error
  end

  test "a_star error on missing to node" do
    graph = Yog.directed() |> Yog.add_node(1)
    assert AStar.a_star(graph, 1, 2, fn _, _ -> 0 end) == :error
  end

  test "a_star empty graph" do
    graph = Yog.directed()
    assert AStar.a_star(graph, 1, 1, fn _, _ -> 0 end) == :error
  end

  test "a_star single node graph same start and goal" do
    graph = Yog.directed() |> Yog.add_node(1)
    assert {:ok, path} = AStar.a_star(graph, 1, 1, fn _, _ -> 0 end)
    assert path.nodes == [1]
    assert path.weight == 0
  end

  test "a_star directed vs undirected behavior" do
    # Directed graph: path exists in one direction
    dg =
      Yog.directed()
      |> Yog.add_node(1)
      |> Yog.add_node(2)
      |> Yog.add_edge!(1, 2, 5)

    assert {:ok, path} = AStar.a_star(dg, 1, 2, fn _, _ -> 0 end)
    assert path.weight == 5
    assert AStar.a_star(dg, 2, 1, fn _, _ -> 0 end) == :error

    # Undirected graph: path exists in both directions
    ug =
      Yog.undirected()
      |> Yog.add_node(1)
      |> Yog.add_node(2)
      |> Yog.add_edge!(1, 2, 5)

    assert {:ok, path1} = AStar.a_star(ug, 1, 2, fn _, _ -> 0 end)
    assert path1.weight == 5
    assert {:ok, path2} = AStar.a_star(ug, 2, 1, fn _, _ -> 0 end)
    assert path2.weight == 5
  end

  test "a_star self-loops are ignored" do
    graph =
      Yog.directed()
      |> Yog.add_node(1)
      |> Yog.add_node(2)
      |> Yog.add_edge!(1, 1, 2)
      |> Yog.add_edge!(1, 2, 5)

    assert {:ok, path} = AStar.a_star(graph, 1, 2, fn _, _ -> 0 end)
    assert path.nodes == [1, 2]
    assert path.weight == 5
  end

  test "options validation - missing required keys" do
    graph = Yog.directed() |> Yog.add_node(1) |> Yog.add_node(2) |> Yog.add_edge!(1, 2, 5)

    assert_raise KeyError, fn ->
      AStar.a_star(in: graph, from: 1, to: 2)
    end

    assert_raise KeyError, fn ->
      AStar.implicit_a_star(
        successors_with_cost: fn n -> [{n + 1, 1}] end,
        is_goal: fn n -> n == 3 end,
        heuristic: fn n -> 3 - n end
      )
    end

    assert_raise KeyError, fn ->
      AStar.implicit_a_star_by(
        from: 1,
        successors_with_cost: fn n -> [{n + 1, 1}] end,
        is_goal: fn n -> n == 3 end,
        heuristic: fn n -> 3 - n end
      )
    end
  end

  test "options validation - unknown option keys" do
    graph = Yog.directed() |> Yog.add_node(1) |> Yog.add_node(2) |> Yog.add_edge!(1, 2, 5)

    assert_raise ArgumentError, ~r/unknown option :invalid_key/, fn ->
      AStar.a_star(in: graph, from: 1, to: 2, heuristic: fn _, _ -> 0 end, invalid_key: true)
    end
  end
end
