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
      assert is_function(opts.node_attributes, 2)
      assert is_function(opts.edge_attributes, 3)
    end
  end

  describe "custom formatters" do
    test "default_options_with_edge_formatter/1" do
      opts = Mermaid.default_options_with_edge_formatter(fn w -> "w:#{w}" end)
      assert opts.edge_label.(5) == "w:5"
    end

    test "default_options_with/1" do
      opts =
        Mermaid.default_options_with(
          node_label: fn id, _ -> "n:#{id}" end,
          edge_label: fn w -> "w:#{w}" end
        )

      assert opts.node_label.(1, nil) == "n:1"
      assert opts.edge_label.(5) == "w:5"
    end

    test "default_options_without_labels/0" do
      opts = Mermaid.default_options_without_labels()
      assert opts.edge_label.(5) == ""
      assert opts.edge_label.(nil) == ""
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
      assert String.contains?(mermaid, "linkStyle")
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

    test "renders with subgraphs" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

      opts =
        Map.put(Mermaid.default_options(), :subgraphs, [
          %{
            name: "Group1",
            label: "Cluster 1",
            node_ids: [1, 2]
          }
        ])

      mermaid = Mermaid.to_mermaid(graph, opts)

      assert String.contains?(mermaid, "subgraph Group1")
      assert String.contains?(mermaid, "[\"Cluster 1\"]")
      assert String.contains?(mermaid, "1")
      assert String.contains?(mermaid, "2")
      assert String.contains?(mermaid, "end")
    end

    test "renders with per-element node attributes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.put(Mermaid.default_options(), :node_attributes, fn id, _data ->
          if id == 1, do: [{:fill, "#e1f5fe"}], else: []
        end)

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, "style 1 fill:#e1f5fe")
    end

    test "renders with per-element edge attributes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      opts =
        Map.put(Mermaid.default_options(), :edge_attributes, fn _from, _to, weight ->
          if weight > 5, do: [{:stroke, "#d32f2f"}], else: []
        end)

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, "linkStyle 0")
      assert String.contains?(mermaid, "stroke:#d32f2f")
    end

    test "renders with combined highlight and custom edge attributes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      opts =
        Map.merge(Mermaid.default_options(), %{
          highlighted_edges: [{1, 2}],
          edge_attributes: fn _from, _to, _weight -> [{:stroke_width, "5px"}] end
        })

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, "linkStyle 0")
      assert String.contains?(mermaid, "stroke:#f57c00")
      assert String.contains?(mermaid, "stroke-width:5px")
    end

    test "renders with empty/partial subgraphs" do
      graph = Yog.directed()

      opts =
        Map.put(Mermaid.default_options(), :subgraphs, [
          %{
            name: "EmptyGroup",
            label: nil,
            node_ids: []
          }
        ])

      mermaid = Mermaid.to_mermaid(graph, opts)

      assert String.contains?(mermaid, "subgraph EmptyGroup")
      assert String.contains?(mermaid, "end")
    end

    test "themes return valid options" do
      for theme <- [:default, :dark, :minimal, :presentation] do
        opts = Mermaid.theme(theme)
        assert is_map(opts)
        assert opts.direction == :td
      end
    end

    test "dark theme renders with default class and font color" do
      graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_edge_ensure(1, 2, 1)
      mermaid = Mermaid.to_mermaid(graph, Mermaid.theme(:dark))
      assert String.contains?(mermaid, "classDef default fill:#16213e,stroke:#e94560")
      assert String.contains?(mermaid, "color:#ffffff")
      assert String.contains?(mermaid, "linkStyle 0")
      assert String.contains?(mermaid, "stroke:#e94560")
    end

    test "minimal theme renders thin lines" do
      graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_edge_ensure(1, 2, 1)
      mermaid = Mermaid.to_mermaid(graph, Mermaid.theme(:minimal))
      assert String.contains?(mermaid, "classDef default fill:#ffffff,stroke:#333333")
      assert String.contains?(mermaid, "stroke-width:1px")
    end

    test "presentation theme renders bold strokes" do
      graph = Yog.directed() |> Yog.add_node(1, "A") |> Yog.add_edge_ensure(1, 2, 1)
      mermaid = Mermaid.to_mermaid(graph, Mermaid.theme(:presentation))
      assert String.contains?(mermaid, "classDef default fill:#4361ee,stroke:#f72585")
      assert String.contains?(mermaid, "stroke-width:3px")
    end

    test "per-node shape function renders different shapes" do
      graph =
        Yog.directed()
        |> Yog.add_node(:db, "DB")
        |> Yog.add_node(:api, "API")
        |> Yog.add_edge_ensure(:db, :api, 1)

      opts = %{
        Mermaid.default_options()
        | node_shape: fn id, _ ->
            case id do
              :db -> :cylinder
              :api -> :circle
              _ -> :rounded_rect
            end
          end
      }

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, "db[(\"DB\")]")
      assert String.contains?(mermaid, "api((\"API\"))")
    end

    test "undirected graph with labels uses correct syntax" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(1, 2, "10")

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())
      assert String.contains?(mermaid, "1 -- 10 --- 2")
      refute String.contains?(mermaid, "1 ---|10| 2")
    end

    test "community_to_options generates node attributes" do
      result = %Yog.Community.Result{
        assignments: %{1 => 0, 2 => 0, 3 => 1},
        num_communities: 2,
        metadata: %{modularity: 0.5}
      }

      opts = Mermaid.community_to_options(result)
      assert is_function(opts.node_attributes, 2)

      # Should return fill for known community
      attrs = opts.node_attributes.(1, nil)
      assert Keyword.has_key?(attrs, :fill)
      assert Keyword.get(attrs, :stroke) == "#333333"

      # Should return empty for unknown node
      assert opts.node_attributes.(99, nil) == []
    end

    test "community_to_options handles zero communities" do
      result = %Yog.Community.Result{assignments: %{}, num_communities: 0}
      opts = Mermaid.community_to_options(result)
      assert is_function(opts.node_attributes, 2)
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

      opts = Mermaid.cut_to_options(result)
      assert is_function(opts.node_attributes, 2)

      source_attrs = opts.node_attributes.(1, nil)
      assert Keyword.get(source_attrs, :fill) == "#a8d8ea"

      sink_attrs = opts.node_attributes.(2, nil)
      assert Keyword.get(sink_attrs, :fill) == "#f08080"

      other_attrs = opts.node_attributes.(3, nil)
      assert other_attrs == []
    end

    test "matching_to_options highlights matched edges" do
      matching = %{1 => 2, 2 => 1, 3 => 4, 4 => 3}
      opts = Mermaid.matching_to_options(matching)

      assert opts.highlighted_nodes == [1, 2, 3, 4]
      assert {1, 2} in opts.highlighted_edges
      assert {3, 4} in opts.highlighted_edges
      # Should deduplicate reversed pairs
      assert length(opts.highlighted_edges) == 2

      # Ensure rendering doesn't fail and uses linkStyle
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edges!([{1, 2, 1}, {3, 4, 1}, {2, 1, 1}])

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, "linkStyle")
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

      opts = Mermaid.mst_to_options(result)
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

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, "linkStyle")
      assert String.contains?(mermaid, ":::highlight")
    end
  end

  describe "edge cases" do
    test "renders empty graph" do
      graph = Yog.directed()
      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "graph TD")
      refute String.contains?(mermaid, "-->")
    end

    test "renders graph with empty map node data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, %{})
        |> Yog.add_node(2, %{})
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      # Should fall back to node ID as label
      assert String.contains?(mermaid, "1[\"1\"]")
      assert String.contains?(mermaid, "2[\"2\"]")
      assert String.contains?(mermaid, "-->")
    end

    test "renders graph with nil node data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      # nil to_string gives "", so falls back to node ID
      assert String.contains?(mermaid, "1[\"1\"]")
      assert String.contains?(mermaid, "2[\"2\"]")
    end

    test "renders graph with atom node ids" do
      graph =
        Yog.directed()
        |> Yog.add_node(:start, "Start")
        |> Yog.add_node(:end, "End")
        |> Yog.add_edge_ensure(from: :start, to: :end, with: 5)

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "start")
      assert String.contains?(mermaid, "end")
      assert String.contains?(mermaid, "-->")
    end

    test "renders graph with empty map edge data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: %{})

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      # Empty map edge data should produce no label part
      assert String.contains?(mermaid, "1 --> 2")
    end

    test "renders graph with nil edge data" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: nil)

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "1 --> 2")
    end

    test "escapes quotes in labels" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Say \"hello\"")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "Say \"hi\"")

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "#quot;")
      refute String.contains?(mermaid, "\"Say \"hello\"")
    end

    test "escapes newlines in labels" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Line 1\nLine 2")

      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "<br/>")
      refute String.contains?(mermaid, "\nLine 2")
    end

    test "renders single node without edges" do
      graph = Yog.directed() |> Yog.add_node(1, "Only")
      mermaid = Mermaid.to_mermaid(graph, Mermaid.default_options())

      assert String.contains?(mermaid, "1[\"Only\"]")
      refute String.contains?(mermaid, "-->")
    end

    test "renders all node shapes" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      shapes = [
        :rounded_rect,
        :stadium,
        :subroutine,
        :cylinder,
        :circle,
        :asymmetric,
        :rhombus,
        :hexagon,
        :parallelogram,
        :parallelogram_alt,
        :trapezoid,
        :trapezoid_alt
      ]

      for shape <- shapes do
        opts = Map.put(Mermaid.default_options(), :node_shape, shape)
        mermaid = Mermaid.to_mermaid(graph, opts)
        assert String.contains?(mermaid, "graph TD"), "Shape #{shape} should render"
      end
    end

    test "renders all directions" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      for dir <- [:td, :lr, :bt, :rl] do
        opts = Map.put(Mermaid.default_options(), :direction, dir)
        mermaid = Mermaid.to_mermaid(graph, opts)
        assert String.contains?(mermaid, "graph #{String.upcase(to_string(dir))}")
      end
    end

    test "handles edge highlighting with reversed edge tuple" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.merge(Mermaid.default_options(), %{
          highlighted_edges: [{2, 1}]
        })

      mermaid = Mermaid.to_mermaid(graph, opts)

      # Should match reversed edge tuple for undirected
      assert String.contains?(mermaid, "linkStyle")
    end

    test "handles MapSet in highlighted sets" do
      graph = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      opts =
        Map.merge(Mermaid.default_options(), %{
          highlighted_nodes: MapSet.new([1]),
          highlighted_edges: MapSet.new([{1, 2}])
        })

      mermaid = Mermaid.to_mermaid(graph, opts)
      assert String.contains?(mermaid, ":::highlight")
      assert String.contains?(mermaid, "linkStyle")
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
