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

    # Perfect community assignment
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

  test "triangles_per_node" do
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
  end
end
