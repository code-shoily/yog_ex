defmodule Yog.Community.WalktrapTest do
  @moduledoc """
  Tests for Yog.Community.Walktrap module.

  Walktrap detects communities using random walks, based on the idea
  that short random walks tend to stay within communities.
  """

  use ExUnit.Case

  alias Yog.Community.Walktrap

  doctest Walktrap

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

    comms = Walktrap.detect(graph)

    # Should find communities
    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 6
  end

  test "detect_with_options" do
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

    opts = [walk_length: 3, seed: 123]
    comms = Walktrap.detect_with_options(graph, opts)

    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 3
  end

  test "detect_hierarchical" do
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

    dendrogram = Walktrap.detect_hierarchical(graph, 4)

    assert length(dendrogram.levels) > 0
    assert is_list(dendrogram.merge_order)
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = Walktrap.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = Walktrap.detect(graph)

    assert comms.num_communities == 1
  end

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "detect on Zachary's Karate Club" do
    graph = Yog.Test.Datasets.karate_club()
    result = Walktrap.detect_with_options(graph, walk_length: 4, seed: 1)

    # Walktrap outcome can vary by walk_length and seeds
    assert result.num_communities >= 1
    assert result.num_communities <= 8
    assert map_size(result.assignments) == 34
  end
end
