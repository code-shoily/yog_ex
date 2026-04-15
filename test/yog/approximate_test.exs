defmodule Yog.ApproximateTest do
  use ExUnit.Case

  doctest Yog.Approximate

  alias Yog.Approximate

  # ============= Diameter Approximation =============

  test "approximate_diameter_empty_graph_test" do
    graph = Yog.undirected()
    assert Approximate.diameter(graph) == nil
  end

  test "approximate_diameter_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, nil)
    assert Approximate.diameter(graph, samples: 2) == 0
  end

  test "approximate_diameter_path_graph_test" do
    # Path 1-2-3-4-5, exact diameter = 4
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {2, 3, 1},
        {3, 4, 1},
        {4, 5, 1}
      ])

    diam = Approximate.diameter(graph, samples: 4)
    assert diam >= 3 and diam <= 4
  end

  test "approximate_diameter_star_graph_test" do
    # Star with center 1, exact diameter = 2
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}, {1, 5, 1}])

    diam = Approximate.diameter(graph, samples: 3)
    assert diam >= 1 and diam <= 2
  end

  test "approximate_diameter_cycle_graph_test" do
    # Cycle C5, exact diameter = 2
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {2, 3, 1},
        {3, 4, 1},
        {4, 5, 1},
        {5, 1, 1}
      ])

    diam = Approximate.diameter(graph, samples: 4)
    assert diam >= 1 and diam <= 2
  end

  # ============= Betweenness Approximation =============

  test "approximate_betweenness_empty_graph_test" do
    graph = Yog.undirected()
    assert Approximate.betweenness(graph) == %{}
  end

  test "approximate_betweenness_star_graph_test" do
    # In a star, the center should have highest betweenness
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}, {1, 5, 1}])

    scores = Approximate.betweenness(graph, samples: 4)

    assert map_size(scores) == 5
    # Center (1) should dominate
    assert scores[1] > scores[2]
    assert scores[1] > scores[3]
  end

  test "approximate_betweenness_path_graph_test" do
    # Path 1-2-3-4, middle nodes have higher betweenness
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])

    scores = Approximate.betweenness(graph, samples: 4)

    assert map_size(scores) == 4
    # Middle nodes should have higher betweenness than endpoints
    assert scores[2] > scores[1]
    assert scores[3] > scores[4]
  end

  test "approximate_betweenness_seed_reproducibility_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {2, 3, 1}, {2, 4, 1}])

    scores1 = Approximate.betweenness(graph, samples: 2, seed: 42)
    scores2 = Approximate.betweenness(graph, samples: 2, seed: 42)

    assert scores1 == scores2
  end

  # ============= Average Path Length Approximation =============

  test "approximate_average_path_length_empty_test" do
    graph = Yog.undirected()
    assert Approximate.average_path_length(graph) == 0.0
  end

  test "approximate_average_path_length_path_graph_test" do
    # Path 1-2-3-4, exact APL = (1+2+3 + 1+2 + 1) / 6 = 10/6 ≈ 1.667
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])

    apl = Approximate.average_path_length(graph, samples: 4)
    assert apl > 0
    # Should be reasonably close to 1.667
    assert apl >= 1.0 and apl <= 3.0
  end

  test "approximate_average_path_length_complete_graph_test" do
    # K4, exact APL = 1.0
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {2, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    apl = Approximate.average_path_length(graph, samples: 4)
    assert apl == 1.0
  end

  test "approximate_average_path_length_disconnected_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {3, 4, 1}])
    # Disconnected, but we only sample reachable pairs
    apl = Approximate.average_path_length(graph, samples: 4)
    assert apl == 1.0
  end

  # ============= Global Efficiency Approximation =============

  test "approximate_global_efficiency_empty_test" do
    graph = Yog.undirected()
    assert Approximate.global_efficiency(graph) == 0.0
  end

  test "approximate_global_efficiency_complete_graph_test" do
    # K4, exact global efficiency = 1.0
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {2, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    eff = Approximate.global_efficiency(graph, samples: 4)
    assert eff == 1.0
  end

  test "approximate_global_efficiency_path_graph_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])

    eff = Approximate.global_efficiency(graph, samples: 3)
    assert eff > 0.0 and eff <= 1.0
  end

  # ============= Transitivity Approximation =============

  test "approximate_transitivity_empty_test" do
    graph = Yog.undirected()
    assert Approximate.transitivity(graph) == 0.0
  end

  test "approximate_transitivity_triangle_test" do
    # Single triangle, exact transitivity = 1.0
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])

    t = Approximate.transitivity(graph, samples: 100)
    assert t == 1.0
  end

  test "approximate_transitivity_square_test" do
    # Square with one diagonal (two triangles sharing an edge)
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {2, 3, 1},
        {3, 4, 1},
        {4, 1, 1},
        {1, 3, 1}
      ])

    # Exact transitivity = 0.75 (2 triangles / 8 connected triples)
    t = Approximate.transitivity(graph, samples: 500)
    assert t >= 0.6 and t <= 0.9
  end

  test "approximate_transitivity_path_test" do
    # Path has no triangles
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])

    t = Approximate.transitivity(graph, samples: 100)
    assert t == 0.0
  end

  test "approximate_transitivity_seed_reproducibility_test" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {2, 3, 1},
        {3, 4, 1},
        {4, 1, 1},
        {1, 3, 1}
      ])

    t1 = Approximate.transitivity(graph, samples: 200, seed: 123)
    t2 = Approximate.transitivity(graph, samples: 200, seed: 123)

    assert t1 == t2
  end

  # ============= Vertex Cover =============

  test "vertex_cover_empty_graph_test" do
    graph = Yog.undirected()
    cover = Approximate.vertex_cover(graph)

    assert MapSet.size(cover) == 0
  end

  test "vertex_cover_single_edge_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}])
    cover = Approximate.vertex_cover(graph)

    assert MapSet.size(cover) == 2
    assert MapSet.member?(cover, 1)
    assert MapSet.member?(cover, 2)
  end

  test "vertex_cover_path_graph_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
    cover = Approximate.vertex_cover(graph)

    # 2-approximation: should be at most 4, at least 2 (optimal is 2)
    assert MapSet.size(cover) <= 4
    assert MapSet.size(cover) >= 2
    assert valid_vertex_cover?(graph, cover)
  end

  test "vertex_cover_star_graph_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}])
    cover = Approximate.vertex_cover(graph)

    # Optimal is just node 1; 2-approx may add center + one leaf
    assert valid_vertex_cover?(graph, cover)
  end

  test "vertex_cover_complete_graph_test" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {2, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    cover = Approximate.vertex_cover(graph)

    # K4 needs 3 nodes minimum; 2-approx gives at most 6
    assert MapSet.size(cover) <= 6
    assert valid_vertex_cover?(graph, cover)
  end

  # ============= Max Clique Approximation =============

  test "max_clique_empty_graph_test" do
    graph = Yog.undirected()
    clique = Approximate.max_clique(graph)

    assert MapSet.size(clique) == 0
  end

  test "max_clique_triangle_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
    clique = Approximate.max_clique(graph)

    assert MapSet.size(clique) == 3
  end

  test "max_clique_path_graph_test" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
    clique = Approximate.max_clique(graph)

    # Max clique in a path is size 2 (any edge)
    assert MapSet.size(clique) == 2
    assert valid_clique?(graph, clique)
  end

  test "max_clique_complete_graph_test" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {2, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    clique = Approximate.max_clique(graph)

    assert MapSet.size(clique) == 4
  end

  test "max_clique_two_triangles_test" do
    # Two triangles sharing one node: 1-2-3 and 1-4-5
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {2, 3, 1},
        {3, 1, 1},
        {1, 4, 1},
        {4, 5, 1},
        {5, 1, 1}
      ])

    clique = Approximate.max_clique(graph)

    # Maximum clique is still size 3 (either triangle)
    assert MapSet.size(clique) == 3
    assert valid_clique?(graph, clique)
  end

  # Helpers

  defp valid_vertex_cover?(graph, cover) do
    Enum.all?(Yog.all_edges(graph), fn {u, v, _} ->
      MapSet.member?(cover, u) or MapSet.member?(cover, v)
    end)
  end

  defp valid_clique?(graph, clique) do
    nodes = MapSet.to_list(clique)

    Enum.all?(nodes, fn u ->
      neighbors = Yog.neighbor_ids(graph, u) |> MapSet.new()
      rest = MapSet.delete(clique, u)
      MapSet.subset?(rest, neighbors)
    end)
  end
end
