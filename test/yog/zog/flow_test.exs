defmodule Yog.Zog.FlowTest do
  use ExUnit.Case, async: true

  alias Yog.Flow.MaxFlow
  alias Yog.Zog.Flow
  alias Yog.Zog.ResourceGraph

  setup do
    # Build a classic CLRS-style max flow network.
    # Max flow from "s" to "t" is 23.
    builder =
      Yog.Builder.Zog.directed()
      |> Yog.Builder.Zog.add_edge("s", "v1", 16.0)
      |> Yog.Builder.Zog.add_edge("s", "v2", 13.0)
      |> Yog.Builder.Zog.add_edge("v1", "v2", 10.0)
      |> Yog.Builder.Zog.add_edge("v1", "v3", 12.0)
      |> Yog.Builder.Zog.add_edge("v2", "v1", 4.0)
      |> Yog.Builder.Zog.add_edge("v2", "v4", 14.0)
      |> Yog.Builder.Zog.add_edge("v3", "v2", 9.0)
      |> Yog.Builder.Zog.add_edge("v3", "t", 20.0)
      |> Yog.Builder.Zog.add_edge("v4", "v3", 7.0)
      |> Yog.Builder.Zog.add_edge("v4", "t", 4.0)

    # Pure Elixir graph for verification
    elixir_graph =
      Yog.directed()
      |> Yog.add_edge_ensure("s", "v1", 16)
      |> Yog.add_edge_ensure("s", "v2", 13)
      |> Yog.add_edge_ensure("v1", "v2", 10)
      |> Yog.add_edge_ensure("v1", "v3", 12)
      |> Yog.add_edge_ensure("v2", "v1", 4)
      |> Yog.add_edge_ensure("v2", "v4", 14)
      |> Yog.add_edge_ensure("v3", "v2", 9)
      |> Yog.add_edge_ensure("v3", "t", 20)
      |> Yog.add_edge_ensure("v4", "v3", 7)
      |> Yog.add_edge_ensure("v4", "t", 4)

    {:ok, builder: builder, elixir_graph: elixir_graph}
  end

  test "Edmonds-Karp NIF parity on classic CLRS flow network", %{
    builder: builder,
    elixir_graph: elixir_graph
  } do
    # Pure Elixir
    elixir_res = MaxFlow.edmonds_karp(elixir_graph, "s", "t")

    # Native Copy-In/Copy-Out
    zog_res = Flow.max_flow(builder, "s", "t")

    assert zog_res.max_flow == 23.0
    assert zog_res.max_flow == elixir_res.max_flow

    # Verify min-cut partitions
    assert "s" in zog_res.source_side
    assert "t" in zog_res.sink_side

    assert MapSet.new(zog_res.source_side ++ zog_res.sink_side) ==
             MapSet.new(["s", "v1", "v2", "v3", "v4", "t"])

    # Native ResourceGraph
    res_graph = ResourceGraph.new(builder)
    res_res = ResourceGraph.max_flow(res_graph, "s", "t")
    ResourceGraph.destroy(res_graph)

    assert res_res.max_flow == 23.0
    assert MapSet.new(res_res.source_side) == MapSet.new(zog_res.source_side)
    assert MapSet.new(res_res.sink_side) == MapSet.new(zog_res.sink_side)
  end

  test "Trivial max flow (single edge)", %{builder: _builder} do
    builder =
      Yog.Builder.Zog.directed()
      |> Yog.Builder.Zog.add_edge("A", "B", 5.0)

    zog_res = Flow.max_flow(builder, "A", "B")
    assert zog_res.max_flow == 5.0
    assert "A" in zog_res.source_side
    assert "B" in zog_res.sink_side
  end

  test "global_min_cut/1 Stoer-Wagner parity with pure Elixir" do
    # Two cliques connected by a bridge
    builder =
      Yog.Builder.Zog.undirected()
      |> Yog.Builder.Zog.add_edge("a1", "a2", 10.0)
      |> Yog.Builder.Zog.add_edge("a1", "a3", 10.0)
      |> Yog.Builder.Zog.add_edge("a2", "a3", 10.0)
      |> Yog.Builder.Zog.add_edge("b1", "b2", 10.0)
      |> Yog.Builder.Zog.add_edge("b1", "b3", 10.0)
      |> Yog.Builder.Zog.add_edge("b2", "b3", 10.0)
      |> Yog.Builder.Zog.add_edge("a3", "b1", 2.0)

    zog_res = Flow.global_min_cut(builder)

    assert zog_res.cut_value == 2.0

    assert MapSet.new(zog_res.source_side) == MapSet.new(["b1", "b2", "b3"]) or
             MapSet.new(zog_res.source_side) == MapSet.new(["a1", "a2", "a3"])

    assert MapSet.new(zog_res.sink_side) == MapSet.new(["b1", "b2", "b3"]) or
             MapSet.new(zog_res.sink_side) == MapSet.new(["a1", "a2", "a3"])

    # Native ResourceGraph
    res_graph = ResourceGraph.new(builder)
    res_res = ResourceGraph.global_min_cut(res_graph)
    ResourceGraph.destroy(res_graph)

    assert res_res.cut_value == 2.0
    assert MapSet.new(res_res.source_side) == MapSet.new(zog_res.source_side)
    assert MapSet.new(res_res.sink_side) == MapSet.new(zog_res.sink_side)
  end

  test "Push-Relabel NIF parity on classic CLRS flow network", %{
    builder: builder,
    elixir_graph: elixir_graph
  } do
    # Pure Elixir
    elixir_res = MaxFlow.edmonds_karp(elixir_graph, "s", "t")

    # Native Copy-In/Copy-Out
    zog_res = Flow.max_flow(builder, "s", "t", :push_relabel)

    assert zog_res.max_flow == 23.0
    assert zog_res.max_flow == elixir_res.max_flow

    # Verify min-cut partitions
    assert "s" in zog_res.source_side
    assert "t" in zog_res.sink_side

    assert MapSet.new(zog_res.source_side ++ zog_res.sink_side) ==
             MapSet.new(["s", "v1", "v2", "v3", "v4", "t"])

    # Native ResourceGraph
    res_graph = ResourceGraph.new(builder)
    res_res = ResourceGraph.max_flow(res_graph, "s", "t", :push_relabel)
    ResourceGraph.destroy(res_graph)

    assert res_res.max_flow == 23.0
    assert MapSet.new(res_res.source_side) == MapSet.new(zog_res.source_side)
    assert MapSet.new(res_res.sink_side) == MapSet.new(zog_res.sink_side)
  end

  test "Push-Relabel trivial max flow (single edge)" do
    builder =
      Yog.Builder.Zog.directed()
      |> Yog.Builder.Zog.add_edge("A", "B", 5.0)

    zog_res = Flow.max_flow(builder, "A", "B", :push_relabel)
    assert zog_res.max_flow == 5.0
    assert "A" in zog_res.source_side
    assert "B" in zog_res.sink_side
  end
end
