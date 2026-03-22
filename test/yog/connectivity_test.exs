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
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

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
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

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
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

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
      |> Yog.add_edge!(from: 1, to: 2, with: 1)

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
      |> Yog.add_edge!(from: 5, to: 3, with: 1)

    result = Connectivity.analyze(in: graph)
    # Bridges should be stored in canonical order (lower ID first)
    assert result.bridges == [{3, 5}]
  end
end
