defmodule Yog.Flow.NetworkSimplexTest do
  @moduledoc """
  Tests for `Yog.Flow.NetworkSimplex` minimum cost flow algorithm.
  """

  use ExUnit.Case, async: true
  alias Yog.Flow.NetworkSimplex
  alias Yog.Flow.SuccessiveShortestPath

  describe "min_cost_flow/4" do
    test "simple supply chain" do
      graph =
        Yog.directed()
        # warehouse: supply 10
        |> Yog.add_node(1, {-10, nil})
        # store_a: demand 5
        |> Yog.add_node(2, {5, nil})
        # store_b: demand 5
        |> Yog.add_node(3, {5, nil})
        # capacity 10, cost 3
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {10, 3})
        # capacity 10, cost 2
        |> Yog.add_edge_ensure(from: 1, to: 3, with: {10, 2})
        # capacity 5, cost 1
        |> Yog.add_edge_ensure(from: 2, to: 3, with: {5, 1})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, result} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )

      # Total cost: 5*3 + 5*2 = 25 (cheaper than using 2->3 edge)
      assert result.cost == 25
      assert length(result.flow) > 0
    end

    test "single edge flow" do
      graph =
        Yog.directed()
        # supply
        |> Yog.add_node(1, {-5, nil})
        # demand
        |> Yog.add_node(2, {5, nil})
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {10, 2})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, result} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )

      # 5 units * cost 2
      assert result.cost == 10
    end

    test "unbalanced demands error" do
      graph =
        Yog.directed()
        # supply 5
        |> Yog.add_node(1, {-5, nil})
        # demand 3 (unbalanced!)
        |> Yog.add_node(2, {3, nil})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:error, :unbalanced_demands} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end

    test "infeasible due to capacity constraints" do
      graph =
        Yog.directed()
        # supply 10
        |> Yog.add_node(1, {-10, nil})
        # demand 10
        |> Yog.add_node(2, {10, nil})
        # capacity only 5
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {5, 1})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:error, :infeasible} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end

    test "chooses cheaper path" do
      graph =
        Yog.directed()
        # supply
        |> Yog.add_node(1, {-10, nil})
        # demand
        |> Yog.add_node(2, {10, nil})
        # intermediate
        |> Yog.add_node(3, {0, nil})
        # Two paths: direct (expensive) vs via node 3 (cheaper)
        # expensive direct
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {10, 10})
        # cheap first leg
        |> Yog.add_edge_ensure(from: 1, to: 3, with: {10, 1})
        # cheap second leg
        |> Yog.add_edge_ensure(from: 3, to: 2, with: {10, 1})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, result} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )

      # Should use the cheaper path via node 3: 10 * (1+1) = 20
      assert result.cost == 20
    end

    test "zero cost edges" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, {-5, nil})
        |> Yog.add_node(2, {5, nil})
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {10, 0})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, result} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )

      assert result.cost == 0
    end

    test "multiple supply and demand nodes" do
      graph =
        Yog.directed()
        # supply 5
        |> Yog.add_node(1, {-5, nil})
        # supply 5
        |> Yog.add_node(2, {-5, nil})
        # demand 3
        |> Yog.add_node(3, {3, nil})
        # demand 3
        |> Yog.add_node(4, {3, nil})
        # demand 4
        |> Yog.add_node(5, {4, nil})
        |> Yog.add_edge_ensure(from: 1, to: 3, with: {5, 1})
        |> Yog.add_edge_ensure(from: 1, to: 4, with: {5, 2})
        |> Yog.add_edge_ensure(from: 2, to: 4, with: {5, 1})
        |> Yog.add_edge_ensure(from: 2, to: 5, with: {5, 1})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, result} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )

      # Total demand = 10, should be satisfied
      assert result.cost > 0
    end
  end

  describe "edge cases" do
    test "empty graph" do
      graph = Yog.directed()

      get_demand = fn _ -> 0 end
      get_capacity = fn _ -> 10 end
      get_cost = fn _ -> 1 end

      # No demands means trivially satisfied
      assert {:ok, %{cost: 0, flow: []}} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end

    test "single node with zero demand" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, {0, nil})

      get_demand = fn {d, _} -> d end
      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, %{cost: 0, flow: []}} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end

    test "disconnected supply and demand" do
      graph =
        Yog.directed()
        # supply
        |> Yog.add_node(1, {-5, nil})
        # demand
        |> Yog.add_node(2, {5, nil})
        # disconnected
        |> Yog.add_node(3, nil)

      # No edges connecting 1 to 2

      get_demand = fn
        {d, _} -> d
        nil -> 0
      end

      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:error, :infeasible} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end

    test "negative cost cycle handles successfully if capacities are finite" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, {-5, nil})
        |> Yog.add_node(2, {5, nil})
        |> Yog.add_edges([
          {1, 2, {10, 10}},
          {2, 1, {10, -20}}
        ])

      get_demand = fn
        {d, _} -> d
        _ -> 0
      end

      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:ok, result} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )

      # Optimal flow satisfies demand and routes around negative cycle to minimize cost
      assert result.cost == 0
      assert Enum.sort(result.flow) == [{1, 2, 10}, {2, 1, 5}]
    end

    test "negative cost cycle with infinite capacity is unbounded" do
      # Using a very large number for capacity to represent infinity
      inf_capacity = 100_000_000_000

      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, {-5, nil})
        |> Yog.add_node(2, {5, nil})
        |> Yog.add_edges([
          {1, 2, {inf_capacity, 10}},
          {2, 1, {inf_capacity, -20}}
        ])

      get_demand = fn
        {d, _} -> d
        _ -> 0
      end

      get_capacity = fn {c, _} -> c end
      get_cost = fn {_, cost} -> cost end

      assert {:error, :unbounded} =
               NetworkSimplex.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end
  end

  describe "cross-validation against Successive Shortest Path" do
    test "random small graphs parity" do
      # Generate small random graphs and verify same costs
      for _ <- 1..20 do
        nodes = Enum.to_list(1..5)
        demands = [0, 0, 0, 0, 0]
        # Choose two supply nodes, two demand nodes
        demands = List.replace_at(demands, 0, -10)
        demands = List.replace_at(demands, 1, -5)
        demands = List.replace_at(demands, 3, 10)
        demands = List.replace_at(demands, 4, 5)

        graph =
          Enum.reduce(Enum.zip(nodes, demands), Yog.directed(), fn {node, d}, g ->
            Yog.add_node(g, node, {d, nil})
          end)

        # Add random edges
        edges = [
          {1, 2, {15, 3}},
          {1, 3, {10, 4}},
          {2, 3, {5, 1}},
          {2, 4, {10, 2}},
          {3, 4, {5, 5}},
          {3, 5, {10, 2}},
          {4, 5, {5, 1}},
          {1, 4, {8, 6}}
        ]

        graph =
          Enum.reduce(edges, graph, fn {u, v, {c, cost}}, g ->
            Yog.add_edge_ensure(g, from: u, to: v, with: {c, cost})
          end)

        get_demand = fn {d, _} -> d end
        get_capacity = fn {c, _} -> c end
        get_cost = fn {_, cost} -> cost end

        res_ssp = SuccessiveShortestPath.min_cost_flow(graph, get_demand, get_capacity, get_cost)
        res_ns = NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost)

        assert {:ok, ssp_val} = res_ssp
        assert {:ok, ns_val} = res_ns
        assert ssp_val.cost == ns_val.cost

        verify_flow_constraints(graph, ns_val.flow, get_demand, get_capacity)
      end
    end
  end

  defp verify_flow_constraints(graph, flow_list, get_demand, get_capacity) do
    net_flows =
      Enum.reduce(flow_list, %{}, fn {u, v, flow_val}, acc ->
        # Find the edge data
        successors = Yog.Model.successors(graph, u)
        edge_data = Enum.find_value(successors, fn {target, data} -> if target == v, do: data end)
        assert edge_data != nil
        capacity = get_capacity.(edge_data)
        assert flow_val > 0
        assert flow_val <= capacity

        acc
        |> Map.update(u, -flow_val, &(&1 - flow_val))
        |> Map.update(v, flow_val, &(&1 + flow_val))
      end)

    nodes = Yog.Model.all_nodes(graph)

    Enum.each(nodes, fn node ->
      node_data = Yog.Model.node(graph, node)
      demand = get_demand.(node_data)
      net_flow = Map.get(net_flows, node, 0)
      assert net_flow == demand
    end)
  end
end
