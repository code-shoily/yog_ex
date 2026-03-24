defmodule Yog.IO.MatrixTest do
  use ExUnit.Case

  alias Yog.IO.Matrix

  doctest Yog.IO.Matrix

  describe "from_matrix/2" do
    test "creates undirected graph from unweighted matrix" do
      matrix = [
        [0, 1, 1, 0],
        [1, 0, 0, 1],
        [1, 0, 0, 1],
        [0, 1, 1, 0]
      ]

      graph = Matrix.from_matrix(:undirected, matrix)
      assert Yog.Model.order(graph) == 4
      assert Yog.Model.edge_count(graph) == 4

      # Check specific edges exist
      assert Yog.Model.has_edge?(graph, 0, 1)
      assert Yog.Model.has_edge?(graph, 0, 2)
      assert Yog.Model.has_edge?(graph, 1, 3)
      assert Yog.Model.has_edge?(graph, 2, 3)

      # Undirected - check reverse edges
      assert Yog.Model.has_edge?(graph, 1, 0)
      assert Yog.Model.has_edge?(graph, 2, 0)
    end

    test "creates directed graph from weighted matrix" do
      matrix = [
        [0, 5, 3, 0],
        [0, 0, 0, 2],
        [0, 0, 0, 7],
        [0, 0, 0, 0]
      ]

      graph = Matrix.from_matrix(:directed, matrix)
      assert Yog.Model.order(graph) == 4
      assert Yog.Model.edge_count(graph) == 4

      # Check specific edges exist
      assert Yog.has_edge?(graph, 0, 1)
      assert Yog.has_edge?(graph, 0, 2)
      assert Yog.has_edge?(graph, 1, 3)
      assert Yog.has_edge?(graph, 2, 3)

      # Check no reverse edges (directed)
      refute Yog.has_edge?(graph, 1, 0)
    end

    test "empty matrix creates empty graph" do
      graph = Matrix.from_matrix(:undirected, [])
      assert Yog.Model.order(graph) == 0
    end

    test "single node matrix" do
      graph = Matrix.from_matrix(:undirected, [[0]])
      assert Yog.Model.order(graph) == 1
      assert Yog.Model.edge_count(graph) == 0
    end

    test "complete graph from matrix" do
      matrix = [
        [0, 1, 1],
        [1, 0, 1],
        [1, 1, 0]
      ]

      graph = Matrix.from_matrix(:undirected, matrix)
      assert Yog.Model.order(graph) == 3
      # K3 has 3 edges
      assert Yog.Model.edge_count(graph) == 3
    end

    test "raises on non-square matrix" do
      assert_raise ArgumentError, fn ->
        Matrix.from_matrix(:undirected, [
          [0, 1, 1],
          [1, 0]
        ])
      end
    end
  end

  describe "to_matrix/1" do
    test "exports undirected graph to symmetric matrix" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge!(from: 1, to: 2, with: 5)
        |> Yog.add_edge!(from: 2, to: 3, with: 7)

      {nodes, matrix} = Matrix.to_matrix(graph)
      assert nodes == [1, 2, 3]
      assert matrix == [[0, 5, 0], [5, 0, 7], [0, 7, 0]]
    end

    test "exports directed graph to asymmetric matrix" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge!(from: 1, to: 2, with: 10)

      {nodes, matrix} = Matrix.to_matrix(graph)
      assert nodes == [1, 2]
      # Directed: [1,2] = 10, [2,1] = 0
      assert matrix == [[0, 10], [0, 0]]
    end

    test "empty graph returns empty matrix" do
      graph = Yog.undirected()
      {nodes, matrix} = Matrix.to_matrix(graph)
      assert nodes == []
      assert matrix == []
    end

    test "round-trip conversion preserves structure" do
      original =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge!(from: 1, to: 2, with: 5)
        |> Yog.add_edge!(from: 2, to: 3, with: 7)

      {_nodes, matrix} = Matrix.to_matrix(original)
      restored = Matrix.from_matrix(:undirected, matrix)

      assert Yog.Model.order(restored) == Yog.Model.order(original)
      assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(original)
    end
  end

  describe "integration with House of Graphs format" do
    test "imports Petersen graph from matrix" do
      # Petersen graph adjacency matrix (10 nodes)
      matrix = [
        [0, 1, 0, 0, 1, 1, 0, 0, 0, 0],
        [1, 0, 1, 0, 0, 0, 1, 0, 0, 0],
        [0, 1, 0, 1, 0, 0, 0, 1, 0, 0],
        [0, 0, 1, 0, 1, 0, 0, 0, 1, 0],
        [1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 1, 0, 0, 1],
        [0, 1, 0, 0, 0, 1, 0, 1, 0, 0],
        [0, 0, 1, 0, 0, 0, 1, 0, 1, 0],
        [0, 0, 0, 1, 0, 0, 0, 1, 0, 1],
        [0, 0, 0, 0, 1, 1, 0, 0, 1, 0]
      ]

      graph = Matrix.from_matrix(:undirected, matrix)
      assert Yog.Model.order(graph) == 10
      # Petersen graph has 15 edges
      assert Yog.Model.edge_count(graph) == 15

      # All nodes have degree 3 (cubic graph)
      for v <- 0..9 do
        assert length(Yog.neighbors(graph, v)) == 3
      end
    end
  end
end
