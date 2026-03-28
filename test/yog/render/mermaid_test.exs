defmodule Yog.Render.MermaidTest do
  use ExUnit.Case

  alias Yog.Render.Mermaid

  doctest Mermaid

  describe "default_options/0" do
    test "returns sensible defaults" do
      opts = Mermaid.default_options()

      assert opts.direction == :td
      assert opts.node_shape == :rounded_rect
      assert opts.highlight_fill == "#ffeb3b"
      assert opts.highlight_stroke == "#f57c00"
      assert is_function(opts.node_label, 2)
      assert is_function(opts.edge_label, 1)
    end
  end

  describe "to_mermaid/2" do
    test "renders directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "End")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "graph TD")
      assert String.contains?(mermaid, "1")
      assert String.contains?(mermaid, "2")
      assert String.contains?(mermaid, "-->")
    end

    test "renders undirected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "1")

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "graph")
      assert String.contains?(mermaid, "---")
      refute String.contains?(mermaid, "-->")
    end

    test "renders graph with multiple nodes and edges" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "Process")
        |> Yog.add_node(3, "End")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "10")
        |> Yog.add_edge_ensure(from: 2, to: 3, with: "5")

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "graph")
      assert String.contains?(mermaid, "1")
      assert String.contains?(mermaid, "2")
      assert String.contains?(mermaid, "3")
    end

    test "applies highlighting" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "End")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")

      opts =
        Map.merge(Mermaid.default_options(), %{
          highlighted_nodes: [1, 2],
          highlighted_edges: [{1, 2}]
        })

      mermaid = Mermaid.to_mermaid(graph, opts)

      assert String.contains?(mermaid, "classDef highlight")
      assert String.contains?(mermaid, ":::highlight")
    end

    test "uses correct direction" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "1")

      # Test left-to-right
      lr_opts = Map.put(Mermaid.default_options(), :direction, :lr)
      lr_mermaid = Mermaid.to_mermaid(graph, lr_opts)
      assert String.contains?(lr_mermaid, "graph LR")

      # Test bottom-to-top
      bt_opts = Map.put(Mermaid.default_options(), :direction, :bt)
      bt_mermaid = Mermaid.to_mermaid(graph, bt_opts)
      assert String.contains?(bt_mermaid, "graph BT")
    end
  end

  describe "path_to_options/2" do
    test "creates highlighted options from path" do
      base_opts = Mermaid.default_options()
      path = %{nodes: [1, 2, 3], weight: 10}

      highlighted = Mermaid.path_to_options(path, base_opts)

      assert highlighted.highlighted_nodes == [1, 2, 3]
      assert highlighted.highlighted_edges == [{1, 2}, {2, 3}]
    end

    test "preserves base options" do
      base_opts = Map.put(Mermaid.default_options(), :direction, :lr)
      path = %{nodes: [1], weight: 0}

      highlighted = Mermaid.path_to_options(path, base_opts)

      assert highlighted.direction == :lr
      assert highlighted.highlighted_nodes == [1]
    end
  end
end
