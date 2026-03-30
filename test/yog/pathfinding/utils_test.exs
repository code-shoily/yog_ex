defmodule Yog.Pathfinding.UtilsTest do
  use ExUnit.Case
  doctest Yog.Pathfinding.Utils

  alias Yog.Pathfinding.Utils
  alias Yog.Pathfinding.Path

  describe "path/2" do
    test "creates a Path struct with nodes and weight" do
      path = Utils.path([:a, :b, :c], 10)
      assert %Path{nodes: [:a, :b, :c], weight: 10} = path

      path2 = Utils.path([1, 2, 3], 42)
      assert %Path{nodes: [1, 2, 3], weight: 42} = path2

      path3 = Utils.path([], 0)
      assert %Path{nodes: [], weight: 0} = path3
    end

    test "works with any weight type" do
      path1 = Utils.path([:a], 3.14)
      assert %Path{nodes: [:a], weight: 3.14} = path1

      path2 = Utils.path([:a], "weight")
      assert %Path{nodes: [:a], weight: "weight"} = path2
    end
  end

  describe "nodes/1" do
    test "extracts nodes from a path" do
      path = Path.new([:a, :b, :c], 10)
      assert Utils.nodes(path) == [:a, :b, :c]
    end

    test "works with empty nodes" do
      path = Path.new([], 0)
      assert Utils.nodes(path) == []
    end

    test "works with single node" do
      path = Path.new([:start], 5)
      assert Utils.nodes(path) == [:start]
    end
  end

  describe "total_weight/1" do
    test "extracts weight from a path" do
      path = Path.new([:a, :b, :c], 10)
      assert Utils.total_weight(path) == 10
    end

    test "works with zero weight" do
      path = Path.new([:a], 0)
      assert Utils.total_weight(path) == 0
    end

    test "works with different weight types" do
      path1 = Path.new([:a], 3.14)
      assert Utils.total_weight(path1) == 3.14

      path2 = Path.new([:a], -5)
      assert Utils.total_weight(path2) == -5
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
