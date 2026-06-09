defmodule Yog.Oracle.CentralityTest do
  use ExUnit.Case, async: false
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

  # Generates simple edges without self-loops to avoid degree convention divergence.
  defp simple_edges_gen(num_nodes) do
    StreamData.list_of(
      {StreamData.integer(0..(num_nodes - 1)), StreamData.integer(0..(num_nodes - 1)),
       StreamData.integer(-100..100)},
      max_length: 30
    )
    |> StreamData.map(fn edges -> Enum.reject(edges, fn {u, v, _} -> u == v end) end)
  end

  # ---------------------------------------------------------------------------
  # Degree centrality — exact-output, robust
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-001 Degree centrality agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.degree(graph)

      nx_result = NetworkX.run("degree_centrality", graph, [])

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  @tag :oracle
  property "P-ORAC-CENT-002 In-degree centrality agrees with NetworkX on directed graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.degree(graph, :in_degree)

      nx_result = NetworkX.run("in_degree_centrality", graph, [])

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  @tag :oracle
  property "P-ORAC-CENT-003 Out-degree centrality agrees with NetworkX on directed graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.degree(graph, :out_degree)

      nx_result = NetworkX.run("out_degree_centrality", graph, [])

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  # ---------------------------------------------------------------------------
  # Remaining centrality measures
  #
  # Closeness, Harmonic, Betweenness — deferred due to semantic differences on
  # disconnected graphs and self-loops (see PARITY.md §Centrality).
  #
  # PageRank, HITS, Katz, Eigenvector — deferred due to normalization and
  # convergence convention differences between YogEx and NetworkX.
  # ---------------------------------------------------------------------------
end
