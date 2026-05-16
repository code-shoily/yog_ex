defmodule Yog.Builder.ToroidalGraphTest do
  use ExUnit.Case
  alias Yog.Builder.ToroidalGraph
  alias Yog.Builder.GridGraph

  test "new/4 creates toroidal graph result" do
    graph = Yog.directed()
    toroidal = ToroidalGraph.new(graph, 3, 3, :queen)
    assert toroidal.rows == 3
    assert toroidal.cols == 3
    assert toroidal.topology == :queen
  end

  test "to_grid_graph/1 converts to GridGraph" do
    graph = Yog.directed()
    toroidal = ToroidalGraph.new(graph, 3, 3, :rook)
    grid = ToroidalGraph.to_grid_graph(toroidal)

    assert match?(%GridGraph{}, grid)
    assert grid.graph == graph
    assert grid.rows == 3
    assert grid.cols == 3
  end

  test "to_graph/1 unwraps to graph" do
    graph = Yog.directed()
    toroidal = ToroidalGraph.new(graph, 3, 3)
    assert ToroidalGraph.to_graph(toroidal) == graph
  end

  test "coordinate conversions" do
    graph = Yog.directed()
    toroidal = ToroidalGraph.new(graph, 3, 4)

    # 3 rows, 4 cols
    # (1, 2) -> 1 * 4 + 2 = 6
    assert ToroidalGraph.coord_to_id(toroidal, 1, 2) == 6
    assert ToroidalGraph.id_to_coord(toroidal, 6) == {1, 2}
  end
end
