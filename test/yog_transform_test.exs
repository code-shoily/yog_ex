defmodule YogTransformTest do
  use ExUnit.Case

  # ============= Transpose Tests =============

  test "transpose_empty_graph_test" do
    graph = Yog.directed()
    transposed = Yog.Transform.transpose(graph)

    assert transposed |> elem(3) == %{}
    assert transposed |> elem(4) == %{}
  end

  test "transpose_single_edge_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

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
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)
      |> Yog.add_edge(from: 1, to: 3, with: 30)

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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 1, with: 3)

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
      |> Yog.add_edge(from: 1, to: 2, with: 10)

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
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    transposed = Yog.Transform.transpose(graph)

    assert elem(transposed, 2) == elem(graph, 2)
  end

  # ============= Map Nodes Tests =============

  test "map_nodes_empty_graph_test" do
    graph = Yog.directed()
    mapped = Yog.Transform.map_nodes(graph, &String.upcase/1)

    assert elem(mapped, 2) == %{}
  end

  test "map_nodes_transforms_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "alice")
      |> Yog.add_node(2, "bob")
      |> Yog.add_node(3, "carol")

    mapped = Yog.Transform.map_nodes(graph, &String.upcase/1)
    nodes = elem(mapped, 2)

    assert Map.get(nodes, 1) == "ALICE"
    assert Map.get(nodes, 2) == "BOB"
    assert Map.get(nodes, 3) == "CAROL"
  end

  test "map_nodes_preserves_structure_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_nodes(graph, fn s -> s <> "!" end)

    assert Yog.successors(mapped, 1) == [{2, 10}]
    assert elem(mapped, 1) == :directed
  end

  test "map_nodes_with_type_change_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "5")
      |> Yog.add_node(2, "10")
      |> Yog.add_node(3, "15")

    mapped = Yog.Transform.map_nodes(graph, fn s -> String.to_integer(s) end)
    nodes = elem(mapped, 2)

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

    assert elem(composed, 2) == elem(direct, 2)
  end

  # ============= Map Edges Tests =============

  test "map_edges_empty_graph_test" do
    graph = Yog.directed()
    mapped = Yog.Transform.map_edges(graph, fn x -> x * 2 end)

    assert elem(mapped, 3) == %{}
    assert elem(mapped, 4) == %{}
  end

  test "map_edges_transforms_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)
      |> Yog.add_edge(from: 1, to: 3, with: 30)

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
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_edges(graph, fn w -> w + 5 end)

    assert elem(mapped, 2) == elem(graph, 2)
    assert elem(mapped, 1) == :directed
    assert Yog.successors(mapped, 1) == [{2, 15}]
  end

  test "map_edges_with_type_change_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    mapped = Yog.Transform.map_edges(graph, fn w -> w * 1.0 end)

    assert Yog.successors(mapped, 1) == [{2, 10.0}]
  end

  test "map_edges_undirected_graph_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 5)

    mapped = Yog.Transform.map_edges(graph, fn w -> w * 3 end)

    assert Yog.successors(mapped, 1) == [{2, 15}]
    assert Yog.successors(mapped, 2) == [{1, 15}]
  end

  test "map_edges_functor_composition_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    composed =
      graph
      |> Yog.Transform.map_edges(fn x -> x * 2 end)
      |> Yog.Transform.map_edges(fn x -> x + 5 end)

    direct =
      graph
      |> Yog.Transform.map_edges(fn x -> x * 2 + 5 end)

    assert Yog.successors(composed, 1) == Yog.successors(direct, 1)
  end

  # ============= Filter Nodes Tests =============

  test "filter_nodes_empty_graph_test" do
    graph = Yog.directed()
    filtered = Yog.Transform.filter_nodes(graph, fn _ -> true end)

    assert elem(filtered, 2) == %{}
  end

  test "filter_nodes_keep_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    filtered = Yog.Transform.filter_nodes(graph, fn _ -> true end)

    assert map_size(elem(filtered, 2)) == 2
    assert Yog.successors(filtered, 1) == [{2, 10}]
  end

  test "filter_nodes_remove_all_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    filtered = Yog.Transform.filter_nodes(graph, fn _ -> false end)

    assert map_size(elem(filtered, 2)) == 0
    assert map_size(elem(filtered, 3)) == 0
  end

  test "filter_nodes_by_predicate_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "apple")
      |> Yog.add_node(2, "banana")
      |> Yog.add_node(3, "apricot")
      |> Yog.add_node(4, "cherry")

    filtered = Yog.Transform.filter_nodes(graph, fn s -> String.starts_with?(s, "a") end)
    nodes = elem(filtered, 2)

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
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)
      |> Yog.add_edge(from: 1, to: 3, with: 30)

    filtered = Yog.Transform.filter_nodes(graph, fn s -> s == "keep" end)

    assert map_size(elem(filtered, 2)) == 2
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
      |> Yog.add_edge(from: 1, to: 2, with: "a")
      |> Yog.add_edge(from: 2, to: 3, with: "b")
      |> Yog.add_edge(from: 3, to: 4, with: "c")
      |> Yog.add_edge(from: 1, to: 4, with: "d")

    filtered = Yog.Transform.filter_nodes(graph, fn n -> rem(n, 2) == 0 end)

    assert map_size(elem(filtered, 2)) == 2
    assert Yog.successors(filtered, 2) == []
    assert Yog.successors(filtered, 4) == []
  end

  test "filter_nodes_preserves_graph_type_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    filtered = Yog.Transform.filter_nodes(graph, fn _ -> true end)

    assert elem(filtered, 1) == :undirected
  end

  # ============= Merge Tests =============

  test "merge_empty_graphs_test" do
    g1 = Yog.directed()
    g2 = Yog.directed()

    merged = Yog.Transform.merge(g1, g2)

    assert map_size(elem(merged, 2)) == 0
  end

  test "merge_with_empty_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    g2 = Yog.directed()

    merged = Yog.Transform.merge(g1, g2)

    assert Map.get(elem(merged, 2), 1) == "A"
  end

  test "merge_disjoint_graphs_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 3, to: 4, with: 20)

    merged = Yog.Transform.merge(g1, g2)

    assert map_size(elem(merged, 2)) == 4
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

    assert Map.get(elem(merged, 2), 1) == "Updated"
    assert map_size(elem(merged, 2)) == 3
  end

  test "merge_overlapping_edges_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 20)

    merged = Yog.Transform.merge(g1, g2)

    assert Yog.successors(merged, 1) == [{2, 20}]
  end

  test "merge_combines_edges_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 2, to: 3, with: 20)

    merged = Yog.Transform.merge(g1, g2)

    assert Yog.successors(merged, 1) == [{2, 10}]
    assert Yog.successors(merged, 2) == [{3, 20}]
  end

  test "merge_preserves_base_graph_type_test" do
    g1 = Yog.directed()
    g2 = Yog.directed()

    merged = Yog.Transform.merge(g1, g2)

    assert elem(merged, 1) == :directed
  end

  test "merge_combines_edges_from_same_node_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 1, to: 3, with: 15)

    g2 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge(from: 1, to: 4, with: 20)
      |> Yog.add_edge(from: 1, to: 5, with: 25)

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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)

    result =
      graph
      |> Yog.Transform.map_nodes(fn x -> x * 2 end)
      |> Yog.Transform.filter_nodes(fn x -> x > 20 end)

    nodes = elem(result, 2)
    assert map_size(nodes) == 1
    assert Map.get(nodes, 3) == 30
  end

  test "transpose_preserves_edge_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 42)

    transposed = Yog.Transform.transpose(graph)

    assert Yog.successors(transposed, 2) == [{1, 42}]
  end

  test "merge_then_map_edges_test" do
    g1 =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    g2 =
      Yog.directed()
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 2, to: 3, with: 20)

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
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    sub = Yog.Transform.subgraph(graph, [])

    assert map_size(elem(sub, 2)) == 0
    assert map_size(elem(sub, 3)) == 0
  end

  test "subgraph_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)

    sub = Yog.Transform.subgraph(graph, [2])

    assert map_size(elem(sub, 2)) == 1
    assert Map.get(elem(sub, 2), 2) == "B"
    assert Yog.successors(sub, 2) == []
  end

  test "subgraph_two_connected_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)

    sub = Yog.Transform.subgraph(graph, [2, 3])

    assert map_size(elem(sub, 2)) == 2
    assert Yog.successors(sub, 2) == [{3, 20}]
    assert Yog.predecessors(sub, 2) == []
  end

  test "subgraph_all_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)

    sub = Yog.Transform.subgraph(graph, [1, 2, 3])

    assert map_size(elem(sub, 2)) == 3
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
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      |> Yog.add_edge(from: 2, to: 3, with: 20)
      |> Yog.add_edge(from: 3, to: 4, with: 30)

    sub = Yog.Transform.subgraph(graph, [2, 3])

    assert map_size(elem(sub, 2)) == 2
    assert Yog.successors(sub, 2) == [{3, 20}]
    assert Yog.successors(sub, 3) == []
  end
end
