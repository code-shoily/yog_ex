defmodule YogBuilderGridTest do
  use ExUnit.Case

  alias Yog.Builder.Grid

  # Basic grid building tests

  test "from_2d_list_creates_grid_test" do
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result = :yog@builder@grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    # Check dimensions using Gleam record syntax
    {:grid, _, rows, cols} = grid_result

    assert rows == 3
    assert cols == 3
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

    grid_result = :yog@builder@grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    # Get center cell
    assert :yog@builder@grid.get_cell(grid_result, 1, 1) == {:ok, 5}

    # Get corner cells
    assert :yog@builder@grid.get_cell(grid_result, 0, 0) == {:ok, 1}
    assert :yog@builder@grid.get_cell(grid_result, 2, 2) == {:ok, 9}

    # Out of bounds
    assert :yog@builder@grid.get_cell(grid_result, 3, 3) == {:error, nil}
    assert :yog@builder@grid.get_cell(grid_result, -1, 0) == {:error, nil}
  end

  # Movement constraint tests

  test "can_move_constraint_applied_test" do
    grid_data = [[1, 2, 5], [2, 3, 6], [3, 4, 7]]

    # Can only move if height difference is at most 1
    grid_result =
      :yog@builder@grid.from_2d_list(grid_data, :directed, fn from, to ->
        to - from <= 1
      end)

    graph = Grid.to_graph(grid_result)

    # From (0,0)=1, can move to (0,1)=2 (diff=1) and (1,0)=2 (diff=1)
    successors = Yog.successors(graph, Grid.coord_to_id(0, 0, 3))
    assert successors == [{1, 1}, {3, 1}]
  end

  test "undirected_grid_test" do
    grid_data = [[1, 2], [3, 4]]

    grid_result = :yog@builder@grid.from_2d_list(grid_data, :undirected, fn _, _ -> true end)

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

    grid_result = :yog@builder@grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

    # Find start node
    start = :yog@builder@grid.find_node(grid_result, fn cell -> cell == "S" end)
    assert start == {:ok, 0}

    # Find end node
    end_node = :yog@builder@grid.find_node(grid_result, fn cell -> cell == "E" end)
    assert end_node == {:ok, 8}

    # Find wall
    wall = :yog@builder@grid.find_node(grid_result, fn cell -> cell == "#" end)
    assert wall == {:ok, 4}

    # Find non-existent
    not_found = :yog@builder@grid.find_node(grid_result, fn cell -> cell == "X" end)
    assert not_found == {:error, nil}
  end

  # Integration test: pathfinding on grid

  test "pathfinding_on_grid_test" do
    # Simple 3x3 grid where all moves are valid
    grid_data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid_result = :yog@builder@grid.from_2d_list(grid_data, :directed, fn _, _ -> true end)

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
      :yog@builder@grid.from_2d_list(grid_data, :directed, fn from, to ->
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
end
