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

  describe "custom formatters" do
    test "default_options_with_edge_formatter/1" do
      opts = DOT.default_options_with_edge_formatter(fn w -> "w:#{w}" end)
      assert opts.edge_label.(5) == "w:5"
    end

    test "default_options_with/1" do
      opts =
        DOT.default_options_with(
          node_label: fn id, _ -> "n:#{id}" end,
          edge_label: fn w -> "w:#{w}" end
        )

      assert opts.node_label.(1, nil) == "n:1"
      assert opts.edge_label.(5) == "w:5"
    end

    test "default_options_without_labels/0" do
      opts = DOT.default_options_without_labels()
      assert opts.edge_label.(5) == ""
      assert opts.edge_label.(nil) == ""
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

    test "renders with empty/partial subgraphs" do
      graph = Yog.directed()

      opts =
        Map.put(DOT.default_options(), :subgraphs, [
          %{
            name: "cluster_1",
            label: nil,
            node_ids: [],
            style: nil,
            fillcolor: nil,
            color: "blue"
          }
        ])

      dot = DOT.to_dot(graph, opts)

      assert String.contains?(dot, "subgraph cluster_1")
      assert String.contains?(dot, "color=\"blue\"")
      refute String.contains?(dot, "    label=")
      refute String.contains?(dot, "    style=")
      refute String.contains?(dot, "    fillcolor=")
    end

    test "renders nested subgraphs" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

      opts =
        Map.put(DOT.default_options(), :subgraphs, [
          %{
            name: "cluster_vpc",
            label: "VPC",
            node_ids: nil,
            style: :filled,
            fillcolor: "lightgrey",
            color: nil,
            subgraphs: [
              %{
                name: "cluster_az1",
                label: "AZ-1",
                node_ids: [1, 2],
                style: nil,
                fillcolor: nil,
                color: nil,
                subgraphs: nil
              },
              %{
                name: "cluster_az2",
                label: "AZ-2",
                node_ids: [3],
                style: nil,
                fillcolor: nil,
                color: nil,
                subgraphs: nil
              }
            ]
          }
        ])

      dot = DOT.to_dot(graph, opts)

      assert String.contains?(dot, "subgraph cluster_vpc")
      assert String.contains?(dot, "subgraph cluster_az1")
      assert String.contains?(dot, "subgraph cluster_az2")
      assert String.contains?(dot, "label=\"VPC\"")
      assert String.contains?(dot, "label=\"AZ-1\"")
      assert String.contains?(dot, "label=\"AZ-2\"")
      # Nested subgraphs should be indented inside their parent
      assert Regex.match?(~r/subgraph cluster_vpc \{[\s\S]*?  subgraph cluster_az1 \{/m, dot)
      assert Regex.match?(~r/subgraph cluster_vpc \{[\s\S]*?  subgraph cluster_az2 \{/m, dot)
    end

    test "renders with invalid graph fallback" do
      # Testing fallback behavior when graph is missing nodes, out_edges, or kind
      dot = DOT.to_dot(%{}, DOT.default_options())
      # default kind
      assert String.contains?(dot, "digraph")
      # no nodes/edges
      assert String.contains?(dot, "}")
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

    test "dark theme renders with dark background" do
      graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_edge_ensure(1, 2, 1)
      dot = DOT.to_dot(graph, DOT.theme(:dark))
      assert String.contains?(dot, "bgcolor=\"#1a1a2e\"")
      assert String.contains?(dot, "fillcolor=\"#16213e\"")
      assert String.contains?(dot, "fontcolor=\"#e0e0e0\"")
    end

    test "minimal theme renders wireframe style" do
      graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_edge_ensure(1, 2, 1)
      dot = DOT.to_dot(graph, DOT.theme(:minimal))
      assert String.contains?(dot, "shape=circle")
      assert String.contains?(dot, "style=solid")
      assert String.contains?(dot, "penwidth=0.5")
    end

    test "presentation theme renders bold style" do
      graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_edge_ensure(1, 2, 1)
      dot = DOT.to_dot(graph, DOT.theme(:presentation))
      assert String.contains?(dot, "fontname=\"Helvetica-Bold\"")
      assert String.contains?(dot, "fontsize=18")
      assert String.contains?(dot, "penwidth=2.0")
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

    test "community_to_options handles zero communities" do
      result = %Yog.Community.Result{assignments: %{}, num_communities: 0}
      opts = DOT.community_to_options(result)
      assert is_function(opts.node_attributes, 2)
    end

    test "community_to_options covers all palette hues" do
      # Generating 7 communities produces hues that cover all branches in hsl_to_hex
      result = %Yog.Community.Result{
        assignments: Map.new(1..7, fn i -> {i, i} end),
        num_communities: 7
      }

      opts = DOT.community_to_options(result)

      # Just evaluate the function to ensure no crashes
      for i <- 1..7 do
        assert Keyword.has_key?(opts.node_attributes.(i, nil), :fillcolor)
      end
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

      # Ensure rendering doesn't fail and uses the list
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edges!([{1, 2, 1}, {3, 4, 1}, {2, 1, 1}])

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "color=\"red\"")
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

      # Ensure rendering works
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "color=\"red\"")
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

      opts_head_only = Map.put(DOT.default_options(), :arrowhead, :vee)
      dot_head = DOT.to_dot(graph, opts_head_only)
      assert String.contains?(dot_head, "arrowhead=vee")
      refute String.contains?(dot_head, "arrowtail=")

      opts_tail_only = Map.put(DOT.default_options(), :arrowtail, :inv)
      dot_tail = DOT.to_dot(graph, opts_tail_only)
      assert String.contains?(dot_tail, "arrowtail=inv")
      refute String.contains?(dot_tail, "arrowhead=")
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

    test "handles MapSet in highlighted sets" do
      graph = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.merge(DOT.default_options(), %{
          highlighted_nodes: MapSet.new([1]),
          highlighted_edges: MapSet.new([{1, 2}])
        })

      dot = DOT.to_dot(graph, opts)
      assert String.contains?(dot, "color=\"red\"")
    end
  end

  describe "path_to_options/2" do
    test "highlights path nodes and edges" do
      base_opts = DOT.default_options()
      path = %{nodes: [1, 2, 3], weight: 10}

      highlighted = DOT.path_to_options(path, base_opts)

      assert highlighted.highlighted_nodes == [1, 2, 3]
      assert highlighted.highlighted_edges == [{1, 2}, {2, 3}]

      # Render the graph, also include a reverse edge to hit the other side of the lookup logic
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 2, 1}])

      dot = DOT.to_dot(graph, highlighted)
      assert String.contains?(dot, "color=\"red\"")
    end

    test "preserves other options" do
      base_opts = Map.put(DOT.default_options(), :graph_name, "TestGraph")
      path = %{nodes: [1], weight: 0}

      highlighted = DOT.path_to_options(path, base_opts)

      assert highlighted.graph_name == "TestGraph"
      assert highlighted.highlighted_nodes == [1]
      assert highlighted.highlighted_edges == []
    end

    test "handles empty and single-node paths" do
      base_opts = DOT.default_options()

      empty_opts = DOT.path_to_options(%{nodes: []}, base_opts)
      assert empty_opts.highlighted_edges == []

      single_opts = DOT.path_to_options(%{nodes: [1]}, base_opts)
      assert single_opts.highlighted_edges == []
    end
  end

  describe "string conversions" do
    test "covers all layout options" do
      for layout <- [:dot, :neato, :circo, :fdp, :sfdp, :twopi, :osage, {:custom, "my_layout"}] do
        opts = Map.put(DOT.default_options(), :layout, layout)
        dot = DOT.to_dot(Yog.directed(), opts)
        expected = if is_tuple(layout), do: elem(layout, 1), else: to_string(layout)
        assert String.contains?(dot, "layout=#{expected}")
      end
    end

    test "covers all rankdir options" do
      for rankdir <- [:tb, :lr, :bt, :rl] do
        opts = Map.put(DOT.default_options(), :rankdir, rankdir)
        dot = DOT.to_dot(Yog.directed(), opts)
        assert String.contains?(dot, "rankdir=#{String.upcase(to_string(rankdir))}")
      end
    end

    test "covers all node_shape options" do
      shapes = [
        :box,
        :box3d,
        :circle,
        :cloud,
        :component,
        :cylinder,
        :diamond,
        :doublecircle,
        :ellipse,
        :folder,
        :hexagon,
        :house,
        :invhouse,
        :invtriangle,
        :note,
        :octagon,
        :parallelogram,
        :pentagon,
        :plain,
        :plaintext,
        :point,
        :rect,
        :rectangle,
        :square,
        :tab,
        :trapezoid,
        :triangle,
        :underline,
        {:custom, "my_shape"}
      ]

      for shape <- shapes do
        opts = Map.put(DOT.default_options(), :node_shape, shape)
        dot = DOT.to_dot(Yog.directed() |> Yog.add_node(1, "A"), opts)
        expected = if is_tuple(shape), do: elem(shape, 1), else: to_string(shape)
        assert String.contains?(dot, "shape=#{expected}")
      end
    end

    test "covers all style options" do
      styles = [:solid, :dashed, :dotted, :bold, :filled, :rounded, :diagonals, :striped, :wedged]

      for style <- styles do
        opts = Map.put(DOT.default_options(), :node_style, style)
        dot = DOT.to_dot(Yog.directed() |> Yog.add_node(1, "A"), opts)
        assert String.contains?(dot, "style=#{style}")
      end
    end

    test "covers all splines options" do
      splines = [:line, :polyline, :curved, :ortho, :spline, :none]

      for spline <- splines do
        opts = Map.put(DOT.default_options(), :splines, spline)
        dot = DOT.to_dot(Yog.directed(), opts)
        assert String.contains?(dot, "splines=#{spline}")
      end
    end

    test "covers all arrow_style options" do
      arrows = [
        :normal,
        :dot,
        :diamond,
        :odiamond,
        :box,
        :crow,
        :vee,
        :inv,
        :tee,
        :none,
        {:custom, "my_arrow"}
      ]

      for arrow <- arrows do
        opts = Map.merge(DOT.default_options(), %{arrowhead: arrow, arrowtail: arrow})
        dot = DOT.to_dot(Yog.directed(), opts)
        expected = if is_tuple(arrow), do: elem(arrow, 1), else: to_string(arrow)
        assert String.contains?(dot, "arrowhead=#{expected}")
        assert String.contains?(dot, "arrowtail=#{expected}")
      end
    end

    test "covers all overlap options" do
      overlaps = [true, false, :scale, :scalexy, :prism, {:custom, "my_overlap"}]

      for overlap <- overlaps do
        opts = Map.put(DOT.default_options(), :overlap, overlap)
        dot = DOT.to_dot(Yog.directed(), opts)
        expected = if is_tuple(overlap), do: elem(overlap, 1), else: to_string(overlap)
        assert String.contains?(dot, "overlap=#{expected}")
      end
    end
  end
end
