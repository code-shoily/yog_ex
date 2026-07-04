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

    test "serialize with formatters" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: {1.5, :real})

      options =
        MatrixMarket.options_with(fn w -> w end,
          edge_formatter: &inspect/1,
          node_formatter: fn id -> "Node#{id}" end
        )

      result = MatrixMarket.serialize_with(options, graph)

      assert String.contains?(result, "Node1 Node2 {1.5, :real}")
    end

    test "serialize legacy options" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      options = {:matrix_market_options, fn w -> w end}
      result = MatrixMarket.serialize_with(options, graph)
      assert String.contains?(result, "1 2 5")
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
      assert MatrixMarket.parse("\n\n") == {:error, :empty_input}
    end

    test "missing header error" do
      assert MatrixMarket.parse("1 1 1") == {:error, {:missing_header, "1 1 1"}}
    end

    test "invalid size line error" do
      input = "%%MatrixMarket matrix coordinate real general\ninvalid size"
      assert {:error, {:invalid_size_line, _}} = MatrixMarket.parse(input)
    end

    test "invalid edge line warning" do
      input = "%%MatrixMarket matrix coordinate real general\n2 2 1\n1"
      {:ok, {:matrix_market_result, _, warnings}} = MatrixMarket.parse(input)
      assert length(warnings) == 1
    end

    test "complex field edge cases" do
      input = "%%MatrixMarket matrix coordinate complex general\n1 1 1\n1 1 1.5"
      {:ok, {:matrix_market_result, _, warnings}} = MatrixMarket.parse(input)
      # Incomplete complex line
      assert length(warnings) == 1
    end

    test "parse_float and parse_int edge cases" do
      input = "%%MatrixMarket matrix coordinate real general\n2 2 1\n1 2 not_a_number"

      {:ok, {:matrix_market_result, _, _warnings}} =
        MatrixMarket.parse_with(input, :directed, & &1, & &1)

      {_, _, weight} = hd(Yog.Model.all_edges(elem(elem(MatrixMarket.parse(input), 1), 1)))
      # Should fallback to string
      assert weight == "not_a_number"
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

    test "read_with and write_with roundtrip" do
      graph = Yog.directed() |> Yog.add_node(1, nil)
      options = MatrixMarket.options_with(fn w -> w end)
      assert :ok = MatrixMarket.write_with(@tmp_file, options, graph)
      {:ok, _} = MatrixMarket.read_with(@tmp_file, :directed, & &1, & &1)
      File.rm(@tmp_file)
    end

    test "read and read_with file not found error" do
      assert {:error, :enoent} = MatrixMarket.read("nonexistent_file.mtx")

      assert {:error, :enoent} =
               MatrixMarket.read_with("nonexistent_file.mtx", :directed, & &1, & &1)
    end

    test "header parsing invalid parts" do
      input = "%%MatrixMarket matrix\n"
      assert {:error, {:invalid_header, _}} = MatrixMarket.parse(input)
    end

    test "size line parsing skipping empty lines and comment lines" do
      input = """
      %%MatrixMarket matrix coordinate real general
      % This is a comment

      2 2 1
      1 2 4.5
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)
      assert Yog.Model.node_count(graph) == 2
    end

    test "size line parsing unexpected end of file" do
      input = "%%MatrixMarket matrix coordinate real general\n"
      assert {:error, :unexpected_end_of_file} = MatrixMarket.parse(input)
    end

    test "build graph with zero max_node" do
      input = """
      %%MatrixMarket matrix coordinate real general
      0 0 0
      """

      {:ok, {:matrix_market_result, graph, _warnings}} = MatrixMarket.parse(input)
      assert Yog.Model.node_count(graph) == 0
    end

    test "edge line parsing add_edge warning on nonexistent nodes" do
      input = """
      %%MatrixMarket matrix coordinate real general
      1 1 1
      1 99 5.5
      """

      {:ok, {:matrix_market_result, _, warnings}} = MatrixMarket.parse(input)
      assert length(warnings) == 1
    end

    test "edge line parsing missing weight value or custom field fallback" do
      # 1. Custom/unknown field type:
      # We construct a header manually, or wait, parse parses the header.
      # If header has custom field type, we can trigger {_, [w | _]} -> w fallback.
      # Let's write an input with custom field "unknown_field":
      input1 = """
      %%MatrixMarket matrix coordinate unknown_field general
      2 2 1
      1 2 custom_val
      """

      # Use raw parser with custom parser mapping string directly
      {:ok, {:matrix_market_result, graph1, _}} =
        MatrixMarket.parse_with(input1, :directed, & &1, & &1)

      {_, _, weight1} = hd(Yog.Model.all_edges(graph1))
      assert weight1 == "custom_val"

      # 2. Missing weight value for real field (defaults to 1.0):
      input2 = """
      %%MatrixMarket matrix coordinate real general
      2 2 1
      1 2
      """

      {:ok, {:matrix_market_result, graph2, _}} = MatrixMarket.parse(input2)
      {_, _, weight2} = hd(Yog.Model.all_edges(graph2))
      assert weight2 == 1.0
    end
  end
end
