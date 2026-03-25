defmodule Yog.Pathfinding.JohnsonTest do
  use ExUnit.Case
  alias Yog.Pathfinding.Johnson
  doctest Johnson

  # Helper functions for algorithms
  defp compare(a, b), do: if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq))
  defp add(a, b), do: a + b
  defp subtract(a, b), do: a - b

  # ============= Basic All-Pairs Tests =============

  test "johnson_linear_graph_test" do
    # Linear graph: 1 -> 2 -> 3
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 1}] == 0
    assert distances[{1, 2}] == 5
    assert distances[{1, 3}] == 15
    assert distances[{2, 2}] == 0
    assert distances[{2, 3}] == 10
    assert distances[{3, 3}] == 0
  end

  test "johnson_simple_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 1}] == 0
    assert distances[{1, 2}] == 10
    assert distances[{2, 2}] == 0
  end

  test "johnson_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 1}] == 0
  end

  test "johnson_empty_graph_test" do
    graph = Yog.directed()

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    assert map_size(distances) == 0
  end

  # ============= Triangle and Complete Graph Tests =============

  test "johnson_triangle_test" do
    # Triangle: 1 -> 2 -> 3, 1 -> 3
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)
      |> Yog.add_edge!(from: 1, to: 3, with: 20)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Should find shorter path 1 -> 2 -> 3 (15) instead of 1 -> 3 (20)
    assert distances[{1, 3}] == 15
  end

  test "johnson_complete_graph_test" do
    # Complete graph with 4 nodes and negative edges (no negative cycles)
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 3)
      |> Yog.add_edge!(from: 1, to: 3, with: 8)
      |> Yog.add_edge!(from: 1, to: 4, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 4, with: 7)
      |> Yog.add_edge!(from: 3, to: 1, with: 2)
      |> Yog.add_edge!(from: 3, to: 4, with: 3)
      |> Yog.add_edge!(from: 4, to: 2, with: 2)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Verify some key distances
    assert distances[{1, 1}] == 0
    assert distances[{1, 2}] == 3
    assert distances[{1, 3}] == 4
    assert distances[{1, 4}] == 5
  end

  # ============= Diamond Graph Tests =============

  test "johnson_diamond_test" do
    # Diamond shape:
    #     1
    #    / \
    #   2   3
    #    \ /
    #     4
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 4)
      |> Yog.add_edge!(from: 2, to: 4, with: 2)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Should find path 1 -> 2 -> 4 (cost 3) not 1 -> 3 -> 4 (cost 5)
    assert distances[{1, 4}] == 3
  end

  # ============= Negative Weight Tests =============

  test "johnson_negative_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 4)
      |> Yog.add_edge!(from: 2, to: 3, with: -3)
      |> Yog.add_edge!(from: 1, to: 3, with: 2)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Should find path 1 -> 2 -> 3 (cost 1) not 1 -> 3 (cost 2)
    assert distances[{1, 3}] == 1
  end

  test "johnson_all_negative_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: -1)
      |> Yog.add_edge!(from: 2, to: 3, with: -2)
      |> Yog.add_edge!(from: 1, to: 3, with: -5)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Direct path 1 -> 3 (cost -5) is better than 1 -> 2 -> 3 (cost -3)
    assert distances[{1, 3}] == -5
  end

  test "johnson_mixed_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 1, to: 3, with: -10)
      |> Yog.add_edge!(from: 2, to: 4, with: 3)
      |> Yog.add_edge!(from: 3, to: 4, with: 20)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Should take path 1 -> 2 -> 4 (cost 8) not 1 -> 3 -> 4 (cost 10)
    assert distances[{1, 4}] == 8
  end

  # ============= Negative Cycle Detection =============

  test "johnson_negative_cycle_test" do
    # Simple negative cycle: 1 -> 2 -> 1
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: -3)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert result == {:error, :negative_cycle}
  end

  test "johnson_three_node_negative_cycle_test" do
    # Three node negative cycle
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: -2)
      |> Yog.add_edge!(from: 3, to: 1, with: -2)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert result == {:error, :negative_cycle}
  end

  test "johnson_positive_cycle_test" do
    # Positive cycle should not be detected as negative
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 1, with: 3)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, _distances} = result
  end

  # ============= Disconnected Graph Tests =============

  test "johnson_disconnected_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 3, to: 4, with: 10)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Reachable pairs
    assert distances[{1, 2}] == 5
    assert distances[{3, 4}] == 10
    # Unreachable pairs should not be in the map
    assert Map.has_key?(distances, {1, 3}) == false
    assert Map.has_key?(distances, {2, 4}) == false
  end

  # ============= Weight Type Tests =============

  test "johnson_int_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    result = Johnson.johnson(graph)

    assert {:ok, distances} = result
    assert distances[{1, 3}] == 15
  end

  test "johnson_float_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5.5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10.5)

    result = Johnson.johnson(graph)

    assert {:ok, distances} = result
    assert distances[{1, 3}] == 16.0
  end

  test "johnson_zero_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 0)
      |> Yog.add_edge!(from: 2, to: 3, with: 0)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 3}] == 0
  end

  # ============= Undirected Graph Tests =============

  test "johnson_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Undirected, so both directions should work
    assert distances[{1, 2}] == 5
    assert distances[{2, 1}] == 5
    assert distances[{1, 3}] == 15
    assert distances[{3, 1}] == 15
  end

  # ============= Complex Graph Tests =============

  test "johnson_complex_graph_test" do
    # More complex graph with negative edges
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge!(from: 1, to: 2, with: 3)
      |> Yog.add_edge!(from: 1, to: 3, with: 8)
      |> Yog.add_edge!(from: 1, to: 5, with: -4)
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 2, to: 5, with: 7)
      |> Yog.add_edge!(from: 3, to: 2, with: 4)
      |> Yog.add_edge!(from: 4, to: 1, with: 2)
      |> Yog.add_edge!(from: 4, to: 3, with: -5)
      |> Yog.add_edge!(from: 5, to: 4, with: 6)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Check some all-pairs distances
    assert distances[{1, 1}] == 0
    assert distances[{1, 4}] == 2
    assert distances[{1, 3}] == -3
  end

  test "johnson_star_graph_test" do
    # Star graph: 1 is center connected to 2, 3, 4
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Center")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(4, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 2)
      |> Yog.add_edge!(from: 1, to: 4, with: 3)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 2}] == 1
    assert distances[{1, 3}] == 2
    assert distances[{1, 4}] == 3
  end

  # ============= Transitive Paths Tests =============

  test "johnson_transitive_path_test" do
    # Test that indirect paths are found
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Check transitive closure
    assert distances[{1, 2}] == 1
    assert distances[{1, 3}] == 2
    assert distances[{1, 4}] == 3
    assert distances[{2, 3}] == 1
    assert distances[{2, 4}] == 2
    assert distances[{3, 4}] == 1
  end

  test "johnson_multiple_intermediate_nodes_test" do
    # Path that goes through multiple intermediate nodes
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 1, to: 5, with: 10)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Should find path through intermediates (cost 4) not direct (cost 10)
    assert distances[{1, 5}] == 4
  end

  # ============= Sparse Graph Benefits =============

  test "johnson_sparse_graph_test" do
    # Johnson's is efficient for sparse graphs
    # Create a sparse graph with 6 nodes and 7 edges
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_node(6, "F")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: -2)
      |> Yog.add_edge!(from: 3, to: 4, with: 3)
      |> Yog.add_edge!(from: 1, to: 5, with: 5)
      |> Yog.add_edge!(from: 5, to: 6, with: -1)
      |> Yog.add_edge!(from: 4, to: 6, with: 2)
      |> Yog.add_edge!(from: 2, to: 6, with: 10)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Verify some paths
    assert distances[{1, 3}] == -1
    assert distances[{1, 6}] == 4
  end

  # ============= Reweighting Verification =============

  test "johnson_reweighting_preserves_paths_test" do
    # Verify that reweighting preserves shortest paths
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)
      |> Yog.add_edge!(from: 1, to: 3, with: 20)

    result = Johnson.johnson(graph, 0, &add/2, &subtract/2, &compare/2)

    assert {:ok, distances} = result
    # Should still find optimal path after reweighting
    assert distances[{1, 3}] == 15
  end
end
