defmodule Yog.PathfindingTest do
  @moduledoc """
  Tests for Yog.Pathfinding facade module.

  These tests verify the unified facade properly delegates to internal modules:
  - Dijkstra for single-source shortest paths
  - AStar for heuristic-guided search
  - BellmanFord for negative weights/cycle detection
  - Bidirectional for bidirectional search
  - FloydWarshall for all-pairs shortest paths
  - Johnson for sparse graph all-pairs
  - Matrix for distance matrix computation
  """

  use ExUnit.Case

  doctest Yog.Pathfinding

  alias Yog.Pathfinding

  # =============================================================================
  # all_pairs_shortest_paths_unweighted/1 (direct implementation)
  # =============================================================================

  describe "all_pairs_shortest_paths_unweighted/1" do
    test "computes distances in a simple path graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert distances[1][4] == 3
      assert distances[4][1] == 3
      assert distances[1][2] == 1
      assert distances[1][1] == 0
    end

    test "handles directed graphs" do
      graph =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_edge_ensure(from: :a, to: :b, with: 1)
        |> Yog.add_edge_ensure(from: :b, to: :c, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert distances[:a][:c] == 2
      assert distances[:c][:a] == nil
    end

    test "handles disconnected nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert distances[1][2] == 1
      assert distances[1][3] == nil
      assert distances[3][3] == 0
    end

    test "handles empty graph" do
      graph = Yog.undirected()
      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)
      assert distances == %{}
    end

    test "handles single node graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)
      assert distances[1][1] == 0
    end

    test "handles cycle graphs" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert distances[1][2] == 1
      assert distances[1][3] == 1
      assert distances[2][3] == 1
    end

    test "handles star graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_node(5, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 4, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 5, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert distances[2][3] == 2
      assert distances[1][2] == 1
    end

    test "produces correct result structure" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert is_map(distances)
      assert is_map(distances[1])
      assert map_size(distances[1]) == 2
    end
  end

  # =============================================================================
  # Dijkstra Facade - shortest_path/1, single_source_distances/1
  # =============================================================================

  describe "shortest_path/1 (Dijkstra facade)" do
    test "delegates to Dijkstra module with keyword options" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])

      {:ok, path} = Pathfinding.shortest_path(in: graph, from: 1, to: 3)

      # Verify result comes from Dijkstra module
      assert %Yog.Pathfinding.Path{} = path
      assert path.nodes == [1, 2, 3]
      assert path.weight == 8
      assert path.algorithm == :dijkstra
    end

    test "passes custom numeric operations through to Dijkstra" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edges([{1, 2, 5}])

      {:ok, path} =
        Pathfinding.shortest_path(
          in: graph,
          from: 1,
          to: 2,
          zero: 0,
          add: &Kernel.+/2,
          compare: &Yog.Utils.compare/2
        )

      assert path.weight == 5
    end

    test "returns :error when Dijkstra finds no path" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")

      assert :error = Pathfinding.shortest_path(in: graph, from: 1, to: 2)
    end

    test "handles same source and target" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_edge_ensure(from: 1, to: 1, with: 5)

      {:ok, path} = Pathfinding.shortest_path(in: graph, from: 1, to: 1)

      assert path.nodes == [1]
      assert path.weight == 0
    end
  end

  describe "single_source_distances/1 (Dijkstra facade)" do
    test "delegates to Dijkstra.single_source_distances" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {1, 3, 10}])

      distances = Pathfinding.single_source_distances(in: graph, from: 1)

      assert distances[1] == 0
      assert distances[2] == 5
      assert distances[3] == 10
    end

    test "only returns reachable nodes from Dijkstra" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      distances = Pathfinding.single_source_distances(in: graph, from: 1)

      assert distances[1] == 0
      assert distances[2] == 5
      assert not Map.has_key?(distances, 3)
    end
  end

  # =============================================================================
  # A* Facade - a_star/1, astar/1
  # =============================================================================

  describe "a_star/1 (AStar facade)" do
    test "delegates to AStar module with heuristic option" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 5}, {1, 3, 15}])

      {:ok, path} =
        Pathfinding.a_star(
          in: graph,
          from: 1,
          to: 3,
          heuristic: fn _, _ -> 0 end
        )

      # Verify AStar result
      assert path.weight == 10
      assert path.algorithm == :a_star
    end

    test "requires heuristic option from AStar" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      assert_raise KeyError, fn ->
        Pathfinding.a_star(in: graph, from: 1, to: 2)
      end
    end

    test "astar/1 is alias for a_star/1 - both delegate to same function" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      {:ok, path1} = Pathfinding.a_star(in: graph, from: 1, to: 2, heuristic: fn _, _ -> 0 end)
      {:ok, path2} = Pathfinding.astar(in: graph, from: 1, to: 2, heuristic: fn _, _ -> 0 end)

      assert path1.weight == path2.weight
      assert path1.nodes == path2.nodes
    end
  end

  # =============================================================================
  # Bellman-Ford Facade - bellman_ford/1
  # =============================================================================

  describe "bellman_ford/1 (BellmanFord facade)" do
    test "delegates to BellmanFord module" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, -3}, {1, 3, 10}])

      {:ok, path} = Pathfinding.bellman_ford(in: graph, from: 1, to: 3)

      # BellmanFord handles negative weights correctly
      assert path.weight == 2
    end

    test "receives negative cycle detection from BellmanFord" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([
          {1, 2, 1},
          {2, 3, -3},
          {3, 1, 1}
        ])

      assert {:error, :negative_cycle} = Pathfinding.bellman_ford(in: graph, from: 1, to: 2)
    end

    test "receives no path error from BellmanFord" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")

      assert {:error, :no_path} = Pathfinding.bellman_ford(in: graph, from: 1, to: 2)
    end
  end

  # =============================================================================
  # Bidirectional Facade - bidirectional/1, bidirectional_unweighted/1
  # =============================================================================

  describe "bidirectional_unweighted/1 (Bidirectional BFS facade)" do
    test "delegates to Bidirectional.shortest_path_unweighted" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

      {:ok, path} = Pathfinding.bidirectional_unweighted(in: graph, from: 1, to: 4)

      assert path.nodes == [1, 2, 3, 4]
      assert path.weight == 3
      assert path.algorithm == :bidirectional_bfs
    end

    test "receives error from Bidirectional on unreachable nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)

      assert :error = Pathfinding.bidirectional_unweighted(in: graph, from: 1, to: 2)
    end
  end

  describe "bidirectional/1 (Bidirectional Dijkstra facade)" do
    test "delegates to Bidirectional.shortest_path" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 5}])

      {:ok, path} = Pathfinding.bidirectional(in: graph, from: 1, to: 3)

      assert path.weight == 10
      assert path.nodes == [1, 2, 3]
    end

    test "passes custom numeric operations to Bidirectional" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edges([{1, 2, 5}])

      {:ok, path} =
        Pathfinding.bidirectional(
          in: graph,
          from: 1,
          to: 2,
          zero: 0,
          add: &Kernel.+/2,
          compare: &Yog.Utils.compare/2
        )

      assert path.weight == 5
    end
  end

  # =============================================================================
  # Floyd-Warshall Facade - floyd_warshall/1, detect_negative_cycle?/4
  # =============================================================================

  describe "floyd_warshall/1 (FloydWarshall facade)" do
    test "delegates to FloydWarshall.floyd_warshall" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])

      {:ok, distances} = Pathfinding.floyd_warshall(in: graph)

      # FloydWarshall returns tuple-keyed map
      assert distances[{1, 3}] == 8
      assert distances[{1, 2}] == 5
      assert distances[{2, 3}] == 3
    end

    test "receives negative cycle detection from FloydWarshall" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([
          {1, 2, 1},
          {2, 3, -3},
          {3, 1, 1}
        ])

      assert {:error, :negative_cycle} = Pathfinding.floyd_warshall(in: graph)
    end

    test "handles disconnected graph from FloydWarshall" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      {:ok, distances} = Pathfinding.floyd_warshall(in: graph)

      assert distances[{1, 2}] == 5
      assert not Map.has_key?(distances, {1, 3})
    end
  end

  describe "detect_negative_cycle?/4 (FloydWarshall facade)" do
    test "delegates to FloydWarshall.detect_negative_cycle?" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([
          {1, 2, 1},
          {2, 3, -3},
          {3, 1, 1}
        ])

      assert Pathfinding.detect_negative_cycle?(graph, 0, &Kernel.+/2, &Yog.Utils.compare/2)
    end

    test "receives false from FloydWarshall for no negative cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edges([{1, 2, 5}])

      refute Pathfinding.detect_negative_cycle?(graph, 0, &Kernel.+/2, &Yog.Utils.compare/2)
    end
  end

  # =============================================================================
  # Johnson's Algorithm Facade - johnson/5
  # =============================================================================

  describe "johnson/5 (Johnson facade)" do
    test "delegates to Johnson.johnson" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      {:ok, distances} = Pathfinding.johnson(graph)

      # Johnson returns tuple-keyed map
      assert distances[{1, 3}] == 8
      assert distances[{1, 2}] == 5
    end

    test "receives negative weight handling from Johnson" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, -3}, {1, 3, 10}])

      {:ok, distances} = Pathfinding.johnson(graph)

      assert distances[{1, 3}] == 2
    end

    test "receives negative cycle detection from Johnson" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([
          {1, 2, 1},
          {2, 3, -3},
          {3, 1, 1}
        ])

      assert {:error, :negative_cycle} = Pathfinding.johnson(graph)
    end
  end

  # =============================================================================
  # Matrix Facade - distance_matrix/6
  # =============================================================================

  describe "distance_matrix/6 (Matrix facade)" do
    test "delegates to Matrix.distance_matrix" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_node(4, "D")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {3, 4, 2}])

      points = [1, 4]
      {:ok, matrix} = Pathfinding.distance_matrix(graph, points)

      assert matrix[{1, 4}] == 10
      assert matrix[{1, 1}] == 0
    end

    test "receives subset filtering from Matrix" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      points = [1, 3]
      {:ok, matrix} = Pathfinding.distance_matrix(graph, points)

      assert matrix[{1, 3}] == 8
      assert not Map.has_key?(matrix, {1, 2})
    end
  end

  # =============================================================================
  # Cross-Algorithm Consistency Tests
  # =============================================================================

  describe "cross-algorithm consistency" do
    test "all single-pair algorithms return consistent Path structs" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      {:ok, d_path} = Pathfinding.shortest_path(in: graph, from: 1, to: 3)
      {:ok, a_path} = Pathfinding.a_star(in: graph, from: 1, to: 3, heuristic: fn _, _ -> 0 end)
      {:ok, bf_path} = Pathfinding.bellman_ford(in: graph, from: 1, to: 3)
      {:ok, bi_path} = Pathfinding.bidirectional(in: graph, from: 1, to: 3)

      assert %Yog.Pathfinding.Path{} = d_path
      assert %Yog.Pathfinding.Path{} = a_path
      assert %Yog.Pathfinding.Path{} = bf_path
      assert %Yog.Pathfinding.Path{} = bi_path

      # All should agree on shortest path weight
      assert d_path.weight == 8
      assert a_path.weight == 8
      assert bf_path.weight == 8
      assert bi_path.weight == 8
    end

    test "all-pairs algorithms agree on distances" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      {:ok, fw_distances} = Pathfinding.floyd_warshall(in: graph)
      {:ok, j_distances} = Pathfinding.johnson(graph)

      assert fw_distances[{1, 3}] == j_distances[{1, 3}]
      assert fw_distances[{1, 2}] == j_distances[{1, 2}]
    end

    test "facade handles edge cases consistently" do
      # Empty graph
      empty = Yog.directed()
      assert :error = Pathfinding.shortest_path(in: empty, from: 1, to: 2)
      assert {:ok, %{}} = Pathfinding.floyd_warshall(in: empty)
      assert %{} = Pathfinding.all_pairs_shortest_paths_unweighted(empty)

      # Single node
      single = Yog.directed() |> Yog.add_node(1, nil)
      assert {:ok, path} = Pathfinding.shortest_path(in: single, from: 1, to: 1)
      assert path.weight == 0
    end
  end
end
