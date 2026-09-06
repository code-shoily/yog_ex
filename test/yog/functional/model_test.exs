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

  describe "pre-1.0 confidence: functional model edge cases" do
    test "empty graph behavior across operations" do
      g_dir = Model.new(:directed)
      g_undir = Model.new(:undirected)

      for g <- [g_dir, g_undir] do
        assert Model.empty?(g)
        assert Model.size(g) == 0
        assert Model.edges(g) == []
        assert Model.nodes(g) == []
        refute Model.has_node?(g, :nonexistent)
        refute Model.has_edge?(g, :u, :v)
        assert Model.get_node(g, :nonexistent) == {:error, :not_found}
        assert Model.get_edge(g, :u, :v) == {:error, :not_found}
        assert Model.out_degree(g, :u) == {:error, :not_found}
        assert Model.in_degree(g, :u) == {:error, :not_found}
        assert Model.degree(g, :u) == {:error, :not_found}
        assert Model.out_neighbors(g, :u) == {:error, :not_found}
        assert Model.in_neighbors(g, :u) == {:error, :not_found}
        assert Model.match(g, :u) == {:error, :not_found}
        assert Model.match_any(g) == {:error, :empty}

        # Conversion to and from empty adjacency graph
        adj = Model.to_adjacency_graph(g)
        assert adj.kind == g.direction
        assert map_size(adj.nodes) == 0
        assert map_size(adj.out_edges) == 0
        assert map_size(adj.in_edges) == 0

        restored = Model.from_adjacency_graph(adj)
        assert restored.direction == g.direction
        assert Model.empty?(restored)
      end
    end

    test "isolated nodes in directed and undirected graphs" do
      g =
        Model.empty()
        |> Model.put_node(1, "isolated_1")
        |> Model.put_node(2, "isolated_2")

      assert Model.size(g) == 2
      assert Model.edges(g) == []
      assert Model.has_node?(g, 1)
      assert Model.has_node?(g, 2)
      assert {:ok, 0} = Model.out_degree(g, 1)
      assert {:ok, 0} = Model.in_degree(g, 1)
      assert {:ok, 0} = Model.degree(g, 1)
      assert {:ok, %{}} = Model.out_neighbors(g, 1)
      assert {:ok, %{}} = Model.in_neighbors(g, 1)

      # Match an isolated node
      {:ok, ctx, remaining} = Model.match(g, 1)
      assert ctx.id == 1
      assert ctx.label == "isolated_1"
      assert ctx.in_edges == %{}
      assert ctx.out_edges == %{}
      assert Model.size(remaining) == 1
      assert Model.has_node?(remaining, 2)
      refute Model.has_node?(remaining, 1)

      # Embed isolated node back
      restored = Model.embed(ctx, remaining)
      assert Model.size(restored) == 2
      assert Model.has_node?(restored, 1)
      assert {:ok, 0} = Model.degree(restored, 1)
    end

    test "self-loops on directed and undirected graphs" do
      # Directed graph with self-loop
      g_dir =
        Model.empty()
        |> Model.put_node(1, "node1")
        |> Model.add_edge!(1, 1, :self_dir)

      assert Model.has_edge?(g_dir, 1, 1)
      assert {:ok, :self_dir} = Model.get_edge(g_dir, 1, 1)
      assert {:ok, 1} = Model.out_degree(g_dir, 1)
      assert {:ok, 1} = Model.in_degree(g_dir, 1)
      assert {:ok, 2} = Model.degree(g_dir, 1)

      # Match node with self-loop
      {:ok, ctx_dir, shrunken_dir} = Model.match(g_dir, 1)
      assert ctx_dir.out_edges == %{1 => :self_dir}
      assert ctx_dir.in_edges == %{1 => :self_dir}
      assert Model.empty?(shrunken_dir)

      # Restoring node with self-loop via embed
      restored_dir = Model.embed(ctx_dir, shrunken_dir)
      assert Model.has_edge?(restored_dir, 1, 1)
      assert {:ok, :self_dir} = Model.get_edge(restored_dir, 1, 1)

      # Undirected graph with self-loop
      g_undir =
        Model.new(:undirected)
        |> Model.put_node(1, "node1")
        |> Model.add_edge!(1, 1, :self_undir)

      assert Model.has_edge?(g_undir, 1, 1)
      assert {:ok, :self_undir} = Model.get_edge(g_undir, 1, 1)

      # Match and embed undirected self-loop
      {:ok, ctx_undir, shrunken_undir} = Model.match(g_undir, 1)
      assert Model.empty?(shrunken_undir)
      restored_undir = Model.embed(ctx_undir, shrunken_undir)
      assert restored_undir.direction == :undirected
      assert Model.has_edge?(restored_undir, 1, 1)
    end

    test "direction preservation through from_adjacency_graph and to_adjacency_graph" do
      for dir <- [:directed, :undirected] do
        adj =
          Yog.new(dir)
          |> Yog.add_node(1, "A")
          |> Yog.add_node(2, "B")
          |> Yog.add_edge_ensure(from: 1, to: 2, with: "w")

        f_graph = Model.from_adjacency_graph(adj)
        assert f_graph.direction == dir

        adj_converted = Model.to_adjacency_graph(f_graph)
        assert adj_converted.kind == dir

        f_graph_roundtrip = Model.from_adjacency_graph(adj_converted)
        assert f_graph_roundtrip.direction == dir
      end
    end

    test "embed does not reverse edge orientation in directed graphs" do
      # Graph: 1 -> 2 with label :one_to_two, and 2 -> 3 with label :two_to_three
      g =
        Model.empty()
        |> Model.put_node(1, "first")
        |> Model.put_node(2, "middle")
        |> Model.put_node(3, "last")
        |> Model.add_edge!(1, 2, :one_to_two)
        |> Model.add_edge!(2, 3, :two_to_three)

      # Match middle node (has incoming from 1 and outgoing to 3)
      {:ok, ctx, shrunken} = Model.match(g, 2)
      assert ctx.in_edges == %{1 => :one_to_two}
      assert ctx.out_edges == %{3 => :two_to_three}

      # In shrunken graph, node 2 and its edges are gone
      refute Model.has_edge?(shrunken, 1, 2)
      refute Model.has_edge?(shrunken, 2, 3)

      # Embed node 2 back
      restored = Model.embed(ctx, shrunken)

      # Verify orientation: 1 -> 2 must exist, 2 -> 1 must NOT exist
      assert Model.has_edge?(restored, 1, 2)
      assert {:ok, :one_to_two} = Model.get_edge(restored, 1, 2)
      refute Model.has_edge?(restored, 2, 1)
      assert Model.get_edge(restored, 2, 1) == {:error, :not_found}

      # Verify orientation: 2 -> 3 must exist, 3 -> 2 must NOT exist
      assert Model.has_edge?(restored, 2, 3)
      assert {:ok, :two_to_three} = Model.get_edge(restored, 2, 3)
      refute Model.has_edge?(restored, 3, 2)
      assert Model.get_edge(restored, 3, 2) == {:error, :not_found}

      # Verify in_neighbors and out_neighbors for all nodes
      assert {:ok, %{2 => :one_to_two}} = Model.out_neighbors(restored, 1)
      assert {:ok, %{}} = Model.in_neighbors(restored, 1)

      assert {:ok, %{1 => :one_to_two}} = Model.in_neighbors(restored, 2)
      assert {:ok, %{3 => :two_to_three}} = Model.out_neighbors(restored, 2)

      assert {:ok, %{2 => :two_to_three}} = Model.in_neighbors(restored, 3)
      assert {:ok, %{}} = Model.out_neighbors(restored, 3)
    end

    test "match and embed behavior after removing and restoring multiple contexts" do
      # Create a triangle: 1 -> 2 -> 3 -> 1
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2, 12)
        |> Model.add_edge!(2, 3, 23)
        |> Model.add_edge!(3, 1, 31)

      # Match node 1, then node 2 sequentially
      {:ok, ctx1, g_after_1} = Model.match(g, 1)
      {:ok, ctx2, g_after_2} = Model.match(g_after_1, 2)

      assert Model.size(g_after_2) == 1
      assert Model.has_node?(g_after_2, 3)

      # Restore in LIFO order (2, then 1)
      g_restored_2 = Model.embed(ctx2, g_after_2)
      assert Model.has_edge?(g_restored_2, 2, 3)
      # Edge 1 -> 2 is not yet present because node 1 is not in g_restored_2
      refute Model.has_edge?(g_restored_2, 1, 2)

      g_restored_all = Model.embed(ctx1, g_restored_2)
      assert Model.has_edge?(g_restored_all, 1, 2)
      assert Model.has_edge?(g_restored_all, 2, 3)
      assert Model.has_edge?(g_restored_all, 3, 1)
      assert Model.size(g_restored_all) == 3

      # Roundtrip identity check: structure of g_restored_all matches original g
      for id <- [1, 2, 3] do
        assert {:ok, orig_ctx} = Model.get_node(g, id)
        assert {:ok, rest_ctx} = Model.get_node(g_restored_all, id)
        assert orig_ctx.id == rest_ctx.id
        assert orig_ctx.label == rest_ctx.label
        assert orig_ctx.in_edges == rest_ctx.in_edges
        assert orig_ctx.out_edges == rest_ctx.out_edges
      end
    end

    test "roundtrip conversion preserves node set and edge set for directed and undirected graphs" do
      # Directed graph with varying weights and isolated node
      adj_dir =
        Yog.directed()
        |> Yog.add_node(1, "alpha")
        |> Yog.add_node(2, "beta")
        |> Yog.add_node(3, "gamma")
        |> Yog.add_node(4, "isolated")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 20)
        |> Yog.add_edge_ensure(from: 3, to: 1, with: 30)
        |> Yog.add_edge_ensure(from: 1, to: 1, with: 99)

      f_dir = Model.from_adjacency_graph(adj_dir)
      adj_dir_back = Model.to_adjacency_graph(f_dir)

      assert adj_dir_back.kind == adj_dir.kind
      assert adj_dir_back.nodes == adj_dir.nodes
      assert Yog.all_edges(adj_dir_back) |> Enum.sort() == Yog.all_edges(adj_dir) |> Enum.sort()

      # Undirected graph with varying weights and isolated node
      adj_undir =
        Yog.undirected()
        |> Yog.add_node("x", 100)
        |> Yog.add_node("y", 200)
        |> Yog.add_node("z", 300)
        |> Yog.add_node("iso", 400)
        |> Yog.add_edge_ensure(from: "x", to: "y", with: 5)
        |> Yog.add_edge_ensure(from: "y", to: "z", with: 15)
        |> Yog.add_edge_ensure(from: "x", to: "x", with: 50)

      f_undir = Model.from_adjacency_graph(adj_undir)
      adj_undir_back = Model.to_adjacency_graph(f_undir)

      assert adj_undir_back.kind == adj_undir.kind
      assert adj_undir_back.nodes == adj_undir.nodes

      assert Yog.all_edges(adj_undir_back) |> Enum.sort() ==
               Yog.all_edges(adj_undir) |> Enum.sort()
    end
  end
end
