defmodule Yog.Pathfinding.PathTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Yog.Pathfinding.Path

  alias Yog.Pathfinding.Path

  describe "new/2" do
    test "creates a basic path" do
      path = Path.new([1, 2, 3], 10)
      assert path.nodes == [1, 2, 3]
      assert path.weight == 10
      assert path.algorithm == :unknown
    end
  end

  describe "hydrate_path/2" do
    test "reconstructs edge data from node path" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 10)

      path = [1, 2]
      assert Path.hydrate_path(graph, path) == [{1, 2, 10}]
    end

    test "handles complex paths" do
      graph =
        Yog.directed()
        |> Yog.add_edge_ensure(1, 2, 1, nil)
        |> Yog.add_edge_ensure(2, 3, 2, nil)
        |> Yog.add_edge_ensure(3, 4, 3, nil)

      path = [1, 2, 3, 4]
      assert Path.hydrate_path(graph, path) == [{1, 2, 1}, {2, 3, 2}, {3, 4, 3}]
    end
  end
end
