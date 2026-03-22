defmodule Yog.Builder.LabeledTest do
  use ExUnit.Case
  doctest Yog.Builder.Labeled
  alias Yog.Builder.Labeled

  describe "labeled graphs" do
    test "creates a labeled graph with string labels" do
      builder =
        Labeled.directed()
        |> Labeled.add_edge("home", "work", 10)
        |> Labeled.add_edge("work", "gym", 5)

      assert Labeled.all_labels(builder) |> length() == 3
      assert {:ok, _id} = Labeled.get_id(builder, "home")
    end

    test "converts to graph" do
      builder =
        Labeled.directed()
        |> Labeled.add_edge("A", "B", 5)

      graph = Labeled.to_graph(builder)
      assert Yog.graph?(graph)
    end

    test "queries by label" do
      builder =
        Labeled.directed()
        |> Labeled.add_edge("A", "B", 10)
        |> Labeled.add_edge("A", "C", 5)

      assert {:ok, successors} = Labeled.successors(builder, "A")
      assert length(successors) == 2
    end

    test "returns error for non-existent labels" do
      builder = Labeled.directed()

      assert {:error, nil} = Labeled.get_id(builder, "NonExistent")
      assert {:error, nil} = Labeled.successors(builder, "NonExistent")
    end

    test "works with atom labels" do
      builder =
        Labeled.directed()
        |> Labeled.add_edge(:start, :middle, 1)
        |> Labeled.add_edge(:middle, :end, 2)

      assert {:ok, _id} = Labeled.get_id(builder, :start)
      assert {:ok, successors} = Labeled.successors(builder, :start)
      assert successors == [{:middle, 1}]
    end

    test "ensure_node creates or returns existing node" do
      builder = Labeled.directed()

      {builder, id1} = Labeled.ensure_node(builder, "A")
      {_builder, id2} = Labeled.ensure_node(builder, "A")

      # Same label returns same ID
      assert id1 == id2
    end
  end
end
