defmodule Yog.ModelTest do
  use ExUnit.Case

  alias Yog.Model

  doctest Yog.Model

  # Note: Many model tests are already covered in yog_test.exs
  # This file focuses on additional model-specific behaviors

  # ============= Edge Weight Combining Tests =============

  test "add_edge_with_combine_sum_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_edge!(1, 2, 10)
      |> Model.add_edge_with_combine!(1, 2, 5, &Kernel.+/2)

    # Edge weight should be 10 + 5 = 15
    assert Model.successors(graph, 1) == [{2, 15}]
  end

  test "add_edge_with_combine_max_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_edge!(1, 2, 10)
      |> Model.add_edge_with_combine!(1, 2, 25, &max/2)

    # Edge weight should be max(10, 25) = 25
    assert Model.successors(graph, 1) == [{2, 25}]
  end

  test "add_edge_with_combine_undirected_test" do
    graph =
      Yog.undirected()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_edge!(1, 2, 10)
      |> Model.add_edge_with_combine!(1, 2, 5, &Kernel.+/2)

    # Both directions should have combined weight
    assert Yog.successors(graph, 1) == [{2, 15}]
    assert Yog.successors(graph, 2) == [{1, 15}]
  end

  # ============= Remove Node Tests =============

  test "remove_node_isolated_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_node(3, "C")
      |> Model.remove_node(2)

    nodes = Yog.all_nodes(graph)
    assert length(nodes) == 2
    assert 1 in nodes
    assert 3 in nodes
    refute 2 in nodes
  end

  test "remove_node_with_edges_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_node(3, "C")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 10)
      |> Model.add_edge_ensure(from: 2, to: 3, with: 20)
      |> Model.remove_node(2)

    # Node 2 removed
    nodes = Model.all_nodes(graph)
    assert length(nodes) == 2
    refute 2 in nodes

    # Edges involving node 2 should be gone
    assert Model.successors(graph, 1) == []
    assert Model.predecessors(graph, 3) == []
  end

  test "remove_node_undirected_test" do
    graph =
      Yog.undirected()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_node(3, "C")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 10)
      |> Model.add_edge_ensure(from: 2, to: 3, with: 20)
      |> Model.remove_node(2)

    # Both directions should be cleaned up
    assert Model.successors(graph, 1) == []
    assert Model.successors(graph, 3) == []
  end

  # ============= Order (Node Count) Tests =============

  test "order_empty_graph_test" do
    graph = Yog.directed()
    assert Model.order(graph) == 0
  end

  test "order_after_adding_nodes_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_node(3, "C")

    assert Model.order(graph) == 3
  end

  test "order_unchanged_by_edges_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")

    assert Model.order(graph) == 2

    graph = Model.add_edge!(graph, from: 1, to: 2, with: 10)
    assert Model.order(graph) == 2
  end

  test "order_after_remove_node_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_node(3, "C")

    assert Model.order(graph) == 3

    graph = Model.remove_node(graph, 2)
    assert Model.order(graph) == 2
  end

  # ============= Edge Count (with Self-Loops) Tests =============

  test "edge_count_directed_self_loop_test" do
    # In directed graphs, a self-loop is 1 edge
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_edge!(1, 1, 10)

    assert Model.edge_count(graph) == 1
    assert Yog.Graph.edge_count(graph) == 1
  end

  test "edge_count_undirected_self_loop_test" do
    # In undirected graphs, 1 self-loop should count as 1 edge
    graph =
      Yog.undirected()
      |> Model.add_node(1, "A")
      |> Model.add_edge!(1, 1, 10)

    assert Model.edge_count(graph) == 1
    assert Yog.Graph.edge_count(graph) == 1
  end

  test "edge_count_undirected_complex_self_loops_test" do
    # 2 nodes, 1 normal edge, 1 self-loop = 2 edges total
    graph =
      Yog.undirected()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_edge!(1, 2, 10)
      |> Model.add_edge!(1, 1, 5)

    assert Model.edge_count(graph) == 2
    assert Yog.Graph.edge_count(graph) == 2
  end

  # ============= Complex Graph Tests =============

  test "complex_directed_graph_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_node(3, "C")
      |> Model.add_node(4, "D")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 1.0)
      |> Model.add_edge_ensure(from: 1, to: 3, with: 2.0)
      |> Model.add_edge_ensure(from: 2, to: 3, with: 1.5)
      |> Model.add_edge_ensure(from: 3, to: 4, with: 3.0)
      |> Model.add_edge_ensure(from: 2, to: 4, with: 2.5)

    # Verify structure through public API
    assert length(Model.all_nodes(graph)) == 4
    assert length(Model.successors(graph, 1)) == 2
    assert length(Model.predecessors(graph, 4)) == 2
    assert length(Model.successors(graph, 3)) == 1
    assert length(Model.predecessors(graph, 3)) == 2
  end

  test "self_loop_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_edge_ensure(from: 1, to: 1, with: 5)

    # Node should point to itself
    assert Model.successors(graph, 1) == [{1, 5}]
    assert Model.predecessors(graph, 1) == [{1, 5}]
  end

  test "graph_with_string_edges_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, 100)
      |> Model.add_node(2, 200)
      |> Model.add_edge_ensure(from: 1, to: 2, with: "labeled_edge")

    assert Model.successors(graph, 1) == [{2, "labeled_edge"}]
  end

  # ============= Neighbors Tests (combines successors + predecessors) =============

  test "neighbors_undirected_matches_successors_test" do
    graph =
      Yog.undirected()
      |> Model.add_node(1, "Node A")
      |> Model.add_node(2, "Node B")
      |> Model.add_node(3, "Node C")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 10)
      |> Model.add_edge_ensure(from: 1, to: 3, with: 20)

    neighbors = Model.neighbors(graph, 1)
    successors = Model.successors(graph, 1)

    assert Enum.sort(neighbors) == Enum.sort(successors)
    assert length(neighbors) == 2
  end

  test "neighbors_directed_outgoing_only_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_node(2, "Node B")
      |> Model.add_node(3, "Node C")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 10)
      |> Model.add_edge_ensure(from: 1, to: 3, with: 20)

    neighbors = Yog.neighbors(graph, 1)
    assert length(neighbors) == 2
    assert {2, 10} in neighbors
    assert {3, 20} in neighbors
  end

  test "neighbors_directed_incoming_only_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_node(2, "Node B")
      |> Model.add_node(3, "Node C")
      |> Model.add_edge_ensure(from: 2, to: 1, with: 10)
      |> Model.add_edge_ensure(from: 3, to: 1, with: 20)

    neighbors = Yog.neighbors(graph, 1)
    assert length(neighbors) == 2
    assert {2, 10} in neighbors
    assert {3, 20} in neighbors
  end

  test "neighbors_directed_both_directions_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_node(2, "Node B")
      |> Model.add_node(3, "Node C")
      |> Model.add_node(4, "Node D")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 10)
      |> Model.add_edge_ensure(from: 1, to: 3, with: 20)
      |> Model.add_edge_ensure(from: 4, to: 1, with: 30)

    neighbors = Model.neighbors(graph, 1)
    assert length(neighbors) == 3
    assert {2, 10} in neighbors
    assert {3, 20} in neighbors
    assert {4, 30} in neighbors
  end

  test "neighbors_directed_bidirectional_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_node(2, "Node B")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 10)
      |> Model.add_edge_ensure(from: 2, to: 1, with: 20)

    neighbors = Yog.neighbors(graph, 1)
    # Should only include each neighbor once
    assert length(neighbors) == 1
    assert {2, 10} in neighbors
  end

  test "neighbors_empty_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")

    assert Model.neighbors(graph, 1) == []
  end

  # ============= Successor IDs Tests =============

  test "successor_ids_consistency_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_node(2, "Node B")
      |> Model.add_node(3, "Node C")
      |> Model.add_edge_ensure(from: 1, to: 2, with: 100)
      |> Model.add_edge_ensure(from: 1, to: 3, with: 200)

    successor_ids = Yog.successor_ids(graph, 1)
    successors = Yog.successors(graph, 1) |> Enum.map(&elem(&1, 0))

    assert Enum.sort(successor_ids) == Enum.sort(successors)
  end

  test "successor_ids_self_loop_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Node A")
      |> Model.add_edge_ensure(from: 1, to: 1, with: 5)

    assert Model.successor_ids(graph, 1) == [1]
  end

  # ============= Add Nodes From Tests =============

  test "add_nodes_from_list_of_ids_test" do
    graph =
      Yog.directed()
      |> Model.add_nodes_from([1, 2, 3])

    assert Model.order(graph) == 3
    assert Model.node(graph, 1) == nil
    assert Model.node(graph, 2) == nil
  end

  test "add_nodes_from_tuples_test" do
    graph =
      Yog.directed()
      |> Model.add_nodes_from([{1, "A"}, {2, "B"}])

    assert Model.order(graph) == 2
    assert Model.node(graph, 1) == "A"
    assert Model.node(graph, 2) == "B"
  end

  test "add_nodes_from_map_test" do
    graph =
      Yog.directed()
      |> Model.add_nodes_from(%{1 => "A", 2 => "B"})

    assert Model.order(graph) == 2
    assert Model.node(graph, 1) == "A"
    assert Model.node(graph, 2) == "B"
  end

  test "add_nodes_from_graph_test" do
    h =
      Yog.undirected()
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")

    graph =
      Yog.directed()
      |> Model.add_nodes_from(h)

    assert Model.order(graph) == 2
    assert Model.node(graph, 1) == "A"
    assert Model.node(graph, 2) == "B"
    # Only nodes copied, not edges
    assert Model.edge_count(graph) == 0
  end

  test "add_nodes_from_replaces_existing_test" do
    graph =
      Yog.directed()
      |> Model.add_node(1, "Old")
      |> Model.add_nodes_from([{1, "New"}])

    assert Model.node(graph, 1) == "New"
  end

  # ============= Coverage Test for All Delegates =============

  test "all_model_delegates_test" do
    # explicitly call all Yog.Model delegates to ensure mix coveralls picks them up
    graph = Model.new(:directed)
    graph = Model.add_node(graph, 1, "A")
    graph = Model.add_node(graph, 2, "B")
    graph = Model.add_nodes_from(graph, [3, 4])
    graph = Model.add_edge!(graph, 1, 2, 10)
    graph = Model.add_edge_ensure(graph, 2, 3, 5, "C")

    assert Model.order(graph) == 4
    assert length(Model.all_nodes(graph)) == 4
    assert Model.successors(graph, 1) == [{2, 10}]
    assert Model.successor_ids(graph, 1) == [2]
    assert Model.predecessors(graph, 2) == [{1, 10}]
    assert length(Model.neighbors(graph, 2)) == 2

    graph = Model.add_edge_with_combine!(graph, 1, 2, 5, &Kernel.+/2)
    assert Model.successors(graph, 1) == [{2, 15}]

    graph = Model.remove_node(graph, 2)
    assert Model.order(graph) == 3

    assert Model.type(graph) == :directed
    assert is_map(Model.nodes(graph))
    assert Model.node(graph, 1) == "A"
  end
end
