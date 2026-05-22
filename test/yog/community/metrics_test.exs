defmodule Yog.Community.MetricsTest do
  @moduledoc """
  Tests for Yog.Community.Metrics module.

  Community metrics measure the quality and characteristics of detected communities.
  """

  use ExUnit.Case

  alias Yog.Community
  alias Yog.Community.Metrics

  doctest Metrics

  # ============================================================
  # Modularity Tests
  # ============================================================

  test "modularity on two disjoint triangles" do
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
        {5, 3, 1}
      ])

    communities = Community.Result.new(%{0 => 0, 1 => 0, 2 => 0, 3 => 1, 4 => 1, 5 => 1})

    q = Metrics.modularity(graph, communities)

    # For two perfectly separated identical communities, Q should be positive
    assert q > 0.4
  end

  test "modularity on weighted graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {1, 2, 10},
        {2, 3, 1},
        {3, 4, 10}
      ])

    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})

    q = Metrics.modularity(graph, communities)

    # Should be a reasonable modularity value (can be any float)
    assert is_float(q)
  end

  test "modularity accepts plain map without Result struct" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1}
      ])

    q = Metrics.modularity(graph, %{assignments: %{1 => 0, 2 => 0, 3 => 0}})
    assert is_float(q)
  end

  test "modularity with resolution parameter" do
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
        {0, 3, 1}
      ])

    communities = Community.Result.new(%{0 => 0, 1 => 0, 2 => 0, 3 => 1})

    q_default = Metrics.modularity(graph, communities)
    q_gamma2 = Metrics.modularity(graph, communities, resolution: 2.0)

    assert is_float(q_default)
    assert is_float(q_gamma2)
    # Higher resolution should generally favor more/smaller communities
    assert q_gamma2 != q_default
  end

  test "modularity on empty graph" do
    graph = Yog.undirected()
    communities = Community.Result.new(%{})

    q = Metrics.modularity(graph, communities)
    assert q == 0.0
  end

  test "modularity on single community" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1}
      ])

    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 0})
    q = Metrics.modularity(graph, communities)

    assert is_float(q)
  end

  test "modularity on directed graph" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1},
        {3, 1, 1}
      ])

    communities = Community.Result.new(%{1 => 0, 2 => 0, 3 => 0})
    q = Metrics.modularity(graph, communities)

    assert is_float(q)
  end

  # ============================================================
  # Triangle Counting Tests
  # ============================================================

  test "count_triangles on triangle" do
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

    assert Metrics.count_triangles(graph) == 1
  end

  test "count_triangles on square" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1},
        {3, 0, 1}
      ])

    # A square has no triangles
    assert Metrics.count_triangles(graph) == 0
  end

  test "count_triangles on complete graph K4" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {0, 2, 1},
        {0, 3, 1},
        {1, 2, 1},
        {1, 3, 1},
        {2, 3, 1}
      ])

    # K4 has 4 triangles
    assert Metrics.count_triangles(graph) == 4
  end

  test "count_triangles on empty graph" do
    graph = Yog.undirected()
    assert Metrics.count_triangles(graph) == 0
  end

  test "count_triangles on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    assert Metrics.count_triangles(graph) == 0
  end

  test "count_triangles on path graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1}
      ])

    assert Metrics.count_triangles(graph) == 0
  end

  test "triangles_per_node on triangle" do
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

    result = Metrics.triangles_per_node(graph)

    assert result[0] == 1
    assert result[1] == 1
    assert result[2] == 1
  end

  test "triangles_per_node on square with diagonal" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1},
        {3, 0, 1},
        {0, 2, 1}
      ])

    result = Metrics.triangles_per_node(graph)

    # Nodes 0, 1, 2 form one triangle; nodes 0, 2, 3 form another
    # Node 0: triangles (0,1,2) and (0,2,3) → 2
    # Node 1: triangle (0,1,2) → 1
    # Node 2: triangles (0,1,2) and (0,2,3) → 2
    # Node 3: triangle (0,2,3) → 1
    assert result[0] == 2
    assert result[1] == 1
    assert result[2] == 2
    assert result[3] == 1
  end

  test "triangles_per_node on empty graph" do
    graph = Yog.undirected()
    result = Metrics.triangles_per_node(graph)
    assert result == %{}
  end

  # ============================================================
  # Clustering Coefficient Tests
  # ============================================================

  test "clustering_coefficient on triangle" do
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

    # In a triangle, each node has clustering coefficient 1.0
    assert Metrics.clustering_coefficient(graph, 0) == 1.0
    assert Metrics.clustering_coefficient(graph, 1) == 1.0
    assert Metrics.clustering_coefficient(graph, 2) == 1.0
  end

  test "clustering_coefficient on isolated node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)

    assert Metrics.clustering_coefficient(graph, 0) == 0.0
  end

  test "clustering_coefficient on degree-1 node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1}
      ])

    # Node 0 has degree 1 → clustering coefficient 0.0
    assert Metrics.clustering_coefficient(graph, 0) == 0.0
    # Node 1 has degree 2, neighbors {0, 2}, edge (0,2) doesn't exist → 0.0
    assert Metrics.clustering_coefficient(graph, 1) == 0.0
  end

  test "clustering_coefficient on star graph center" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {0, 2, 1},
        {0, 3, 1}
      ])

    # Center node 0 has degree 3, neighbors {1,2,3} with 0 edges between them
    assert Metrics.clustering_coefficient(graph, 0) == 0.0
  end

  test "clustering_coefficient on square" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1},
        {3, 0, 1}
      ])

    # Each node in a square has degree 2, neighbors are not connected
    assert Metrics.clustering_coefficient(graph, 0) == 0.0
    assert Metrics.clustering_coefficient(graph, 1) == 0.0
    assert Metrics.clustering_coefficient(graph, 2) == 0.0
    assert Metrics.clustering_coefficient(graph, 3) == 0.0
  end

  test "clustering_coefficient on square with one diagonal" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1},
        {3, 0, 1},
        {0, 2, 1}
      ])

    # Node 0: neighbors {1, 2, 3}, edges (1,2)? yes, (1,3)? no, (2,3)? yes → 2/3
    assert Metrics.clustering_coefficient(graph, 0) == 2.0 / 3.0
    # Node 1: neighbors {0, 2}, edge (0,2)? yes → 1.0
    assert Metrics.clustering_coefficient(graph, 1) == 1.0
    # Node 2: neighbors {0, 1, 3}, edges (0,1)? yes, (0,3)? yes, (1,3)? no → 2/3
    assert Metrics.clustering_coefficient(graph, 2) == 2.0 / 3.0
    # Node 3: neighbors {0, 2}, edge (0,2)? yes → 1.0
    assert Metrics.clustering_coefficient(graph, 3) == 1.0
  end

  test "average_clustering_coefficient on triangle" do
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

    assert Metrics.average_clustering_coefficient(graph) == 1.0
  end

  test "average_clustering_coefficient on empty graph" do
    graph = Yog.undirected()
    assert Metrics.average_clustering_coefficient(graph) == 0.0
  end

  test "average_clustering_coefficient on mixed graph" do
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
        {0, 3, 1}
      ])

    # Node 0: neighbors {1, 2, 3}, edges (1,2)? yes, (1,3)? no, (2,3)? no → 1/3
    # Node 1: neighbors {0, 2}, edge (0,2)? yes → 1.0
    # Node 2: neighbors {0, 1}, edge (0,1)? yes → 1.0
    # Node 3: neighbors {0}, degree 1 → 0.0
    # Average: (1/3 + 1.0 + 1.0 + 0.0) / 4 = 2.333... / 4 = 0.5833...
    avg = Metrics.average_clustering_coefficient(graph)
    assert_in_delta avg, 7.0 / 12.0, 0.0001
  end

  # ============================================================
  # Transitivity Tests
  # ============================================================

  test "transitivity on triangle" do
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

    # One triangle, three connected triples → T = 3*1/3 = 1.0
    assert Metrics.transitivity(graph) == 1.0
  end

  test "transitivity on square" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1},
        {3, 0, 1}
      ])

    # No triangles, 4 connected triples → T = 0.0
    assert Metrics.transitivity(graph) == 0.0
  end

  test "transitivity on square with diagonal" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 3, 1},
        {3, 0, 1},
        {0, 2, 1}
      ])

    # 2 triangles (0,1,2) and (0,2,3), 8 connected triples
    # T = 3*2/8 = 0.75
    assert Metrics.transitivity(graph) == 0.75
  end

  test "transitivity on star graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {0, 2, 1},
        {0, 3, 1}
      ])

    # No triangles, 3 connected triples → T = 0.0
    assert Metrics.transitivity(graph) == 0.0
  end

  test "transitivity on empty graph" do
    graph = Yog.undirected()
    assert Metrics.transitivity(graph) == 0.0
  end

  # ============================================================
  # Density Tests
  # ============================================================

  test "density on complete graph" do
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

    # Triangle has density 1.0
    assert Metrics.density(graph) == 1.0
  end

  test "density on empty graph" do
    graph = Yog.undirected()
    assert Metrics.density(graph) == 0.0
  end

  test "density on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    assert Metrics.density(graph) == 0.0
  end

  test "density on path graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1}
      ])

    # 3 nodes, 2 edges → density = 2*2 / (3*2) = 2/3
    assert Metrics.density(graph) == 2.0 / 3.0
  end

  test "community_density" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_edges!([
        {0, 1, 1}
      ])

    cd = Metrics.community_density(graph, MapSet.new([0, 1]))
    assert is_float(cd)
    # Two nodes with one edge has density 1.0
    assert cd == 1.0
  end

  test "community_density on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    cd = Metrics.community_density(graph, MapSet.new([0]))
    assert cd == 0.0
  end

  test "community_density with no internal edges" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1}
      ])

    # Node 2 has no edges to 0 or 1
    cd = Metrics.community_density(graph, MapSet.new([0, 1, 2]))
    # 3 nodes, 1 internal edge → density = 2*1 / (3*2) = 1/3
    assert cd == 1.0 / 3.0
  end

  test "average_community_density" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_edges!([
        {0, 1, 1}
      ])

    communities = Community.Result.new(%{0 => 0, 1 => 0})

    avg_cd = Metrics.average_community_density(graph, communities)
    assert is_float(avg_cd)
    assert avg_cd == 1.0
  end

  test "average_community_density with multiple communities" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {2, 3, 1}
      ])

    communities = Community.Result.new(%{0 => 0, 1 => 0, 2 => 1, 3 => 1})

    avg_cd = Metrics.average_community_density(graph, communities)
    # Both communities have density 1.0, average = 1.0
    assert avg_cd == 1.0
  end

  test "average_community_density with empty communities" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_edges!([
        {0, 1, 1}
      ])

    communities = Community.Result.new(%{0 => 0, 1 => 0})

    avg_cd = Metrics.average_community_density(graph, communities)
    assert is_float(avg_cd)
  end
end
