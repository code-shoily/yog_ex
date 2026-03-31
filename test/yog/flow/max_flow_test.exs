defmodule Yog.Flow.MaxFlowTest do
  @moduledoc """
  Tests for `Yog.Flow.MaxFlow` matching Gleam's `yog/flow/max_flow` module.
  """

  use ExUnit.Case, async: true
  alias Yog.Flow.MaxFlow
  doctest MaxFlow

  describe "edmonds_karp/3" do
    test "simple flow network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 4)

      assert result.max_flow == 15
      assert result.source == 1
      assert result.sink == 4
      assert result.residual_graph != nil
    end

    test "single edge path" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      result = MaxFlow.edmonds_karp(graph, 1, 2)

      assert result.max_flow == 5
      assert result.source == 1
      assert result.sink == 2
    end

    test "multiple parallel paths" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 4)

      # Two parallel paths each with capacity 10
      assert result.max_flow == 20
    end

    test "bottleneck limits flow" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "mid")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 100},
          {2, 3, 5}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 3)

      # Bottleneck is the edge with capacity 5
      assert result.max_flow == 5
    end

    test "disconnected source and sink" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      # No edge to sink

      result = MaxFlow.edmonds_karp(graph, 1, 3)

      assert result.max_flow == 0
    end
  end

  describe "extract_min_cut/1" do
    test "extracts min cut from max flow result" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 4, 10},
          {3, 4, 10}
        ])

      max_flow_result = MaxFlow.edmonds_karp(graph, 1, 4)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      # Cut value should equal max flow
      assert min_cut.cut_value == 15

      # Both sides should have at least one node
      assert min_cut.source_side_size >= 1
      assert min_cut.sink_side_size >= 1

      # Total nodes should be 4
      assert Yog.Flow.MinCutResult.total_nodes(min_cut) == 4
    end

    test "min cut equals max flow" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 7)

      max_flow_result = MaxFlow.edmonds_karp(graph, 1, 2)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      # Cut value should equal max flow
      assert min_cut.cut_value == 7

      # For a single edge, one node on each side
      assert min_cut.source_side_size == 1
      assert min_cut.sink_side_size == 1
    end
  end
end
