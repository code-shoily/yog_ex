defmodule YogBipartiteTest do
  use ExUnit.Case

  alias Yog.Bipartite

  # ============= Bipartite Detection Tests =============

  test "is_bipartite_empty_test" do
    graph = Yog.undirected()
    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_single_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)

    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_path_test" do
    # Path: 1 - 2 - 3 - 4 (always bipartite)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)

    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_even_cycle_test" do
    # Square: 1 - 2 - 3 - 4 - 1 (even cycle is bipartite)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)
      |> Yog.add_edge(from: 4, to: 1, weight: 1)

    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_odd_cycle_test" do
    # Triangle: 1 - 2 - 3 - 1 (odd cycle is NOT bipartite)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert Bipartite.is_bipartite?(graph) == false
  end

  test "is_bipartite_complete_bipartite_test" do
    # K_2,3: Complete bipartite with left={1,2}, right={3,4,5}
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 1, to: 5, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)

    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_tree_test" do
    # Tree (always bipartite)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)

    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_disconnected_components_test" do
    # Two disconnected even cycles (both bipartite)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 1, weight: 1)
      |> Yog.add_node(5, nil)
      |> Yog.add_node(6, nil)
      |> Yog.add_node(7, nil)
      |> Yog.add_node(8, nil)
      |> Yog.add_edge(from: 5, to: 6, weight: 1)
      |> Yog.add_edge(from: 6, to: 7, weight: 1)
      |> Yog.add_edge(from: 7, to: 8, weight: 1)
      |> Yog.add_edge(from: 8, to: 5, weight: 1)

    assert Bipartite.is_bipartite?(graph) == true
  end

  test "is_bipartite_disconnected_with_odd_cycle_test" do
    # One even cycle + one odd cycle (not bipartite because of odd cycle)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)
      |> Yog.add_edge(from: 4, to: 1, weight: 1)
      |> Yog.add_node(5, nil)
      |> Yog.add_node(6, nil)
      |> Yog.add_node(7, nil)
      |> Yog.add_edge(from: 5, to: 6, weight: 1)
      |> Yog.add_edge(from: 6, to: 7, weight: 1)
      |> Yog.add_edge(from: 7, to: 5, weight: 1)

    assert Bipartite.is_bipartite?(graph) == false
  end

  # ============= Partition Tests =============

  test "partition_path_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, %{left: left, right: right}} ->
        # Should partition as {1, 3} and {2, 4}
        left_size = MapSet.size(left)
        right_size = MapSet.size(right)

        assert left_size == 2
        assert right_size == 2

        # Verify alternating pattern
        if MapSet.member?(left, 1) do
          assert MapSet.member?(left, 3)
          assert MapSet.member?(right, 2)
          assert MapSet.member?(right, 4)
        else
          assert MapSet.member?(right, 1)
          assert MapSet.member?(right, 3)
          assert MapSet.member?(left, 2)
          assert MapSet.member?(left, 4)
        end
    end
  end

  test "partition_returns_error_for_odd_cycle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    case Bipartite.partition(graph) do
      {:error, :not_bipartite} -> assert true
      {:ok, _} -> flunk("Expected partition to fail for odd cycle")
    end
  end

  # ============= Maximum Matching Tests =============

  test "maximum_matching_perfect_test" do
    # K_2,2: Complete bipartite graph with 2 vertices on each side
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)

        # Perfect matching: all 4 vertices matched (2 edges)
        assert length(matching) == 2

        # Verify all vertices are matched
        matched_left = Enum.map(matching, fn {u, _v} -> u end) |> MapSet.new()
        matched_right = Enum.map(matching, fn {_u, v} -> v end) |> MapSet.new()

        assert MapSet.size(matched_left) == 2
        assert MapSet.size(matched_right) == 2
    end
  end

  test "maximum_matching_path_test" do
    # Path: 1 - 2 - 3 - 4
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)

        # Maximum matching size is 2 (either 1-2, 3-4 or just one edge depending on partition)
        # Actually, the maximum matching in a path is floor(n/2) = 2
        assert length(matching) == 2
    end
  end

  test "maximum_matching_unbalanced_test" do
    # K_2,3: 2 vertices on left, 3 on right
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 1, to: 5, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)

        # Maximum matching: min(2, 3) = 2
        assert length(matching) == 2
    end
  end

  test "maximum_matching_empty_graph_test" do
    graph = Yog.undirected()

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)
        assert length(matching) == 0
    end
  end

  test "maximum_matching_no_edges_test" do
    # Bipartite but no edges
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)
        assert length(matching) == 0
    end
  end

  test "maximum_matching_augmenting_path_test" do
    # Test case where augmenting path algorithm needs to rematch
    # Graph: 1-3, 1-4, 2-4
    # First greedy match: 1-3
    # Then for 2: 2-4 is available
    # Result: {1-3, 2-4} or {1-4, 2-?} - wait, 2 only connects to 4
    # So we need: 1-3, 2-4 (both matched)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)

        # Maximum matching: 2 edges
        assert length(matching) == 2
    end
  end

  test "maximum_matching_directed_graph_test" do
    # Test with directed graph (should treat as undirected for bipartite purposes)
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)

    case Bipartite.partition(graph) do
      {:error, _} ->
        flunk("Expected partition to succeed")

      {:ok, p} ->
        matching = Bipartite.maximum_matching(graph, p)

        # Should still find a matching of size 2
        assert length(matching) == 2
    end
  end
end
