defmodule Yog.Functional.AnalysisTest do
  use ExUnit.Case, async: true
  alias Yog.Functional.Model
  alias Yog.Functional.Analysis
  doctest Yog.Functional.Analysis

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

    test "empty graph has no connected components" do
      assert Analysis.connected_components(Model.new(:undirected)) == []
    end

    test "single-node graph has one singleton component" do
      graph = Model.new(:undirected) |> Model.put_node(1, "A")
      assert Analysis.connected_components(graph) == [[1]]
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

    test "empty graph has no bridges or articulation points" do
      assert Analysis.analyze_connectivity(Model.new(:undirected)) == %{bridges: [], points: []}
    end

    test "pure cycle has no bridges or articulation points" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)

      result = Analysis.analyze_connectivity(g)

      assert result.bridges == []
      assert result.points == []
    end

    test "handles disconnected graph with independent bridges" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(3, 4)

      result = Analysis.analyze_connectivity(g)
      bridges = Enum.map(result.bridges, fn {u, v} -> {min(u, v), max(u, v)} end) |> MapSet.new()

      assert bridges == MapSet.new([{1, 2}, {3, 4}])
      assert result.points == []
    end
  end

  describe "transitive_closure" do
    test "computes full reachability" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)

      tc = Analysis.transitive_closure(g)
      assert Enum.sort(tc[1]) == [1, 2, 3]
      assert Enum.sort(tc[2]) == [2, 3]
      assert Enum.sort(tc[3]) == [3]
    end

    test "empty graph closure is empty" do
      assert Analysis.transitive_closure(Model.empty()) == %{}
    end

    test "cycle reaches every node in the strongly connected component" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)

      tc = Analysis.transitive_closure(g)

      assert Enum.sort(tc[1]) == [1, 2, 3]
      assert Enum.sort(tc[2]) == [1, 2, 3]
      assert Enum.sort(tc[3]) == [1, 2, 3]
    end
  end

  describe "biconnected_components" do
    test "finds biconnected components" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "1")
        |> Model.put_node(2, "2")
        |> Model.put_node(3, "3")
        |> Model.put_node(4, "4")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)
        |> Model.add_edge!(3, 4)

      bccs = Analysis.biconnected_components(g)
      # Cycle 1-2-3 and edge 3-4
      assert length(bccs) == 2
    end
  end

  describe "analyze_connectivity root articulation" do
    test "root with multiple children is articulation point" do
      # Star graph: root 1 connects to 2, 3, 4. No other edges.
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "root")
        |> Model.put_node(2, "A")
        |> Model.put_node(3, "B")
        |> Model.put_node(4, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(1, 3)
        |> Model.add_edge!(1, 4)

      result = Analysis.analyze_connectivity(g)
      # Root 1 is an articulation point (removing it disconnects 2,3,4)
      assert 1 in result.points
      # All edges are bridges in a tree
      assert length(result.bridges) == 3
    end
  end

  describe "connected_components edge cases" do
    test "triangle graph component extraction" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)

      components = Analysis.connected_components(g)
      assert length(components) == 1
      assert Enum.sort(hd(components)) == [1, 2, 3]
    end
  end

  describe "biconnected_components edge cases" do
    test "single edge graph" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      bccs = Analysis.biconnected_components(g)
      assert length(bccs) == 1
      assert hd(bccs) == [{1, 2}]
    end

    test "single node graph" do
      g = Model.new(:undirected) |> Model.put_node(1, "A")
      assert Analysis.biconnected_components(g) == []
    end

    test "empty graph" do
      assert Analysis.biconnected_components(Model.new(:undirected)) == []
    end

    test "disconnected graph with two independent edges" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(3, 4)

      bccs = Analysis.biconnected_components(g)

      normalized =
        Enum.map(bccs, fn comp -> Enum.map(comp, fn {u, v} -> {min(u, v), max(u, v)} end) end)

      assert [{1, 2}] in normalized
      assert [{3, 4}] in normalized
    end
  end

  describe "dominators" do
    test "returns empty map when start node is missing" do
      graph = Model.empty() |> Model.put_node(1, "A")
      assert Analysis.dominators(graph, 99) == %{}
    end

    test "omits nodes unreachable from the start node" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)

      assert Analysis.dominators(graph, 1) == %{1 => 1, 2 => 1}
    end

    test "finds dominator sets" do
      g =
        Model.empty()
        |> Model.put_node(1, "root")
        |> Model.put_node(2, "A")
        |> Model.put_node(3, "B")
        |> Model.put_node(4, "C")
        |> Model.put_node(5, "D")
        |> Model.put_node(6, "E")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(2, 4)
        |> Model.add_edge!(3, 5)
        |> Model.add_edge!(4, 5)
        |> Model.add_edge!(5, 2)
        |> Model.add_edge!(1, 6)

      doms = Analysis.dominators(g, 1)
      # Root dominates itself
      assert doms[1] == 1
      # Node 2 is dominated by root and itself, so idom is root
      assert doms[2] == 1
      # Node 3 is dominated by root, 2, and itself, so idom is 2
      assert doms[3] == 2
      # Node 6 was directly from root
      assert doms[6] == 1
      # Node 5 has predecessors 3 and 4 (both dominated by 2), so idom is 2
      assert doms[5] == 2
    end

    test "dominators on simple chain" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)

      doms = Analysis.dominators(g, 1)
      assert doms[1] == 1
      assert doms[2] == 1
      assert doms[3] == 2
    end

    test "dominators on diamond graph" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(1, 3)
        |> Model.add_edge!(2, 4)
        |> Model.add_edge!(3, 4)

      doms = Analysis.dominators(g, 1)
      assert doms[1] == 1
      assert doms[2] == 1
      assert doms[3] == 1
      assert doms[4] == 1
    end
  end
end
