defmodule Yog.MSTTest do
  use ExUnit.Case

  doctest Yog.MST
  doctest Yog.MST.Result
  doctest Yog.MST.Kruskal
  doctest Yog.MST.Prim
  doctest Yog.MST.Boruvka
  doctest Yog.MST.Edmonds
  doctest Yog.MST.Wilson

  alias Yog.MST

  # Helper functions for algorithms
  defp compare(a, b), do: if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq))

  # ============= Basic MST Tests =============

  # Simple triangle graph
  #   1
  #  /|\
  # 2-+-3
  test "mst_simple_triangle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 3
    assert Enum.any?(result.edges, fn e -> e.from == 1 and e.to == 2 and e.weight == 1 end)
    assert Enum.any?(result.edges, fn e -> e.from == 2 and e.to == 3 and e.weight == 2 end)
  end

  # Linear chain
  test "mst_linear_chain_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 15
  end

  # Single edge
  test "mst_single_edge_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 1
    [edge] = result.edges
    assert edge.from == 1
    assert edge.to == 2
    assert edge.weight == 10
  end

  # Single node (no edges)
  test "mst_single_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edges == []
    assert result.total_weight == 0
    assert result.edge_count == 0
    assert result.node_count == 1
  end

  # Empty graph
  test "mst_empty_graph_test" do
    graph = Yog.undirected()

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edges == []
    assert result.total_weight == 0
    assert result.edge_count == 0
    assert result.node_count == 0
  end

  # ============= Classic MST Test Cases =============

  # Square with diagonal
  #   1---2
  #   |\ /|
  #   | X |
  #   |/ \|
  #   3---4
  test "mst_square_with_diagonal_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 4, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 5)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 3
    assert result.total_weight == 3
  end

  # Classic example where greedy fails but Kruskal works
  test "mst_classic_kruskal_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 5)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 3
    assert result.total_weight == 6
  end

  # Pentagon graph
  test "mst_pentagon_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      # Pentagon edges
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 4, to: 5, with: 4)
      |> Yog.add_edge_ensure(from: 5, to: 1, with: 5)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 4
    assert result.total_weight == 10
  end

  # ============= Disconnected Graph Tests =============

  test "mst_disconnected_two_components_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # Component 1: 1-2
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      # Component 2: 3-4
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 2)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 3
  end

  test "mst_disconnected_three_components_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_node(6, "F")
      # Component 1: 1-2
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      # Component 2: 3-4
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 2)
      # Component 3: 5-6
      |> Yog.add_edge_ensure(from: 5, to: 6, with: 3)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 3
  end

  # Isolated nodes
  test "mst_with_isolated_nodes_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    # Nodes 3 and 4 are isolated

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 1
  end

  # ============= Weight Variation Tests =============

  test "mst_all_same_weights_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 5)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 5)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 5)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 3
    assert result.total_weight == 15
  end

  test "mst_zero_weight_edges_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 0)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 0)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 0
  end

  # ============= Complete Graph Tests =============

  test "mst_complete_graph_k4_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # All possible edges with increasing weights
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 5)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 6)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 3
    assert result.total_weight == 6
  end

  test "mst_complete_graph_k5_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      # K5 has 10 edges
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 1, to: 5, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 6)
      |> Yog.add_edge_ensure(from: 2, to: 5, with: 7)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 8)
      |> Yog.add_edge_ensure(from: 3, to: 5, with: 9)
      |> Yog.add_edge_ensure(from: 4, to: 5, with: 10)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 4
    assert result.total_weight == 10
  end

  # ============= Cycle Detection Tests =============

  test "mst_avoids_cycle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 100)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert not Enum.any?(result.edges, fn e -> e.weight == 100 end)
  end

  test "mst_is_cycle_free_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 5)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    # Build a set of undirected edge pairs
    edge_pairs =
      Enum.map(result.edges, fn e ->
        [e.from, e.to] |> Enum.sort() |> List.to_tuple()
      end)

    # For a cycle-free graph on V nodes, edges == nodes - connected_components
    # Here graph is connected, so edges should be V - 1 = 3
    assert result.edge_count == 3

    # No duplicates
    assert length(edge_pairs) == length(Enum.uniq(edge_pairs))
  end

  # ============= Large Graph Tests =============

  test "mst_larger_graph_test" do
    # Create a graph with 10 nodes and various edges
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_node(6, "6")
      |> Yog.add_node(7, "7")
      |> Yog.add_node(8, "8")
      |> Yog.add_node(9, "9")
      |> Yog.add_node(10, "10")
      # Add edges to form a spanning tree with some extras
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 4, to: 5, with: 4)
      |> Yog.add_edge_ensure(from: 5, to: 6, with: 5)
      |> Yog.add_edge_ensure(from: 6, to: 7, with: 6)
      |> Yog.add_edge_ensure(from: 7, to: 8, with: 7)
      |> Yog.add_edge_ensure(from: 8, to: 9, with: 8)
      |> Yog.add_edge_ensure(from: 9, to: 10, with: 9)
      # Add some cycle-creating edges with higher weights
      |> Yog.add_edge_ensure(from: 1, to: 10, with: 100)
      |> Yog.add_edge_ensure(from: 5, to: 10, with: 50)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 9
    assert result.total_weight == 45
  end

  # ============= Edge Case: Self Loops =============

  test "mst_with_self_loop_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 1, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 2)

    {:ok, result} = MST.kruskal(in: graph, compare: &compare/2)

    assert result.edge_count == 1
    [edge] = result.edges
    assert edge.from == 1
    assert edge.to == 2
  end

  # ============= Tie-Breaking Consistency =============

  test "kruskal_and_prim_agree_on_total_weight_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 5)

    {:ok, kruskal_result} = MST.kruskal(in: graph, compare: &compare/2)
    {:ok, prim_result} = MST.prim(in: graph, compare: &compare/2)

    assert kruskal_result.total_weight == prim_result.total_weight
    assert kruskal_result.edge_count == prim_result.edge_count
  end

  test "kruskal_and_prim_agree_on_tied_weights_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 5)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 5)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 5)

    {:ok, kruskal_result} = MST.kruskal(in: graph, compare: &compare/2)
    {:ok, prim_result} = MST.prim(in: graph, compare: &compare/2)

    assert kruskal_result.total_weight == prim_result.total_weight
    assert kruskal_result.edge_count == prim_result.edge_count
    assert kruskal_result.total_weight == 15
  end

  # ============= Prim's Algorithm Tests =============

  test "prim_simple_triangle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)

    {:ok, result} = MST.prim(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 3
  end

  test "prim_linear_chain_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    {:ok, result} = MST.prim(in: graph, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 15
  end

  test "prim_single_edge_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

    {:ok, result} = MST.prim(in: graph, compare: &compare/2)

    assert result.edge_count == 1
    [edge] = result.edges
    nodes = [edge.from, edge.to] |> Enum.sort()
    assert nodes == [1, 2]
    assert edge.weight == 10
  end

  test "prim_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, "A")
    {:ok, result} = MST.prim(in: graph, compare: &compare/2)
    assert result.edges == []
    assert result.node_count == 1
  end

  test "prim_empty_graph_test" do
    graph = Yog.undirected()
    {:ok, result} = MST.prim(in: graph, compare: &compare/2)
    assert result.edges == []
    assert result.node_count == 0
  end

  test "prim_square_with_diagonal_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 4, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 5)

    {:ok, result} = MST.prim(in: graph, compare: &compare/2)

    assert result.edge_count == 3
    assert result.total_weight == 3
  end

  test "prim_classic_kruskal_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 5)

    {:ok, result} = MST.prim(in: graph, compare: &compare/2)

    assert result.edge_count == 3
    assert result.total_weight == 6
  end

  test "prim_disconnected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 2)

    {:ok, result} = MST.prim(in: graph, compare: &compare/2)
    assert result.edge_count == 1
    [edge] = result.edges
    assert edge.weight in [1, 2]
  end

  test "prim_from_specific_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)

    {:ok, result} = MST.prim(in: graph, from: 3, compare: &compare/2)

    assert result.edge_count == 2
    assert result.total_weight == 3
  end

  test "prim_from_nonexistent_node_returns_empty_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    {:ok, result} = MST.prim(in: graph, from: 99, compare: &compare/2)

    assert result.edges == []
    assert result.node_count == 2
  end

  # ============= Directed Graph Tests =============

  test "kruskal_directed_graph_returns_error_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)

    assert MST.kruskal(in: graph, compare: &compare/2) == {:error, :undirected_only}
    assert MST.kruskal(graph, &compare/2) == {:error, :undirected_only}
  end

  test "prim_directed_graph_returns_error_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)

    assert MST.prim(in: graph, compare: &compare/2) == {:error, :undirected_only}
    assert MST.prim(graph, &compare/2) == {:error, :undirected_only}
  end

  # ============= Maximum Spanning Tree Tests =============

  test "kruskal_max_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 5}, {3, 4, 2}, {1, 4, 10}, {2, 4, 1}])

    {:ok, result} = MST.kruskal_max(in: graph)

    assert result.edge_count == 3
    assert result.total_weight == 17
    assert result.algorithm == :kruskal
  end

  test "prim_max_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 5}, {3, 4, 2}, {1, 4, 10}, {2, 4, 1}])

    {:ok, result} = MST.prim_max(in: graph)

    assert result.edge_count == 3
    assert result.total_weight == 17
    assert result.algorithm == :prim
  end

  test "maximum_spanning_tree_facade_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 5}, {3, 4, 2}, {1, 4, 10}, {2, 4, 1}])

    {:ok, result} = MST.maximum_spanning_tree(graph)
    assert result.total_weight == 17
    assert result.algorithm == :kruskal
  end

  test "boruvka_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 5}, {3, 4, 2}, {1, 4, 10}, {2, 4, 1}])

    {:ok, result} = MST.boruvka(in: graph)

    assert result.edge_count == 3
    assert result.total_weight == 4
    assert result.algorithm == :boruvka
  end

  # ============= Minimum Spanning Arborescence Tests =============

  test "minimum_arborescence_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(4, "C")
      |> Yog.add_edges!([
        {1, 2, 10},
        {1, 3, 20},
        {2, 3, 5},
        {3, 4, 15},
        {4, 2, 2}
      ])

    # This graph has a cycle: 2 -> 3 -> 4 -> 2
    # best incoming for 2 is from 4 (w=2)
    # best incoming for 3 is from 2 (w=5)
    # best incoming for 4 is from 3 (w=15)
    # Cycle weight: 2 + 5 + 15 = 22
    #
    # Now we need an edge from root (1) to enter the cycle.
    # 1 -> 2 (10): adjusts to 10 - 2 = 8
    # 1 -> 3 (20): adjusts to 20 - 5 = 15
    #
    # Minimum entry is 1 -> 2 (adjust 8).
    #
    # Resulting MSA:
    # 1 -> 2 (10)
    # 2 -> 3 (5)
    # 3 -> 4 (15)
    # Total weight: 10 + 5 + 15 = 30

    {:ok, result} = MST.minimum_arborescence(in: graph, root: 1)

    assert result.edge_count == 3
    assert result.total_weight == 30
    assert result.algorithm == :chu_liu_edmonds
  end

  test "no_arborescence_exists_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_edges!([{1, 2, 10}, {3, 2, 5}])

    # 3 is unreachable from 1
    assert MST.minimum_arborescence(in: graph, root: 1) == {:error, :no_arborescence_exists}
  end

  test "chu_liu_edmonds_alias_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "Node")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

    {:ok, result} = MST.chu_liu_edmonds(graph, 1)
    assert result.total_weight == 5
  end

  describe "Wilson's Algorithm" do
    test "generates a valid spanning tree for a simple graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}, {1, 3, 1}])

      {:ok, result} = MST.uniform_spanning_tree(in: graph)

      assert result.edge_count == 3
      assert result.node_count == 4
      assert result.algorithm == :wilson

      # Verify it's connected (all 4 nodes reachable in result edges)
      nodes_in_tree =
        Enum.flat_map(result.edges, fn e -> [e.from, e.to] end) |> Enum.uniq() |> Enum.sort()

      assert nodes_in_tree == [1, 2, 3, 4]
    end

    test "works with different roots" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge!(1, 2, 1)

      {:ok, res1} = MST.uniform_spanning_tree(in: graph, root: 1)
      {:ok, res2} = MST.uniform_spanning_tree(in: graph, root: 2)

      assert res1.edge_count == 1
      assert res2.edge_count == 1
    end
  end
end
