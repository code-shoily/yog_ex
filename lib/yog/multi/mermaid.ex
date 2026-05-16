defmodule Yog.Multi.Mermaid do
  alias Yog.Render.Mermaid

  @moduledoc """
  Mermaid.js format export for visualizing multigraphs.

  This module exports multigraphs (graphs with support for parallel edges)
  to Mermaid syntax. It mirrors the capabilities of `Yog.Render.Mermaid`
  but adapts the edge configurations to account for multiple relationships.

  ## Per-Edge Customization

  Because multiple edges can exist between the same nodes, callback functions
  pass the unique `edge_id`:

      options = %{
        Yog.Multi.Mermaid.default_options() |
        edge_attributes: fn from, to, edge_id, weight ->
          if edge_id == 5 do
            [{:stroke, "#d32f2f"}, {:stroke_width, "3px"}]
          else
            []
          end
        end
      }

  ## Subgraphs

  Group nodes visually using subgraphs:

      options = %{
        Yog.Multi.Mermaid.default_options() |
        subgraphs: [
          %{
            name: "Group A",
            label: "Cluster A",
            node_ids: [1, 2, 3]
          }
        ]
      }
  """

  # =============================================================================
  # TYPES
  # =============================================================================

  @typedoc "Direction for graph layout"
  @type direction ::
          :td
          | :lr
          | :bt
          | :rl

  @typedoc """
  Node shape options for Mermaid diagrams.

  See `Yog.Render.Mermaid` for the full list of shapes.
  """
  @type node_shape ::
          :rounded_rect
          | :stadium
          | :subroutine
          | :cylinder
          | :circle
          | :asymmetric
          | :rhombus
          | :hexagon
          | :parallelogram
          | :parallelogram_alt
          | :trapezoid
          | :trapezoid_alt

  @typedoc "CSS length unit for styling."
  @type css_length ::
          {:px, integer()}
          | {:em, float()}
          | {:rem, float()}
          | {:percent, float()}
          | {:custom, String.t()}

  @typedoc "A subgraph for grouping nodes visually in the diagram."
  @type subgraph :: %{
          name: String.t(),
          label: String.t() | nil,
          node_ids: [Yog.Model.node_id()] | nil
        }

  @typedoc "Options for customizing multigraph Mermaid rendering"
  @type options :: %{
          node_label: (Yog.Model.node_id(), any() -> String.t()),
          edge_label: (Yog.Multi.Graph.edge_id(), any() -> String.t()),
          highlighted_nodes: [Yog.Model.node_id()] | nil,
          highlighted_edges:
            [Yog.Multi.Graph.edge_id() | {Yog.Model.node_id(), Yog.Model.node_id()}] | nil,
          # Per-element styling
          node_attributes: (Yog.Model.node_id(), any() -> [{atom(), String.t()}]),
          edge_attributes: (Yog.Model.node_id(),
                            Yog.Model.node_id(),
                            Yog.Multi.Graph.edge_id(),
                            any() ->
                              [{atom(), String.t()}]),
          # Subgraphs
          subgraphs: [subgraph()] | nil,
          # Graph-level attributes
          direction: direction(),
          # Node styling
          node_shape: node_shape(),
          # Default styling (applied to all nodes/edges)
          default_fill: String.t() | nil,
          default_stroke: String.t() | nil,
          default_stroke_width: css_length() | nil,
          default_font_color: String.t() | nil,
          default_link_stroke: String.t() | nil,
          # Highlight styling (applied to selected nodes/edges)
          highlight_fill: String.t(),
          highlight_stroke: String.t(),
          highlight_stroke_width: css_length(),
          # Edge styling
          link_thickness: css_length(),
          highlight_link_stroke: String.t(),
          highlight_link_stroke_width: css_length()
        }

  @doc """
  Creates default Mermaid options with multigraph labeling capabilities.
  """
  @spec default_options() :: options()
  def default_options do
    %{
      node_label: &Yog.Utils.to_label/2,
      edge_label: fn _id, weight -> Yog.Utils.to_weight_label(weight) end,
      highlighted_nodes: nil,
      highlighted_edges: nil,
      # Per-element styling defaults
      node_attributes: fn _, _ -> [] end,
      edge_attributes: fn _, _, _, _ -> [] end,
      # Subgraphs
      subgraphs: nil,
      # Graph-level
      direction: :td,
      # Node styling
      node_shape: :rounded_rect,
      # Default styling
      default_fill: nil,
      default_stroke: nil,
      default_stroke_width: nil,
      default_font_color: nil,
      default_link_stroke: nil,
      # Highlight styling
      highlight_fill: "#ffeb3b",
      highlight_stroke: "#f57c00",
      highlight_stroke_width: {:px, 3},
      # Edge styling
      link_thickness: {:px, 2},
      highlight_link_stroke: "#f57c00",
      highlight_link_stroke_width: {:px, 3}
    }
  end

  @doc """
  Returns a pre-configured theme as Mermaid options for multigraphs.

  Available themes:
  - `:default` — Yellow highlight, orange stroke (same as `default_options/0`)
  - `:dark` — Dark-friendly colors with neon accent colors
  - `:minimal` — Clean wireframe look with no fills and thin lines
  - `:presentation` — Large strokes and bold colors for slides and demos
  """
  @spec theme(atom()) :: options()
  def theme(:default), do: default_options()

  def theme(:dark) do
    %{
      default_options()
      | default_fill: "#16213e",
        default_stroke: "#e94560",
        default_stroke_width: {:px, 2},
        default_font_color: "#ffffff",
        default_link_stroke: "#e94560",
        highlight_fill: "#16213e",
        highlight_stroke: "#e94560",
        highlight_stroke_width: {:px, 3},
        link_thickness: {:px, 2},
        highlight_link_stroke: "#e94560",
        highlight_link_stroke_width: {:px, 3}
    }
  end

  def theme(:minimal) do
    %{
      default_options()
      | default_fill: "#ffffff",
        default_stroke: "#333333",
        default_stroke_width: {:px, 1},
        default_font_color: "#333333",
        default_link_stroke: "#333333",
        highlight_fill: "#ffffff",
        highlight_stroke: "#333333",
        highlight_stroke_width: {:px, 1},
        link_thickness: {:px, 1},
        highlight_link_stroke: "#333333",
        highlight_link_stroke_width: {:px, 2}
    }
  end

  def theme(:presentation) do
    %{
      default_options()
      | default_fill: "#4361ee",
        default_stroke: "#f72585",
        default_stroke_width: {:px, 3},
        default_font_color: "#ffffff",
        default_link_stroke: "#f72585",
        highlight_fill: "#4361ee",
        highlight_stroke: "#f72585",
        highlight_stroke_width: {:px, 4},
        link_thickness: {:px, 3},
        highlight_link_stroke: "#f72585",
        highlight_link_stroke_width: {:px, 4}
    }
  end

  @doc """
  Converts a multigraph (`Yog.Multi.Graph`) to Mermaid syntax.
  """
  @spec to_mermaid(Yog.Multi.Graph.t(), options()) :: String.t()
  def to_mermaid(graph, options \\ default_options()) do
    nodes = Map.get(graph, :nodes, %{})
    edges = Map.get(graph, :edges, %{})
    kind = Map.get(graph, :kind, :directed)

    # Graph type and direction
    graph_type = "graph #{Mermaid.direction_to_string(options.direction)}\n"

    # Style definitions for highlighting
    styles =
      if options.highlighted_nodes || options.highlighted_edges do
        node_highlight =
          "  classDef highlight fill:#{options.highlight_fill},stroke:#{options.highlight_stroke},stroke-width:#{Mermaid.css_length_to_string(options.highlight_stroke_width)}\n"

        edge_highlight =
          "  classDef highlightEdge stroke:#{options.highlight_link_stroke},stroke-width:#{Mermaid.css_length_to_string(options.highlight_link_stroke_width)}\n"

        node_highlight <> edge_highlight
      else
        ""
      end

    # Default class definition for theming (applies to all nodes automatically)
    default_class_parts =
      [
        if(options.default_fill, do: "fill:#{options.default_fill}"),
        if(options.default_stroke, do: "stroke:#{options.default_stroke}"),
        if(options.default_stroke_width,
          do: "stroke-width:#{Mermaid.css_length_to_string(options.default_stroke_width)}"
        ),
        if(options.default_font_color, do: "color:#{options.default_font_color}")
      ]
      |> Enum.reject(&is_nil/1)

    default_class =
      if default_class_parts != [] do
        "  classDef default #{Enum.join(default_class_parts, ",")}\n"
      else
        ""
      end

    # Convert highlight lists to MapSets for O(1) membership checks
    hl_nodes = to_mapset(options.highlighted_nodes)
    hl_edges = to_mapset(options.highlighted_edges)
    options = %{options | highlighted_nodes: hl_nodes, highlighted_edges: hl_edges}

    # Generate node declarations
    nodes_str = build_node_lines(nodes, options)

    # Generate per-node style lines
    node_styles_str = build_node_styles(nodes, options)

    # Generate subgraphs
    subgraphs_str = build_subgraphs(options.subgraphs)

    # Generate edge declarations
    {edges_str, link_styles} = build_edge_lines(edges, options, kind)

    # Combine edge styles
    edge_styles_str = build_link_styles(link_styles)

    parts = [
      graph_type,
      styles,
      default_class,
      nodes_str,
      if(node_styles_str != "", do: "\n" <> node_styles_str, else: ""),
      if(subgraphs_str != "", do: "\n" <> subgraphs_str, else: ""),
      if(edges_str != "", do: "\n" <> edges_str, else: ""),
      if(edge_styles_str != "", do: "\n" <> edge_styles_str, else: "")
    ]

    parts
    |> Enum.join("")
    |> String.trim_trailing("\n")
    |> Kernel.<>("\n")
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  defp to_mapset(nil), do: nil
  defp to_mapset(list) when is_list(list), do: MapSet.new(list)
  defp to_mapset(%MapSet{} = set), do: set

  defp build_node_lines(nodes, options) do
    Enum.map_join(nodes, "\n", fn {id, data} ->
      label = options.node_label.(id, data)

      node_def =
        "  #{Yog.Utils.safe_string(id)}#{Mermaid.node_shape_brackets(options.node_shape, label)}"

      # Add highlight class if this node is in the highlighted list
      if options.highlighted_nodes && MapSet.member?(options.highlighted_nodes, id) do
        node_def <> ":::highlight"
      else
        node_def
      end
    end)
  end

  defp build_node_styles(nodes, options) do
    nodes
    |> Enum.map(fn {id, data} ->
      attrs = options.node_attributes.(id, data)

      # Merge highlight styling if applicable
      attrs =
        if options.highlighted_nodes && MapSet.member?(options.highlighted_nodes, id) do
          [
            {:fill, options.highlight_fill},
            {:stroke, options.highlight_stroke},
            {:stroke_width, Mermaid.css_length_to_string(options.highlight_stroke_width)}
            | attrs
          ]
        else
          attrs
        end

      if attrs != [] do
        style_str = attributes_to_style(attrs)
        "  style #{Yog.Utils.safe_string(id)} #{style_str}"
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp attributes_to_style(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      style_key =
        case key do
          :fill -> "fill"
          :fillcolor -> "fill"
          :stroke -> "stroke"
          :color -> "stroke"
          :stroke_width -> "stroke-width"
          :stroke_width_px -> "stroke-width"
          _ -> to_string(key)
        end

      "#{style_key}:#{value}"
    end)
    |> Enum.uniq()
    |> Enum.join(",")
  end

  defp build_subgraphs(nil), do: ""
  defp build_subgraphs([]), do: ""

  defp build_subgraphs(subgraph_list) when is_list(subgraph_list) do
    Enum.map_join(subgraph_list, "\n", &build_subgraph/1)
  end

  defp build_subgraph(sub) do
    header = "  subgraph #{escape_subgraph_name(sub.name)}"

    label =
      if sub.label do
        " [\"#{escape_label(sub.label)}\"]"
      else
        ""
      end

    node_list =
      case Map.get(sub, :node_ids) do
        nil -> ""
        [] -> ""
        ids -> Enum.map_join(ids, "\n", &"    #{Yog.Utils.safe_string(&1)}")
      end

    header <> label <> "\n" <> node_list <> "\n  end"
  end

  defp escape_subgraph_name(name) do
    if String.contains?(name, " ") do
      "\"#{name}\""
    else
      name
    end
  end

  defp escape_label(label) do
    label
    |> String.replace("\"", "#quot;")
    |> String.replace("\n", "<br/>")
  end

  defp build_edge_lines(edges, options, kind) do
    flat_edges =
      edges
      |> Enum.map(fn {edge_id, {from_id, to_id, weight}} -> {edge_id, from_id, to_id, weight} end)
      |> Enum.filter(fn {_edge_id, from_id, to_id, _weight} ->
        case kind do
          :undirected -> from_id <= to_id
          _ -> true
        end
      end)

    {edge_declarations, link_styles} =
      flat_edges
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{edge_id, from_id, to_id, weight}, idx},
                                  {defs_acc, styles_acc} ->
        label = options.edge_label.(edge_id, weight)

        edge_def =
          case kind do
            :directed ->
              label_part = if label == "", do: "", else: "|#{label}|"

              "  #{Yog.Utils.safe_string(from_id)} -->#{label_part} #{Yog.Utils.safe_string(to_id)}"

            :undirected ->
              if label == "" do
                "  #{Yog.Utils.safe_string(from_id)} --- #{Yog.Utils.safe_string(to_id)}"
              else
                "  #{Yog.Utils.safe_string(from_id)} -- #{escape_label(label)} --- #{Yog.Utils.safe_string(to_id)}"
              end
          end

        # Check if this edge should be highlighted
        is_highlighted =
          options.highlighted_edges &&
            (MapSet.member?(options.highlighted_edges, edge_id) ||
               MapSet.member?(options.highlighted_edges, {from_id, to_id}) ||
               (kind == :undirected &&
                  MapSet.member?(options.highlighted_edges, {to_id, from_id})))

        # Build custom edge attributes
        custom_attrs = options.edge_attributes.(from_id, to_id, edge_id, weight)

        {style_attrs, has_style} =
          if is_highlighted do
            attrs =
              [
                {:stroke, options.highlight_link_stroke},
                {:stroke_width, Mermaid.css_length_to_string(options.highlight_link_stroke_width)}
              ] ++ custom_attrs

            {attrs, true}
          else
            base_attrs =
              if options.default_link_stroke,
                do: [{:stroke, options.default_link_stroke}],
                else: []

            if custom_attrs != [] or base_attrs != [] do
              base_width = Mermaid.css_length_to_string(options.link_thickness)

              attrs =
                [{:stroke_width, base_width} | base_attrs ++ custom_attrs]
                |> Enum.uniq_by(fn {k, _} -> k end)

              {attrs, true}
            else
              {[], false}
            end
          end

        if has_style do
          style_str =
            "  linkStyle #{idx} #{attributes_to_link_style(style_attrs)}"

          {[edge_def | defs_acc], [style_str | styles_acc]}
        else
          {[edge_def | defs_acc], styles_acc}
        end
      end)

    edges_str =
      edge_declarations
      |> Enum.reverse()
      |> Enum.join("\n")

    {edges_str, Enum.reverse(link_styles)}
  end

  defp attributes_to_link_style(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      style_key =
        case key do
          :stroke -> "stroke"
          :color -> "stroke"
          :stroke_width -> "stroke-width"
          _ -> to_string(key)
        end

      "#{style_key}:#{value}"
    end)
    |> Enum.uniq()
    |> Enum.join(",")
  end

  defp build_link_styles([]), do: ""

  defp build_link_styles(styles) do
    Enum.join(styles, "\n")
  end
end
