defmodule Yog.IO.ListTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Yog.IO.List
  import Yog.Generators

  doctest Yog.IO.List

  describe "from_list/2" do
    test "raises on invalid graph type" do
      assert_raise ArgumentError, ~r/Invalid graph type/, fn ->
        apply(List, :from_list, [:invalid, [{1, [{2, 1}]}]])
      end
    end

    test "raises on non-list entries" do
      assert_raise ArgumentError, ~r/expected entries to be a list/, fn ->
        apply(List, :from_list, [:directed, "not a list"])
      end
    end

    test "raises on malformed entry tuple" do
      assert_raise ArgumentError, ~r/expected entry to be a tuple/, fn ->
        List.from_list(:directed, [:invalid_entry])
      end
    end

    test "raises on non-list neighbors" do
      assert_raise ArgumentError, ~r/expected neighbors for node 1 to be a list/, fn ->
        List.from_list(:directed, [{1, :not_a_list}])
      end
    end

    test "raises on invalid neighbor element" do
      assert_raise ArgumentError, ~r/expected neighbor to be a node ID or/, fn ->
        List.from_list(:directed, [{1, [{2, 3, 4}]}])
      end
    end

    test "creates undirected graph from adjacency list" do
      entries = [
        {1, [{2, 1}, {3, 1}]},
        {2, [{3, 1}]},
        {3, []}
      ]

      graph = List.from_list(:undirected, entries)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 3

      assert Yog.has_edge?(graph, 1, 2)
      assert Yog.has_edge?(graph, 2, 1)
      assert Yog.has_edge?(graph, 1, 3)
      assert Yog.has_edge?(graph, 3, 1)
    end

    test "creates directed graph from adjacency list" do
      entries = [
        {1, [{2, 5}, {3, 10}]},
        {2, [{3, 2}]},
        {3, []}
      ]

      graph = List.from_list(:directed, entries)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 3

      assert Yog.has_edge?(graph, 1, 2)
      assert Yog.has_edge?(graph, 1, 3)
      assert Yog.has_edge?(graph, 2, 3)

      refute Yog.has_edge?(graph, 2, 1)
      refute Yog.has_edge?(graph, 3, 1)
    end

    test "supports flexible neighbor tuple formats: {node}, raw node ID" do
      entries = [
        {1, [{2}, 3]},
        {2, []},
        {3, []}
      ]

      graph = List.from_list(:directed, entries)
      assert Yog.Model.order(graph) == 3
      assert Yog.has_edge?(graph, 1, 2)
      assert Yog.has_edge?(graph, 1, 3)
    end

    test "handles isolated nodes" do
      entries = [
        {1, [{2, 1}]},
        {2, []},
        {3, []}
      ]

      graph = List.from_list(:undirected, entries)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 1
    end

    test "handles nodes defined only as neighbors" do
      entries = [
        {1, [{2, 1}]}
      ]

      graph = List.from_list(:undirected, entries)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.edge_count(graph) == 1
    end

    test "empty list creates empty graph" do
      graph = List.from_list(:undirected, [])
      assert Yog.Model.order(graph) == 0
    end

    test "single node graph without edges" do
      graph = List.from_list(:directed, [{1, []}])
      assert Yog.Model.order(graph) == 1
      assert Yog.Model.edge_count(graph) == 0
    end

    test "supports self-loops" do
      entries = [
        {1, [{1, 5}]}
      ]

      graph = List.from_list(:directed, entries)
      assert Yog.Model.order(graph) == 1
      assert Yog.has_edge?(graph, 1, 1)
    end
  end

  describe "from_string/3" do
    test "parses unweighted adjacency list" do
      text = """
      1: 2 3
      2: 3
      3:
      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 3
    end

    test "parses weighted adjacency list" do
      text = """
      1: 2,5 3,10
      2: 3,2
      3:
      """

      graph = List.from_string(:directed, text, weighted: true)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 3

      assert Yog.successors(graph, 1) == [{2, 5}, {3, 10}]
      assert Yog.successors(graph, 2) == [{3, 2}]
    end

    test "handles negative weights and floats" do
      text = """
      1: 2,-5.5 3,10
      2: 3,-2
      """

      graph = List.from_string(:directed, text, weighted: true)
      assert Yog.successors(graph, 1) == [{2, -5.5}, {3, 10}]
      assert Yog.successors(graph, 2) == [{3, -2}]
    end

    test "handles empty lines and whitespace" do
      text = """

      1: 2 3

      2: 3

      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 3
    end

    test "handles comments" do
      text = """
      # This is a comment
      1: 2 3
      2: 3
      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 3
    end

    test "handles nodes with no neighbors" do
      text = """
      1: 2
      2:
      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.edge_count(graph) == 1
    end

    test "custom delimiter" do
      text = """
      1 -> 2
      2 -> 3
      """

      graph = List.from_string(:undirected, text, delimiter: "->")
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 2
    end

    test "options validation errors" do
      assert_raise ArgumentError, ~r/expected string to be a binary/, fn ->
        apply(List, :from_string, [:directed, 123])
      end

      assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
        apply(List, :from_string, [:directed, "1: 2", :invalid])
      end

      assert_raise ArgumentError, ~r/unknown option/, fn ->
        List.from_string(:directed, "1: 2", unknown_opt: true)
      end

      assert_raise ArgumentError, ~r/expected :weighted to be a boolean/, fn ->
        List.from_string(:directed, "1: 2", weighted: "not_a_bool")
      end

      assert_raise ArgumentError, ~r/expected :delimiter to be a non-empty string/, fn ->
        List.from_string(:directed, "1: 2", delimiter: "")
      end
    end

    test "raises on lines with only delimiter" do
      text = "1: 2\n:\n2: 3\n"

      assert_raise ArgumentError, ~r/Node ID cannot be empty/, fn ->
        List.from_string(:undirected, text)
      end
    end

    test "raises on invalid numerical weight" do
      text = "1: 2,abc\n"

      assert_raise ArgumentError, ~r/invalid numerical weight/, fn ->
        List.from_string(:undirected, text, weighted: true)
      end
    end

    test "raises on invalid graph type" do
      assert_raise ArgumentError, ~r/Invalid graph type/, fn ->
        apply(List, :from_string, [:invalid, "1: 2"])
      end
    end

    test "raises on empty node ID" do
      text = " : 2\n"

      assert_raise ArgumentError, ~r/Node ID cannot be empty/, fn ->
        List.from_string(:undirected, text)
      end
    end

    test "handles float weights" do
      text = "1: 2,1.5 3,0.5"
      graph = List.from_string(:directed, text, weighted: true)
      assert Yog.successors(graph, 1) == [{2, 1.5}, {3, 0.5}]
    end

    test "handles mixed weighted/unweighted neighbors when weighted: true" do
      text = "1: 2,5 3"
      graph = List.from_string(:directed, text, weighted: true)
      assert Yog.successors(graph, 1) == [{2, 5}, {3, 1}]
    end

    test "handles lines without delimiter" do
      text = "1\n2\n"
      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.edge_count(graph) == 0
    end
  end

  describe "to_list/1" do
    test "raises on invalid graph input" do
      assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
        List.to_list(:not_a_graph)
      end
    end

    test "exports undirected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)

      entries = List.to_list(graph)
      assert entries == [{1, [{2, 5}]}, {2, [{1, 5}, {3, 7}]}, {3, [{2, 7}]}]
    end

    test "exports directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)

      entries = List.to_list(graph)
      assert entries == [{1, [{2, 5}]}, {2, [{3, 7}]}, {3, []}]
    end

    test "exports isolated nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)

      entries = List.to_list(graph)
      assert entries == [{1, []}, {2, []}]
    end

    test "empty graph returns empty list" do
      graph = Yog.undirected()
      assert List.to_list(graph) == []
    end

    test "exports Yog.DAG struct" do
      g = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      {:ok, dag} = Yog.DAG.from_graph(g)

      entries = List.to_list(dag)
      assert entries == [{1, [{2, 5}]}, {2, []}]
    end
  end

  describe "to_string/2" do
    test "raises on options validation failure" do
      graph = Yog.undirected()

      assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
        apply(List, :to_string, [graph, :invalid_opts])
      end

      assert_raise ArgumentError, ~r/unknown option/, fn ->
        List.to_string(graph, unknown: true)
      end

      assert_raise ArgumentError, ~r/expected :weighted to be a boolean/, fn ->
        List.to_string(graph, weighted: 123)
      end

      assert_raise ArgumentError, ~r/expected :delimiter to be a string/, fn ->
        List.to_string(graph, delimiter: 123)
      end

      assert_raise ArgumentError, ~r/expected :node_formatter to be an arity-1 function/, fn ->
        List.to_string(graph, node_formatter: :invalid)
      end

      assert_raise ArgumentError, ~r/expected :weight_formatter to be an arity-1 function/, fn ->
        List.to_string(graph, weight_formatter: :invalid)
      end
    end

    test "exports unweighted format" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      str = List.to_string(graph)
      assert str == "1: 2\n2: 1"
    end

    test "exports weighted format" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      str = List.to_string(graph, weighted: true)
      assert str == "1: 2,5\n2: 1,5"
    end

    test "exports weighted format with floats and negative weights" do
      graph =
        Yog.directed()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1.5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: -4)

      str = List.to_string(graph, weighted: true)
      assert str == "1: 2,1.5\n2: 3,-4\n3:"
    end

    test "exports nodes with no neighbors" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, nil)

      str = List.to_string(graph)
      assert str == "1:"
    end

    test "custom delimiter" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      str = List.to_string(graph, delimiter: "->")
      assert str == "1-> 2\n2-> 1"
    end

    test "custom formatters for complex types" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_with({1, 2}, {3, 4}, [weight: 10], & &1)

      str =
        List.to_string(graph,
          node_formatter: fn {a, b} -> "#{a}_#{b}" end,
          weight_formatter: fn [weight: w] -> "w#{w}" end,
          weighted: true
        )

      assert str == "1_2: 3_4,w10\n3_4: 1_2,w10"
    end

    test "exports Yog.DAG struct to string" do
      g = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      {:ok, dag} = Yog.DAG.from_graph(g)

      str = List.to_string(dag)
      assert str == "1: 2\n2:"
    end
  end

  describe "round-trip conversion" do
    test "preserves structure" do
      original =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)

      entries = List.to_list(original)
      restored = List.from_list(:undirected, entries)

      assert Yog.Model.order(restored) == Yog.Model.order(original)
      assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(original)
    end

    test "string round-trip preserves structure" do
      original_text = """
      1: 2,5 3,10
      2: 3,7
      3:
      """

      graph = List.from_string(:directed, original_text, weighted: true)
      restored_text = List.to_string(graph, weighted: true)

      graph2 = List.from_string(:directed, restored_text, weighted: true)

      assert Yog.Model.order(graph) == Yog.Model.order(graph2)
      assert Yog.Model.edge_count(graph) == Yog.Model.edge_count(graph2)
    end
  end

  describe "property tests" do
    property "round-trip from_list and to_list preserves graph nodes and edges" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              graph <-
                if(kind == :directed, do: directed_graph_gen(), else: undirected_graph_gen())
            ) do
        entries = List.to_list(graph)
        restored = List.from_list(kind, entries)

        assert Yog.Model.order(restored) == Yog.Model.order(graph)
        assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(graph)
      end
    end

    property "round-trip from_string and to_string preserves graph node and edge counts" do
      check all(
              kind <- StreamData.member_of([:directed, :undirected]),
              graph <-
                if(kind == :directed, do: directed_graph_gen(), else: undirected_graph_gen())
            ) do
        str = List.to_string(graph, weighted: true)
        restored = List.from_string(kind, str, weighted: true)

        assert Yog.Model.order(restored) == Yog.Model.order(graph)
        assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(graph)
      end
    end
  end

  describe "integration with common formats" do
    test "handles House of Graphs style format" do
      text = """
      0: 1 2
      1: 2 3
      2: 3
      3:
      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 4
      assert Yog.Model.edge_count(graph) == 5
    end

    test "handles string node IDs" do
      text = """
      a: b c
      b: c
      c:
      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 3
      assert Yog.has_edge?(graph, "a", "b")
      assert Yog.has_edge?(graph, "a", "c")
    end
  end
end
