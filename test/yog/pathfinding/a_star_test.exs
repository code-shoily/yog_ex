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
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 3, 0, &add/2, &compare/2, heuristic)

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
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    # Simple heuristic
    heuristic = fn _current, goal ->
      if goal == 3, do: 0, else: 5
    end

    result = AStar.a_star(graph, 1, 3, 0, &add/2, &compare/2, heuristic)

    assert {:ok, path} = result
    assert path.weight == 15
  end

  test "a_star_int_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star_int(graph, 1, 3, heuristic)

    assert {:ok, path} = result
    assert path.weight == 15
  end

  test "a_star_float_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5.5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10.5)

    heuristic = fn _, _ -> 0.0 end

    result = AStar.a_star_float(graph, 1, 3, heuristic)

    assert {:ok, path} = result
    assert path.weight == 16.0
  end

  test "a_star_no_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 2, 0, &add/2, &compare/2, heuristic)

    assert result == :error
  end

  test "a_star_same_start_and_goal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    heuristic = fn _, _ -> 0 end

    result = AStar.a_star(graph, 1, 1, 0, &add/2, &compare/2, heuristic)

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
        0,
        &add/2,
        &compare/2,
        heuristic
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
        0,
        &add/2,
        &compare/2,
        heuristic
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
        0,
        &add/2,
        &compare/2,
        heuristic
      )

    assert {:ok, 0} = result
  end
end
