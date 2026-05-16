defmodule Yog.IO.LEDATest do
  use ExUnit.Case

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
    # Expected 5 edges, only got 1.
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

    # Verify no warnings
    assert warnings == []

    # Verify graph structure
    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 3
    assert Yog.Model.type(graph) == :directed

    # Verify node data
    assert Yog.Model.node(graph, 1) == "Alice"
    assert Yog.Model.node(graph, 2) == "Bob"
    assert Yog.Model.node(graph, 3) == "Charlie"

    # Verify edges exist
    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 1
  end

  test "roundtrip fixture file" do
    fixture_path = "test/fixtures/io/sample.leda"
    output_path = "/tmp/test_yog_leda_output.leda"

    # Read original fixture
    {:ok, {:leda_result, original, _}} = LEDA.read(fixture_path)

    # Write to temp file
    assert :ok = LEDA.write(output_path, original)
    assert File.exists?(output_path)

    # Read back the written file
    {:ok, {:leda_result, reloaded, _}} = LEDA.read(output_path)

    # Verify structure matches
    assert Yog.Model.node_count(reloaded) == Yog.Model.node_count(original)
    assert Yog.Model.edge_count(reloaded) == Yog.Model.edge_count(original)
    assert Yog.Model.type(reloaded) == Yog.Model.type(original)

    # Verify node data matches
    assert Yog.Model.node(reloaded, 1) == "Alice"
    assert Yog.Model.node(reloaded, 2) == "Bob"
    assert Yog.Model.node(reloaded, 3) == "Charlie"

    # Cleanup
    File.rm(output_path)
  end
end
