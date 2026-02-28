defmodule YogGeneratorsClassicTest do
  use ExUnit.Case

  alias Yog.Generators

  # Complete graph tests
  test "complete_graph_nodes_test" do
    k5 = Generators.complete(5)
    assert length(Yog.all_nodes(k5)) == 5
  end

  test "complete_graph_edges_test" do
    # K_5 should have 5*4/2 = 10 edges (undirected)
    k5 = Generators.complete(5)

    # Count edges by checking all successors
    edge_count =
      Yog.all_nodes(k5)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(k5, node)
        count + length(successors)
      end)

    # Each edge counted twice (undirected), so divide by 2
    assert div(edge_count, 2) == 10
  end

  test "complete_graph_connectivity_test" do
    # In K_4, node 0 should be connected to nodes 1, 2, 3
    k4 = Generators.complete(4)
    neighbors = Yog.successors(k4, 0) |> Enum.map(&elem(&1, 0))

    assert 1 in neighbors
    assert 2 in neighbors
    assert 3 in neighbors
    assert length(neighbors) == 3
  end

  test "complete_graph_single_node_test" do
    k1 = Generators.complete(1)
    assert length(Yog.all_nodes(k1)) == 1

    # No edges
    assert Yog.successors(k1, 0) == []
  end

  # Cycle graph tests
  test "cycle_graph_nodes_test" do
    c6 = Generators.cycle(6)
    assert length(Yog.all_nodes(c6)) == 6
  end

  test "cycle_graph_edges_test" do
    # C_6 should have exactly 6 edges
    c6 = Generators.cycle(6)

    edge_count =
      Yog.all_nodes(c6)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(c6, node)
        count + length(successors)
      end)

    assert div(edge_count, 2) == 6
  end

  test "cycle_graph_structure_test" do
    # Each node in a cycle should have exactly 2 neighbors
    c5 = Generators.cycle(5)

    assert Enum.all?(Yog.all_nodes(c5), fn node ->
             neighbors = Yog.successors(c5, node)
             length(neighbors) == 2
           end)
  end

  test "cycle_graph_small_test" do
    # Cycle requires at least 3 nodes
    c2 = Generators.cycle(2)
    assert Yog.all_nodes(c2) == []
  end

  # Path graph tests
  test "path_graph_nodes_test" do
    p5 = Generators.path(5)
    assert length(Yog.all_nodes(p5)) == 5
  end

  test "path_graph_edges_test" do
    # P_5 should have 4 edges (n-1)
    p5 = Generators.path(5)

    edge_count =
      Yog.all_nodes(p5)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(p5, node)
        count + length(successors)
      end)

    assert div(edge_count, 2) == 4
  end

  test "path_graph_endpoints_test" do
    # In a path, the first and last nodes have degree 1
    p4 = Generators.path(4)

    assert length(Yog.successors(p4, 0)) == 1
    assert length(Yog.successors(p4, 3)) == 1
  end

  test "path_graph_middle_nodes_test" do
    # Middle nodes in a path have degree 2
    p5 = Generators.path(5)

    assert length(Yog.successors(p5, 2)) == 2
  end

  # Star graph tests
  test "star_graph_nodes_test" do
    s6 = Generators.star(6)
    assert length(Yog.all_nodes(s6)) == 6
  end

  test "star_graph_edges_test" do
    # S_6 should have 5 edges (n-1)
    s6 = Generators.star(6)

    edge_count =
      Yog.all_nodes(s6)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(s6, node)
        count + length(successors)
      end)

    assert div(edge_count, 2) == 5
  end

  test "star_graph_center_test" do
    # Center node (0) should be connected to all others
    s5 = Generators.star(5)

    assert length(Yog.successors(s5, 0)) == 4
  end

  test "star_graph_leaf_test" do
    # Leaf nodes should only connect to center
    s5 = Generators.star(5)

    assert length(Yog.successors(s5, 1)) == 1

    neighbors = Yog.successors(s5, 1) |> Enum.map(&elem(&1, 0))
    assert 0 in neighbors
  end

  # Wheel graph tests
  test "wheel_graph_nodes_test" do
    w6 = Generators.wheel(6)
    assert length(Yog.all_nodes(w6)) == 6
  end

  test "wheel_graph_center_degree_test" do
    # Center node should be connected to all rim nodes
    w6 = Generators.wheel(6)

    assert length(Yog.successors(w6, 0)) == 5
  end

  test "wheel_graph_rim_degree_test" do
    # Rim nodes should have degree 3 (center + 2 neighbors on rim)
    w5 = Generators.wheel(5)

    assert length(Yog.successors(w5, 1)) == 3
  end

  # Complete bipartite tests
  test "complete_bipartite_nodes_test" do
    k33 = Generators.complete_bipartite(3, 3)
    assert length(Yog.all_nodes(k33)) == 6
  end

  test "complete_bipartite_edges_test" do
    # K_3,3 should have 3*3 = 9 edges
    k33 = Generators.complete_bipartite(3, 3)

    edge_count =
      Yog.all_nodes(k33)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(k33, node)
        count + length(successors)
      end)

    assert div(edge_count, 2) == 9
  end

  test "complete_bipartite_left_connections_test" do
    # Node 0 (left partition) should connect to all right partition nodes
    k23 = Generators.complete_bipartite(2, 3)

    assert length(Yog.successors(k23, 0)) == 3

    neighbors = Yog.successors(k23, 0) |> Enum.map(&elem(&1, 0))
    assert 2 in neighbors
    assert 3 in neighbors
    assert 4 in neighbors
  end

  test "complete_bipartite_no_within_partition_test" do
    # Nodes in same partition shouldn't be connected
    k22 = Generators.complete_bipartite(2, 2)

    neighbors_0 = Yog.successors(k22, 0) |> Enum.map(&elem(&1, 0))
    refute 1 in neighbors_0
  end

  # Empty graph tests
  test "empty_graph_test" do
    empty = Generators.empty(5)

    assert length(Yog.all_nodes(empty)) == 5

    # No edges
    assert Enum.all?(Yog.all_nodes(empty), fn node ->
             edges = Yog.successors(empty, node)
             edges == []
           end)
  end

  # Binary tree tests
  test "binary_tree_nodes_test" do
    # Binary tree of depth 3 should have 2^4 - 1 = 15 nodes
    tree = Generators.binary_tree(3)
    assert length(Yog.all_nodes(tree)) == 15
  end

  test "binary_tree_root_children_test" do
    # Root (0) should have children 1 and 2
    tree = Generators.binary_tree(2)

    children = Yog.successors(tree, 0) |> Enum.map(&elem(&1, 0))
    assert 1 in children
    assert 2 in children

    assert length(children) == 2
  end

  test "binary_tree_leaf_nodes_test" do
    # In a complete binary tree of depth 2, nodes 3,4,5,6 are leaves
    # But since it's undirected, they still have an edge back to parent
    # So they have degree 1, not 0
    tree = Generators.binary_tree(2)

    assert length(Yog.successors(tree, 3)) == 1
    assert length(Yog.successors(tree, 6)) == 1
  end

  # Grid 2D tests
  test "grid_2d_nodes_test" do
    grid = Generators.grid_2d(3, 4)
    assert length(Yog.all_nodes(grid)) == 12
  end

  test "grid_2d_corner_degree_test" do
    # Corner nodes have degree 2
    grid = Generators.grid_2d(3, 3)

    assert length(Yog.successors(grid, 0)) == 2
    assert length(Yog.successors(grid, 8)) == 2
  end

  test "grid_2d_edge_degree_test" do
    # Edge nodes (not corners) have degree 3
    grid = Generators.grid_2d(3, 3)

    # Top edge
    assert length(Yog.successors(grid, 1)) == 3
  end

  test "grid_2d_internal_degree_test" do
    # Internal nodes have degree 4
    grid = Generators.grid_2d(3, 3)

    # Center node
    assert length(Yog.successors(grid, 4)) == 4
  end

  test "grid_2d_connections_test" do
    # Node 0 should connect to 1 (right) and 3 (down) in a 3x3 grid
    grid = Generators.grid_2d(3, 3)

    neighbors = Yog.successors(grid, 0) |> Enum.map(&elem(&1, 0))
    assert 1 in neighbors
    assert 3 in neighbors
  end

  # Petersen graph tests
  test "petersen_graph_nodes_test" do
    petersen = Generators.petersen()
    assert length(Yog.all_nodes(petersen)) == 10
  end

  test "petersen_graph_edges_test" do
    # Petersen graph has 15 edges
    petersen = Generators.petersen()

    edge_count =
      Yog.all_nodes(petersen)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(petersen, node)
        count + length(successors)
      end)

    assert div(edge_count, 2) == 15
  end

  test "petersen_graph_regularity_test" do
    # Petersen graph is 3-regular (every node has degree 3)
    petersen = Generators.petersen()

    assert Enum.all?(Yog.all_nodes(petersen), fn node ->
             degree = Yog.successors(petersen, node) |> length()
             degree == 3
           end)
  end

  test "petersen_graph_outer_pentagon_test" do
    # Verify outer pentagon exists: 0-1-2-3-4-0
    petersen = Generators.petersen()

    neighbors_0 = Yog.successors(petersen, 0) |> Enum.map(&elem(&1, 0))
    assert 1 in neighbors_0
    assert 4 in neighbors_0
  end

  # Directed vs undirected tests
  test "complete_directed_test" do
    directed = Generators.complete_with_type(4, :directed)

    # In directed K_4, should have 4*3 = 12 edges
    edge_count =
      Yog.all_nodes(directed)
      |> Enum.reduce(0, fn node, count ->
        successors = Yog.successors(directed, node)
        count + length(successors)
      end)

    assert edge_count == 12
  end

  test "cycle_directed_test" do
    directed = Generators.cycle_with_type(5, :directed)

    # In directed cycle, each node has out-degree 1
    assert Enum.all?(Yog.all_nodes(directed), fn node ->
             successors = Yog.successors(directed, node)
             length(successors) == 1
           end)
  end

  # Edge weight tests
  test "generated_graphs_have_unit_weights_test" do
    k3 = Generators.complete(3)

    edges = Yog.successors(k3, 0)

    assert Enum.all?(edges, fn {_, weight} ->
             weight == 1
           end)
  end
end
