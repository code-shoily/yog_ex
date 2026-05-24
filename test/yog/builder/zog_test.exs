defmodule Yog.Builder.ZogTest do
  use ExUnit.Case, async: true

  alias Yog.Builder.Zog

  describe "construction" do
    test "directed/0 and undirected/0" do
      assert %Zog{kind: :directed} = Zog.directed()
      assert %Zog{kind: :undirected} = Zog.undirected()
    end

    test "add_node/2 assigns sequential ids" do
      builder =
        Zog.directed()
        |> Zog.add_node("A")
        |> Zog.add_node("B")

      assert Zog.label_to_id(builder, "A") == 0
      assert Zog.label_to_id(builder, "B") == 1
      assert Zog.node_count(builder) == 2
    end

    test "add_edge/4 auto-creates nodes" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 10)

      assert Zog.node_count(builder) == 2
      assert Zog.edge_count(builder) == 1
      assert Zog.label_to_id(builder, "A") == 0
      assert Zog.label_to_id(builder, "B") == 1
    end

    test "undirected edges are stored bidirectionally" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 5)

      assert Zog.edge_count(builder) == 2
      edges = Zog.all_edges(builder)
      assert {0, 1, 5.0} in edges
      assert {1, 0, 5.0} in edges
    end

    test "to_edge_arrays/1" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 2.0)

      {from, to, weights} = Zog.to_edge_arrays(builder)
      assert from == [0, 1]
      assert to == [1, 2]
      assert weights == [1.0, 2.0]
    end
  end

  describe "conversion from Yog.Graph" do
    test "from_graph/1 preserves structure" do
      graph =
        Yog.directed()
        |> Yog.add_node(:a, "A")
        |> Yog.add_node(:b, "B")
        |> Yog.add_edge!(:a, :b, 10)

      builder = Zog.from_graph(graph)

      assert Zog.node_count(builder) == 2
      assert Zog.edge_count(builder) == 1
      assert Zog.label_to_id(builder, :a) == 0
      assert Zog.label_to_id(builder, :b) == 1
    end

    test "from_graph/1 handles undirected graphs" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 5)

      builder = Zog.from_graph(graph)
      assert builder.kind == :undirected
      assert Zog.edge_count(builder) == 2
    end
  end

  describe "conversion from Yog.Builder.Labeled" do
    test "from_labeled/1 preserves mapping" do
      labeled =
        Yog.Builder.Labeled.directed()
        |> Yog.Builder.Labeled.add_edge("X", "Y", 3)

      builder = Zog.from_labeled(labeled)

      assert Zog.node_count(builder) == 2
      assert Zog.label_to_id(builder, "X") == 0
      assert Zog.label_to_id(builder, "Y") == 1
    end
  end

  describe "round-trip" do
    test "to_graph/1 after from_graph/1" do
      original =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 10)

      builder = Zog.from_graph(original)
      roundtrip = Zog.to_graph(builder)

      assert Yog.Model.order(roundtrip) == 2
      assert Yog.Model.edge_count(roundtrip) == 1
      # Node IDs become integer indices; original labels are node data
      assert Yog.has_edge?(roundtrip, 0, 1)
      assert Yog.Model.node(roundtrip, 0) == 1
      assert Yog.Model.node(roundtrip, 1) == 2
    end
  end
end
