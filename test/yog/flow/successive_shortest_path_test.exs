defmodule Yog.Flow.SuccessiveShortestPathTest do
  @moduledoc """
  Tests for `Yog.Flow.SuccessiveShortestPath` minimum cost flow algorithm.
  """

  use ExUnit.Case, async: true
  alias Yog.Flow.SuccessiveShortestPath
  doctest SuccessiveShortestPath

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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
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
               SuccessiveShortestPath.min_cost_flow(
                 graph,
                 get_demand,
                 get_capacity,
                 get_cost
               )
    end
  end
end
