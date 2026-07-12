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

    test "handles empty graph" do
      assert Transform.map_nodes(Model.empty(), & &1) == Model.empty()
    end

    test "stores transformed contexts under their original node keys" do
      graph = Model.empty() |> Model.put_node(1, "A")
      transformed = Transform.map_nodes(graph, fn ctx -> %{ctx | id: :changed, label: "B"} end)

      assert Model.has_node?(transformed, 1)
      refute Model.has_node?(transformed, :changed)
      assert {:ok, %{id: :changed, label: "B"}} = Model.get_node(transformed, 1)
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

    test "removing a middle node cleans incoming and outgoing references", %{graph: graph} do
      g = Transform.filter_nodes(graph, fn ctx -> ctx.id != 2 end)

      assert Model.has_node?(g, 1)
      refute Model.has_node?(g, 2)
      assert Model.has_node?(g, 3)
      refute Model.has_edge?(g, 1, 2)
      refute Model.has_edge?(g, 2, 3)

      assert {:ok, %{}} = Model.out_neighbors(g, 1)
      assert {:ok, %{}} = Model.in_neighbors(g, 3)
    end

    test "can remove all nodes while preserving graph direction" do
      graph = Model.new(:undirected) |> Model.put_node(1, "A") |> Model.put_node(2, "B")
      g = Transform.filter_nodes(graph, fn _ctx -> false end)

      assert Model.empty?(g)
      assert g.direction == :undirected
    end
  end

  describe "fold_nodes" do
    test "accumulates over all nodes", %{graph: graph} do
      sum = Transform.fold_nodes(graph, 0, fn ctx, acc -> acc + ctx.id end)
      assert sum == 10
    end

    test "returns initial accumulator for empty graph" do
      assert Transform.fold_nodes(Model.empty(), :initial, fn _ctx, _acc -> :changed end) ==
               :initial
    end
  end

  describe "map_labels" do
    test "updates only labels", %{graph: graph} do
      g = Transform.map_labels(graph, fn label -> String.downcase(label) end)

      {:ok, ctx} = Model.get_node(g, 1)
      assert ctx.label == "a"
      assert ctx.id == 1
      assert Model.has_edge?(g, 1, 2)
    end
  end

  describe "map_edge_labels" do
    test "updates edge labels", %{graph: graph} do
      g = Transform.map_edge_labels(graph, fn label -> String.replace(label, "->", "-") end)

      {:ok, label} = Model.get_edge(g, 1, 2)
      assert label == "1-2"
    end

    test "updates both stored directions in an undirected graph" do
      graph =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, 10)

      g = Transform.map_edge_labels(graph, &(&1 * 2))

      assert {:ok, 20} = Model.get_edge(g, 1, 2)
      assert {:ok, 20} = Model.get_edge(g, 2, 1)
      assert {:ok, %{2 => 20}} = Model.in_neighbors(g, 1)
      assert {:ok, %{1 => 20}} = Model.in_neighbors(g, 2)
    end
  end

  describe "reverse" do
    test "reverses directed graph edges", %{graph: graph} do
      g = Transform.reverse(graph)

      assert g.direction == :directed
      # Edge was 1->2. Now should be 2->1
      assert Model.has_edge?(g, 2, 1)
      refute Model.has_edge?(g, 1, 2)
    end

    test "preserves self-loops in directed graphs" do
      graph = Model.empty() |> Model.put_node(1, "A") |> Model.add_edge!(1, 1, :loop)
      g = Transform.reverse(graph)

      assert g.direction == :directed
      assert Model.has_edge?(g, 1, 1)
      assert {:ok, :loop} = Model.get_edge(g, 1, 1)
    end
  end

  describe "reverse on undirected" do
    test "reverse on undirected graph is identity" do
      ug =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      assert Transform.reverse(ug) == ug
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

    test "to_undirected on already undirected graph is identity" do
      ug =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      assert Transform.to_undirected(ug) == ug
    end

    test "to_directed only changes direction flag" do
      ug =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, :edge)

      dg = Transform.to_directed(ug)

      assert dg.direction == :directed
      assert Model.has_edge?(dg, 1, 2)
      assert Model.has_edge?(dg, 2, 1)
    end

    test "to_undirected symmetrizes directed edges and preserves labels" do
      dg =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, :edge)

      ug = Transform.to_undirected(dg)

      assert ug.direction == :undirected
      assert {:ok, :edge} = Model.get_edge(ug, 1, 2)
      assert {:ok, :edge} = Model.get_edge(ug, 2, 1)
    end

    test "preserves empty graph structure when changing direction" do
      graph = Model.empty()

      assert Transform.to_directed(graph) == graph

      undirected = Transform.to_undirected(graph)
      assert Model.empty?(undirected)
      assert undirected.direction == :undirected
    end
  end
end
