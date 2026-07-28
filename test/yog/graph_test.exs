defmodule Yog.GraphTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Yog.Graph
  doctest Enumerable.Yog.Graph
  doctest Inspect.Yog.Graph

  alias Yog.Graph
  alias Yog.Model

  # ============= Constructor & Validation Tests =============

  describe "new/1 constructor validation" do
    test "creates directed and undirected graphs" do
      g_dir = Graph.new(:directed)
      assert g_dir.kind == :directed

      g_undir = Graph.new(:undirected)
      assert g_undir.kind == :undirected
    end

    test "raises ArgumentError on invalid kind" do
      assert_raise ArgumentError, ~r/expected kind to be :directed or :undirected/, fn ->
        Graph.new(:invalid)
      end
    end
  end

  describe "node_count/1 and edge_count/1 struct verification" do
    test "edge_count with self-loops (directed)" do
      graph =
        Graph.new(:directed)
        |> Model.add_node(1, "A")
        |> Model.add_edge!(1, 1, 10)

      assert Graph.edge_count(graph) == 1
    end

    test "edge_count with self-loops (undirected)" do
      graph =
        Graph.new(:undirected)
        |> Model.add_node(1, "A")
        |> Model.add_edge!(1, 1, 10)

      assert Graph.edge_count(graph) == 1
    end

    test "edge_count complex with self-loops (undirected)" do
      graph =
        Graph.new(:undirected)
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge!(1, 2, 10)
        |> Model.add_edge!(1, 1, 5)

      assert Graph.edge_count(graph) == 2
    end

    test "raises ArgumentError on non-Graph input" do
      assert_raise ArgumentError, ~r/expected a Yog.Graph struct/, fn ->
        Graph.node_count(:not_a_graph)
      end

      assert_raise ArgumentError, ~r/expected a Yog.Graph struct/, fn ->
        Graph.edge_count(:not_a_graph)
      end
    end
  end

  describe "Inspect protocol implementation" do
    test "formats directed and undirected graph inspection" do
      g1 = Graph.new(:directed) |> Model.add_node(1, "A")
      assert inspect(g1) == "#Yog.Graph<:directed, 1 node, 0 edges>"

      g2 =
        Graph.new(:undirected)
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge!(1, 2, 10)

      assert inspect(g2) == "#Yog.Graph<:undirected, 2 nodes, 1 edge>"
    end
  end

  # ============= Property-Based Invariant Tests =============

  describe "property-based graph struct invariants" do
    property "dual-map index symmetry: out_edges and in_edges remain consistent" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              nodes <-
                StreamData.list_of(StreamData.integer(1..30), min_length: 0, max_length: 15),
              edges <-
                StreamData.list_of(
                  StreamData.tuple({
                    StreamData.integer(1..30),
                    StreamData.integer(1..30),
                    StreamData.integer(1..100)
                  }),
                  min_length: 0,
                  max_length: 20
                )
            ) do
        graph =
          Enum.reduce(nodes, Model.new(kind), fn u, g ->
            Model.add_node(g, u, "node_#{u}")
          end)

        graph =
          Enum.reduce(edges, graph, fn {u, v, w}, g ->
            Model.add_edge_ensure(g, u, v, w)
          end)

        # Every out_edge u -> v with weight w MUST exist in in_edges v -> u with weight w
        for {u, inner} <- graph.out_edges,
            {v, w} <- inner do
          in_weight = graph.in_edges |> Map.get(v, %{}) |> Map.get(u)
          assert in_weight == w
        end

        # Node count matches map_size(nodes)
        assert Graph.node_count(graph) == map_size(graph.nodes)

        # Enumerable iterates over all nodes as {id, data}
        assert Enum.sort(Enum.to_list(graph)) == Enum.sort(Map.to_list(graph.nodes))
      end
    end
  end
end
