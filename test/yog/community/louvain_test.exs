defmodule Yog.Community.LouvainTest do
  @moduledoc """
  Tests for Yog.Community.Louvain module.

  Louvain algorithm is a greedy optimization method for community detection
  that maximizes modularity.
  """

  use ExUnit.Case

  alias Yog.Community.Louvain
  alias Yog.Community.Metrics

  doctest Louvain

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect finds communities in two triangles connected by bridge" do
    # Two triangles connected by a single edge
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

    comms = Louvain.detect(graph)

    # Should find at least 2 communities (may find more due to local optima on small graphs)
    assert comms.num_communities >= 2
    assert comms.num_communities <= 6

    # All nodes should be assigned
    assert map_size(comms.assignments) == 6

    # Modularity should be positive for this clear community structure
    q = Metrics.modularity(graph, comms)
    assert q > 0.0
  end

  test "detect on complete graph K5" do
    # K5 should converge to 1 community (or close to it)
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

    comms = Louvain.detect(graph)

    # A complete graph should ideally be 1 community
    assert comms.num_communities >= 1
    assert comms.num_communities <= 3

    # All nodes should be assigned
    assert map_size(comms.assignments) == 5
  end

  test "detect on two disjoint triangles" do
    # Two disjoint triangles should have positive modularity
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

    comms = Louvain.detect(graph)
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

    comms = Louvain.detect_with_options(graph, opts)

    # Should produce valid communities
    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 3
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = Louvain.detect(graph)

    assert comms.num_communities == 0
    assert comms.assignments == %{}
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = Louvain.detect(graph)

    assert comms.num_communities == 1
    assert comms.assignments[0] == 0
  end

  # ============================================================
  # Hierarchical Detection Tests
  # ============================================================

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

    dendrogram = Louvain.detect_hierarchical(graph)

    # Should have multiple levels
    assert length(dendrogram.levels) > 0
    assert is_list(dendrogram.merge_order)
  end

  # ============================================================
  # Rigorous Modularity Benchmarks
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
    comms1 = Louvain.detect_with_options(graph, resolution: 1.0, seed: 1)
    assert comms1.num_communities == 2

    # 2. High resolution (gamma = 10.0)
    # Should find MANY more communities (likely singlets or very small groups)
    comms2 = Louvain.detect_with_options(graph, resolution: 10.0, seed: 1)
    assert comms2.num_communities > 2
  end

  test "modularity gain verification: single bridge vs 2 bridges" do
    # Two cliques with 1 bridge vs 2 bridges. 
    # The modularity should reflect the structural strength.
    edges_a = for u <- 0..4, v <- 0..4, u < v, do: {u, v, 1}
    edges_b = for u <- 10..14, v <- 10..14, u < v, do: {u, v, 1}

    g1 =
      Enum.reduce(edges_a ++ edges_b ++ [{4, 10, 1}], Yog.undirected(), fn {u, v, w}, acc ->
        Yog.add_edge_ensure(acc, u, v, w, nil)
      end)

    g2 =
      Enum.reduce(edges_a ++ edges_b ++ [{4, 10, 1}, {0, 14, 1}], Yog.undirected(), fn {u, v, w},
                                                                                       acc ->
        Yog.add_edge_ensure(acc, u, v, w, nil)
      end)

    comms1 = Louvain.detect(g1)
    comms2 = Louvain.detect(g2)

    q1 = Metrics.modularity(g1, comms1)
    q2 = Metrics.modularity(g2, comms2)

    # g1 is more "separate" than g2, so q1 should be higher for the 2-partition
    assert q1 > q2
  end

  # ============================================================
  # Stats Detection Tests
  # ============================================================

  test "detect_with_stats returns communities with statistics" do
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
    {communities, stats} = Louvain.detect_with_stats(graph, opts)

    assert communities.num_communities >= 1
    assert is_map(communities.assignments)
    assert is_map(stats)
    assert Map.has_key?(stats, :num_phases)
    assert Map.has_key?(stats, :final_modularity)
  end
end
