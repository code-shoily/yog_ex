defmodule Yog.IO.MatrixTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.IO.Matrix

  doctest Yog.IO.Matrix

  describe "from_matrix/2" do
    test "raises on invalid graph type" do
      assert_raise ArgumentError, fn ->
        apply(Matrix, :from_matrix, [:invalid, [[0, 1], [1, 0]]])
      end
    end

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

      assert Yog.Model.has_edge?(graph, 0, 1)
      assert Yog.Model.has_edge?(graph, 0, 2)
      assert Yog.Model.has_edge?(graph, 1, 3)
      assert Yog.Model.has_edge?(graph, 2, 3)

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

      assert Yog.has_edge?(graph, 0, 1)
      assert Yog.has_edge?(graph, 0, 2)
      assert Yog.has_edge?(graph, 1, 3)
      assert Yog.has_edge?(graph, 2, 3)

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

    test "raises on non-list matrix" do
      assert_raise ArgumentError, fn ->
        apply(Matrix, :from_matrix, [:undirected, nil])
      end
    end

    test "raises on non-list row in matrix" do
      assert_raise ArgumentError, fn ->
        Matrix.from_matrix(:undirected, [nil, [1, 0]])
      end
    end

    test "raises on non-numeric entry" do
      assert_raise ArgumentError, fn ->
        Matrix.from_matrix(:undirected, [[0, :a], [:b, 0]])
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
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)

      {nodes, matrix} = Matrix.to_matrix(graph)
      assert nodes == [1, 2, 3]
      assert matrix == [[0, 5, 0], [5, 0, 7], [0, 7, 0]]
    end

    test "exports directed graph to asymmetric matrix" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      {nodes, matrix} = Matrix.to_matrix(graph)
      assert nodes == [1, 2]
      assert matrix == [[0, 10], [0, 0]]
    end

    test "exports DAG to matrix" do
      dag =
        Yog.DAG.new()
        |> Yog.DAG.add_node(0, nil)
        |> Yog.DAG.add_node(1, nil)

      {:ok, dag} = Yog.DAG.add_edge(dag, 0, 1, 5)

      {nodes, matrix} = Matrix.to_matrix(dag)
      assert nodes == [0, 1]
      assert matrix == [[0, 5], [0, 0]]
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
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)

      {_nodes, matrix} = Matrix.to_matrix(original)
      restored = Matrix.from_matrix(:undirected, matrix)

      assert Yog.Model.order(restored) == Yog.Model.order(original)
      assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(original)
    end

    test "raises ArgumentError when input is not a graph or DAG struct" do
      assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
        apply(Matrix, :to_matrix, [:not_a_graph])
      end
    end
  end

  describe "to_string/2" do
    test "exports matrix to string" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)

      str = Matrix.to_string(graph)
      assert str == "0 5 0\n5 0 7\n0 7 0"
    end

    test "custom delimiter" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      str = Matrix.to_string(graph, delimiter: ",")
      assert str == "0,5\n5,0"
    end

    test "custom weight formatter for complex types" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_with(1, 2, [weight: 10], & &1)

      str =
        Matrix.to_string(graph,
          weight_formatter: fn
            0 -> "0"
            [weight: w] -> "w#{w}"
          end
        )

      assert str == "0 w10\nw10 0"
    end

    test "input validation for to_string/2" do
      assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
        apply(Matrix, :to_string, [:not_a_graph])
      end

      assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
        apply(Matrix, :to_string, [Yog.undirected(), :invalid_opts])
      end

      assert_raise ArgumentError, ~r/expected weight_formatter to be an arity-1 function/, fn ->
        Matrix.to_string(Yog.undirected(), weight_formatter: :invalid)
      end

      assert_raise ArgumentError, ~r/expected delimiter to be a binary string/, fn ->
        Matrix.to_string(Yog.undirected(), delimiter: 123)
      end
    end
  end

  describe "integration with House of Graphs format" do
    test "imports Petersen graph from matrix" do
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
      assert Yog.Model.edge_count(graph) == 15

      for v <- 0..9 do
        assert length(Yog.neighbors(graph, v)) == 3
      end
    end
  end

  describe "property tests" do
    property "roundtrip matrix conversion preserves structure for simple integer-indexed graphs" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              n <- StreamData.integer(0..15),
              raw_edges <-
                StreamData.list_of(
                  StreamData.tuple(
                    {StreamData.integer(0..max(n - 1, 0)), StreamData.integer(0..max(n - 1, 0))}
                  )
                )
            ) do
        graph =
          if n == 0 do
            Yog.Model.new(kind)
          else
            base = Enum.reduce(0..(n - 1), Yog.Model.new(kind), &Yog.add_node(&2, &1, nil))

            Enum.reduce(raw_edges, base, fn {u, v}, acc ->
              if u != v and u < n and v < n do
                Yog.add_edge_ensure(acc, u, v, 1)
              else
                acc
              end
            end)
          end

        {_nodes, matrix} = Matrix.to_matrix(graph)
        restored = Matrix.from_matrix(kind, matrix)

        assert Yog.Model.node_count(restored) == Yog.Model.node_count(graph)
        assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(graph)
      end
    end
  end
end
