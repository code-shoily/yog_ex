defmodule Yog.IO.MatrixMarketTest do
  use ExUnit.Case

  alias Yog.IO.MatrixMarket
  doctest MatrixMarket

  @tmp_file "/tmp/test_yog_matrix_market.mtx"

  describe "serialization" do
    test "serialize directed" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5.5)

      result = MatrixMarket.serialize(graph)

      assert String.contains?(result, "%%MatrixMarket matrix coordinate real general")
      assert String.contains?(result, "2 2 1")
      assert String.contains?(result, "1 2 5.5")
    end

    test "serialize undirected" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      result = MatrixMarket.serialize(graph)

      assert String.contains?(result, "%%MatrixMarket matrix coordinate real symmetric")
      assert String.contains?(result, "2 2 1")
      assert String.contains?(result, "1 2 10")
    end

    test "serialize with options" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {1, 2})

      options = MatrixMarket.options_with(fn {a, b} -> "#{a}/#{b}" end)
      result = MatrixMarket.serialize_with(options, graph)

      assert String.contains?(result, "1 2 1/2")
    end
  end

  describe "parsing" do
    test "parse simple directed" do
      input = """
      %%MatrixMarket matrix coordinate real general
      3 3 2
      1 2 1.5
      2 3 2.5
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)

      assert Yog.Model.node_count(graph) == 3
      assert Yog.Model.edge_count(graph) == 2
      assert Yog.Model.type(graph) == :directed
      # Successors of 1
      assert Yog.successor_ids(graph, 1) == [2]
    end

    test "parse symmetric (undirected)" do
      input = """
      %%MatrixMarket matrix coordinate real symmetric
      2 2 1
      1 2 5.0
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)

      assert Yog.Model.type(graph) == :undirected
      assert Yog.Model.edge_count(graph) == 1
    end

    test "parse with comments and empty lines" do
      input = """
      %%MatrixMarket matrix coordinate real general
      % Comment here
      3 3 1

      % Another comment
      1 2 1.0
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)
      assert Yog.Model.node_count(graph) == 3
      assert Yog.Model.edge_count(graph) == 1
    end

    test "parse_with custom parsers" do
      input = "%%MatrixMarket matrix coordinate real general\n1 1 1\n1 1 5.0"

      {:ok, {:matrix_market_result, graph, _warnings}} =
        MatrixMarket.parse_with(input, :directed, fn id -> "Node#{id}" end, fn w -> w * 2 end)

      assert Yog.Model.node(graph, 1) == "Node1"
      # self loop weight 10.0
      {_, _, weight} = hd(Yog.Model.all_edges(graph))
      assert weight == 10.0
    end

    test "parse pattern field" do
      input = """
      %%MatrixMarket matrix coordinate pattern general
      3 3 2
      1 2
      2 3
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)
      assert Yog.Model.edge_count(graph) == 2
      # weight should be 1.0 by default for pattern
      {_, _, weight} = hd(Yog.Model.all_edges(graph))
      assert weight == 1.0
    end

    test "parse integer field" do
      input = """
      %%MatrixMarket matrix coordinate integer general
      3 3 1
      1 2 42.0
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)
      {_, _, weight} = hd(Yog.Model.all_edges(graph))
      assert weight == 42
    end

    test "parse complex field" do
      input = """
      %%MatrixMarket matrix coordinate complex general
      1 1 1
      1 1 1.5 2.5
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)
      {_, _, weight} = hd(Yog.Model.all_edges(graph))
      assert weight == {1.5, 2.5}
    end

    test "empty input error" do
      assert MatrixMarket.parse("") == {:error, :empty_input}
    end

    test "missing header error" do
      assert MatrixMarket.parse("1 1 1") == {:error, {:missing_header, "1 1 1"}}
    end
  end

  describe "file I/O" do
    test "read sample fixture" do
      fixture_path = "test/fixtures/io/sample.mtx"
      assert File.exists?(fixture_path)

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.read(fixture_path)

      assert Yog.Model.node_count(graph) == 3
      assert Yog.Model.edge_count(graph) == 3
      # edges are 1->2, 2->3, 3->1
      assert Yog.has_edge?(graph, 1, 2)
      assert Yog.has_edge?(graph, 2, 3)
      assert Yog.has_edge?(graph, 3, 1)
    end

    test "roundtrip write and read" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5.5)

      assert :ok = MatrixMarket.write(@tmp_file, graph)
      assert File.exists?(@tmp_file)

      {:ok, {:matrix_market_result, reloaded, _warnings}} = MatrixMarket.read(@tmp_file)
      assert Yog.Model.node_count(reloaded) == 2
      assert Yog.Model.edge_count(reloaded) == 1
      assert Yog.has_edge?(reloaded, 1, 2)

      File.rm(@tmp_file)
    end
  end
end
