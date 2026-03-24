defmodule Yog.Functional.AnalysisTest do
  use ExUnit.Case, async: true
  alias Yog.Functional.Model
  alias Yog.Functional.Analysis

  describe "connected_components" do
    test "finds connected components in undirected graph" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.put_node(5, "E")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(3, 4)

      components = Analysis.connected_components(g)
      assert length(components) == 3

      comp_sets = Enum.map(components, &MapSet.new/1)
      assert MapSet.new([1, 2]) in comp_sets
      assert MapSet.new([3, 4]) in comp_sets
      assert MapSet.new([5]) in comp_sets
    end
  end

  describe "analyze_connectivity" do
    test "finds bridges and articulation points" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.put_node(5, "E")
        # Cycle 1-2-3
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)
        # Bridge 3-4
        |> Model.add_edge!(3, 4)
        # Leaf on 4
        |> Model.add_edge!(4, 5)

      result = Analysis.analyze_connectivity(g)

      # Bridges are 3-4 and 4-5
      assert length(result.bridges) == 2

      bridges_set =
        Enum.map(result.bridges, fn {u, v} -> {min(u, v), max(u, v)} end) |> MapSet.new()

      assert MapSet.new([{3, 4}, {4, 5}]) == bridges_set

      # Points: 3 and 4
      assert MapSet.new(result.points) == MapSet.new([3, 4])
    end
  end
end
