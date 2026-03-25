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
end
