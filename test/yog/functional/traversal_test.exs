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

    test "handles empty graph" do
      assert Traversal.dfs(Model.empty(), 1) == []
      assert Traversal.dfs(Model.empty(), [1, 2]) == []
    end

    test "handles single-node graph" do
      graph = Model.empty() |> Model.put_node(1, "A")
      ids = Traversal.dfs(graph, 1) |> Enum.map(& &1.id)

      assert ids == [1]
    end

    test "handles self-loops without revisiting" do
      graph = Model.empty() |> Model.put_node(1, "A") |> Model.add_edge!(1, 1, :loop)
      ids = Traversal.dfs(graph, 1) |> Enum.map(& &1.id)

      assert ids == [1]
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

    test "handles empty graph" do
      assert Traversal.bfs(Model.empty(), 1) == []
      assert Traversal.bfs(Model.empty(), [1, 2]) == []
    end

    test "handles duplicate start nodes and skips already visited nodes" do
      graph =
        Model.empty() |> Model.put_node(1, "A") |> Model.put_node(2, "B") |> Model.add_edge!(1, 2)

      ids = Traversal.bfs(graph, [1, 2, 1]) |> Enum.map(& &1.id)

      assert length(ids) == 2
      assert MapSet.new(ids) == MapSet.new([1, 2])
    end

    test "from non-existent node returns empty list" do
      graph = Model.empty() |> Model.put_node(1, "A")
      assert Traversal.bfs(graph, 99) == []
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

    test "return empty lists for missing starts" do
      graph = Model.empty() |> Model.put_node(1, "A")

      assert Traversal.preorder(graph, 99) == []
      assert Traversal.postorder(graph, 99) == []
      assert Traversal.reachable(graph, 99) == []
    end

    test "return empty lists for empty graph" do
      graph = Model.empty()

      assert Traversal.preorder(graph, 1) == []
      assert Traversal.postorder(graph, 1) == []
      assert Traversal.reachable(graph, 1) == []
    end
  end

  describe "dfs edge cases" do
    test "dfs with duplicate start nodes skips already visited" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      # Start with both 1 and 2 in the stack
      visited = Traversal.dfs(g, [1, 2])
      ids = Enum.map(visited, & &1.id)
      assert length(ids) == 2
      assert MapSet.new(ids) == MapSet.new([1, 2])
    end

    test "dfs from non-existent node" do
      g = Model.empty() |> Model.put_node(1, "A")
      visited = Traversal.dfs(g, 99)
      assert visited == []
    end
  end

  describe "multi-start and graph direction behavior" do
    test "multiple disconnected start nodes traverse separate components" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(3, 4)

      dfs_ids = Traversal.dfs(graph, [1, 3]) |> Enum.map(& &1.id)
      bfs_ids = Traversal.bfs(graph, [1, 3]) |> Enum.map(& &1.id)

      assert MapSet.new(dfs_ids) == MapSet.new([1, 2, 3, 4])
      assert MapSet.new(bfs_ids) == MapSet.new([1, 2, 3, 4])
    end

    test "directed traversal follows outgoing edges only" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      assert Traversal.reachable(graph, 1) |> MapSet.new() == MapSet.new([1, 2])
      assert Traversal.reachable(graph, 2) == [2]
    end

    test "undirected traversal follows symmetric adjacency" do
      graph =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)

      assert Traversal.reachable(graph, 1) |> MapSet.new() == MapSet.new([1, 2])
      assert Traversal.reachable(graph, 2) |> MapSet.new() == MapSet.new([1, 2])
    end
  end
end
