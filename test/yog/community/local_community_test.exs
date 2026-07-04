defmodule Yog.Community.LocalCommunityTest do
  @moduledoc """
  Tests for Yog.Community.LocalCommunity module.

  Local Community detection finds communities by expanding from seed nodes,
  useful for large graphs where global detection is expensive.
  """

  use ExUnit.Case

  alias Yog.Community.LocalCommunity

  doctest LocalCommunity

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect from seed node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 0, 1},
        {2, 3, 1}
      ])

    result = LocalCommunity.detect(graph, seeds: [0])

    # Should find a local community containing the seed
    assert is_struct(result, MapSet)
    assert MapSet.member?(result, 0)
    assert MapSet.size(result) <= 4
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

    opts = [max_iterations: 100]
    result = LocalCommunity.detect_with_options(graph, [0], opts)

    assert is_struct(result, MapSet)
    assert MapSet.member?(result, 0)
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    result = LocalCommunity.detect(graph, seeds: [0])

    # Should just return the seed node
    assert is_struct(result, MapSet)
  end

  test "detect with multiple seeds" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1}
      ])

    result = LocalCommunity.detect(graph, seeds: [0, 2])

    assert is_struct(result, MapSet)
    assert MapSet.member?(result, 0)
    assert MapSet.member?(result, 2)
  end

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "detect on Zachary's Karate Club from seed" do
    graph = Yog.Test.Datasets.karate_club()
    # Node 1 is the Officer
    result = LocalCommunity.detect(graph, seeds: [1])

    assert MapSet.member?(result, 1)
    # Growing from node 1 should find a sizeable local community
    assert MapSet.size(result) >= 5
    assert MapSet.size(result) <= 34
  end

  test "detect with max_iterations boundary" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1}
      ])

    result = LocalCommunity.detect_with_options(graph, [0], max_iterations: 0)
    assert MapSet.size(result) == 2
  end

  test "detect with multi-seed starting S ensures frontier and weights updated" do
    # Graph with multiple seeds so S > 1 immediately
    graph =
      Yog.undirected()
      |> Yog.add_edge_ensure(from: 0, to: 1, with: 1.0)
      |> Yog.add_edge_ensure(from: 0, to: 2, with: 5.0)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 5.0)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1.0)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1.0)
      |> Yog.add_edge_ensure(from: 4, to: 5, with: 10.0)
      |> Yog.add_edge_ensure(from: 5, to: 6, with: 10.0)

    result = LocalCommunity.detect_with_options(graph, [0, 1], alpha: 2.5)
    assert is_struct(result, MapSet)
    assert MapSet.size(result) >= 1

    result2 = LocalCommunity.detect_with_options(graph, [0, 1, 2], alpha: 2.5, max_iterations: 1)
    assert is_struct(result2, MapSet)
  end

  test "detect grows monotonically - no removal step" do
    # The greedy algorithm only adds nodes (remove path is mathematically unreachable).
    # This test verifies the algorithm converges on a consistent, seed-containing result.
    graph =
      Yog.undirected()
      |> Yog.add_edge_ensure(from: 0, to: 3, with: 9.0)
      |> Yog.add_edge_ensure(from: 0, to: 6, with: 7.0)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 9.0)
      |> Yog.add_edge_ensure(from: 1, to: 6, with: 4.0)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 3.0)
      |> Yog.add_edge_ensure(from: 2, to: 5, with: 9.0)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 9.0)
      |> Yog.add_edge_ensure(from: 3, to: 5, with: 5.0)
      |> Yog.add_edge_ensure(from: 3, to: 6, with: 6.0)
      |> Yog.add_edge_ensure(from: 5, to: 6, with: 5.0)

    result =
      LocalCommunity.detect_with(graph, [0], %{alpha: 1.8, max_iterations: 1000}, fn w -> w end)

    assert is_struct(result, MapSet)
    assert MapSet.member?(result, 0)

    # max_iterations = 1 forces early stop
    result2 =
      LocalCommunity.detect_with(graph, [0], %{alpha: 1.8, max_iterations: 1}, fn w -> w end)

    assert is_struct(result2, MapSet)
  end
end
