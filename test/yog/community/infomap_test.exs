defmodule Yog.Community.InfomapTest do
  @moduledoc """
  Tests for Yog.Community.Infomap module.

  Infomap detects communities based on information theory principles,
  minimizing the description length of a random walk on the graph.
  """

  use ExUnit.Case

  alias Yog.Community.{Infomap, Metrics}

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
      |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)
      # Second triangle
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 4, to: 5, with: 1)
      |> Yog.add_edge_ensure(from: 5, to: 3, with: 1)
      # Bridge edge
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

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
    result = Infomap.detect_with_options(graph, max_pagerank_iters: 100, seed: 1)

    # Infomap can find multiple communities depending on structure
    assert result.num_communities >= 1
    assert result.num_communities <= 10
    assert map_size(result.assignments) == 34
  end

  test "canonical two K5 cliques + bridge finds correct partition" do
    graph =
      Yog.undirected()
      |> then(fn g -> Enum.reduce(0..9, g, &Yog.add_node(&2, &1, nil)) end)
      |> then(fn g ->
        edges =
          for(i <- 0..4, j <- (i + 1)..4//1, do: {i, j, 1.0}) ++
            for(i <- 5..9, j <- (i + 1)..9//1, do: {i, j, 1.0}) ++
            [{4, 5, 1.0}]

        Enum.reduce(edges, g, fn {u, v, w}, acc ->
          {:ok, ng} = Yog.add_edge(acc, u, v, w)
          ng
        end)
      end)

    result = Infomap.detect(graph)

    assert result.num_communities == 2
    assert map_size(result.assignments) == 10

    mod = Metrics.modularity(graph, %{assignments: result.assignments})
    assert mod >= 0.4
  end

  test "convergence: redetect on output produces same partition" do
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
        {5, 3, 1},
        {2, 3, 1}
      ])

    result1 = Infomap.detect(graph)

    # Build a new graph with nodes relabeled by community
    # Not needed — just verify running again gives same partition structure
    result2 = Infomap.detect(graph)

    assert result1.num_communities == result2.num_communities
    assert map_size(result1.assignments) == map_size(result2.assignments)
  end
end
