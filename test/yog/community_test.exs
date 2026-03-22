defmodule Yog.CommunityTest do
  use ExUnit.Case

  alias Yog.Community

  doctest Community

  # ============= Utility Functions Tests =============

  test "to_dict_basic_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 0, 3 => 1, 4 => 1},
      num_communities: 2
    }

    result = Community.to_dict(communities)

    assert result[0] == MapSet.new([1, 2])
    assert result[1] == MapSet.new([3, 4])
  end

  test "largest_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 0, 3 => 0, 4 => 1},
      num_communities: 2
    }

    assert Community.largest(communities) == {:some, 0}
  end

  test "largest_empty_test" do
    communities = %{
      assignments: %{},
      num_communities: 0
    }

    assert Community.largest(communities) == :none
  end

  test "sizes_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 0, 3 => 1, 4 => 1, 5 => 1},
      num_communities: 2
    }

    assert Community.sizes(communities) == %{0 => 2, 1 => 3}
  end

  test "merge_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 0, 3 => 1, 4 => 1},
      num_communities: 2
    }

    merged = Community.merge(communities, source: 1, target: 0)

    assert merged.assignments == %{1 => 0, 2 => 0, 3 => 0, 4 => 0}
    assert merged.num_communities == 1
  end

  test "merge_same_source_target_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 0},
      num_communities: 1
    }

    merged = Community.merge(communities, source: 0, target: 0)

    assert merged.num_communities == 1
  end

  test "nodes_in_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 0, 3 => 1, 4 => 1},
      num_communities: 2
    }

    assert Community.nodes_in(communities, 0) == MapSet.new([1, 2])
    assert Community.nodes_in(communities, 1) == MapSet.new([3, 4])
  end

  test "for_node_test" do
    communities = %{
      assignments: %{1 => 0, 2 => 1},
      num_communities: 2
    }

    assert Community.for_node(communities, 1) == {:some, 0}
    assert Community.for_node(communities, 2) == {:some, 1}
    assert Community.for_node(communities, 999) == :none
  end

  # ============= Metrics Tests =============

  test "modularity_basic_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    communities = %{
      assignments: %{1 => 0, 2 => 0},
      num_communities: 1
    }

    q = Community.modularity(graph, communities)
    assert is_float(q)
  end

  test "count_triangles_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

    assert Community.count_triangles(graph) == 1
  end

  test "triangles_per_node_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

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
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

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
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

    assert Community.average_clustering_coefficient(graph) == 1.0
  end

  test "density_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    d = Community.density(graph)
    assert is_float(d)
  end

  test "community_density_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    communities = %{
      assignments: %{1 => 0, 2 => 0},
      num_communities: 1
    }

    cd = Community.community_density(graph, communities, 0)
    assert is_float(cd)
  end

  test "average_community_density_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    communities = %{
      assignments: %{1 => 0, 2 => 0},
      num_communities: 1
    }

    avg_cd = Community.average_community_density(graph, communities)
    assert is_float(avg_cd)
  end
end
