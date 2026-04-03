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

    property "power(G, 1) == G" do
      check all(graph <- graph_gen()) do
        assert Yog.Operation.power(graph, 1, 1) == graph
      end
    end

    property "cartesian_product order equals product of orders" do
      check all(g1 <- directed_graph_gen(), g2 <- directed_graph_gen()) do
        product = Yog.Operation.cartesian_product(g1, g2, 0, 0)
        assert Yog.node_count(product) == Yog.node_count(g1) * Yog.node_count(g2)
      end
    end

    property "subgraph? is reflexive" do
      check all(graph <- graph_gen()) do
        assert Yog.Operation.subgraph?(graph, graph)
      end
    end

    property "subgraph?(subgraph(G, S), G) is true" do
      check all(graph <- graph_gen()) do
        ids = Yog.all_nodes(graph)

        if length(ids) > 0 do
          subset = Enum.take(ids, max(1, div(length(ids), 2)))
          sub = Yog.subgraph(graph, subset)
          assert Yog.Operation.subgraph?(sub, graph)
        end
      end
    end

    property "symmetric_difference is commutative" do
      check all({g1, g2} <- same_kind_graphs_gen()) do
        sd1 = Yog.Operation.symmetric_difference(g1, g2)
        sd2 = Yog.Operation.symmetric_difference(g2, g1)

        assert Yog.node_count(sd1) == Yog.node_count(sd2)
        assert Yog.edge_count(sd1) == Yog.edge_count(sd2)
      end
    end

    property "symmetric_difference edges are in exactly one input" do
      check all({g1, g2} <- same_kind_graphs_gen()) do
        sd = Yog.Operation.symmetric_difference(g1, g2)

        for {u, v, _w} <- Yog.all_edges(sd) do
          assert Yog.Model.has_edge?(g1, u, v) != Yog.Model.has_edge?(g2, u, v)
        end
      end
    end

    property "line_graph node count equals edge count of original" do
      check all(graph <- graph_gen()) do
        lg = Yog.Operation.line_graph(graph, 1)
        assert Yog.node_count(lg) == Yog.edge_count(graph)
      end
    end

    property "line_graph edge count for simple undirected graphs" do
      check all(graph <- undirected_graph_gen()) do
        graph = Yog.filter_edges(graph, fn u, v, _ -> u != v end)
        lg = Yog.Operation.line_graph(graph, 1)

        expected_edges =
          Yog.all_nodes(graph)
          |> Enum.map(&Yog.Model.degree(graph, &1))
          |> Enum.map(fn d -> div(d * (d - 1), 2) end)
          |> Enum.sum()

        assert Yog.edge_count(lg) == expected_edges
      end
    end

    property "line_graph edge count for simple directed graphs (line digraph)" do
      check all(graph <- directed_graph_gen()) do
        graph = Yog.filter_edges(graph, fn u, v, _ -> u != v end)
        lg = Yog.Operation.line_graph(graph, 1)

        expected_edges =
          Yog.all_nodes(graph)
          |> Enum.map(fn v -> Yog.Model.in_degree(graph, v) * Yog.Model.out_degree(graph, v) end)
          |> Enum.sum()

        assert Yog.edge_count(lg) == expected_edges
      end
    end
  end
end
