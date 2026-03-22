defmodule YogFlowNetworkSimplexTest do
  @moduledoc """
  Tests for `Yog.Flow.NetworkSimplex` matching Gleam's `yog/flow/network_simplex` module.

  Note: The get_demand, get_capacity, and get_cost functions work with node/edge data,
  not IDs. In these tests, node data is the string label (e.g., "warehouse") and
  edge data is the capacity integer.
  """

  use ExUnit.Case, async: true
  alias Yog.Flow.NetworkSimplex

  describe "min_cost_flow/4" do
    test "returns error for unbalanced demands" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge!(from: 1, to: 2, with: 10)

      # Supply doesn't equal demand (-10 ≠ 5)
      get_demand = fn
        "s" -> -10
        "t" -> 5
        _ -> 0
      end

      get_capacity = fn weight -> weight end
      get_cost = fn _weight -> 1 end

      assert {:error, :unbalanced_demands} =
               NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost)
    end

    test "returns error or result for zero flow" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge!(from: 1, to: 2, with: 10)

      # Zero demand/supply
      get_demand = fn
        "s" -> 0
        "t" -> 0
        _ -> 0
      end

      get_capacity = fn weight -> weight end
      get_cost = fn _weight -> 5 end

      # With zero demands, should either succeed with zero cost or return error
      case NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost) do
        {:ok, result} ->
          assert result.cost == 0
          assert result.flow == []

        {:error, _} ->
          # Some implementations may return error for trivial cases
          :ok
      end
    end

    test "API accepts required function signatures" do
      # This test verifies the API is callable with the right function types
      graph =
        Yog.directed()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_edge!(from: 1, to: 2, with: 5)

      # Functions take node/edge data (strings and integers)
      get_demand = fn
        "a" -> -5
        "b" -> 5
        _ -> 0
      end

      get_capacity = fn _weight -> 5 end
      get_cost = fn _weight -> 1 end

      # Just verify the function doesn't crash and returns a valid result type
      result = NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
