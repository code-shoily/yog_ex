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
end
