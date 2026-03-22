defmodule Yog.Generator.ClassicTest do
  use ExUnit.Case

  alias Yog.Generator.Classic

  # ============= Complete Graph Tests =============

  test "complete_undirected_test" do
    graph = Classic.complete(4)

    assert Yog.Model.order(graph) == 4
    assert Yog.Model.type(graph) == :undirected

    # K4 should have 4*3/2 = 6 edges (undirected)
    # Each node should have degree 3
    assert length(Yog.neighbors(graph, 0)) == 3
    assert length(Yog.neighbors(graph, 1)) == 3
    assert length(Yog.neighbors(graph, 2)) == 3
    assert length(Yog.neighbors(graph, 3)) == 3
  end

  test "complete_directed_test" do
    graph = Classic.complete_with_type(3, :directed)

    assert Yog.Model.order(graph) == 3
    assert Yog.Model.type(graph) == :directed

    # Each node should have 2 outgoing edges (to other 2 nodes)
    assert length(Yog.successors(graph, 0)) == 2
    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 2
  end

  test "complete_single_node_test" do
    graph = Classic.complete(1)

    assert Yog.Model.order(graph) == 1
    assert length(Yog.neighbors(graph, 0)) == 0
  end

  # ============= Cycle Graph Tests =============

  test "cycle_test" do
    graph = Classic.cycle(5)

    assert Yog.Model.order(graph) == 5
    # In a cycle, each node has degree 2
    assert length(Yog.neighbors(graph, 0)) == 2
    assert length(Yog.neighbors(graph, 1)) == 2
    assert length(Yog.neighbors(graph, 2)) == 2
    assert length(Yog.neighbors(graph, 3)) == 2
    assert length(Yog.neighbors(graph, 4)) == 2
  end

  test "cycle_directed_test" do
    graph = Classic.cycle_with_type(4, :directed)

    assert Yog.Model.type(graph) == :directed
    # Each node should have 1 outgoing edge
    assert length(Yog.successors(graph, 0)) == 1
    assert length(Yog.successors(graph, 3)) == 1
  end

  test "cycle_too_small_test" do
    # Cycles require at least 3 nodes
    graph = Classic.cycle(2)

    # Should return empty graph
    assert Yog.Model.order(graph) == 0
  end

  # ============= Path Graph Tests =============

  test "path_test" do
    graph = Classic.path(4)

    assert Yog.Model.order(graph) == 4
    # End nodes have degree 1, middle nodes have degree 2
    # End
    assert length(Yog.neighbors(graph, 0)) == 1
    # Middle
    assert length(Yog.neighbors(graph, 1)) == 2
    # Middle
    assert length(Yog.neighbors(graph, 2)) == 2
    # End
    assert length(Yog.neighbors(graph, 3)) == 1
  end

  test "path_directed_test" do
    graph = Classic.path_with_type(3, :directed)

    assert Yog.Model.type(graph) == :directed
    # Should form a linear path
    assert length(Yog.successors(graph, 0)) == 1
    assert length(Yog.successors(graph, 1)) == 1
    # Last node
    assert length(Yog.successors(graph, 2)) == 0
  end

  test "path_single_node_test" do
    graph = Classic.path(1)

    assert Yog.Model.order(graph) == 1
    assert length(Yog.neighbors(graph, 0)) == 0
  end

  # ============= Star Graph Tests =============

  test "star_test" do
    graph = Classic.star(5)

    assert Yog.Model.order(graph) == 5
    # Node 0 is center with degree 4, others have degree 1
    # Center
    assert length(Yog.neighbors(graph, 0)) == 4
    # Leaf
    assert length(Yog.neighbors(graph, 1)) == 1
    # Leaf
    assert length(Yog.neighbors(graph, 2)) == 1
    # Leaf
    assert length(Yog.neighbors(graph, 3)) == 1
    # Leaf
    assert length(Yog.neighbors(graph, 4)) == 1
  end

  test "star_directed_test" do
    graph = Classic.star_with_type(4, :directed)

    assert Yog.Model.type(graph) == :directed
    # Center has 3 outgoing edges
    assert length(Yog.successors(graph, 0)) == 3
  end

  # ============= Wheel Graph Tests =============

  test "wheel_test" do
    graph = Classic.wheel(5)

    assert Yog.Model.order(graph) == 5
    # Center (node 0) connected to rim (4 nodes), rim forms a cycle
    # Center has degree 4, rim nodes have degree 3
    # Center
    assert length(Yog.neighbors(graph, 0)) == 4
    # Rim
    assert length(Yog.neighbors(graph, 1)) == 3
    # Rim
    assert length(Yog.neighbors(graph, 2)) == 3
    # Rim
    assert length(Yog.neighbors(graph, 3)) == 3
    # Rim
    assert length(Yog.neighbors(graph, 4)) == 3
  end

  # ============= Complete Bipartite Graph Tests =============

  test "complete_bipartite_test" do
    graph = Classic.complete_bipartite(3, 2)

    # Should have 3 + 2 = 5 nodes
    assert Yog.Model.order(graph) == 5

    # First partition (nodes 0-2) connect to second partition (nodes 3-4)
    # Nodes 0-2 should each have degree 2 (connect to both nodes in other partition)
    assert length(Yog.neighbors(graph, 0)) == 2
    assert length(Yog.neighbors(graph, 1)) == 2
    assert length(Yog.neighbors(graph, 2)) == 2

    # Nodes 3-4 should each have degree 3 (connect to all nodes in other partition)
    assert length(Yog.neighbors(graph, 3)) == 3
    assert length(Yog.neighbors(graph, 4)) == 3
  end

  test "complete_bipartite_directed_test" do
    graph = Classic.complete_bipartite_with_type(2, 2, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 4
  end

  # ============= Binary Tree Tests =============

  test "binary_tree_test" do
    # Depth 2 binary tree: 1 root + 2 level-1 + 4 level-2 = 7 nodes
    graph = Classic.binary_tree(2)

    assert Yog.Model.order(graph) == 7
    # Default is undirected, so edges go both ways
    assert Yog.Model.type(graph) == :undirected

    # Root (node 0) has 2 children
    assert length(Yog.successors(graph, 0)) == 2

    # Level-1 nodes (1, 2) each have 3 neighbors (1 parent + 2 children)
    assert length(Yog.successors(graph, 1)) == 3
    assert length(Yog.successors(graph, 2)) == 3

    # Leaf nodes have 1 neighbor (parent only)
    assert length(Yog.successors(graph, 3)) == 1
    assert length(Yog.successors(graph, 4)) == 1
    assert length(Yog.successors(graph, 5)) == 1
    assert length(Yog.successors(graph, 6)) == 1
  end

  test "binary_tree_directed_test" do
    # Directed binary tree has edges only from parent to child
    graph = Classic.binary_tree_with_type(2, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 7

    # Root has 2 children
    assert length(Yog.successors(graph, 0)) == 2

    # Level-1 nodes have 2 children each
    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 2

    # Leaf nodes have no children
    assert length(Yog.successors(graph, 3)) == 0
    assert length(Yog.successors(graph, 4)) == 0
  end

  test "binary_tree_depth_zero_test" do
    # Depth 0 is just the root
    graph = Classic.binary_tree(0)

    assert Yog.Model.order(graph) == 1
    assert length(Yog.successors(graph, 0)) == 0
  end

  # ============= Grid 2D Tests =============

  test "grid_2d_test" do
    graph = Classic.grid_2d(3, 3)

    # 3x3 grid has 9 nodes
    assert Yog.Model.order(graph) == 9

    # Corner nodes have degree 2
    # Top-left corner
    assert length(Yog.neighbors(graph, 0)) == 2

    # Edge nodes (not corners) have degree 3
    # Top edge
    assert length(Yog.neighbors(graph, 1)) == 3

    # Center node has degree 4
    # Center (row 1, col 1)
    assert length(Yog.neighbors(graph, 4)) == 4
  end

  test "grid_2d_1x5_test" do
    # 1x5 is essentially a path
    graph = Classic.grid_2d(1, 5)

    assert Yog.Model.order(graph) == 5
  end

  test "grid_2d_directed_test" do
    graph = Classic.grid_2d_with_type(2, 2, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 4
  end

  # ============= Petersen Graph Tests =============

  test "petersen_test" do
    graph = Classic.petersen()

    # Petersen graph has 10 nodes and 15 edges
    assert Yog.Model.order(graph) == 10

    # All nodes in Petersen graph have degree 3
    for i <- 0..9 do
      assert length(Yog.neighbors(graph, i)) == 3
    end
  end

  test "petersen_directed_test" do
    graph = Classic.petersen_with_type(:directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 10
  end

  # ============= Empty Graph Tests =============

  test "empty_test" do
    graph = Classic.empty(5)

    # Should have 5 isolated nodes (no edges)
    assert Yog.Model.order(graph) == 5

    for i <- 0..4 do
      assert length(Yog.neighbors(graph, i)) == 0
    end
  end

  test "empty_zero_nodes_test" do
    graph = Classic.empty(0)

    assert Yog.Model.order(graph) == 0
  end

  # ============= Edge Weight Tests =============

  test "complete_edge_weights_test" do
    graph = Classic.complete(3)

    # All edges should have weight 1
    [{_, weight} | _] = Yog.neighbors(graph, 0)
    assert weight == 1
  end

  test "path_edge_weights_test" do
    graph = Classic.path(3)

    # All edges should have weight 1
    [{_, weight} | _] = Yog.neighbors(graph, 0)
    assert weight == 1
  end

  # ============= Complex Graph Tests =============

  test "large_complete_graph_test" do
    graph = Classic.complete(10)

    assert Yog.Model.order(graph) == 10
    # Each node connected to 9 others
    assert length(Yog.neighbors(graph, 0)) == 9
  end

  test "large_grid_test" do
    graph = Classic.grid_2d(10, 10)

    # 10x10 = 100 nodes
    assert Yog.Model.order(graph) == 100
  end
end
