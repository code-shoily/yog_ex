defmodule Yog.IO.PajekTest do
  use ExUnit.Case

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
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")
      |> Yog.add_edge!(from: 2, to: 3, with: "knows")

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
      |> Yog.add_edge!(from: 1, to: 2, with: "edge1")

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
      |> Yog.add_edge!(from: 1, to: 2, with: 5.0)

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
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    result = Pajek.serialize(graph)

    assert String.contains?(result, "*Vertices 2")
    assert String.contains?(result, ~s("Alice"))
    assert String.contains?(result, ~s("Bob"))
  end

  test "to_string alias test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "End")
      |> Yog.add_edge!(from: 1, to: 2, with: "connects")

    result = Pajek.to_string(graph)

    assert String.contains?(result, "*Vertices 2")
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

  test "parse invalid header" do
    input = "Invalid\n1 \"A\"\n*Arcs\n1 2"
    assert {:error, {:invalid_vertices_line, 1, "Invalid"}} = Pajek.parse(input)
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
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

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
    # node attributes are {:node_attributes, x, y, shape, size, color}
    # shape is the 4th element (1-based), because record fields start at index 2 (+name) in Erlang
    # We can just verify it is :none since Gleam None compiles to :none
    # The tuple is {:node_attributes, x, y, shape, size, color}
    # NOTE: This elem() accesses a node_attributes tuple, NOT a graph, so keep it as-is
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
    input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 2\ninvalid line\n2 1"

    {:ok, {:pajek_result, graph, warnings}} = Pajek.parse(input)

    assert Yog.Model.edge_count(graph) == 2
    assert warnings != []
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
end
