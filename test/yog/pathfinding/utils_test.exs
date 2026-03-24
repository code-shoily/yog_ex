defmodule Yog.Pathfinding.UtilsTest do
  use ExUnit.Case
  doctest Yog.Pathfinding.Utils

  alias Yog.Pathfinding.Utils

  describe "path/2" do
    test "creates a path tuple with nodes and weight" do
      assert Utils.path([:a, :b, :c], 10) == {:path, [:a, :b, :c], 10}
      assert Utils.path([1, 2, 3], 42) == {:path, [1, 2, 3], 42}
      assert Utils.path([], 0) == {:path, [], 0}
    end

    test "works with any weight type" do
      assert Utils.path([:a], 3.14) == {:path, [:a], 3.14}
      assert Utils.path([:a], "weight") == {:path, [:a], "weight"}
    end
  end

  describe "nodes/1" do
    test "extracts nodes from a path" do
      path = {:path, [:a, :b, :c], 10}
      assert Utils.nodes(path) == [:a, :b, :c]
    end

    test "works with empty nodes" do
      path = {:path, [], 0}
      assert Utils.nodes(path) == []
    end

    test "works with single node" do
      path = {:path, [:start], 5}
      assert Utils.nodes(path) == [:start]
    end
  end

  describe "total_weight/1" do
    test "extracts weight from a path" do
      path = {:path, [:a, :b, :c], 10}
      assert Utils.total_weight(path) == 10
    end

    test "works with zero weight" do
      path = {:path, [:a], 0}
      assert Utils.total_weight(path) == 0
    end

    test "works with different weight types" do
      assert Utils.total_weight({:path, [:a], 3.14}) == 3.14
      assert Utils.total_weight({:path, [:a], -5}) == -5
    end
  end

  describe "path roundtrip" do
    test "creating and extracting path data" do
      nodes = [:start, :middle, :end]
      weight = 100

      path = Utils.path(nodes, weight)
      assert Utils.nodes(path) == nodes
      assert Utils.total_weight(path) == weight
    end
  end
end
