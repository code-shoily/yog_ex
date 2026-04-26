defmodule Yog.Multi.DOT do
  @moduledoc """
  DOT (Graphviz) format export for visualizing multigraphs.

  This module exports multigraphs (graphs with support for parallel edges)
  to the DOT language. It mirrors the capabilities of `Yog.Render.DOT`
  but adapts the edge configurations to account for multiple relationships.

  ## Per-Edge Customization

  Because multiple edges can exist between the same nodes, callback functions
  pass the unique `edge_id`:

      options = %{
        Yog.Multi.DOT.default_options() |
        edge_attributes: fn from, to, edge_id, weight ->
          if edge_id == 5 do
            [{:color, "red"}, {:style, "dashed"}]
          else
            []
          end
        end
      }
  """

  # =============================================================================
  # TYPES
  # =============================================================================

  @typedoc "Graphviz layout engine"
  @type layout ::
          :dot
          | :neato
          | :circo
          | :fdp
          | :sfdp
          | :twopi
          | :osage
          | {:custom, String.t()}

  @typedoc "Graph direction (rank direction)"
  @type rank_dir :: :tb | :lr | :bt | :rl

  @typedoc "Node shapes"
  @type node_shape ::
          :box
          | :box3d
          | :circle
          | :cloud
          | :component
          | :cylinder
          | :diamond
          | :doublecircle
          | :ellipse
          | :folder
          | :hexagon
          | :house
          | :invhouse
          | :invtriangle
          | :note
          | :octagon
          | :parallelogram
          | :pentagon
          | :plain
          | :plaintext
          | :point
          | :rect
          | :rectangle
          | :square
          | :tab
          | :trapezoid
          | :triangle
          | :underline
          | {:custom, String.t()}

  @typedoc "Visual style"
  @type style ::
          :solid
          | :dashed
          | :dotted
          | :bold
          | :filled
          | :rounded
          | :diagonals
          | :striped
          | :wedged

  @typedoc "Edge routing style"
  @type splines :: :line | :polyline | :curved | :ortho | :spline | :none

  @typedoc "Arrow head/tail style"
  @type arrow_style ::
          :normal
          | :dot
          | :diamond
          | :odiamond
          | :box
          | :crow
          | :vee
          | :inv
          | :tee
          | :none
          | {:custom, String.t()}

  @typedoc "Overlap handling"
  @type overlap :: true | false | :scale | :scalexy | :prism | {:custom, String.t()}

  @typedoc "A subgraph (cluster) for grouping nodes visually in the diagram."
  @type subgraph :: %{
          name: String.t(),
          label: String.t() | nil,
          node_ids: [Yog.Model.node_id()] | nil,
          style: style() | nil,
          fillcolor: String.t() | nil,
          color: String.t() | nil,
          subgraphs: [subgraph()] | nil
        }

  @typedoc "Options for customizing multigraph DOT rendering"
  @type options :: %{
          node_label: (Yog.Model.node_id(), any() -> String.t()),
          edge_label: (Yog.Multi.Graph.edge_id(), any() -> String.t()),
          highlighted_nodes: [Yog.Model.node_id()] | nil,
          highlighted_edges:
            [Yog.Multi.Graph.edge_id() | {Yog.Model.node_id(), Yog.Model.node_id()}] | nil,
          node_attributes: (Yog.Model.node_id(), any() -> [{atom(), String.t()}]),
          edge_attributes: (Yog.Model.node_id(),
                            Yog.Model.node_id(),
                            Yog.Multi.Graph.edge_id(),
                            any() ->
                              [{atom(), String.t()}]),
          subgraphs: [subgraph()] | nil,
          ranks: [{:same | :min | :max | :source | :sink, [Yog.Model.node_id()]}] | nil,
          graph_name: String.t(),
          layout: layout() | nil,
          rankdir: rank_dir() | nil,
          bgcolor: String.t() | nil,
          splines: splines() | nil,
          overlap: overlap() | nil,
          nodesep: float() | nil,
          ranksep: float() | nil,
          node_shape: node_shape(),
          node_color: String.t(),
          node_style: style(),
          node_fontname: String.t(),
          node_fontsize: integer(),
          node_fontcolor: String.t(),
          edge_color: String.t(),
          edge_style: style(),
          edge_fontname: String.t(),
          edge_fontsize: integer(),
          edge_penwidth: float(),
          arrowhead: arrow_style() | nil,
          arrowtail: arrow_style() | nil,
          highlight_color: String.t(),
          highlight_penwidth: float()
        }

  @doc """
  Creates default DOT options with multigraph labeling capabilities.
  """
  @spec default_options() :: options()
  def default_options do
    %{
      node_label: &Yog.Utils.to_label/2,
      edge_label: fn _id, weight -> Yog.Utils.to_weight_label(weight) end,
      highlighted_nodes: nil,
      highlighted_edges: nil,
      node_attributes: fn _, _ -> [] end,
      edge_attributes: fn _, _, _, _ -> [] end,
      subgraphs: nil,
      ranks: nil,
      graph_name: "G",
      layout: nil,
      rankdir: :tb,
      bgcolor: nil,
      splines: nil,
      overlap: nil,
      nodesep: nil,
      ranksep: nil,
      node_shape: :ellipse,
      node_color: "lightblue",
      node_style: :filled,
      node_fontname: "Helvetica",
      node_fontsize: 12,
      node_fontcolor: "black",
      edge_color: "black",
      edge_style: :solid,
      edge_fontname: "Helvetica",
      edge_fontsize: 10,
      edge_penwidth: 1.0,
      arrowhead: nil,
      arrowtail: nil,
      highlight_color: "red",
      highlight_penwidth: 2.0
    }
  end

  @doc """
  Converts a multigraph (`Yog.Multi.Graph`) to DOT syntax.
  """
  @spec to_dot(Yog.Multi.Graph.t(), options()) :: String.t()
  def to_dot(graph, options \\ default_options()) do
    nodes = Map.get(graph, :nodes, %{})
    edges = Map.get(graph, :edges, %{})
    kind = Map.get(graph, :kind, :directed)

    {graph_type, arrow} =
      if kind == :directed do
        {"digraph", "->"}
      else
        {"graph", "--"}
      end

    header = "#{graph_type} #{options.graph_name} {\n"
    graph_attrs = build_graph_attrs(options)
    node_defaults = build_node_defaults(options)
    edge_defaults = build_edge_defaults(options)

    hl_nodes = to_mapset(options.highlighted_nodes)
    hl_edges = to_mapset(options.highlighted_edges)
    options = %{options | highlighted_nodes: hl_nodes, highlighted_edges: hl_edges}

    nodes_str = build_node_lines(nodes, options)
    subgraphs_str = build_subgraphs(options.subgraphs, 1)
    ranks_str = build_ranks(options.ranks)
    edges_str = build_edge_lines(edges, options, arrow, kind)

    [
      header,
      graph_attrs,
      node_defaults,
      edge_defaults,
      "\n",
      nodes_str,
      "\n",
      subgraphs_str,
      ranks_str,
      edges_str,
      "\n}"
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("")
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  defp build_graph_attrs(options) do
    attrs =
      [
        if(options.layout, do: "layout=#{layout_to_string(options.layout)}"),
        if(options.rankdir, do: "rankdir=#{rankdir_to_string(options.rankdir)}"),
        if(options.bgcolor, do: "bgcolor=\"#{options.bgcolor}\""),
        if(options.splines, do: "splines=#{splines_to_string(options.splines)}"),
        if(options.overlap != nil, do: "overlap=#{overlap_to_string(options.overlap)}"),
        if(options.nodesep != nil, do: "nodesep=#{options.nodesep}"),
        if(options.ranksep != nil, do: "ranksep=#{options.ranksep}")
      ]
      |> Enum.reject(&is_nil/1)

    if attrs != [] do
      "  graph [#{Enum.join(attrs, ", ")}];\n"
    else
      ""
    end
  end

  defp build_node_defaults(options) do
    attrs = [
      "shape=#{node_shape_to_string(options.node_shape)}",
      "style=#{style_to_string(options.node_style)}",
      "fillcolor=\"#{options.node_color}\"",
      "fontname=\"#{options.node_fontname}\"",
      "fontsize=#{options.node_fontsize}",
      "fontcolor=\"#{options.node_fontcolor}\""
    ]

    "  node [#{Enum.join(attrs, ", ")}];\n"
  end

  defp build_edge_defaults(options) do
    base_attrs = [
      "color=\"#{options.edge_color}\"",
      "style=#{style_to_string(options.edge_style)}",
      "fontname=\"#{options.edge_fontname}\"",
      "fontsize=#{options.edge_fontsize}",
      "penwidth=#{options.edge_penwidth}"
    ]

    attrs =
      case {options.arrowhead, options.arrowtail} do
        {nil, nil} ->
          base_attrs

        {head, nil} ->
          ["arrowhead=#{arrow_style_to_string(head)}" | base_attrs]

        {nil, tail} ->
          ["arrowtail=#{arrow_style_to_string(tail)}" | base_attrs]

        {head, tail} ->
          [
            "arrowhead=#{arrow_style_to_string(head)}",
            "arrowtail=#{arrow_style_to_string(tail)}" | base_attrs
          ]
      end

    "  edge [#{Enum.join(attrs, ", ")}];\n"
  end

  defp build_node_lines(nodes, options) do
    Enum.map_join(nodes, "", fn {id, data} ->
      label = options.node_label.(id, data)
      id_str = Yog.Utils.safe_string(id)

      attrs = [{:label, label}]

      attrs =
        if options.highlighted_nodes && MapSet.member?(options.highlighted_nodes, id) do
          [{:fillcolor, options.highlight_color} | attrs]
        else
          attrs
        end

      custom_attrs = options.node_attributes.(id, data)
      attrs = merge_attributes_list(attrs, custom_attrs)

      attr_str = format_attributes_list(attrs)
      "  #{id_str} [#{attr_str}];\n"
    end)
  end

  defp build_subgraphs(nil, _indent), do: ""
  defp build_subgraphs([], _indent), do: ""

  defp build_subgraphs(subgraph_list, indent) when is_list(subgraph_list) do
    Enum.map_join(subgraph_list, "", &build_subgraph(&1, indent))
  end

  defp build_subgraph(sub, indent) do
    prefix = String.duplicate("  ", indent)
    inner_prefix = String.duplicate("  ", indent + 1)

    header = "#{prefix}subgraph #{sub.name} {\n"

    label = if sub.label, do: "#{inner_prefix}label=\"#{sub.label}\";\n", else: ""

    style =
      cond do
        sub.style -> "#{inner_prefix}style=#{style_to_string(sub.style)};\n"
        sub.fillcolor -> "#{inner_prefix}style=filled;\n"
        true -> ""
      end

    fillcolor = if sub.fillcolor, do: "#{inner_prefix}fillcolor=\"#{sub.fillcolor}\";\n", else: ""
    color = if sub.color, do: "#{inner_prefix}color=\"#{sub.color}\";\n", else: ""

    node_list =
      case Map.get(sub, :node_ids) do
        nil -> ""
        [] -> ""
        ids -> Enum.map_join(ids, ";\n", &"#{inner_prefix}#{Yog.Utils.safe_string(&1)}") <> ";\n"
      end

    nested = build_subgraphs(Map.get(sub, :subgraphs), indent + 1)

    header <> label <> style <> fillcolor <> color <> node_list <> nested <> "#{prefix}}\n"
  end

  defp build_ranks(nil), do: ""

  defp build_ranks(rank_list) do
    Enum.map_join(rank_list, "", fn {rank_type, node_ids} ->
      rank_str = Atom.to_string(rank_type)
      nodes = Enum.map_join(node_ids, "; ", &Yog.Utils.safe_string/1)
      "  {rank=#{rank_str}; #{nodes};}\n"
    end)
  end

  defp build_edge_lines(edges, options, arrow, kind) do
    edges
    |> Enum.flat_map(fn {{from_id, to_id}, edge_list} ->
      # In undirected graphs, only render edges where from_id <= to_id
      if kind == :undirected and from_id > to_id do
        []
      else
        Enum.map(edge_list, fn {edge_id, weight} ->
          label = options.edge_label.(edge_id, weight)
          attrs = [{:label, label}]

          is_highlighted =
            options.highlighted_edges &&
              (MapSet.member?(options.highlighted_edges, edge_id) ||
                 MapSet.member?(options.highlighted_edges, {from_id, to_id}) ||
                 (kind == :undirected &&
                    MapSet.member?(options.highlighted_edges, {to_id, from_id})))

          attrs =
            if is_highlighted do
              [
                {:penwidth, options.highlight_penwidth},
                {:color, options.highlight_color} | attrs
              ]
            else
              attrs
            end

          custom_attrs = options.edge_attributes.(from_id, to_id, edge_id, weight)
          attrs = merge_attributes_list(attrs, custom_attrs)

          attr_str = format_attributes_list(attrs)

          "  #{Yog.Utils.safe_string(from_id)} #{arrow} #{Yog.Utils.safe_string(to_id)} [#{attr_str}];\n"
        end)
      end
    end)
    |> Enum.join("")
  end

  defp merge_attributes_list(base, []), do: base

  defp merge_attributes_list(base, override) do
    override_map = Map.new(override)
    merged = Enum.reject(base, fn {key, _} -> Map.has_key?(override_map, key) end)
    override ++ merged
  end

  defp format_attributes_list(attrs) do
    attrs
    |> Enum.reverse()
    |> Enum.map_join(", ", fn {key, value} ->
      "#{key}=\"#{escape_quotes(value)}\""
    end)
  end

  defp escape_quotes(s) when is_binary(s) do
    s
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp escape_quotes(v), do: v

  defp to_mapset(nil), do: nil
  defp to_mapset(list) when is_list(list), do: MapSet.new(list)
  defp to_mapset(%MapSet{} = set), do: set

  # Layout/Styling to strings
  defp layout_to_string(:dot), do: "dot"
  defp layout_to_string(:neato), do: "neato"
  defp layout_to_string(:circo), do: "circo"
  defp layout_to_string(:fdp), do: "fdp"
  defp layout_to_string(:sfdp), do: "sfdp"
  defp layout_to_string(:twopi), do: "twopi"
  defp layout_to_string(:osage), do: "osage"
  defp layout_to_string({:custom, s}), do: s

  defp rankdir_to_string(:tb), do: "TB"
  defp rankdir_to_string(:lr), do: "LR"
  defp rankdir_to_string(:bt), do: "BT"
  defp rankdir_to_string(:rl), do: "RL"

  defp node_shape_to_string(:box), do: "box"
  defp node_shape_to_string(:box3d), do: "box3d"
  defp node_shape_to_string(:circle), do: "circle"
  defp node_shape_to_string(:cloud), do: "cloud"
  defp node_shape_to_string(:component), do: "component"
  defp node_shape_to_string(:cylinder), do: "cylinder"
  defp node_shape_to_string(:diamond), do: "diamond"
  defp node_shape_to_string(:doublecircle), do: "doublecircle"
  defp node_shape_to_string(:ellipse), do: "ellipse"
  defp node_shape_to_string(:folder), do: "folder"
  defp node_shape_to_string(:hexagon), do: "hexagon"
  defp node_shape_to_string(:house), do: "house"
  defp node_shape_to_string(:invhouse), do: "invhouse"
  defp node_shape_to_string(:invtriangle), do: "invtriangle"
  defp node_shape_to_string(:note), do: "note"
  defp node_shape_to_string(:octagon), do: "octagon"
  defp node_shape_to_string(:parallelogram), do: "parallelogram"
  defp node_shape_to_string(:pentagon), do: "pentagon"
  defp node_shape_to_string(:plain), do: "plain"
  defp node_shape_to_string(:plaintext), do: "plaintext"
  defp node_shape_to_string(:point), do: "point"
  defp node_shape_to_string(:rect), do: "rect"
  defp node_shape_to_string(:rectangle), do: "rectangle"
  defp node_shape_to_string(:square), do: "square"
  defp node_shape_to_string(:tab), do: "tab"
  defp node_shape_to_string(:trapezoid), do: "trapezoid"
  defp node_shape_to_string(:triangle), do: "triangle"
  defp node_shape_to_string(:underline), do: "underline"
  defp node_shape_to_string({:custom, s}), do: s

  defp style_to_string(:solid), do: "solid"
  defp style_to_string(:dashed), do: "dashed"
  defp style_to_string(:dotted), do: "dotted"
  defp style_to_string(:bold), do: "bold"
  defp style_to_string(:filled), do: "filled"
  defp style_to_string(:rounded), do: "rounded"
  defp style_to_string(:diagonals), do: "diagonals"
  defp style_to_string(:striped), do: "striped"
  defp style_to_string(:wedged), do: "wedged"

  defp splines_to_string(:line), do: "line"
  defp splines_to_string(:polyline), do: "polyline"
  defp splines_to_string(:curved), do: "curved"
  defp splines_to_string(:ortho), do: "ortho"
  defp splines_to_string(:spline), do: "spline"
  defp splines_to_string(:none), do: "none"

  defp arrow_style_to_string(:normal), do: "normal"
  defp arrow_style_to_string(:dot), do: "dot"
  defp arrow_style_to_string(:diamond), do: "diamond"
  defp arrow_style_to_string(:odiamond), do: "odiamond"
  defp arrow_style_to_string(:box), do: "box"
  defp arrow_style_to_string(:crow), do: "crow"
  defp arrow_style_to_string(:vee), do: "vee"
  defp arrow_style_to_string(:inv), do: "inv"
  defp arrow_style_to_string(:tee), do: "tee"
  defp arrow_style_to_string(:none), do: "none"
  defp arrow_style_to_string({:custom, s}), do: s

  defp overlap_to_string(true), do: "true"
  defp overlap_to_string(false), do: "false"
  defp overlap_to_string(:scale), do: "scale"
  defp overlap_to_string(:scalexy), do: "scalexy"
  defp overlap_to_string(:prism), do: "prism"
  defp overlap_to_string({:custom, s}), do: s
end
