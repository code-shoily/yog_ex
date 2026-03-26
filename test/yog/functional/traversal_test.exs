defmodule Yog.Functional.TraversalTest do
  use ExUnit.Case, async: true
  alias Yog.Functional.Model
  alias Yog.Functional.Traversal
  doctest Yog.Functional.Traversal

  setup do
    g =
      Model.empty()
      |> Model.put_node(1, "A")
      |> Model.put_node(2, "B")
      |> Model.put_node(3, "C")
      |> Model.put_node(4, "D")
      |> Model.put_node(5, "E")
      |> Model.add_edge!(1, 2)
      |> Model.add_edge!(2, 3)
      |> Model.add_edge!(1, 4)
      |> Model.add_edge!(4, 3)
      |> Model.add_edge!(3, 5)

    {:ok, graph: g}
  end

  describe "dfs" do
    test "traverses graph depth-first", %{graph: graph} do
      visited = Traversal.dfs(graph, 1)
      ids = Enum.map(visited, & &1.id)

      assert hd(ids) == 1
      assert 5 in ids
      assert length(ids) == 5
      assert MapSet.new(ids) == MapSet.new([1, 2, 3, 4, 5])
    end

    test "handles cycles properly", %{graph: graph} do
      g = Model.add_edge!(graph, 5, 1)

      visited = Traversal.dfs(g, 1)
      ids = Enum.map(visited, & &1.id)

      # Should not infinite loop and should visit 5 unique nodes
      assert length(ids) == 5
      assert MapSet.new(ids) == MapSet.new([1, 2, 3, 4, 5])
    end
  end

  describe "bfs" do
    test "traverses graph breadth-first", %{graph: graph} do
      visited = Traversal.bfs(graph, 1)
      ids = Enum.map(visited, & &1.id)

      assert hd(ids) == 1
      # 2 and 4 should be visited before 3 and 5
      ix_1 = Enum.find_index(ids, &(&1 == 1))
      ix_2 = Enum.find_index(ids, &(&1 == 2))
      ix_3 = Enum.find_index(ids, &(&1 == 3))
      ix_4 = Enum.find_index(ids, &(&1 == 4))
      ix_5 = Enum.find_index(ids, &(&1 == 5))

      assert ix_1 < ix_2
      assert ix_1 < ix_4
      assert ix_2 < ix_3
      assert ix_4 < ix_3
      assert ix_3 < ix_5
    end

    test "handles cycles properly", %{graph: graph} do
      g = Model.add_edge!(graph, 5, 1)

      visited = Traversal.bfs(g, 1)
      ids = Enum.map(visited, & &1.id)

      assert length(ids) == 5
      assert MapSet.new(ids) == MapSet.new([1, 2, 3, 4, 5])
    end
  end

  describe "preorder, postorder, and reachable" do
    test "preorder returns nodes in visit order", %{graph: graph} do
      ids = Traversal.preorder(graph, 1)
      assert hd(ids) == 1
      assert length(ids) == 5
    end

    test "postorder returns nodes in finishing order", %{graph: graph} do
      ids = Traversal.postorder(graph, 1)
      # Last node visited should be first to finish in a linear part
      assert List.last(ids) == 1
      assert length(ids) == 5
    end

    test "reachable returns all reachable node IDs", %{graph: graph} do
      ids = Traversal.reachable(graph, 1)
      assert MapSet.new(ids) == MapSet.new([1, 2, 3, 4, 5])

      # From 5, nothing is reachable
      assert Traversal.reachable(graph, 5) == [5]
    end
  end
end
