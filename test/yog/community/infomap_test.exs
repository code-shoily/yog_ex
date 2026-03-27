defmodule Yog.Community.InfomapTest do
  @moduledoc """
  Tests for Yog.Community.Infomap module.

  Infomap detects communities based on information theory principles,
  minimizing the description length of a random walk on the graph.
  """

  use ExUnit.Case

  alias Yog.Community.Infomap

  doctest Infomap

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
      |> Yog.add_edge!(from: 0, to: 1, with: 1)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 0, with: 1)
      # Second triangle
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 3, with: 1)
      # Bridge edge
      |> Yog.add_edge!(from: 2, to: 3, with: 1)

    comms = Infomap.detect(graph)

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

    opts = [max_iterations: 50, seed: 123]
    comms = Infomap.detect_with_options(graph, opts)

    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 3
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = Infomap.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = Infomap.detect(graph)

    assert comms.num_communities == 1
  end

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "detect on Zachary's Karate Club" do
    graph = Yog.Test.Datasets.karate_club()
    result = Infomap.detect_with_options(graph, max_iterations: 100, seed: 1)

    # Infomap can find multiple communities depending on structure
    assert result.num_communities >= 1
    assert result.num_communities <= 10
    assert map_size(result.assignments) == 34
  end
end
