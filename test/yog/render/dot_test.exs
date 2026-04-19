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

  describe "edge cases" do
    test "renders empty graph" do
      graph = Yog.directed()
      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "digraph G {")
      assert String.contains?(dot, "}")
    end

    test "renders graph with empty map node data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, %{})
        |> Yog.add_node(2, %{})
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      dot = DOT.to_dot(graph, DOT.default_options())

      # Should fall back to node ID as label
      assert String.contains?(dot, "label=\"1\"")
      assert String.contains?(dot, "label=\"2\"")
    end

    test "renders graph with nil node data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "label=\"1\"")
      assert String.contains?(dot, "label=\"2\"")
    end

    test "renders graph with empty map edge data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: %{})

      dot = DOT.to_dot(graph, DOT.default_options())

      # Empty map edge data should produce empty label
      assert String.contains?(dot, "1 -> 2")
    end

    test "escapes quotes in labels" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Say \"hello\"")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "Say \"hi\"")

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "\\\"hello\\\"")
    end

    test "escapes backslashes in labels" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "C:\\Users\\Alice")

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "C:\\\\Users\\\\Alice")
    end

    test "escapes newlines in labels" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Line 1\nLine 2")

      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "\\n")
    end

    test "renders single node without edges" do
      graph = Yog.directed() |> Yog.add_node(1, "Only")
      dot = DOT.to_dot(graph, DOT.default_options())

      assert String.contains?(dot, "1")
      refute String.contains?(dot, "->")
    end

    test "renders with subgraphs" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

      opts =
        Map.put(DOT.default_options(), :subgraphs, [
          %{
            name: "cluster_0",
            label: "Group 1",
            node_ids: [1, 2],
            style: :filled,
            fillcolor: "lightgrey",
            color: nil
          }
        ])

      dot = DOT.to_dot(graph, opts)

      assert String.contains?(dot, "subgraph cluster_0")
      assert String.contains?(dot, "label=\"Group 1\"")
      assert String.contains?(dot, "style=filled")
      assert String.contains?(dot, "fillcolor=\"lightgrey\"")
    end

    test "renders with rank constraints" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts = Map.put(DOT.default_options(), :ranks, [{:same, [1, 2]}])
      dot = DOT.to_dot(graph, opts)

      assert String.contains?(dot, "{rank=same; 1; 2;}")
    end

    test "themes return valid options" do
      for theme <- [:default, :dark, :minimal, :presentation] do
        opts = DOT.theme(theme)
        assert is_map(opts)
        assert opts.graph_name == "G"
      end
    end

    test "community_to_options generates node attributes" do
      result = %Yog.Community.Result{
        assignments: %{1 => 0, 2 => 0, 3 => 1},
        num_communities: 2,
        metadata: %{modularity: 0.5}
      }

      opts = DOT.community_to_options(result)
      assert is_function(opts.node_attributes, 2)

      # Should return fillcolor for known community
      attrs = opts.node_attributes.(1, nil)
      assert Keyword.has_key?(attrs, :fillcolor)
      assert Keyword.get(attrs, :style) == "filled"

      # Should return empty for unknown node
      assert opts.node_attributes.(99, nil) == []
    end

    test "cut_to_options generates source/sink colors" do
      result = %Yog.Flow.MinCutResult{
        cut_value: 5,
        source_side_size: 1,
        sink_side_size: 1,
        source_side: [1],
        sink_side: [2],
        algorithm: :edmonds_karp
      }

      opts = DOT.cut_to_options(result)
      assert is_function(opts.node_attributes, 2)

      source_attrs = opts.node_attributes.(1, nil)
      assert Keyword.get(source_attrs, :fillcolor) == "#a8d8ea"

      sink_attrs = opts.node_attributes.(2, nil)
      assert Keyword.get(sink_attrs, :fillcolor) == "#f08080"

      other_attrs = opts.node_attributes.(3, nil)
      assert other_attrs == []
    end

    test "matching_to_options highlights matched edges" do
      matching = %{1 => 2, 2 => 1, 3 => 4, 4 => 3}
      opts = DOT.matching_to_options(matching)

      assert opts.highlighted_nodes == [1, 2, 3, 4]
      assert {1, 2} in opts.highlighted_edges
      assert {3, 4} in opts.highlighted_edges
      # Should deduplicate reversed pairs
      assert length(opts.highlighted_edges) == 2
    end

    test "mst_to_options highlights mst edges" do
      result = %Yog.MST.Result{
        edges: [
          %{from: 1, to: 2, weight: 1},
          %{from: 2, to: 3, weight: 2}
        ],
        total_weight: 3,
        node_count: 3,
        edge_count: 2,
        algorithm: :kruskal,
        root: nil
      }

      opts = DOT.mst_to_options(result)
      assert opts.highlighted_nodes == [1, 2, 3]
      assert {1, 2} in opts.highlighted_edges
      assert {2, 3} in opts.highlighted_edges
    end

    test "renders with per-element node attributes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.put(DOT.default_options(), :node_attributes, fn id, _data ->
          if id == 1, do: [{:fillcolor, "green"}], else: []
        end)

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "fillcolor=\"green\"")
    end

    test "renders with per-element edge attributes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      opts =
        Map.put(DOT.default_options(), :edge_attributes, fn _from, _to, weight ->
          if weight > 5, do: [{:color, "red"}], else: []
        end)

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "color=\"red\"")
    end

    test "renders with custom arrow styles" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.merge(DOT.default_options(), %{
          arrowhead: :diamond,
          arrowtail: :dot
        })

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "arrowhead=diamond")
      assert String.contains?(dot, "arrowtail=dot")
    end

    test "renders with custom layout and graph attributes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.merge(DOT.default_options(), %{
          layout: :neato,
          rankdir: :lr,
          bgcolor: "#1a1a2e",
          splines: :curved,
          overlap: false,
          nodesep: 0.5,
          ranksep: 1.0
        })

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "layout=neato")
      assert String.contains?(dot, "rankdir=LR")
      assert String.contains?(dot, "bgcolor=\"#1a1a2e\"")
      assert String.contains?(dot, "splines=curved")
      assert String.contains?(dot, "overlap=false")
      assert String.contains?(dot, "nodesep=0.5")
      assert String.contains?(dot, "ranksep=1.0")
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
