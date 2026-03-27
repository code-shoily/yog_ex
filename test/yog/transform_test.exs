defmodule Yog.TransformTest do
  use ExUnit.Case

  doctest Yog.Transform

  # ============= Transpose Tests =============

  test "transpose_empty_graph_test" do
    graph = Yog.directed()
    transposed = Yog.Transform.transpose(graph)

    assert transposed.out_edges == %{}
    assert transposed.in_edges == %{}
  end

  test "transpose_single_edge_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    transposed = Yog.Transform.transpose(graph)

    assert Yog.successors(transposed, 2) == [{1, 10}]
    assert Yog.successors(transposed, 1) == []
    assert Yog.predecessors(transposed, 1) == [{2, 10}]
  end

  test "transpose_multiple_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)
      |> Yog.add_edge!(from: 1, to: 3, with: 30)

    transposed = Yog.Transform.transpose(graph)

    assert Yog.successors(transposed, 2) == [{1, 10}]

    succ_3 = Yog.successors(transposed, 3)
    assert length(succ_3) == 2
    assert {2, 20} in succ_3
    assert {1, 30} in succ_3
  end

  test "transpose_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 2)
      |> Yog.add_edge!(from: 3, to: 1, with: 3)

    transposed = Yog.Transform.transpose(graph)

    assert Yog.successors(transposed, 1) == [{3, 3}]
    assert Yog.successors(transposed, 3) == [{2, 2}]
    assert Yog.successors(transposed, 2) == [{1, 1}]
  end

  test "transpose_twice_is_identity_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    double_transposed =
      graph
      |> Yog.Transform.transpose()
      |> Yog.Transform.transpose()

    assert Yog.successors(double_transposed, 1) == Yog.successors(graph, 1)
    assert Yog.successors(double_transposed, 2) == Yog.successors(graph, 2)
  end

  test "transpose_preserves_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    transposed = Yog.Transform.transpose(graph)

    assert transposed.nodes == graph.nodes
  end

  # ============= Map Nodes Tests =============

  test "map_nodes_empty_graph_test" do
    graph = Yog.directed()
    mapped = Yog.Transform.map_nodes(graph, &String.upcase/1)

    assert mapped.nodes == %{}
  end

  test "map_nodes_transforms_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "alice")
      |> Yog.add_node(2, "bob")
      |> Yog.add_node(3, "carol")

    mapped = Yog.Transform.map_nodes(graph, &String.upcase/1)
    nodes = mapped.nodes

    assert Map.get(nodes, 1) == "ALICE"
    assert Map.get(nodes, 2) == "BOB"
    assert Map.get(nodes, 3) == "CAROL"
  end

  test "map_nodes_preserves_structure_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_nodes(graph, fn s -> s <> "!" end)

    assert Yog.successors(mapped, 1) == [{2, 10}]
    assert mapped.kind == :directed
  end

  test "map_nodes_with_type_change_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "5")
      |> Yog.add_node(2, "10")
      |> Yog.add_node(3, "15")

    mapped = Yog.Transform.map_nodes(graph, fn s -> String.to_integer(s) end)
    nodes = mapped.nodes

    assert Map.get(nodes, 1) == 5
    assert Map.get(nodes, 2) == 10
  end

  test "map_nodes_functor_composition_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 1)
      |> Yog.add_node(2, 2)

    composed =
      graph
      |> Yog.Transform.map_nodes(fn x -> x * 2 end)
      |> Yog.Transform.map_nodes(fn x -> x + 1 end)

    direct =
      graph
      |> Yog.Transform.map_nodes(fn x -> x * 2 + 1 end)

    assert composed.nodes == direct.nodes
  end

  # ============= Map Edges Tests =============

  test "map_edges_empty_graph_test" do
    graph = Yog.directed()
    mapped = Yog.Transform.map_edges(graph, fn x -> x * 2 end)

    assert mapped.out_edges == %{}
    assert mapped.in_edges == %{}
  end

  test "map_edges_transforms_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)
      |> Yog.add_edge!(from: 1, to: 3, with: 30)

    mapped = Yog.Transform.map_edges(graph, fn w -> w * 2 end)

    assert Yog.successors(mapped, 1) |> List.keyfind!(2, 0) |> elem(1) == 20
    assert Yog.successors(mapped, 2) == [{3, 40}]
    assert Yog.successors(mapped, 1) |> List.keyfind!(3, 0) |> elem(1) == 60
  end

  test "map_edges_preserves_structure_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_edges(graph, fn w -> w + 5 end)

    assert mapped.nodes == graph.nodes
    assert mapped.kind == :directed
    assert Yog.successors(mapped, 1) == [{2, 15}]
  end

  test "map_edges_with_type_change_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_edges(graph, fn w -> w * 1.0 end)

    assert Yog.successors(mapped, 1) == [{2, 10.0}]
  end

  test "map_edges_undirected_graph_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)

    mapped = Yog.Transform.map_edges(graph, fn w -> w * 3 end)

    assert Yog.successors(mapped, 1) == [{2, 15}]
    assert Yog.successors(mapped, 2) == [{1, 15}]
  end

  test "map_edges_functor_composition_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    composed =
      graph
      |> Yog.Transform.map_edges(fn x -> x * 2 end)
      |> Yog.Transform.map_edges(fn x -> x + 5 end)

    direct =
      graph
      |> Yog.Transform.map_edges(fn x -> x * 2 + 5 end)

    assert Yog.successors(composed, 1) == Yog.successors(direct, 1)
  end

  # ============= Map Nodes Async Tests =============

  test "map_nodes_async_empty_graph_test" do
    graph = Yog.directed()
    mapped = Yog.Transform.map_nodes_async(graph, &String.upcase/1)

    assert mapped.nodes == %{}
  end

  test "map_nodes_async_transforms_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "alice")
      |> Yog.add_node(2, "bob")
      |> Yog.add_node(3, "carol")

    mapped = Yog.Transform.map_nodes_async(graph, &String.upcase/1)
    nodes = mapped.nodes

    assert Map.get(nodes, 1) == "ALICE"
    assert Map.get(nodes, 2) == "BOB"
    assert Map.get(nodes, 3) == "CAROL"
  end

  test "map_nodes_async_preserves_structure_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_nodes_async(graph, fn s -> s <> "!" end)

    assert Yog.successors(mapped, 1) == [{2, 10}]
    assert mapped.kind == :directed
  end

  test "map_nodes_async_with_options_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "test")
      |> Yog.add_node(2, "data")

    opts = [max_concurrency: 2, timeout: 10_000, ordered: true]
    mapped = Yog.Transform.map_nodes_async(graph, &String.upcase/1, opts)

    assert mapped.nodes[1] == "TEST"
    assert mapped.nodes[2] == "DATA"
  end

  test "map_nodes_async_matches_sync_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 5)
      |> Yog.add_node(2, 10)
      |> Yog.add_node(3, 15)

    transform = fn x -> x * 2 + 1 end

    sync_result = Yog.Transform.map_nodes(graph, transform)
    async_result = Yog.Transform.map_nodes_async(graph, transform)

    assert sync_result.nodes == async_result.nodes
  end

  test "map_nodes_async_large_graph_test" do
    # Build a larger graph to test parallelism
    graph =
      Enum.reduce(1..100, Yog.directed(), fn i, g ->
        Yog.add_node(g, i, i)
      end)

    mapped = Yog.Transform.map_nodes_async(graph, fn x -> x * 2 end)

    assert map_size(mapped.nodes) == 100
    assert mapped.nodes[1] == 2
    assert mapped.nodes[50] == 100
    assert mapped.nodes[100] == 200
  end

  # ============= Map Edges Async Tests =============

  test "map_edges_async_empty_graph_test" do
    graph = Yog.directed()
    mapped = Yog.Transform.map_edges_async(graph, fn x -> x * 2 end)

    assert mapped.out_edges == %{}
    assert mapped.in_edges == %{}
  end

  test "map_edges_async_transforms_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)
      |> Yog.add_edge!(from: 1, to: 3, with: 30)

    mapped = Yog.Transform.map_edges_async(graph, fn w -> w * 2 end)

    assert Yog.successors(mapped, 1) |> List.keyfind!(2, 0) |> elem(1) == 20
    assert Yog.successors(mapped, 2) == [{3, 40}]
    assert Yog.successors(mapped, 1) |> List.keyfind!(3, 0) |> elem(1) == 60
  end

  test "map_edges_async_preserves_structure_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_edges_async(graph, fn w -> w + 5 end)

    assert mapped.nodes == graph.nodes
    assert mapped.kind == :directed
    assert Yog.successors(mapped, 1) == [{2, 15}]
  end

  test "map_edges_async_with_options_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)

    opts = [max_concurrency: 4, timeout: 10_000, ordered: true]
    mapped = Yog.Transform.map_edges_async(graph, fn w -> w * 3 end, opts)

    assert Yog.successors(mapped, 1) == [{2, 15}]
  end

  test "map_edges_async_matches_sync_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    transform = fn w -> w * 2 + 3 end

    sync_result = Yog.Transform.map_edges(graph, transform)
    async_result = Yog.Transform.map_edges_async(graph, transform)

    assert Yog.successors(sync_result, 1) == Yog.successors(async_result, 1)
    assert Yog.successors(sync_result, 2) == Yog.successors(async_result, 2)
  end

  test "map_edges_async_undirected_graph_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)

    mapped = Yog.Transform.map_edges_async(graph, fn w -> w * 3 end)

    assert Yog.successors(mapped, 1) == [{2, 15}]
    assert Yog.successors(mapped, 2) == [{1, 15}]
  end

  test "map_edges_async_large_graph_test" do
    # Build a larger graph with many edges
    graph =
      Enum.reduce(1..100, Yog.directed(), fn i, g ->
        Yog.add_node(g, i, "node_#{i}")
      end)

    # Add edges
    graph =
      Enum.reduce(1..99, graph, fn i, g ->
        Yog.add_edge!(g, from: i, to: i + 1, with: i)
      end)

    mapped = Yog.Transform.map_edges_async(graph, fn w -> w * 2 end)

    assert Yog.successors(mapped, 1) == [{2, 2}]
    assert Yog.successors(mapped, 50) == [{51, 100}]
  end

  # ============= Filter Nodes Tests =============

  test "filter_nodes_empty_graph_test" do
    graph = Yog.directed()
    filtered = Yog.Transform.filter_nodes(graph, fn _ -> true end)

    assert filtered.nodes == %{}
  end

  test "filter_nodes_keep_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    filtered = Yog.Transform.filter_nodes(graph, fn _ -> true end)

    assert map_size(filtered.nodes) == 2
    assert Yog.successors(filtered, 1) == [{2, 10}]
  end

  test "filter_nodes_remove_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    filtered = Yog.Transform.filter_nodes(graph, fn _ -> false end)

    assert map_size(filtered.nodes) == 0
    assert map_size(filtered.out_edges) == 0
  end

  test "filter_nodes_by_predicate_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "apple")
      |> Yog.add_node(2, "banana")
      |> Yog.add_node(3, "apricot")
      |> Yog.add_node(4, "cherry")

    filtered = Yog.Transform.filter_nodes(graph, fn s -> String.starts_with?(s, "a") end)
    nodes = filtered.nodes

    assert map_size(nodes) == 2
    assert Map.has_key?(nodes, 1)
    assert Map.has_key?(nodes, 3)
    refute Map.has_key?(nodes, 2)
  end

  test "filter_nodes_prunes_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "keep")
      |> Yog.add_node(2, "remove")
      |> Yog.add_node(3, "keep")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)
      |> Yog.add_edge!(from: 1, to: 3, with: 30)

    filtered = Yog.Transform.filter_nodes(graph, fn s -> s == "keep" end)

    assert map_size(filtered.nodes) == 2
    assert Yog.successors(filtered, 1) == [{3, 30}]
    assert Yog.successors(filtered, 3) == []
  end

  test "filter_nodes_complex_pruning_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 1)
      |> Yog.add_node(2, 2)
      |> Yog.add_node(3, 3)
      |> Yog.add_node(4, 4)
      |> Yog.add_edge!(from: 1, to: 2, with: "a")
      |> Yog.add_edge!(from: 2, to: 3, with: "b")
      |> Yog.add_edge!(from: 3, to: 4, with: "c")
      |> Yog.add_edge!(from: 1, to: 4, with: "d")

    filtered = Yog.Transform.filter_nodes(graph, fn n -> rem(n, 2) == 0 end)

    assert map_size(filtered.nodes) == 2
    assert Yog.successors(filtered, 2) == []
    assert Yog.successors(filtered, 4) == []
  end

  test "filter_nodes_preserves_graph_type_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    filtered = Yog.Transform.filter_nodes(graph, fn _ -> true end)

    assert filtered.kind == :undirected
  end

  # ============= Merge Tests =============

  test "merge_empty_graphs_test" do
    g1 = Yog.directed()
    g2 = Yog.directed()

    merged = Yog.Transform.merge(g1, g2)

    assert map_size(merged.nodes) == 0
  end

  test "merge_with_empty_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    g2 = Yog.directed()

    merged = Yog.Transform.merge(g1, g2)

    assert Map.get(merged.nodes, 1) == "A"
  end

  test "merge_disjoint_graphs_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 3, to: 4, with: 20)

    merged = Yog.Transform.merge(g1, g2)

    assert map_size(merged.nodes) == 4
    assert Yog.successors(merged, 1) == [{2, 10}]
    assert Yog.successors(merged, 3) == [{4, 20}]
  end

  test "merge_overlapping_nodes_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "Original")
      |> Yog.add_node(2, "B")

    g2 =
      Yog.directed()
      |> Yog.add_node(1, "Updated")
      |> Yog.add_node(3, "C")

    merged = Yog.Transform.merge(g1, g2)

    assert Map.get(merged.nodes, 1) == "Updated"
    assert map_size(merged.nodes) == 3
  end

  test "merge_overlapping_edges_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 20)

    merged = Yog.Transform.merge(g1, g2)

    assert Yog.successors(merged, 1) == [{2, 20}]
  end

  test "merge_combines_edges_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    merged = Yog.Transform.merge(g1, g2)

    assert Yog.successors(merged, 1) == [{2, 10}]
    assert Yog.successors(merged, 2) == [{3, 20}]
  end

  test "merge_preserves_base_graph_type_test" do
    g1 = Yog.directed()
    g2 = Yog.directed()

    merged = Yog.Transform.merge(g1, g2)

    assert merged.kind == :directed
  end

  test "merge_combines_edges_from_same_node_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 1, to: 3, with: 15)

    g2 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge!(from: 1, to: 4, with: 20)
      |> Yog.add_edge!(from: 1, to: 5, with: 25)

    merged = Yog.Transform.merge(g1, g2)
    edges = Yog.successors(merged, 1)

    assert length(edges) == 4
    assert {2, 10} in edges
    assert {3, 15} in edges
    assert {4, 20} in edges
    assert {5, 25} in edges
  end

  # ============= Combined Operations Tests =============

  test "map_then_filter_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 5)
      |> Yog.add_node(2, 10)
      |> Yog.add_node(3, 15)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 2)

    result =
      graph
      |> Yog.Transform.map_nodes(fn x -> x * 2 end)
      |> Yog.Transform.filter_nodes(fn x -> x > 20 end)

    nodes = result.nodes
    assert map_size(nodes) == 1
    assert Map.get(nodes, 3) == 30
  end

  test "transpose_preserves_edge_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 42)

    transposed = Yog.Transform.transpose(graph)

    assert Yog.successors(transposed, 2) == [{1, 42}]
  end

  test "merge_then_map_edges_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    result =
      Yog.Transform.merge(g1, g2)
      |> Yog.Transform.map_edges(fn w -> w / 10 end)

    assert Yog.successors(result, 1) == [{2, 1.0}]
    assert Yog.successors(result, 2) == [{3, 2.0}]
  end

  # ============= Subgraph Tests =============

  test "subgraph_empty_list_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    sub = Yog.Transform.subgraph(graph, [])

    assert map_size(sub.nodes) == 0
    assert map_size(sub.out_edges) == 0
  end

  test "subgraph_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    sub = Yog.Transform.subgraph(graph, [2])

    assert map_size(sub.nodes) == 1
    assert Map.get(sub.nodes, 2) == "B"
    assert Yog.successors(sub, 2) == []
  end

  test "subgraph_two_connected_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    sub = Yog.Transform.subgraph(graph, [2, 3])

    assert map_size(sub.nodes) == 2
    assert Yog.successors(sub, 2) == [{3, 20}]
    assert Yog.predecessors(sub, 2) == []
  end

  test "subgraph_all_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    sub = Yog.Transform.subgraph(graph, [1, 2, 3])

    assert map_size(sub.nodes) == 3
    assert Yog.successors(sub, 1) == [{2, 10}]
    assert Yog.successors(sub, 2) == [{3, 20}]
  end

  test "subgraph_removes_edges_outside_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)
      |> Yog.add_edge!(from: 3, to: 4, with: 30)

    sub = Yog.Transform.subgraph(graph, [2, 3])

    assert map_size(sub.nodes) == 2
    assert Yog.successors(sub, 2) == [{3, 20}]
    assert Yog.successors(sub, 3) == []
  end

  # ============= Filter Edges Tests =============

  test "filter_edges_by_weight_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)
      |> Yog.add_edge!(from: 1, to: 3, with: 5)

    filtered = Yog.Transform.filter_edges(graph, fn _u, _v, weight -> weight >= 10 end)
    assert Yog.successors(filtered, 1) == [{2, 10}]
    assert Yog.successors(filtered, 2) == [{3, 20}]
  end

  test "filter_edges_remove_self_loops_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 1, with: 10)
      |> Yog.add_edge!(from: 1, to: 2, with: 20)

    filtered = Yog.Transform.filter_edges(graph, fn u, v, _w -> u != v end)
    assert Yog.successors(filtered, 1) == [{2, 20}]
  end

  test "filter_edges_empty_graph_test" do
    graph = Yog.directed()
    filtered = Yog.Transform.filter_edges(graph, fn _, _, _ -> true end)
    assert filtered.out_edges == %{}
  end

  test "filter_edges_keep_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    filtered = Yog.Transform.filter_edges(graph, fn _, _, _ -> true end)
    assert Yog.successors(filtered, 1) == [{2, 10}]
  end

  test "filter_edges_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    filtered = Yog.Transform.filter_edges(graph, fn _u, _v, w -> w > 5 end)
    assert Yog.successors(filtered, 1) == [{2, 10}]
    assert Yog.successors(filtered, 2) == [{1, 10}]
  end

  # ============= Complement Tests =============

  test "complement_triangle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    comp = Yog.Transform.complement(graph, 100)
    assert Yog.successors(comp, 1) == [{3, 100}]
    assert Yog.successors(comp, 2) == [{3, 100}]
    assert Enum.sort(Yog.successors(comp, 3)) == [{1, 100}, {2, 100}]
  end

  test "complement_path_graph_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    comp = Yog.Transform.complement(graph, 5)
    assert Yog.successors(comp, 1) == [{3, 5}, {4, 5}]
    assert Yog.successors(comp, 2) == [{4, 5}]
  end

  test "complement_directed_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    comp = Yog.Transform.complement(graph, 9)
    # A complete directed graph on 3 nodes has 6 edges. We added 1. Result should have 5 edges.
    assert Enum.sort(Yog.successors(comp, 1)) == [{3, 9}]
    assert Enum.sort(Yog.successors(comp, 2)) == [{1, 9}, {3, 9}]
    assert Enum.sort(Yog.successors(comp, 3)) == [{1, 9}, {2, 9}]
  end

  test "complement_preserves_nodes_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
    comp = Yog.Transform.complement(graph, 0)
    assert Map.fetch(comp.nodes, 1) == {:ok, "A"}
    assert Map.fetch(comp.nodes, 2) == {:ok, "B"}
  end

  # ============= Directional Conversion Tests =============

  test "to_directed_changes_kind_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    dir_graph = Yog.Transform.to_directed(graph)
    assert dir_graph.kind == :directed
    assert Yog.successors(dir_graph, 1) == [{2, 10}]
    assert Yog.successors(dir_graph, 2) == [{1, 10}]
  end

  test "to_directed_already_directed_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    dir_graph = Yog.Transform.to_directed(graph)
    assert dir_graph.kind == :directed
    assert Yog.successors(dir_graph, 1) == [{2, 10}]
    assert Yog.successors(dir_graph, 2) == []
  end

  test "to_undirected_mirrors_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    undir_graph = Yog.Transform.to_undirected(graph, fn a, _b -> a end)
    assert undir_graph.kind == :undirected
    assert Yog.successors(undir_graph, 1) == [{2, 10}]
    assert Yog.successors(undir_graph, 2) == [{1, 10}]
  end

  test "to_undirected_resolves_conflicts_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 1, with: 20)

    # Prefer max weight
    undir_graph = Yog.Transform.to_undirected(graph, &max/2)
    assert Yog.successors(undir_graph, 1) == [{2, 20}]
    assert Yog.successors(undir_graph, 2) == [{1, 20}]
  end

  test "to_undirected_already_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    undir_graph = Yog.Transform.to_undirected(graph, &max/2)
    assert undir_graph.kind == :undirected
    assert Yog.successors(undir_graph, 1) == [{2, 10}]
    assert Yog.successors(undir_graph, 2) == [{1, 10}]
  end

  test "to_directed_then_to_undirected_roundtrip_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    roundtrip = graph |> Yog.Transform.to_directed() |> Yog.Transform.to_undirected(&max/2)
    assert roundtrip.kind == :undirected
    assert Yog.successors(roundtrip, 1) == [{2, 10}]
    assert Yog.successors(roundtrip, 2) == [{1, 10}]
  end

  # ============= Contract Operations Tests =============

  test "contract_simple_directed_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    contracted =
      Yog.Transform.contract(graph, 1, 2, fn w1, w2 -> w1 + w2 end)

    assert Map.fetch(contracted.nodes, 1) == {:ok, "A"}
    assert Map.fetch(contracted.nodes, 2) == :error
    assert Yog.successors(contracted, 1) == [{3, 20}]
  end

  test "contract_combining_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 3, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 20)

    contracted =
      Yog.Transform.contract(graph, 1, 2, fn w1, w2 -> w1 + w2 end)

    assert Yog.successors(contracted, 1) == [{3, 30}]
  end

  test "contract_removes_self_loops_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 1, with: 20)

    contracted = Yog.Transform.contract(graph, 1, 2, fn w, _ -> w end)

    # The edges between 1 and 2 become self-loops on 1. Yog does not retain these upon contraction.
    assert Yog.successors(contracted, 1) == []
  end

  test "contract_isolated_nodes_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B") |> Yog.add_node(3, "C")

    contracted =
      Yog.Transform.contract(graph, 1, 2, fn w, _ -> w end)

    assert Map.fetch(contracted.nodes, 1) == {:ok, "A"}
    assert Map.fetch(contracted.nodes, 2) == :error
    assert Yog.successors(contracted, 1) == []
    assert map_size(contracted.nodes) == 2
  end

  # ============= Transitive Closure Tests =============

  # Helper to add multiple nodes
  defp add_nodes(graph, nodes) do
    Enum.reduce(nodes, graph, fn {id, data}, acc ->
      Yog.add_node(acc, id, data)
    end)
  end

  test "transitive_closure_dag_test" do
    # 1 -> 2 -> 3
    graph =
      Yog.directed()
      |> add_nodes([{1, nil}, {2, nil}, {3, nil}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

    closure = Yog.Transform.transitive_closure(graph)
    assert Yog.Model.has_edge?(closure, 1, 2)
    assert Yog.Model.has_edge?(closure, 2, 3)
    assert Yog.Model.has_edge?(closure, 1, 3)
  end

  test "transitive_closure_cyclic_test" do
    # 1 -> 2 -> 1 (cycle), 2 -> 3
    graph =
      Yog.directed()
      |> add_nodes([{1, nil}, {2, nil}, {3, nil}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}, {2, 3, 1}])

    closure = Yog.Transform.transitive_closure(graph)
    assert Yog.Model.has_edge?(closure, 1, 3)
    assert Yog.Model.has_edge?(closure, 2, 3)
    # Check that there are no edges from/to the wrong place
    # 3 has no outgoing edges
    assert Yog.Model.successor_ids(closure, 3) == []
  end

  test "transitive_closure_diamond_test" do
    # a -> b, a -> c, b -> d, c -> d
    graph =
      Yog.directed()
      |> add_nodes([{:a, nil}, {:b, nil}, {:c, nil}, {:d, nil}])
      |> Yog.add_edges!([{:a, :b, 1}, {:a, :c, 2}, {:b, :d, 3}, {:c, :d, 4}])

    closure = Yog.Transform.transitive_closure(graph)
    # a should have direct edge to all: b, c, d
    successors = Yog.Model.successor_ids(closure, :a)
    assert :b in successors
    assert :c in successors
    assert :d in successors
  end

  # ============= Transitive Reduction Tests =============

  test "transitive_reduction_dag_test" do
    # 1 -> 2, 2 -> 3, 1 -> 3 (redundant)
    graph =
      Yog.directed()
      |> add_nodes([{1, nil}, {2, nil}, {3, nil}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {1, 3, 1}])

    {:ok, reduction} = Yog.Transform.transitive_reduction(graph)
    assert Yog.Model.has_edge?(reduction, 1, 2)
    assert Yog.Model.has_edge?(reduction, 2, 3)
    # 1 -> 3 was correctly removed
    refute Yog.Model.has_edge?(reduction, 1, 3)
  end

  test "transitive_reduction_diamond_test" do
    # Diamond: a -> b, a -> c, b -> d, c -> d
    # No edges are redundant here.
    graph =
      Yog.directed()
      |> add_nodes([{:a, nil}, {:b, nil}, {:c, nil}, {:d, nil}])
      |> Yog.add_edges!([{:a, :b, 1}, {:a, :c, 2}, {:b, :d, 3}, {:c, :d, 4}])

    {:ok, reduction} = Yog.Transform.transitive_reduction(graph)
    assert Yog.Model.has_edge?(reduction, :a, :b)
    assert Yog.Model.has_edge?(reduction, :a, :c)
    assert Yog.Model.has_edge?(reduction, :b, :d)
    assert Yog.Model.has_edge?(reduction, :c, :d)
    assert Map.has_key?(reduction.out_edges, :a)
    assert Map.has_key?(reduction.out_edges, :b)
    assert Map.has_key?(reduction.out_edges, :c)
  end

  test "transitive_reduction_error_on_cycle_test" do
    graph =
      Yog.directed()
      |> add_nodes([{1, nil}, {2, nil}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}])

    assert {:error, :contains_cycle} = Yog.Transform.transitive_reduction(graph)
  end

  # ============= Update Tests =============

  test "update_node_existing_test" do
    graph = Yog.directed() |> Yog.add_node(1, 100)
    updated = Yog.Transform.update_node(graph, 1, 0, fn x -> x + 50 end)
    assert Yog.Model.node(updated, 1) == 150
  end

  test "update_node_missing_test" do
    graph = Yog.directed()
    updated = Yog.Transform.update_node(graph, 1, 5, fn x -> x + 5 end)
    assert Yog.Model.node(updated, 1) == 5
  end

  test "update_edge_directed_test" do
    {:ok, graph} =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(1, 2, 10)

    updated = Yog.Transform.update_edge(graph, 1, 2, 0, fn w -> w + 5 end)
    assert Yog.successors(updated, 1) == [{2, 15}]
    assert Yog.predecessors(updated, 2) == [{1, 15}]
  end

  test "update_edge_undirected_test" do
    {:ok, graph} =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(1, 2, 10)

    updated = Yog.Transform.update_edge(graph, 1, 2, 0, fn w -> w * 2 end)
    assert Yog.successors(updated, 1) == [{2, 20}]
    assert Yog.successors(updated, 2) == [{1, 20}]
  end

  test "update_edge_missing_node_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A")
    # Node 2 doesn't exist
    updated = Yog.Transform.update_edge(graph, 1, 2, 10, fn w -> w + 1 end)
    assert updated == graph
    refute Yog.Model.has_edge?(updated, 1, 2)
  end

  test "update_edge_self_loop_undirected_test" do
    {:ok, graph} =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_edge(1, 1, 5)

    updated = Yog.Transform.update_edge(graph, 1, 1, 0, fn w -> w + 1 end)
    assert Yog.successors(updated, 1) == [{1, 6}]
  end

  test "update_edge_adds_if_not_exists_but_nodes_exist_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
    updated = Yog.Transform.update_edge(graph, 1, 2, 10, fn w -> w + 5 end)
    assert Yog.successors(updated, 1) == [{2, 10}]
  end
end
