defmodule Yog.Oracle.FlowTest do
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
  # Edmonds-Karp max flow
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-FLOW-001 Edmonds-Karp max flow agrees with NetworkX" do
    check all(
            {graph, s, t} <- Yog.Generators.flow_problem_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)

      nx_flow =
        NetworkX.run("maximum_flow", graph,
          source: s,
          target: t,
          flow_func: "edmonds_karp",
          capacity: "weight"
        )

      assert_in_delta yog_result.max_flow, nx_flow, 1.0e-9
    end
  end

  # ---------------------------------------------------------------------------
  # Dinic max flow
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-FLOW-002 Dinic max flow agrees with NetworkX" do
    check all(
            {graph, s, t} <- Yog.Generators.flow_problem_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Flow.MaxFlow.dinic(graph, s, t)

      nx_flow =
        NetworkX.run("maximum_flow", graph,
          source: s,
          target: t,
          flow_func: "dinitz",
          capacity: "weight"
        )

      assert_in_delta yog_result.max_flow, nx_flow, 1.0e-9
    end
  end

  # ---------------------------------------------------------------------------
  # Stoer-Wagner global min cut
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-FLOW-003 Stoer-Wagner min cut value agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 20),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 0..100),
            # Guarantee connectivity with a path backbone (use indices, not node IDs)
            indices = Enum.to_list(0..(length(nodes) - 1)),
            backbone = Enum.chunk_every(indices, 2, 1, :discard),
            backbone_edges = Enum.map(backbone, fn [u, v] -> {u, v, 1} end),
            all_edges = edges ++ backbone_edges,
            graph = Yog.Generators.build_graph(:undirected, nodes, all_edges),
            max_runs: 50
          ) do
      yog_result = Yog.Flow.MinCut.global_min_cut(graph)

      nx_cut =
        NetworkX.run("stoer_wagner", graph, weight: "weight")

      assert_in_delta yog_result.cut_value, nx_cut, 1.0e-9
    end
  end
end
