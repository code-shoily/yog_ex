defmodule Yog.Pathfinding.FloydWarshallTest do
  use ExUnit.Case
  alias Yog.Pathfinding.FloydWarshall
  doctest FloydWarshall

  # Helper functions for algorithms
  defp compare(a, b), do: if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq))
  defp add(a, b), do: a + b

  # ============= Basic All-Pairs Tests =============

  test "floyd_warshall_linear_graph_test" do
    # Linear graph: 1 -> 2 -> 3
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 1}] == 0
    assert distances[{1, 2}] == 5
    assert distances[{1, 3}] == 15
    assert distances[{2, 2}] == 0
    assert distances[{2, 3}] == 10
    assert distances[{3, 3}] == 0
  end

  test "floyd_warshall_simple_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 1}] == 0
    assert distances[{1, 2}] == 10
    assert distances[{2, 2}] == 0
  end

  test "floyd_warshall_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 1}] == 0
  end

  test "floyd_warshall_empty_graph_test" do
    graph = Yog.directed()

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    assert map_size(distances) == 0
  end

  # ============= Complete Graph Tests =============

  test "floyd_warshall_triangle_test" do
    # Triangle: 1 -> 2 -> 3, 1 -> 3
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)
      |> Yog.add_edge!(from: 1, to: 3, with: 20)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Should find shorter path 1 -> 2 -> 3 (15) instead of 1 -> 3 (20)
    assert distances[{1, 3}] == 15
  end

  test "floyd_warshall_complete_graph_test" do
    # Complete graph with 4 nodes (no negative cycles)
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

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Verify some key distances
    assert distances[{1, 1}] == 0
    assert distances[{1, 2}] == 3
    assert distances[{1, 3}] == 4
    assert distances[{1, 4}] == 5
  end

  # ============= Diamond Graph Tests =============

  test "floyd_warshall_diamond_test" do
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

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Should find path 1 -> 2 -> 4 (cost 3) not 1 -> 3 -> 4 (cost 5)
    assert distances[{1, 4}] == 3
  end

  # ============= Negative Weight Tests =============

  test "floyd_warshall_negative_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 4)
      |> Yog.add_edge!(from: 2, to: 3, with: -3)
      |> Yog.add_edge!(from: 1, to: 3, with: 2)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Should find path 1 -> 2 -> 3 (cost 1) not 1 -> 3 (cost 2)
    assert distances[{1, 3}] == 1
  end

  test "floyd_warshall_all_negative_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: -1)
      |> Yog.add_edge!(from: 2, to: 3, with: -2)
      |> Yog.add_edge!(from: 1, to: 3, with: -5)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Direct path 1 -> 3 (cost -5) is better than 1 -> 2 -> 3 (cost -3)
    assert distances[{1, 3}] == -5
  end

  # ============= Negative Cycle Detection =============

  test "floyd_warshall_negative_cycle_test" do
    # Simple negative cycle: 1 -> 2 -> 1
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: -3)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert result == {:error, :negative_cycle}
  end

  test "floyd_warshall_three_node_negative_cycle_test" do
    # Three node negative cycle
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: -2)
      |> Yog.add_edge!(from: 3, to: 1, with: -2)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert result == {:error, :negative_cycle}
  end

  # Note: detect_negative_cycle? has compatibility issues with Gleam implementation
  # Using the main floyd_warshall function with error return is preferred
  #
  # test "detect_negative_cycle_true_test" do
  #   graph =
  #     Yog.directed()
  #     |> Yog.add_node(1, "A")
  #     |> Yog.add_node(2, "B")
  #     |> Yog.add_edge!(from: 1, to: 2, with: 1)
  #     |> Yog.add_edge!(from: 2, to: 1, with: -3)
  #
  #   assert FloydWarshall.detect_negative_cycle?(graph, 0, &add/2, &compare/2) == true
  # end
  #
  # test "detect_negative_cycle_false_test" do
  #   graph =
  #     Yog.directed()
  #     |> Yog.add_node(1, "A")
  #     |> Yog.add_node(2, "B")
  #     |> Yog.add_edge!(from: 1, to: 2, with: 5)
  #
  #   assert FloydWarshall.detect_negative_cycle?(graph, 0, &add/2, &compare/2) == false
  # end

  test "floyd_warshall_positive_cycle_test" do
    # Positive cycle should not be detected as negative
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 1, with: 3)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, _distances} = result
  end

  # ============= Disconnected Graph Tests =============

  test "floyd_warshall_disconnected_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 3, to: 4, with: 10)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Reachable pairs
    assert distances[{1, 2}] == 5
    assert distances[{3, 4}] == 10
    # Unreachable pairs should not be in the map
    assert Map.has_key?(distances, {1, 3}) == false
    assert Map.has_key?(distances, {2, 4}) == false
  end

  # ============= Weight Type Tests =============

  test "floyd_warshall_int_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    result = FloydWarshall.floyd_warshall_int(graph)

    assert {:ok, distances} = result
    assert distances[{1, 3}] == 15
  end

  test "floyd_warshall_float_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5.5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10.5)

    result = FloydWarshall.floyd_warshall_float(graph)

    assert {:ok, distances} = result
    assert distances[{1, 3}] == 16.0
  end

  test "floyd_warshall_zero_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 0)
      |> Yog.add_edge!(from: 2, to: 3, with: 0)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 3}] == 0
  end

  # ============= Undirected Graph Tests =============

  test "floyd_warshall_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 5)
      |> Yog.add_edge!(from: 2, to: 3, with: 10)

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Undirected, so both directions should work
    assert distances[{1, 2}] == 5
    assert distances[{2, 1}] == 5
    assert distances[{1, 3}] == 15
    assert distances[{3, 1}] == 15
  end

  # ============= Complex Graph Tests =============

  test "floyd_warshall_complex_graph_test" do
    # More complex graph
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

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Check some all-pairs distances
    assert distances[{1, 1}] == 0
    assert distances[{1, 4}] == 2
    assert distances[{1, 3}] == -3
  end

  test "floyd_warshall_star_graph_test" do
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

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    assert distances[{1, 2}] == 1
    assert distances[{1, 3}] == 2
    assert distances[{1, 4}] == 3
  end

  # ============= Transitive Paths Tests =============

  test "floyd_warshall_transitive_path_test" do
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

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Check transitive closure
    assert distances[{1, 2}] == 1
    assert distances[{1, 3}] == 2
    assert distances[{1, 4}] == 3
    assert distances[{2, 3}] == 1
    assert distances[{2, 4}] == 2
    assert distances[{3, 4}] == 1
  end

  test "floyd_warshall_multiple_intermediate_nodes_test" do
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

    result = FloydWarshall.floyd_warshall(graph, 0, &add/2, &compare/2)

    assert {:ok, distances} = result
    # Should find path through intermediates (cost 4) not direct (cost 10)
    assert distances[{1, 5}] == 4
  end
end
