defmodule YogTraversalTest do
  use ExUnit.Case

  # ============= BFS Tests =============

  test "bfs_linear_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first) == [1, 2, 3]
  end

  test "bfs_tree_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "LL")
      |> Yog.add_node(5, "LR")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)

    result = Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first)

    # Order of children depends on map order (Erlang dict), but level by level is guaranteed
    assert hd(result) == 1
    assert Enum.sort(Enum.slice(result, 1, 2)) == [2, 3]
    assert Enum.sort(Enum.slice(result, 3, 2)) == [4, 5]
  end

  test "bfs_with_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    result = Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first)
    assert result == [1, 2, 3]
  end

  test "bfs_isolated_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Isolated")
      |> Yog.add_node(2, "Other")

    assert Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first) == [1]
  end

  test "bfs_nonexistent_start_test" do
    graph = Yog.directed()
    assert Yog.Traversal.walk(in: graph, from: 99, using: :breadth_first) == [99]
  end

  test "bfs_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    result = Yog.Traversal.walk(in: graph, from: 2, using: :breadth_first)

    assert hd(result) == 2
    assert Enum.sort(tl(result)) == [1, 3]
  end

  # ============= DFS Tests =============

  test "dfs_linear_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Yog.Traversal.walk(in: graph, from: 1, using: :depth_first) == [1, 2, 3]
  end

  test "dfs_tree_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "LL")
      |> Yog.add_node(5, "LR")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)

    result = Yog.Traversal.walk(in: graph, from: 1, using: :depth_first)

    # DFS visits down the chain
    assert hd(result) == 1
    assert length(result) == 5
  end

  test "dfs_with_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    result = Yog.Traversal.walk(in: graph, from: 1, using: :depth_first)
    assert result == [1, 2, 3]
  end

  test "dfs_isolated_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Isolated")
      |> Yog.add_node(2, "Other")

    assert Yog.Traversal.walk(in: graph, from: 1, using: :depth_first) == [1]
  end

  test "dfs_diamond_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)

    result = Yog.Traversal.walk(in: graph, from: 1, using: :depth_first)

    assert length(result) == 4
    assert Enum.sort(result) == [1, 2, 3, 4]
  end

  # ============= walk_until Tests =============

  test "walk_until_bfs_stops_at_target_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)

    result =
      Yog.Traversal.walk_until(
        in: graph,
        from: 1,
        using: :breadth_first,
        until: fn id -> id == 3 end
      )

    assert result == [1, 2, 3]
  end

  test "walk_until_dfs_stops_at_target_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)

    result =
      Yog.Traversal.walk_until(
        in: graph,
        from: 1,
        using: :depth_first,
        until: fn id -> id == 3 end
      )

    assert result == [1, 2, 3]
  end

  test "walk_until_never_stops_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    result =
      Yog.Traversal.walk_until(
        in: graph,
        from: 1,
        using: :breadth_first,
        until: fn _id -> false end
      )

    assert result == [1, 2, 3]
  end

  test "walk_until_stops_at_start_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)

    result =
      Yog.Traversal.walk_until(
        in: graph,
        from: 1,
        using: :breadth_first,
        until: fn id -> id == 1 end
      )

    assert result == [1]
  end

  test "walk_until_complex_condition_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "LL")
      |> Yog.add_node(5, "LR")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)

    result =
      Yog.Traversal.walk_until(
        in: graph,
        from: 1,
        using: :breadth_first,
        until: fn id -> id > 3 end
      )

    # Should stop when reaching first node > 3
    # Order depends on erlang internals. Let's just make sure 4 or 5 is the last element
    assert length(result) == 3 or length(result) == 4
    assert List.last(result) > 3
  end

  # ============= Edge Cases =============

  test "traversal_with_self_loop_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 1, weight: 1)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)

    assert Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first) == [1, 2]
  end

  test "traversal_disconnected_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)

    assert Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first) == [1, 2]
  end
end
