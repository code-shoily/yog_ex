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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

    options = TGF.options_with(fn data -> data end, fn label -> {:some, label} end)
    result = TGF.serialize_with(options, graph)

    assert String.contains?(result, "1 2 follows")
  end

  test "serialize default" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

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

  test "serialize complex types" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, {"Alice", :admin})
      |> Yog.add_node(2, %{role: "User"})
      |> Yog.add_edge_ensure(from: 1, to: 2, with: {10, :kg})

    options =
      TGF.options_with(
        fn data -> data end,
        fn weight -> {:some, weight} end,
        node_formatter: &inspect/1,
        edge_formatter: &inspect/1
      )

    # Should not crash on tuples/maps
    result = TGF.serialize_with(options, graph)
    assert String.contains?(result, "{\"Alice\", :admin}")
    assert String.contains?(result, "{10, :kg}")
  end

  # =============================================================================
  # ERROR HANDLING TESTS
  # =============================================================================

  test "parse alphanumeric node id" do
    input = """
    abc Alice
    #
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

    # Alphanumeric IDs are now supported!
    assert Yog.all_nodes(graph) == ["abc"]
    assert Yog.Model.node(graph, "abc") == "Alice"
  end

  test "parse alphanumeric edge endpoints" do
    input = """
    #
    node1 node2
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

    assert length(Yog.all_nodes(graph)) == 2
    assert Enum.member?(Yog.all_nodes(graph), "node1")
    assert Enum.member?(Yog.all_nodes(graph), "node2")
  end

  test "parse invalid input" do
    input = "   "
    assert {:error, {:missing_separator, _}} = TGF.parse(input, :directed)
  end

  test "parse with error adding edge" do
    # This is tricky because add_edge rarely fails if nodes exist.
    # We can simulate by using a graph type that rejects certain edges if it existed.
    # But for TGF, we just check warnings.
    input = """
    1 A
    2 B
    #
    1 2
    3
    """

    {:ok, {:tgf_result, _graph, warnings}} = TGF.parse(input, :directed)
    assert length(warnings) == 1
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

  # =============================================================================
  # FIXTURE FILE TESTS
  # =============================================================================

  test "read sample fixture file" do
    fixture_path = "test/fixtures/io/sample.tgf"
    assert File.exists?(fixture_path), "Fixture file does not exist"

    {:ok, {:tgf_result, graph, warnings}} = TGF.read(fixture_path, :directed)

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

  test "read and write simple" do
    path = "/tmp/test_yog_tgf_simple.tgf"
    graph = Yog.directed() |> Yog.add_node(1, "Alice")
    assert :ok = TGF.write(path, graph)
    assert {:ok, _} = TGF.read(path, :directed)
    File.rm(path)
  end

  test "read_with and write_with roundtrip" do
    path = "/tmp/test_yog_tgf_custom.tgf"
    graph = Yog.directed() |> Yog.add_node(1, %{name: "Alice"})

    options = TGF.options_with(fn d -> d.name end, fn _ -> :none end)

    try do
      assert :ok = TGF.write_with(path, options, graph)

      {:ok, {:tgf_result, loaded, _}} =
        TGF.read_with(path, :directed, fn _id, label -> %{name: label} end, fn _ -> nil end)

      assert Yog.Model.node(loaded, 1).name == "Alice"
    after
      File.rm(path)
    end
  end

  test "parse handles no separator" do
    input = "1 Alice\n2 Bob"
    assert {:error, {:missing_separator, _}} = TGF.parse(input, :directed)
  end

  test "serialize with legacy 3-tuple options" do
    # Verify backward compatibility
    graph = Yog.directed() |> Yog.add_node(1, "A")
    options = {:tgf_options, fn d -> d end, fn _ -> :none end}
    result = TGF.serialize_with(options, graph)
    assert String.contains?(result, "1 A")
  end

  test "parse handles empty lines and warnings" do
    input = """
    1 A

    2 B
    #
    1 2

    malformed
    """

    {:ok, {:tgf_result, graph, warnings}} = TGF.parse(input, :directed)
    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
    # One malformed line
    assert length(warnings) == 1
  end

  test "parse edge with invalid endpoint warning" do
    # Since parse_int now supports strings, we need a way to fail add_edge.
    # Actually, add_edge might fail if we reach a limit or something,
    # but for now let's just trigger the malformed edge warning.
    input = """
    1 A
    #
    1
    """

    {:ok, {:tgf_result, _, warnings}} = TGF.parse(input, :directed)
    assert length(warnings) == 1
    assert elem(hd(warnings), 0) == :malformed_edge
  end
end
