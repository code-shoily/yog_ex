defmodule YogComponentsTest do
  use ExUnit.Case

  # ============= Connectivity Analysis Tests (Bridges & Articulation Points) =============

  test "connectivity_empty_graph_test" do
    graph = Yog.undirected()
    result = Yog.Connectivity.analyze(in: graph)

    assert result.bridges == []
    assert result.articulation_points == []
  end

  test "connectivity_single_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")

    result = Yog.Connectivity.analyze(in: graph)

    assert result.bridges == []
    assert result.articulation_points == []
  end

  test "connectivity_two_nodes_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Single edge is a bridge
    assert length(result.bridges) == 1
    assert {1, 2} in result.bridges

    # Neither node is an articulation point (only 2 nodes)
    assert result.articulation_points == []
  end

  test "connectivity_linear_chain_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # All edges are bridges in a linear chain
    assert length(result.bridges) == 3
    assert {1, 2} in result.bridges
    assert {2, 3} in result.bridges
    assert {3, 4} in result.bridges

    # Middle nodes are articulation points
    assert length(result.articulation_points) == 2
    assert 2 in result.articulation_points
    assert 3 in result.articulation_points
  end

  test "connectivity_triangle_no_bridges_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # No bridges in a cycle (triangle)
    assert result.bridges == []
    # No articulation points in a triangle
    assert result.articulation_points == []
  end

  test "connectivity_bridge_between_triangles_test" do
    # Two triangles connected by a single edge (bridge)
    #   1 - 2      4 - 5
    #    \ /        \ /
    #     3 -------- 6
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_node(6, "F")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 6, with: 1)
      |> Yog.add_edge!(from: 6, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 6, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Only the connecting edge is a bridge
    assert length(result.bridges) == 1
    assert {3, 6} in result.bridges

    # The endpoints of the bridge are articulation points
    assert length(result.articulation_points) == 2
    assert 3 in result.articulation_points
    assert 6 in result.articulation_points
  end

  test "connectivity_star_graph_test" do
    # Star graph: node 1 connected to all others
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Center")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(4, "C")
      |> Yog.add_node(5, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 1, to: 4, with: 1)
      |> Yog.add_edge!(from: 1, to: 5, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # All edges are bridges in a star
    assert length(result.bridges) == 4

    # Only the center is an articulation point
    assert length(result.articulation_points) == 1
    assert 1 in result.articulation_points
  end

  test "connectivity_diamond_test" do
    # Diamond shape: two paths from 1 to 4
    #   1
    #  / \
    # 2   3
    #  \ /
    #   4
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # No bridges (multiple paths between all pairs)
    assert result.bridges == []
    # No articulation points in a diamond
    assert result.articulation_points == []
  end

  test "connectivity_complex_graph_test" do
    # Complex graph with multiple bridges and articulation points
    #     1 - 2 - 3
    #         |   |
    #         4 - 5 - 6
    #             |
    #             7 - 8
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_node(6, "F")
      |> Yog.add_node(7, "G")
      |> Yog.add_node(8, "H")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 5, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 6, with: 1)
      |> Yog.add_edge!(from: 5, to: 7, with: 1)
      |> Yog.add_edge!(from: 7, to: 8, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Bridges: 1-2, 5-6, 5-7, 7-8
    assert length(result.bridges) == 4
    assert {1, 2} in result.bridges
    assert {5, 6} in result.bridges
    assert {5, 7} in result.bridges
    assert {7, 8} in result.bridges

    # Articulation points: 2, 5, 7
    assert length(result.articulation_points) == 3
    assert 2 in result.articulation_points
    assert 5 in result.articulation_points
    assert 7 in result.articulation_points
  end

  test "connectivity_disconnected_graph_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # All edges are bridges (within their components)
    assert length(result.bridges) == 3

    # Middle node of second component is articulation point
    assert length(result.articulation_points) == 1
    assert 4 in result.articulation_points
  end

  test "connectivity_complete_graph_test" do
    # Complete graph K4 - no bridges or articulation points
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 1, to: 4, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # No bridges in a complete graph
    assert result.bridges == []
    # No articulation points in a complete graph
    assert result.articulation_points == []
  end

  test "connectivity_bridge_ordering_test" do
    # Bridges should be stored in canonical order (lower ID first)
    graph =
      Yog.undirected()
      |> Yog.add_node(5, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_edge!(from: 5, to: 3, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Bridge should be {3, 5} (ordered)
    assert result.bridges == [{3, 5}]
  end

  # ============= Basic SCC Tests =============

  # Single node with no edges
  test "scc_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    result = Yog.Components.scc(graph)

    # Each node is its own SCC when no cycles
    assert length(result) == 2
  end

  # Empty graph
  test "scc_empty_graph_test" do
    graph = Yog.directed()
    result = Yog.Components.scc(graph)
    assert result == []
  end

  # Two separate nodes
  test "scc_two_separate_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)

    result = Yog.Components.scc(graph)

    # Linear chain - each node is separate SCC
    assert length(result) == 3
  end

  # Simple cycle - single SCC
  test "scc_simple_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

    result = Yog.Components.scc(graph)

    # All three nodes form one SCC
    assert length(result) == 1

    [component] = result
    assert length(component) == 3
    assert 1 in component
    assert 2 in component
    assert 3 in component
  end

  # Self-loop - SCC of size 1
  test "scc_self_loop_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_edge!(from: 1, to: 1, with: 1)

    result = Yog.Components.scc(graph)

    assert length(result) == 1
    assert result == [[1]]
  end

  # Two-node cycle
  test "scc_two_node_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)

    result = Yog.Components.scc(graph)

    assert length(result) == 1

    [component] = result
    assert length(component) == 2
  end

  # ============= Multiple SCC Tests =============

  # Two separate cycles
  test "scc_two_separate_cycles_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # Cycle 1: 1->2->1
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      # Cycle 2: 3->4->3
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 3, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 2 SCCs
    assert length(result) == 2

    # Each should have 2 nodes
    assert Enum.all?(result, fn comp -> length(comp) == 2 end)
  end

  # Mixed: cycle and non-cycle nodes
  test "scc_mixed_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # Cycle: 1->2->3->1
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)
      # Non-cycle node: 4
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 2 SCCs: {1,2,3} and {4}
    assert length(result) == 2

    # One component should have 3 nodes, one should have 1
    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [1, 3]
  end

  # ============= Classic Test Cases =============

  # Kosaraju's example graph
  test "scc_kosaraju_example_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 4, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 2 SCCs: {1,2,3} and {4,5}
    assert length(result) == 2

    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [2, 3]
  end

  # Diamond with cycle at bottom
  test "scc_diamond_with_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 2, with: 1)

    # Cycle: 2->4->2

    result = Yog.Components.scc(graph)

    # Should have 3 SCCs: {1}, {3}, {2,4}
    assert length(result) == 3

    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [1, 1, 2]
  end

  # Complete directed graph (all pairs connected both ways)
  test "scc_complete_graph_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      # All edges in both directions
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 2, with: 1)

    result = Yog.Components.scc(graph)

    # All nodes form one SCC
    assert length(result) == 1

    [component] = result
    assert length(component) == 3
  end

  # ============= Complex Graph Tests =============

  # Multiple cycles connected in chain
  test "scc_chain_of_cycles_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_node(6, "6")
      # Cycle 1: 1<->2
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      # Connection: 2->3
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      # Cycle 2: 3<->4
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 3, with: 1)
      # Connection: 4->5
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      # Cycle 3: 5<->6
      |> Yog.add_edge!(from: 5, to: 6, with: 1)
      |> Yog.add_edge!(from: 6, to: 5, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 3 SCCs
    assert length(result) == 3

    # Each should have 2 nodes
    assert Enum.all?(result, fn comp -> length(comp) == 2 end)
  end

  # Large SCC with small SCCs
  test "scc_large_and_small_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_node(6, "6")
      |> Yog.add_node(7, "7")
      # Large cycle: 1->2->3->4->1
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 1, with: 1)
      # Small cycle: 5<->6
      |> Yog.add_edge!(from: 5, to: 6, with: 1)
      |> Yog.add_edge!(from: 6, to: 5, with: 1)
      # Single node
      |> Yog.add_edge!(from: 7, to: 1, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 3 SCCs
    assert length(result) == 3

    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [1, 2, 4]
  end

  # Tree structure (no cycles)
  test "scc_tree_no_cycles_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Root")
      |> Yog.add_node(2, "L")
      |> Yog.add_node(3, "R")
      |> Yog.add_node(4, "LL")
      |> Yog.add_node(5, "LR")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 2, to: 5, with: 1)

    result = Yog.Components.scc(graph)

    # Each node is its own SCC (no cycles)
    assert length(result) == 5

    # Each component has 1 node
    assert Enum.all?(result, fn comp -> length(comp) == 1 end)
  end

  # ============= Edge Cases =============

  # Graph with all self-loops
  test "scc_all_self_loops_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 1, with: 1)
      |> Yog.add_edge!(from: 2, to: 2, with: 1)
      |> Yog.add_edge!(from: 3, to: 3, with: 1)

    result = Yog.Components.scc(graph)

    # Each node is its own SCC
    assert length(result) == 3

    assert Enum.all?(result, fn comp -> length(comp) == 1 end)
  end

  # Single large cycle
  test "scc_single_large_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_node(6, "6")
      |> Yog.add_node(7, "7")
      |> Yog.add_node(8, "8")
      # Cycle: 1->2->3->4->5->6->7->8->1
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 6, with: 1)
      |> Yog.add_edge!(from: 6, to: 7, with: 1)
      |> Yog.add_edge!(from: 7, to: 8, with: 1)
      |> Yog.add_edge!(from: 8, to: 1, with: 1)

    result = Yog.Components.scc(graph)

    # All form one SCC
    assert length(result) == 1

    [component] = result
    assert length(component) == 8
  end

  # Nested cycles
  test "scc_nested_cycles_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      # Outer cycle: 1->2->3->4->5->1
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 1, with: 1)
      # Inner shortcuts
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 5, with: 1)

    result = Yog.Components.scc(graph)

    # All nodes form one large SCC
    assert length(result) == 1

    [component] = result
    assert length(component) == 5
  end

  # ============= Disconnected Components =============

  # Multiple disconnected subgraphs
  test "scc_disconnected_subgraphs_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A1")
      |> Yog.add_node(2, "A2")
      |> Yog.add_node(3, "B1")
      |> Yog.add_node(4, "B2")
      |> Yog.add_node(5, "C1")
      # Subgraph A: 1<->2
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      # Subgraph B: 3<->4
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 3, with: 1)
      # Subgraph C: 5 (isolated with self-loop)
      |> Yog.add_edge!(from: 5, to: 5, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 3 SCCs
    assert length(result) == 3

    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [1, 2, 2]
  end

  # ============= Real-World-Like Examples =============

  # Call graph with mutual recursion
  test "scc_call_graph_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "main")
      |> Yog.add_node(2, "funcA")
      |> Yog.add_node(3, "funcB")
      |> Yog.add_node(4, "funcC")
      |> Yog.add_node(5, "helper")
      # main calls funcA
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      # Mutual recursion: funcA <-> funcB
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 2, with: 1)
      # funcB calls funcC
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      # funcC calls helper
      |> Yog.add_edge!(from: 4, to: 5, with: 1)

    result = Yog.Components.scc(graph)

    # Should have 4 SCCs: {main}, {funcA,funcB}, {funcC}, {helper}
    assert length(result) == 4

    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [1, 1, 1, 2]
  end

  # Web page link structure
  test "scc_web_pages_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "index")
      |> Yog.add_node(2, "about")
      |> Yog.add_node(3, "contact")
      |> Yog.add_node(4, "blog")
      |> Yog.add_node(5, "archive")
      # index links to everything
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 1, to: 4, with: 1)
      # about and contact link to each other
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 2, with: 1)
      # blog and archive link to each other
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 4, with: 1)
      # Everything links back to index
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      |> Yog.add_edge!(from: 4, to: 1, with: 1)

    result = Yog.Components.scc(graph)

    # All pages are in one SCC because:
    # - index can reach all pages
    # - about/contact can reach index (and thus all)
    # - blog/archive can reach index (and thus all)
    assert length(result) == 1

    [component] = result
    assert length(component) == 5
  end

  # Package dependencies (should have no cycles in real world)
  test "scc_package_deps_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "app")
      |> Yog.add_node(2, "libA")
      |> Yog.add_node(3, "libB")
      |> Yog.add_node(4, "core")
      # app depends on libA and libB
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      # Both libs depend on core
      |> Yog.add_edge!(from: 2, to: 4, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    result = Yog.Components.scc(graph)

    # No cycles - each is its own SCC
    assert length(result) == 4

    assert Enum.all?(result, fn comp -> length(comp) == 1 end)
  end

  # ============= Kosaraju's Algorithm Tests =============

  test "kosaraju_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    result = Yog.Components.kosaraju(graph)
    assert length(result) == 2
  end

  test "kosaraju_empty_graph_test" do
    graph = Yog.directed()
    result = Yog.Components.kosaraju(graph)
    assert result == []
  end

  test "kosaraju_simple_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

    result = Yog.Components.kosaraju(graph)
    assert length(result) == 1
    [comp] = result
    assert Enum.sort(comp) == [1, 2, 3]
  end

  test "kosaraju_two_separate_cycles_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 3, with: 1)

    result = Yog.Components.kosaraju(graph)
    assert length(result) == 2
    assert Enum.all?(result, fn comp -> length(comp) == 2 end)
  end

  test "kosaraju_classic_example_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 4, with: 1)

    result = Yog.Components.kosaraju(graph)
    assert length(result) == 2
    sizes = result |> Enum.map(&length/1) |> Enum.sort()
    assert sizes == [2, 3]
  end

  test "kosaraju_chain_of_cycles_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "1")
      |> Yog.add_node(2, "2")
      |> Yog.add_node(3, "3")
      |> Yog.add_node(4, "4")
      |> Yog.add_node(5, "5")
      |> Yog.add_node(6, "6")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 1, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 3, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 6, with: 1)
      |> Yog.add_edge!(from: 6, to: 5, with: 1)

    result = Yog.Components.kosaraju(graph)
    assert length(result) == 3
    assert Enum.all?(result, fn comp -> length(comp) == 2 end)
  end
end
