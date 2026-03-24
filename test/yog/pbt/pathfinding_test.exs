defmodule Yog.PBT.PathfindingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Pathfinding Properties" do
    property "Shortest Path: Dijkstra agrees with BFS on unweighted graphs" do
      check all(
              nodes <- node_list_gen(2, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_graph(:directed, nodes, weights),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        # Create unweighted version (all weights = 1)
        unweighted =
          Enum.reduce(Yog.all_edges(graph), Yog.new(graph.kind), fn {u, v, _}, g ->
            g |> Yog.add_node(u, nil) |> Yog.add_node(v, nil) |> Yog.add_edge!(u, v, 1)
          end)

        # BFS shortest path (via Traversal)
        bfs_path = Yog.Traversal.find_path(unweighted, s, t)

        # Dijkstra shortest path
        dijkstra_result = Yog.Pathfinding.Dijkstra.shortest_path_int(unweighted, s, t)

        case {bfs_path, dijkstra_result} do
          {b_path, {:ok, d_path}} when is_list(b_path) ->
            assert length(b_path) == length(d_path.nodes)
            assert d_path.weight == length(d_path.nodes) - 1

          {nil, :error} ->
            assert true

          _ ->
            flunk(
              "Inconsistent pathfinding between BFS and Dijkstra: BFS=#{inspect(bfs_path)}, Dijkstra=#{inspect(dijkstra_result)}"
            )
        end
      end
    end

    property "Dijkstra vs Bellman-Ford vs A*: Consistency on non-negative weights" do
      check all(
              nodes <- node_list_gen(2, 20),
              # Non-negative weights
              weights <- weight_list_gen(length(nodes), 0..100),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        graph = build_graph(:directed, nodes, weights)

        d_res = Yog.Pathfinding.Dijkstra.shortest_path_int(graph, s, t)
        bf_res = Yog.Pathfinding.BellmanFord.bellman_ford_int(graph, s, t)

        # A* with zero heuristic (Dijkstra)
        a_res = Yog.Pathfinding.AStar.a_star_int(graph, s, t, fn _, _ -> 0 end)

        case {d_res, bf_res, a_res} do
          {{:ok, d}, {:ok, bf}, {:ok, a}} ->
            assert d.weight == bf.weight
            assert d.weight == a.weight

          {:error, {:error, :no_path}, :error} ->
            assert true

          _ ->
            flunk("Inconsistent shortest path weights between algorithms")
        end
      end
    end

    property "Bellman-Ford: Detects negative cycles" do
      check all(
              nodes <- node_list_gen(3, 10),
              # Small weights to create controllable cycles
              weights <- weight_list_gen(length(nodes), -10..10),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        graph = build_graph(:directed, nodes, weights)

        # If FW detects it, BF should too
        fw_res = Yog.Pathfinding.FloydWarshall.floyd_warshall_int(graph)
        bf_res = Yog.Pathfinding.BellmanFord.bellman_ford_int(graph, s, t)

        if fw_res == {:error, :negative_cycle} do
          # BF only detects reachable negative cycles
          # If a negative cycle is reachable from s, BF MUST return :negative_cycle
          if Yog.Pathfinding.BellmanFord.has_negative_cycle?(
               graph,
               s,
               0,
               &+/2,
               &Yog.Utils.compare/2
             ) do
            assert bf_res == {:error, :negative_cycle}
          end
        end
      end
    end

    property "Bidirectional vs Dijkstra: Correctness" do
      check all(
              nodes <- node_list_gen(2, 12),
              weights <- weight_list_gen(length(nodes), 1..100),
              graph = build_graph(:undirected, nodes, weights),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        # Use unweighted for simplicity initially
        # Let's force all weights to 1 for this comparison
        unweighted =
          Enum.reduce(Yog.all_edges(graph), Yog.new(:undirected), fn {u, v, _}, g ->
            g |> Yog.add_node(u, nil) |> Yog.add_node(v, nil) |> Yog.add_edge!(u, v, 1)
          end)

        d_res = Yog.Pathfinding.Dijkstra.shortest_path_int(unweighted, s, t)
        bi_res = Yog.Pathfinding.Bidirectional.shortest_path_unweighted(unweighted, s, t)

        case {d_res, bi_res} do
          {{:ok, d_p}, {:ok, bi_p}} ->
            assert d_p.weight == bi_p.weight

          {:error, :error} ->
            assert true

          _ ->
            flunk("Inconsistent results in Bidirectional comparison")
        end
      end
    end

    property "All-Pairs: Floyd-Warshall agrees with Dijkstra multi-run" do
      check all(
              nodes <- node_list_gen(2, 10),
              weights <- weight_list_gen(length(nodes), 0..50)
            ) do
        graph = build_graph(:directed, nodes, weights)

        fw_res = Yog.Pathfinding.FloydWarshall.floyd_warshall_int(graph)

        matrix_res =
          Yog.Pathfinding.Matrix.distance_matrix(graph, nodes, 0, &+/2, &Yog.Utils.compare/2)

        case {fw_res, matrix_res} do
          {{:ok, fw}, {:ok, mat}} ->
            for {u, v} <- Map.keys(fw), u in nodes and v in nodes do
              if u == v do
                assert fw[{u, v}] == 0
              else
                assert fw[{u, v}] == mat[{u, v}]
              end
            end

          _ ->
            flunk("Inconsistent matrix results")
        end
      end
    end
  end
end
