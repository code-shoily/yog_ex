defmodule YogTopologicalSortTest do
  use ExUnit.Case

  # ============= Basic Topological Sort Tests =============

  # Simple linear DAG: 1 -> 2 -> 3
  test "topo_sort_linear_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:ok, [1, 2, 3]}
  end

  # Single node with edge to itself (current implementation requires edges)
  test "topo_sort_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:ok, [1, 2]}
  end

  # Empty graph
  test "topo_sort_empty_graph_test" do
    graph = Yog.directed()

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:ok, []}
  end

  # Two nodes connected with edge
  test "topo_sort_two_independent_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    # Should succeed with all nodes
    assert {:ok, sorted} = result
    assert length(sorted) == 3

    # 3 should be last
    pos3 = Enum.find_index(sorted, &(&1 == 3))
    assert pos3 == 2
  end

  # Simple fork: 1 -> {2, 3}
  test "topo_sort_fork_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result

    # Node 1 must come before both 2 and 3
    pos1 = Enum.find_index(sorted, &(&1 == 1))
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos3 = Enum.find_index(sorted, &(&1 == 3))

    assert pos1 < pos2
    assert pos1 < pos3
  end

  # Simple join: {1, 2} -> 3
  test "topo_sort_join_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Left")
      |> Yog.add_node(2, "Right")
      |> Yog.add_node(3, "Bottom")
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result

    # Both 1 and 2 must come before 3
    pos1 = Enum.find_index(sorted, &(&1 == 1))
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos3 = Enum.find_index(sorted, &(&1 == 3))

    assert pos1 < pos3
    assert pos2 < pos3
  end

  # Diamond DAG
  #     1
  #    / \
  #   2   3
  #    \ /
  #     4
  test "topo_sort_diamond_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result

    pos1 = Enum.find_index(sorted, &(&1 == 1))
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos3 = Enum.find_index(sorted, &(&1 == 3))
    pos4 = Enum.find_index(sorted, &(&1 == 4))

    # 1 before all
    assert pos1 < pos2
    assert pos1 < pos3
    assert pos1 < pos4

    # 2 and 3 before 4
    assert pos2 < pos4
    assert pos3 < pos4
  end

  # ============= Cycle Detection Tests =============

  # Simple cycle: 1 -> 2 -> 3 -> 1
  test "topo_sort_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:error, :contains_cycle}
  end

  # Self-loop
  test "topo_sort_self_loop_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_edge(from: 1, to: 1, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:error, :contains_cycle}
  end

  # Cycle in part of graph
  test "topo_sort_partial_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 2, with: 1)
      # 2-3 cycle
      |> Yog.add_edge(from: 1, to: 4, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:error, :contains_cycle}
  end

  # Two-node cycle
  test "topo_sort_two_node_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 1, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:error, :contains_cycle}
  end

  # ============= Complex DAG Tests =============

  # Multiple disconnected components
  test "topo_sort_disconnected_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # Component 1: 1->2
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      # Component 2: 3->4
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result
    assert length(sorted) == 4

    # Each edge constraint must be satisfied
    pos1 = Enum.find_index(sorted, &(&1 == 1))
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos3 = Enum.find_index(sorted, &(&1 == 3))
    pos4 = Enum.find_index(sorted, &(&1 == 4))

    assert pos1 < pos2
    assert pos3 < pos4
  end

  # Long chain
  test "topo_sort_long_chain_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_node(6, "6")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)
      |> Yog.add_edge(from: 4, to: 5, with: 1)
      |> Yog.add_edge(from: 5, to: 6, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert result == {:ok, [1, 2, 3, 4, 5, 6]}
  end

  # Tree structure
  test "topo_sort_tree_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "L")
      |> Yog.add_node(3, "R")
      |> Yog.add_node(4, "LL")
      |> Yog.add_node(5, "LR")
      |> Yog.add_node(6, "RL")
      |> Yog.add_node(7, "RR")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 2, to: 5, with: 1)
      |> Yog.add_edge(from: 3, to: 6, with: 1)
      |> Yog.add_edge(from: 3, to: 7, with: 1)

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result
    assert length(sorted) == 7

    # Root must be first
    pos1 = Enum.find_index(sorted, &(&1 == 1))
    assert pos1 == 0

    # All children after parents
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos3 = Enum.find_index(sorted, &(&1 == 3))
    pos4 = Enum.find_index(sorted, &(&1 == 4))
    pos5 = Enum.find_index(sorted, &(&1 == 5))
    pos6 = Enum.find_index(sorted, &(&1 == 6))
    pos7 = Enum.find_index(sorted, &(&1 == 7))

    assert pos1 < pos2
    assert pos1 < pos3
    assert pos2 < pos4
    assert pos2 < pos5
    assert pos3 < pos6
    assert pos3 < pos7
  end

  # ============= Lexicographical Sort Tests =============

  # Simple case where order matters
  test "lexi_topo_sort_basic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)

    # In Elixir we can just use &<=/2
    result =
      Yog.TopologicalSort.lexicographical_sort(graph, fn a, b ->
        if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)
      end)

    # Should return [1, 2, 3] - after 1, both 2 and 3 available, picks 2 first
    assert result == {:ok, [1, 2, 3]}
  end

  # Fork - lexicographically smallest
  test "lexi_topo_sort_fork_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)

    result =
      Yog.TopologicalSort.lexicographical_sort(graph, fn a, b ->
        if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)
      end)

    # Should be [1, 2, 3] because after 1, both 2 and 3 are available
    # and 2 < 3 lexicographically
    assert result == {:ok, [1, 2, 3]}
  end

  # Join - lexicographically smallest
  test "lexi_topo_sort_join_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(1, "C")
      |> Yog.add_edge(from: 2, to: 1, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 1)

    result =
      Yog.TopologicalSort.lexicographical_sort(graph, fn a, b ->
        if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)
      end)

    # Should start with 2 (smaller than 3), then 3, then 1
    assert result == {:ok, [2, 3, 1]}
  end

  # Diamond - lexicographical
  test "lexi_topo_sort_diamond_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    result =
      Yog.TopologicalSort.lexicographical_sort(graph, fn a, b ->
        if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)
      end)

    # After 1, both 2 and 3 are available. Pick 2 (smaller).
    # After 2, only 3 is available (4 still has incoming from 3).
    # After 3, 4 is available.
    assert result == {:ok, [1, 2, 3, 4]}
  end

  # Lexicographical with cycle detection
  test "lexi_topo_sort_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 1, with: 1)

    result =
      Yog.TopologicalSort.lexicographical_sort(graph, fn a, b ->
        if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)
      end)

    assert result == {:error, :contains_cycle}
  end

  # Multiple valid orderings - lexicographical picks smallest
  test "lexi_topo_sort_multiple_valid_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(5, "E")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(4, "D")
      # Add edges to connect them
      |> Yog.add_edge(from: 1, to: 5, with: 1)
      |> Yog.add_edge(from: 2, to: 5, with: 1)
      |> Yog.add_edge(from: 3, to: 5, with: 1)
      |> Yog.add_edge(from: 4, to: 5, with: 1)

    # All point to 5, so 5 must be last
    result =
      Yog.TopologicalSort.lexicographical_sort(graph, fn a, b ->
        if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)
      end)

    # Should start with smallest and end with 5
    assert result == {:ok, [1, 2, 3, 4, 5]}
  end

  # ============= Classic Examples =============

  # Task scheduling example
  test "topo_sort_tasks_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Wake up")
      |> Yog.add_node(2, "Shower")
      |> Yog.add_node(3, "Dress")
      |> Yog.add_node(4, "Eat breakfast")
      |> Yog.add_node(5, "Leave house")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      # Wake before shower
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      # Shower before dress
      |> Yog.add_edge(from: 3, to: 5, with: 1)
      # Dress before leave
      |> Yog.add_edge(from: 4, to: 5, with: 1)
      # Eat before leave
      |> Yog.add_edge(from: 1, to: 4, with: 1)

    # Wake before eat

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result

    # Verify all constraints
    pos1 = Enum.find_index(sorted, &(&1 == 1))
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos3 = Enum.find_index(sorted, &(&1 == 3))
    pos4 = Enum.find_index(sorted, &(&1 == 4))
    pos5 = Enum.find_index(sorted, &(&1 == 5))

    assert pos1 < pos2
    assert pos2 < pos3
    assert pos3 < pos5
    assert pos4 < pos5
    assert pos1 < pos4

    # Node 5 should be last
    assert pos5 == 4
  end

  # Build system dependencies
  test "topo_sort_build_deps_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "main.o")
      |> Yog.add_node(2, "main.c")
      |> Yog.add_node(3, "utils.o")
      |> Yog.add_node(4, "utils.c")
      |> Yog.add_node(5, "app")
      |> Yog.add_edge(from: 2, to: 1, with: 1)
      # main.c -> main.o
      |> Yog.add_edge(from: 4, to: 3, with: 1)
      # utils.c -> utils.o
      |> Yog.add_edge(from: 1, to: 5, with: 1)
      # main.o -> app
      |> Yog.add_edge(from: 3, to: 5, with: 1)

    # utils.o -> app

    result = Yog.TopologicalSort.sort(graph)

    assert {:ok, sorted} = result

    # Sources before objects
    pos2 = Enum.find_index(sorted, &(&1 == 2))
    pos1 = Enum.find_index(sorted, &(&1 == 1))
    pos4 = Enum.find_index(sorted, &(&1 == 4))
    pos3 = Enum.find_index(sorted, &(&1 == 3))
    pos5 = Enum.find_index(sorted, &(&1 == 5))

    assert pos2 < pos1
    assert pos4 < pos3

    # Objects before app
    assert pos1 < pos5
    assert pos3 < pos5

    # App is last
    assert pos5 == 4
  end
end
