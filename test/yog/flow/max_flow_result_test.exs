defmodule Yog.Flow.MaxFlowResultTest do
  use ExUnit.Case, async: true
  alias Yog.Flow.MaxFlowResult
  doctest MaxFlowResult

  describe "constructors" do
    test "new/4" do
      graph = Yog.directed()
      result = MaxFlowResult.new(10, graph, 1, 2)
      assert result.max_flow == 10
      assert result.residual_graph == graph
      assert result.source == 1
      assert result.sink == 2
      assert result.algorithm == :unknown
    end

    test "new/5" do
      graph = Yog.directed()
      result = MaxFlowResult.new(15, graph, 1, 2, :dinic)
      assert result.max_flow == 15
      assert result.algorithm == :dinic
    end

    test "new/7" do
      graph = Yog.directed()
      compare = &Yog.Utils.compare/2
      result = MaxFlowResult.new(20, graph, 1, 2, :push_relabel, 0, compare)
      assert result.max_flow == 20
      assert result.zero == 0
      assert result.compare == compare
    end
  end

  describe "residual_capacity/3" do
    test "returns capacity for existing edge" do
      graph = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      result = MaxFlowResult.new(10, graph, 1, 3)
      assert MaxFlowResult.residual_capacity(result, 1, 2) == 10
    end

    test "returns 0 for non-existing edge" do
      graph = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      result = MaxFlowResult.new(10, graph, 1, 3)
      assert MaxFlowResult.residual_capacity(result, 1, 4) == 0
    end

    test "returns 0 when no successors" do
      graph = Yog.directed() |> Yog.add_node(1, nil)
      result = MaxFlowResult.new(0, graph, 1, 2)
      assert MaxFlowResult.residual_capacity(result, 1, 2) == 0
    end
  end

  describe "map conversions" do
    test "to_map/1" do
      graph = Yog.directed()
      result = MaxFlowResult.new(10, graph, 1, 2)
      map = MaxFlowResult.to_map(result)

      assert map == %{
               max_flow: 10,
               residual_graph: graph,
               source: 1,
               sink: 2
             }
    end

    test "from_map/1" do
      graph = Yog.directed()

      map = %{
        max_flow: 10,
        residual_graph: graph,
        source: 1,
        sink: 2,
        algorithm: :dinic,
        metadata: %{time: 123}
      }

      result = MaxFlowResult.from_map(map)
      assert result.max_flow == 10
      assert result.algorithm == :dinic
      assert result.metadata == %{time: 123}
    end

    test "from_map/1 with defaults" do
      graph = Yog.directed()

      map = %{
        max_flow: 10,
        residual_graph: graph,
        source: 1,
        sink: 2
      }

      result = MaxFlowResult.from_map(map)
      assert result.algorithm == :unknown
      assert result.zero == 0
    end
  end
end
