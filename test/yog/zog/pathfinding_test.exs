defmodule Yog.Zog.PathfindingTest do
  use ExUnit.Case, async: true

  alias Yog.Builder.Zog
  alias Yog.Zog.Pathfinding

  @moduletag :zigler

  describe "floyd_warshall/1" do
    test "triangle graph" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      {:ok, matrix} = Pathfinding.floyd_warshall(builder)

      # A -> B = 1, A -> C = 2 (via B)
      assert hd(matrix) == [0.0, 1.0, 2.0]
      # B -> C = 1, B -> A = 2 (via C)
      assert Enum.at(matrix, 1) == [2.0, 0.0, 1.0]
      # C -> A = 1, C -> B = 2 (via A)
      assert Enum.at(matrix, 2) == [1.0, 2.0, 0.0]
    end

    test "chain graph" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 2.0)

      {:ok, matrix} = Pathfinding.floyd_warshall(builder)

      # A -> B = 1, A -> C = 3
      assert hd(matrix) == [0.0, 1.0, 3.0]
      # B -> C = 2, B -> A = unreachable (Inf)
      assert Enum.at(matrix, 1) == [:infinity, 0.0, 2.0]
      # C -> nothing
      assert Enum.at(matrix, 2) == [:infinity, :infinity, 0.0]
    end

    test "detects negative cycle" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", -2.0)
        |> Zog.add_edge("C", "A", -1.0)

      assert Pathfinding.floyd_warshall(builder) == {:error, :negative_cycle}
    end

    test "empty graph" do
      builder = Zog.directed()
      {:ok, matrix} = Pathfinding.floyd_warshall(builder)
      assert matrix == []
    end

    test "single node" do
      builder = Zog.directed() |> Zog.add_node("A")
      {:ok, matrix} = Pathfinding.floyd_warshall(builder)
      assert matrix == [[0.0]]
    end
  end

  describe "johnsons/1" do
    test "triangle graph" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      {:ok, matrix} = Pathfinding.johnsons(builder)

      assert hd(matrix) == [0.0, 1.0, 2.0]
      assert Enum.at(matrix, 1) == [2.0, 0.0, 1.0]
      assert Enum.at(matrix, 2) == [1.0, 2.0, 0.0]
    end

    test "detects negative cycle" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", -2.0)
        |> Zog.add_edge("C", "A", -1.0)

      assert Pathfinding.johnsons(builder) == {:error, :negative_cycle}
    end
  end
end
