defmodule Yog.Community.LouvainTest do
  @moduledoc """
  Tests for the Louvain community detection algorithm.
  """
  use ExUnit.Case

  doctest Yog.Community.Louvain

  alias Yog.Community.Louvain

  describe "detect/1" do
    test "detects communities in a simple clique graph" do
      # Create two cliques (complete subgraphs)
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1, default: nil)
        |> Yog.add_edge_ensure(0, 2, 1, default: nil)
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        # Clique 2: nodes 3, 4, 5
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)
        |> Yog.add_edge_ensure(3, 5, 1, default: nil)
        |> Yog.add_edge_ensure(4, 5, 1, default: nil)
        # Weak connection between cliques
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)

      communities = Louvain.detect(graph)

      # Should find 2 communities
      assert communities.num_communities >= 1
      assert map_size(communities.assignments) == 6

      # Nodes in same clique should be in same community
      comm_0 = Map.get(communities.assignments, 0)
      comm_1 = Map.get(communities.assignments, 1)
      comm_2 = Map.get(communities.assignments, 2)

      assert comm_0 == comm_1
      assert comm_1 == comm_2

      comm_3 = Map.get(communities.assignments, 3)
      comm_4 = Map.get(communities.assignments, 4)
      comm_5 = Map.get(communities.assignments, 5)

      assert comm_3 == comm_4
      assert comm_4 == comm_5
    end

    test "handles empty graph" do
      graph = Yog.undirected()
      communities = Louvain.detect(graph)

      assert communities.num_communities == 0
      assert communities.assignments == %{}
    end

    test "handles single node graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(0, "a")

      communities = Louvain.detect(graph)

      assert communities.num_communities == 1
      assert Map.get(communities.assignments, 0) == 0
    end

    test "handles disconnected nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_node(0, "a")
        |> Yog.add_node(1, "b")
        |> Yog.add_node(2, "c")

      communities = Louvain.detect(graph)

      # Each node in its own community since no edges
      assert communities.num_communities == 3
    end
  end

  describe "detect_with_options/2" do
    test "accepts custom options" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1, default: nil)
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)

      options = [
        min_modularity_gain: 0.00001,
        max_iterations: 50,
        seed: 123
      ]

      communities = Louvain.detect_with_options(graph, options)

      assert map_size(communities.assignments) == 3
    end
  end

  describe "detect_with_stats/2" do
    test "returns statistics" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1, default: nil)
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 0, 1, default: nil)

      {communities, stats} = Louvain.detect_with_stats(graph, [])

      assert map_size(communities.assignments) == 3
      assert is_number(stats.num_phases)
      assert is_number(stats.final_modularity)
      assert is_list(stats.iteration_modularity)
      assert stats.num_phases >= 1
    end
  end

  describe "detect_hierarchical/1" do
    test "returns hierarchical structure" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1, default: nil)
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(2, 0, 1, default: nil)
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)
        |> Yog.add_edge_ensure(4, 5, 1, default: nil)
        |> Yog.add_edge_ensure(5, 3, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)

      dendrogram = Louvain.detect_hierarchical(graph)

      assert is_list(dendrogram.levels)
      assert length(dendrogram.levels) >= 1

      # First level should have assignments for all nodes
      first_level = hd(dendrogram.levels)
      assert map_size(first_level.assignments) == 6
    end
  end

  describe "default_options/0" do
    test "returns default options map" do
      defaults = Louvain.default_options()

      assert defaults.min_modularity_gain == 0.000001
      assert defaults.max_iterations == 100
      assert defaults.seed == 42
    end
  end

  describe "modularity optimization" do
    test "finds communities with positive modularity" do
      # Create a graph with clear community structure
      graph =
        Yog.undirected()
        # Dense community 1
        |> Yog.add_edge_ensure(0, 1, 1, default: nil)
        |> Yog.add_edge_ensure(0, 2, 1, default: nil)
        |> Yog.add_edge_ensure(1, 2, 1, default: nil)
        |> Yog.add_edge_ensure(0, 3, 1, default: nil)
        |> Yog.add_edge_ensure(1, 3, 1, default: nil)
        |> Yog.add_edge_ensure(2, 3, 1, default: nil)
        # Dense community 2
        |> Yog.add_edge_ensure(4, 5, 1, default: nil)
        |> Yog.add_edge_ensure(4, 6, 1, default: nil)
        |> Yog.add_edge_ensure(5, 6, 1, default: nil)
        |> Yog.add_edge_ensure(4, 7, 1, default: nil)
        |> Yog.add_edge_ensure(5, 7, 1, default: nil)
        |> Yog.add_edge_ensure(6, 7, 1, default: nil)
        # Single bridge edge
        |> Yog.add_edge_ensure(3, 4, 1, default: nil)

      {_communities, stats} = Louvain.detect_with_stats(graph, [])

      # Modularity should be positive for clear community structure
      assert stats.final_modularity > 0
    end
  end
end
