defmodule Yog.IO.TGFTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Yog.IO.TGF
  import Yog.Generators

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

  test "serialize Yog.DAG struct" do
    g =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

    {:ok, dag} = Yog.DAG.from_graph(g)

    tgf = TGF.serialize(dag)
    assert String.contains?(tgf, "1 Alice")
    assert String.contains?(tgf, "2 Bob")
    assert String.contains?(tgf, "1 2")
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

    result = TGF.serialize_with(options, graph)
    assert String.contains?(result, "{\"Alice\", :admin}")
    assert String.contains?(result, "{10, :kg}")
  end

  # =============================================================================
  # ERROR HANDLING & VALIDATION TESTS
  # =============================================================================

  test "input and option validation errors" do
    assert_raise ArgumentError, ~r/expected node_label to be an arity-1 function/, fn ->
      apply(TGF, :options_with, [:invalid, fn _ -> :none end])
    end

    assert_raise ArgumentError, ~r/expected edge_label to be an arity-1 function/, fn ->
      apply(TGF, :options_with, [fn d -> d end, :invalid])
    end

    assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
      apply(TGF, :options_with, [fn d -> d end, fn _ -> :none end, :invalid_opts])
    end

    assert_raise ArgumentError, ~r/unknown option/, fn ->
      TGF.options_with(fn d -> d end, fn _ -> :none end, unknown: true)
    end

    assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
      apply(TGF, :serialize, [:not_a_graph])
    end

    assert_raise ArgumentError, ~r/expected valid options tuple/, fn ->
      apply(TGF, :serialize_with, [:invalid_options, Yog.directed()])
    end

    assert_raise ArgumentError, ~r/Invalid graph type/, fn ->
      apply(TGF, :parse, ["1 Alice\n#\n", :invalid_type])
    end

    assert_raise ArgumentError, ~r/expected input to be a binary string/, fn ->
      apply(TGF, :parse, [123, :directed])
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      apply(TGF, :read, [123, :directed])
    end

    assert_raise ArgumentError, ~r/expected path to be a binary string/, fn ->
      apply(TGF, :write, [123, Yog.directed()])
    end
  end

  test "parse alphanumeric node id" do
    input = """
    abc Alice
    #
    """

    {:ok, {:tgf_result, graph, _}} = TGF.parse(input, :directed)

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
    assert length(warnings) == 1
  end

  test "parse edge with invalid endpoint warning" do
    input = """
    1 A
    #
    1
    """

    {:ok, {:tgf_result, _, warnings}} = TGF.parse(input, :directed)
    assert length(warnings) == 1
    assert elem(hd(warnings), 0) == :malformed_edge
  end

  describe "property tests" do
    property "roundtrip serialize and parse preserves graph node and edge counts" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              graph <-
                if(kind == :directed, do: directed_graph_gen(), else: undirected_graph_gen())
            ) do
        options =
          TGF.options_with(fn data -> Yog.Utils.safe_string(data) end, fn w ->
            {:some, Yog.Utils.safe_string(w)}
          end)

        tgf = TGF.serialize_with(options, graph)

        assert {:ok, {:tgf_result, parsed, _warnings}} =
                 TGF.parse_with(tgf, kind, fn _id, label -> label end, fn label -> label end)

        assert Yog.Model.node_count(parsed) == Yog.Model.node_count(graph)
        assert Yog.Model.edge_count(parsed) == Yog.Model.edge_count(graph)
      end
    end
  end
end
