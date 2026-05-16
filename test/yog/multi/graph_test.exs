defmodule Yog.Multi.GraphTest do
  use ExUnit.Case

  doctest Yog.Multi.Graph

  test "convenience constructors" do
    assert Yog.Multi.Graph.directed().kind == :directed
    assert Yog.Multi.Graph.undirected().kind == :undirected
  end

  test "edge_count/1 returns total edges" do
    multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(2, "B")
    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 10)
    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 20)
    assert Yog.Multi.Graph.edge_count(multi) == 2
  end

  describe "Enumerable protocol" do
    test "count returns node count" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(2, "B")
      assert Enum.count(multi) == 2
    end

    test "member? checks for node presence" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      assert Enum.member?(multi, {1, "A"})
      refute Enum.member?(multi, {1, "B"})
      refute Enum.member?(multi, {2, "A"})
    end

    test "reduce iterates over nodes" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(2, "B")
      nodes = Enum.to_list(multi)
      assert length(nodes) == 2
      assert {1, "A"} in nodes
      assert {2, "B"} in nodes
    end

    test "slice returns node segments" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")
        |> Yog.Multi.add_node(3, "C")

      slice = Enum.slice(multi, 0, 2)
      assert length(slice) == 2
    end
  end

  describe "Inspect protocol" do
    test "renders compact representation" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 10)

      inspected = inspect(multi)
      assert inspected =~ "#Yog.Multi.Graph<:directed, 2 nodes, 1 edge>"
    end

    test "handles singular node/edge count" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 1, 10)

      inspected = inspect(multi)
      assert inspected =~ "1 node, 1 edge"
    end
  end
end
