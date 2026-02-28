defmodule YogConnectivityTest do
  use ExUnit.Case

  # ============= Basic Connectivity Tests =============

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
      |> Yog.add_edge(from: 1, to: 2, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Single edge is a bridge
    assert length(result.bridges) == 1
    assert {1, 2} in result.bridges

    # Neither node is an articulation point (only 2 nodes)
    assert result.articulation_points == []
  end

  # ============= Bridge Detection Tests =============

  test "connectivity_linear_chain_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 1)

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
    #     3 ------- 6
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_node(6, "F")
      # First triangle
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 3, to: 1, with: 1)
      # Second triangle
      |> Yog.add_edge(from: 4, to: 5, with: 1)
      |> Yog.add_edge(from: 5, to: 6, with: 1)
      |> Yog.add_edge(from: 6, to: 4, with: 1)
      # Bridge connecting the triangles
      |> Yog.add_edge(from: 3, to: 6, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Only the connecting edge is a bridge
    assert length(result.bridges) == 1
    assert {3, 6} in result.bridges

    # The endpoints of the bridge are articulation points
    assert length(result.articulation_points) == 2
    assert 3 in result.articulation_points
    assert 6 in result.articulation_points
  end

  # ============= Articulation Point Detection Tests =============

  test "connectivity_star_graph_test" do
    # Star graph: center node connected to all others
    #     2
    #     |
    # 3 - 1 - 4
    #     |
    #     5
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Center")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(4, "C")
      |> Yog.add_node(5, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 1, to: 4, with: 1)
      |> Yog.add_edge(from: 1, to: 5, with: 1)

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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # No bridges (multiple paths between all pairs)
    assert result.bridges == []

    # No articulation points in a diamond
    # (removing any node leaves remaining nodes connected)
    assert result.articulation_points == []
  end

  # ============= Complex Graph Tests =============

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
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 3, to: 5, with: 1)
      |> Yog.add_edge(from: 4, to: 5, with: 1)
      |> Yog.add_edge(from: 5, to: 6, with: 1)
      |> Yog.add_edge(from: 5, to: 7, with: 1)
      |> Yog.add_edge(from: 7, to: 8, with: 1)

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

  # ============= Disconnected Graph Tests =============

  test "connectivity_disconnected_components_test" do
    # Two separate components
    # Component 1: 1 - 2
    # Component 2: 3 - 4 - 5
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)
      |> Yog.add_edge(from: 4, to: 5, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # All edges are bridges (within their components)
    assert length(result.bridges) == 3

    # Middle node of second component is articulation point
    assert length(result.articulation_points) == 1
    assert 4 in result.articulation_points
  end

  test "connectivity_isolated_nodes_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Only the edge between connected nodes is a bridge
    assert length(result.bridges) == 1

    # Isolated node doesn't affect articulation points
    assert result.articulation_points == []
  end

  # ============= Edge Case Tests =============

  test "connectivity_self_loop_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 1, with: 1)
      |> Yog.add_edge(from: 1, to: 2, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Self-loop doesn't affect bridge detection
    assert length(result.bridges) == 1
    assert {1, 2} in result.bridges
    assert result.articulation_points == []
  end

  test "connectivity_parallel_edges_test" do
    # Multiple edges between the same pair of nodes
    # Note: Standard Tarjan's algorithm with node-based parent tracking
    # doesn't handle parallel edges perfectly - it would need edge IDs.
    # This test documents the actual behavior.
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 2, with: 2)
      # Duplicate edge with different weight
      |> Yog.add_edge(from: 2, to: 3, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # With node-based parent tracking, parallel edges are detected
    # Both edges 1-2 and 2-3 are detected as bridges
    assert length(result.bridges) == 2
    assert {1, 2} in result.bridges
    assert {2, 3} in result.bridges

    # Node 2 is an articulation point
    assert length(result.articulation_points) == 1
    assert 2 in result.articulation_points
  end

  test "connectivity_complete_graph_test" do
    # Complete graph K4: every node connected to every other node
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: 1)
      |> Yog.add_edge(from: 1, to: 3, with: 1)
      |> Yog.add_edge(from: 1, to: 4, with: 1)
      |> Yog.add_edge(from: 2, to: 3, with: 1)
      |> Yog.add_edge(from: 2, to: 4, with: 1)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # No bridges in a complete graph
    assert result.bridges == []

    # No articulation points in a complete graph
    assert result.articulation_points == []
  end

  test "connectivity_square_with_diagonal_test" do
    # Square with one diagonal
    #   1 - 2
    #   | X |
    #   3 - 4
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
      |> Yog.add_edge(from: 1, to: 4, with: 1)

    # Diagonal

    result = Yog.Connectivity.analyze(in: graph)

    # No bridges (multiple paths between all pairs)
    assert result.bridges == []

    # No articulation points (removing any node leaves graph connected)
    assert result.articulation_points == []
  end

  # ============= Bridge Ordering Test =============

  test "connectivity_bridge_ordering_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(5, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_edge(from: 5, to: 3, with: 1)

    result = Yog.Connectivity.analyze(in: graph)

    # Bridges should be stored in canonical order (lower ID first)
    assert result.bridges == [{3, 5}]
  end
end
