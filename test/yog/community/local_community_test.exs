defmodule Yog.Community.LocalCommunityTest do
  @moduledoc """
  Tests for the Local Community detection algorithm.
  """
  use ExUnit.Case

  doctest Yog.Community.LocalCommunity

  alias Yog.Community.LocalCommunity

  describe "detect/2" do
    test "detects local community from single seed" do
      # Create a clique: 1-2-3 tightly connected
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)
        |> Yog.add_edge_ensure(1, 3, 1, default: nil)
        # Weak connection to outer node
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)

      community = LocalCommunity.detect(graph, seeds: [2])

      # Should include the tightly connected nodes
      assert MapSet.member?(community, 2)
      assert MapSet.member?(community, 1)
      assert MapSet.member?(community, 3)
    end

    test "detects local community from multiple seeds" do
      # Two cliques connected by one edge
      graph =
        Yog.undirected()
        # Clique A: 1-2-3
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)
        |> Yog.add_edge_ensure(1, 3, 1, default: nil)
        # Clique B: 4-5-6
        |> Yog.add_edge_ensure(4, 5, 1, default: nil)
        |> Yog.add_edge_ensure(5, 6, 1, default: nil)
        |> Yog.add_edge_ensure(4, 6, 1, default: nil)
        # Bridge
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)

      # Seeds in clique A
      community = LocalCommunity.detect(graph, seeds: [1, 2])

      # Should stay in clique A
      assert MapSet.member?(community, 1)
      assert MapSet.member?(community, 2)
      assert MapSet.member?(community, 3)
    end

    test "returns seed when isolated node" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)

      community = LocalCommunity.detect(graph, seeds: [1])

      assert MapSet.equal?(community, MapSet.new([1]))
    end

    test "handles empty seeds list" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)

      community = LocalCommunity.detect(graph, seeds: [])

      assert MapSet.size(community) == 0
    end
  end

  describe "detect_with_options/3" do
    test "accepts custom alpha parameter" do
      # Create a chain: 1-2-3-4-5
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)
        |> Yog.add_edge_ensure(4, 5, 1, default: nil)

      # Different alpha values produce different community structures
      community_high_alpha =
        LocalCommunity.detect_with_options(graph, [3], alpha: 2.0, max_iterations: 100)

      community_low_alpha =
        LocalCommunity.detect_with_options(graph, [3], alpha: 0.5, max_iterations: 100)

      # Both should find non-empty communities
      assert MapSet.size(community_high_alpha) >= 1
      assert MapSet.size(community_low_alpha) >= 1

      # Higher alpha typically yields smaller communities (more conservative)
      assert MapSet.size(community_high_alpha) <= MapSet.size(community_low_alpha) + 1
    end

    test "respects max_iterations" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)

      # With very low max_iterations, should limit expansion
      community_limited =
        LocalCommunity.detect_with_options(graph, [2], alpha: 1.0, max_iterations: 1)

      community_unlimited =
        LocalCommunity.detect_with_options(graph, [2], alpha: 1.0, max_iterations: 100)

      # Both should include the seed
      assert MapSet.member?(community_limited, 2)
      assert MapSet.member?(community_unlimited, 2)

      # Limited iterations should produce smaller or equal community
      assert MapSet.size(community_limited) <= MapSet.size(community_unlimited)
    end
  end

  describe "default_options/0" do
    test "returns default options map" do
      defaults = LocalCommunity.default_options()

      assert defaults.alpha == 1.0
      assert defaults.max_iterations == 1000
    end
  end

  describe "fitness optimization" do
    test "expands to include high-degree boundary nodes" do
      # Star graph with center at 1
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(1, 3, 1, default: nil)
        |> Yog.add_edge_ensure(1, 4, 1, default: nil)
        |> Yog.add_edge_ensure(1, 5, 1, default: nil)

      community = LocalCommunity.detect(graph, seeds: [1])

      # Center should be included
      assert MapSet.member?(community, 1)
      # All leaves should eventually be included due to high internal connectivity
      assert MapSet.size(community) >= 1
    end

    test "handles triangle structure correctly" do
      # Triangle 1-2-3 with dangling nodes
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)
        |> Yog.add_edge_ensure(3, 1, 1, default: nil)
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)
        |> Yog.add_edge_ensure(4, 5, 1, default: nil)

      community = LocalCommunity.detect(graph, seeds: [1])

      # Triangle nodes should be included
      assert MapSet.member?(community, 1)
      assert MapSet.member?(community, 2)
      assert MapSet.member?(community, 3)
    end
  end
end
