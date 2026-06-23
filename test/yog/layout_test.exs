defmodule Yog.LayoutTest do
  use ExUnit.Case, async: true

  alias Yog.Layout

  describe "circular/2" do
    test "returns empty map for empty graph" do
      assert Layout.circular(Yog.undirected()) == %{}
    end

    test "positions a single node at center" do
      graph = Yog.undirected() |> Yog.add_node(1)
      assert Layout.circular(graph, center: {2.0, 3.0}) == %{1 => {2.0, 3.0}}
    end

    test "positions two nodes at opposite ends of radius" do
      graph = Yog.undirected() |> Yog.add_nodes_from([1, 2])
      pos = Layout.circular(graph, radius: 2.0, center: {0.0, 0.0})

      assert Map.keys(pos) |> Enum.sort() == [1, 2]
      {x1, y1} = Map.get(pos, 1)
      {x2, y2} = Map.get(pos, 2)

      # Node 1 at angle 0 -> {2.0, 0.0}
      assert_in_delta x1, 2.0, 1.0e-6
      assert_in_delta y1, 0.0, 1.0e-6

      # Node 2 at angle pi -> {-2.0, 0.0}
      assert_in_delta x2, -2.0, 1.0e-6
      assert_in_delta y2, 0.0, 1.0e-6
    end
  end

  describe "random/2" do
    test "positions nodes inside the specified bounding box" do
      graph = Yog.undirected() |> Yog.add_nodes_from(1..20)
      center = {10.0, -10.0}
      width = 5.0
      height = 8.0

      pos = Layout.random(graph, center: center, width: width, height: height)

      assert map_size(pos) == 20

      Enum.each(pos, fn {_id, {x, y}} ->
        assert x >= 7.5 and x <= 12.5
        assert y >= -14.0 and y <= -6.0
      end)
    end

    test "seed option produces reproducible results" do
      graph = Yog.undirected() |> Yog.add_nodes_from(1..10)

      pos1 = Layout.random(graph, seed: 123)
      pos2 = Layout.random(graph, seed: 123)
      pos3 = Layout.random(graph, seed: 456)

      assert pos1 == pos2
      assert pos1 != pos3
    end
  end

  describe "spring/2" do
    test "handles empty graph" do
      assert Layout.spring(Yog.undirected()) == %{}
    end

    test "handles single node" do
      graph = Yog.undirected() |> Yog.add_node(1)
      assert Layout.spring(graph, center: {5.0, 5.0}) == %{1 => {5.0, 5.0}}
    end

    test "positions a small connected graph" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}, {3, 4}])

      pos = Layout.spring(graph, iterations: 15, seed: 42)

      assert Map.keys(pos) |> Enum.sort() == [1, 2, 3, 4]

      # Check bounds
      Enum.each(pos, fn {_id, {x, y}} ->
        assert x >= -0.5 and x <= 0.5
        assert y >= -0.5 and y <= 0.5
      end)
    end

    test "honors fixed nodes" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}])

      initial_pos = %{1 => {0.0, 0.0}, 2 => {1.0, 1.0}, 3 => {2.0, 2.0}}

      # Node 2 is fixed; it shouldn't move from its initial pos
      pos = Layout.spring(graph, initial_pos: initial_pos, fixed: [2], iterations: 20)

      assert Map.get(pos, 2) == {1.0, 1.0}
    end
  end
end
