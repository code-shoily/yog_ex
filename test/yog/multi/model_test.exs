defmodule Yog.Multi.ModelTest do
  @moduledoc """
  Tests for Yog.Multi.Model module.

  Multi-graphs allow multiple parallel edges between the same pair of nodes,
  which is essential for modeling networks with multiple connections.
  """

  use ExUnit.Case

  doctest Yog.Multi.Model

  alias Yog.Multi.Model

  # ============================================================
  # Construction Tests
  # ============================================================

  describe "construction" do
    test "new/1 creates directed multigraph" do
      graph = Model.new(:directed)
      assert graph.kind == :directed
      assert graph.nodes == %{}
      assert graph.edges == %{}
      assert graph.next_edge_id == 0
    end

    test "new/1 creates undirected multigraph" do
      graph = Model.new(:undirected)
      assert graph.kind == :undirected
      assert graph.nodes == %{}
      assert graph.edges == %{}
    end

    test "directed/0 convenience constructor" do
      graph = Model.directed()
      assert graph.kind == :directed
    end

    test "undirected/0 convenience constructor" do
      graph = Model.undirected()
      assert graph.kind == :undirected
    end
  end

  # ============================================================
  # Node Operations Tests
  # ============================================================

  describe "node operations" do
    test "add_node/3 adds node with data" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")

      assert graph.nodes == %{1 => "A", 2 => "B"}
    end

    test "add_node/3 replaces existing node data" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(1, "Updated")

      assert graph.nodes[1] == "Updated"
    end

    test "add_node/3 preserves edges when replacing data" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      graph = Model.add_node(graph, 1, "Updated")

      # Edges should still exist
      assert Model.edges_between(graph, 1, 2) != []
    end

    test "all_nodes/1 returns all node IDs" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")

      nodes = Model.all_nodes(graph)
      assert length(nodes) == 3
      assert 1 in nodes
      assert 2 in nodes
      assert 3 in nodes
    end

    test "order/1 returns node count" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")

      assert Model.order(graph) == 2
    end

    test "order/1 returns 0 for empty graph" do
      assert Model.order(Model.directed()) == 0
    end

    test "remove_node/2 removes isolated node" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.remove_node(1)

      assert Model.all_nodes(graph) == [2]
    end

    test "remove_node/2 removes all connected edges" do
      # Build graph and track all edge IDs properly
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")
        |> Model.add_edge(1, 2, 10)

      {graph, e2} = Model.add_edge(graph, 2, 3, 20)
      {graph, _e3} = Model.add_edge(graph, 1, 3, 30)

      # All edges exist
      assert Model.has_edge(graph, e1)
      assert Model.has_edge(graph, e2)

      graph = Model.remove_node(graph, 2)

      # Node 2 removed
      nodes = Model.all_nodes(graph)
      assert length(nodes) == 2
      refute 2 in nodes

      # Edges involving node 2 should be gone
      refute Model.has_edge(graph, e1)
      refute Model.has_edge(graph, e2)
    end
  end

  # ============================================================
  # Edge Operations Tests (Parallel Edges)
  # ============================================================

  describe "edge operations" do
    test "add_edge/4 creates single edge" do
      {graph, edge_id} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      assert edge_id == 0
      assert graph.edges[0] == {1, 2, 10}
    end

    test "add_edge/4 assigns incrementing edge IDs" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {graph, e2} = Model.add_edge(graph, 1, 2, 20)
      {_graph, e3} = Model.add_edge(graph, 2, 1, 30)

      assert e1 == 0
      assert e2 == 1
      assert e3 == 2
    end

    test "add_edge/4 creates parallel edges between same nodes" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, "first")

      {_graph, e2} = Model.add_edge(graph, 1, 2, "second")

      assert e1 != e2
    end

    test "remove_edge/2 removes specific edge by ID" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, "first")

      {graph, e2} = Model.add_edge(graph, 1, 2, "second")

      graph = Model.remove_edge(graph, e1)

      # e1 should be gone
      refute Model.has_edge(graph, e1)

      # e2 should remain
      assert Model.has_edge(graph, e2)
    end

    test "has_edge/2 checks edge existence" do
      {graph, edge_id} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      assert Model.has_edge(graph, edge_id)
      refute Model.has_edge(graph, 999)
    end

    test "all_edge_ids/1 returns all edge IDs" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {graph, e2} = Model.add_edge(graph, 1, 2, 20)
      {graph, e3} = Model.add_edge(graph, 2, 1, 30)

      edge_ids = Model.all_edge_ids(graph)
      assert length(edge_ids) == 3
      assert e1 in edge_ids
      assert e2 in edge_ids
      assert e3 in edge_ids
    end

    test "size/1 returns edge count" do
      {graph, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {graph, _e2} = Model.add_edge(graph, 1, 2, 20)

      assert Model.size(graph) == 2
    end

    test "edges_between/3 returns parallel edges" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, "first")

      {graph, e2} = Model.add_edge(graph, 1, 2, "second")

      edges = Model.edges_between(graph, 1, 2)
      assert length(edges) == 2
      assert {e1, "first"} in edges
      assert {e2, "second"} in edges
    end

    test "edges_between/3 returns empty when no edges" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")

      assert Model.edges_between(graph, 1, 2) == []
    end
  end

  # ============================================================
  # Undirected Graph Edge Tests
  # ============================================================

  describe "undirected graph edges" do
    test "add_edge/4 indexes reverse direction for undirected" do
      {graph, edge_id} =
        Model.undirected()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      # Both directions should be indexed
      out_edges = Map.get(graph.out_edge_ids, 1, [])

      # For undirected, successors of 1 should include 2
      assert edge_id in out_edges

      # And 2 should also have this edge in its outgoing
      assert edge_id in Map.get(graph.out_edge_ids, 2, [])
    end

    test "remove_edge/2 removes both directions for undirected" do
      {graph, edge_id} =
        Model.undirected()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      graph = Model.remove_edge(graph, edge_id)

      refute Model.has_edge(graph, edge_id)
    end
  end

  # ============================================================
  # Successors and Predecessors Tests
  # ============================================================

  describe "successors and predecessors" do
    test "successors/2 returns outgoing edges" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")
        |> Model.add_edge(1, 2, 10)

      {graph, e2} = Model.add_edge(graph, 1, 3, 20)

      succs = Model.successors(graph, 1)
      assert length(succs) == 2
      assert {2, e1, 10} in succs
      assert {3, e2, 20} in succs
    end

    test "predecessors/2 returns incoming edges" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")
        |> Model.add_edge(2, 1, 10)

      {graph, e2} = Model.add_edge(graph, 3, 1, 20)

      preds = Model.predecessors(graph, 1)
      assert length(preds) == 2
      assert {2, e1, 10} in preds
      assert {3, e2, 20} in preds
    end

    test "out_degree/2 counts outgoing edges" do
      {graph, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")
        |> Model.add_edge(1, 2, 10)

      {graph, _e2} = Model.add_edge(graph, 1, 3, 20)

      assert Model.out_degree(graph, 1) == 2
      assert Model.out_degree(graph, 2) == 0
    end

    test "in_degree/2 counts incoming edges" do
      {graph, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")
        |> Model.add_edge(2, 1, 10)

      {graph, _e2} = Model.add_edge(graph, 3, 1, 20)

      assert Model.in_degree(graph, 1) == 2
      assert Model.in_degree(graph, 2) == 0
    end
  end

  # ============================================================
  # Conversion Tests
  # ============================================================

  describe "conversion to simple graph" do
    test "to_simple_graph/2 returns a valid simple graph structure" do
      {multi, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {multi, _e2} = Model.add_edge(multi, 1, 2, 20)

      simple = Model.to_simple_graph(multi, &min/2)

      # Verify the result is a valid graph structure
      assert simple.__struct__ == Yog.Graph
      assert simple.kind == :directed
    end

    test "to_simple_graph_min_edges/1 returns a valid graph" do
      {multi, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {multi, _e2} = Model.add_edge(multi, 1, 2, 20)

      simple = Model.to_simple_graph_min_edges(multi)

      assert simple.__struct__ == Yog.Graph
      assert simple.kind == :directed
    end

    test "to_simple_graph_sum_edges/2 returns a valid graph" do
      {multi, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {multi, _e2} = Model.add_edge(multi, 1, 2, 20)

      simple = Model.to_simple_graph_sum_edges(multi, &Kernel.+/2)

      assert simple.__struct__ == Yog.Graph
      assert simple.kind == :directed
    end
  end

  # ============================================================
  # Complex Scenarios
  # ============================================================

  describe "complex scenarios" do
    test "parallel edges with different weights" do
      # Build multigraph with multiple edges between same nodes
      {multi, e1} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_edge(:a, :b, 100)

      {multi, e2} = Model.add_edge(multi, :a, :b, 200)
      {multi, e3} = Model.add_edge(multi, :a, :b, 50)

      edges = Model.edges_between(multi, :a, :b)
      assert length(edges) == 3

      weights = Enum.map(edges, &elem(&1, 1))
      assert 100 in weights
      assert 200 in weights
      assert 50 in weights

      # Verify all edge IDs are unique
      edge_ids = Enum.map(edges, &elem(&1, 0))
      assert e1 in edge_ids
      assert e2 in edge_ids
      assert e3 in edge_ids
    end

    test "remove_node/2 handles self-loops correctly" do
      {multi, e1} =
        Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_edge(1, 1, 10)

      assert Yog.Multi.Model.has_edge(multi, e1)

      multi = Yog.Multi.Model.remove_node(multi, 1)
      refute Yog.Multi.Model.has_edge(multi, e1)
      assert Yog.Multi.Model.all_nodes(multi) == []
    end

    test "map conversion (from_map/to_map)" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 10)

      map = Yog.Multi.Model.to_map(multi)
      assert map.kind == :directed
      assert map.nodes[1] == "A"

      multi2 = Yog.Multi.Model.from_map(map)
      assert multi2.kind == :directed
      assert multi2.nodes[1] == "A"
      assert Yog.Multi.Model.size(multi2) == 1
    end

    test "mixed parallel and single edges" do
      {multi, _e1} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {multi, _e2} = Model.add_edge(multi, :a, :b, 2)
      {multi, _e3} = Model.add_edge(multi, :b, :c, 3)

      # a->b has 2 edges, b->c has 1 edge
      assert length(Model.edges_between(multi, :a, :b)) == 2
      assert length(Model.edges_between(multi, :b, :c)) == 1
      assert Model.edges_between(multi, :a, :c) == []
    end
  end
end
