defmodule Yog.Builder.GridGraphTest do
  use ExUnit.Case, async: true
  doctest Yog.Builder.GridGraph

  alias Yog.Builder.GridGraph

  test "map serialization (to_map/from_map)" do
    graph = Yog.directed()
    grid = GridGraph.new(graph, 3, 3, :queen)

    map = GridGraph.to_map(grid)
    assert map.rows == 3
    assert map.cols == 3
    # Note: to_map currently only includes graph, rows, cols in implementation

    grid2 = GridGraph.from_map(map)
    assert grid2.rows == 3
    assert grid2.cols == 3
    # Default when not in map
    assert grid2.topology == :rook
  end

  test "get_cell/3 with missing nodes in graph" do
    # Create a grid result where some nodes are missing from the graph
    graph = Yog.directed() |> Yog.add_node(0, "A")
    grid = GridGraph.new(graph, 2, 2)

    assert GridGraph.get_cell(grid, 0, 0) == {:ok, "A"}
    # (0, 1) -> ID 1 is not in graph
    assert GridGraph.get_cell(grid, 0, 1) == {:error, nil}
  end
end
