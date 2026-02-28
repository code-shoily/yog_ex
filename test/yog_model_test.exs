defmodule YogModelTest do
  use ExUnit.Case

  # Note: Many model tests are already covered in yog_test.exs
  # This file focuses on additional model-specific behaviors

  # ============= Edge Weight Combining Tests =============

  test "add_edge_with_combine_sum_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> :yog@model.add_edge(1, 2, 10)
      |> :yog@model.add_edge_with_combine(1, 2, 5, &Kernel.+/2)

    # Edge weight should be 10 + 5 = 15
    assert Yog.successors(graph, 1) == [{2, 15}]
  end

  test "add_edge_with_combine_max_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> :yog@model.add_edge(1, 2, 10)
      |> :yog@model.add_edge_with_combine(1, 2, 25, &max/2)

    # Edge weight should be max(10, 25) = 25
    assert Yog.successors(graph, 1) == [{2, 25}]
  end

  test "add_edge_with_combine_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> :yog@model.add_edge(1, 2, 10)
      |> :yog@model.add_edge_with_combine(1, 2, 5, &Kernel.+/2)

    # Both directions should have combined weight
    assert Yog.successors(graph, 1) == [{2, 15}]
    assert Yog.successors(graph, 2) == [{1, 15}]
  end

  # ============= Remove Node Tests =============

  test "remove_node_isolated_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> :yog@model.remove_node(2)

    nodes = Yog.all_nodes(graph)
    assert length(nodes) == 2
    assert 1 in nodes
    assert 3 in nodes
    refute 2 in nodes
  end

  test "remove_node_with_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 2, to: 3, weight: 20)
      |> :yog@model.remove_node(2)

    # Node 2 removed
    nodes = Yog.all_nodes(graph)
    assert length(nodes) == 2
    refute 2 in nodes

    # Edges involving node 2 should be gone
    assert Yog.successors(graph, 1) == []
    assert Yog.predecessors(graph, 3) == []
  end

  test "remove_node_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 2, to: 3, weight: 20)
      |> :yog@model.remove_node(2)

    # Both directions should be cleaned up
    assert Yog.successors(graph, 1) == []
    assert Yog.successors(graph, 3) == []
  end

  # ============= Order (Node Count) Tests =============

  test "order_empty_graph_test" do
    graph = Yog.directed()
    assert :yog@model.order(graph) == 0
  end

  test "order_after_adding_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")

    assert :yog@model.order(graph) == 3
  end

  test "order_unchanged_by_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    assert :yog@model.order(graph) == 2

    graph = Yog.add_edge(graph, from: 1, to: 2, weight: 10)
    assert :yog@model.order(graph) == 2
  end

  test "order_after_remove_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")

    assert :yog@model.order(graph) == 3

    graph = :yog@model.remove_node(graph, 2)
    assert :yog@model.order(graph) == 2
  end

  # ============= Complex Graph Tests =============

  test "complex_directed_graph_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, weight: 1.0)
      |> Yog.add_edge(from: 1, to: 3, weight: 2.0)
      |> Yog.add_edge(from: 2, to: 3, weight: 1.5)
      |> Yog.add_edge(from: 3, to: 4, weight: 3.0)
      |> Yog.add_edge(from: 2, to: 4, weight: 2.5)

    # Verify structure through public API
    assert length(Yog.all_nodes(graph)) == 4
    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.predecessors(graph, 4)) == 2
    assert length(Yog.successors(graph, 3)) == 1
    assert length(Yog.predecessors(graph, 3)) == 2
  end

  test "self_loop_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_edge(from: 1, to: 1, weight: 5)

    # Node should point to itself
    assert Yog.successors(graph, 1) == [{1, 5}]
    assert Yog.predecessors(graph, 1) == [{1, 5}]
  end

  test "graph_with_string_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 100)
      |> Yog.add_node(2, 200)
      |> Yog.add_edge(from: 1, to: 2, weight: "labeled_edge")

    assert Yog.successors(graph, 1) == [{2, "labeled_edge"}]
  end

  # ============= Neighbors Tests (combines successors + predecessors) =============

  test "neighbors_undirected_matches_successors_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_node(3, "Node C")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 20)

    neighbors = Yog.neighbors(graph, 1)
    successors = Yog.successors(graph, 1)

    assert Enum.sort(neighbors) == Enum.sort(successors)
    assert length(neighbors) == 2
  end

  test "neighbors_directed_outgoing_only_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_node(3, "Node C")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 20)

    neighbors = Yog.neighbors(graph, 1)
    assert length(neighbors) == 2
    assert {2, 10} in neighbors
    assert {3, 20} in neighbors
  end

  test "neighbors_directed_incoming_only_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_node(3, "Node C")
      |> Yog.add_edge(from: 2, to: 1, weight: 10)
      |> Yog.add_edge(from: 3, to: 1, weight: 20)

    neighbors = Yog.neighbors(graph, 1)
    assert length(neighbors) == 2
    assert {2, 10} in neighbors
    assert {3, 20} in neighbors
  end

  test "neighbors_directed_both_directions_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_node(3, "Node C")
      |> Yog.add_node(4, "Node D")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 20)
      |> Yog.add_edge(from: 4, to: 1, weight: 30)

    neighbors = Yog.neighbors(graph, 1)
    assert length(neighbors) == 3
    assert {2, 10} in neighbors
    assert {3, 20} in neighbors
    assert {4, 30} in neighbors
  end

  test "neighbors_directed_bidirectional_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 2, to: 1, weight: 20)

    neighbors = Yog.neighbors(graph, 1)
    # Should only include each neighbor once
    assert length(neighbors) == 1
    assert {2, 10} in neighbors
  end

  test "neighbors_empty_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")

    assert Yog.neighbors(graph, 1) == []
  end

  # ============= Successor IDs Tests =============

  test "successor_ids_consistency_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_node(3, "Node C")
      |> Yog.add_edge(from: 1, to: 2, weight: 100)
      |> Yog.add_edge(from: 1, to: 3, weight: 200)

    successor_ids = Yog.successor_ids(graph, 1)
    successors = Yog.successors(graph, 1) |> Enum.map(&elem(&1, 0))

    assert Enum.sort(successor_ids) == Enum.sort(successors)
  end

  test "successor_ids_self_loop_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_edge(from: 1, to: 1, weight: 5)

    assert Yog.successor_ids(graph, 1) == [1]
  end
end
