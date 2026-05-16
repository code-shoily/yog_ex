defmodule Yog.Builder.LiveTest do
  use ExUnit.Case

  alias Yog.Builder.Labeled
  alias Yog.Builder.Live

  doctest Live

  test "live_builder_add_and_sync_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("B", "C", 5)

    assert Live.pending_count(builder) > 0
    assert Live.node_count(builder) == 3

    {builder, graph} = Live.sync(builder, Yog.directed())

    assert Live.pending_count(builder) == 0
    assert length(Yog.all_nodes(graph)) == 3
  end

  test "live_builder_directed_undirected_test" do
    directed = Live.directed()
    assert is_struct(directed, Live)

    undirected = Live.undirected()
    assert is_struct(undirected, Live)
  end

  test "live_builder_from_labeled_test" do
    labeled =
      Labeled.directed()
      |> Labeled.add_edge("X", "Y", 7)

    builder = Live.from_labeled(labeled)
    assert is_struct(builder, Live)
    assert {:ok, _} = Live.get_id(builder, "X")
  end

  test "live_builder_unweighted_edge_test" do
    builder =
      Live.new()
      |> Live.add_unweighted_edge("A", "B")

    assert Live.pending_count(builder) > 0
  end

  test "live_builder_simple_edge_test" do
    builder =
      Live.new()
      |> Live.add_simple_edge("A", "B")

    assert Live.pending_count(builder) > 0
  end

  test "live_builder_remove_edge_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.remove_edge("A", "B")

    assert Live.pending_count(builder) > 0
  end

  test "live_builder_remove_node_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.remove_node("A")

    assert is_struct(builder, Live)
  end

  test "live_builder_purge_pending_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("B", "C", 5)
      |> Live.purge_pending()

    assert Live.pending_count(builder) == 0
  end

  test "live_builder_checkpoint_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.checkpoint()

    assert Live.pending_count(builder) == 0
  end

  test "live_builder_get_id_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)

    assert {:ok, _id} = Live.get_id(builder, "A")
    assert {:error, nil} = Live.get_id(builder, "NonExistent")
  end

  test "live_builder_all_labels_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)

    labels = Live.all_labels(builder)
    assert Enum.sort(labels) == ["A", "B"]
  end

  test "live_builder_has_label_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)

    assert Live.has_label?(builder, "A")
    assert Live.has_label?(builder, "B")
    refute Live.has_label?(builder, "Z")
  end

  test "live_builder_incremental_sync_test" do
    # Build base graph
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)

    {builder, graph} = Live.sync(builder, Yog.directed())
    assert length(Yog.all_nodes(graph)) == 2

    # Add more edges incrementally
    builder = Live.add_edge(builder, "B", "C", 5)
    {_builder, graph} = Live.sync(builder, graph)
    assert length(Yog.all_nodes(graph)) == 3
  end

  test "live_builder_sync_multi_directed_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("B", "C", 5)

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())

    assert Yog.Multi.order(multi) == 3
    assert Yog.Multi.size(multi) == 2
  end

  test "live_builder_sync_multi_parallel_edges_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("A", "B", 20)
      |> Live.add_edge("A", "B", 30)

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())

    assert Yog.Multi.order(multi) == 2
    assert Yog.Multi.size(multi) == 3

    # Verify parallel edges are tracked independently
    edges = Yog.Multi.edges_between(multi, 0, 1)
    assert length(edges) == 3
    weights = Enum.map(edges, fn {_eid, data} -> data end) |> Enum.sort()
    assert weights == [10, 20, 30]
  end

  test "live_builder_sync_multi_undirected_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("B", "A", 20)

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.undirected())

    assert Yog.Multi.order(multi) == 2
    assert Yog.Multi.size(multi) == 2
  end

  test "live_builder_sync_multi_remove_edge_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("A", "B", 20)
      |> Live.remove_edge("A", "B")

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())

    assert Yog.Multi.order(multi) == 2
    assert Yog.Multi.size(multi) == 0
  end

  test "live_builder_sync_multi_remove_node_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)
      |> Live.add_edge("B", "C", 20)
      |> Live.remove_node("B")

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())

    # Nodes A and C remain; B and its edges are removed
    assert Yog.Multi.order(multi) == 2
    assert Yog.Multi.size(multi) == 0
  end

  test "live_builder_sync_multi_empty_pending_test" do
    builder = Live.new()
    multi = Yog.Multi.directed()

    {builder, multi} = Live.sync_multi(builder, multi)
    assert Yog.Multi.order(multi) == 0
    assert builder.pending == []
  end

  test "live_builder_sync_multi_incremental_sync_test" do
    builder =
      Live.new()
      |> Live.add_edge("A", "B", 10)

    {builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())
    assert Yog.Multi.order(multi) == 2
    assert Yog.Multi.size(multi) == 1

    builder = Live.add_edge(builder, "B", "C", 5)
    {_builder, multi} = Live.sync_multi(builder, multi)
    assert Yog.Multi.order(multi) == 3
    assert Yog.Multi.size(multi) == 2
  end

  test "live_builder_sync_multi_unweighted_edge_test" do
    builder =
      Live.new()
      |> Live.add_unweighted_edge("A", "B")

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())
    assert Yog.Multi.size(multi) == 1

    edge_data = Yog.Multi.edges_between(multi, 0, 1)
    assert [{_eid, nil}] = edge_data
  end

  test "live_builder_sync_multi_simple_edge_test" do
    builder =
      Live.new()
      |> Live.add_simple_edge("A", "B")

    {_builder, multi} = Live.sync_multi(builder, Yog.Multi.directed())
    assert Yog.Multi.size(multi) == 1

    edge_data = Yog.Multi.edges_between(multi, 0, 1)
    assert [{_eid, 1}] = edge_data
  end
end
