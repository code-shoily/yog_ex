defmodule Yog.CentralityTest do
  use ExUnit.Case

  doctest Yog.Centrality

  # Helper to create a simple test graph
  defp simple_graph do
    Yog.directed()
    |> Yog.add_node(1, "A")
    |> Yog.add_node(2, "B")
    |> Yog.add_node(3, "C")
    |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
    |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
  end

  defp triangle_graph do
    Yog.undirected()
    |> Yog.add_node(1, "A")
    |> Yog.add_node(2, "B")
    |> Yog.add_node(3, "C")
    |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
    |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
    |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
  end

  defp star_graph do
    # Node 1 is center, connected to 2, 3, 4
    Yog.undirected()
    |> Yog.add_node(1, "center")
    |> Yog.add_node(2, "A")
    |> Yog.add_node(3, "B")
    |> Yog.add_node(4, "C")
    |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
    |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
    |> Yog.add_edge_ensure(from: 1, to: 4, with: 1)
  end

  # ============= Degree Centrality Tests =============

  test "degree_undirected_test" do
    graph = triangle_graph()
    scores = Yog.Centrality.degree(graph)

    assert map_size(scores) == 3
    # In a triangle, all nodes have degree 2, normalized is 2/2 = 1.0
    assert_in_delta scores[1], 1.0, 0.001
    assert_in_delta scores[2], 1.0, 0.001
    assert_in_delta scores[3], 1.0, 0.001
  end

  test "degree_star_graph_test" do
    graph = star_graph()
    scores = Yog.Centrality.degree(graph)

    # Center has degree 3, leaves have degree 1
    # Normalized: center = 3/3 = 1.0, leaves = 1/3 = 0.333
    assert_in_delta scores[1], 1.0, 0.001
    assert_in_delta scores[2], 0.333, 0.01
    assert_in_delta scores[3], 0.333, 0.01
    assert_in_delta scores[4], 0.333, 0.01
  end

  test "degree_directed_out_test" do
    graph = simple_graph()
    scores = Yog.Centrality.degree(graph, :out_degree)

    # Node 1: out-degree 1, Node 2: out-degree 1, Node 3: out-degree 0
    assert_in_delta scores[1], 0.5, 0.001
    assert_in_delta scores[2], 0.5, 0.001
    assert_in_delta scores[3], 0.0, 0.001
  end

  test "degree_directed_in_test" do
    graph = simple_graph()
    scores = Yog.Centrality.degree(graph, :in_degree)

    # Node 1: in-degree 0, Node 2: in-degree 1, Node 3: in-degree 1
    assert_in_delta scores[1], 0.0, 0.001
    assert_in_delta scores[2], 0.5, 0.001
    assert_in_delta scores[3], 0.5, 0.001
  end

  test "degree_directed_total_test" do
    graph = simple_graph()
    scores = Yog.Centrality.degree(graph, :total_degree)

    # Node 1: total 1, Node 2: total 2, Node 3: total 1
    assert_in_delta scores[1], 0.5, 0.001
    assert_in_delta scores[2], 1.0, 0.001
    assert_in_delta scores[3], 0.5, 0.001
  end

  # ============= Closeness Centrality Tests =============

  test "closeness_triangle_test" do
    graph = triangle_graph()

    scores =
      Yog.Centrality.closeness(graph,
        zero: 0,
        add: &Kernel.+/2,
        compare: &compare_int/2,
        to_float: &(&1 * 1.0)
      )

    # In a triangle, all nodes are equidistant: closeness = (n-1) / sum_distances = 2/2 = 1.0
    assert_in_delta scores[1], 1.0, 0.001
    assert_in_delta scores[2], 1.0, 0.001
    assert_in_delta scores[3], 1.0, 0.001
  end

  test "closeness_star_graph_test" do
    graph = star_graph()

    scores =
      Yog.Centrality.closeness(graph,
        zero: 0,
        add: &Kernel.+/2,
        compare: &compare_int/2,
        to_float: &(&1 * 1.0)
      )

    # Center node has best closeness (distance 1 to everyone)
    # Leaf nodes have worse closeness (distance 1 to center, 2 to other leaves)
    # Center: (4-1)/(1+1+1) = 3/3 = 1.0
    assert_in_delta scores[1], 1.0, 0.001
    # Leaf: (4-1)/(1+2+2) = 3/5 = 0.6
    assert_in_delta scores[2], 0.6, 0.001
    assert_in_delta scores[3], 0.6, 0.001
    assert_in_delta scores[4], 0.6, 0.001
  end

  # ============= Harmonic Centrality Tests =============

  test "harmonic_triangle_test" do
    graph = triangle_graph()

    scores =
      Yog.Centrality.harmonic(graph,
        zero: 0,
        add: &Kernel.+/2,
        compare: &compare_int/2,
        to_float: &(&1 * 1.0)
      )

    # Triangle: each node has distance 1 to 2 others
    # Harmonic = (1/1 + 1/1) / (n-1) = 2/2 = 1.0
    assert_in_delta scores[1], 1.0, 0.001
    assert_in_delta scores[2], 1.0, 0.001
    assert_in_delta scores[3], 1.0, 0.001
  end

  test "harmonic_star_graph_test" do
    graph = star_graph()

    scores =
      Yog.Centrality.harmonic(graph,
        zero: 0,
        add: &Kernel.+/2,
        compare: &compare_int/2,
        to_float: &(&1 * 1.0)
      )

    # Center: (1/1 + 1/1 + 1/1) / 3 = 1.0
    assert_in_delta scores[1], 1.0, 0.001
    # Leaf: (1/1 + 1/2 + 1/2) / 3 = 2/3 = 0.666...
    assert_in_delta scores[2], 0.666, 0.01
    assert_in_delta scores[3], 0.666, 0.01
    assert_in_delta scores[4], 0.666, 0.01
  end

  # ============= Betweenness Centrality Tests =============

  test "betweenness_simple_path_test" do
    graph = simple_graph()

    scores =
      Yog.Centrality.betweenness(graph,
        zero: 0,
        add: &Kernel.+/2,
        compare: &compare_int/2,
        to_float: &(&1 * 1.0)
      )

    # In a simple path 1->2->3, node 2 is on the path from 1 to 3
    assert_in_delta scores[1], 0.0, 0.001
    # Lies on 1 shortest path
    assert_in_delta scores[2], 1.0, 0.001
    assert_in_delta scores[3], 0.0, 0.001
  end

  test "betweenness_triangle_test" do
    graph = triangle_graph()

    scores =
      Yog.Centrality.betweenness(graph,
        zero: 0,
        add: &Kernel.+/2,
        compare: &compare_int/2,
        to_float: &(&1 * 1.0)
      )

    # In a triangle, all nodes are on equal footing
    assert_in_delta scores[1], 0.0, 0.001
    assert_in_delta scores[2], 0.0, 0.001
    assert_in_delta scores[3], 0.0, 0.001
  end

  # ============= PageRank Tests =============

  test "pagerank_simple_test" do
    graph = simple_graph()
    scores = Yog.Centrality.pagerank(graph)

    assert map_size(scores) == 3
    # All scores should be positive and sum to approximately 1.0
    total = scores[1] + scores[2] + scores[3]
    assert_in_delta total, 1.0, 0.01

    # In a chain 1->2->3, node 3 should have highest PageRank
    # as it receives links but doesn't distribute them
    assert scores[3] > scores[2]
    assert scores[2] > scores[1]
  end

  test "pagerank_with_options_test" do
    graph = triangle_graph()
    scores = Yog.Centrality.pagerank(graph, damping: 0.85, max_iterations: 50, tolerance: 0.001)

    assert map_size(scores) == 3
    # In a symmetric triangle, all PageRank scores should be approximately equal
    assert_in_delta scores[1], scores[2], 0.01
    assert_in_delta scores[2], scores[3], 0.01
  end

  # ============= Eigenvector Centrality Tests =============

  test "eigenvector_triangle_test" do
    graph = triangle_graph()
    scores = Yog.Centrality.eigenvector(graph)

    assert map_size(scores) == 3
    # In a symmetric triangle, eigenvector centrality should be equal for all
    assert_in_delta scores[1], scores[2], 0.01
    assert_in_delta scores[2], scores[3], 0.01
  end

  test "eigenvector_star_test" do
    graph = star_graph()
    scores = Yog.Centrality.eigenvector(graph)

    # Center should have highest eigenvector centrality
    # as it's connected to all nodes
    assert scores[1] > scores[2]
    assert scores[1] > scores[3]
    assert scores[1] > scores[4]

    # Leaves should have equal centrality
    assert_in_delta scores[2], scores[3], 0.01
    assert_in_delta scores[3], scores[4], 0.01
  end

  # ============= Katz Centrality Tests =============

  test "katz_simple_test" do
    graph = simple_graph()
    scores = Yog.Centrality.katz(graph, alpha: 0.1, beta: 1.0)

    assert map_size(scores) == 3
    # All scores should be >= beta
    assert scores[1] >= 1.0
    assert scores[2] >= 1.0
    assert scores[3] >= 1.0
  end

  test "katz_with_options_test" do
    graph = triangle_graph()

    scores =
      Yog.Centrality.katz(graph, alpha: 0.2, beta: 1.0, max_iterations: 50, tolerance: 0.001)

    assert map_size(scores) == 3
    # In a symmetric graph, Katz centrality should be approximately equal
    assert_in_delta scores[1], scores[2], 0.1
    assert_in_delta scores[2], scores[3], 0.1
  end

  # ============= Alpha Centrality Tests =============

  test "alpha_simple_test" do
    # For alpha centrality to be meaningful, we need a graph where nodes have predecessors
    # In a simple chain 1->2->3, node 1 has no predecessors, so alpha converges to 0
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

    scores = Yog.Centrality.alpha(graph, alpha: 0.3, initial: 1.0)

    assert map_size(scores) == 3
    # All scores should be computed (may be 0 for nodes without predecessors)
    assert Map.has_key?(scores, 1)
    assert Map.has_key?(scores, 2)
    assert Map.has_key?(scores, 3)
  end

  test "alpha_triangle_test" do
    graph = triangle_graph()

    scores =
      Yog.Centrality.alpha(graph,
        alpha: 0.3,
        initial: 1.0,
        max_iterations: 100,
        tolerance: 0.0001
      )

    assert map_size(scores) == 3
    # In a symmetric triangle, alpha centrality should be approximately equal
    assert_in_delta scores[1], scores[2], 0.1
    assert_in_delta scores[2], scores[3], 0.1
  end

  # ============= Edge Cases =============

  test "degree_single_node_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A")
    scores = Yog.Centrality.degree(graph)

    assert map_size(scores) == 1
    assert_in_delta scores[1], 0.0, 0.001
  end

  test "degree_empty_graph_test" do
    graph = Yog.directed()
    scores = Yog.Centrality.degree(graph)

    assert map_size(scores) == 0
  end

  test "pagerank_single_node_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A")
    scores = Yog.Centrality.pagerank(graph)

    assert map_size(scores) == 1
    assert_in_delta scores[1], 1.0, 0.01
  end

  # ============= Helper Functions =============

  defp compare_int(a, b) when a < b, do: :lt
  defp compare_int(a, b) when a > b, do: :gt
  defp compare_int(_, _), do: :eq
end
