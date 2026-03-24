defmodule Yog.IO.ListTest do
  use ExUnit.Case

  alias Yog.IO.List

  doctest Yog.IO.List

  describe "from_list/2" do
    test "creates undirected graph from adjacency list" do
      entries = [
        {1, [{2, 1}, {3, 1}]},
        {2, [{3, 1}]},
        {3, []}
      ]

      graph = List.from_list(:undirected, entries)
      assert Yog.Model.order(graph) == 3
      # Triangle has 3 edges
      assert Yog.Model.edge_count(graph) == 3

      # Check bidirectional edges
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

      # Check directed edges
      assert Yog.has_edge?(graph, 1, 2)
      assert Yog.has_edge?(graph, 1, 3)
      assert Yog.has_edge?(graph, 2, 3)

      # No reverse edges
      refute Yog.has_edge?(graph, 2, 1)
      refute Yog.has_edge?(graph, 3, 1)
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
        # Node 2 is only mentioned as neighbor
      ]

      graph = List.from_list(:undirected, entries)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.edge_count(graph) == 1
    end

    test "empty list creates empty graph" do
      graph = List.from_list(:undirected, [])
      assert Yog.Model.order(graph) == 0
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

      # Check weights
      assert Yog.successors(graph, 1) == [{2, 5}, {3, 10}]
      assert Yog.successors(graph, 2) == [{3, 2}]
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
  end

  describe "to_list/1" do
    test "exports undirected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_edge!(from: 1, to: 2, with: 5)
        |> Yog.add_edge!(from: 2, to: 3, with: 7)

      entries = List.to_list(graph)
      assert entries == [{1, [{2, 5}]}, {2, [{1, 5}, {3, 7}]}, {3, [{2, 7}]}]
    end

    test "exports directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_edge!(from: 1, to: 2, with: 5)
        |> Yog.add_edge!(from: 2, to: 3, with: 7)

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
  end

  describe "to_string/2" do
    test "exports unweighted format" do
      graph =
        Yog.undirected()
        |> Yog.add_edge!(from: 1, to: 2, with: 5)

      str = List.to_string(graph)
      assert str == "1: 2\n2: 1"
    end

    test "exports weighted format" do
      graph =
        Yog.undirected()
        |> Yog.add_edge!(from: 1, to: 2, with: 5)

      str = List.to_string(graph, weighted: true)
      assert str == "1: 2,5\n2: 1,5"
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
        |> Yog.add_edge!(from: 1, to: 2, with: 5)

      str = List.to_string(graph, delimiter: "->")
      assert str == "1-> 2\n2-> 1"
    end
  end

  describe "round-trip conversion" do
    test "preserves structure" do
      original =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge!(from: 1, to: 2, with: 5)
        |> Yog.add_edge!(from: 2, to: 3, with: 7)

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

      # Parse both and compare
      graph2 = List.from_string(:directed, restored_text, weighted: true)

      assert Yog.Model.order(graph) == Yog.Model.order(graph2)
      assert Yog.Model.edge_count(graph) == Yog.Model.edge_count(graph2)
    end
  end

  describe "integration with common formats" do
    test "handles House of Graphs style format" do
      # Common competition format: 0-indexed integers
      text = """
      0: 1 2
      1: 2 3
      2: 3
      3:
      """

      graph = List.from_string(:undirected, text)
      assert Yog.Model.order(graph) == 4
      # 0-1, 0-2, 1-2, 1-3, 2-3 = 5 edges
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
