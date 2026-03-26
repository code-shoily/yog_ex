defmodule Yog.Functional.ModelTest do
  use ExUnit.Case, async: true
  alias Yog.Functional.Model
  doctest Yog.Functional.Model

  describe "creation and basic properties" do
    test "new/1 creates a graph with specified direction" do
      g1 = Model.new(:directed)
      assert g1.direction == :directed

      g2 = Model.new(:undirected)
      assert g2.direction == :undirected

      g3 = Model.empty()
      assert g3.direction == :directed
      assert Model.empty?(g3)
    end
  end

  describe "node operations" do
    setup do
      {:ok, graph: Model.empty()}
    end

    test "add, get, check, and remove nodes", %{graph: graph} do
      g1 = Model.put_node(graph, 1, "A")
      assert Model.has_node?(g1, 1)
      assert Model.size(g1) == 1

      {:ok, ctx} = Model.get_node(g1, 1)
      assert ctx.id == 1
      assert ctx.label == "A"

      g2 = Model.remove_node!(g1, 1)
      refute Model.has_node?(g2, 1)
      assert Model.empty?(g2)
    end
  end

  describe "edge operations" do
    setup do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")

      {:ok, graph: g}
    end

    test "add and remove directed edges", %{graph: graph} do
      {:ok, g1} = Model.add_edge(graph, 1, 2, "1->2")
      assert Model.has_edge?(g1, 1, 2)
      refute Model.has_edge?(g1, 2, 1)

      {:ok, out_n} = Model.out_neighbors(g1, 1)
      assert Map.has_key?(out_n, 2)

      {:ok, in_n} = Model.in_neighbors(g1, 2)
      assert Map.has_key?(in_n, 1)

      {:ok, g2} = Model.remove_edge(g1, 1, 2)
      refute Model.has_edge?(g2, 1, 2)
    end

    test "add and remove undirected edges" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")

      {:ok, g1} = Model.add_edge(g, 1, 2, "1-2")

      # Since it's undirected, an edge from 1 to 2 also adds an out edge from 2 to 1 in representation
      assert Model.has_edge?(g1, 1, 2)
      assert Model.has_edge?(g1, 2, 1)

      {:ok, g2} = Model.remove_edge(g1, 1, 2)
      refute Model.has_edge?(g2, 1, 2)
      refute Model.has_edge?(g2, 2, 1)
    end
  end

  describe "match and embed" do
    setup do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)

      {:ok, graph: g}
    end

    test "match/2 extracts a node and removes its incident edges", %{graph: graph} do
      assert Model.has_edge?(graph, 1, 2)
      assert Model.has_edge?(graph, 3, 1)

      {:ok, ctx, shrunken} = Model.match(graph, 1)

      assert ctx.id == 1
      assert Map.has_key?(ctx.out_edges, 2)
      assert Map.has_key?(ctx.in_edges, 3)

      refute Model.has_node?(shrunken, 1)
      # Edges involving 1 should be gone
      refute Model.has_edge?(shrunken, 3, 1)
      assert Model.has_edge?(shrunken, 2, 3)
    end

    test "embed/2 restores a node and its edges", %{graph: graph} do
      {:ok, ctx, shrunken} = Model.match(graph, 1)

      restored = Model.embed(ctx, shrunken)

      assert Model.has_node?(restored, 1)
      assert Model.has_edge?(restored, 1, 2)
      assert Model.has_edge?(restored, 3, 1)
    end
  end
end
