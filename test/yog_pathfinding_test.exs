defmodule YogPathfindingTest do
  use ExUnit.Case

  alias Yog.Pathfinding

  # ============= Basic Path Tests =============

  # Simple linear path: 1 -> 2 -> 3
  test "shortest_path_linear_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 10)

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:some, {:path, [1, 2, 3], 15}} = result
  end

  # Direct path exists
  test "shortest_path_direct_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 2,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:some, {:path, [1, 2], 10}} = result
  end

  # Start and goal are the same
  test "shortest_path_same_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 1,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:some, {:path, [1], 0}} = result
  end

  # No path exists
  test "shortest_path_no_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)

    # No edge to node 3

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert result == :none
  end

  # Start node doesn't exist
  test "shortest_path_invalid_start_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 99,
        to: 2,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert result == :none
  end

  # Goal node doesn't exist
  test "shortest_path_invalid_goal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 99,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert result == :none
  end

  # ============= Multiple Path Tests =============

  # Two paths, one is shorter
  #   1 --(5)--> 2 --(10)--> 3
  #    \                    /
  #     --------(20)-------
  test "shortest_path_two_paths_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 10)
      |> Yog.add_edge(from: 1, to: 3, with: 20)

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:some, {:path, [1, 2, 3], 15}} = result
  end

  # Direct path is shorter than indirect
  #   1 --(5)--> 3
  #    \        /
  #     --(2)--> 2 --(10)--
  test "shortest_path_direct_shorter_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 3, with: 5)
      |> Yog.add_edge(from: 1, to: 2, with: 2)
      |> Yog.add_edge(from: 2, to: 3, with: 10)

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:some, {:path, [1, 3], 5}} = result
  end

  # Diamond graph - multiple paths
  #      1
  #     / \
  #   (2) (3)
  #   /     \
  #  2       3
  #  |       |
  # (4)     (5)
  #   \     /
  #     \ /
  #      4
  test "shortest_path_diamond_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge(from: 1, to: 2, with: 2)
      |> Yog.add_edge(from: 1, to: 3, with: 3)
      |> Yog.add_edge(from: 2, to: 4, with: 4)
      |> Yog.add_edge(from: 3, to: 4, with: 5)

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 4,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    # Path through left is 2+4=6, path through right is 3+5=8
    assert {:some, {:path, [1, 2, 4], 6}} = result
  end

  # ============= Complex Graph Tests =============

  # Grid-like graph with multiple routes
  test "shortest_path_grid_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_node(6, "F")
      # Row 1
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      # Row 2
      |> Yog.add_edge(from: 4, to: 5, with: 1)
      |> Yog.add_edge(from: 5, to: 6, with: 1)
      # Columns
      |> Yog.add_edge(from: 1, to: 4, with: 10)
      |> Yog.add_edge(from: 2, to: 5, with: 1)
      |> Yog.add_edge(from: 3, to: 6, with: 10)

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 6,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    # Best path: 1->2->5->6 with weight 1+1+1=3
    assert {:some, {:path, [1, 2, 5, 6], 3}} = result
  end

  # Graph with cycle
  test "shortest_path_with_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 1)

    # Cycle: 1->2->3->1

    result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:some, {:path, [1, 2, 3], 2}} = result
  end

  # ============= A* Search Tests =============

  # A* with zero heuristic (equivalent to Dijkstra)
  test "astar_zero_heuristic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 10)

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: fn _, _ -> 0 end
      )

    assert {:some, {:path, [1, 2, 3], 15}} = result
  end

  # A* with Manhattan distance heuristic (grid)
  test "astar_manhattan_distance_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "0,0")
      |> Yog.add_node(2, "1,0")
      |> Yog.add_node(3, "2,0")
      |> Yog.add_node(4, "0,1")
      |> Yog.add_node(5, "1,1")
      |> Yog.add_node(6, "2,1")
      # Grid connections (each edge cost 1)
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 1, to: 4, with: 1)
      |> Yog.add_edge(from: 2, to: 5, with: 1)
      |> Yog.add_edge(from: 3, to: 6, with: 1)
      |> Yog.add_edge(from: 4, to: 5, with: 1)
      |> Yog.add_edge(from: 5, to: 6, with: 1)

    # Manhattan distance heuristic
    # Node positions: 1=(0,0), 2=(1,0), 3=(2,0), 4=(0,1), 5=(1,1), 6=(2,1)
    manhattan = fn from, to ->
      case {from, to} do
        # |0-2| + |0-1| = 3
        {1, 6} -> 3
        # |1-2| + |0-1| = 2
        {2, 6} -> 2
        # |2-2| + |0-1| = 1
        {3, 6} -> 1
        # |0-2| + |1-1| = 2
        {4, 6} -> 3
        # |1-2| + |1-1| = 1
        {5, 6} -> 1
        _ -> 0
      end
    end

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 6,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: manhattan
      )

    assert {:some, {:path, _nodes, 3}} = result
  end

  # A* finds better path than greedy
  test "astar_better_than_greedy_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(4, "Goal")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 2)
      |> Yog.add_edge(from: 2, to: 4, with: 100)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    # Heuristic that prefers node 2 initially
    h = fn from, to ->
      case {from, to} do
        # Underestimate for node 2
        {2, 4} -> 10
        # Good estimate for node 3
        {3, 4} -> 1
        _ -> 0
      end
    end

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 4,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: h
      )

    assert {:some, {:path, [1, 3, 4], 3}} = result
  end

  # A* with same start and goal
  test "astar_same_start_goal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 1,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: fn _, _ -> 0 end
      )

    assert {:some, {:path, [1], 0}} = result
  end

  # A* with no path
  test "astar_no_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: fn _, _ -> 0 end
      )

    assert result == :none
  end

  # A* with admissible heuristic finds optimal path
  test "astar_admissible_heuristic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      # Multiple paths from 1 to 5
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 5, with: 10)
      |> Yog.add_edge(from: 1, to: 3, with: 3)
      |> Yog.add_edge(from: 3, to: 4, with: 2)
      |> Yog.add_edge(from: 4, to: 5, with: 1)

    # Admissible heuristic (never overestimates)
    h = fn from, to ->
      case {from, to} do
        {1, 5} -> 5
        {2, 5} -> 4
        {3, 5} -> 3
        {4, 5} -> 1
        _ -> 0
      end
    end

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: h
      )

    assert {:some, {:path, [1, 3, 4, 5], 6}} = result
  end

  # A* on diamond graph
  test "astar_diamond_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge(from: 1, to: 2, with: 2)
      |> Yog.add_edge(from: 1, to: 3, with: 3)
      |> Yog.add_edge(from: 2, to: 4, with: 4)
      |> Yog.add_edge(from: 3, to: 4, with: 5)

    h = fn from, to ->
      case {from, to} do
        {1, 4} -> 5
        {2, 4} -> 3
        {3, 4} -> 4
        _ -> 0
      end
    end

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 4,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: h
      )

    assert {:some, {:path, [1, 2, 4], 6}} = result
  end

  # A* empty graph
  test "astar_empty_graph_test" do
    graph = Yog.directed()

    result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 2,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: fn _, _ -> 0 end
      )

    assert result == :none
  end

  # A* comparison with Dijkstra
  test "astar_vs_dijkstra_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 4)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 2, to: 4, with: 5)
      |> Yog.add_edge(from: 3, to: 4, with: 1)
      |> Yog.add_edge(from: 4, to: 5, with: 2)

    astar_result =
      Pathfinding.astar(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
        heuristic: fn _, _ -> 0 end
      )

    dijkstra_result =
      Pathfinding.shortest_path(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert astar_result == dijkstra_result
  end

  # ============= Bellman-Ford Tests =============

  # Basic shortest path (no negative weights)
  test "bellman_ford_basic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 10)

    result =
      Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:shortest_path, {:path, [1, 2, 3], 15}} = result
  end

  # Negative edge weights (still finds shortest path)
  test "bellman_ford_negative_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: -5)

    result =
      Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert {:shortest_path, {:path, [1, 2, 3], 5}} = result
  end

  # Negative weights make different path optimal
  test "bellman_ford_negative_optimal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 4, with: 5)
      |> Yog.add_edge(from: 1, to: 2, with: 2)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 4, with: -10)

    result =
      Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 4,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    # Path through 2,3 is 2+2-10=-6, direct is 5
    assert {:shortest_path, {:path, [1, 2, 3, 4], -6}} = result
  end

  # Detects negative cycle
  test "bellman_ford_negative_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 1, with: -5)

    result =
      Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert :negative_cycle = result
  end

  # Negative cycle not reachable from source (should still find path)
  test "bellman_ford_negative_cycle_elsewhere_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      # Negative cycle: 2->3->4->2 (unreachable from 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)
      |> Yog.add_edge(from: 4, to: 2, with: -5)
      # Path from 1 to 5 (doesn't touch the cycle)
      |> Yog.add_edge(from: 1, to: 5, with: 10)

    result =
      Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 5,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    # Cycle is unreachable from source, so path should be found
    assert {:shortest_path, {:path, [1, 5], 10}} = result
  end

  # No path exists
  test "bellman_ford_no_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)

    result =
      Pathfinding.bellman_ford(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &(&1 + &2),
        compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
      )

    assert :no_path = result
  end
end
