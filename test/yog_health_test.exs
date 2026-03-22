defmodule YogHealthTest do
  use ExUnit.Case

  # Helper functions
  defp compare_int(a, b) when a < b, do: :lt
  defp compare_int(a, b) when a > b, do: :gt
  defp compare_int(_, _), do: :eq

  defp opts_int do
    [
      with_zero: 0,
      with_add: &Kernel.+/2,
      with_compare: &compare_int/2,
      with: &Function.identity/1
    ]
  end

  defp opts_int_with_to_float do
    opts_int() ++ [with_to_float: &(&1 * 1.0)]
  end

  # Helper to create test graphs
  defp triangle_graph do
    # Complete connected triangle
    Yog.undirected()
    |> Yog.add_node(1, "A")
    |> Yog.add_node(2, "B")
    |> Yog.add_node(3, "C")
    |> Yog.add_edge!(from: 1, to: 2, with: 1)
    |> Yog.add_edge!(from: 2, to: 3, with: 1)
    |> Yog.add_edge!(from: 3, to: 1, with: 1)
  end

  defp path_graph do
    # Linear path: 1-2-3-4
    Yog.undirected()
    |> Yog.add_node(1, "A")
    |> Yog.add_node(2, "B")
    |> Yog.add_node(3, "C")
    |> Yog.add_node(4, "D")
    |> Yog.add_edge!(from: 1, to: 2, with: 1)
    |> Yog.add_edge!(from: 2, to: 3, with: 1)
    |> Yog.add_edge!(from: 3, to: 4, with: 1)
  end

  defp disconnected_graph do
    # Two separate components: 1-2 and 3-4
    Yog.undirected()
    |> Yog.add_node(1, "A")
    |> Yog.add_node(2, "B")
    |> Yog.add_node(3, "C")
    |> Yog.add_node(4, "D")
    |> Yog.add_edge!(from: 1, to: 2, with: 1)
    |> Yog.add_edge!(from: 3, to: 4, with: 1)
  end

  defp star_graph do
    # Star with center node 1
    Yog.undirected()
    |> Yog.add_node(1, "center")
    |> Yog.add_node(2, "A")
    |> Yog.add_node(3, "B")
    |> Yog.add_node(4, "C")
    |> Yog.add_edge!(from: 1, to: 2, with: 1)
    |> Yog.add_edge!(from: 1, to: 3, with: 1)
    |> Yog.add_edge!(from: 1, to: 4, with: 1)
  end

  # ============= Diameter Tests =============

  test "diameter_triangle_test" do
    graph = triangle_graph()
    diameter = Yog.Health.diameter(graph, opts_int())

    # In a triangle, max distance is 1
    assert diameter == 1
  end

  test "diameter_path_test" do
    graph = path_graph()
    diameter = Yog.Health.diameter(graph, opts_int())

    # In a path of 4 nodes, max distance is 3 (from node 1 to node 4)
    assert diameter == 3
  end

  test "diameter_star_test" do
    graph = star_graph()
    diameter = Yog.Health.diameter(graph, opts_int())

    # In a star, max distance is 2 (leaf to leaf through center)
    assert diameter == 2
  end

  test "diameter_disconnected_test" do
    graph = disconnected_graph()
    diameter = Yog.Health.diameter(graph, opts_int())

    # Disconnected graph should return nil
    assert diameter == nil
  end

  test "diameter_empty_graph_test" do
    graph = Yog.undirected()
    diameter = Yog.Health.diameter(graph, opts_int())

    assert diameter == nil
  end

  test "diameter_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, "A")
    diameter = Yog.Health.diameter(graph, opts_int())

    # Single node has diameter 0
    assert diameter == 0
  end

  # ============= Radius Tests =============

  test "radius_triangle_test" do
    graph = triangle_graph()
    radius = Yog.Health.radius(graph, opts_int())

    # In a triangle, min eccentricity is 1
    assert radius == 1
  end

  test "radius_path_test" do
    graph = path_graph()
    radius = Yog.Health.radius(graph, opts_int())

    # In a path of 4 nodes, radius is 2 (from middle nodes)
    # Node 2 or 3 can reach furthest node in 2 steps
    assert radius == 2
  end

  test "radius_star_test" do
    graph = star_graph()
    radius = Yog.Health.radius(graph, opts_int())

    # In a star, center has eccentricity 1 (can reach all in 1 step)
    assert radius == 1
  end

  test "radius_disconnected_test" do
    graph = disconnected_graph()
    radius = Yog.Health.radius(graph, opts_int())

    # Disconnected graph should return nil
    assert radius == nil
  end

  test "radius_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, "A")
    radius = Yog.Health.radius(graph, opts_int())

    # Single node has radius 0
    assert radius == 0
  end

  # ============= Eccentricity Tests =============

  test "eccentricity_triangle_test" do
    graph = triangle_graph()

    # All nodes in triangle have eccentricity 1
    assert Yog.Health.eccentricity(graph, 1, opts_int()) == 1
    assert Yog.Health.eccentricity(graph, 2, opts_int()) == 1
    assert Yog.Health.eccentricity(graph, 3, opts_int()) == 1
  end

  test "eccentricity_path_test" do
    graph = path_graph()

    # End nodes have eccentricity 3, middle nodes have eccentricity 2
    assert Yog.Health.eccentricity(graph, 1, opts_int()) == 3
    assert Yog.Health.eccentricity(graph, 2, opts_int()) == 2
    assert Yog.Health.eccentricity(graph, 3, opts_int()) == 2
    assert Yog.Health.eccentricity(graph, 4, opts_int()) == 3
  end

  test "eccentricity_star_test" do
    graph = star_graph()

    # Center has eccentricity 1, leaves have eccentricity 2
    assert Yog.Health.eccentricity(graph, 1, opts_int()) == 1
    assert Yog.Health.eccentricity(graph, 2, opts_int()) == 2
    assert Yog.Health.eccentricity(graph, 3, opts_int()) == 2
    assert Yog.Health.eccentricity(graph, 4, opts_int()) == 2
  end

  test "eccentricity_disconnected_test" do
    graph = disconnected_graph()

    # Nodes in disconnected components can't reach all nodes
    assert Yog.Health.eccentricity(graph, 1, opts_int()) == nil
  end

  test "eccentricity_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, "A")

    assert Yog.Health.eccentricity(graph, 1, opts_int()) == 0
  end

  # ============= Assortativity Tests =============

  test "assortativity_triangle_test" do
    graph = triangle_graph()
    assort = Yog.Health.assortativity(graph)

    # Triangle is perfectly assortative (all nodes have same degree)
    # Should be around 0 or NaN due to no variance
    assert is_float(assort)
  end

  test "assortativity_star_test" do
    graph = star_graph()
    assort = Yog.Health.assortativity(graph)

    # Star is disassortative (high degree connects to low degree)
    assert is_float(assort)
    # Center (degree 3) connects only to leaves (degree 1)
    assert assort < 0.0
  end

  test "assortativity_path_test" do
    graph = path_graph()
    assort = Yog.Health.assortativity(graph)

    # Path should be somewhat assortative (similar degrees connect)
    # End nodes (degree 1) connect to middle nodes (degree 2)
    assert is_float(assort)
  end

  test "assortativity_empty_graph_test" do
    graph = Yog.undirected()
    assort = Yog.Health.assortativity(graph)

    assert assort == 0.0
  end

  # ============= Average Path Length Tests =============

  test "average_path_length_triangle_test" do
    graph = triangle_graph()
    avg = Yog.Health.average_path_length(graph, opts_int_with_to_float())

    # In triangle: each node has distance 1 to 2 others
    # Total distances: 3 nodes * 2 edges = 6, pairs = 3*2 = 6
    # Average = 6/6 = 1.0
    assert_in_delta avg, 1.0, 0.001
  end

  test "average_path_length_path_test" do
    graph = path_graph()
    avg = Yog.Health.average_path_length(graph, opts_int_with_to_float())

    # Path 1-2-3-4:
    # Distances: 1-2:1, 1-3:2, 1-4:3, 2-3:1, 2-4:2, 3-4:1
    # Total = 1+2+3+1+2+1 = 10 (one direction)
    # Total both directions = 20, pairs = 4*3 = 12
    # Average = 20/12 = 1.666...
    assert_in_delta avg, 1.666, 0.01
  end

  test "average_path_length_star_test" do
    graph = star_graph()
    avg = Yog.Health.average_path_length(graph, opts_int_with_to_float())

    # Star: center to each leaf = 1, leaf to leaf = 2
    # Center to 3 leaves: 3 * 1 = 3
    # 3 leaves to each other: 3 * 2 = 6 (for 3 pairs)
    # Total one direction: 3 + 6 = 9
    # Both directions: 18, pairs = 4*3 = 12
    # Average = 18/12 = 1.5
    assert_in_delta avg, 1.5, 0.001
  end

  test "average_path_length_disconnected_test" do
    graph = disconnected_graph()
    avg = Yog.Health.average_path_length(graph, opts_int_with_to_float())

    # Disconnected graph should return nil
    assert avg == nil
  end

  test "average_path_length_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, "A")
    avg = Yog.Health.average_path_length(graph, opts_int_with_to_float())

    # Single node has no pairs
    assert avg == nil
  end

  test "average_path_length_two_nodes_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

    avg = Yog.Health.average_path_length(graph, opts_int_with_to_float())

    # Two connected nodes: distance 1, average = 1.0
    assert_in_delta avg, 1.0, 0.001
  end

  # ============= Weighted Graph Tests =============

  test "diameter_weighted_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 5)

    diameter = Yog.Health.diameter(graph, opts_int())

    # Max weighted distance is 15 (1 to 3)
    assert diameter == 15
  end

  test "radius_weighted_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 10)
      |> Yog.add_edge!(from: 2, to: 3, with: 5)

    radius = Yog.Health.radius(graph, opts_int())

    # Node 2 has min eccentricity of 10 (max distance to node 1 or node 3)
    assert radius == 10
  end
end
