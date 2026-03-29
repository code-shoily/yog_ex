defmodule Yog.TraversalTest do
  use ExUnit.Case

  doctest Yog.Traversal

  # ============= BFS Tests =============

  test "bfs_linear_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 5, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 5, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 5, with: 1)

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
      |> Yog.add_edge_ensure(from: 1, to: 1, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    assert Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first) == [1, 2]
  end

  test "traversal_disconnected_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    assert Yog.Traversal.walk(in: graph, from: 1, using: :breadth_first) == [1, 2]
  end

  # ============= fold_walk Tests =============

  test "fold_walk_bfs_distance_limit_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    result =
      Yog.Traversal.fold_walk(
        over: graph,
        from: 1,
        using: :breadth_first,
        initial: [],
        with: fn acc, node, meta ->
          if meta.depth <= 2 do
            {:continue, [node | acc]}
          else
            {:stop, acc}
          end
        end
      )

    assert Enum.sort(result) == [1, 2, 3]
  end

  # ============= Implicit Fold Tests =============

  test "implicit_fold_bfs_chain_test" do
    successors = fn state ->
      case state do
        1 -> [2]
        2 -> [3]
        _ -> []
      end
    end

    result =
      Yog.Traversal.implicit_fold(
        from: 1,
        using: :breadth_first,
        successors_of: successors,
        initial: [],
        with: fn acc, node, _meta -> {:continue, [node | acc]} end
      )

    assert Enum.sort(result) == [1, 2, 3]
  end

  test "implicit_fold_by_bfs_chain_test" do
    successors = fn state ->
      case state do
        # Both lead to nodes that have the same visited key
        1 -> [2, 3]
        2 -> [4]
        3 -> [4]
        _ -> []
      end
    end

    result =
      Yog.Traversal.implicit_fold_by(
        from: 1,
        using: :breadth_first,
        successors_of: successors,
        # Group by odd/even
        visited_by: fn state -> rem(state, 2) end,
        initial: [],
        with: fn acc, node, _meta -> {:continue, [node | acc]} end
      )

    # Starting at 1 (odd).
    # Its successors are 2 (even) and 3 (odd).
    # 3 will be ignored because 1 already marked the 'odd' key visited.
    # From 2 (even), its successor is 4 (even), which is ignored because 2 marked the 'even' key visited.
    assert Enum.sort(result) == [1, 2]
  end

  test "implicit_fold_best_first_test" do
    # Goal: visit nodes closest to 10 first
    successors = fn n -> if n < 5, do: [n + 1, n + 2], else: [] end

    result =
      Yog.Traversal.implicit_fold(
        from: 1,
        using: :best_first,
        successors_of: successors,
        priority: fn id, _meta -> abs(10 - id) end,
        initial: [],
        with: fn acc, node, _meta -> {:continue, [node | acc]} end
      )

    assert Enum.sort(result) == [1, 2, 3, 4, 5, 6]
  end

  test "implicit_fold_random_test" do
    successors = fn n -> if n < 5, do: [n + 1], else: [] end

    result =
      Yog.Traversal.implicit_fold(
        from: 1,
        using: :random,
        successors_of: successors,
        initial: [],
        with: fn acc, node, _meta -> {:continue, [node | acc]} end
      )

    assert Enum.sort(result) == [1, 2, 3, 4, 5]
  end

  test "implicit_fold_dfs_test" do
    # 1 -> [2, 3], 2 -> [4], 3 -> [5]
    successors = fn n ->
      case n do
        1 -> [2, 3]
        2 -> [4]
        3 -> [5]
        _ -> []
      end
    end

    result =
      Yog.Traversal.implicit_fold(
        from: 1,
        using: :depth_first,
        successors_of: successors,
        initial: [],
        with: fn acc, node, _meta -> {:continue, [node | acc]} end
      )

    # DFS visits down one branch completely before another
    assert length(result) == 5
    # result is reversed since we [node | acc]
    assert hd(result) in [4, 5]
  end

  test "implicit_fold_halt_test" do
    successors = fn n -> [n + 1] end

    result =
      Yog.Traversal.implicit_fold(
        from: 1,
        using: :breadth_first,
        successors_of: successors,
        initial: [],
        with: fn acc, node, _meta ->
          if node == 3, do: {:halt, [node | acc]}, else: {:continue, [node | acc]}
        end
      )

    assert Enum.sort(result) == [1, 2, 3]
  end

  test "implicit_fold_stop_test" do
    # 1 -> [2, 3], 2 -> [4], 3 -> [5]
    # Stop at 2 means don't explore 4, but continue with 3 and 5.
    successors = fn n ->
      case n do
        1 -> [2, 3]
        2 -> [4]
        3 -> [5]
        _ -> []
      end
    end

    result =
      Yog.Traversal.implicit_fold(
        from: 1,
        using: :breadth_first,
        successors_of: successors,
        initial: [],
        with: fn acc, node, _meta ->
          if node == 2, do: {:stop, [node | acc]}, else: {:continue, [node | acc]}
        end
      )

    # Should have 1, 2, 3, 5. 4 should be missing.
    assert Enum.sort(result) == [1, 2, 3, 5]
  end

  test "implicit_fold_by_dfs_test" do
    successors = fn n -> [n + 1, n + 2] end
    # Deduplicate by key n rem 2
    result =
      Yog.Traversal.implicit_fold_by(
        from: 1,
        using: :depth_first,
        successors_of: successors,
        visited_by: fn n -> rem(n, 2) end,
        initial: [],
        with: fn acc, node, _meta -> {:continue, [node | acc]} end
      )

    # Start 1 (rem 1). Successors 2 (rem 0), 3 (rem 1).
    # 3 is skipped. 2 explored.
    assert Enum.sort(result) == [1, 2]
  end

  # ============= Cycle Detection Tests =============

  test "cyclic_and_acyclic_test" do
    graph_acyclic =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    assert Yog.acyclic?(graph_acyclic) == true
    assert Yog.cyclic?(graph_acyclic) == false

    graph_cyclic =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 1, with: 1)

    assert Yog.acyclic?(graph_cyclic) == false
    assert Yog.cyclic?(graph_cyclic) == true
  end

  # ============= find_path Tests =============

  test "find_path_linear_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

    assert Yog.Traversal.find_path(graph, 1, 3) == [1, 2, 3]
  end

  test "find_path_shortest_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      # Long way in weight but short in edges
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 10)

    assert Yog.Traversal.find_path(graph, 1, 3) == [1, 3]
  end

  test "find_path_none_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    assert Yog.Traversal.find_path(graph, 1, 2) == nil
  end

  test "find_path_self_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A")
    assert Yog.Traversal.find_path(graph, 1, 1) == [1]
  end

  # ============= Topological Sort Tests =============

  test "topological_sort_dag_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

    assert {:ok, order} = Yog.Traversal.topological_sort(graph)
    # Valid topological order: 1 before 2 before 3
    assert Enum.find_index(order, &(&1 == 1)) < Enum.find_index(order, &(&1 == 2))
    assert Enum.find_index(order, &(&1 == 2)) < Enum.find_index(order, &(&1 == 3))
  end

  test "topological_sort_cyclic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    assert {:error, :contains_cycle} = Yog.Traversal.topological_sort(graph)
  end

  test "topological_sort_empty_test" do
    graph = Yog.directed()
    assert {:ok, []} = Yog.Traversal.topological_sort(graph)
  end

  test "topological_sort_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    assert {:ok, [1]} = Yog.Traversal.topological_sort(graph)
  end

  test "topological_sort_diamond_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "End")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    assert {:ok, order} = Yog.Traversal.topological_sort(graph)
    # 1 must be first, 4 must be last
    assert hd(order) == 1
    assert List.last(order) == 4
  end

  test "lexicographical_topological_sort_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "charlie")
      |> Yog.add_node(2, "alpha")
      |> Yog.add_node(3, "bravo")
      # Edges: 1 -> 3 -> 2 (charlie -> bravo -> alpha)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 2, with: 1)

    # When there are multiple choices, pick smallest by string value
    # Valid order respecting dependencies: 2 (alpha), 3 (bravo), 1 (charlie)
    assert {:ok, order} =
             Yog.Traversal.lexicographical_topological_sort(graph, fn a, b ->
               a <= b
             end)

    # The lexicographical sort should produce a deterministic order
    assert length(order) == 3
    # Dependencies must be respected: 1 before 3 before 2
    assert Enum.find_index(order, &(&1 == 1)) < Enum.find_index(order, &(&1 == 3))
    assert Enum.find_index(order, &(&1 == 3)) < Enum.find_index(order, &(&1 == 2))
  end

  test "lexicographical_topological_sort_cyclic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 1, with: 1)

    assert {:error, :contains_cycle} =
             Yog.Traversal.lexicographical_topological_sort(graph, &<=/2)
  end

  # ============= Best First Search Tests =============

  test "best_first_greedy_path_test" do
    # 1 -> 2 (100), 1 -> 3 (10)
    # 3 leads to 4 (weight 5)
    # 2 leads to 4 (weight 1)
    # Greedy walk where we pick lowest edge weight first
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 100)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 10)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 5)

    result =
      Yog.Traversal.walk(
        in: graph,
        from: 1,
        using: :best_first,
        priority: fn _id, weight, _meta -> weight end
      )

    # Starts at 1.
    # Frontiers: {10, 3}, {100, 2}
    # Pops 3. Visited: [1, 3].
    # New Frontiers: {100, 2}, {5, 4}
    # Pops 4. Visited: [1, 3, 4].
    # Pops 2. Visited: [1, 3, 4, 2].
    assert result == [1, 3, 4, 2]
  end

  test "best_first_heuristic_test" do
    # A simple grid-like graph where nodes have numerical IDs
    # Goal: get to node 10. Heuristic: distance to 10.
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(10, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 10, with: 1)

    # If h(2) = 8, h(3) = 7. It should pick 3 first.
    heuristic = fn id -> abs(10 - id) end

    result =
      Yog.Traversal.walk(
        in: graph,
        from: 1,
        using: :best_first,
        priority: fn id, _weight, _meta -> heuristic.(id) end
      )

    assert result == [1, 10, 3, 2] or result == [1, 3, 10, 2]
  end

  # ============= Random Walk Tests =============

  test "random_order_traversal_test" do
    # Simply check that all nodes are visited in some order
    graph =
      Yog.directed()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 4, 1, nil)

    result = Yog.Traversal.walk(in: graph, from: 1, using: :random)
    assert length(result) == 4
    assert Enum.sort(result) == [1, 2, 3, 4]
  end

  test "stochastic_random_walk_test" do
    # Path of 10 steps should result in 11 nodes
    graph =
      Yog.directed()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 1, 1, nil)

    path = Yog.Traversal.Walk.random_walk(graph, 1, 10)
    assert length(path) == 11
    # Check that it alternates between 1 and 2
    assert Enum.all?(path, fn node -> node in [1, 2] end)
  end

  test "stochastic_random_walk_dead_end_test" do
    # Should stop early if it hits a dead end
    graph = Yog.directed() |> Yog.add_node(1, nil)
    path = Yog.Traversal.Walk.random_walk(graph, 1, 10)
    assert path == [1]
  end
end
