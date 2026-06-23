defmodule Yog.LayoutTest do
  use ExUnit.Case, async: true

  doctest Yog.Layout

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

    test "handles overlapping nodes with repulsion and attraction" do
      # 1 and 2 start at exact same spot. Repulsion should push them apart.
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])
      initial_pos = %{1 => {0.0, 0.0}, 2 => {0.0, 0.0}}
      pos = Layout.spring(graph, initial_pos: initial_pos, iterations: 2, fixed: [1])

      # Node 1 is fixed at 0,0, but Node 2 should have been pushed away by repulsion
      assert Map.get(pos, 1) == {0.0, 0.0}
      assert Map.get(pos, 2) != {0.0, 0.0}
    end

    test "ignores edges containing missing nodes in initial_pos" do
      # Edge between 1 and 2, but node 2 is missing from initial_pos
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])
      initial_pos = %{1 => {0.0, 0.0}}
      pos = Layout.spring(graph, initial_pos: initial_pos, iterations: 2)
      assert Map.keys(pos) == [1]
    end

    test "rescales nodes at identical positions to center" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])
      initial_pos = %{1 => {1.0, 1.0}, 2 => {1.0, 1.0}}
      # 0 iterations so they remain at {1.0, 1.0}, center is {5.0, 5.0}
      pos = Layout.spring(graph, initial_pos: initial_pos, iterations: 0, center: {5.0, 5.0})
      assert pos == %{1 => {5.0, 5.0}, 2 => {5.0, 5.0}}
    end

    test "works when weight option is disabled or weights are non-numeric" do
      graph = Yog.from_edges(:undirected, [{1, 2, "heavy"}])

      # Should run fine even with string weights
      pos1 = Layout.spring(graph, weight: true, iterations: 5)
      assert Map.keys(pos1) |> Enum.sort() == [1, 2]

      # Should run fine with weight: false
      pos2 = Layout.spring(graph, weight: false, iterations: 5)
      assert Map.keys(pos2) |> Enum.sort() == [1, 2]
    end
  end

  describe "tutte/3" do
    test "positions interior node at the center of a symmetric boundary" do
      # Boundary nodes: 1, 2, 3. Interior node: 4 connected to 1, 2, 3.
      graph =
        Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}, {3, 1}, {1, 4}, {2, 4}, {3, 4}])

      pos = Layout.tutte(graph, [1, 2, 3], iterations: 50, center: {0.0, 0.0}, radius: 2.0)

      assert Map.keys(pos) |> Enum.sort() == [1, 2, 3, 4]

      # Boundary nodes are on a circle of radius 2.0
      for id <- [1, 2, 3] do
        {x, y} = Map.get(pos, id)
        assert_in_delta :math.sqrt(x * x + y * y), 2.0, 1.0e-6
      end

      # Interior node 4 is at center of symmetric boundary
      {x4, y4} = Map.get(pos, 4)
      assert_in_delta x4, 0.0, 1.0e-6
      assert_in_delta y4, 0.0, 1.0e-6
    end

    test "raises error for invalid boundary nodes count or missing nodes" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}, {3, 1}])

      assert_raise ArgumentError, ~r/at least 3 boundary nodes/, fn ->
        Layout.tutte(graph, [1, 2])
      end

      assert_raise ArgumentError, ~r/must exist within the graph/, fn ->
        Layout.tutte(graph, [1, 2, 99])
      end
    end

    test "handles isolated interior nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_nodes_from([1, 2, 3, 4])
        |> Yog.add_edges!([{1, 2, nil}, {2, 3, nil}, {3, 1, nil}])

      pos = Layout.tutte(graph, [1, 2, 3], iterations: 10, center: {0.0, 0.0})
      # Node 4 has no neighbors, so it should stay at the center
      assert Map.get(pos, 4) == {0.0, 0.0}
    end
  end

  describe "shell/3" do
    test "arranges nodes in concentric circles based on shells grouping" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}, {3, 4}])

      pos = Layout.shell(graph, [[1, 2], [3, 4]], center: {0.0, 0.0})

      assert Map.keys(pos) |> Enum.sort() == [1, 2, 3, 4]

      # Shell 1 has nodes 1 and 2 at radius 0.5
      for id <- [1, 2] do
        {x, y} = Map.get(pos, id)
        assert_in_delta :math.sqrt(x * x + y * y), 0.5, 1.0e-6
      end

      # Shell 2 has nodes 3 and 4 at radius 1.0
      for id <- [3, 4] do
        {x, y} = Map.get(pos, id)
        assert_in_delta :math.sqrt(x * x + y * y), 1.0, 1.0e-6
      end
    end

    test "raises errors for empty shells, mismatched radii, or missing nodes" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}])

      assert_raise ArgumentError, ~r/must not contain empty lists/, fn ->
        Layout.shell(graph, [[1, 2], []])
      end

      assert_raise ArgumentError, ~r/must exist in the graph/, fn ->
        Layout.shell(graph, [[1, 2], [99]])
      end

      assert_raise ArgumentError, ~r/radii list must match the number of shells/, fn ->
        Layout.shell(graph, [[1], [2], [3]], radii: [1.0, 2.0])
      end
    end

    test "handles empty shells list and single node shell" do
      graph = Yog.undirected() |> Yog.add_node(1)
      assert Layout.shell(graph, []) == %{}
      assert Layout.shell(graph, [[1]], center: {3.0, 3.0}) == %{1 => {3.0, 3.0}}
    end

    test "supports custom radii list" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {3, 4}])
      pos = Layout.shell(graph, [[1, 2], [3, 4]], radii: [0.2, 0.9], center: {0.0, 0.0})
      {x1, y1} = Map.get(pos, 1)
      {x3, y3} = Map.get(pos, 3)
      assert_in_delta :math.sqrt(x1 * x1 + y1 * y1), 0.2, 1.0e-6
      assert_in_delta :math.sqrt(x3 * x3 + y3 * y3), 0.9, 1.0e-6
    end
  end

  describe "multipartite/3" do
    test "arranges layers in vertical columns" do
      # 2 layers: layer 0 contains [1], layer 1 contains [2, 3]
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {1, 3}])

      pos =
        Layout.multipartite(graph, [[1], [2, 3]],
          align: :vertical,
          width: 2.0,
          height: 4.0,
          center: {0.0, 0.0}
        )

      # Column 0: x = -1.0. Column 1: x = 1.0.
      # Single node in layer 0 positioned at cy
      assert Map.get(pos, 1) == {-1.0, 0.0}
      # Node 2 is first in layer 1 -> cy - height/2
      assert Map.get(pos, 2) == {1.0, -2.0}
      # Node 3 is second in layer 1 -> cy + height/2
      assert Map.get(pos, 3) == {1.0, 2.0}
    end

    test "arranges layers in horizontal rows" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {1, 3}])

      pos =
        Layout.multipartite(graph, [[1], [2, 3]],
          align: :horizontal,
          width: 2.0,
          height: 4.0,
          center: {0.0, 0.0}
        )

      # Row 0: y = -2.0. Row 1: y = 2.0.
      assert Map.get(pos, 1) == {0.0, -2.0}
      assert Map.get(pos, 2) == {-1.0, 2.0}
      assert Map.get(pos, 3) == {1.0, 2.0}
    end

    test "raises errors for empty layers, invalid align, or missing nodes" do
      graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])

      assert_raise ArgumentError, ~r/must be either :vertical or :horizontal/, fn ->
        Layout.multipartite(graph, [[1], [2]], align: :diagonal)
      end

      assert_raise ArgumentError, ~r/must not contain empty lists/, fn ->
        Layout.multipartite(graph, [[1], []])
      end

      assert_raise ArgumentError, ~r/must exist in the graph/, fn ->
        Layout.multipartite(graph, [[1], [99]])
      end
    end

    test "handles empty layers" do
      graph = Yog.undirected()
      assert Layout.multipartite(graph, []) == %{}
    end
  end
end
