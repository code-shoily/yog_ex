defmodule Yog.Pathfinding.MatrixTest do
  use ExUnit.Case
  doctest Yog.Pathfinding.Matrix

  alias Yog.Pathfinding.Matrix

  describe "distance_matrix/6 with non-negative weights" do
    test "computes distances between POIs using Dijkstra (few POIs)" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 3, to: 4, with: 2)

      # 3 POIs out of 4 nodes: P = 3, V = 4, so P > V/3, uses Floyd-Warshall
      # Actually 3 <= 4/3 is false, so 3 > 1.33, so uses Floyd-Warshall
      # Let me use 1 POI to ensure Dijkstra path
      pois = [1, 4]

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, pois, 0, &(&1 + &2), &Yog.Utils.compare/2)

      # Distance from 1 to 4 should be 1->2->3->4 = 7
      assert distances[{1, 4}] == 7
      # Undirected
      assert distances[{4, 1}] == 7
      # Self-distance
      assert distances[{1, 1}] == 0
      # 2×2 = 4 entries
      assert map_size(distances) == 4
    end

    test "computes distances using Floyd-Warshall (many POIs)" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      # All 3 nodes as POIs: P = 3, V = 3, P > V/3 (3 > 1), uses Floyd-Warshall
      pois = [1, 2, 3]

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, pois, 0, &(&1 + &2), &Yog.Utils.compare/2)

      assert distances[{1, 2}] == 4
      assert distances[{2, 3}] == 1
      # 4 + 1
      assert distances[{1, 3}] == 5
      # 3×3 = 9 entries
      assert map_size(distances) == 9
    end

    test "handles disconnected nodes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      # Node 3 is isolated

      pois = [1, 2, 3]

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, pois, 0, &(&1 + &2), &Yog.Utils.compare/2)

      assert distances[{1, 2}] == 5
      assert distances[{1, 1}] == 0
      assert distances[{2, 2}] == 0
      assert distances[{3, 3}] == 0
      # No path from 1 to 3 or 2 to 3 in directed graph
      refute Map.has_key?(distances, {1, 3})
      refute Map.has_key?(distances, {2, 3})
    end

    test "handles single POI" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      pois = [1]

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, pois, 0, &(&1 + &2), &Yog.Utils.compare/2)

      assert distances[{1, 1}] == 0
      assert map_size(distances) == 1
    end

    test "handles empty POI list" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, [], 0, &(&1 + &2), &Yog.Utils.compare/2)

      assert distances == %{}
    end
  end

  describe "distance_matrix/6 with negative weights" do
    test "uses Johnson for sparse graphs with negative weights" do
      # Sparse graph: 3 nodes, 2 edges, V²/4 = 9/4 = 2.25, E = 2 < 2.25
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: -2)

      pois = [1, 3]

      assert {:ok, distances} =
               Matrix.distance_matrix(
                 graph,
                 pois,
                 0,
                 &(&1 + &2),
                 &Yog.Utils.compare/2,
                 &(&1 - &2)
               )

      # Shortest path 1->2->3 = 4 + (-2) = 2
      assert distances[{1, 3}] == 2
    end

    test "detects negative cycles" do
      # Graph with negative cycle: 1 -> 2 (1), 2 -> 1 (-3)
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 1, with: -3)

      pois = [1, 2]

      assert {:error, :negative_cycle} =
               Matrix.distance_matrix(
                 graph,
                 pois,
                 0,
                 &(&1 + &2),
                 &Yog.Utils.compare/2,
                 &(&1 - &2)
               )
    end

    test "handles dense graph with negative weights using Floyd-Warshall" do
      # Dense graph: 4 nodes, 6 edges (complete graph), V²/4 = 16/4 = 4, E = 6 >= 4
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
        |> Yog.add_edge_ensure(from: 3, to: 4, with: -1)
        |> Yog.add_edge_ensure(from: 1, to: 3, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 4, with: 3)
        |> Yog.add_edge_ensure(from: 1, to: 4, with: 10)

      pois = [1, 4]

      assert {:ok, distances} =
               Matrix.distance_matrix(
                 graph,
                 pois,
                 0,
                 &(&1 + &2),
                 &Yog.Utils.compare/2,
                 &(&1 - &2)
               )

      # Shortest path should be 1->2->3->4 = 1 + 2 + (-1) = 2
      assert distances[{1, 4}] == 2
    end
  end

  describe "edge cases" do
    test "handles float weights" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1.5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 2.5)

      pois = [1, 3]

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, pois, 0.0, &(&1 + &2), &Yog.Utils.compare/2)

      assert distances[{1, 3}] == 4.0
    end

    test "handles larger graphs" do
      # Build a path graph: 1-2-3-4-5-6-7-8-9-10
      graph =
        Enum.reduce(1..9, Yog.undirected(), fn i, g ->
          g
          |> Yog.add_node(i, nil)
          |> Yog.add_node(i + 1, nil)
          |> Yog.add_edge_ensure(from: i, to: i + 1, with: 1)
        end)

      # Select every other node as POI
      pois = [1, 3, 5, 7, 9]

      assert {:ok, distances} =
               Matrix.distance_matrix(graph, pois, 0, &(&1 + &2), &Yog.Utils.compare/2)

      # Distance from 1 to 9 should be 8 (path 1-2-3-4-5-6-7-8-9)
      assert distances[{1, 9}] == 8
      assert distances[{1, 5}] == 4
      assert distances[{3, 7}] == 4
    end
  end
end
