defmodule Yog.Render.DOTTest do
  use ExUnit.Case

  alias Yog.Render.DOT

  doctest DOT

  describe "default_options/0" do
    test "returns sensible defaults" do
      opts = DOT.default_options()

      assert opts.graph_name == "G"
      assert opts.node_shape == :ellipse
      assert opts.node_color == "lightblue"
      assert opts.node_style == :filled
      assert opts.edge_color == "black"
      assert opts.highlight_color == "red"
      assert is_function(opts.node_label, 2)
      assert is_function(opts.edge_label, 1)
    end
  end

  describe "to_dot/2" do
    test "renders directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "End")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "digraph G {")
      assert String.contains?(dot, "}")
      assert String.contains?(dot, "1")
      assert String.contains?(dot, "2")
      assert String.contains?(dot, "->")
    end

    test "renders undirected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "1")

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "graph G {")
      assert String.contains?(dot, "--")
    end

    test "renders graph with multiple nodes and edges" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "Process")
        |> Yog.add_node(3, "End")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "10")
        |> Yog.add_edge_ensure(from: 2, to: 3, with: "5")

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "digraph")
      assert String.contains?(dot, "1")
      assert String.contains?(dot, "2")
      assert String.contains?(dot, "3")
    end

    test "applies custom options" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Node 1")
        |> Yog.add_node(2, "Node 2")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "1")

      opts =
        Map.merge(DOT.default_options(), %{
          graph_name: "MyGraph",
          node_shape: :box,
          node_color: "green"
        })

      dot = DOT.to_dot(graph, opts)

      assert String.contains?(dot, "digraph MyGraph {")
      assert String.contains?(dot, "shape=box")
      assert String.contains?(dot, "fillcolor=\"green\"")
    end
  end

  describe "path_to_options/2" do
    test "highlights path nodes and edges" do
      base_opts = DOT.default_options()
      path = %{nodes: [1, 2, 3], weight: 10}

      highlighted = DOT.path_to_options(path, base_opts)

      assert highlighted.highlighted_nodes == [1, 2, 3]
      assert highlighted.highlighted_edges == [{1, 2}, {2, 3}]
    end

    test "preserves other options" do
      base_opts = Map.put(DOT.default_options(), :graph_name, "TestGraph")
      path = %{nodes: [1], weight: 0}

      highlighted = DOT.path_to_options(path, base_opts)

      assert highlighted.graph_name == "TestGraph"
      assert highlighted.highlighted_nodes == [1]
      assert highlighted.highlighted_edges == []
    end
  end
end
