defmodule Yog.Layout.GeometryTest do
  use ExUnit.Case, async: true

  doctest Yog.Layout.Geometry

  alias Yog.Layout.Geometry

  describe "rects/2" do
    test "converts center positions to bounding rects with uniform size" do
      positions = %{a: {10.0, 20.0}, b: {0.0, 0.0}}
      result = Geometry.rects(positions, size: {4.0, 2.0})
      assert result == %{a: {8.0, 19.0, 4.0, 2.0}, b: {-2.0, -1.0, 4.0, 2.0}}
    end

    test "uses default size {1.0, 1.0} when no size option given" do
      positions = %{a: {5.0, 5.0}}
      result = Geometry.rects(positions)
      assert result == %{a: {4.5, 4.5, 1.0, 1.0}}
    end

    test "accepts per-node function for size" do
      positions = %{a: {10.0, 10.0}, b: {20.0, 20.0}}

      size_fn = fn
        :a, _pos -> {2.0, 2.0}
        :b, _pos -> {4.0, 6.0}
      end

      result = Geometry.rects(positions, size: size_fn)
      assert result == %{a: {9.0, 9.0, 2.0, 2.0}, b: {18.0, 17.0, 4.0, 6.0}}
    end

    test "returns empty map for empty positions" do
      assert Geometry.rects(%{}) == %{}
    end
  end

  describe "anchor/2" do
    # rect: x=10, y=20, w=4, h=2 => right edge=14, bottom=22, center=(12,21)
    setup do
      %{rect: {10.0, 20.0, 4.0, 2.0}}
    end

    test "top returns top-center", %{rect: rect} do
      assert Geometry.anchor(rect, :top) == {12.0, 20.0}
    end

    test "bottom returns bottom-center", %{rect: rect} do
      assert Geometry.anchor(rect, :bottom) == {12.0, 22.0}
    end

    test "left returns left-center", %{rect: rect} do
      assert Geometry.anchor(rect, :left) == {10.0, 21.0}
    end

    test "right returns right-center", %{rect: rect} do
      assert Geometry.anchor(rect, :right) == {14.0, 21.0}
    end

    test "top_left returns top-left corner", %{rect: rect} do
      assert Geometry.anchor(rect, :top_left) == {10.0, 20.0}
    end

    test "top_right returns top-right corner", %{rect: rect} do
      assert Geometry.anchor(rect, :top_right) == {14.0, 20.0}
    end

    test "bottom_left returns bottom-left corner", %{rect: rect} do
      assert Geometry.anchor(rect, :bottom_left) == {10.0, 22.0}
    end

    test "bottom_right returns bottom-right corner", %{rect: rect} do
      assert Geometry.anchor(rect, :bottom_right) == {14.0, 22.0}
    end

    test "center returns center point", %{rect: rect} do
      assert Geometry.anchor(rect, :center) == {12.0, 21.0}
    end
  end

  describe "edge_endpoints/3" do
    test "without node_size returns center-to-center" do
      positions = %{a: {0.0, 0.0}, b: {10.0, 5.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}])
      assert result == [{{0.0, 0.0}, {10.0, 5.0}}]
    end

    test "horizontal edge clips to left/right sides" do
      positions = %{a: {0.0, 0.0}, b: {10.0, 0.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}], node_size: {2.0, 2.0})
      assert result == [{{1.0, 0.0}, {9.0, 0.0}}]
    end

    test "horizontal edge going left clips reversed sides" do
      positions = %{a: {10.0, 0.0}, b: {0.0, 0.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}], node_size: {2.0, 2.0})
      # a is to the right of b, so a uses :left and b uses :right
      assert result == [{{9.0, 0.0}, {1.0, 0.0}}]
    end

    test "vertical edge clips to top/bottom sides" do
      positions = %{a: {0.0, 0.0}, b: {0.0, 10.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}], node_size: {2.0, 2.0})
      # dy > 0 so a uses :bottom, b uses :top
      assert result == [{{0.0, 1.0}, {0.0, 9.0}}]
    end

    test "diagonal edge where |dx| > |dy| uses horizontal clipping" do
      positions = %{a: {0.0, 0.0}, b: {10.0, 3.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}], node_size: {2.0, 2.0})
      [{from_pt, to_pt}] = result
      {fx, fy} = from_pt
      {tx, ty} = to_pt
      assert is_float(fx) and is_float(fy) and is_float(tx) and is_float(ty)
      # horizontal dominance: from uses :right (x=1, y=0), to uses :left (x=9, y=3)
      assert from_pt == {1.0, 0.0}
      assert to_pt == {9.0, 3.0}
    end

    test "diagonal edge where |dy| > |dx| uses vertical clipping" do
      positions = %{a: {0.0, 0.0}, b: {3.0, 10.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}], node_size: {2.0, 2.0})
      [{from_pt, to_pt}] = result
      # vertical dominance: from uses :bottom (x=0, y=1), to uses :top (x=3, y=9)
      assert from_pt == {0.0, 1.0}
      assert to_pt == {3.0, 9.0}
    end

    test "overlapping nodes (same position) returns centers gracefully" do
      positions = %{a: {5.0, 5.0}, b: {5.0, 5.0}}
      result = Geometry.edge_endpoints(positions, [{:a, :b}], node_size: {2.0, 2.0})
      [{from_pt, to_pt}] = result
      # Both centers are (5, 5), anchors at :center => (5, 5)
      assert from_pt == {5.0, 5.0}
      assert to_pt == {5.0, 5.0}
    end

    test "multiple edges are processed in order" do
      positions = %{a: {0.0, 0.0}, b: {10.0, 0.0}, c: {0.0, 10.0}}
      edges = [{:a, :b}, {:a, :c}]
      result = Geometry.edge_endpoints(positions, edges, node_size: {2.0, 2.0})
      assert length(result) == 2
      [ab, ac] = result
      assert ab == {{1.0, 0.0}, {9.0, 0.0}}
      assert ac == {{0.0, 1.0}, {0.0, 9.0}}
    end
  end
end
