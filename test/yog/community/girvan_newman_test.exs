defmodule Yog.Community.GirvanNewmanTest do
  @moduledoc """
  Tests for Yog.Community.GirvanNewman module.

  Girvan-Newman algorithm detects communities by progressively removing
  edges with highest betweenness centrality.
  """

  use ExUnit.Case

  alias Yog.Community.GirvanNewman

  doctest GirvanNewman

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect on two triangles connected by bridge" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      # First triangle
      |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)
      # Second triangle
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 4, to: 5, with: 1)
      |> Yog.add_edge_ensure(from: 5, to: 3, with: 1)
      # Bridge edge
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

    comms = GirvanNewman.detect(graph)

    # Should find communities
    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 6
  end

  test "detect with options" do
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

    opts = [target_communities: 1]
    {:ok, comms} = GirvanNewman.detect_with_options(graph, opts)

    assert comms.num_communities >= 1
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

    dendrogram = GirvanNewman.detect_hierarchical(graph)

    assert length(dendrogram.levels) > 0
    assert is_list(dendrogram.merge_order)
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = GirvanNewman.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = GirvanNewman.detect(graph)

    # Single node should be in one community
    assert comms.num_communities == 1
  end

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "detect on Zachary's Karate Club" do
    graph = Yog.Test.Datasets.karate_club()
    # GN can be slow, but for 34 nodes it should be fine.
    # We target 2 factions.
    {:ok, result} = GirvanNewman.detect_with_options(graph, target_communities: 2)

    assert result.num_communities == 2
    assert map_size(result.assignments) == 34
  end
end
