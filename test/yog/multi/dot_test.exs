defmodule Yog.Multi.DOTTest do
  use ExUnit.Case
  alias Yog.Multi.DOT

  describe "default_options/0" do
    test "returns multigraph defaults" do
      opts = DOT.default_options()
      assert opts.graph_name == "G"
      assert opts.node_shape == :ellipse
      assert is_function(opts.node_label, 2)
      assert is_function(opts.edge_label, 2)
    end
  end

  describe "custom formatters" do
    test "default_options_with_edge_formatter/1" do
      opts = DOT.default_options_with_edge_formatter(fn w -> "w:#{w}" end)
      assert opts.edge_label.(:any_id, 5) == "w:5"
    end

    test "default_options_with/1" do
      opts =
        DOT.default_options_with(
          node_label: fn id, _ -> "n:#{id}" end,
          edge_label: fn w -> "w:#{w}" end
        )

      assert opts.node_label.(1, nil) == "n:1"
      assert opts.edge_label.(:any_id, 5) == "w:5"
    end

    test "default_options_without_labels/0" do
      opts = DOT.default_options_without_labels()
      assert opts.edge_label.(:any_id, 5) == ""
      assert opts.edge_label.(:any_id, nil) == ""
    end
  end

  describe "themes" do
    test "all themes return valid options" do
      for theme <- [:default, :dark, :minimal, :presentation] do
        opts = DOT.theme(theme)
        assert is_map(opts)
        assert opts.graph_name == "G"
      end
    end

    test "dark theme renders with dark background" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)
      dot = DOT.to_dot(multi, DOT.theme(:dark))
      assert String.contains?(dot, "bgcolor=\"#1a1a2e\"")
      assert String.contains?(dot, "fillcolor=\"#16213e\"")
    end

    test "minimal theme renders wireframe style" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)
      dot = DOT.to_dot(multi, DOT.theme(:minimal))
      assert String.contains?(dot, "shape=circle")
      assert String.contains?(dot, "style=solid")
    end

    test "presentation theme renders bold style" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)
      dot = DOT.to_dot(multi, DOT.theme(:presentation))
      assert String.contains?(dot, "fontname=\"Helvetica-Bold\"")
      assert String.contains?(dot, "fontsize=18")
    end
  end

  describe "algorithm helpers" do
    test "path_to_options highlights path nodes and edges" do
      path = %{nodes: [1, 2, 3], weight: 10}
      opts = DOT.path_to_options(path)
      assert opts.highlighted_nodes == [1, 2, 3]
      assert opts.highlighted_edges == [{1, 2}, {2, 3}]
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

    test "community_to_options generates node attributes" do
      result = %Yog.Community.Result{
        assignments: %{1 => 0, 2 => 0, 3 => 1},
        num_communities: 2,
        metadata: %{modularity: 0.5}
      }

      opts = DOT.community_to_options(result)
      assert is_function(opts.node_attributes, 2)

      attrs = opts.node_attributes.(1, nil)
      assert Keyword.has_key?(attrs, :fillcolor)
      assert Keyword.get(attrs, :style) == "filled"

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

      assert opts.node_attributes.(3, nil) == []
    end

    test "matching_to_options highlights matched edges" do
      matching = %{1 => 2, 2 => 1, 3 => 4, 4 => 3}
      opts = DOT.matching_to_options(matching)

      assert opts.highlighted_nodes == [1, 2, 3, 4]
      assert {1, 2} in opts.highlighted_edges
      assert {3, 4} in opts.highlighted_edges
      assert length(opts.highlighted_edges) == 2
    end
  end

  describe "to_dot/2" do
    test "renders empty multigraph" do
      multi = Yog.Multi.Graph.new(:directed)
      dot = DOT.to_dot(multi)

      assert String.contains?(dot, "digraph G {")
      assert String.contains?(dot, "}")
    end

    test "renders parallel edges in directed graph" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "Server")
        |> Yog.Multi.add_node(2, "Database")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 5.0)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 15.0)

      dot = DOT.to_dot(multi)

      assert String.contains?(dot, "digraph")
      assert String.contains?(dot, "1 -> 2")
      # It should output multiple edge lines
      edge_lines = String.split(dot, "\n") |> Enum.filter(&String.contains?(&1, "->"))
      assert length(edge_lines) == 2
    end

    test "renders parallel edges in undirected graph without duplication" do
      multi =
        Yog.Multi.undirected()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      dot = DOT.to_dot(multi)

      assert String.contains?(dot, "graph")
      assert String.contains?(dot, "1 -- 2")
      edge_lines = String.split(dot, "\n") |> Enum.filter(&String.contains?(&1, "--"))
      assert length(edge_lines) == 2
    end

    test "supports per-edge configuration via edge_id" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, id1} = Yog.Multi.add_edge(multi, 1, 2, 1.0)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 2.0)

      opts = %{
        DOT.default_options()
        | edge_attributes: fn _u, _v, edge_id, _weight ->
            if edge_id == id1, do: [{:color, "red"}], else: [{:color, "blue"}]
          end,
          edge_label: fn _edge_id, weight -> "id:#{weight}" end
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "color=\"red\"")
      assert String.contains?(dot, "color=\"blue\"")
      assert String.contains?(dot, "label=\"id:1.0\"")
      assert String.contains?(dot, "label=\"id:2.0\"")
    end

    test "highlights specific multigraph edge by edge_id" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      opts = %{DOT.default_options() | highlighted_edges: [id1]}

      dot = DOT.to_dot(multi, opts)
      # One line should have highlight styling (red by default), the other standard
      assert String.contains?(dot, "color=\"red\"")
      assert String.contains?(dot, "color=\"black\"")
    end

    test "renders with subgraphs and styling" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")
        |> Yog.Multi.add_node(3, "C")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1.0)
      {multi, _} = Yog.Multi.add_edge(multi, 2, 3, 1.0)

      opts = %{
        DOT.default_options()
        | subgraphs: [
            %{
              name: "cluster_0",
              label: "SubGroup",
              node_ids: [1, 2],
              style: :filled,
              fillcolor: "yellow",
              color: "black"
            }
          ]
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "subgraph cluster_0")
      assert String.contains?(dot, "label=\"SubGroup\"")
      assert String.contains?(dot, "style=filled")
      assert String.contains?(dot, "fillcolor=\"yellow\"")
    end

    test "renders large complex multigraph for Livebook visual inspection" do
      # Create a large mock system architecture graph
      multi =
        Yog.Multi.directed()
        # Core microservices
        |> Yog.Multi.add_node("API", %{type: :service, desc: "Gateway API"})
        |> Yog.Multi.add_node("Auth", %{type: :service, desc: "Auth Service"})
        |> Yog.Multi.add_node("UserDB", %{type: :db, desc: "PostgreSQL"})
        |> Yog.Multi.add_node("Payment", %{type: :service, desc: "Stripe Integration"})
        |> Yog.Multi.add_node("Cache", %{type: :infra, desc: "Redis"})
        |> Yog.Multi.add_node("Analytics", %{type: :service, desc: "Data Pipeline"})

      # Establish parallel flows
      # API <-> Auth traffic
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Auth", "Auth Check (REST)")
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Auth", "Token Refresh (gRPC)")

      # Auth <-> DB connections
      {multi, _} = Yog.Multi.add_edge(multi, "Auth", "UserDB", "Read (SQL)")
      {multi, _} = Yog.Multi.add_edge(multi, "Auth", "UserDB", "Update Session (SQL)")

      # Payment pipeline
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Payment", "Process Charge")
      {multi, _} = Yog.Multi.add_edge(multi, "Payment", "Cache", "Idempotency Lock")
      {multi, _} = Yog.Multi.add_edge(multi, "Payment", "Analytics", "Metric emission")

      # Custom large styling options suitable for direct Livebook copy
      opts = %{
        DOT.default_options()
        | graph_name: "SystemDesign",
          layout: :dot,
          rankdir: :lr,
          bgcolor: "#1e1e24",
          node_shape: :box,
          node_fontname: "Helvetica-Bold",
          node_fontsize: 14,
          node_fontcolor: "#ffffff",
          edge_fontname: "Courier",
          node_attributes: fn _id, data ->
            case Map.get(data || %{}, :type) do
              :service -> [{:fillcolor, "#4a90e2"}, {:style, "filled,rounded"}]
              :db -> [{:fillcolor, "#50e3c2"}, {:style, "filled,box"}, {:shape, "cylinder"}]
              :infra -> [{:fillcolor, "#f5a623"}, {:style, "filled"}]
              _ -> []
            end
          end,
          edge_attributes: fn _from, _to, _edge_id, weight ->
            case weight do
              w when is_binary(w) -> [{:label, w}, {:color, "#8b949e"}]
              _ -> []
            end
          end,
          subgraphs: [
            %{
              name: "cluster_security",
              label: "Security Domain",
              node_ids: ["Auth", "UserDB"],
              style: :dashed,
              fillcolor: nil,
              color: "#ff4d4f"
            }
          ]
      }

      dot = DOT.to_dot(multi, opts)

      assert String.contains?(dot, "digraph SystemDesign")
      assert String.contains?(dot, "API -> Auth")
      assert String.contains?(dot, "Auth -> UserDB")
      assert String.contains?(dot, "shape=\"cylinder\"")
      assert String.contains?(dot, "fillcolor=\"#4a90e2\"")
      assert String.contains?(dot, "Token Refresh")
    end
  end

  describe "attribute mapping and escaping" do
    test "renders various node shapes" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")

      shapes = [
        :cylinder,
        :doublecircle,
        :diamond,
        :hexagon,
        :note,
        :box3d,
        :component,
        :folder,
        :invtriangle
      ]

      for shape <- shapes do
        opts = %{DOT.default_options() | node_shape: shape}
        dot = DOT.to_dot(multi, opts)
        assert String.contains?(dot, "shape=#{shape}")
      end
    end

    test "renders custom node shape and layout" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")

      opts = %{
        DOT.default_options()
        | node_shape: {:custom, "myshape"},
          layout: {:custom, "mylayout"}
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "shape=myshape")
      assert String.contains?(dot, "layout=mylayout")
    end

    test "renders various arrow styles" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(2, "B")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)

      styles = [:dot, :diamond, :box, :crow, :vee, :tee, :odiamond, :inv, :none]

      for style <- styles do
        opts = %{DOT.default_options() | arrowhead: style, arrowtail: style}
        dot = DOT.to_dot(multi, opts)
        assert String.contains?(dot, "arrowhead=#{style}")
        assert String.contains?(dot, "arrowtail=#{style}")
      end
    end

    test "renders various overlap and spline modes" do
      multi = Yog.Multi.directed()

      for overlap <- [true, false, :scale, :scalexy, :prism] do
        opts = %{DOT.default_options() | overlap: overlap}
        dot = DOT.to_dot(multi, opts)

        expected =
          case overlap do
            true -> "overlap=true"
            false -> "overlap=false"
            :scale -> "overlap=scale"
            :scalexy -> "overlap=scalexy"
            :prism -> "overlap=prism"
          end

        assert String.contains?(dot, expected)
      end

      for spline <- [:line, :polyline, :curved, :ortho, :spline, :none] do
        opts = %{DOT.default_options() | splines: spline}
        dot = DOT.to_dot(multi, opts)
        assert String.contains?(dot, "splines=#{spline}")
      end
    end

    test "renders graph attributes" do
      multi = Yog.Multi.directed()

      opts = %{
        DOT.default_options()
        | layout: :neato,
          rankdir: :lr,
          splines: :ortho,
          overlap: false,
          nodesep: 0.5,
          ranksep: 1.2
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "layout=neato")
      assert String.contains?(dot, "rankdir=LR")
      assert String.contains?(dot, "splines=ortho")
      assert String.contains?(dot, "overlap=false")
      assert String.contains?(dot, "nodesep=0.5")
      assert String.contains?(dot, "ranksep=1.2")
    end

    test "escapes special characters in labels" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "Line1\nLine2")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 1, "Quote \" and backslash \\")

      dot = DOT.to_dot(multi)
      assert String.contains?(dot, "label=\"Line1\\nLine2\"")
      assert String.contains?(dot, "label=\"Quote \\\" and backslash \\\\\"")
    end

    test "merge_attributes_list overrides defaults" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      # Override label via node_attributes callback
      opts = %{DOT.default_options() | node_attributes: fn _, _ -> [{:label, "OVERRIDDEN"}] end}
      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "label=\"OVERRIDDEN\"")
      refute String.contains?(dot, "label=\"A\"")
    end
  end

  describe "cut_to_options/2" do
    test "colors source and sink sides" do
      result = %Yog.Flow.MinCutResult{
        cut_value: 10,
        source_side_size: 2,
        sink_side_size: 3,
        source_side: MapSet.new([1, 2]),
        sink_side: MapSet.new([3, 4, 5]),
        algorithm: :stoer_wagner
      }

      opts = DOT.cut_to_options(result)
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(3, "B")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 3, 1)

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "fillcolor=\"#a8d8ea\"")
      assert String.contains?(dot, "fillcolor=\"#f08080\"")
    end
  end

  describe "subgraphs" do
    test "renders nested subgraphs" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(2, "B")
      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)

      opts = %{
        DOT.default_options()
        | subgraphs: [
            %{
              name: "cluster_outer",
              label: "Outer",
              node_ids: [1],
              style: :dashed,
              fillcolor: "#eeeeee",
              color: "#333333",
              subgraphs: [
                %{
                  name: "cluster_inner",
                  label: "Inner",
                  node_ids: [2],
                  style: :solid,
                  fillcolor: "#cccccc",
                  color: nil
                }
              ]
            }
          ]
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "subgraph cluster_outer")
      assert String.contains?(dot, "subgraph cluster_inner")
      assert String.contains?(dot, "label=\"Outer\"")
      assert String.contains?(dot, "label=\"Inner\"")
    end

    test "renders subgraph with nil node_ids" do
      multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")

      opts = %{
        DOT.default_options()
        | subgraphs: [
            %{
              name: "cluster_empty",
              label: "Empty",
              node_ids: nil,
              style: nil,
              fillcolor: nil,
              color: nil
            }
          ]
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "subgraph cluster_empty")
      assert String.contains?(dot, "label=\"Empty\"")
    end
  end

  describe "undirected edge highlighting" do
    test "highlights reversed edge tuple in undirected graph" do
      multi = Yog.Multi.undirected() |> Yog.Multi.add_node(1, "A") |> Yog.Multi.add_node(2, "B")
      {multi, _eid} = Yog.Multi.add_edge(multi, 1, 2, 5)

      opts = %{
        DOT.default_options()
        | highlighted_edges: [{2, 1}]
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "penwidth=\"2.0\"")
      assert String.contains?(dot, "color=\"red\"")
    end
  end
end
