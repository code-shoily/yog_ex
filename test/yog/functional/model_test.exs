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

      # Test add_edge/3 (default label) on undirected graph
      {:ok, g0} = Model.add_edge(g, 1, 2)
      assert Model.has_edge?(g0, 1, 2)

      {:ok, g1} = Model.add_edge(g, 1, 2, "1-2")

      # Since it's undirected, an edge from 1 to 2 also adds an out edge from 2 to 1 in representation
      assert Model.has_edge?(g1, 1, 2)
      assert Model.has_edge?(g1, 2, 1)

      {:ok, g2} = Model.remove_edge(g1, 1, 2)
      refute Model.has_edge?(g2, 1, 2)
      refute Model.has_edge?(g2, 2, 1)

      # Test remove_edge! and remove_undirected_edge!
      g3 = Model.add_edge!(g, 1, 2, "x")
      g4 = Model.remove_edge!(g3, 1, 2)
      refute Model.has_edge?(g4, 1, 2)

      g5 = Model.remove_undirected_edge!(g3, 1, 2)
      refute Model.has_edge?(g5, 1, 2)
    end
  end

  describe "get_node and get_node!" do
    test "get_node returns context or error" do
      g = Model.empty() |> Model.put_node(1, "A")
      assert {:ok, ctx} = Model.get_node(g, 1)
      assert ctx.id == 1
      assert ctx.label == "A"
      assert {:error, :not_found} = Model.get_node(g, 2)
    end

    test "get_node! returns context or raises" do
      g = Model.empty() |> Model.put_node(1, "A")
      assert %Model.Context{id: 1} = Model.get_node!(g, 1)
      assert_raise KeyError, fn -> Model.get_node!(g, 2) end
    end
  end

  describe "neighbor and edge queries" do
    setup do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2, "w12")
        |> Model.add_edge!(2, 3, "w23")

      {:ok, graph: g}
    end

    test "out_neighbors and in_neighbors", %{graph: g} do
      assert {:ok, %{2 => "w12"}} = Model.out_neighbors(g, 1)
      assert {:ok, %{1 => "w12"}} = Model.in_neighbors(g, 2)
      assert {:error, :not_found} = Model.out_neighbors(g, 99)
      assert {:error, :not_found} = Model.in_neighbors(g, 99)
    end

    test "neighbors returns all unique neighbors", %{graph: g} do
      # Add a reverse edge so 2 has both in and out neighbors
      g2 = Model.add_edge!(g, 3, 2, "w32")
      assert {:ok, neighbors} = Model.neighbors(g2, 2)
      assert Enum.sort(neighbors) == [1, 3]
      assert {:error, :not_found} = Model.neighbors(g2, 99)
    end

    test "has_edge? and get_edge", %{graph: g} do
      assert Model.has_edge?(g, 1, 2)
      refute Model.has_edge?(g, 2, 1)
      refute Model.has_edge?(g, 99, 1)

      assert {:ok, "w12"} = Model.get_edge(g, 1, 2)
      assert {:error, :not_found} = Model.get_edge(g, 2, 1)
      assert {:error, :not_found} = Model.get_edge(g, 99, 1)
    end

    test "degree functions", %{graph: g} do
      assert {:ok, 1} = Model.out_degree(g, 1)
      assert {:ok, 1} = Model.in_degree(g, 2)
      assert {:ok, 2} = Model.degree(g, 2)
      assert {:error, :not_found} = Model.out_degree(g, 99)
      assert {:error, :not_found} = Model.in_degree(g, 99)
      assert {:error, :not_found} = Model.degree(g, 99)
    end

    test "edges returns all edges", %{graph: g} do
      edges = Model.edges(g)
      assert length(edges) == 2
      assert {1, 2, "w12"} in edges
      assert {2, 3, "w23"} in edges
    end
  end

  describe "edge error handling" do
    test "add_edge returns error for missing nodes" do
      g = Model.empty() |> Model.put_node(1, "A")
      assert {:error, :source_not_found} = Model.add_edge(g, 99, 1, "w")
      assert {:error, :target_not_found} = Model.add_edge(g, 1, 99, "w")
    end

    test "add_edge! raises on error" do
      g = Model.empty() |> Model.put_node(1, "A")
      assert_raise RuntimeError, fn -> Model.add_edge!(g, 99, 1) end
    end

    test "add_undirected_edge returns error for missing nodes" do
      g = Model.new(:undirected) |> Model.put_node(1, "A")
      assert {:error, :source_not_found} = Model.add_undirected_edge(g, 99, 1, "w")
      assert {:error, :target_not_found} = Model.add_undirected_edge(g, 1, 99, "w")
    end

    test "add_undirected_edge! raises on error" do
      g = Model.new(:undirected) |> Model.put_node(1, "A")
      assert_raise RuntimeError, fn -> Model.add_undirected_edge!(g, 99, 1) end
    end
  end

  describe "match_any" do
    test "match_any on empty graph" do
      assert {:error, :empty} = Model.match_any(Model.empty())
    end

    test "match_any extracts arbitrary node" do
      g = Model.empty() |> Model.put_node(1, "A")
      {:ok, ctx, remaining} = Model.match_any(g)
      assert ctx.id == 1
      assert Model.empty?(remaining)
    end
  end

  describe "remove_node" do
    test "remove_node not found returns graph unchanged" do
      g = Model.empty() |> Model.put_node(1, "A")
      {:ok, g2} = Model.remove_node(g, 99)
      assert Model.has_node?(g2, 1)
    end

    test "remove_node with self-loop" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.add_edge!(1, 1, "loop")

      {:ok, g2} = Model.remove_node(g, 1)
      assert Model.empty?(g2)
    end
  end

  describe "ensure_node and put_node" do
    test "ensure_node does nothing if node exists" do
      g = Model.empty() |> Model.put_node(1, "A")
      g2 = Model.ensure_node(g, 1, "B")
      {:ok, ctx} = Model.get_node(g2, 1)
      assert ctx.label == "A"
    end

    test "ensure_node creates node if missing" do
      g = Model.empty()
      g2 = Model.ensure_node(g, 1, "A")
      assert Model.has_node?(g2, 1)
    end

    test "put_node updates existing node label" do
      g = Model.empty() |> Model.put_node(1, "A")
      g2 = Model.put_node(g, 1, "B")
      {:ok, ctx} = Model.get_node(g2, 1)
      assert ctx.label == "B"
    end
  end

  describe "adjacency graph interop" do
    test "roundtrip conversion preserves structure" do
      fg =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, "w")

      eg = Model.to_adjacency_graph(fg)
      assert eg.kind == :directed
      assert eg.nodes[1] == "A"
      assert eg.nodes[2] == "B"
      assert eg.out_edges[1][2] == "w"
      assert eg.in_edges[2][1] == "w"

      fg2 = Model.from_adjacency_graph(eg)
      assert Model.size(fg2) == 2
      assert Model.has_edge?(fg2, 1, 2)
      {:ok, ctx} = Model.get_node(fg2, 1)
      assert ctx.label == "A"
    end

    test "undirected roundtrip conversion preserves direction and symmetric edges" do
      fg =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, "w")

      eg = Model.to_adjacency_graph(fg)
      assert eg.kind == :undirected
      assert eg.out_edges[1][2] == "w"
      assert eg.out_edges[2][1] == "w"
      assert eg.in_edges[1][2] == "w"
      assert eg.in_edges[2][1] == "w"

      fg2 = Model.from_adjacency_graph(eg)
      assert fg2.direction == :undirected
      assert Model.has_edge?(fg2, 1, 2)
      assert Model.has_edge?(fg2, 2, 1)
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

    test "match/2 preserves graph direction in the remaining graph" do
      graph =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, :edge)

      {:ok, _ctx, shrunken} = Model.match(graph, 1)

      assert shrunken.direction == :undirected
      refute Model.has_node?(shrunken, 1)
      assert Model.has_node?(shrunken, 2)
    end

    test "embed/2 restores a node and its edges", %{graph: graph} do
      {:ok, ctx, shrunken} = Model.match(graph, 1)

      restored = Model.embed(ctx, shrunken)

      assert Model.has_node?(restored, 1)
      assert Model.has_edge?(restored, 1, 2)
      assert Model.has_edge?(restored, 3, 1)
    end

    test "embed/2 preserves target graph direction" do
      graph =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, :edge)

      {:ok, ctx, shrunken} = Model.match(graph, 1)
      restored = Model.embed(ctx, shrunken)

      assert restored.direction == :undirected
      assert Model.has_edge?(restored, 1, 2)
      assert Model.has_edge?(restored, 2, 1)
    end

    test "embed/2 does not restore reverse references to missing neighbors" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, :edge)

      {:ok, ctx, shrunken} = Model.match(graph, 1)
      {:ok, shrunken_without_neighbor} = Model.remove_node(shrunken, 2)
      restored = Model.embed(ctx, shrunken_without_neighbor)

      assert Model.has_node?(restored, 1)
      assert Model.has_edge?(restored, 1, 2)
      refute Model.has_node?(restored, 2)
    end
  end

  describe "edge overwrite and self-loop semantics" do
    test "adding an existing edge overwrites its label" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, :old)
        |> Model.add_edge!(1, 2, :new)

      assert {:ok, :new} = Model.get_edge(graph, 1, 2)

      {:ok, in_neighbors} = Model.in_neighbors(graph, 2)
      assert in_neighbors[1] == :new
    end

    test "self-loop contributes to both in-degree and out-degree" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.add_edge!(1, 1, :loop)

      assert {:ok, 1} = Model.out_degree(graph, 1)
      assert {:ok, 1} = Model.in_degree(graph, 1)
      assert {:ok, 2} = Model.degree(graph, 1)
      assert {:ok, :loop} = Model.get_edge(graph, 1, 1)
    end
  end
end
