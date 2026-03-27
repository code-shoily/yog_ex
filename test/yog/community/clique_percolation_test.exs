defmodule Yog.Community.CliquePercolationTest do
  @moduledoc """
  Tests for Yog.Community.CliquePercolation module.

  Clique Percolation Method (CPM) finds overlapping communities by
  detecting k-cliques that share k-1 nodes.
  """

  use ExUnit.Case

  alias Yog.Community.{CliquePercolation, Overlapping}

  doctest CliquePercolation

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "detect overlapping: two triangles sharing an edge (Diamond should merge for k=3)" do
    # 0-1-2 and 1-2-3 (sharing 1-2)
    edges = [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}, {1, 3, 1}, {2, 3, 1}]

    graph =
      Enum.reduce(edges, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    # Default k=3
    result = CliquePercolation.detect_overlapping(graph)

    # K=3 cliques are {0,1,2} and {1,2,3}. They share {1,2} (size 2 = k-1). 
    # They MUST MERGE into one community.
    assert result.num_communities == 1
    # All nodes 0,1,2,3 should be in community 0
    for i <- 0..3, do: assert(0 in result.memberships[i])
  end

  test "detect separate: triangles sharing only one node (should NOT merge for k=3)" do
    # 0-1-2 and 2-3-4 (sharing node 2 only)
    edges = [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}, {2, 3, 1}, {3, 4, 1}, {4, 2, 1}]

    graph =
      Enum.reduce(edges, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    result = CliquePercolation.detect_overlapping(graph)

    # K=3 cliques share only 1 node. k-1=2. 
    # They should be separate communities.
    assert result.num_communities == 2

    # Node 2 is the ONLY node that should be in both communities
    labels_2 = result.memberships[2] |> Enum.sort()
    assert length(labels_2) == 2

    # Other nodes should be in exactly one
    assert length(result.memberships[0]) == 1
    assert length(result.memberships[4]) == 1

    # Community sets should be {0,1,2} and {2,3,4}
    c0 = Overlapping.nodes_in_community(result, 0)
    c1 = Overlapping.nodes_in_community(result, 1)

    if 0 in c0 do
      assert MapSet.equal?(c0, MapSet.new([0, 1, 2]))
      assert MapSet.equal?(c1, MapSet.new([2, 3, 4]))
    else
      assert MapSet.equal?(c1, MapSet.new([0, 1, 2]))
      assert MapSet.equal?(c0, MapSet.new([2, 3, 4]))
    end
  end

  test "detect merged: adjacent K4s sharing a K3 (should merge for k=4)" do
    # Node 0,1,2,3 is K4. Node 1,2,3,4 is K4. Sharing {1,2,3}.
    # For k=4, they share 3 nodes (k-1). Should MERGE.
    # K4 (0,1,2,3)
    edges_a = for u <- 0..3, v <- 0..3, u < v, do: {u, v, 1}
    # K4 (1,2,3,4)
    edges_b = for u <- 1..4, v <- 1..4, u < v, do: {u, v, 1}

    graph =
      Enum.reduce(edges_a ++ edges_b, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    result = CliquePercolation.detect_overlapping_with_options(graph, k: 4)

    # They should merge into one k=4 community
    assert result.num_communities == 1
    for i <- 0..4, do: assert(0 in result.memberships[i])
  end

  test "no communities: pentagon C5 (k=3)" do
    edges = [{0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 0, 1}]

    graph =
      Enum.reduce(edges, Yog.undirected(), fn {u, v, w}, g ->
        Yog.add_edge_ensure(g, u, v, w, nil)
      end)

    result = CliquePercolation.detect_overlapping(graph)
    assert result.num_communities == 0
    assert result.memberships == %{}
  end

  # ============================================================
  # Basic Edge Case Tests
  # ============================================================

  test "detect_overlapping on empty graph" do
    graph = Yog.undirected()
    result = CliquePercolation.detect_overlapping(graph)

    assert result.num_communities == 0
  end
end
