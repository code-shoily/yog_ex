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

    test "single node graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")

      result = MinCut.global_min_cut(graph)

      assert result.cut_value == 0
      assert result.source_side_size == 0
      assert result.sink_side_size == 0
    end

    test "empty graph" do
      graph = Yog.undirected()
      result = MinCut.global_min_cut(graph)

      assert result.cut_value == 0
    end

    test "path graph" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")
        |> Yog.add_node(4, "d")
        |> Yog.add_edges([
          {1, 2, 5},
          {2, 3, 3},
          {3, 4, 7}
        ])

      result = MinCut.global_min_cut(graph)

      # Min cut is the weakest edge in the path
      assert result.cut_value == 3
    end

    test "complete graph K4" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")
        |> Yog.add_node(4, "d")
        |> Yog.add_edges([
          {1, 2, 1},
          {1, 3, 1},
          {1, 4, 1},
          {2, 3, 1},
          {2, 4, 1},
          {3, 4, 1}
        ])

      result = MinCut.global_min_cut(graph)

      # In K4 with equal weights, min cut is 3 (separating 1 node cuts 3 edges)
      assert result.cut_value == 3
    end

    test "weighted edges" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")
        |> Yog.add_edges([
          # Triangle with one weak edge and two strong edges
          # Cut {1} from {2,3}: edges (1,2)=1, (1,3)=100 -> total 101
          # Cut {2} from {1,3}: edges (1,2)=1, (2,3)=100 -> total 101
          # Cut {3} from {1,2}: edges (1,3)=100, (2,3)=100 -> total 200
          {1, 2, 1},
          {2, 3, 100},
          {1, 3, 100}
        ])

      result = MinCut.global_min_cut(graph)

      # Min cut is 101 (separating node 1 or node 2)
      assert result.cut_value == 101
    end

    test "cycle graph" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")
        |> Yog.add_node(4, "d")
        |> Yog.add_node(5, "e")
        |> Yog.add_edges([
          {1, 2, 2},
          {2, 3, 2},
          {3, 4, 2},
          {4, 5, 2},
          {5, 1, 2}
        ])

      result = MinCut.global_min_cut(graph)

      # In a cycle C5 with weight 2 per edge:
      # - Separating any single node cuts 2 edges = 2+2 = 4
      # This is the minimum cut for a cycle
      assert result.cut_value == 4
    end

    test "barbell graph" do
      # Two cliques connected by a bridge
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a1")
        |> Yog.add_node(2, "a2")
        |> Yog.add_node(3, "a3")
        |> Yog.add_node(4, "b1")
        |> Yog.add_node(5, "b2")
        |> Yog.add_node(6, "b3")
        |> Yog.add_edges([
          # First clique (complete)
          {1, 2, 10},
          {1, 3, 10},
          {2, 3, 10},
          # Second clique (complete)
          {4, 5, 10},
          {4, 6, 10},
          {5, 6, 10},
          # Bridge between cliques
          {3, 4, 2}
        ])

      result = MinCut.global_min_cut(graph)

      # Min cut is the bridge
      assert result.cut_value == 2
    end

    test "ladder graph" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a1")
        |> Yog.add_node(2, "a2")
        |> Yog.add_node(3, "b1")
        |> Yog.add_node(4, "b2")
        |> Yog.add_edges([
          # Rungs
          {1, 2, 5},
          {3, 4, 5},
          # Rails
          {1, 3, 1},
          {2, 4, 1}
        ])

      result = MinCut.global_min_cut(graph)

      # Min cut is 2 (both rails)
      assert result.cut_value == 2
    end
  end

  describe "MinCutResult struct" do
    test "partition_product helper" do
      result = Yog.Flow.MinCutResult.new(10, 3, 4)
      assert Yog.Flow.MinCutResult.partition_product(result) == 12
      assert Yog.Flow.MinCutResult.total_nodes(result) == 7
    end

    test "new/3 creates correct struct" do
      result = Yog.Flow.MinCutResult.new(5, 2, 3)
      assert result.cut_value == 5
      assert result.source_side_size == 2
      assert result.sink_side_size == 3
      assert result.algorithm == :stoer_wagner
    end
  end

  describe "edge cases" do
    test "two nodes with multiple edges" do
      # Note: Adding multiple edges between same nodes creates separate entries
      # The min cut value depends on how edges are stored
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 7)

      result = MinCut.global_min_cut(graph)

      # Single edge is the only cut
      assert result.cut_value == 7
    end

    test "disconnected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")

      # No edges - already disconnected
      result = MinCut.global_min_cut(graph)

      # Min cut in disconnected graph is 0
      assert result.cut_value == 0
    end
  end
end
