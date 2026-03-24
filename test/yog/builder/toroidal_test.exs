defmodule Yog.Builder.ToroidalTest do
  use ExUnit.Case
  alias Yog.Builder.Toroidal

  doctest Toroidal

  test "toroidal_from_2d_list_test" do
    data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    grid = Toroidal.from_2d_list(data, :directed, Toroidal.always())
    assert match?(%Yog.Builder.GridGraph{}, grid)

    graph = Toroidal.to_graph(grid)
    assert length(Yog.all_nodes(graph)) == 9
  end

  test "toroidal_from_2d_list_with_topology_test" do
    data = [[1, 2], [3, 4]]

    grid =
      Toroidal.from_2d_list_with_topology(
        data,
        :directed,
        Toroidal.queen(),
        Toroidal.always()
      )

    assert match?(%Yog.Builder.GridGraph{}, grid)

    graph = Toroidal.to_graph(grid)
    assert length(Yog.all_nodes(graph)) == 4
  end

  test "toroidal_get_cell_test" do
    data = [["A", "B"], ["C", "D"]]
    grid = Toroidal.from_2d_list(data, :undirected, Toroidal.always())

    assert {:ok, "A"} = Toroidal.get_cell(grid, 0, 0)
    assert {:ok, "D"} = Toroidal.get_cell(grid, 1, 1)
  end

  test "toroidal_find_node_test" do
    data = [[".", "S"], [".", "."]]
    grid = Toroidal.from_2d_list(data, :undirected, Toroidal.always())

    assert {:ok, node_id} = Toroidal.find_node(grid, fn cell -> cell == "S" end)
    assert is_integer(node_id)
  end

  test "toroidal_coord_conversion_test" do
    # 3 columns: coord_to_id(2, 1, 3) = 2 * 3 + 1 = 7
    assert Toroidal.coord_to_id(2, 1, 3) == 7

    # id_to_coord(7, 3) = {2, 1}
    assert Toroidal.id_to_coord(7, 3) == {2, 1}
  end

  test "toroidal_manhattan_distance_wrapping_test" do
    # On a 3x3 grid, distance from (0,0) to (2,2)
    # Direct: |2-0| + |2-0| = 4
    # Wrapping: min(2, 3-2) + min(2, 3-2) = 1 + 1 = 2
    from_id = Toroidal.coord_to_id(0, 0, 3)
    to_id = Toroidal.coord_to_id(2, 2, 3)

    dist = Toroidal.toroidal_manhattan_distance(from_id, to_id, 3, 3)
    assert dist == 2
  end

  test "toroidal_chebyshev_distance_wrapping_test" do
    from_id = Toroidal.coord_to_id(0, 0, 3)
    to_id = Toroidal.coord_to_id(2, 2, 3)

    dist = Toroidal.toroidal_chebyshev_distance(from_id, to_id, 3, 3)
    # Chebyshev = max(dx_wrapped, dy_wrapped) = max(1, 1) = 1
    assert dist == 1
  end

  test "toroidal_octile_distance_test" do
    from_id = Toroidal.coord_to_id(0, 0, 3)
    to_id = Toroidal.coord_to_id(2, 2, 3)

    dist = Toroidal.toroidal_octile_distance(from_id, to_id, 3, 3)
    assert is_float(dist)
  end

  test "toroidal_topology_presets_test" do
    rook = Toroidal.rook()
    assert is_list(rook)
    assert length(rook) == 4

    bishop = Toroidal.bishop()
    assert is_list(bishop)
    assert length(bishop) == 4

    queen = Toroidal.queen()
    assert is_list(queen)
    assert length(queen) == 8

    knight = Toroidal.knight()
    assert is_list(knight)
    assert length(knight) == 8
  end

  test "toroidal_movement_predicates_test" do
    always_fn = Toroidal.always()
    assert always_fn.("any", "thing")

    walkable_fn = Toroidal.walkable(".")
    assert walkable_fn.(".", ".")
    refute walkable_fn.(".", "#")

    avoiding_fn = Toroidal.avoiding("#")
    assert avoiding_fn.(".", ".")
    refute avoiding_fn.(".", "#")

    including_fn = Toroidal.including([".", "S"])
    assert including_fn.(".", "S")
    refute including_fn.(".", "#")
  end

  test "toroidal_wrapping_edges_exist_test" do
    # On a 3x3 toroidal grid, node at (0,0) should connect to (0,2) via wrapping
    data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    grid = Toroidal.from_2d_list(data, :directed, Toroidal.always())
    graph = Toroidal.to_graph(grid)

    # (0,0) = id 0 — wrapping left from col 0 goes to col 2
    neighbors = Yog.neighbors(graph, 0)
    # Should have 4 neighbors (up-wrap, down, left-wrap, right)
    assert length(neighbors) == 4
  end
end
