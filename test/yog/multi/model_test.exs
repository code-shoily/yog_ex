defmodule Yog.Multi.ModelTest do
  @moduledoc """
  Tests for Yog.Multi.Model module.

  Multi-graphs allow multiple parallel edges between the same pair of nodes,
  which is essential for modeling networks with multiple connections.
  """

  use ExUnit.Case
  use ExUnitProperties

  doctest Yog.Multi.Model

  alias Yog.Multi.Model

  # Helper function to assert internal index consistency for a multigraph
  defp assert_index_consistency(graph) do
    # 1. Size match
    assert Model.size(graph) == map_size(graph.edges)
    assert Model.order(graph) == map_size(graph.nodes)

    # 2. Every edge in edges has endpoints in nodes and is indexed in out_edge_ids and in_edge_ids
    Enum.each(graph.edges, fn {eid, {src, dst, _data}} ->
      assert Map.has_key?(graph.nodes, src), "Source node #{inspect(src)} missing from nodes"
      assert Map.has_key?(graph.nodes, dst), "Target node #{inspect(dst)} missing from nodes"

      out_set = Map.get(graph.out_edge_ids, src, MapSet.new())

      assert MapSet.member?(out_set, eid),
             "Edge #{eid} missing from out_edge_ids of #{inspect(src)}"

      in_set = Map.get(graph.in_edge_ids, dst, MapSet.new())

      assert MapSet.member?(in_set, eid),
             "Edge #{eid} missing from in_edge_ids of #{inspect(dst)}"

      if graph.kind == :undirected do
        rev_out = Map.get(graph.out_edge_ids, dst, MapSet.new())

        assert MapSet.member?(rev_out, eid),
               "Edge #{eid} missing from out_edge_ids of #{inspect(dst)} in undirected graph"

        rev_in = Map.get(graph.in_edge_ids, src, MapSet.new())

        assert MapSet.member?(rev_in, eid),
               "Edge #{eid} missing from in_edge_ids of #{inspect(src)} in undirected graph"
      end
    end)

    # 3. Every edge ID in out_edge_ids exists in edges
    Enum.each(graph.out_edge_ids, fn {node_id, set} ->
      assert Map.has_key?(graph.nodes, node_id)

      Enum.each(set, fn eid ->
        assert Map.has_key?(graph.edges, eid)
      end)
    end)

    # 4. Every edge ID in in_edge_ids exists in edges
    Enum.each(graph.in_edge_ids, fn {node_id, set} ->
      assert Map.has_key?(graph.nodes, node_id)

      Enum.each(set, fn eid ->
        assert Map.has_key?(graph.edges, eid)
      end)
    end)

    # 5. Handshake lemma for undirected graph
    if graph.kind == :undirected do
      sum_degrees =
        graph
        |> Model.all_nodes()
        |> Enum.map(&Model.degree(graph, &1))
        |> Enum.sum()

      assert sum_degrees == 2 * Model.size(graph)
    end
  end

  # ============================================================
  # Construction Tests
  # ============================================================

  describe "construction" do
    test "new/1 creates directed multigraph" do
      graph = Model.new(:directed)
      assert graph.kind == :directed
      assert Model.type(graph) == :directed
      assert Model.kind(graph) == :directed
      assert graph.nodes == %{}
      assert graph.edges == %{}
      assert graph.next_edge_id == 0
    end

    test "new/1 creates undirected multigraph" do
      graph = Model.new(:undirected)
      assert graph.kind == :undirected
      assert Model.type(graph) == :undirected
      assert graph.nodes == %{}
      assert graph.edges == %{}
    end

    test "new/1 raises on invalid graph type" do
      assert_raise ArgumentError, ~r/Invalid graph type/, fn ->
        apply(Model, :new, [:invalid])
      end
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
      assert Model.has_node?(graph, 1)
      assert Model.has_node?(graph, 2)
      refute Model.has_node?(graph, 3)

      assert Model.node(graph, 1) == "A"
      assert Model.node_data(graph, 1) == "A"
      assert Model.fetch_node(graph, 1) == {:ok, "A"}
      assert Model.fetch_node(graph, 99) == :error
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

      assert Model.edges_between(graph, 1, 2) != []
      assert_index_consistency(graph)
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

    test "order/1 and node_count/1 return node count" do
      graph =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")

      assert Model.order(graph) == 2
      assert Model.node_count(graph) == 2
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
      assert_index_consistency(graph)
    end

    test "remove_node/2 removes all connected edges and maintains index consistency" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_node(3, "C")
        |> Model.add_edge(1, 2, 10)

      {graph, e2} = Model.add_edge(graph, 2, 3, 20)
      {graph, e3} = Model.add_edge(graph, 1, 3, 30)

      assert Model.has_edge(graph, e1)
      assert Model.has_edge(graph, e2)
      assert Model.has_edge(graph, e3)

      graph = Model.remove_node(graph, 2)

      nodes = Model.all_nodes(graph)
      assert length(nodes) == 2
      refute 2 in nodes

      refute Model.has_edge(graph, e1)
      refute Model.has_edge(graph, e2)
      assert Model.has_edge(graph, e3)

      assert_index_consistency(graph)
    end

    test "remove_node/2 with non-existent node returns unchanged graph" do
      graph = Model.directed() |> Model.add_node(1, "A")
      updated = Model.remove_node(graph, 999)
      assert updated == graph
    end
  end

  # ============================================================
  # Edge Operations Tests
  # ============================================================

  describe "edge operations" do
    test "add_edge/4 creates single edge and auto-creates missing nodes" do
      {graph, edge_id} =
        Model.directed()
        |> Model.add_edge(1, 2, 10)

      assert edge_id == 0
      assert graph.edges[0] == {1, 2, 10}
      assert Model.has_node?(graph, 1)
      assert Model.has_node?(graph, 2)
      assert Model.edge(graph, 0) == {1, 2, 10}
      assert Model.edge_data(graph, 0) == 10
      assert Model.fetch_edge(graph, 0) == {:ok, {1, 2, 10}}
      assert Model.fetch_edge(graph, 99) == :error
      assert Model.has_edge?(graph, 0)
      refute Model.has_edge?(graph, 99)
      assert_index_consistency(graph)
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

      {graph, e2} = Model.add_edge(graph, 1, 2, "second")

      assert e1 != e2
      assert Model.edge_count(graph, 1, 2) == 2
      assert Model.has_edge_between?(graph, 1, 2)
      assert Model.has_edge_between(graph, 1, 2)
      refute Model.has_edge_between?(graph, 1, 3)
      assert_index_consistency(graph)
    end

    test "remove_edge/2 removes specific edge by ID" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, "first")

      {graph, e2} = Model.add_edge(graph, 1, 2, "second")

      graph = Model.remove_edge(graph, e1)

      refute Model.has_edge(graph, e1)
      assert Model.has_edge(graph, e2)
      assert_index_consistency(graph)
    end

    test "remove_edge/2 on non-existent edge ID returns graph unchanged" do
      graph = Model.directed() |> Model.add_node(1, "A")
      assert Model.remove_edge(graph, 999) == graph
    end

    test "all_edge_ids/1 and all_edges/1" do
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

      edges = Model.all_edges(graph)
      assert edges == [{0, 1, 2, 10}, {1, 1, 2, 20}, {2, 2, 1, 30}]
    end

    test "size/1 and edge_count/1 return edge count" do
      {graph, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {graph, _e2} = Model.add_edge(graph, 1, 2, 20)

      assert Model.size(graph) == 2
      assert Model.edge_count(graph) == 2
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

      out_edges = Map.get(graph.out_edge_ids, 1, [])
      assert edge_id in out_edges
      assert edge_id in Map.get(graph.out_edge_ids, 2, [])
      assert Model.has_edge_between?(graph, 1, 2)
      assert Model.has_edge_between?(graph, 2, 1)
      assert_index_consistency(graph)
    end

    test "remove_edge/2 removes both directions for undirected" do
      {graph, edge_id} =
        Model.undirected()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      graph = Model.remove_edge(graph, edge_id)

      refute Model.has_edge(graph, edge_id)
      assert_index_consistency(graph)
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

      assert simple.__struct__ == Yog.Graph
      assert simple.kind == :directed
    end

    test "to_simple_graph/2 raises on invalid combine_fn" do
      multi = Model.directed() |> Model.add_node(1, "A")

      assert_raise ArgumentError, ~r/expected combine_fn to be an arity-2 function/, fn ->
        apply(Model, :to_simple_graph, [multi, :invalid])
      end
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

    test "to_simple_graph_max_edges/1 returns a valid graph" do
      {multi, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {multi, _e2} = Model.add_edge(multi, 1, 2, 20)

      simple = Model.to_simple_graph_max_edges(multi)

      assert simple.__struct__ == Yog.Graph
      assert simple.kind == :directed
      assert Yog.Model.edge_data(simple, 1, 2) == 20
    end

    test "to_simple_graph_sum_edges/1 returns a valid graph" do
      {multi, _e1} =
        Model.directed()
        |> Model.add_node(1, "A")
        |> Model.add_node(2, "B")
        |> Model.add_edge(1, 2, 10)

      {multi, _e2} = Model.add_edge(multi, 1, 2, 20)

      simple = Model.to_simple_graph_sum_edges(multi)

      assert simple.__struct__ == Yog.Graph
      assert simple.kind == :directed
      assert Yog.Model.edge_data(simple, 1, 2) == 30
    end
  end

  # ============================================================
  # Struct Verification Errors
  # ============================================================

  describe "struct verification" do
    test "functions raise ArgumentError when given non-multigraph struct" do
      assert_raise ArgumentError, ~r/expected a Yog.Multi.Graph struct/, fn ->
        apply(Model, :type, [:not_a_graph])
      end

      assert_raise ArgumentError, ~r/expected a Yog.Multi.Graph struct/, fn ->
        apply(Model, :add_node, [:not_a_graph, 1, "A"])
      end

      assert_raise ArgumentError, ~r/expected a Yog.Multi.Graph struct/, fn ->
        apply(Model, :remove_node, [:not_a_graph, 1])
      end

      assert_raise ArgumentError, ~r/expected a Yog.Multi.Graph struct/, fn ->
        apply(Model, :add_edge, [:not_a_graph, 1, 2, "w"])
      end

      assert_raise ArgumentError, ~r/expected a Yog.Multi.Graph struct/, fn ->
        apply(Model, :remove_edge, [:not_a_graph, 0])
      end
    end
  end

  # ============================================================
  # Complex Scenarios
  # ============================================================

  describe "complex scenarios" do
    test "parallel edges with different weights" do
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

      edge_ids = Enum.map(edges, &elem(&1, 0))
      assert e1 in edge_ids
      assert e2 in edge_ids
      assert e3 in edge_ids
      assert_index_consistency(multi)
    end

    test "remove_node/2 handles self-loops correctly" do
      {multi, e1} =
        Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_edge(1, 1, 10)

      assert Yog.Multi.Model.has_edge(multi, e1)

      multi = Yog.Multi.Model.remove_node(multi, 1)
      refute Yog.Multi.Model.has_edge(multi, e1)
      assert Yog.Multi.Model.all_nodes(multi) == []
      assert_index_consistency(multi)
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
      assert_index_consistency(multi2)
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

      assert length(Model.edges_between(multi, :a, :b)) == 2
      assert length(Model.edges_between(multi, :b, :c)) == 1
      assert Model.edges_between(multi, :a, :c) == []
      assert_index_consistency(multi)
    end
  end

  # ============================================================
  # Self-Loop Degree Tests
  # ============================================================

  describe "self-loop degrees" do
    test "single undirected self-loop contributes 2 to degree" do
      {multi, _} =
        Model.undirected()
        |> Model.add_node(:u, nil)
        |> Model.add_edge(:u, :u, "loop")

      assert Model.degree(multi, :u) == 2
      assert Model.out_degree(multi, :u) == 2
      assert Model.in_degree(multi, :u) == 2
      assert_index_consistency(multi)
    end

    test "undirected self-loop plus regular edge" do
      {multi, _} =
        Model.undirected()
        |> Model.add_node(:u, nil)
        |> Model.add_node(:v, nil)
        |> Model.add_edge(:u, :u, "loop")

      {multi, _} = Model.add_edge(multi, :u, :v, "edge")

      assert Model.degree(multi, :u) == 3
      assert Model.degree(multi, :v) == 1
      assert_index_consistency(multi)
    end

    test "multiple undirected self-loops" do
      {multi, _} =
        Model.undirected()
        |> Model.add_node(:u, nil)
        |> Model.add_edge(:u, :u, "loop1")

      {multi, _} = Model.add_edge(multi, :u, :u, "loop2")

      assert Model.degree(multi, :u) == 4
      assert_index_consistency(multi)
    end

    test "directed self-loop contributes 1 to in-degree and 1 to out-degree" do
      {multi, _} =
        Model.directed()
        |> Model.add_node(:u, nil)
        |> Model.add_edge(:u, :u, "loop")

      assert Model.out_degree(multi, :u) == 1
      assert Model.in_degree(multi, :u) == 1
      assert Model.degree(multi, :u) == 2
      assert_index_consistency(multi)
    end

    test "handshake lemma holds for undirected multigraph with self-loops" do
      multi =
        Model.undirected()
        |> Model.add_node(:a, nil)
        |> Model.add_node(:b, nil)
        |> Model.add_node(:c, nil)
        |> then(fn g ->
          {g, _} = Model.add_edge(g, :a, :a, "loop")
          {g, _} = Model.add_edge(g, :a, :b, "e1")
          {g, _} = Model.add_edge(g, :b, :c, "e2")
          {g, _} = Model.add_edge(g, :c, :c, "loop2")
          g
        end)

      sum_deg =
        multi
        |> Model.all_nodes()
        |> Enum.map(&Model.degree(multi, &1))
        |> Enum.sum()

      assert sum_deg == 2 * Model.size(multi)
      assert_index_consistency(multi)
    end
  end

  # ============================================================
  # Property-Based Index Consistency Tests
  # ============================================================

  describe "property-based index consistency" do
    property "random sequence of multigraph operations maintains strict index consistency" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              ops <-
                StreamData.list_of(
                  StreamData.tuple({
                    StreamData.member_of([:add_node, :add_edge, :remove_edge, :remove_node]),
                    StreamData.integer(1..10),
                    StreamData.integer(1..10)
                  }),
                  min_length: 5,
                  max_length: 50
                )
            ) do
        graph =
          Enum.reduce(ops, Model.new(kind), fn
            {:add_node, u, _}, g ->
              Model.add_node(g, u, "data_#{u}")

            {:add_edge, u, v}, g ->
              {updated, _eid} = Model.add_edge(g, u, v, "edge_#{u}_#{v}")
              updated

            {:remove_edge, _u, _v}, g ->
              case Model.all_edge_ids(g) do
                [] -> g
                eids -> Model.remove_edge(g, hd(eids))
              end

            {:remove_node, u, _v}, g ->
              Model.remove_node(g, u)
          end)

        assert_index_consistency(graph)
      end
    end
  end
end
