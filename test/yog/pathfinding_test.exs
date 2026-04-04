defmodule Yog.PathfindingTest do
  use ExUnit.Case

  doctest Yog.Pathfinding

  alias Yog.Pathfinding

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

      # Path 1 -> 4 is 3 edges: 1-2-3-4
      assert distances[1][4] == 3
      assert distances[4][1] == 3
      assert distances[1][2] == 1
      assert distances[2][4] == 2
      # Self-distances are 0
      assert distances[1][1] == 0
      assert distances[2][2] == 0
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

      # Forward path exists
      assert distances[:a][:c] == 2
      assert distances[:a][:b] == 1
      # No backward path in directed graph
      assert distances[:c][:a] == nil
      assert distances[:b][:a] == nil
      # Self-distances
      assert distances[:a][:a] == 0
    end

    test "handles disconnected nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      # Node 3 is isolated

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      assert distances[1][2] == 1
      assert distances[1][1] == 0
      assert distances[2][2] == 0
      assert distances[3][3] == 0
      # No path between disconnected components
      assert distances[1][3] == nil
      assert distances[3][1] == nil
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
      assert map_size(distances) == 1
      assert map_size(distances[1]) == 1
    end

    test "handles cycle graphs" do
      # Triangle cycle
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      # In a triangle, every node is 1 edge away from every other
      assert distances[1][2] == 1
      assert distances[1][3] == 1
      assert distances[2][3] == 1
      # Or the other direction
      assert distances[2][1] == 1
      assert distances[3][1] == 1
      assert distances[3][2] == 1
    end

    test "handles star graph" do
      # Center node 1 connected to all others
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

      # All leaves are 2 edges apart via center
      assert distances[2][3] == 2
      assert distances[2][4] == 2
      assert distances[3][5] == 2
      # All leaves are 1 edge from center
      assert distances[1][2] == 1
      assert distances[1][5] == 1
    end

    test "handles larger path graph" do
      # Build path 1-2-3-...-10
      graph =
        Enum.reduce(1..9, Yog.undirected(), fn i, g ->
          g
          |> Yog.add_node(i, nil)
          |> Yog.add_node(i + 1, nil)
          |> Yog.add_edge_ensure(from: i, to: i + 1, with: 1)
        end)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      # Distance from 1 to 10 is 9 edges
      assert distances[1][10] == 9
      # Distance from 3 to 7 is 4 edges
      assert distances[3][7] == 4
      # Symmetric
      assert distances[10][1] == 9
      assert distances[7][3] == 4
    end

    test "produces correct result structure" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      # Should be a map of maps
      assert is_map(distances)
      assert is_map(distances[1])
      assert is_map(distances[2])
      # Each node should have an entry for itself and reachable nodes
      assert map_size(distances[1]) == 2
      assert map_size(distances[2]) == 2
    end

    test "handles graph with no edges (isolated nodes)" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      # Each node should only have a self-distance entry
      assert distances[1][1] == 0
      assert distances[2][2] == 0
      assert distances[3][3] == 0

      # No paths between different nodes
      assert distances[1][2] == nil
      assert distances[1][3] == nil
      assert distances[2][3] == nil

      # Each source only has one entry (itself)
      assert map_size(distances[1]) == 1
      assert map_size(distances[2]) == 1
      assert map_size(distances[3]) == 1
    end

    test "unreachable nodes return nil (not omitted)" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      distances = Pathfinding.all_pairs_shortest_paths_unweighted(graph)

      # 3 is isolated - accessing its distance from 1 should return nil
      # This differs from floyd_warshall which would omit the key entirely
      assert distances[1][3] == nil
      assert distances[2][3] == nil
      assert distances[3][1] == nil
      assert distances[3][2] == nil

      # But the keys for nodes themselves should exist (with self-distance 0)
      assert distances[3][3] == 0
    end
  end

  # =============================================================================
  # Facade Delegation Tests - Ensure proper delegation to internal modules
  # =============================================================================

  describe "shortest_path/1 (Dijkstra facade)" do
    test "delegates to Dijkstra with correct options" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])

      # Facade call with keyword options
      {:ok, path} = Pathfinding.shortest_path(in: graph, from: 1, to: 3)

      # Verify result structure
      assert %Yog.Pathfinding.Path{} = path
      assert path.nodes == [1, 2, 3]
      assert path.weight == 8
      assert path.algorithm == :dijkstra
    end

    test "passes custom numeric operations to Dijkstra" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      # Use custom comparison function
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

    test "returns :error when no path exists" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")

      # No edges

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

    test "only returns reachable nodes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      # Node 3 is unreachable

      distances = Pathfinding.single_source_distances(in: graph, from: 1)

      assert distances[1] == 0
      assert distances[2] == 5
      assert not Map.has_key?(distances, 3)
    end
  end

  describe "a_star/1 (A* facade)" do
    test "delegates to AStar with heuristic" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 5}, {1, 3, 15}])

      # Zero heuristic (equivalent to Dijkstra)
      {:ok, path} =
        Pathfinding.a_star(
          in: graph,
          from: 1,
          to: 3,
          heuristic: fn _, _ -> 0 end
        )

      # Via node 2
      assert path.weight == 10
      assert path.algorithm == :a_star
    end

    test "requires heuristic option" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      # Missing heuristic should raise KeyError
      assert_raise KeyError, fn ->
        Pathfinding.a_star(in: graph, from: 1, to: 2)
      end
    end

    test "astar/1 is alias for a_star/1" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      {:ok, path1} = Pathfinding.a_star(in: graph, from: 1, to: 2, heuristic: fn _, _ -> 0 end)
      {:ok, path2} = Pathfinding.astar(in: graph, from: 1, to: 2, heuristic: fn _, _ -> 0 end)

      assert path1.weight == path2.weight
    end
  end

  describe "bellman_ford/1 (Bellman-Ford facade)" do
    test "delegates to BellmanFord" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, -3}, {1, 3, 10}])

      {:ok, path} = Pathfinding.bellman_ford(in: graph, from: 1, to: 3)

      # Should find path with negative weight: 5 + (-3) = 2
      assert path.weight == 2
    end

    test "detects negative cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([
          {1, 2, 1},
          {2, 3, -3},
          # Negative cycle: 1 -> 2 -> 3 -> 1 = -1
          {3, 1, 1}
        ])

      assert {:error, :negative_cycle} = Pathfinding.bellman_ford(in: graph, from: 1, to: 2)
    end

    test "returns error when no path exists" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")

      # BellmanFord returns {:error, :no_path} for no path
      assert {:error, :no_path} = Pathfinding.bellman_ford(in: graph, from: 1, to: 2)
    end
  end

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
      # 3 edges
      assert path.weight == 3
    end

    test "handles unreachable nodes" do
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

    test "accepts custom numeric operations" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

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

  describe "floyd_warshall/1 (Floyd-Warshall facade)" do
    test "computes all-pairs shortest paths" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 10}])

      {:ok, distances} = Pathfinding.floyd_warshall(in: graph)

      # Via node 2
      assert distances[{1, 3}] == 8
      assert distances[{1, 2}] == 5
      assert distances[{2, 3}] == 3
      assert distances[{1, 1}] == 0
    end

    test "detects negative cycles" do
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

    test "handles disconnected graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      {:ok, distances} = Pathfinding.floyd_warshall(in: graph)

      # 1 and 2 connected
      assert distances[{1, 2}] == 5
      # 3 is disconnected
      assert not Map.has_key?(distances, {1, 3})
      assert not Map.has_key?(distances, {3, 1})
    end
  end

  describe "johnson/5 (Johnson's algorithm facade)" do
    test "computes all-pairs for sparse graph" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      {:ok, distances} = Pathfinding.johnson(graph)

      # Johnson returns tuple-keyed map
      # Via node 2
      assert distances[{1, 3}] == 8
      assert distances[{1, 2}] == 5
      assert distances[{2, 3}] == 3
    end

    test "handles negative weights without negative cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, -3}, {1, 3, 10}])

      {:ok, distances} = Pathfinding.johnson(graph)

      # Should use the negative weight edge
      # 5 + (-3)
      assert distances[{1, 3}] == 2
    end

    test "detects negative cycles" do
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

  describe "distance_matrix/6 (Matrix facade)" do
    test "computes distances between points of interest" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_node(4, "D")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {3, 4, 2}])

      # Only care about distances between nodes 1 and 4
      points = [1, 4]
      {:ok, matrix} = Pathfinding.distance_matrix(graph, points)

      # 5 + 3 + 2
      assert matrix[{1, 4}] == 10
      assert matrix[{1, 1}] == 0
      assert matrix[{4, 4}] == 0
    end

    test "handles subset of nodes efficiently" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      # Only query two nodes
      points = [1, 3]
      {:ok, matrix} = Pathfinding.distance_matrix(graph, points)

      assert matrix[{1, 3}] == 8
      # Should only have entries for queried nodes
      assert Map.has_key?(matrix, {1, 3})
      assert not Map.has_key?(matrix, {1, 2})
    end
  end

  describe "detect_negative_cycle?/4 (Floyd-Warshall facade)" do
    test "detects negative cycle in graph" do
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

    test "returns false for graph without negative cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edges([{1, 2, 5}])

      refute Pathfinding.detect_negative_cycle?(graph, 0, &Kernel.+/2, &Yog.Utils.compare/2)
    end
  end

  describe "facade consistency tests" do
    test "all single-pair algorithms return consistent Path structs" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}])

      # Test all single-pair algorithms return Path struct
      {:ok, d_path} = Pathfinding.shortest_path(in: graph, from: 1, to: 3)
      {:ok, a_path} = Pathfinding.a_star(in: graph, from: 1, to: 3, heuristic: fn _, _ -> 0 end)
      {:ok, bf_path} = Pathfinding.bellman_ford(in: graph, from: 1, to: 3)
      {:ok, bi_path} = Pathfinding.bidirectional(in: graph, from: 1, to: 3)

      # All should be Path structs with correct weight
      assert %Yog.Pathfinding.Path{} = d_path
      assert %Yog.Pathfinding.Path{} = a_path
      assert %Yog.Pathfinding.Path{} = bf_path
      assert %Yog.Pathfinding.Path{} = bi_path

      # All should have same weight for this simple graph
      assert d_path.weight == 8
      assert a_path.weight == 8
      assert bf_path.weight == 8
      assert bi_path.weight == 8
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

    test "unweighted facade delegates correctly" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      # bidirectional_unweighted should find path of 2 edges
      {:ok, path} = Pathfinding.bidirectional_unweighted(in: graph, from: 1, to: 3)
      assert path.weight == 2
      assert path.algorithm == :bidirectional_bfs
    end
  end
end
