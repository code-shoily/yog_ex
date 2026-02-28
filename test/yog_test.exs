defmodule YogTest do
  use ExUnit.Case

  describe "Yog Model Tests" do
    # Test creating a new directed graph
    test "new_directed_graph_test" do
      graph = Yog.directed()

      assert graph |> elem(0) == :graph
      assert graph |> elem(1) == :directed
      # nodes
      assert graph |> elem(2) |> map_size() == 0
      # out_edges
      assert graph |> elem(3) |> map_size() == 0
      # in_edges
      assert graph |> elem(4) |> map_size() == 0
    end

    # Test creating a new undirected graph
    test "new_undirected_graph_test" do
      graph = Yog.undirected()
      assert graph |> elem(1) == :undirected
    end

    # Test adding a single node
    test "add_single_node_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")

      nodes = graph |> elem(2)
      assert map_size(nodes) == 1
      assert Map.get(nodes, 1) == "Node A"
    end

    # Test adding multiple nodes
    test "add_multiple_nodes_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")

      nodes = graph |> elem(2)
      assert map_size(nodes) == 3
      assert Map.get(nodes, 2) == "Node B"
    end

    # Test updating a node (adding with same ID replaces)
    test "update_node_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Original")
        |> Yog.add_node(1, "Updated")

      nodes = graph |> elem(2)
      assert map_size(nodes) == 1
      assert Map.get(nodes, 1) == "Updated"
    end

    # Test adding a directed edge
    test "add_directed_edge_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)

      out_edges = graph |> elem(3)
      in_edges = graph |> elem(4)

      assert Map.get(out_edges, 1) == %{2 => 10}
      assert Map.get(in_edges, 2) == %{1 => 10}

      assert Map.get(out_edges, 2) == nil
      assert Map.get(in_edges, 1) == nil
    end

    # Test adding multiple directed edges from one node
    test "add_multiple_outgoing_edges_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 1, to: 3, weight: 20)

      out_edges_1 = graph |> elem(3) |> Map.get(1)
      assert map_size(out_edges_1) == 2
      assert Map.get(out_edges_1, 2) == 10
      assert Map.get(out_edges_1, 3) == 20
    end

    # Test adding multiple directed edges to one node
    test "add_multiple_incoming_edges_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_edge(from: 1, to: 3, weight: 10)
        |> Yog.add_edge(from: 2, to: 3, weight: 20)

      in_edges_3 = graph |> elem(4) |> Map.get(3)
      assert map_size(in_edges_3) == 2
      assert Map.get(in_edges_3, 1) == 10
      assert Map.get(in_edges_3, 2) == 20
    end

    # Test undirected edge creates bidirectional edges
    test "add_undirected_edge_test" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 15)

      out_edges = graph |> elem(3)
      in_edges = graph |> elem(4)

      assert Map.get(out_edges, 1) == %{2 => 15}
      assert Map.get(out_edges, 2) == %{1 => 15}

      assert Map.get(in_edges, 1) == %{2 => 15}
      assert Map.get(in_edges, 2) == %{1 => 15}
    end

    # Test updating an edge (adding same edge replaces weight)
    test "update_edge_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 1, to: 2, weight: 25)

      out_edges = graph |> elem(3)
      assert Map.get(out_edges, 1) == %{2 => 25}
    end

    # Test graph with different data types - String edge weights
    test "graph_with_string_edges_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, 100)
        |> Yog.add_node(2, 200)
        |> Yog.add_edge(from: 1, to: 2, weight: "labeled_edge")

      nodes = graph |> elem(2)
      assert Map.get(nodes, 1) == 100

      out_edges = graph |> elem(3)
      assert Map.get(out_edges, 1) |> Map.get(2) == "labeled_edge"
    end

    # Test complex directed graph
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

      nodes = graph |> elem(2)
      out_edges = graph |> elem(3)
      in_edges = graph |> elem(4)

      assert map_size(nodes) == 4
      assert Map.get(out_edges, 1) |> map_size() == 2
      assert Map.get(in_edges, 4) |> map_size() == 2
      assert Map.get(out_edges, 3) |> map_size() == 1
      assert Map.get(in_edges, 3) |> map_size() == 2
    end

    # Test self-loop
    test "self_loop_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_edge(from: 1, to: 1, weight: 5)

      out_edges = graph |> elem(3)
      in_edges = graph |> elem(4)

      assert Map.get(out_edges, 1) == %{1 => 5}
      assert Map.get(in_edges, 1) == %{1 => 5}
    end

    # ============= Tests for successors() =============
    test "successors_empty_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")

      assert Yog.successors(graph, 1) == []
    end

    test "successors_nonexistent_node_test" do
      graph = Yog.directed()
      assert Yog.successors(graph, 99) == []
    end

    test "successors_single_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)

      assert Yog.successors(graph, 1) == [{2, 10}]
    end

    test "successors_multiple_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_node(4, "Node D")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 1, to: 3, weight: 20)
        |> Yog.add_edge(from: 1, to: 4, weight: 30)

      result = Yog.successors(graph, 1)
      assert length(result) == 3
      assert {2, 10} in result
      assert {3, 20} in result
      assert {4, 30} in result
    end

    # ============= Tests for predecessors() =============
    test "predecessors_empty_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")

      assert Yog.predecessors(graph, 1) == []
    end

    test "predecessors_nonexistent_node_test" do
      graph = Yog.directed()
      assert Yog.predecessors(graph, 99) == []
    end

    test "predecessors_single_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)

      assert Yog.predecessors(graph, 2) == [{1, 10}]
    end

    test "predecessors_multiple_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_node(4, "Node D")
        |> Yog.add_edge(from: 1, to: 4, weight: 10)
        |> Yog.add_edge(from: 2, to: 4, weight: 20)
        |> Yog.add_edge(from: 3, to: 4, weight: 30)

      result = Yog.predecessors(graph, 4)
      assert length(result) == 3
      assert {1, 10} in result
      assert {2, 20} in result
      assert {3, 30} in result
    end

    # ============= Tests for neighbors() =============
    test "neighbors_undirected_test" do
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

    test "neighbors_directed_both_test" do
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
      assert length(neighbors) == 1
      assert {2, 10} in neighbors
    end

    test "neighbors_empty_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")

      assert Yog.neighbors(graph, 1) == []
    end

    # ============= Tests for all_nodes() =============
    test "all_nodes_empty_test" do
      graph = Yog.directed()
      assert Yog.all_nodes(graph) == []
    end

    test "all_nodes_no_edges_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")

      result = Yog.all_nodes(graph)
      assert length(result) == 3
      assert 1 in result
      assert 2 in result
      assert 3 in result
    end

    test "all_nodes_directed_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_node(4, "Node D")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 2, to: 3, weight: 20)

      result = Yog.all_nodes(graph)
      assert length(result) == 4
      assert 1 in result
      assert 2 in result
      assert 3 in result
      assert 4 in result
    end

    test "all_nodes_undirected_test" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)

      result = Yog.all_nodes(graph)
      assert length(result) == 3
      assert 1 in result
      assert 2 in result
      assert 3 in result
    end

    test "all_nodes_self_loop_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_edge(from: 1, to: 1, weight: 5)

      assert Yog.all_nodes(graph) == [1]
    end

    test "all_nodes_unique_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 2, to: 1, weight: 20)

      result = Yog.all_nodes(graph)
      assert length(result) == 2
      assert 1 in result
      assert 2 in result
    end

    # ============= Tests for successor_ids() =============
    test "successor_ids_empty_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")

      assert Yog.successor_ids(graph, 1) == []
    end

    test "successor_ids_nonexistent_node_test" do
      graph = Yog.directed()
      assert Yog.successor_ids(graph, 99) == []
    end

    test "successor_ids_single_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)

      assert Yog.successor_ids(graph, 1) == [2]
    end

    test "successor_ids_multiple_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_node(3, "Node C")
        |> Yog.add_node(4, "Node D")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 1, to: 3, weight: 20)
        |> Yog.add_edge(from: 1, to: 4, weight: 30)

      result = Yog.successor_ids(graph, 1)
      assert length(result) == 3
      assert 2 in result
      assert 3 in result
      assert 4 in result
    end

    test "successor_ids_self_loop_test" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_edge(from: 1, to: 1, weight: 5)

      assert Yog.successor_ids(graph, 1) == [1]
    end

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
  end
end
