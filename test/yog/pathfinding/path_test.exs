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
        |> Yog.add_edge_ensure(1, 2, 10)

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

  describe "path helper utilities" do
    test "empty?" do
      p1 = Path.new([], 0)
      p2 = Path.new([1], 0)
      assert Path.empty?(p1)
      refute Path.empty?(p2)
    end

    test "length" do
      assert Path.length(Path.new([], 0)) == 0
      assert Path.length(Path.new([1], 0)) == 0
      assert Path.length(Path.new([1, 2, 3], 10)) == 2
    end

    test "start and finish" do
      assert Path.start(Path.new([], 0)) == nil
      assert Path.finish(Path.new([], 0)) == nil
      p = Path.new([1, 2, 3], 10)
      assert Path.start(p) == 1
      assert Path.finish(p) == 3
    end

    test "reverse" do
      p = Path.new([1, 2, 3], 10, :dijkstra, %{visited: 5})
      rev = Path.reverse(p)
      assert rev.nodes == [3, 2, 1]
      assert rev.weight == 10
      assert rev.algorithm == :dijkstra
      assert rev.metadata == %{visited: 5}
    end

    test "contains?" do
      p = Path.new([1, 2, 3], 10)
      assert Path.contains?(p, 2)
      refute Path.contains?(p, 4)
    end

    test "at" do
      p = Path.new([1, 2, 3], 10)
      assert Path.at(p, 0) == 1
      assert Path.at(p, 2) == 3
      assert Path.at(p, 3) == nil
    end
  end
end
