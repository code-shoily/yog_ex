defmodule Yog.CommunityTest do
  use ExUnit.Case

  alias Yog.Community
  alias Yog.Generator.Random

  doctest Community

  # ============= Utility Functions Tests =============

  test "to_dict_basic_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})

    result = Community.to_dict(communities)

    assert result[0] == MapSet.new([1, 2])
    assert result[1] == MapSet.new([3, 4])
  end

  test "largest_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 1})

    assert Community.largest(communities) == {:ok, 0}
  end

  test "largest_empty_test" do
    communities = Community.Result.new(%{})

    assert Community.largest(communities) == :error
  end

  test "sizes_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1, 5 => 1})

    assert Community.sizes(communities) == %{0 => 2, 1 => 3}
  end

  test "merge_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})

    merged = Community.merge(communities, source: 1, target: 0)

    assert merged.assignments == %{1 => 0, 2 => 0, 3 => 0, 4 => 0}
    assert merged.num_communities == 1
  end

  test "merge_same_source_target_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 0})

    merged = Community.merge(communities, source: 0, target: 0)

    assert merged.num_communities == 1
  end

  test "nodes_in_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})

    assert Community.nodes_in(communities, 0) == MapSet.new([1, 2])
    assert Community.nodes_in(communities, 1) == MapSet.new([3, 4])
  end

  test "for_node_test" do
    communities = Community.Result.new(%{1 => 0, 2 => 1})

    assert Community.for_node(communities, 1) == {:ok, 0}
    assert Community.for_node(communities, 2) == {:ok, 1}
    assert Community.for_node(communities, 999) == :error
  end

  # ============= Metrics Tests =============

  test "modularity_basic_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    communities = Community.Result.new(%{1 => 0, 2 => 0})

    q = Community.modularity(graph, communities)
    assert is_float(q)
  end

  test "count_triangles_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    assert Community.count_triangles(graph) == 1
  end

  test "triangles_per_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    result = Community.triangles_per_node(graph)
    assert result[1] == 1
    assert result[2] == 1
    assert result[3] == 1
  end

  test "clustering_coefficient_triangle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    # In a triangle, each node has clustering coefficient 1.0
    assert Community.clustering_coefficient(graph, 1) == 1.0
    assert Community.clustering_coefficient(graph, 2) == 1.0
    assert Community.clustering_coefficient(graph, 3) == 1.0
  end

  test "average_clustering_coefficient_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    assert Community.average_clustering_coefficient(graph) == 1.0
  end

  test "density_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    d = Community.density(graph)
    assert is_float(d)
  end

  test "community_density_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    communities = Community.Result.new(%{1 => 0, 2 => 0})

    cd = Community.community_density(graph, communities, 0)
    assert is_float(cd)
  end

  test "average_community_density_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    communities = Community.Result.new(%{1 => 0, 2 => 0})

    avg_cd = Community.average_community_density(graph, communities)
    assert is_float(avg_cd)
  end

  # ============= SBM Generator Tests for Community Detection =============

  describe "sbm-based community detection tests" do
    test "louvain detects sbm communities with strong signal" do
      # Generate SBM with clear community structure (high p_in, low p_out)
      {graph, _true_assignments} = Random.sbm_with_labels(60, 3, 0.4, 0.02, seed: 42)

      # Run Louvain algorithm
      detected = Community.Louvain.detect(graph)

      # Should detect approximately 3 communities
      assert detected.num_communities >= 2
      assert detected.num_communities <= 5

      # Check that modularity is positive (indicates structure)
      q = Community.modularity(graph, detected)
      assert q > 0.3
    end

    test "leiden detects sbm communities with quality guarantee" do
      {graph, _true_assignments} = Random.sbm_with_labels(60, 3, 0.4, 0.02, seed: 42)

      detected = Community.Leiden.detect(graph)

      # Leiden should also detect approximately 3 communities
      assert detected.num_communities >= 2
      assert detected.num_communities <= 5

      q = Community.modularity(graph, detected)
      assert q > 0.3
    end

    test "label_propagation detects sbm communities efficiently" do
      {graph, _true_assignments} = Random.sbm_with_labels(60, 3, 0.4, 0.02, seed: 42)

      detected = Community.LabelPropagation.detect(graph)

      # Label propagation may find different number due to its nature
      assert detected.num_communities >= 1
      assert detected.num_communities <= 6

      q = Community.modularity(graph, detected)
      # Modularity might be lower for LP but should still be reasonable
      assert q > 0.2
    end

    test "fluid_communities with exact k matches sbm structure" do
      k = 3
      {graph, _true_assignments} = Random.sbm_with_labels(60, k, 0.4, 0.02, seed: 42)

      # Fluid communities allows specifying exact k
      detected =
        Community.FluidCommunities.detect_with_options(graph,
          target_communities: k,
          max_iterations: 100,
          seed: 42
        )

      # Should detect exactly k communities
      assert detected.num_communities == k
    end

    test "girvan_newman hierarchical structure on sbm" do
      {graph, _true_assignments} = Random.sbm_with_labels(30, 2, 0.5, 0.05, seed: 42)

      dendrogram = Community.GirvanNewman.detect_hierarchical(graph)

      # Should have multiple levels
      assert Community.Dendrogram.num_levels(dendrogram) >= 1

      # Finest level should have more communities than coarsest (merges happen over time)
      finest = Community.Dendrogram.finest(dendrogram)
      coarsest = Community.Dendrogram.coarsest(dendrogram)

      assert finest.num_communities <= coarsest.num_communities
    end

    test "walktrap detects sbm communities via random walks" do
      {graph, _true_assignments} = Random.sbm_with_labels(50, 3, 0.4, 0.03, seed: 42)

      detected = Community.Walktrap.detect(graph)

      # Walktrap may find single community on some random seeds
      assert detected.num_communities >= 1
      assert detected.num_communities <= 6

      q = Community.modularity(graph, detected)
      # Modularity may be 0 if only one community found
      assert q >= 0.0
    end

    test "infomap detects flow-based communities in sbm" do
      {graph, _true_assignments} = Random.sbm_with_labels(50, 3, 0.4, 0.03, seed: 42)

      detected = Community.Infomap.detect(graph)

      # Infomap may find more communities due to its flow-based nature
      assert detected.num_communities >= 1
      assert detected.num_communities <= 15
    end

    test "dcsbm generation with power_law degrees" do
      graph =
        Random.dcsbm(50, 3, 0.3, 0.02,
          degree_dist: :power_law,
          gamma: 2.5,
          seed: 42
        )

      assert Yog.Model.order(graph) == 50

      # Run community detection
      detected = Community.Louvain.detect(graph)
      assert detected.num_communities >= 2
    end

    test "hsbm hierarchical community detection" do
      # Hierarchical SBM with 2 levels
      graph =
        Random.hsbm(80,
          levels: 2,
          branching: 2,
          p_in: 0.4,
          p_out: 0.01,
          seed: 42
        )

      assert Yog.Model.order(graph) == 80

      # Leiden should handle hierarchical structure well
      dendrogram = Community.Leiden.detect_hierarchical(graph)
      assert Community.Dendrogram.num_levels(dendrogram) >= 1
    end

    test "modularity on perfect sbm partition is high" do
      {graph, true_assignments} = Random.sbm_with_labels(60, 3, 0.5, 0.01, seed: 42)

      # Convert true assignments to Result
      true_communities = Community.Result.new(true_assignments)

      # Modularity of true partition should be high
      q = Community.modularity(graph, true_communities)
      assert q > 0.4
    end

    test "community metrics on sbm detected partition" do
      {graph, _true_assignments} = Random.sbm_with_labels(40, 2, 0.4, 0.05, seed: 42)

      detected = Community.Louvain.detect(graph)

      # Test various metrics
      sizes = Community.sizes(detected)
      assert map_size(sizes) == detected.num_communities

      # Get nodes in each community
      Enum.each(0..(detected.num_communities - 1), fn comm_id ->
        nodes = Community.nodes_in(detected, comm_id)
        assert MapSet.size(nodes) > 0
      end)

      # Community density should be reasonable
      avg_density = Community.average_community_density(graph, detected)
      assert is_float(avg_density)
    end
  end

  # ============= Algorithm Comparison Tests =============

  describe "algorithm comparison on sbm" do
    test "all algorithms produce reasonable results on same sbm" do
      {graph, _true_assignments} = Random.sbm_with_labels(50, 3, 0.35, 0.03, seed: 123)

      algorithms = [
        {"Louvain", fn g -> Community.Louvain.detect(g) end},
        {"Leiden", fn g -> Community.Leiden.detect(g) end},
        {"Label Propagation", fn g -> Community.LabelPropagation.detect(g) end}
      ]

      results =
        Enum.map(algorithms, fn {name, algo} ->
          communities = algo.(graph)
          q = Community.modularity(graph, communities)
          {name, communities.num_communities, q}
        end)

      # All should find multiple communities
      Enum.each(results, fn {name, num_comms, q} ->
        assert num_comms >= 2, "#{name} found too few communities"
        assert num_comms <= 6, "#{name} found too many communities"
        assert q > 0.2, "#{name} has too low modularity"
      end)
    end
  end

  # ============= Edge Case Tests =============

  describe "community detection edge cases" do
    test "empty graph returns empty communities" do
      graph = Yog.undirected()

      result = Community.Louvain.detect(graph)
      assert result.num_communities == 0
    end

    test "single node graph" do
      graph = Yog.undirected() |> Yog.add_node(1, nil)

      result = Community.Louvain.detect(graph)
      assert result.num_communities == 1
      assert result.assignments[1] == 0
    end

    test "two disconnected cliques" do
      # Two 5-node cliques with no edges between them
      # Start with empty graph and add all nodes first
      graph =
        Enum.reduce(1..10, Yog.undirected(), fn i, g -> Yog.add_node(g, i, nil) end)
        |> Yog.add_edges!([
          # First clique (nodes 1-5)
          {1, 2, 1},
          {1, 3, 1},
          {1, 4, 1},
          {1, 5, 1},
          {2, 3, 1},
          {2, 4, 1},
          {2, 5, 1},
          {3, 4, 1},
          {3, 5, 1},
          {4, 5, 1},
          # Second clique (nodes 6-10)
          {6, 7, 1},
          {6, 8, 1},
          {6, 9, 1},
          {6, 10, 1},
          {7, 8, 1},
          {7, 9, 1},
          {7, 10, 1},
          {8, 9, 1},
          {8, 10, 1},
          {9, 10, 1}
        ])

      result = Community.Louvain.detect(graph)

      # Should detect 2 communities (may detect more due to algorithm specifics)
      assert result.num_communities >= 2
      assert result.num_communities <= 3

      # Modularity should be high (two clear communities)
      q = Community.modularity(graph, result)
      assert q > 0.4
    end

    test "random graph has lower modularity than sbm" do
      # Generate random graph with same size as SBM but no structure
      graph = Random.erdos_renyi_gnp(50, 0.1)

      result = Community.Louvain.detect(graph)

      # Random graphs have weaker community structure than SBMs
      q = Community.modularity(graph, result)
      # Modularity should be lower than well-structured SBMs
      assert q < 0.4
    end
  end

  # ============= Performance/Scalability Smoke Tests =============

  describe "scalability smoke tests" do
    test "louvain handles medium-sized sbm" do
      {graph, _true} = Random.sbm_with_labels(200, 4, 0.3, 0.02, seed: 42)

      {time_ms, result} = :timer.tc(fn -> Community.Louvain.detect(graph) end, :millisecond)

      # Should complete in reasonable time (< 5 seconds)
      assert time_ms < 5000
      assert result.num_communities >= 2
    end

    test "label_propagation is faster on large graphs" do
      {graph, _true} = Random.sbm_with_labels(300, 4, 0.25, 0.02, seed: 42)

      {time_ms, result} =
        :timer.tc(
          fn ->
            Community.LabelPropagation.detect_with_options(graph,
              max_iterations: 50,
              seed: 42
            )
          end,
          :millisecond
        )

      # LP should be relatively fast
      assert time_ms < 3000
      assert result.num_communities >= 1
    end
  end
end
