defmodule YogMultiTraversalTest do
  @moduledoc """
  Tests for Yog.Multi.Traversal module.

  Multi-graph traversals use edge IDs to correctly handle parallel edges —
  each edge is traversed at most once, but a node may be reached via multiple edges.
  """

  use ExUnit.Case

  doctest Yog.Multi.Traversal

  alias Yog.Multi.Model
  alias Yog.Multi.Traversal

  # ============================================================
  # BFS Tests
  # ============================================================

  describe "bfs/2" do
    test "bfs on single node" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")

      assert Traversal.bfs(graph, :a) == [:a]
    end

    test "bfs traverses all reachable nodes" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :c, 2)
      {graph, _} = Model.add_edge(graph, :b, :d, 3)

      result = Traversal.bfs(graph, :a)
      assert length(result) == 4
      assert :a in result
      assert :b in result
      assert :c in result
      assert :d in result
    end

    test "bfs with parallel edges" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :b, 2)

      # Node b should appear only once despite multiple edges
      result = Traversal.bfs(graph, :a)
      assert :a in result
      assert :b in result
      assert length(result) == 2
    end

    test "bfs does not revisit nodes" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :b, :c, 2)
      {graph, _} = Model.add_edge(graph, :c, :a, 3)

      result = Traversal.bfs(graph, :a)
      assert length(result) == 3
      assert :a in result
      assert :b in result
      assert :c in result
    end

    test "bfs from disconnected start only visits reachable" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      result = Traversal.bfs(graph, :a)
      assert length(result) == 2
      assert :a in result
      assert :b in result
      refute :c in result
    end
  end

  # ============================================================
  # DFS Tests
  # ============================================================

  describe "dfs/2" do
    test "dfs on single node" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")

      assert Traversal.dfs(graph, :a) == [:a]
    end

    test "dfs returns pre-order traversal" do
      #     a
      #    / \
      #   b   c
      #  /
      # d

      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :c, 2)
      {graph, _} = Model.add_edge(graph, :b, :d, 3)

      result = Traversal.dfs(graph, :a)
      # Pre-order: a is first
      assert hd(result) == :a
      assert length(result) == 4
      assert :a in result
      assert :b in result
      assert :c in result
      assert :d in result
    end

    test "dfs with parallel edges visits node once" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :b, 2)

      result = Traversal.dfs(graph, :a)
      assert length(result) == 2
      assert :a in result
      assert :b in result
    end

    test "dfs handles cycles" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :b, :c, 2)
      {graph, _} = Model.add_edge(graph, :c, :a, 3)

      result = Traversal.dfs(graph, :a)
      assert length(result) == 3
      assert :a in result
      assert :b in result
      assert :c in result
    end
  end

  # ============================================================
  # fold_walk Tests
  # ============================================================

  describe "fold_walk/4" do
    test "fold_walk accumulates with :continue" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :c, 2)

      result =
        Traversal.fold_walk(graph, :a, [], fn acc, node, _meta ->
          {:continue, [node | acc]}
        end)

      assert length(result) == 3
      assert :a in result
      assert :b in result
      assert :c in result
    end

    test "fold_walk stops with :halt" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :b, :c, 2)

      result =
        Traversal.fold_walk(graph, :a, [], fn acc, node, _meta ->
          if node == :b do
            {:halt, acc}
          else
            {:continue, [node | acc]}
          end
        end)

      # Should have stopped when reaching :b
      refute :c in result
    end

    test "fold_walk skips successors with :stop" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :c, 2)
      {graph, _} = Model.add_edge(graph, :c, :d, 3)

      result =
        Traversal.fold_walk(graph, :a, [], fn acc, node, _meta ->
          if node == :c do
            # :stop means don't explore successors, but :c itself is added to result
            {:stop, [node | acc]}
          else
            {:continue, [node | acc]}
          end
        end)

      # Should visit :a, :b, :c but not :d (because :stop was used at :c)
      assert :a in result
      assert :b in result
      assert :c in result
      refute :d in result
    end

    test "fold_walk provides depth metadata" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :b, :c, 2)

      depths =
        Traversal.fold_walk(graph, :a, %{}, fn acc, node, meta ->
          {:continue, Map.put(acc, node, meta.depth)}
        end)

      assert depths[:a] == 0
      assert depths[:b] == 1
      assert depths[:c] == 2
    end

    test "fold_walk provides parent metadata" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, e2} = Model.add_edge(graph, :b, :c, 2)

      parents =
        Traversal.fold_walk(graph, :a, %{}, fn acc, node, meta ->
          new_acc =
            case meta.parent do
              nil -> acc
              {parent, edge_id} -> Map.put(acc, node, {parent, edge_id})
            end

          {:continue, new_acc}
        end)

      assert parents[:b] == {:a, e1}
      assert parents[:c] == {:b, e2}
    end

    test "fold_walk root has nil parent" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")

      result =
        Traversal.fold_walk(graph, :a, [], fn acc, node, meta ->
          new_acc =
            if meta.parent == nil do
              [{node, :root} | acc]
            else
              acc
            end

          {:continue, new_acc}
        end)

      assert {:a, :root} in result
    end

    test "fold_walk traverses all parallel edges to reach node" do
      {graph, e1} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_edge(:a, :b, 1)

      {graph, e2} = Model.add_edge(graph, :a, :b, 2)

      edges_used =
        Traversal.fold_walk(graph, :a, [], fn acc, _node, meta ->
          new_acc =
            case meta.parent do
              nil -> acc
              {_, edge_id} -> [edge_id | acc]
            end

          {:continue, new_acc}
        end)

      # fold_walk uses edge-based tracking, so both parallel edges are traversed
      # (both edges lead to :b, and each edge is tracked separately)
      assert length(edges_used) == 2
      assert e1 in edges_used
      assert e2 in edges_used
    end
  end

  # ============================================================
  # Undirected Graph Traversal Tests
  # ============================================================

  describe "undirected graph traversals" do
    test "bfs on undirected graph" do
      {graph, _} =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :b, :c, 2)

      result = Traversal.bfs(graph, :a)
      assert length(result) == 3
      assert :a in result
      assert :b in result
      assert :c in result
    end

    test "bfs can traverse in reverse direction for undirected" do
      {graph, _} =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_edge(:b, :a, 1)

      {graph, _} = Model.add_edge(graph, :c, :b, 2)

      # Starting from a, should reach c via b
      result = Traversal.bfs(graph, :a)
      assert :c in result
    end
  end

  # ============================================================
  # Complex Graph Traversal Tests
  # ============================================================

  describe "complex graph traversals" do
    test "diamond-shaped graph" do
      #     a
      #    / \
      #   b   c
      #    \ /
      #     d

      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :a, :c, 2)
      {graph, _} = Model.add_edge(graph, :b, :d, 3)
      {graph, _} = Model.add_edge(graph, :c, :d, 4)

      bfs_result = Traversal.bfs(graph, :a)
      assert length(bfs_result) == 4

      dfs_result = Traversal.dfs(graph, :a)
      assert length(dfs_result) == 4
    end

    test "graph with multiple disconnected components" do
      {graph, _} =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> Model.add_edge(:a, :b, 1)

      {graph, _} = Model.add_edge(graph, :c, :d, 2)

      # From a, only reach a and b
      result = Traversal.bfs(graph, :a)
      assert length(result) == 2
      assert :a in result
      assert :b in result
      refute :c in result
      refute :d in result
    end
  end
end
