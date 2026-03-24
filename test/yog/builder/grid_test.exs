defmodule Yog.Builder.GridTest do
  use ExUnit.Case

  alias Yog.Builder.Grid

  doctest Grid

  # Basic grid building tests

  test "from_2d_list_creates_grid_test" do
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result = Grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    # Check dimensions using struct syntax
    assert match?(%Yog.Builder.GridGraph{}, grid_result)
    assert grid_result.rows == 3
    assert grid_result.cols == 3
  end

  test "coord_to_id_conversion_test" do
    # For a 3x3 grid:
    # (0,0)=0  (0,1)=1  (0,2)=2
    # (1,0)=3  (1,1)=4  (1,2)=5
    # (2,0)=6  (2,1)=7  (2,2)=8

    assert Grid.coord_to_id(0, 0, 3) == 0
    assert Grid.coord_to_id(0, 2, 3) == 2
    assert Grid.coord_to_id(1, 1, 3) == 4
    assert Grid.coord_to_id(2, 2, 3) == 8
  end

  test "id_to_coord_conversion_test" do
    assert Grid.id_to_coord(0, 3) == {0, 0}
    assert Grid.id_to_coord(2, 3) == {0, 2}
    assert Grid.id_to_coord(4, 3) == {1, 1}
    assert Grid.id_to_coord(8, 3) == {2, 2}
  end

  test "get_cell_retrieves_correct_data_test" do
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result = Grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    # Get center cell
    assert Grid.get_cell(grid_result, 1, 1) == {:ok, 5}

    # Get corner cells
    assert Grid.get_cell(grid_result, 0, 0) == {:ok, 1}
    assert Grid.get_cell(grid_result, 2, 2) == {:ok, 9}

    # Out of bounds
    assert Grid.get_cell(grid_result, 3, 3) == {:error, nil}
    assert Grid.get_cell(grid_result, -1, 0) == {:error, nil}
  end

  # Movement constraint tests

  test "can_move_constraint_applied_test" do
    grid_data = [[1, 2, 5], [2, 3, 6], [3, 4, 7]]

    # Can only move if height difference is at most 1
    grid_result =
      Grid.from_2d_list(grid_data, :directed, fn from, to ->
        to - from <= 1
      end)

    graph = Grid.to_graph(grid_result)

    # From (0,0)=1, can move to (0,1)=2 (diff=1) and (1,0)=2 (diff=1)
    successors = Yog.successors(graph, Grid.coord_to_id(0, 0, 3))
    assert successors == [{1, 1}, {3, 1}]
  end

  test "undirected_grid_test" do
    grid_data = [[1, 2], [3, 4]]

    grid_result = Grid.from_2d_list(grid_data, :undirected, fn _, _ -> true end)

    graph = Grid.to_graph(grid_result)

    # In undirected graph, edges go both ways
    top_left = Grid.coord_to_id(0, 0, 2)
    top_right = Grid.coord_to_id(0, 1, 2)

    # From top-left, should be able to reach top-right
    left_successors = Yog.successors(graph, top_left)

    assert Enum.any?(left_successors, fn {node_id, _} -> node_id == top_right end)

    # From top-right, should be able to reach top-left
    right_successors = Yog.successors(graph, top_right)

    assert Enum.any?(right_successors, fn {node_id, _} -> node_id == top_left end)
  end

  # Manhattan distance tests

  test "manhattan_distance_test" do
    # Distance from (0,0) to (3,4) in a grid with 10 columns
    from = Grid.coord_to_id(0, 0, 10)
    to = Grid.coord_to_id(3, 4, 10)

    assert Grid.manhattan_distance(from, to, 10) == 7

    # Distance from (2,3) to (2,7)
    from2 = Grid.coord_to_id(2, 3, 10)
    to2 = Grid.coord_to_id(2, 7, 10)

    assert Grid.manhattan_distance(from2, to2, 10) == 4

    # Distance from (5,5) to (5,5) should be 0
    same = Grid.coord_to_id(5, 5, 10)

    assert Grid.manhattan_distance(same, same, 10) == 0
  end

  # Find node tests

  test "find_node_test" do
    grid_data = [["S", ".", "."], [".", "#", "."], [".", ".", "E"]]

    grid_result = Grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    # Find start node
    start = Grid.find_node(grid_result, fn cell -> cell == "S" end)
    assert start == {:ok, 0}

    # Find end node
    end_node = Grid.find_node(grid_result, fn cell -> cell == "E" end)
    assert end_node == {:ok, 8}

    # Find wall
    wall = Grid.find_node(grid_result, fn cell -> cell == "#" end)
    assert wall == {:ok, 4}

    # Find non-existent
    not_found = Grid.find_node(grid_result, fn cell -> cell == "X" end)
    assert not_found == {:error, nil}
  end

  # Integration test: pathfinding on grid

  test "pathfinding_on_grid_test" do
    # Simple 3x3 grid where all moves are valid
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result = Grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    graph = Grid.to_graph(grid_result)

    # Find path from top-left (0,0) to bottom-right (2,2) using BFS
    start = Grid.coord_to_id(0, 0, 3)
    goal = Grid.coord_to_id(2, 2, 3)

    path =
      Yog.Traversal.walk_until(
        in: graph,
        from: start,
        using: :breadth_first,
        until: fn node -> node == goal end
      )

    # Path should exist
    refute Enum.empty?(path)

    # Path should end at goal
    assert List.last(path) == goal
  end

  # AoC-style test: heightmap with climbing constraint

  test "heightmap_climbing_test" do
    # Simplified AoC 2022 Day 12 style test
    # 'a' = 1, 'b' = 2, 'c' = 3, etc.
    grid_data = [[1, 2, 3], [2, 3, 4], [3, 4, 5]]

    # Can only climb 1 unit at a time, but descend any amount
    grid_result =
      Grid.from_2d_list(grid_data, :directed, fn from, to ->
        to - from <= 1
      end)

    graph = Grid.to_graph(grid_result)

    # From (0,0)=1, should be able to move to adjacent cells with height 2
    start = Grid.coord_to_id(0, 0, 3)
    successors = Yog.successors(graph, start)

    # Should have 2 successors: (0,1)=2 and (1,0)=2
    assert length(successors) == 2

    # From (1,1)=3, can move to cells with height up to 4
    middle = Grid.coord_to_id(1, 1, 3)
    middle_successors = Yog.successors(graph, middle)

    # Can go to all 4 directions (including descent)
    assert length(middle_successors) == 4
  end

  # ============= New Topologies and Predicates =============

  test "from_2d_list_with_topology_test" do
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    # Using queen topology (8 directions) and always predicate
    grid_result =
      Grid.from_2d_list_with_topology(
        grid_data,
        :directed,
        Grid.queen(),
        Grid.always()
      )

    graph = Grid.to_graph(grid_result)

    # Center node (4) should have 8 neighbors
    center = Grid.coord_to_id(1, 1, 3)
    successors = Yog.successors(graph, center)
    assert length(successors) == 8
  end

  test "bishop_topology_test" do
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result =
      Grid.from_2d_list_with_topology(grid_data, :directed, Grid.bishop(), Grid.always())

    graph = Grid.to_graph(grid_result)

    # Center node (1,1) -> neighbors (0,0), (0,2), (2,0), (2,2)
    center = Grid.coord_to_id(1, 1, 3)
    successors = Yog.successors(graph, center)
    assert length(successors) == 4
  end

  test "rook_topology_test" do
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result =
      Grid.from_2d_list_with_topology(grid_data, :directed, Grid.rook(), Grid.always())

    graph = Grid.to_graph(grid_result)

    # Center node (1,1) -> neighbors (0,1), (1,0), (1,2), (2,1)
    center = Grid.coord_to_id(1, 1, 3)
    successors = Yog.successors(graph, center)
    assert length(successors) == 4
  end

  test "knight_topology_test" do
    grid_data = [
      [1, 2, 3, 4, 5],
      [6, 7, 8, 9, 10],
      [11, 12, 13, 14, 15],
      [16, 17, 18, 19, 20],
      [21, 22, 23, 24, 25]
    ]

    grid_result =
      Grid.from_2d_list_with_topology(grid_data, :directed, Grid.knight(), Grid.always())

    graph = Grid.to_graph(grid_result)

    # Center node (2,2) -> 8 knight jumps
    center = Grid.coord_to_id(2, 2, 5)
    successors = Yog.successors(graph, center)
    assert length(successors) == 8
  end

  test "avoiding_predicate_test" do
    grid_data = [[1, 2, 1], [1, 2, 1], [1, 1, 1]]
    # Cannot move into a cell with value 2
    grid_result =
      Grid.from_2d_list_with_topology(
        grid_data,
        :directed,
        Grid.rook(),
        Grid.avoiding(2)
      )

    graph = Grid.to_graph(grid_result)

    # From (0,0), can move to (1,0) but not (0,1)
    start = Grid.coord_to_id(0, 0, 3)

    successors =
      Yog.successors(graph, start) |> Enum.map(fn {id, _weight} -> Grid.id_to_coord(id, 3) end)

    assert {1, 0} in successors
    refute {0, 1} in successors
  end

  test "walkable_predicate_test" do
    grid_data = [["A", ".", "A"], ["A", ".", "A"], ["A", "A", "A"]]
    # Can only move into a cell with value "."
    grid_result =
      Grid.from_2d_list_with_topology(
        grid_data,
        :directed,
        Grid.rook(),
        Grid.walkable(".")
      )

    graph = Grid.to_graph(grid_result)

    # From (0,1) = ".", successors are (1,1) only, not (0,0) or (0,2) or (1,1).
    start = Grid.coord_to_id(0, 1, 3)

    successors =
      Yog.successors(graph, start) |> Enum.map(fn {id, _weight} -> Grid.id_to_coord(id, 3) end)

    assert {1, 1} in successors
    refute {0, 0} in successors
    refute {0, 2} in successors
  end
end
