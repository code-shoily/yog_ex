defmodule YogMSTTest do
  use ExUnit.Case
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 1, to: 3, with: 3)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # MST should have 2 edges (n-1 for n nodes)
    assert length(result) == 2

    # Total weight should be 1+2=3 (edges 1-2 and 2-3)
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 3

    # Should include edges 1-2 and 2-3
    assert Enum.any?(result, fn e -> e.from == 1 and e.to == 2 and e.weight == 1 end)
    assert Enum.any?(result, fn e -> e.from == 2 and e.to == 3 and e.weight == 2 end)
  end

  # Linear chain
  test "mst_linear_chain_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 10)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 2 edges
    assert length(result) == 2

    # Total weight should be 15
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 15
  end

  # Single edge
  test "mst_single_edge_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 10)

    result = MST.kruskal(in: graph, compare: &compare/2)

    assert length(result) == 1

    [edge] = result
    assert edge.from == 1
    assert edge.to == 2
    assert edge.weight == 10
  end

  # Single node (no edges)
  test "mst_single_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")

    result = MST.kruskal(in: graph, compare: &compare/2)

    assert result == []
  end

  # Empty graph
  test "mst_empty_graph_test" do
    graph = Yog.undirected()

    result = MST.kruskal(in: graph, compare: &compare/2)

    assert result == []
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 4, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 1)
      |> Yog.add_edge(from: 1, to: 4, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 5)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 3 edges (4 nodes)
    assert length(result) == 3

    # Total weight should be 3 (three edges of weight 1)
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 3
  end

  # Classic example where greedy fails but Kruskal works
  test "mst_classic_kruskal_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 4, with: 3)
      |> Yog.add_edge(from: 1, to: 4, with: 4)
      |> Yog.add_edge(from: 2, to: 4, with: 5)

    result = MST.kruskal(in: graph, compare: &compare/2)

    assert length(result) == 3

    # Should select edges 1-2 (1), 2-3 (2), 3-4 (3) for total weight 6
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 6
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 4, with: 3)
      |> Yog.add_edge(from: 4, to: 5, with: 4)
      |> Yog.add_edge(from: 5, to: 1, with: 5)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 4 edges (5 nodes)
    assert length(result) == 4

    # Should select edges 1,2,3,4 (not 5) for total weight 10
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 10
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      # Component 2: 3-4
      |> Yog.add_edge(from: 3, to: 4, with: 2)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 2 edges (one per component)
    assert length(result) == 2

    # Should be a forest, not a tree
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 3
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      # Component 2: 3-4
      |> Yog.add_edge(from: 3, to: 4, with: 2)
      # Component 3: 5-6
      |> Yog.add_edge(from: 5, to: 6, with: 3)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 3 edges (one per component)
    assert length(result) == 3
  end

  # Isolated nodes
  test "mst_with_isolated_nodes_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 1)

    # Nodes 3 and 4 are isolated

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should only have 1 edge
    assert length(result) == 1
  end

  # ============= Weight Variation Tests =============

  test "mst_all_same_weights_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 5)
      |> Yog.add_edge(from: 3, to: 4, with: 5)
      |> Yog.add_edge(from: 1, to: 4, with: 5)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 3 edges
    assert length(result) == 3

    # All edges have weight 5, so total is 15
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 15
  end

  test "mst_zero_weight_edges_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 0)
      |> Yog.add_edge(from: 2, to: 3, with: 0)

    result = MST.kruskal(in: graph, compare: &compare/2)

    assert length(result) == 2

    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 0
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 2)
      |> Yog.add_edge(from: 1, to: 4, with: 3)
      |> Yog.add_edge(from: 2, to: 3, with: 4)
      |> Yog.add_edge(from: 2, to: 4, with: 5)
      |> Yog.add_edge(from: 3, to: 4, with: 6)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # MST of K4 has 3 edges
    assert length(result) == 3

    # Should select edges with weights 1, 2, 3
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 6
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 2)
      |> Yog.add_edge(from: 1, to: 4, with: 3)
      |> Yog.add_edge(from: 1, to: 5, with: 4)
      |> Yog.add_edge(from: 2, to: 3, with: 5)
      |> Yog.add_edge(from: 2, to: 4, with: 6)
      |> Yog.add_edge(from: 2, to: 5, with: 7)
      |> Yog.add_edge(from: 3, to: 4, with: 8)
      |> Yog.add_edge(from: 3, to: 5, with: 9)
      |> Yog.add_edge(from: 4, to: 5, with: 10)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # MST of K5 has 4 edges
    assert length(result) == 4

    # Should select edges with weights 1, 2, 3, 4
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 10
  end

  # ============= Cycle Detection Tests =============

  test "mst_avoids_cycle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 100)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have 2 edges (avoiding the cycle)
    assert length(result) == 2

    # Should not include the heavy edge
    assert not Enum.any?(result, fn e -> e.weight == 100 end)
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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 4, with: 3)
      |> Yog.add_edge(from: 4, to: 5, with: 4)
      |> Yog.add_edge(from: 5, to: 6, with: 5)
      |> Yog.add_edge(from: 6, to: 7, with: 6)
      |> Yog.add_edge(from: 7, to: 8, with: 7)
      |> Yog.add_edge(from: 8, to: 9, with: 8)
      |> Yog.add_edge(from: 9, to: 10, with: 9)
      # Add some cycle-creating edges with higher weights
      |> Yog.add_edge(from: 1, to: 10, with: 100)
      |> Yog.add_edge(from: 5, to: 10, with: 50)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Should have exactly 9 edges (n-1 for n=10)
    assert length(result) == 9

    # Should have total weight 1+2+3+4+5+6+7+8+9 = 45
    total_weight = Enum.reduce(result, 0, fn edge, acc -> acc + edge.weight end)

    assert total_weight == 45
  end

  # ============= Edge Case: Self Loops =============

  test "mst_with_self_loop_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 1, with: 1)
      |> Yog.add_edge(from: 1, to: 2, with: 2)

    result = MST.kruskal(in: graph, compare: &compare/2)

    # Self-loops should be ignored (they create cycles)
    # Should only have 1 edge connecting 1 and 2
    assert length(result) == 1

    [edge] = result
    assert edge.from == 1
    assert edge.to == 2
  end
end
