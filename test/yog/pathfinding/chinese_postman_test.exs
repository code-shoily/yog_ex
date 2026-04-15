defmodule Yog.Pathfinding.ChinesePostmanTest do
  use ExUnit.Case

  alias Yog.Pathfinding.ChinesePostman

  doctest Yog.Pathfinding.ChinesePostman

  # ============= Validation Helpers =============

  defp valid_closed_walk?(graph, walk) do
    # Must be a closed walk
    # Every step must correspond to an existing edge
    hd(walk) == List.last(walk) and
      Enum.all?(Enum.chunk_every(walk, 2, 1, :discard), fn [u, v] ->
        v in Yog.Model.neighbor_ids(graph, u)
      end)
  end

  defp all_edges_covered?(graph, walk) do
    edges_in_walk =
      walk
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [u, v] -> if u <= v, do: {u, v}, else: {v, u} end)
      |> Enum.frequencies()

    graph
    |> Yog.Model.all_edges()
    |> Enum.all?(fn {u, v, _} ->
      key = if u <= v, do: {u, v}, else: {v, u}
      Map.get(edges_in_walk, key, 0) >= 1
    end)
  end

  defp total_walk_weight(graph, walk) do
    walk
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0, fn [u, v], acc ->
      w =
        graph.out_edges
        |> Map.get(u, %{})
        |> Map.get(v, 0)

      acc + w
    end)
  end

  # ============= Basic Tests =============

  test "empty graph returns error" do
    assert {:error, :no_solution} = ChinesePostman.chinese_postman(Yog.undirected())
  end

  test "directed graph returns error" do
    graph =
      Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 3, 1, nil)

    assert {:error, :no_solution} = ChinesePostman.chinese_postman(graph)
  end

  test "disconnected graph returns error" do
    graph =
      Yog.from_edges(:undirected, [{1, 2, 1}])
      |> Yog.add_edge_ensure(3, 4, 1, nil)

    assert {:error, :no_solution} = ChinesePostman.chinese_postman(graph)
  end

  # ============= Eulerian Graphs =============

  test "square is already Eulerian" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    assert weight == 4
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
    # 4 edges + return to start
    assert length(walk) == 5
  end

  test "triangle is already Eulerian" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    assert weight == 3
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
  end

  # ============= Graphs with Odd Vertices =============

  test "path graph P4 has 2 odd vertices" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    # Must duplicate the entire shortest path 1-2-3-4 (weight 3)
    assert weight == 6
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
  end

  test "square with one diagonal has 4 odd vertices" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {2, 3, 1},
        {3, 4, 1},
        {4, 1, 1},
        {1, 3, 2}
      ])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    # Original weight = 6, optimal duplication = 2 (pair 1-3 via diagonal, 2-4 via 2-3-4 or 2-1-4)
    assert weight == 8
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
  end

  test "K4 complete graph" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {2, 3, 1},
        {2, 4, 1},
        {3, 4, 1}
      ])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    # All 4 vertices have degree 3 (odd). Need to duplicate 2 edges (perfect matching).
    # Minimum matching weight = 1 + 1 = 2. Total = 6 + 2 = 8.
    assert weight == 8
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
  end

  test "star graph S4" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1},
        {1, 5, 1}
      ])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    # 4 leaves are odd. Pair them optimally: (2,3) via 2-1-3 = 2, (4,5) via 4-1-5 = 2.
    # Total duplication = 4. Original = 4. Total = 8.
    assert weight == 8
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
  end

  test "walk weight matches computed total" do
    graph =
      Yog.from_edges(:undirected, [
        {1, 2, 2},
        {2, 3, 3},
        {3, 4, 4},
        {4, 1, 5},
        {1, 3, 1}
      ])

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    assert weight == total_walk_weight(graph, walk)
  end

  test "works via Pathfinding facade" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])

    assert {:ok, walk, weight} = Yog.Pathfinding.chinese_postman(graph)
    assert weight == 3
    assert valid_closed_walk?(graph, walk)
  end

  test "graph with isolated vertices is valid" do
    graph =
      Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      |> Yog.add_node(99, "isolated")

    assert {:ok, walk, weight} = ChinesePostman.chinese_postman(graph)
    assert weight == 3
    assert valid_closed_walk?(graph, walk)
    assert all_edges_covered?(graph, walk)
  end
end
