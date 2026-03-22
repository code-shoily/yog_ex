defmodule YogGeneratorRandomTest do
  use ExUnit.Case

  alias Yog.Generator.Random

  # Helper to count edges in an undirected graph
  defp edge_count(graph) do
    {:graph, _type, _nodes, out_edges, _in_edges} = graph

    # For undirected graphs, each edge appears twice (once in each direction)
    # So we count all entries and divide by 2
    out_edges
    |> Map.values()
    |> Enum.map(&map_size/1)
    |> Enum.sum()
    |> div(2)
  end

  # Helper for directed graphs
  defp edge_count_directed(graph) do
    {:graph, _type, _nodes, out_edges, _in_edges} = graph

    out_edges
    |> Map.values()
    |> Enum.map(&map_size/1)
    |> Enum.sum()
  end

  # ============= Erdős-Rényi G(n, p) Tests =============

  test "erdos_renyi_gnp_basic_test" do
    graph = Random.erdos_renyi_gnp(10, 0.5)

    assert Yog.Model.order(graph) == 10
    assert Yog.Model.type(graph) == :undirected
  end

  test "erdos_renyi_gnp_sparse_test" do
    # Very sparse graph
    graph = Random.erdos_renyi_gnp(20, 0.01)

    assert Yog.Model.order(graph) == 20
    # Should have very few edges
    assert edge_count(graph) < 10
  end

  test "erdos_renyi_gnp_directed_test" do
    graph = Random.erdos_renyi_gnp_with_type(10, 0.5, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 10
  end

  test "erdos_renyi_gnp_edge_probability_test" do
    # With p=1.0, should be close to complete graph
    graph = Random.erdos_renyi_gnp(5, 1.0)

    assert Yog.Model.order(graph) == 5
    # K5 has 10 edges (undirected)
    assert edge_count(graph) == 10
  end

  # ============= Erdős-Rényi G(n, m) Tests =============

  test "erdos_renyi_gnm_basic_test" do
    graph = Random.erdos_renyi_gnm(10, 15)

    assert Yog.Model.order(graph) == 10
    # Should have exactly 15 edges
    assert edge_count(graph) == 15
  end

  test "erdos_renyi_gnm_directed_test" do
    graph = Random.erdos_renyi_gnm_with_type(10, 20, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 10
  end

  test "erdos_renyi_gnm_zero_edges_test" do
    graph = Random.erdos_renyi_gnm(5, 0)

    assert Yog.Model.order(graph) == 5
    assert edge_count(graph) == 0
  end

  # ============= Barabási-Albert Tests =============

  test "barabasi_albert_basic_test" do
    graph = Random.barabasi_albert(20, 2)

    assert Yog.Model.order(graph) == 20
    assert Yog.Model.type(graph) == :undirected
  end

  test "barabasi_albert_directed_test" do
    graph = Random.barabasi_albert_with_type(20, 2, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 20
  end

  test "barabasi_albert_scale_free_property_test" do
    # Larger graph to see scale-free properties
    graph = Random.barabasi_albert(50, 3)

    assert Yog.Model.order(graph) == 50

    # Should have some high-degree nodes (hubs)
    degrees =
      for i <- 0..49 do
        length(Yog.neighbors(graph, i))
      end

    max_degree = Enum.max(degrees)
    # In BA model, some nodes should have significantly higher degree
    assert max_degree > 5
  end

  # ============= Watts-Strogatz Tests =============

  test "watts_strogatz_basic_test" do
    graph = Random.watts_strogatz(20, 4, 0.1)

    assert Yog.Model.order(graph) == 20
    assert Yog.Model.type(graph) == :undirected
  end

  test "watts_strogatz_directed_test" do
    graph = Random.watts_strogatz_with_type(20, 4, 0.1, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 20
  end

  test "watts_strogatz_regular_lattice_test" do
    # With p=0, should be a regular ring lattice (no rewiring)
    graph = Random.watts_strogatz(10, 4, 0.0)

    assert Yog.Model.order(graph) == 10
    # In a regular ring lattice with k=4, each node has degree 4
    for i <- 0..9 do
      assert length(Yog.neighbors(graph, i)) == 4
    end
  end

  test "watts_strogatz_fully_random_test" do
    # With p=1.0, all edges are rewired
    graph = Random.watts_strogatz(10, 4, 1.0)

    assert Yog.Model.order(graph) == 10
  end

  # ============= Random Tree Tests =============

  test "random_tree_basic_test" do
    graph = Random.random_tree(10)

    assert Yog.Model.order(graph) == 10
    # A tree has exactly n-1 edges
    assert edge_count(graph) == 9
    assert Yog.Model.type(graph) == :undirected
  end

  test "random_tree_directed_test" do
    graph = Random.random_tree_with_type(10, :directed)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.order(graph) == 10
  end

  test "random_tree_connected_test" do
    # A tree should be connected (all nodes reachable from node 0)
    graph = Random.random_tree(15)

    # Walk from node 0 should reach all nodes
    visited = Yog.walk(graph, 0, :breadth_first)
    assert length(visited) == 15
  end

  test "random_tree_acyclic_test" do
    # A tree should have no cycles
    graph = Random.random_tree(10)

    # Check that it's acyclic
    assert Yog.Property.Cyclicity.acyclic?(graph)
  end

  test "random_tree_single_node_test" do
    graph = Random.random_tree(1)

    assert Yog.Model.order(graph) == 1
    assert edge_count(graph) == 0
  end

  # ============= Edge Cases =============

  test "erdos_renyi_gnp_zero_nodes_test" do
    graph = Random.erdos_renyi_gnp(0, 0.5)
    assert Yog.Model.order(graph) == 0
  end

  test "erdos_renyi_gnm_zero_nodes_test" do
    graph = Random.erdos_renyi_gnm(0, 0)
    assert Yog.Model.order(graph) == 0
  end

  test "barabasi_albert_small_test" do
    # BA model with m=1 (each new node connects to 1 existing)
    graph = Random.barabasi_albert(5, 1)

    assert Yog.Model.order(graph) == 5
    # Should form a tree-like structure (n-1 edges)
    assert edge_count(graph) == 4
  end

  test "random_tree_two_nodes_test" do
    graph = Random.random_tree(2)

    assert Yog.Model.order(graph) == 2
    assert edge_count(graph) == 1
  end
end
