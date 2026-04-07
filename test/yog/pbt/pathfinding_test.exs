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
            g |> Yog.add_node(u, nil) |> Yog.add_node(v, nil) |> Yog.add_edge_ensure(u, v, 1)
          end)

        # BFS shortest path (via Traversal)
        bfs_path = Yog.Traversal.find_path(unweighted, s, t)

        # Dijkstra shortest path
        dijkstra_result = Yog.Pathfinding.Dijkstra.shortest_path(unweighted, s, t)

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

        d_res = Yog.Pathfinding.Dijkstra.shortest_path(graph, s, t)
        bf_res = Yog.Pathfinding.BellmanFord.bellman_ford(graph, s, t)

        # A* with zero heuristic (Dijkstra)
        a_res = Yog.Pathfinding.AStar.a_star(graph, s, t, fn _, _ -> 0 end)

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
        fw_res = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph)
        bf_res = Yog.Pathfinding.BellmanFord.bellman_ford(graph, s, t)

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
            g |> Yog.add_node(u, nil) |> Yog.add_node(v, nil) |> Yog.add_edge_ensure(u, v, 1)
          end)

        d_res = Yog.Pathfinding.Dijkstra.shortest_path(unweighted, s, t)
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

        fw_res = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph)

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

    property "All-Pairs Unweighted: Self-distances are zero" do
      check all(
              nodes <- node_list_gen(1, 15),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights)
            ) do
        distances = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)

        for node <- nodes do
          assert distances[node][node] == 0
        end
      end
    end

    property "All-Pairs Unweighted: Symmetric in undirected graphs" do
      check all(
              nodes <- node_list_gen(2, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph_undirected(nodes, weights)
            ) do
        # Pick 2 distinct nodes deterministically
        [s, t] = Enum.take(nodes, 2)

        distances = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)

        dist_st = distances[s][t]
        dist_ts = distances[t][s]

        # In undirected graphs, distance should be symmetric
        assert dist_st == dist_ts
      end
    end

    property "All-Pairs Unweighted: Triangle inequality holds" do
      check all(
              nodes <- node_list_gen(3, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights)
            ) do
        # Pick 3 distinct nodes deterministically
        [a, b, c] = nodes |> Enum.uniq() |> Enum.take(3)

        distances = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)

        ab = distances[a][b]
        bc = distances[b][c]
        ac = distances[a][c]

        # If all paths exist, triangle inequality: d(a,c) <= d(a,b) + d(b,c)
        if ab != nil and bc != nil and ac != nil do
          assert ac <= ab + bc
        end
      end
    end

    property "All-Pairs Unweighted: Consistent with BFS single-source" do
      check all(
              nodes <- node_list_gen(2, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights),
              s <- StreamData.member_of(nodes)
            ) do
        # Get all-pairs result
        all_pairs = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)

        # Get BFS result for single source
        bfs_distances =
          Yog.Pathfinding.Dijkstra.single_source_distances(
            graph,
            s,
            0,
            &+/2,
            &Yog.Utils.compare/2
          )

        # Should match for all reachable nodes
        for t <- nodes do
          ap_dist = all_pairs[s][t]
          bfs_dist = Map.get(bfs_distances, t)

          case {ap_dist, bfs_dist} do
            {nil, nil} -> :ok
            {d, d} when is_integer(d) -> :ok
            {nil, _} -> flunk("BFS found path but all-pairs didn't for #{s} -> #{t}")
            {_, nil} -> flunk("All-pairs found path but BFS didn't for #{s} -> #{t}")
            _ -> flunk("Distance mismatch for #{s} -> #{t}: #{ap_dist} vs #{bfs_dist}")
          end
        end
      end
    end

    property "All-Pairs Unweighted: Consistent with Floyd-Warshall on unit weights" do
      check all(
              nodes <- node_list_gen(2, 10),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights)
            ) do
        all_pairs = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)

        fw_res =
          Yog.Pathfinding.FloydWarshall.floyd_warshall(graph, 0, &+/2, &Yog.Utils.compare/2)

        case fw_res do
          {:ok, fw_distances} ->
            for u <- nodes, v <- nodes do
              ap_dist = all_pairs[u][v]
              fw_dist = Map.get(fw_distances, {u, v})

              case {ap_dist, fw_dist} do
                {nil, nil} -> :ok
                {d, d} when is_integer(d) -> :ok
                {0, 0} -> :ok
                _ -> flunk("Mismatch for #{u} -> #{v}: AP=#{ap_dist}, FW=#{fw_dist}")
              end
            end

          {:error, :negative_cycle} ->
            # Skip graphs with negative cycles (shouldn't happen with unit weights anyway)
            :ok
        end
      end
    end

    property "All-Pairs Unweighted: Reachability is transitive" do
      check all(
              nodes <- node_list_gen(3, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights)
            ) do
        # Pick 3 distinct nodes deterministically
        [a, b, c] = nodes |> Enum.uniq() |> Enum.take(3)

        distances = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)

        # If a can reach b and b can reach c, then a can reach c
        ab_reachable = distances[a][b] != nil
        bc_reachable = distances[b][c] != nil
        ac_reachable = distances[a][c] != nil

        if ab_reachable and bc_reachable do
          assert ac_reachable,
                 "Transitivity violated: #{a} -> #{b} and #{b} -> #{c} but not #{a} -> #{c}"
        end
      end
    end
  end

  # =============================================================================
  # shortest_path_unweighted/3 Properties
  # =============================================================================

  describe "shortest_path_unweighted/3 Properties" do
    property "Shortest path length matches BFS distance" do
      check all(
              nodes <- node_list_gen(2, 15),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        # Single-pair BFS result
        sp_result = Yog.Pathfinding.shortest_path_unweighted(graph, s, t)

        # All-pairs BFS for verification
        all_pairs = Yog.Pathfinding.all_pairs_shortest_paths_unweighted(graph)
        expected_dist = all_pairs[s][t]

        case {sp_result, expected_dist} do
          {{:ok, path}, dist} when is_integer(dist) ->
            # Path length should be distance + 1 (nodes vs edges)
            assert length(path) == dist + 1
            assert hd(path) == s
            assert List.last(path) == t

          {{:error, :no_path}, nil} ->
            assert true

          _ ->
            flunk("Mismatch: sp=#{inspect(sp_result)}, dist=#{inspect(expected_dist)}")
        end
      end
    end

    property "Shortest path unweighted agrees with Dijkstra on unweighted graphs" do
      check all(
              nodes <- node_list_gen(2, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        bfs_result = Yog.Pathfinding.shortest_path_unweighted(graph, s, t)
        dijkstra_result = Yog.Pathfinding.Dijkstra.shortest_path(graph, s, t)

        case {bfs_result, dijkstra_result} do
          {{:ok, bfs_path}, {:ok, d_path}} ->
            # Both should find paths of same length
            assert length(bfs_path) == length(d_path.nodes)

          {{:error, :no_path}, :error} ->
            assert true

          _ ->
            flunk(
              "Inconsistent: BFS=#{inspect(bfs_result)}, Dijkstra=#{inspect(dijkstra_result)}"
            )
        end
      end
    end

    property "Shortest path is symmetric in undirected graphs" do
      check all(
              nodes <- node_list_gen(2, 12),
              edges <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph_undirected(nodes, edges),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        st_result = Yog.Pathfinding.shortest_path_unweighted(graph, s, t)
        ts_result = Yog.Pathfinding.shortest_path_unweighted(graph, t, s)

        case {st_result, ts_result} do
          {{:ok, st_path}, {:ok, ts_path}} ->
            # Paths should have same length (though may be different routes)
            assert length(st_path) == length(ts_path)

          {{:error, :no_path}, {:error, :no_path}} ->
            assert true

          _ ->
            flunk(
              "Asymmetric result: #{s}->#{t}=#{inspect(st_result)}, #{t}->#{s}=#{inspect(ts_result)}"
            )
        end
      end
    end

    property "Path concatenation: if s->t and t->u, then s->u exists (triangle inequality)" do
      check all(
              nodes <- node_list_gen(3, 12),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights)
            ) do
        # Pick 3 distinct nodes
        uniq_nodes = Enum.uniq(nodes)

        if length(uniq_nodes) >= 3 do
          [s, t, u] = Enum.take(uniq_nodes, 3)

          st = Yog.Pathfinding.shortest_path_unweighted(graph, s, t)
          tu = Yog.Pathfinding.shortest_path_unweighted(graph, t, u)
          su = Yog.Pathfinding.shortest_path_unweighted(graph, s, u)

          case {st, tu, su} do
            {{:ok, _}, {:ok, _}, {:ok, _}} ->
              # Both segments exist, s->u should exist
              assert true

            {{:ok, _}, {:ok, _}, {:error, :no_path}} ->
              # This violates triangle inequality - should not happen!
              flunk(
                "Triangle inequality violated: #{s}->#{t} and #{t}->#{u} exist but #{s}->#{u} does not"
              )

            _ ->
              # Other cases are fine
              assert true
          end
        end
      end
    end

    property "Shortest path uses at most V-1 edges" do
      check all(
              nodes <- node_list_gen(2, 15),
              weights <- weight_list_gen(length(nodes)),
              graph = build_unweighted_graph(nodes, weights),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        result = Yog.Pathfinding.shortest_path_unweighted(graph, s, t)
        num_nodes = length(nodes)

        case result do
          {:ok, path} ->
            # Path length (nodes) <= num_nodes (no cycles)
            assert length(path) <= num_nodes
            # Path has at least 2 nodes (s and t)
            assert length(path) >= 2

          {:error, :no_path} ->
            assert true
        end
      end
    end
  end

  # Helper to build unweighted directed graph (all weights = 1)
  defp build_unweighted_graph(nodes, edges) do
    graph = Yog.new(:directed)
    graph = Enum.reduce(nodes, graph, fn id, g -> Yog.add_node(g, id, nil) end)

    Enum.reduce(edges, graph, fn {from_idx, to_idx, _}, g ->
      from = Enum.at(nodes, from_idx)
      to = Enum.at(nodes, to_idx)

      if from != nil and to != nil do
        case Yog.add_edge(g, from, to, 1) do
          {:ok, new_g} -> new_g
          {:error, _} -> g
        end
      else
        g
      end
    end)
  end

  # Helper to build unweighted undirected graph
  defp build_unweighted_graph_undirected(nodes, edges) do
    graph = Yog.new(:undirected)
    graph = Enum.reduce(nodes, graph, fn id, g -> Yog.add_node(g, id, nil) end)

    Enum.reduce(edges, graph, fn {from_idx, to_idx, _}, g ->
      from = Enum.at(nodes, from_idx)
      to = Enum.at(nodes, to_idx)

      if from != nil and to != nil do
        case Yog.add_edge(g, from, to, 1) do
          {:ok, new_g} -> new_g
          {:error, _} -> g
        end
      else
        g
      end
    end)
  end
end
