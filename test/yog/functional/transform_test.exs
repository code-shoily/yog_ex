defmodule Yog.Functional.TransformTest do
  use ExUnit.Case, async: true
  alias Yog.Functional.Model
  alias Yog.Functional.Transform
  doctest Yog.Functional.Transform

  setup do
    g =
      Model.empty()
      |> Model.put_node(1, "A")
      |> Model.put_node(2, "B")
      |> Model.put_node(3, "C")
      |> Model.put_node(4, "D")
      |> Model.add_edge!(1, 2, "1->2")
      |> Model.add_edge!(2, 3, "2->3")

    {:ok, graph: g}
  end

  describe "map_nodes" do
    test "transforms contexts", %{graph: graph} do
      g = Transform.map_nodes(graph, fn ctx -> %{ctx | label: ctx.label <> "_mapped"} end)

      {:ok, ctx} = Model.get_node(g, 1)
      assert ctx.label == "A_mapped"
    end
  end

  describe "filter_nodes" do
    test "keeps nodes where function returns true", %{graph: graph} do
      # Let's keep ONLY node 1
      g = Transform.filter_nodes(graph, fn ctx -> ctx.id == 1 end)

      assert Model.has_node?(g, 1)
      refute Model.has_node?(g, 2)

      # Since node 2 is gone, node 1's out-edges shouldn't have 2 anymore
      {:ok, ctx} = Model.get_node(g, 1)
      assert map_size(ctx.out_edges) == 0
    end
  end

  describe "fold_nodes" do
    test "accumulates over all nodes", %{graph: graph} do
      sum = Transform.fold_nodes(graph, 0, fn ctx, acc -> acc + ctx.id end)
      assert sum == 10
    end
  end

  describe "map_labels" do
    test "updates only labels", %{graph: graph} do
      g = Transform.map_labels(graph, fn label -> String.downcase(label) end)

      {:ok, ctx} = Model.get_node(g, 1)
      assert ctx.label == "a"
    end
  end

  describe "map_edge_labels" do
    test "updates edge labels", %{graph: graph} do
      g = Transform.map_edge_labels(graph, fn label -> String.replace(label, "->", "-") end)

      {:ok, label} = Model.get_edge(g, 1, 2)
      assert label == "1-2"
    end
  end

  describe "reverse" do
    test "reverses directed graph edges", %{graph: graph} do
      g = Transform.reverse(graph)

      # Edge was 1->2. Now should be 2->1
      assert Model.has_edge?(g, 2, 1)
      refute Model.has_edge?(g, 1, 2)
    end
  end

  describe "to_directed/1 and to_undirected/1" do
    test "converts between directions correctly" do
      dg =
        Model.new(:directed)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      ug = Transform.to_undirected(dg)
      assert ug.direction == :undirected
      assert Model.has_edge?(ug, 1, 2)
      assert Model.has_edge?(ug, 2, 1)

      back_dg = Transform.to_directed(ug)
      assert back_dg.direction == :directed
      # But since the edges were physically added symmetric, this might still have 2,1
      # Note: Transform.to_directed/1 only changes direction currently as an interpretation
      assert Model.has_edge?(back_dg, 2, 1)
    end
  end
end
