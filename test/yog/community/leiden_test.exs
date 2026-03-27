defmodule Yog.Community.LeidenTest do
  @moduledoc """
  Tests for Yog.Community.Leiden module.

  Leiden algorithm is an improvement over Louvain that guarantees
  well-connected communities and is typically faster.
  """

  use ExUnit.Case

  alias Yog.Community.Leiden
  alias Yog.Community.Metrics

  doctest Leiden

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect finds communities in two triangles connected by bridge" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      # First triangle
      |> Yog.add_edge!(from: 0, to: 1, with: 1)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 0, with: 1)
      # Second triangle
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 3, with: 1)
      # Bridge edge
      |> Yog.add_edge!(from: 2, to: 3, with: 1)

    comms = Leiden.detect(graph)

    # Should find at least 2 communities
    assert comms.num_communities >= 2
    assert comms.num_communities <= 6

    # All nodes should be assigned
    assert map_size(comms.assignments) == 6

    # Modularity should be positive
    q = Metrics.modularity(graph, comms)
    assert q > 0.0
  end

  test "detect on complete graph K5" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {0, 2, 1},
        {0, 3, 1},
        {0, 4, 1},
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {2, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    comms = Leiden.detect(graph)

    # A complete graph should ideally be 1 community
    assert comms.num_communities >= 1
    assert comms.num_communities <= 3

    # All nodes should be assigned
    assert map_size(comms.assignments) == 5
  end

  test "detect on two disjoint triangles" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 0, 1},
        {3, 4, 1},
        {4, 5, 1},
        {5, 3, 1}
      ])

    comms = Leiden.detect(graph)
    q = Metrics.modularity(graph, comms)

    # Modularity should be positive for clear community structure
    assert q > 0.0
  end

  test "detect with custom options" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 0, 1}
      ])

    opts = [
      min_modularity_gain: 0.0001,
      max_iterations: 50,
      seed: 123
    ]

    comms = Leiden.detect_with_options(graph, opts)

    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 3
  end

  test "detect_hierarchical returns dendrogram" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1}
      ])

    dendrogram = Leiden.detect_hierarchical(graph)

    assert length(dendrogram.levels) > 0
    assert is_list(dendrogram.merge_order)
  end

  test "detect_hierarchical_with_options" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 0, 1}
      ])

    opts = [seed: 42]
    dendrogram = Leiden.detect_hierarchical_with_options(graph, opts)

    assert length(dendrogram.levels) > 0
  end

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "resolution sensitivity: two 10nd-cliques sharing one bridge" do
    # 0-9 is clique 1, 10-19 is clique 2. Bridge 9-10.
    edges_a = for u <- 0..9, v <- 0..9, u < v, do: {u, v, 1}
    edges_b = for u <- 10..19, v <- 10..19, u < v, do: {u, v, 1}
    bridge = [{9, 10, 1}]

    graph =
      Enum.reduce(edges_a ++ edges_b ++ bridge, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    # 1. Standard resolution (gamma = 1.0)
    # Should find exactly 2 communities
    comms1 = Leiden.detect_with_options(graph, resolution: 1.0, seed: 1)
    assert comms1.num_communities == 2

    # 2. High resolution (gamma = 5.0)
    # Should find MANY more communities
    comms2 = Leiden.detect_with_options(graph, resolution: 5.0, seed: 1)
    assert comms2.num_communities > 2
  end

  test "connectivity guarantee: isolated communities stay separate" do
    # Two disjoint cliques. 
    # Louvain might merge them on very small graphs due to resolution limit, 
    # but Leiden refinement step aims to keep them separate if not connected.
    edges_a = for u <- 0..4, v <- 0..4, u < v, do: {u, v, 1}
    edges_b = for u <- 10..14, v <- 10..14, u < v, do: {u, v, 1}

    graph =
      Enum.reduce(edges_a ++ edges_b, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    comms = Leiden.detect(graph)

    # Must be 2 communities
    assert comms.num_communities == 2
    # All nodes in clique 1 should have same assignment
    c1_id = comms.assignments[0]
    for i <- 1..4, do: assert(comms.assignments[i] == c1_id)

    # Clique 2 should have different assignment
    c2_id = comms.assignments[10]
    assert c2_id != c1_id
    for i <- 11..14, do: assert(comms.assignments[i] == c2_id)
  end

  # ============================================================
  # Basic Edge Case Tests
  # ============================================================

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = Leiden.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = Leiden.detect(graph)

    assert comms.num_communities == 1
    assert comms.assignments[0] == 0
  end
end
