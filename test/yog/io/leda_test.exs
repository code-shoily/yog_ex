defmodule Yog.IO.LEDATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.IO.LEDA

  doctest Yog.IO.LEDA

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize directed graph" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")
      |> Yog.add_edge_ensure(from: 2, to: 3, with: "knows")

    options = LEDA.options_with(fn d -> d end, fn d -> d end, fn s -> s end, fn s -> s end)
    result = LEDA.serialize_with(options, graph)

    assert String.contains?(result, "LEDA.GRAPH")
    assert String.contains?(result, "string")
    assert String.contains?(result, "-1")
    assert String.contains?(result, "|{Alice}|")
    assert String.contains?(result, "|{Bob}|")
    assert String.contains?(result, "|{Carol}|")
    assert String.contains?(result, "1 2 0 |{follows}|")
    assert String.contains?(result, "2 3 0 |{knows}|")
  end

  test "serialize undirected graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "edge1")

    result = LEDA.serialize(graph)

    assert String.contains?(result, "-2")
    assert String.contains?(result, "|{A}|")
    assert String.contains?(result, "|{B}|")
  end

  test "serialize default configuration" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

    result = LEDA.serialize(graph)

    assert String.contains?(result, "LEDA.GRAPH")
    assert String.contains?(result, "|{Alice}|")
    assert String.contains?(result, "|{Bob}|")
  end

  test "to_string alias test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "End")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "connects")

    result = LEDA.to_string(graph)

    assert String.contains?(result, "LEDA.GRAPH")
  end

  test "serialize DAG" do
    dag =
      Yog.DAG.new()
      |> Yog.DAG.add_node(1, "Node1")
      |> Yog.DAG.add_node(2, "Node2")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, "link")

    result = LEDA.serialize(dag)
    assert String.contains?(result, "LEDA.GRAPH")
    assert String.contains?(result, "|{Node1}|")
    assert String.contains?(result, "|{Node2}|")
  end

  test "input and option validation" do
    assert_raise ArgumentError, ~r/expected node_serializer to be an arity-1 function/, fn ->
      LEDA.options_with(:invalid, &to_string/1, & &1, & &1)
    end

    assert_raise ArgumentError, ~r/expected edge_serializer to be an arity-1 function/, fn ->
      LEDA.options_with(&to_string/1, :invalid, & &1, & &1)
    end

    assert_raise ArgumentError, ~r/expected node_deserializer to be an arity-1 function/, fn ->
      LEDA.options_with(&to_string/1, &to_string/1, :invalid, & &1)
    end

    assert_raise ArgumentError, ~r/expected edge_deserializer to be an arity-1 function/, fn ->
      LEDA.options_with(&to_string/1, &to_string/1, & &1, :invalid)
    end

    assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
      LEDA.options_with(&to_string/1, &to_string/1, & &1, & &1, :invalid_opts)
    end

    assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
      LEDA.serialize(:not_a_graph)
    end

    assert_raise ArgumentError, ~r/expected valid leda_options tuple/, fn ->
      LEDA.serialize_with(:invalid_opts, Yog.directed())
    end
  end

  # =============================================================================
  # PARSING TESTS
  # =============================================================================

  test "parse simple graph" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice}|\n|{Bob}|\n1\n1 2 0 |{follows}|"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1

    assert Yog.Model.node(graph, 1) == "Alice"
    assert Yog.Model.node(graph, 2) == "Bob"
  end

  test "parse undirected graph" do
    input = "LEDA.GRAPH\nstring\nstring\n-2\n2\n|{A}|\n|{B}|\n1\n1 2 0 |{edge1}|"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.type(graph) == :undirected
  end

  test "parse empty input" do
    assert {:error, :empty_input} = LEDA.parse("")
  end

  test "parse invalid header" do
    input = "INVALID\nstring\nstring\n-1\n1\n|{A}|\n0"
    assert {:error, :invalid_header} = LEDA.parse(input)
  end

  test "parse with custom types (node and edge parsers)" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{100}|\n|{200}|\n1\n1 2 0 |{42}|"

    node_parser = fn s ->
      case Integer.parse(s) do
        {n, _} -> n
        :error -> 0
      end
    end

    edge_parser = node_parser

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse_with(input, node_parser, edge_parser)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.node(graph, 1) == 100
    assert Yog.Model.node(graph, 2) == 200
  end

  test "parse_with input validation" do
    assert_raise ArgumentError, ~r/expected input to be a binary string/, fn ->
      LEDA.parse(123)
    end

    assert_raise ArgumentError, ~r/expected node_parser to be an arity-1 function/, fn ->
      LEDA.parse_with("LEDA.GRAPH", :invalid, & &1)
    end

    assert_raise ArgumentError, ~r/expected edge_parser to be an arity-1 function/, fn ->
      LEDA.parse_with("LEDA.GRAPH", & &1, :invalid)
    end
  end

  # =============================================================================
  # ROUNDTRIP TESTS
  # =============================================================================

  test "roundtrip simple test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

    options = LEDA.options_with(fn d -> d end, fn d -> d end, fn s -> s end, fn s -> s end)
    exported = LEDA.serialize_with(options, graph)

    {:ok, {:leda_result, parsed_graph, _warnings}} =
      LEDA.parse_with(exported, fn s -> s end, fn s -> s end)

    assert Yog.Model.node_count(parsed_graph) == 2
    assert Yog.Model.edge_count(parsed_graph) == 1
  end

  # =============================================================================
  # EDGE CASE TESTS
  # =============================================================================

  test "parse labels with spaces" do
    input =
      "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice Smith}|\n|{Bob Jones}|\n1\n1 2 0 |{works with}|"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node(graph, 1) == "Alice Smith"
    assert Yog.Model.node(graph, 2) == "Bob Jones"
  end

  test "parse multiple edges" do
    input =
      "LEDA.GRAPH\nstring\nstring\n-1\n3\n|{A}|\n|{B}|\n|{C}|\n2\n1 2 0 |{edge1}|\n2 3 0 |{edge2}|"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 2
  end

  test "serialize custom types" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 100)
      |> Yog.add_node(2, 200)
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 42)

    int_parser = fn s ->
      case Integer.parse(s) do
        {n, _} -> n
        :error -> 0
      end
    end

    options = LEDA.options_with(&to_string/1, &to_string/1, int_parser, int_parser)
    result = LEDA.serialize_with(options, graph)

    assert String.contains?(result, "|{100}|")
    assert String.contains?(result, "|{200}|")
    assert String.contains?(result, "|{42}|")
  end

  # =============================================================================
  # ERROR HANDLING TESTS
  # =============================================================================

  test "parse invalid direction" do
    input = "LEDA.GRAPH\nstring\nstring\n-99\n1\n|{A}|\n0"

    assert {:error, {:invalid_direction, 4, "-99"}} = LEDA.parse(input)
  end

  test "parse empty graph block" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n0\n0"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node_count(graph) == 0
    assert Yog.Model.edge_count(graph) == 0
  end

  test "parse edge referencing nonexistent node with warnings" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n1\n1 99 0 |{edge}|"

    {:ok, {:leda_result, graph, warnings}} = LEDA.parse(input)

    assert Yog.Model.edge_count(graph) == 0
    assert warnings != []
  end

  test "parse invalid node data format" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\nAlice\n|{Bob}|\n0"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.node(graph, 1) == "Alice"
  end

  test "parse malformed edge line with warnings" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n1\n1 2"

    {:ok, {:leda_result, graph, warnings}} = LEDA.parse(input)

    assert Yog.Model.edge_count(graph) == 0
    assert warnings != []
  end

  test "parse multiple spaces" do
    input =
      "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice   Smith}|\n|{Bob   Jones}|\n1\n1   2   0   |{works   with}|"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node(graph, 1) == "Alice   Smith"
    assert Yog.Model.node(graph, 2) == "Bob   Jones"
  end

  test "parse node id mapping" do
    input =
      "LEDA.GRAPH\nstring\nstring\n-1\n3\n|{First}|\n|{Second}|\n|{Third}|\n2\n1 3 0 |{edge1}|\n2 3 0 |{edge2}|"

    {:ok, {:leda_result, graph, _warnings}} = LEDA.parse(input)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 2
    assert Yog.Model.node(graph, 1) == "First"
    assert Yog.Model.node(graph, 2) == "Second"
    assert Yog.Model.node(graph, 3) == "Third"
  end

  test "parse with warnings payload populated" do
    input =
      "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n2\n1 2 0 |{valid}|\ninvalid edge line"

    {:ok, {:leda_result, graph, warnings}} = LEDA.parse(input)

    assert Yog.Model.edge_count(graph) == 1
    assert warnings != []
  end

  test "parse with premature EOF in nodes" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n5\n|{A}|\n|{B}|"
    assert {:error, {:unexpected_end_of_nodes, _}} = LEDA.parse(input)
  end

  test "parse with missing node count" do
    input = "LEDA.GRAPH\nstring\nstring\n-1"
    assert {:error, :missing_node_count} = LEDA.parse(input)
  end

  test "parse with missing direction" do
    input = "LEDA.GRAPH\nstring\nstring"
    assert {:error, :missing_direction} = LEDA.parse(input)
  end

  test "parse with invalid node count" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\nnot_a_number"
    assert {:error, :invalid_node_count} = LEDA.parse(input)
  end

  test "parse with premature EOF in edges" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n5\n1 2 0 |{edge1}|"
    {:ok, {:leda_result, graph, warnings}} = LEDA.parse(input)
    assert Yog.Model.edge_count(graph) == 1
    assert warnings == []
  end

  test "parse with invalid edge format" do
    input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n1\n1 abc 0 |{data}|"
    {:ok, {:leda_result, _graph, warnings}} = LEDA.parse(input)
    assert length(warnings) == 1
  end

  # =============================================================================
  # FIXTURE FILE TESTS
  # =============================================================================

  test "read sample fixture file" do
    fixture_path = "test/fixtures/io/sample.leda"
    assert File.exists?(fixture_path), "Fixture file does not exist"

    {:ok, {:leda_result, graph, warnings}} = LEDA.read(fixture_path)

    assert warnings == []
    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 3
    assert Yog.Model.type(graph) == :directed

    assert Yog.Model.node(graph, 1) == "Alice"
    assert Yog.Model.node(graph, 2) == "Bob"
    assert Yog.Model.node(graph, 3) == "Charlie"

    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 1
  end

  test "roundtrip fixture file" do
    fixture_path = "test/fixtures/io/sample.leda"
    output_path = "/tmp/test_yog_leda_output.leda"

    {:ok, {:leda_result, original, _}} = LEDA.read(fixture_path)

    assert :ok = LEDA.write(output_path, original)
    assert File.exists?(output_path)

    {:ok, {:leda_result, reloaded, _}} = LEDA.read(output_path)

    assert Yog.Model.node_count(reloaded) == Yog.Model.node_count(original)
    assert Yog.Model.edge_count(reloaded) == Yog.Model.edge_count(original)
    assert Yog.Model.type(reloaded) == Yog.Model.type(original)

    assert Yog.Model.node(reloaded, 1) == "Alice"
    assert Yog.Model.node(reloaded, 2) == "Bob"
    assert Yog.Model.node(reloaded, 3) == "Charlie"

    File.rm(output_path)
  end

  test "default options call" do
    assert {:leda_options, _, _, _, _, _, _} = LEDA.default_options()
  end

  test "serialize with 5-element options tuple" do
    graph = Yog.directed() |> Yog.add_node(1, nil)
    options = {:leda_options, fn d -> d end, fn d -> d end, fn s -> s end, fn s -> s end}
    assert String.contains?(LEDA.serialize_with(options, graph), "LEDA.GRAPH")
  end

  test "read and write file errors" do
    graph = Yog.directed() |> Yog.add_node(1, nil)
    assert {:error, :enoent} = LEDA.write("/nonexistent_dir/file.leda", graph)

    assert {:error, :enoent} =
             LEDA.write_with("/nonexistent_dir/file.leda", LEDA.default_options(), graph)

    assert {:error, :enoent} = LEDA.read_with("/nonexistent_dir/file.leda", & &1, & &1)
  end

  test "read/1, read_with/3, write/2, write_with/3 raise ArgumentError for non-binary paths" do
    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      LEDA.read(123)
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      LEDA.read_with(123, & &1, & &1)
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      LEDA.write(123, Yog.directed())
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      LEDA.write_with(123, LEDA.default_options(), Yog.directed())
    end
  end

  test "parse truncated and malformed inputs" do
    assert {:error, :missing_node_type} = LEDA.parse("LEDA.GRAPH")
    assert {:error, :missing_edge_type} = LEDA.parse("LEDA.GRAPH\nstring")

    input_no_edge_count = """
    LEDA.GRAPH
    string
    string
    -1
    2
    |{A}|
    |{B}|
    """

    assert {:error, :missing_edge_count} = LEDA.parse(String.trim_trailing(input_no_edge_count))

    input_invalid_edge_count = """
    LEDA.GRAPH
    string
    string
    -1
    2
    |{A}|
    |{B}|
    abc
    """

    assert {:error, :invalid_edge_count} = LEDA.parse(input_invalid_edge_count)
  end

  test "parse edges with empty lines" do
    input = """
    LEDA.GRAPH
    string
    string
    -1
    2
    |{A}|
    |{B}|
    2
    1 2 0 |{edge1}|

    2 1 0 |{edge2}|
    """

    {:ok, {:leda_result, graph, warnings}} = LEDA.parse(input)
    assert Yog.Model.edge_count(graph) == 2
    assert warnings == []
  end

  describe "property tests" do
    property "roundtrip serialize and parse preserves node and edge counts for 1-indexed graphs" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              n <- StreamData.integer(0..15),
              raw_edges <-
                StreamData.list_of(
                  StreamData.tuple(
                    {StreamData.integer(1..max(n, 1)), StreamData.integer(1..max(n, 1))}
                  )
                )
            ) do
        graph =
          if n == 0 do
            Yog.Model.new(kind)
          else
            base =
              Enum.reduce(
                1..n,
                Yog.Model.new(kind),
                &Yog.add_node(&2, &1, "Node#{&1}")
              )

            Enum.reduce(raw_edges, base, fn {u, v}, acc ->
              if u <= n and v <= n do
                Yog.add_edge_ensure(acc, u, v, "Edge")
              else
                acc
              end
            end)
          end

        leda = LEDA.serialize(graph)
        assert {:ok, {:leda_result, parsed, _warnings}} = LEDA.parse(leda)

        assert Yog.Model.node_count(parsed) == Yog.Model.node_count(graph)
        assert Yog.Model.edge_count(parsed) == Yog.Model.edge_count(graph)
      end
    end
  end
end
