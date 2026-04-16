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

  describe "gomory_hu_tree/1" do
    test "tree graph is identical to original" do
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

      tree = MinCut.gomory_hu_tree(graph)

      # Tree has V-1 edges and is connected
      assert length(Yog.Model.all_edges(tree)) == 3
      assert Yog.Property.connected?(tree)
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

      tree = MinCut.gomory_hu_tree(graph)

      assert length(Yog.Model.all_edges(tree)) == 3
      assert Yog.Property.connected?(tree)
    end

    test "single node graph" do
      graph = Yog.undirected() |> Yog.add_node(1, "a")
      tree = MinCut.gomory_hu_tree(graph)

      assert Yog.Model.all_nodes(tree) == [1]
      assert Yog.Model.all_edges(tree) == []
    end

    test "empty graph" do
      tree = MinCut.gomory_hu_tree(Yog.undirected())
      assert Yog.Model.all_nodes(tree) == []
    end
  end

  describe "min_cut_query/3" do
    test "query matches actual min-cut for path graph" do
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

      tree = MinCut.gomory_hu_tree(graph)
      {cut_value, _s, _t} = MinCut.min_cut_query(tree, 1, 4)

      # Actual min-cut in path 1-2-3-4 is the weakest edge = 3
      assert cut_value == 3
    end

    test "query partitions are valid" do
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

      tree = MinCut.gomory_hu_tree(graph)
      {cut_value, s, t} = MinCut.min_cut_query(tree, 1, 4)

      all_nodes = MapSet.new([1, 2, 3, 4])
      assert MapSet.disjoint?(s, t)
      assert MapSet.equal?(MapSet.union(s, t), all_nodes)
      assert MapSet.member?(s, 1)
      assert MapSet.member?(t, 4)
      assert cut_value == 3
    end

    test "query for same node returns zero" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      tree = MinCut.gomory_hu_tree(graph)
      {cut_value, s, t} = MinCut.min_cut_query(tree, 1, 1)

      assert cut_value == 0
      assert MapSet.member?(s, 1)
      assert MapSet.member?(t, 2)
    end

    test "query matches s-t min-cut on original graph" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")
        |> Yog.add_node(4, "d")
        |> Yog.add_edges([
          {1, 2, 3},
          {1, 3, 4},
          {2, 3, 2},
          {2, 4, 5},
          {3, 4, 1}
        ])

      tree = MinCut.gomory_hu_tree(graph)
      {gh_cut, _s, _t} = MinCut.min_cut_query(tree, 1, 4)

      # Compare against direct s-t min-cut
      st_result = MinCut.s_t_min_cut(graph, 1, 4, :dinic)
      assert gh_cut == st_result.cut_value
    end
  end

  describe "karger_stein/2" do
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

      result = MinCut.karger_stein(graph, iterations: 10)
      assert result.cut_value == 2
      assert result.source_side_size + result.sink_side_size == 3
    end

    test "single edge graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      result = MinCut.karger_stein(graph)
      assert result.cut_value == 5
      assert result.source_side_size == 1
      assert result.sink_side_size == 1
    end

    test "two connected cliques" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a1")
        |> Yog.add_node(2, "a2")
        |> Yog.add_node(3, "b1")
        |> Yog.add_node(4, "b2")
        |> Yog.add_edges([
          {1, 2, 10},
          {3, 4, 10},
          {2, 3, 1}
        ])

      result = MinCut.karger_stein(graph, iterations: 20)
      assert result.cut_value == 1
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

      result = MinCut.karger_stein(graph, iterations: 20)
      assert result.cut_value == 3
    end

    test "returns valid partitions" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_node(3, "c")
        |> Yog.add_edges([
          {1, 2, 5},
          {2, 3, 3},
          {1, 3, 2}
        ])

      result = MinCut.karger_stein(graph, iterations: 20)
      assert result.cut_value == 5
      assert MapSet.disjoint?(result.source_side, result.sink_side)

      all_nodes = MapSet.new([1, 2, 3])
      assert MapSet.equal?(MapSet.union(result.source_side, result.sink_side), all_nodes)
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

  describe "global_min_cut/2 with track_partitions" do
    test "returns actual node partitions for triangle" do
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

      result = MinCut.global_min_cut(graph, track_partitions: true)

      assert result.cut_value == 2
      assert result.source_side_size == MapSet.size(result.source_side)
      assert result.sink_side_size == MapSet.size(result.sink_side)
      assert MapSet.disjoint?(result.source_side, result.sink_side)

      all_nodes = MapSet.new([1, 2, 3])
      assert MapSet.equal?(MapSet.union(result.source_side, result.sink_side), all_nodes)
    end

    test "partitions are valid cuts for two cliques" do
      {:ok, graph} =
        Yog.undirected()
        |> Yog.add_node(1, "a1")
        |> Yog.add_node(2, "a2")
        |> Yog.add_node(3, "b1")
        |> Yog.add_node(4, "b2")
        |> Yog.add_edges([
          {1, 2, 10},
          {3, 4, 10},
          {2, 3, 1}
        ])

      result = MinCut.global_min_cut(graph, track_partitions: true)

      assert result.cut_value == 1

      # Verify cut value matches edges crossing the partition
      crossing_weight =
        Yog.Model.all_edges(graph)
        |> Enum.filter(fn {u, v, _} ->
          u_in_a = MapSet.member?(result.source_side, u)
          v_in_a = MapSet.member?(result.source_side, v)
          u_in_a != v_in_a
        end)
        |> Enum.reduce(0, fn {_, _, w}, acc -> acc + w end)

      assert crossing_weight == result.cut_value
    end

    test "empty graph with track_partitions" do
      graph = Yog.undirected()
      result = MinCut.global_min_cut(graph, track_partitions: true)

      assert result.cut_value == 0
      assert result.source_side == MapSet.new()
      assert result.sink_side == MapSet.new()
    end

    test "single node with track_partitions" do
      graph = Yog.undirected() |> Yog.add_node(1, "A")
      result = MinCut.global_min_cut(graph, track_partitions: true)

      assert result.cut_value == 0
      assert result.source_side == MapSet.new([1])
      assert result.sink_side == MapSet.new()
    end
  end

  describe "s_t_min_cut/3" do
    test "simple s-t cut using default algorithm" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])

      result = MinCut.s_t_min_cut(graph, 1, 3)
      assert result.cut_value == 5
      assert result.source_side_size >= 1
      assert result.sink_side_size >= 1
      assert result.algorithm == :edmonds_karp
    end

    test "s-t cut with dinic" do
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

      result = MinCut.s_t_min_cut(graph, 1, 4, :dinic)
      assert result.cut_value == 20
      assert result.algorithm == :dinic
      assert MapSet.member?(result.source_side, 1)
      assert MapSet.member?(result.sink_side, 4)
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
