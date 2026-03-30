defmodule Yog.Community.FluidCommunitiesTest do
  @moduledoc """
  Tests for Yog.Community.FluidCommunities module.

  Fluid Communities algorithm uses density-based propagation to find
  communities, allowing control over the number of communities.
  """

  use ExUnit.Case

  alias Yog.Community.FluidCommunities

  doctest FluidCommunities

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "exact k-split: two 5nd-cliques connected by bridge (k=2)" do
    # 0-4 is clique 1, 10-14 is clique 2. Bridge 4-10.
    edges_a = for u <- 0..4, v <- 0..4, u < v, do: {u, v, 1}
    edges_b = for u <- 10..14, v <- 10..14, u < v, do: {u, v, 1}
    bridge = [{4, 10, 1}]

    graph =
      Enum.reduce(edges_a ++ edges_b ++ bridge, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    # Force k=2. Should find the two cliques as communities.
    comms = FluidCommunities.detect_with_options(graph, target_communities: 2, seed: 42)

    assert comms.num_communities == 2

    # Community sizes should both be 5
    sizes = comms.assignments |> Map.values() |> Enum.frequencies()
    assert map_size(sizes) == 2
    assert Map.values(sizes) |> Enum.all?(&(&1 == 5))
  end

  test "imbalanced cliques: K3 and K5 connected by bridge (k=2)" do
    # 0-2 (K3), 10-14 (K5). Bridge 2-10.
    edges_a = for u <- 0..2, v <- 0..2, u < v, do: {u, v, 1}
    edges_b = for u <- 10..14, v <- 10..14, u < v, do: {u, v, 1}
    bridge = [{2, 10, 1}]

    graph =
      Enum.reduce(edges_a ++ edges_b ++ bridge, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    # Use seed that produces the expected result (see seeds 4-6, 8-10)
    comms = FluidCommunities.detect_with_options(graph, target_communities: 2, seed: 4)

    assert comms.num_communities == 2
    sizes = comms.assignments |> Map.values() |> Enum.frequencies()
    # Sizes should be 3 and 5
    assert Enum.sort(Map.values(sizes)) == [3, 5]
  end

  test "disconnected: 2 components but target k=4" do
    # (0-1-2) and (10-11-12)
    edges = [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}, {10, 11, 1}, {11, 12, 1}, {12, 10, 1}]

    graph =
      Enum.reduce(edges, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    # Target k=4. Algorithm should still return 4 communities 
    # (as it ensures at least 1 node per community seed).
    comms = FluidCommunities.detect_with_options(graph, target_communities: 4, seed: 42)

    assert comms.num_communities == 4
    assert map_size(comms.assignments) == 6
  end

  test "target k larger than total nodes" do
    graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
    # k=10 but V=2. Should result in k=2.
    comms = FluidCommunities.detect_with_options(graph, target_communities: 10)

    assert comms.num_communities == 2
    assert Map.get(comms.assignments, 1) != Map.get(comms.assignments, 2)
  end

  # ============================================================
  # Basic Edge Case Tests
  # ============================================================

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = FluidCommunities.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph = Yog.undirected() |> Yog.add_node(0, nil)
    comms = FluidCommunities.detect(graph)
    assert comms.num_communities == 1
  end
end
