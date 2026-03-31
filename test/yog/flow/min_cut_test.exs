defmodule Yog.Flow.MinCutTest do
  @moduledoc """
  Tests for `Yog.Flow.MinCut` matching Gleam's `yog/flow/min_cut` module.
  """

  use ExUnit.Case, async: true
  alias Yog.Flow.MinCut
  doctest MinCut

  describe "global_min_cut/1" do
    test "simple triangle graph" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([
          {1, 2, 1},
          {2, 3, 1},
          {1, 3, 1}
        ])

      result = MinCut.global_min_cut(graph)

      # In a triangle with equal weights, min cut is 2 (cutting any two edges)
      assert result.cut_value == 2
      assert result.source_side_size + result.sink_side_size == 3
    end

    test "square with diagonal" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_node(4, "D")
        |> Yog.add_edges([
          {1, 2, 3},
          {2, 3, 1},
          {3, 4, 3},
          {4, 1, 1},
          {1, 3, 2}
        ])

      result = MinCut.global_min_cut(graph)

      # The minimum cut should cut the weakest edges
      assert result.cut_value == 4
      assert result.source_side_size >= 1
      assert result.sink_side_size >= 1
    end

    test "two connected cliques" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a1")
        |> Yog.add_node(2, "a2")
        |> Yog.add_node(3, "b1")
        |> Yog.add_node(4, "b2")
        |> Yog.add_edges([
          # Clique A (nodes 1, 2)
          {1, 2, 10},
          # Clique B (nodes 3, 4)
          {3, 4, 10},
          # Single connection between cliques
          {2, 3, 1}
        ])

      result = MinCut.global_min_cut(graph)

      # Min cut should be the single edge connecting the cliques
      assert result.cut_value == 1
    end

    test "single edge graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      result = MinCut.global_min_cut(graph)

      # Single edge is the only cut
      assert result.cut_value == 5
      assert result.source_side_size == 1
      assert result.sink_side_size == 1
    end

    test "star graph" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "center")
        |> Yog.add_node(2, "leaf1")
        |> Yog.add_node(3, "leaf2")
        |> Yog.add_node(4, "leaf3")
        |> Yog.add_edges([
          {1, 2, 3},
          {1, 3, 3},
          {1, 4, 3}
        ])

      result = MinCut.global_min_cut(graph)

      # Min cut is separating one leaf (weight 3)
      assert result.cut_value == 3
    end

    test "partition_product helper" do
      result = Yog.Flow.MinCutResult.new(10, 3, 4)
      assert Yog.Flow.MinCutResult.partition_product(result) == 12
      assert Yog.Flow.MinCutResult.total_nodes(result) == 7
    end
  end
end
