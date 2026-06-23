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

  # ---------------------------------------------------------------------------
  # Successive Shortest Path min-cost flow
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-FLOW-004 Successive Shortest Path min-cost flow agrees with NetworkX" do
    check all(
            graph <- Yog.Generators.min_cost_flow_problem_gen(),
            max_runs: 50
          ) do
      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      yog_result =
        Yog.Flow.SuccessiveShortestPath.min_cost_flow(graph, get_demand, get_capacity, get_cost)

      nodes = Yog.Model.all_nodes(graph)

      demands_map =
        Map.new(nodes, fn node -> {node, get_demand.(Yog.Model.node(graph, node))} end)

      edge_attrs =
        Enum.flat_map(nodes, fn from ->
          Yog.Model.successors(graph, from)
          |> Enum.map(fn {to, data} ->
            %{
              "from" => from,
              "to" => to,
              "capacity" => get_capacity.(data),
              "cost" => get_cost.(data)
            }
          end)
        end)

      nx_result =
        NetworkX.run("min_cost_flow", graph,
          demands: demands_map,
          edge_attrs: edge_attrs
        )

      case {yog_result, nx_result} do
        {{:ok, yog_flow_res}, %{"status" => "ok", "cost" => nx_cost}} ->
          assert yog_flow_res.cost == nx_cost

        {{:error, :infeasible}, %{"status" => "error", "reason" => "infeasible"}} ->
          :ok

        {{:error, :unbalanced_demands}, %{"status" => "error", "reason" => "unbalanced"}} ->
          :ok

        {yog, nx} ->
          flunk(
            "Mismatch between Yog and NetworkX. Yog: #{inspect(yog)}, NetworkX: #{inspect(nx)}"
          )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Network Simplex min-cost flow
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-FLOW-005 Network Simplex min-cost flow agrees with NetworkX" do
    check all(
            graph <- Yog.Generators.min_cost_flow_problem_gen(),
            max_runs: 50
          ) do
      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      yog_result =
        Yog.Flow.NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost)

      nodes = Yog.Model.all_nodes(graph)

      demands_map =
        Map.new(nodes, fn node -> {node, get_demand.(Yog.Model.node(graph, node))} end)

      edge_attrs =
        Enum.flat_map(nodes, fn from ->
          Yog.Model.successors(graph, from)
          |> Enum.map(fn {to, data} ->
            %{
              "from" => from,
              "to" => to,
              "capacity" => get_capacity.(data),
              "cost" => get_cost.(data)
            }
          end)
        end)

      nx_result =
        NetworkX.run("min_cost_flow", graph,
          demands: demands_map,
          edge_attrs: edge_attrs
        )

      case {yog_result, nx_result} do
        {{:ok, yog_flow_res}, %{"status" => "ok", "cost" => nx_cost}} ->
          assert yog_flow_res.cost == nx_cost

        {{:error, :infeasible}, %{"status" => "error", "reason" => "infeasible"}} ->
          :ok

        {{:error, :unbalanced_demands}, %{"status" => "error", "reason" => "unbalanced"}} ->
          :ok

        {{:error, :unbounded}, %{"status" => "error", "reason" => "unbounded"}} ->
          :ok

        {yog, nx} ->
          flunk(
            "Mismatch between Yog and NetworkX. Yog: #{inspect(yog)}, NetworkX: #{inspect(nx)}"
          )
      end
    end
  end
end
