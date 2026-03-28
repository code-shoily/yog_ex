defmodule Yog.ConnectivityTest do
  use ExUnit.Case

  alias Yog.Connectivity

  doctest Yog.Connectivity

  # Helper to add multiple nodes since Yog.add_nodes doesn't exist
  defp add_nodes(graph, nodes) do
    Enum.reduce(nodes, graph, fn {id, data}, acc ->
      Yog.add_node(acc, id, data)
    end)
  end

  # ============= Basic Connectivity Tests (analyze) =============

  test "connectivity_empty_graph_test" do
    graph = Yog.undirected()
    result = Connectivity.analyze(in: graph)
    assert result.bridges == []
    assert result.articulation_points == []
  end

  test "connectivity_single_node_test" do
    graph = Yog.undirected() |> Yog.add_node(1, "A")
    result = Connectivity.analyze(in: graph)
    assert result.bridges == []
    assert result.articulation_points == []
  end

  test "connectivity_two_nodes_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    result = Connectivity.analyze(in: graph)
    assert length(result.bridges) == 1
    assert {1, 2} in result.bridges
    assert result.articulation_points == []
  end

  test "connectivity_linear_chain_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    result = Connectivity.analyze(in: graph)
    assert length(result.bridges) == 3
    assert {1, 2} in result.bridges
    assert {2, 3} in result.bridges
    assert {3, 4} in result.bridges
    assert length(result.articulation_points) == 2
    assert 2 in result.articulation_points
    assert 3 in result.articulation_points
  end

  test "connectivity_triangle_no_bridges_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    result = Connectivity.analyze(in: graph)
    assert result.bridges == []
    assert result.articulation_points == []
  end

  # ============= Strongly Connected Components (SCC) Tests =============

  test "scc_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

    result = Connectivity.strongly_connected_components(graph)
    assert length(result) == 2
  end

  test "scc_simple_cycle_test" do
    graph =
      Yog.directed()
      |> add_nodes([{1, "A"}, {2, "B"}, {3, "C"}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])

    result = Connectivity.strongly_connected_components(graph)
    assert length(result) == 1
    assert length(hd(result)) == 3
  end

  test "scc_mixed_test" do
    graph =
      Yog.directed()
      |> add_nodes([{1, "A"}, {2, "B"}, {3, "C"}, {4, "D"}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}, {3, 4, 1}])

    result = Connectivity.strongly_connected_components(graph)
    assert length(result) == 2
    sizes = Enum.map(result, &length/1) |> Enum.sort()
    assert sizes == [1, 3]
  end

  # ============= Kosaraju's Algorithm Tests =============

  test "kosaraju_simple_cycle_test" do
    graph =
      Yog.directed()
      |> add_nodes([{1, "A"}, {2, "B"}, {3, "C"}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])

    result = Connectivity.kosaraju(graph)
    assert length(result) == 1
    assert length(hd(result)) == 3
  end

  test "kosaraju_classic_example_test" do
    graph =
      Yog.directed()
      |> add_nodes([{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {5, "5"}])
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1},
        {3, 1, 1},
        {3, 4, 1},
        {4, 5, 1},
        {5, 4, 1}
      ])

    result = Connectivity.kosaraju(graph)
    assert length(result) == 2
    sizes = Enum.map(result, &length/1) |> Enum.sort()
    assert sizes == [2, 3]
  end

  # ============= Connected Components (Undirected) =============

  test "cc_isolated_nodes_test" do
    graph =
      Yog.undirected()
      |> add_nodes([{1, "A"}, {2, "B"}, {3, "C"}])

    result = Connectivity.connected_components(graph)
    assert length(result) == 3
    assert Enum.all?(result, &(length(&1) == 1))
  end

  test "cc_complex_graph_test" do
    graph =
      Yog.undirected()
      |> add_nodes([{1, "A"}, {2, "B"}, {3, "C"}, {4, "D"}])
      |> Yog.add_edges!([{1, 2, 1}, {3, 4, 1}])

    result = Connectivity.connected_components(graph)
    assert length(result) == 2
    assert Enum.all?(result, &(length(&1) == 2))
  end

  # ============= Weakly Connected Components (Directed) =============

  test "wcc_opposing_arrows_test" do
    # 1 -> 2 <- 3
    graph =
      Yog.directed()
      |> add_nodes([{1, "A"}, {2, "B"}, {3, "C"}])
      |> Yog.add_edges!([{1, 2, 1}, {3, 2, 1}])

    wccs = Connectivity.weakly_connected_components(graph)
    sccs = Connectivity.strongly_connected_components(graph)

    # WCC: All one component
    assert length(wccs) == 1
    assert length(hd(wccs)) == 3

    # SCC: Three separate components (no cycles)
    assert length(sccs) == 3
  end

  test "wcc_complex_graph_test" do
    graph =
      Yog.directed()
      |> add_nodes([
        {1, "A"},
        {2, "B"},
        {3, "C"},
        {4, "D"},
        {5, "E"},
        {6, "F"},
        {7, "G"},
        {8, "H"}
      ])
      # WCC 1
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {4, 2, 1}])
      # WCC 2 (cycle)
      |> Yog.add_edges!([{5, 6, 1}, {6, 7, 1}, {7, 5, 1}])

    # WCC 3 (8 is isolated)

    result = Connectivity.weakly_connected_components(graph)
    assert length(result) == 3
    sizes = Enum.map(result, &length/1) |> Enum.sort()
    assert sizes == [1, 3, 4]
  end

  # ============= Bridge Ordering Test =============

  test "connectivity_bridge_ordering_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(5, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_edge_ensure(from: 5, to: 3, with: 1)

    result = Connectivity.analyze(in: graph)
    # Bridges should be stored in canonical order (lower ID first)
    assert result.bridges == [{3, 5}]
  end

  # ============= Reachability Tests =============

  test "reachability_counts_linear_test" do
    # 1 -> 2 -> 3
    graph =
      Yog.directed()
      |> add_nodes([{1, "1"}, {2, "2"}, {3, "3"}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

    descendants = Connectivity.reachability_counts(graph, :descendants)
    assert descendants[1] == 2
    assert descendants[2] == 1
    assert descendants[3] == 0

    ancestors = Connectivity.reachability_counts(graph, :ancestors)
    assert ancestors[1] == 0
    assert ancestors[2] == 1
    assert ancestors[3] == 2
  end

  test "reachability_counts_cyclic_test" do
    # 1 -> 2 -> 3 -> 1 (cycle) , 3 -> 4
    graph =
      Yog.directed()
      |> add_nodes([{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}, {3, 4, 1}])

    # 1, 2, 3 can each reach themselves and 4.
    # But reachability_counts excludes the node itself?
    # Let's check the implementation.
    # In DAG, descendants = all nodes reachable from me.
    # In my generalized version:
    # node_count + (my_scc_size - 1)
    # For node 1 (SCC size 3): reach 4 (size 1) + (3 - 1) = 3 total.
    # Node 1 reaches 2, 3, 4.

    descendants = Connectivity.reachability_counts(graph, :descendants)
    assert descendants[1] == 3
    assert descendants[2] == 3
    assert descendants[3] == 3
    assert descendants[4] == 0

    ancestors = Connectivity.reachability_counts(graph, :ancestors)
    # 4 is reached by 1, 2, 3
    assert ancestors[4] == 3
    # 1 is reached by 2, 3
    assert ancestors[1] == 2
  end

  test "reachability_counts_diamond_test" do
    # a -> b, a -> c, b -> d, c -> d
    graph =
      Yog.directed()
      |> add_nodes([{:a, 1}, {:b, 2}, {:c, 3}, {:d, 4}])
      |> Yog.add_edges!([{:a, :b, 1}, {:a, :c, 2}, {:b, :d, 3}, {:c, :d, 4}])

    descendants = Connectivity.reachability_counts(graph, :descendants)
    # a can reach b, c, d (3 nodes)
    assert descendants[:a] == 3
    assert descendants[:b] == 1
    assert descendants[:c] == 1
    assert descendants[:d] == 0

    ancestors = Connectivity.reachability_counts(graph, :ancestors)
    # d can be reached from a, b, c (3 nodes)
    assert ancestors[:d] == 3
    assert ancestors[:a] == 0
  end

  # ============= K-Core & Shell Decomposition Tests =============

  test "k_core_decomposition_test" do
    # 0 --- 1 --- 2
    #       | \ / |
    #       |  3  |
    #       | / \ |
    #       4 --- 5
    graph =
      Yog.undirected()
      |> add_nodes([{0, nil}, {1, nil}, {2, nil}, {3, nil}, {4, nil}, {5, nil}])
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {1, 3, 1},
        {2, 3, 1},
        {3, 4, 1},
        {3, 5, 1},
        {4, 5, 1},
        {1, 4, 1}
      ])

    # Core numbers:
    # 0: degree 1 -> core 1
    # 1: stays in after 0 is removed (deg becomes 3) -> core 3 (actually wait)
    # Let's re-calculate:
    # Initially: 0:1, 1:4, 2:2, 3:4, 4:3, 5:2
    # Process i=1: node 0 (deg 1). core[0]=1. nbr 1 deg 4->3.
    # Process i=2: nodes 2, 5 (deg 2).
    #   Take 2: core[2]=2. nbrs 1, 3 degs 3->2, 4->3.
    #   Take 5: core[5]=2. nbrs 3, 4 degs 3->2, 3->2.
    # Process i=3: nodes 1, 3, 4 (deg 2, but max(2, current_deg) is used).
    #   Wait, if we process them at i=2:
    #   Take 1: core[1]=2. nbr 4 deg 2->1.
    #   Take 3: core[3]=2. nbr 4 deg 1->0.
    #   Take 4: core[4]=2.
    # So all except 0 have core 2.

    cores = Connectivity.core_numbers(graph)
    assert cores[0] == 1
    assert cores[1] == 2
    assert cores[2] == 2
    assert cores[3] == 2
    assert cores[4] == 2
    assert cores[5] == 2

    shells = Connectivity.shell_decomposition(graph)
    assert Map.keys(shells) |> Enum.sort() == [1, 2]
    assert shells[1] == [0]
    assert MapSet.new(shells[2]) == MapSet.new([1, 2, 3, 4, 5])
  end

  test "k_core_clique_test" do
    # K4 clique: every node connects to every other node
    graph =
      Yog.undirected()
      |> add_nodes([{1, nil}, {2, nil}, {3, nil}, {4, nil}])
      |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}, {1, 4, 1}, {2, 3, 1}, {2, 4, 1}, {3, 4, 1}])

    cores = Connectivity.core_numbers(graph)

    assert Enum.all?(Map.values(cores), fn c -> c == 3 end)

    assert Connectivity.degeneracy(graph) == 3
  end
end
