defmodule Yog.IO.PajekTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.IO.Pajek

  doctest Yog.IO.Pajek

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize directed" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")
      |> Yog.add_edge_ensure(from: 2, to: 3, with: "knows")

    options =
      Pajek.options_with(
        fn data -> data end,
        fn _ -> :none end,
        fn _ -> Pajek.default_node_attributes() end,
        false,
        false
      )

    result = Pajek.serialize_with(options, graph)

    assert String.contains?(result, "*Vertices 3")
    assert String.contains?(result, ~s("Alice"))
    assert String.contains?(result, ~s("Bob"))
    assert String.contains?(result, ~s("Carol"))
    assert String.contains?(result, "*Arcs")
    assert String.contains?(result, "1 2")
    assert String.contains?(result, "2 3")
  end

  test "serialize undirected" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "edge1")

    options =
      Pajek.options_with(
        fn data -> data end,
        fn _ -> :none end,
        fn _ -> Pajek.default_node_attributes() end,
        false,
        false
      )

    result = Pajek.serialize_with(options, graph)

    assert String.contains?(result, "*Vertices 2")
    assert String.contains?(result, ~s("A"))
    assert String.contains?(result, ~s("B"))
    assert String.contains?(result, "*Edges")
    assert String.contains?(result, "1 2")
  end

  test "serialize with weights" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5.0)

    options =
      Pajek.options_with(
        fn _data -> "Person" end,
        fn w -> {:some, w} end,
        fn _ -> Pajek.default_node_attributes() end,
        false,
        false
      )

    result = Pajek.serialize_with(options, graph)

    assert String.contains?(result, "1 2 5.0")
  end

  test "serialize default" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

    result = Pajek.serialize(graph)

    assert String.contains?(result, "*Vertices 2")
    assert String.contains?(result, ~s("Alice"))
    assert String.contains?(result, ~s("Bob"))
  end

  test "serialize DAG" do
    dag =
      Yog.DAG.new()
      |> Yog.DAG.add_node(1, "Node1")
      |> Yog.DAG.add_node(2, "Node2")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, "link")

    result = Pajek.serialize(dag)
    assert String.contains?(result, "*Vertices 2")
    assert String.contains?(result, ~s("Node1"))
    assert String.contains?(result, ~s("Node2"))
  end

  test "serialize complex types" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, {"Alice", :admin})
      |> Yog.add_node(2, %{role: "User"})
      |> Yog.add_edge_ensure(from: 1, to: 2, with: {10, :kg})

    options =
      Pajek.options_with(
        fn d -> d end,
        fn w -> {:some, w} end,
        fn _ -> Pajek.default_node_attributes() end,
        false,
        false,
        node_formatter: &inspect/1,
        edge_formatter: &inspect/1
      )

    result = Pajek.serialize_with(options, graph)
    assert String.contains?(result, "{\"Alice\", :admin}")
    assert String.contains?(result, "{10, :kg}")
  end

  test "to_string alias test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "End")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "connects")

    result = Pajek.to_string(graph)

    assert String.contains?(result, "*Vertices 2")
  end

  test "input and options validation" do
    assert_raise ArgumentError, ~r/expected node_label to be an arity-1 function/, fn ->
      Pajek.options_with(:invalid, & &1, & &1, false, false)
    end

    assert_raise ArgumentError, ~r/expected edge_weight to be an arity-1 function/, fn ->
      Pajek.options_with(& &1, :invalid, & &1, false, false)
    end

    assert_raise ArgumentError, ~r/expected node_attributes to be an arity-1 function/, fn ->
      Pajek.options_with(& &1, & &1, :invalid, false, false)
    end

    assert_raise ArgumentError, ~r/expected include_coordinates to be a boolean/, fn ->
      Pajek.options_with(& &1, & &1, & &1, :invalid, false)
    end

    assert_raise ArgumentError, ~r/expected include_visuals to be a boolean/, fn ->
      Pajek.options_with(& &1, & &1, & &1, false, :invalid)
    end

    assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
      Pajek.options_with(& &1, & &1, & &1, false, false, :invalid)
    end

    assert_raise ArgumentError, ~r/expected node_formatter to be an arity-1 function/, fn ->
      Pajek.options_with(& &1, & &1, & &1, false, false, node_formatter: :invalid)
    end

    assert_raise ArgumentError, ~r/expected edge_formatter to be an arity-1 function/, fn ->
      Pajek.options_with(& &1, & &1, & &1, false, false, edge_formatter: :invalid)
    end

    assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
      Pajek.serialize(:not_a_graph)
    end

    assert_raise ArgumentError, ~r/expected valid pajek_options tuple/, fn ->
      Pajek.serialize_with(:invalid, Yog.directed())
    end

    assert_raise ArgumentError, ~r/expected input to be a binary string/, fn ->
      Pajek.parse(123)
    end

    assert_raise ArgumentError, ~r/expected node_parser to be an arity-1 function/, fn ->
      Pajek.parse_with("*Vertices 1", :invalid, & &1)
    end

    assert_raise ArgumentError, ~r/expected edge_parser to be an arity-1 function/, fn ->
      Pajek.parse_with("*Vertices 1", & &1, :invalid)
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      Pajek.read(123)
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      Pajek.read_with(123, & &1, & &1)
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      Pajek.write(123, Yog.directed())
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      Pajek.write_with(123, Pajek.default_options(), Yog.directed())
    end
  end

  # =============================================================================
  # PARSING TESTS
  # =============================================================================

  test "parse simple" do
    input = "*Vertices 2\n1 \"Alice\"\n2 \"Bob\"\n*Arcs\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
    assert Yog.Model.type(graph) == :directed

    assert Yog.Model.node(graph, 1) == "Alice"
    assert Yog.Model.node(graph, 2) == "Bob"
  end

  test "parse undirected" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Edges\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
    assert Yog.Model.type(graph) == :undirected
  end

  test "parse with weights" do
    input = "*Vertices 2\n1 \"Alice\"\n2 \"Bob\"\n*Arcs\n1 2 5.5"

    {:ok, {:pajek_result, graph, _warnings}} =
      Pajek.parse_with(input, fn s -> s end, fn w -> w end)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
  end

  test "parse empty input" do
    assert {:error, :empty_input} = Pajek.parse("")
  end

  test "parse alphanumeric ids" do
    input = "*Vertices 2\nA \"Alice\"\nB \"Bob\"\n*Arcs\nA B"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.all_nodes(graph) == ["A", "B"]
    assert Yog.Model.node(graph, "A") == "Alice"
  end

  test "parse invalid header" do
    input = "Invalid\n1 \"A\"\n*Arcs\n1 2"
    assert {:error, {:invalid_vertices_line, 1, "Invalid"}} = Pajek.parse(input)
  end

  test "parse edge header edge cases" do
    input = """
    *Vertices 1
    1 "A"

    *UnknownHeader
    """

    {:ok, {:pajek_result, graph, _}} = Pajek.parse(input)
    assert Yog.Model.node_count(graph) == 1
  end

  test "parse multiple edges" do
    input = "*Vertices 3\n1 \"A\"\n2 \"B\"\n3 \"C\"\n*Arcs\n1 2\n2 3"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 2
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

    options =
      Pajek.options_with(
        fn d -> d end,
        fn _ -> :none end,
        fn _ -> Pajek.default_node_attributes() end,
        false,
        false
      )

    exported = Pajek.serialize_with(options, graph)

    {:ok, {:pajek_result, loaded, _warnings}} =
      Pajek.parse_with(exported, fn s -> s end, fn _ -> "" end)

    assert Yog.Model.node_count(loaded) == 2
    assert Yog.Model.edge_count(loaded) == 1
  end

  # =============================================================================
  # NODE ATTRIBUTES TESTS
  # =============================================================================

  test "node shape test" do
    default_attrs = Pajek.default_node_attributes()
    shape = elem(default_attrs, 3)
    assert shape == :none
  end

  test "node attributes creation test" do
    attrs =
      {:node_attributes, {:some, 0.5}, {:some, 0.7}, {:some, :box}, {:some, 1.0}, {:some, "red"}}

    assert elem(attrs, 1) == {:some, 0.5}
    assert elem(attrs, 2) == {:some, 0.7}
  end

  # =============================================================================
  # CRITICAL BUG FIX TESTS
  # =============================================================================

  test "parse multi word labels" do
    input = "*Vertices 3\n1 \"Alice Smith\"\n2 \"Bob Jones\"\n3 \"Carol White\"\n*Arcs\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.node(graph, 1) == "Alice Smith"
    assert Yog.Model.node(graph, 2) == "Bob Jones"
    assert Yog.Model.node(graph, 3) == "Carol White"
  end

  test "parse multi word labels with coordinates" do
    input = "*Vertices 2\n1 \"Alice Smith\" 0.5 0.7\n2 \"Bob Jones\" 0.3 0.4\n*Arcs"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node(graph, 1) == "Alice Smith"
    assert Yog.Model.node(graph, 2) == "Bob Jones"
  end

  # =============================================================================
  # CASE-INSENSITIVE HEADER TESTS
  # =============================================================================

  test "parse lowercase arcs header" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*arcs\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.type(graph) == :directed
  end

  test "parse uppercase arcs header" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*ARCS\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.type(graph) == :directed
  end

  test "parse mixed case edges header" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*EdGeS\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.type(graph) == :undirected
  end

  test "parse lowercase vertices header" do
    input = "*vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
  end

  # =============================================================================
  # COMMENT HANDLING TESTS
  # =============================================================================

  test "parse with comments" do
    input =
      "% This is a comment\n*Vertices 2\n% Another comment\n1 \"Alice\"\n2 \"Bob\"\n% Comment before arcs\n*Arcs\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
  end

  # =============================================================================
  # EMPTY SECTION TESTS
  # =============================================================================

  test "parse empty arcs section" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 0
  end

  test "parse empty edges section" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Edges"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 0
  end

  # =============================================================================
  # MALFORMED INPUT TESTS
  # =============================================================================

  test "parse label without quotes" do
    input = "*Vertices 2\n1 Alice\n2 Bob\n*Arcs\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node(graph, 1) == "Alice"
    assert Yog.Model.node(graph, 2) == "Bob"
  end

  test "parse edge referencing nonexistent node" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 99"

    {:ok, {:pajek_result, graph, warnings}} = Pajek.parse(input)

    assert Yog.Model.edge_count(graph) == 0
    assert warnings != []
  end

  test "parse with malformed lines" do
    input = """
    *Vertices 2
    1 "A"
    2 "B"
    *Arcs
    1 2
    malformed line
    2 1
    """

    {:ok, {:pajek_result, graph, warnings}} = Pajek.parse(input)

    assert Yog.Model.edge_count(graph) == 2
    assert warnings != []
  end

  test "parse weight edge cases" do
    input = """
    *Vertices 2
    1 "A"
    2 "B"
    *Arcs
    1 2 string_weight
    """

    {:ok, {:pajek_result, graph, _}} = Pajek.parse_with(input, & &1, & &1)
    {_, _, weight} = hd(Yog.Model.all_edges(graph))
    assert weight == {:some, "string_weight"}
  end

  test "parse unquoted node with only ID" do
    input = """
    *Vertices 1
    1
    *Arcs
    """

    {:ok, {:pajek_result, graph, _}} = Pajek.parse(input)
    assert Yog.Model.node(graph, 1) == "1"
  end

  test "parse legacy options" do
    graph = Yog.directed() |> Yog.add_node(1, "A")

    options =
      {:pajek_options, fn d -> d end, fn _ -> :none end,
       fn _ -> Pajek.default_node_attributes() end, false, false}

    result = Pajek.serialize_with(options, graph)
    assert String.contains?(result, "1 \"A\"")
  end

  # =============================================================================
  # WHITESPACE HANDLING TESTS
  # =============================================================================

  test "parse multiple spaces" do
    input = "*Vertices 2\n1   \"Alice\"\n2    \"Bob\"\n*Arcs\n1   2"

    {:ok, {:pajek_result, graph, _warnings}} = Pajek.parse(input)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
  end

  test "parse multiple spaces with weights" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1   2   5.5"

    {:ok, {:pajek_result, graph, _warnings}} =
      Pajek.parse_with(input, fn s -> s end, fn w -> w end)

    assert Yog.Model.edge_count(graph) == 1
  end

  # =============================================================================
  # WEIGHT PARSING TESTS
  # =============================================================================

  test "parse edges with integer weights" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 2 5"

    {:ok, {:pajek_result, graph, _warnings}} =
      Pajek.parse_with(input, fn s -> s end, fn w -> w end)

    assert Yog.Model.edge_count(graph) == 1
  end

  test "parse edges without weights" do
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 2"

    {:ok, {:pajek_result, graph, _warnings}} =
      Pajek.parse_with(input, fn s -> s end, fn
        {:some, _} -> "weighted"
        :none -> "unweighted"
      end)

    assert Yog.Model.edge_count(graph) == 1
  end

  # =============================================================================
  # FIXTURE FILE TESTS
  # =============================================================================

  test "read sample fixture file" do
    fixture_path = "test/fixtures/io/sample.net"
    assert File.exists?(fixture_path), "Fixture file does not exist"

    {:ok, {:pajek_result, graph, warnings}} = Pajek.read(fixture_path)

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
    fixture_path = "test/fixtures/io/sample.net"
    output_path = "/tmp/test_yog_pajek_output.net"

    {:ok, {:pajek_result, original, _}} = Pajek.read(fixture_path)

    assert :ok = Pajek.write(output_path, original)
    assert File.exists?(output_path)

    {:ok, {:pajek_result, reloaded, _}} = Pajek.read(output_path)

    assert Yog.Model.node_count(reloaded) == Yog.Model.node_count(original)
    assert Yog.Model.edge_count(reloaded) == Yog.Model.edge_count(original)
    assert Yog.Model.type(reloaded) == Yog.Model.type(original)

    assert Yog.Model.node(reloaded, 1) == "Alice"
    assert Yog.Model.node(reloaded, 2) == "Bob"
    assert Yog.Model.node(reloaded, 3) == "Charlie"

    File.rm(output_path)
  end

  # =============================================================================
  # FILE I/O ERROR TESTS
  # =============================================================================

  test "read file not found" do
    assert {:error, :enoent} = Pajek.read("nonexistent.net")
  end

  test "read_with file not found" do
    assert {:error, :enoent} = Pajek.read_with("nonexistent.net", & &1, & &1)
  end

  test "write_with roundtrip" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 3.5)

    options =
      Pajek.options_with(
        fn d -> d end,
        fn w -> {:some, w} end,
        fn _ -> Pajek.default_node_attributes() end,
        false,
        false
      )

    path = "/tmp/test_yog_pajek_write_with.net"
    assert :ok = Pajek.write_with(path, options, graph)
    assert File.exists?(path)
    {:ok, {:pajek_result, loaded, _}} = Pajek.read(path)
    assert Yog.Model.node_count(loaded) == 2
    File.rm(path)
  end

  test "parse invalid vertex count" do
    input = "*Vertices abc\n1 \"A\"\n"
    assert {:error, {:invalid_vertices_line, _, _}} = Pajek.parse(input)
  end

  test "parse unexpected end of nodes" do
    input = "*Vertices 3\n1 \"A\"\n2 \"B\"\n"
    assert {:error, :unexpected_end_of_nodes} = Pajek.parse(input)
  end

  test "parse edge header empty input" do
    input = "*Vertices 1\n1 \"A\"\n"
    {:ok, {:pajek_result, graph, _}} = Pajek.parse(input)
    assert Yog.Model.node_count(graph) == 1
    assert Yog.Model.edge_count(graph) == 0
  end

  describe "property tests" do
    property "roundtrip serialize and parse preserves node and edge counts for 1-indexed graphs" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              n <- StreamData.integer(1..15),
              raw_edges <-
                StreamData.list_of(
                  StreamData.tuple({StreamData.integer(1..n), StreamData.integer(1..n)})
                )
            ) do
        graph =
          Enum.reduce(1..n, Yog.Model.new(kind), &Yog.add_node(&2, &1, "Node#{&1}"))

        graph =
          Enum.reduce(raw_edges, graph, fn {u, v}, acc ->
            Yog.add_edge_ensure(acc, u, v, "Edge")
          end)

        pajek = Pajek.serialize(graph)
        assert {:ok, {:pajek_result, parsed, _warnings}} = Pajek.parse(pajek)
        assert Yog.Model.node_count(parsed) == Yog.Model.node_count(graph)
        assert Yog.Model.edge_count(parsed) == Yog.Model.edge_count(graph)
      end
    end
  end
end
