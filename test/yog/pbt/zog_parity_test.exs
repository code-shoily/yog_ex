defmodule Yog.PBT.ZogParityTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  alias Yog.Builder.Zog
  alias Yog.Zog.ResourceGraph

  @moduletag :zigler

  describe "Native vs Elixir Parity Properties" do
    property "Metrics: density, triangle_count, clustering_coefficient, assortativity" do
      check all(graph <- positive_undirected_graph_gen()) do
        builder = Zog.from_graph(graph)
        res_graph = ResourceGraph.new(builder)

        try do
          # 1. Density
          native_density = Yog.Zog.Metrics.density(builder)
          res_density = ResourceGraph.density(res_graph)
          elixir_density = Yog.Community.Metrics.density(graph)

          assert_in_delta native_density, elixir_density, 1.0e-5
          assert_in_delta res_density, elixir_density, 1.0e-5

          # 2. Triangle Count
          native_triangles = Yog.Zog.Metrics.triangle_count(builder)
          res_triangles = ResourceGraph.triangle_count(res_graph)
          elixir_triangles = Yog.Community.Metrics.count_triangles(graph)
          assert native_triangles == elixir_triangles
          assert res_triangles == elixir_triangles

          # 3. Average Clustering Coefficient
          native_avg_cc = Yog.Zog.Metrics.average_clustering_coefficient(builder)
          res_avg_cc = ResourceGraph.average_clustering_coefficient(res_graph)
          elixir_avg_cc = Yog.Community.Metrics.average_clustering_coefficient(graph)
          assert_in_delta native_avg_cc, elixir_avg_cc, 1.0e-4
          assert_in_delta res_avg_cc, elixir_avg_cc, 1.0e-4

          # 4. Local Clustering Coefficient
          native_local_cc = Yog.Zog.Metrics.local_clustering_coefficient(builder)
          res_local_cc = ResourceGraph.local_clustering_coefficient(res_graph)

          for node <- Yog.all_nodes(graph) do
            elixir_cc = Yog.Community.Metrics.clustering_coefficient(graph, node)
            assert_in_delta native_local_cc[node], elixir_cc, 1.0e-4
            assert_in_delta res_local_cc[node], elixir_cc, 1.0e-4
          end

          # 5. Assortativity (only if graph has edges)
          if length(Yog.all_edges(graph)) > 0 do
            elixir_assort = Yog.Health.assortativity(graph)
            native_assort = Yog.Zog.Metrics.assortativity(builder)
            res_assort = ResourceGraph.assortativity(res_graph)

            if is_number(native_assort) do
              assert_in_delta native_assort, elixir_assort, 1.0e-3
            end

            if is_number(res_assort) do
              assert_in_delta res_assort, elixir_assort, 1.0e-3
            end
          end
        after
          ResourceGraph.destroy(res_graph)
        end
      end
    end

    property "Centrality: pagerank, eigenvector, betweenness, closeness, harmonic" do
      check all(graph <- positive_undirected_graph_gen()) do
        builder = Zog.from_graph(graph)
        res_graph = ResourceGraph.new(builder)

        try do
          # 1. PageRank
          native_pr = Yog.Zog.Centrality.pagerank(builder)
          res_pr = ResourceGraph.pagerank(res_graph)
          elixir_pr = Yog.Centrality.pagerank(graph)

          for node <- Yog.all_nodes(graph) do
            assert_in_delta native_pr[node], elixir_pr[node], 1.0e-3
            assert_in_delta res_pr[node], elixir_pr[node], 1.0e-3
          end

          # 2. Eigenvector (only if number of nodes > 1 and has edges)
          has_edges = length(Yog.all_edges(graph)) > 0

          if has_edges and map_size(graph.nodes) > 1 do
            native_ev = Yog.Zog.Centrality.eigenvector(builder)
            res_ev = ResourceGraph.eigenvector(res_graph)
            elixir_ev = Yog.Centrality.eigenvector(graph)

            for node <- Yog.all_nodes(graph) do
              assert_in_delta abs(native_ev[node]), abs(elixir_ev[node]), 0.25
              assert_in_delta abs(res_ev[node]), abs(elixir_ev[node]), 0.25
            end
          end

          # 3. Betweenness Unweighted
          unweighted_graph = Yog.map_edges(graph, fn _ -> 1 end)
          elixir_bet_unweighted = Yog.Centrality.betweenness(unweighted_graph)
          native_bet_unweighted = Yog.Zog.Centrality.betweenness_unweighted(builder)
          res_bet_unweighted = ResourceGraph.betweenness_unweighted(res_graph)

          for node <- Yog.all_nodes(graph) do
            assert_in_delta native_bet_unweighted[node], elixir_bet_unweighted[node], 1.0e-3
            assert_in_delta res_bet_unweighted[node], elixir_bet_unweighted[node], 1.0e-3
          end

          # 4. Closeness
          native_close = Yog.Zog.Centrality.closeness_f64(builder)
          res_close = ResourceGraph.closeness_f64(res_graph)
          elixir_close = Yog.Centrality.closeness(graph)

          for node <- Yog.all_nodes(graph) do
            assert_in_delta native_close[node], elixir_close[node], 1.0e-3
            assert_in_delta res_close[node], elixir_close[node], 1.0e-3
          end

          # 5. Harmonic
          native_harm = Yog.Zog.Centrality.harmonic_centrality_f64(builder)
          res_harm = ResourceGraph.harmonic_centrality_f64(res_graph)
          elixir_harm = Yog.Centrality.harmonic(graph)

          for node <- Yog.all_nodes(graph) do
            assert_in_delta native_harm[node], elixir_harm[node], 1.0e-3
            assert_in_delta res_harm[node], elixir_harm[node], 1.0e-3
          end
        after
          ResourceGraph.destroy(res_graph)
        end
      end
    end

    property "Pathfinding: floyd_warshall and johnsons parity" do
      check all(
              nodes <- node_list_gen(2, 10),
              weights <- weight_list_gen(length(nodes), 1..50),
              graph = build_graph(:directed, nodes, weights)
            ) do
        builder = Zog.from_graph(graph)
        res_graph = ResourceGraph.new(builder)

        try do
          # 1. Floyd-Warshall
          assert {:ok, el_matrix} = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph)
          assert {:ok, nat_matrix} = Yog.Zog.Pathfinding.floyd_warshall(builder)
          assert {:ok, res_matrix} = ResourceGraph.floyd_warshall(res_graph)

          labels = Zog.all_labels(builder)

          for {u, i} <- Enum.with_index(labels) do
            for {v, j} <- Enum.with_index(labels) do
              elixir_val = Map.get(el_matrix, {u, v})
              native_val = Enum.at(Enum.at(nat_matrix, i), j)
              res_val = Enum.at(Enum.at(res_matrix, i), j)

              if u == v do
                assert native_val == 0.0 or native_val == 0
                assert res_val == 0.0 or res_val == 0
              else
                case elixir_val do
                  nil ->
                    assert native_val == :infinity
                    assert res_val == :infinity

                  val ->
                    assert_in_delta native_val, val * 1.0, 1.0e-3
                    assert_in_delta res_val, val * 1.0, 1.0e-3
                end
              end
            end
          end

          # 2. Johnson's Parity
          assert {:ok, el_j_matrix} = Yog.Pathfinding.johnson(graph)
          assert {:ok, nat_j_matrix} = Yog.Zog.Pathfinding.johnsons(builder)
          assert {:ok, res_j_matrix} = ResourceGraph.johnsons(res_graph)

          labels = Zog.all_labels(builder)

          for {u, i} <- Enum.with_index(labels) do
            for {v, j} <- Enum.with_index(labels) do
              elixir_val = Map.get(el_j_matrix, {u, v})
              native_val = Enum.at(Enum.at(nat_j_matrix, i), j)
              res_val = Enum.at(Enum.at(res_j_matrix, i), j)

              if u == v do
                assert native_val == 0.0 or native_val == 0
                assert res_val == 0.0 or res_val == 0
              else
                case elixir_val do
                  nil ->
                    assert native_val == :infinity
                    assert res_val == :infinity

                  val ->
                    assert_in_delta native_val, val * 1.0, 1.0e-3
                    assert_in_delta res_val, val * 1.0, 1.0e-3
                end
              end
            end
          end
        after
          ResourceGraph.destroy(res_graph)
        end
      end
    end

    property "Pathfinding: negative cycle detection parity" do
      check all(
              nodes <- node_list_gen(3, 10),
              weights <- weight_list_gen(length(nodes), -20..20),
              graph = build_graph(:directed, nodes, weights)
            ) do
        builder = Zog.from_graph(graph)
        res_graph = ResourceGraph.new(builder)

        try do
          elixir_fw = Yog.Pathfinding.FloydWarshall.floyd_warshall(graph)
          native_fw = Yog.Zog.Pathfinding.floyd_warshall(builder)
          res_fw = ResourceGraph.floyd_warshall(res_graph)

          case elixir_fw do
            {:error, :negative_cycle} ->
              assert native_fw == {:error, :negative_cycle}
              assert res_fw == {:error, :negative_cycle}

            _ ->
              assert {:ok, _} = native_fw
              assert {:ok, _} = res_fw
          end
        after
          ResourceGraph.destroy(res_graph)
        end
      end
    end

    property "Flow: max_flow and global_min_cut parity" do
      check all({graph, s, t} <- flow_problem_gen()) do
        builder = Zog.from_graph(graph)
        res_graph = ResourceGraph.new(builder)

        try do
          # 1. Edmonds-Karp Max Flow Parity
          el_ek = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)
          nat_ek = Yog.Zog.Flow.max_flow(builder, s, t, :edmonds_karp)
          res_ek = ResourceGraph.max_flow(res_graph, s, t, :edmonds_karp)

          assert_in_delta nat_ek.max_flow, el_ek.max_flow, 1.0e-3
          assert_in_delta res_ek.max_flow, el_ek.max_flow, 1.0e-3

          # 2. Push-Relabel / Dinic Flow Parity
          el_dinic = Yog.Flow.MaxFlow.dinic(graph, s, t)
          nat_pr = Yog.Zog.Flow.max_flow(builder, s, t, :push_relabel)
          res_pr = ResourceGraph.max_flow(res_graph, s, t, :push_relabel)

          assert_in_delta nat_pr.max_flow, el_dinic.max_flow, 1.0e-3
          assert_in_delta res_pr.max_flow, el_dinic.max_flow, 1.0e-3

          # 3. Global Min Cut Parity
          undirected_graph = Yog.to_undirected(graph, fn a, b -> a + b end)

          if length(Yog.all_edges(undirected_graph)) > 0 do
            undir_builder = Zog.from_graph(undirected_graph)
            undir_res = ResourceGraph.new(undir_builder)

            try do
              el_cut = Yog.Flow.MinCut.global_min_cut(undirected_graph)
              nat_cut = Yog.Zog.Flow.global_min_cut(undir_builder)
              res_cut = ResourceGraph.global_min_cut(undir_res)

              assert_in_delta nat_cut.cut_value, el_cut.cut_value, 1.0e-3
              assert_in_delta res_cut.cut_value, el_cut.cut_value, 1.0e-3

              all_nodes_count = map_size(undirected_graph.nodes)
              assert length(nat_cut.source_side) + length(nat_cut.sink_side) == all_nodes_count
              assert length(res_cut.source_side) + length(res_cut.sink_side) == all_nodes_count
            after
              ResourceGraph.destroy(undir_res)
            end
          end
        after
          ResourceGraph.destroy(res_graph)
        end
      end
    end

    property "Community: Louvain, Leiden, and Modularity bounds" do
      check all(graph <- positive_undirected_graph_gen()) do
        if length(Yog.all_edges(graph)) > 0 do
          builder = Zog.from_graph(graph)
          res_graph = ResourceGraph.new(builder)

          try do
            # 1. Louvain Community Detection
            nat_louvain = Yog.Zog.Community.louvain(builder)
            res_louvain = ResourceGraph.louvain(res_graph)
            el_louvain = Yog.Community.Louvain.detect(graph)

            verify_partition_pbt(graph, nat_louvain)
            verify_partition_pbt(graph, res_louvain)

            nat_louvain_mod = Yog.Zog.Community.modularity(builder, nat_louvain)
            res_louvain_mod = ResourceGraph.modularity(res_graph, res_louvain)
            el_louvain_mod = Yog.Community.Metrics.modularity(graph, el_louvain)

            assert nat_louvain_mod >= el_louvain_mod - 0.1
            assert res_louvain_mod >= el_louvain_mod - 0.1

            # 2. Leiden Community Detection
            nat_leiden = Yog.Zog.Community.leiden(builder)
            res_leiden = ResourceGraph.leiden(res_graph)
            el_leiden = Yog.Community.Leiden.detect(graph)

            verify_partition_pbt(graph, nat_leiden)
            verify_partition_pbt(graph, res_leiden)

            nat_leiden_mod = Yog.Zog.Community.modularity(builder, nat_leiden)
            res_leiden_mod = ResourceGraph.modularity(res_graph, res_leiden)
            el_leiden_mod = Yog.Community.Metrics.modularity(graph, el_leiden)

            assert nat_leiden_mod >= el_leiden_mod - 0.1
            assert res_leiden_mod >= el_leiden_mod - 0.1

            # 3. Hierarchical Leiden Community Detection
            nat_leiden_h = Yog.Zog.Community.leiden_hierarchical(builder)
            res_leiden_h = ResourceGraph.leiden_hierarchical(res_graph)

            assert length(nat_leiden_h.levels) >= 1
            assert length(res_leiden_h.levels) >= 1

            verify_partition_pbt(graph, nat_leiden_h)
            verify_partition_pbt(graph, res_leiden_h)
          after
            ResourceGraph.destroy(res_graph)
          end
        end
      end
    end

    property "Connectivity: core_numbers, detect, and analyze (bridges/articulation_points)" do
      check all(graph <- positive_undirected_graph_gen()) do
        builder = Zog.from_graph(graph)
        res_graph = ResourceGraph.new(builder)

        try do
          # 1. Core numbers
          elixir_cores = Yog.Connectivity.KCore.core_numbers(graph)
          native_cores = Yog.Zog.Connectivity.core_numbers(builder)
          res_cores = ResourceGraph.core_numbers(res_graph)

          assert native_cores == elixir_cores
          assert res_cores == elixir_cores

          # 2. Detect k-cores
          for k <- 0..4 do
            elixir_kcore = Yog.Connectivity.KCore.detect(graph, k)
            native_kcore_builder = Yog.Zog.Connectivity.detect(builder, k)
            native_kcore = Zog.to_graph(native_kcore_builder)

            assert Yog.node_count(native_kcore) == Yog.node_count(elixir_kcore)
            assert Yog.edge_count(native_kcore) == Yog.edge_count(elixir_kcore)
          end

          # 3. Analyze connectivity
          elixir_analysis = Yog.Connectivity.Analysis.analyze(graph)
          native_analysis = Yog.Zog.Connectivity.analyze(builder)
          res_analysis = ResourceGraph.analyze(res_graph)

          assert native_analysis.articulation_points == elixir_analysis.articulation_points
          assert native_analysis.bridges == elixir_analysis.bridges
          assert res_analysis.articulation_points == elixir_analysis.articulation_points
          assert res_analysis.bridges == elixir_analysis.bridges
        after
          ResourceGraph.destroy(res_graph)
        end
      end
    end

    property "Property: cliques and coloring" do
      check all(graph <- positive_undirected_graph_gen()) do
        builder = Zog.from_graph(graph)

        # 1. Maximal Cliques
        elixir_cliques = Yog.Property.Clique.all_maximal_cliques(graph) |> Enum.sort()
        native_cliques = Yog.Zog.Property.all_maximal_cliques(builder) |> Enum.sort()
        assert native_cliques == elixir_cliques

        # 2. Maximum Clique
        elixir_max_clique = Yog.Property.Clique.max_clique(graph)
        native_max_clique = Yog.Zog.Property.max_clique(builder)
        assert MapSet.size(native_max_clique) == MapSet.size(elixir_max_clique)

        # 3. DSatur Coloring
        {native_chi, native_colors} = Yog.Zog.Property.coloring_dsatur(builder)
        {elixir_chi, elixir_colors} = Yog.Property.Coloring.coloring_dsatur(graph)
        assert native_chi == elixir_chi
        verify_coloring(graph, native_colors)
        verify_coloring(graph, elixir_colors)

        # 4. Exact Coloring
        case Yog.Zog.Property.coloring_exact(builder) do
          {:ok, native_exact_chi, native_exact_colors} ->
            case Yog.Property.Coloring.coloring_exact(graph) do
              {:ok, elixir_exact_chi, _elixir_exact_colors} ->
                assert native_exact_chi == elixir_exact_chi
                verify_coloring(graph, native_exact_colors)

              _ ->
                :ok
            end

          _ ->
            :ok
        end
      end
    end
  end

  defp verify_partition_pbt(graph, result) do
    assignments =
      case result do
        %Yog.Community.Result{assignments: ass} -> ass
        %Yog.Community.Dendrogram{levels: levels} -> List.last(levels).assignments
        ass when is_map(ass) -> ass
      end

    all_nodes = Yog.all_nodes(graph) |> MapSet.new()
    assigned_nodes = Map.keys(assignments) |> MapSet.new()

    assert MapSet.equal?(all_nodes, assigned_nodes)

    ids = Map.values(assignments) |> Enum.uniq()
    assert length(ids) > 0
  end

  defp verify_coloring(graph, color_map) do
    for {u, neighbors} <- graph.out_edges do
      for {v, _weight} <- neighbors do
        if Map.has_key?(color_map, u) and Map.has_key?(color_map, v) do
          assert color_map[u] != color_map[v]
        end
      end
    end
  end
end
