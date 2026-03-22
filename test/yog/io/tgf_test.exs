defmodule Yog.IO.TGFTest do
  use ExUnit.Case

  alias Yog.IO.TGF

  doctest Yog.IO.TGF

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize directed graph" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")
      |> Yog.add_edges!([{1, 2, "follows"}, {2, 3, "knows"}])

    options = TGF.options_with(fn data -> data end, fn _ -> :none end)
    result = TGF.serialize_with(options, graph)

    assert String.contains?(result, "1 Alice")
    assert String.contains?(result, "2 Bob")
    assert String.contains?(result, "3 Carol")
    assert String.contains?(result, "#")
    assert String.contains?(result, "1 2")
    assert String.contains?(result, "2 3")
  end

  test "serialize with edge labels" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    options = TGF.options_with(fn data -> data end, fn label -> {:some, label} end)
    result = TGF.serialize_with(options, graph)

    assert String.contains?(result, "1 2 follows")
  end

  test "serialize default" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    result = TGF.serialize(graph)

    # Default uses node data as label
    assert String.contains?(result, "1 Alice")
    assert String.contains?(result, "2 Bob")
  end

  test "serialize undirected graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edges!([{1, 2, ""}, {2, 3, ""}])

    options = TGF.options_with(fn data -> data end, fn _ -> :none end)
    result = TGF.serialize_with(options, graph)

    assert String.contains?(result, "1 A")
    assert String.contains?(result, "2 B")
    assert String.contains?(result, "3 C")
    assert String.contains?(result, "#")
  end

  # =============================================================================
  # PARSING TESTS
  # =============================================================================

  test "parse simple" do
    input = """
    1 Alice
    2 Bob
    #
    1 2
    """

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1

    assert Yog.Model.node(graph, 1) == "Alice"
    assert Yog.Model.node(graph, 2) == "Bob"
  end

  test "parse with edge labels" do
    input = """
    1 Alice
    2 Bob
    3 Carol
    #
    1 2 follows
    2 3 knows
    """

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 2
  end

  test "parse undirected" do
    input = """
    1 A
    2 B
    3 C
    #
    1 2
    2 3
    """

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :undirected)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 2
    assert Yog.Model.type(graph) == :undirected
  end

  test "parse empty input" do
    input = ""
    assert {:error, _} = TGF.parse(input, :directed)
  end

  test "parse no edges" do
    input = """
    1 Alice
    2 Bob
    #
    """

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 0
  end

  test "parse only separator" do
    input = "#"

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 0
    assert Yog.Model.edge_count(graph) == 0
  end

  test "parse whitespace handling" do
    input = """
      1  Alice  
      2  Bob  
      #  
      1  2  follows  
    """

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 2
  end

  test "parse labels with spaces" do
    input = """
    1 Alice Smith
    2 Bob Jones
    #
    1 2 works with
    """

    {:ok, {:tgf_result, graph, _warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node(graph, 1) == "Alice Smith"
    assert Yog.Model.node(graph, 2) == "Bob Jones"
  end

  test "parse duplicate node id" do
    input = """
    1 Alice
    1 Bob
    #
    """

    assert {:error, _} = TGF.parse(input, :directed)
  end

  # =============================================================================
  # ROUNDTRIP TESTS
  # =============================================================================

  test "roundtrip simple" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    options = TGF.options_with(fn data -> data end, fn label -> {:some, label} end)
    exported = TGF.serialize_with(options, graph)

    {:ok, {:tgf_result, loaded, _}} =
      TGF.parse_with(
        exported,
        :directed,
        fn _id, label -> label end,
        fn label -> label end
      )

    assert Yog.Model.node_count(loaded) == 2
    assert Yog.Model.edge_count(loaded) == 1
  end

  # =============================================================================
  # CUSTOM TYPE TESTS
  # =============================================================================

  test "serialize custom types" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 100)
      |> Yog.add_node(2, 200)
      |> Yog.add_edge!(from: 1, to: 2, with: 42)

    options =
      TGF.options_with(
        fn n -> Integer.to_string(n) end,
        fn w -> {:some, Integer.to_string(w)} end
      )

    result = TGF.serialize_with(options, graph)

    assert String.contains?(result, "1 100")
    assert String.contains?(result, "2 200")
    assert String.contains?(result, "1 2 42")
  end

  # =============================================================================
  # AUTO-NODE CREATION TESTS
  # =============================================================================

  test "parse auto create nodes" do
    input = """
    1 Alice
    #
    1 99 knows
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1

    assert Yog.Model.node(graph, 99) == "99"
  end

  test "parse auto create both nodes" do
    input = """
    #
    5 10 connects
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1

    assert Yog.Model.node(graph, 5) == "5"
    assert Yog.Model.node(graph, 10) == "10"
  end

  # =============================================================================
  # ERROR HANDLING TESTS
  # =============================================================================

  test "parse invalid node id" do
    input = """
    abc Alice
    #
    """

    # In Gleam: Error(InvalidNodeId(line: 1, value: "abc"))
    # In Elixir, standard tuple wrapping applies (e.g. `{:invalid_node_id, 1, "abc"}`)
    {:error, error} = TGF.parse(input, :directed)
    assert elem(error, 0) == :invalid_node_id
    assert elem(error, 1) == 1
    assert elem(error, 2) == "abc"
  end

  test "parse invalid edge source" do
    input = """
    1 Alice
    2 Bob
    #
    xyz 2
    """

    {:error, error} = TGF.parse(input, :directed)
    assert elem(error, 0) == :invalid_edge_endpoint
    assert elem(error, 1) == 4
    assert elem(error, 2) == "xyz"
  end

  test "parse invalid edge target" do
    input = """
    1 Alice
    2 Bob
    #
    1 xyz
    """

    {:error, error} = TGF.parse(input, :directed)
    assert elem(error, 0) == :invalid_edge_endpoint
    assert elem(error, 1) == 4
    assert elem(error, 2) == "xyz"
  end

  # =============================================================================
  # WARNING TESTS
  # =============================================================================

  test "parse with warnings" do
    input = """
    1 Alice
    2 Bob
    #
    1 2
    3
    incomplete
    """

    {:ok, {:tgf_result, graph, warnings}} = TGF.parse(input, :directed)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1

    assert length(warnings) == 2
  end

  # =============================================================================
  # EDGE CASE TESTS
  # =============================================================================

  test "parse node without label" do
    input = """
    1
    2 Bob
    #
    1 2
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

    assert Yog.Model.node(graph, 1) == "1"
    assert Yog.Model.node(graph, 2) == "Bob"
  end

  test "parse multiple spaces" do
    input = """
    1   Alice   Smith
    2    Bob    Jones
    #
    1   2   works   with
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

    assert Yog.Model.node(graph, 1) == "Alice Smith"
    assert Yog.Model.node(graph, 2) == "Bob Jones"
  end
end
