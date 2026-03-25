defmodule Yog.PBT.FlowTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Flow Properties" do
    property "Max-Flow Min-Cut Theorem: max_flow value equals cut capacity" do
      check all({graph, s, t} <- flow_problem_gen()) do
        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)
        cut = Yog.Flow.MaxFlow.extract_min_cut(result)

        cut_value = Yog.Flow.MinCutResult.compute_cut_value(cut, graph)
        assert result.max_flow == cut_value
      end
    end

    property "Flow Conservation and Capacity Constraints" do
      check all({graph, s, t} <- flow_problem_gen()) do
        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)
        res_graph = result.residual_graph

        all_node_ids = Yog.all_nodes(graph)

        # Calculate net flow out for each node
        net_flows =
          Enum.reduce(all_node_ids, %{}, fn u, acc ->
            out_orig = Yog.successors(graph, u) |> Enum.into(%{})
            out_res = Yog.successors(res_graph, u) |> Enum.into(%{})

            sum_orig = out_orig |> Map.values() |> Enum.sum()
            sum_res = out_res |> Map.values() |> Enum.sum()

            Map.put(acc, u, sum_orig - sum_res)
          end)

        for u <- all_node_ids do
          cond do
            u == s ->
              assert net_flows[u] == result.max_flow

            u == t ->
              assert net_flows[u] == -result.max_flow

            true ->
              assert net_flows[u] == 0
          end
        end
      end
    end
  end
end
