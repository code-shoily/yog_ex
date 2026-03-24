defmodule Yog.PBT.OperationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Operation Properties" do
    property "union(G1, G2) contains all nodes and edges" do
      check all({g1, g2} <- same_kind_graphs_gen()) do
        u = Yog.Operation.union(g1, g2)

        n1 = Yog.all_nodes(g1) |> MapSet.new()
        n2 = Yog.all_nodes(g2) |> MapSet.new()
        un = Yog.all_nodes(u) |> MapSet.new()
        assert MapSet.equal?(un, MapSet.union(n1, n2))

        assert Yog.edge_count(u) <= Yog.edge_count(g1) + Yog.edge_count(g2)
      end
    end

    property "intersection(G, G) == G" do
      check all(graph <- graph_gen()) do
        assert graph == Yog.Operation.intersection(graph, graph)
      end
    end

    property "difference(G, G) is empty" do
      check all(graph <- graph_gen()) do
        diff = Yog.Operation.difference(graph, graph)
        assert Yog.node_count(diff) == 0
        assert Yog.edge_count(diff) == 0
      end
    end

    property "disjoint_union re-indexing avoids collisions" do
      check all({g1, g2} <- same_kind_graphs_gen()) do
        combined = Yog.Operation.disjoint_union(g1, g2)
        assert Yog.node_count(combined) == Yog.node_count(g1) + Yog.node_count(g2)
        assert Yog.edge_count(combined) == Yog.edge_count(g1) + Yog.edge_count(g2)
      end
    end

    property "isomorphic?(G, G) is true" do
      check all(graph <- small_graph_gen()) do
        assert Yog.Operation.isomorphic?(graph, graph)
      end
    end

    property "isomorphic?(G1, G2) where G2 is a re-indexed G1" do
      check all(graph <- small_graph_gen()) do
        reindexed = Yog.Operation.disjoint_union(Yog.new(graph.kind), graph)
        assert Yog.Operation.isomorphic?(graph, reindexed)
      end
    end
  end
end
