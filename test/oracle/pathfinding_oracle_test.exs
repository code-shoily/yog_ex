defmodule Yog.Oracle.PathfindingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.Oracle.NetworkX

  setup_all do
    case NetworkX.adapter_health() do
      :ok ->
        :ok

      {:error, reason} ->
        {:skip, "NetworkX adapter not healthy: #{inspect(reason)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp assert_maps_close(m1, m2, delta: delta) do
    assert Map.keys(m1) |> Enum.sort() == Map.keys(m2) |> Enum.sort()

    for {k, v1} <- m1 do
      v2 = Map.fetch!(m2, k)
      assert_in_delta v1, v2, delta, "mismatch at #{inspect(k)}: yog=#{v1}, nx=#{v2}"
    end
  end

  # ---------------------------------------------------------------------------
  # Dijkstra (exact-output)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-001 Dijkstra agrees with NetworkX on shortest path lengths" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            source <- StreamData.member_of(nodes),
            max_runs: 100
          ) do
      yog_distances = Yog.Pathfinding.Dijkstra.single_source_distances(graph, source)

      nx_distances =
        NetworkX.run("single_source_dijkstra_path_length", graph,
          source: source,
          weight: "weight"
        )

      # Both libraries omit unreachable nodes, so direct comparison works
      assert_maps_close(yog_distances, nx_distances, delta: 1.0e-9)
    end
  end

  @tag :oracle
  property "P-ORAC-PATH-002 Dijkstra path length matches NetworkX point-to-point" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            source <- StreamData.member_of(nodes),
            target <- StreamData.member_of(nodes),
            source != target,
            max_runs: 100
          ) do
      yog_result = Yog.Pathfinding.Dijkstra.shortest_path(graph, source, target)

      nx_result =
        NetworkX.run("dijkstra_path_length", graph,
          source: source,
          target: target,
          weight: "weight"
        )

      case {yog_result, nx_result} do
        {{:ok, %{weight: w}}, nx_length} when is_number(nx_length) ->
          assert_in_delta w, nx_length, 1.0e-9

        {:error, {:error, :no_path}} ->
          assert true

        _ ->
          flunk(
            "Mismatched Dijkstra result: yog=#{inspect(yog_result)}, nx=#{inspect(nx_result)}"
          )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # A* (exact-output with zero heuristic → Dijkstra)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-003 A* with zero heuristic agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            source <- StreamData.member_of(nodes),
            target <- StreamData.member_of(nodes),
            source != target,
            max_runs: 100
          ) do
      yog_result = Yog.Pathfinding.AStar.a_star(graph, source, target, fn _, _ -> 0 end)

      nx_result =
        NetworkX.run("astar_path", graph,
          source: source,
          target: target,
          weight: "weight"
        )

      case {yog_result, nx_result} do
        {{:ok, yog_path}, nx_path} when is_list(nx_path) ->
          assert length(yog_path.nodes) == length(nx_path)
          assert yog_path.weight == path_length(graph, nx_path)

        {:error, {:error, :no_path}} ->
          assert true

        _ ->
          flunk("Mismatched A* result: yog=#{inspect(yog_result)}, nx=#{inspect(nx_result)}")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bellman-Ford (exact-output, negative cycle handling)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-004 Bellman-Ford agrees with NetworkX on non-negative graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 20),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            source <- StreamData.member_of(nodes),
            target <- StreamData.member_of(nodes),
            source != target,
            max_runs: 100
          ) do
      yog_result = Yog.Pathfinding.BellmanFord.bellman_ford(graph, source, target)

      nx_result =
        NetworkX.run("bellman_ford_path_length", graph,
          source: source,
          target: target,
          weight: "weight"
        )

      case {yog_result, nx_result} do
        {{:ok, yog_path}, nx_length} when is_number(nx_length) ->
          assert_in_delta yog_path.weight, nx_length, 1.0e-9

        {{:error, :negative_cycle}, {:error, :negative_cycle}} ->
          assert true

        {{:error, :no_path}, {:error, :no_path}} ->
          assert true

        _ ->
          flunk(
            "Mismatched Bellman-Ford result: yog=#{inspect(yog_result)}, nx=#{inspect(nx_result)}"
          )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Floyd-Warshall (all-pairs exact-output)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-005 Floyd-Warshall agrees with NetworkX on all-pairs distances" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..50),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph)

      case yog_result do
        {:error, :negative_cycle} ->
          # NetworkX also raises on negative cycles; skip this graph
          assert true

        {:ok, yog_distances} ->
          nx_distances =
            NetworkX.run("floyd_warshall", graph, weight: "weight")

          # Yog returns %{{u, v} => distance}; NetworkX returns nested dicts.
          # Compare only the finite distances Yog reports.
          for {{u, v}, d} <- yog_distances, d != :infinity do
            nx_d = get_in(nx_distances, [u, v])
            assert nx_d != nil, "NetworkX missing distance #{u} -> #{v}"
            assert_in_delta d, nx_d, 1.0e-9
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Johnson (all-pairs sparse exact-output)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-006 Johnson agrees with NetworkX on all-pairs distances" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..50),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Pathfinding.Johnson.johnson(graph)

      case yog_result do
        {:error, :negative_cycle} ->
          assert true

        {:ok, yog_distances} ->
          nx_distances = NetworkX.run("johnson", graph, weight: "weight")

          for {{u, v}, d} <- yog_distances, d != :infinity do
            nx_d = get_in(nx_distances, [u, v])
            assert nx_d != nil, "NetworkX missing distance #{u} -> #{v}"
            assert_in_delta d, nx_d, 1.0e-9
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bidirectional Dijkstra (exact-output)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-007 Bidirectional Dijkstra agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            source <- StreamData.member_of(nodes),
            target <- StreamData.member_of(nodes),
            source != target,
            max_runs: 100
          ) do
      yog_result = Yog.Pathfinding.Bidirectional.shortest_path(graph, source, target)

      nx_result =
        NetworkX.run("bidirectional_dijkstra", graph,
          source: source,
          target: target,
          weight: "weight"
        )

      case {yog_result, nx_result} do
        {{:ok, yog_path}, %{length: length}} ->
          assert_in_delta yog_path.weight, length, 1.0e-9
          assert length(yog_path.nodes) == length(nx_result.path)

        {:error, {:error, :no_path}} ->
          assert true

        _ ->
          flunk(
            "Mismatched bidirectional Dijkstra result: yog=#{inspect(yog_result)}, nx=#{inspect(nx_result)}"
          )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bidirectional BFS (unweighted exact-output)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PATH-009 Bidirectional BFS agrees with NetworkX on unweighted graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            # Force unit weights
            edges = Enum.map(edges, fn {u, v, _} -> {u, v, 1} end),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            source <- StreamData.member_of(nodes),
            target <- StreamData.member_of(nodes),
            source != target,
            max_runs: 100
          ) do
      yog_result = Yog.Pathfinding.Bidirectional.shortest_path_unweighted(graph, source, target)

      nx_result =
        NetworkX.run("bidirectional_shortest_path", graph,
          source: source,
          target: target
        )

      case {yog_result, nx_result} do
        {{:ok, yog_path}, nx_path} when is_list(nx_path) ->
          assert length(yog_path.nodes) == length(nx_path)

        {:error, {:error, :no_path}} ->
          assert true

        _ ->
          flunk(
            "Mismatched bidirectional BFS result: yog=#{inspect(yog_result)}, nx=#{inspect(nx_result)}"
          )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp path_length(graph, path) do
    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [u, v] ->
      # Find edge weight from u to v
      graph.out_edges[u][v] || 0
    end)
    |> Enum.sum()
  end
end
