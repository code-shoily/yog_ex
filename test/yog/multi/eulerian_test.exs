defmodule Yog.Multi.EulerianTest do
  @moduledoc """
  Tests for Yog.Multi.Eulerian module.

  Eulerian paths and circuits in multigraphs use edge IDs to handle
  parallel edges correctly. Hierholzer's algorithm is adapted for this purpose.
  """

  use ExUnit.Case

  doctest Yog.Multi.Eulerian

  alias Yog.Multi.Eulerian
  alias Yog.Multi.Model

  # ============================================================
  # Empty Graph Tests
  # ============================================================

  describe "empty graph" do
    test "has_eulerian_circuit?/1 returns false for empty graph" do
      graph = Model.directed()
      refute Eulerian.has_eulerian_circuit?(graph)
    end

    test "has_eulerian_path?/1 returns false for empty graph" do
      graph = Model.directed()
      refute Eulerian.has_eulerian_path?(graph)
    end

    test "find_eulerian_circuit/1 returns :error for empty graph" do
      graph = Model.directed()
      assert Eulerian.find_eulerian_circuit(graph) == :error
    end

    test "find_eulerian_path/1 returns :error for empty graph" do
      graph = Model.directed()
      assert Eulerian.find_eulerian_path(graph) == :error
    end
  end

  # ============================================================
  # Directed Graph Tests - Eulerian Circuit
  # ============================================================

  describe "directed eulerian circuit" do
    test "single edge has no eulerian circuit" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> add_edge!(:a, :b, 1)

      refute Eulerian.has_eulerian_circuit?(graph)
      assert Eulerian.find_eulerian_circuit(graph) == :error
    end

    test "cycle has eulerian circuit" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)
        |> add_edge!(:c, :a, 3)

      assert Eulerian.has_eulerian_circuit?(graph)

      case Eulerian.find_eulerian_circuit(graph) do
        {:ok, edge_ids} ->
          assert length(edge_ids) == 3

        :error ->
          flunk("Expected to find an Eulerian circuit")
      end
    end

    test "balanced but disconnected has no eulerian circuit" do
      # Two separate cycles
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :a, 2)
        |> add_edge!(:c, :d, 3)
        |> add_edge!(:d, :c, 4)

      refute Eulerian.has_eulerian_circuit?(graph)
    end

    test "unbalanced degrees have no eulerian circuit" do
      # a: out=2, in=0 (unbalanced)
      # b: out=0, in=1
      # c: out=0, in=1
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:a, :c, 2)

      refute Eulerian.has_eulerian_circuit?(graph)
    end
  end

  # ============================================================
  # Directed Graph Tests - Eulerian Path
  # ============================================================

  describe "directed eulerian path" do
    test "single edge has eulerian path" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> add_edge!(:a, :b, 1)

      assert Eulerian.has_eulerian_path?(graph)

      case Eulerian.find_eulerian_path(graph) do
        {:ok, edge_ids} -> assert length(edge_ids) == 1
        :error -> flunk("Expected to find an Eulerian path")
      end
    end

    test "one start one end has eulerian path" do
      # a: out=1, in=0 (start)
      # b: out=1, in=1
      # c: out=0, in=1 (end)
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)

      assert Eulerian.has_eulerian_path?(graph)

      case Eulerian.find_eulerian_path(graph) do
        {:ok, edge_ids} ->
          assert length(edge_ids) == 2

        :error ->
          flunk("Expected to find an Eulerian path")
      end
    end

    test "too many unbalanced nodes have no eulerian path" do
      # a: out=2, in=0
      # b: out=0, in=1
      # c: out=0, in=1
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:a, :c, 2)

      # This has 1 start node and 2 end nodes - invalid
      refute Eulerian.has_eulerian_path?(graph)
    end

    test "circuit is also a path" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)
        |> add_edge!(:c, :a, 3)

      # A circuit is also a valid path
      assert Eulerian.has_eulerian_path?(graph)
    end
  end

  # ============================================================
  # Undirected Graph Tests - Eulerian Circuit
  # ============================================================

  describe "undirected eulerian circuit" do
    test "triangle has eulerian circuit" do
      graph =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)
        |> add_edge!(:c, :a, 3)

      assert Eulerian.has_eulerian_circuit?(graph)

      case Eulerian.find_eulerian_circuit(graph) do
        {:ok, edge_ids} ->
          assert length(edge_ids) == 3

        :error ->
          flunk("Expected to find an Eulerian circuit")
      end
    end

    test "odd degree nodes have no eulerian circuit" do
      # Path of 2 edges: a-b-c
      # a: degree 1 (odd)
      # b: degree 2 (even)
      # c: degree 1 (odd)
      graph =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)

      refute Eulerian.has_eulerian_circuit?(graph)
    end

    test "square with diagonals has eulerian circuit" do
      # Square a-b-c-d-a with all even degrees
      graph =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)
        |> add_edge!(:c, :d, 3)
        |> add_edge!(:d, :a, 4)

      assert Eulerian.has_eulerian_circuit?(graph)
    end
  end

  # ============================================================
  # Undirected Graph Tests - Eulerian Path
  # ============================================================

  describe "undirected eulerian path" do
    test "path graph has eulerian path" do
      # a-b-c (2 odd degree nodes at ends)
      graph =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)

      assert Eulerian.has_eulerian_path?(graph)

      case Eulerian.find_eulerian_path(graph) do
        {:ok, edge_ids} ->
          assert length(edge_ids) == 2

        :error ->
          flunk("Expected to find an Eulerian path")
      end
    end

    test "four odd degrees have no eulerian path" do
      # Star with 4 leaves: center connected to a, b, c, d
      # All leaves have degree 1 (odd)
      # Center has degree 4 (even)
      graph =
        Model.undirected()
        |> Model.add_node(:center, "Center")
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> add_edge!(:center, :a, 1)
        |> add_edge!(:center, :b, 2)
        |> add_edge!(:center, :c, 3)
        |> add_edge!(:center, :d, 4)

      # 4 odd degree nodes - no eulerian path
      refute Eulerian.has_eulerian_path?(graph)
    end

    test "circuit is also a path (undirected)" do
      graph =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)
        |> add_edge!(:c, :a, 3)

      assert Eulerian.has_eulerian_path?(graph)
    end
  end

  # ============================================================
  # Multigraph Specific Tests (Parallel Edges)
  # ============================================================

  describe "multigraph parallel edges" do
    test "parallel edges affect degree correctly" do
      # Two parallel edges between a and b
      # a: degree 2, b: degree 2 (both even)
      graph =
        Model.undirected()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:a, :b, 2)

      assert Eulerian.has_eulerian_circuit?(graph)

      case Eulerian.find_eulerian_circuit(graph) do
        {:ok, edge_ids} ->
          assert length(edge_ids) == 2

        :error ->
          flunk("Expected to find an Eulerian circuit")
      end
    end

    test "directed parallel edges affect balance" do
      # Two parallel edges from a to b
      # a: out=2, in=0
      # b: out=0, in=2
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:a, :b, 2)

      refute Eulerian.has_eulerian_circuit?(graph)
      refute Eulerian.has_eulerian_path?(graph)
    end

    test "balanced parallel edges in directed graph" do
      # a -> b (2 edges), b -> a (2 edges)
      # Both balanced with degree 2
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:a, :b, 2)
        |> add_edge!(:b, :a, 3)
        |> add_edge!(:b, :a, 4)

      assert Eulerian.has_eulerian_circuit?(graph)
    end
  end

  # ============================================================
  # Complex Graph Tests
  # ============================================================

  describe "complex graphs" do
    test "figure-eight graph has eulerian circuit" do
      # Two cycles sharing a common node
      # a-b-c-a and a-d-e-a
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> Model.add_node(:e, "E")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :c, 2)
        |> add_edge!(:c, :a, 3)
        |> add_edge!(:a, :d, 4)
        |> add_edge!(:d, :e, 5)
        |> add_edge!(:e, :a, 6)

      assert Eulerian.has_eulerian_circuit?(graph)

      case Eulerian.find_eulerian_circuit(graph) do
        {:ok, edge_ids} ->
          assert length(edge_ids) == 6

        :error ->
          flunk("Expected to find an Eulerian circuit")
      end
    end

    test "disconnected graph has no eulerian path or circuit" do
      graph =
        Model.directed()
        |> Model.add_node(:a, "A")
        |> Model.add_node(:b, "B")
        |> Model.add_node(:c, "C")
        |> Model.add_node(:d, "D")
        |> add_edge!(:a, :b, 1)
        |> add_edge!(:b, :a, 2)
        |> add_edge!(:c, :d, 3)
        |> add_edge!(:d, :c, 4)

      # Two separate balanced components
      refute Eulerian.has_eulerian_circuit?(graph)
      refute Eulerian.has_eulerian_path?(graph)
    end
  end

  # ============================================================
  # Helper Functions
  # ============================================================

  # Helper to add edge and return updated graph (ignoring edge_id)
  defp add_edge!(graph, from, to, weight) do
    {graph, _} = Model.add_edge(graph, from, to, weight)
    graph
  end
end
