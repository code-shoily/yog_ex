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
end
