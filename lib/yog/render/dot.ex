defmodule Yog.Render.DOT do
  @moduledoc """
  DOT (Graphviz) format export for visualizing graphs.

  This module exports graphs to the [DOT language](https://graphviz.org/doc/info/lang.html),
  which is the native format for [Graphviz](https://graphviz.org/) - a powerful open-source
  graph visualization tool. The exported files can be rendered to PNG, SVG, PDF, and other
  formats using the `dot`, `neato`, `circo`, or other Graphviz layout engines.

  ## Quick Start

      # Export with default styling
      dot_string = Yog.Render.DOT.to_dot(my_graph, Yog.Render.DOT.default_options())

      # Write to file and render with Graphviz CLI
      # $ dot -Tpng output.dot -o graph.png

  ## Customization

  Use `t:options/0` to customize:
  - Node labels and shapes
  - Edge labels and styles
  - **Per-node and per-edge attributes** (custom colors, shapes, etc.)
  - **Subgraphs/clusters** for visual grouping
  - Highlight specific nodes or paths
  - Graph direction (LR, TB, etc.)

  ## Generic Data Types

  The `to_dot` function works with any node and edge data types. Use
  `default_options_with_edge_formatter/1` when your edge data is not a String.

  ## Per-Element Styling

  Provide custom attribute functions for fine-grained control:

      options = %{
        Yog.Render.DOT.default_options() |
        node_attributes: fn id, data ->
          case id do
            1 -> [{:fillcolor, "green"}, {:shape, "diamond"}]
            _ -> []
          end
        end,
        edge_attributes: fn from, to, weight ->
          if weight > 10 do
            [{:color, "red"}, {:penwidth, 2}]
          else
            []
          end
        end
      }

  ## Subgraphs and Clusters

  Group nodes visually using subgraphs:

      options = %{
        Yog.Render.DOT.default_options() |
        subgraphs: [
          %{
            name: "cluster_0",
            label: "Cluster A",
            node_ids: [1, 2, 3],
            style: :filled,
            fillcolor: "lightgrey",
            color: nil
          }
        ]
      }

  ## Rendering Options

  | Engine | Best For |
  |--------|----------|
  | `dot` | Hierarchical layouts (DAGs, trees) |
  | `neato` | Spring-based layouts (undirected) |
  | `circo` | Circular layouts |
  | `fdp` | Force-directed layouts |
  | `sfdp` | Large graphs |

  ## References

  - [Graphviz Documentation](https://graphviz.org/documentation/)
  - [DOT Language Guide](https://graphviz.org/doc/info/lang.html)
  - [Node Shapes](https://graphviz.org/doc/info/shapes.html)
  - [Arrow Styles](https://graphviz.org/doc/info/arrows.html)
  - [Cluster/Subgraph Syntax](https://graphviz.org/docs/attrs/cluster/)

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
          | :circle
          | :ellipse
          | :diamond
          | :hexagon
          | :pentagon
          | :octagon
          | :triangle
          | :rectangle
          | :square
          | :rect
          | :invtriangle
          | :house
          | :invhouse
          | :parallelogram
          | :trapezoid
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

  @typedoc """
  A subgraph (cluster) for grouping nodes visually in the diagram.

  In Graphviz, subgraphs with names starting with "cluster_" are rendered
  as bounded rectangles around the contained nodes.
  """
  @type subgraph :: %{
          name: String.t(),
          label: String.t() | nil,
          node_ids: [Yog.node_id()],
          style: style() | nil,
          fillcolor: String.t() | nil,
          color: String.t() | nil
        }

  @typedoc "Options for customizing DOT (Graphviz) diagram rendering"
  @type options :: %{
          node_label: (Yog.node_id(), any() -> String.t()),
          edge_label: (any() -> String.t()),
          highlighted_nodes: [Yog.node_id()] | nil,
          highlighted_edges: [{Yog.node_id(), Yog.node_id()}] | nil,
          # Per-element styling
          node_attributes: (Yog.node_id(), any() -> [{atom(), String.t()}]),
          edge_attributes: (Yog.node_id(), Yog.node_id(), any() -> [{atom(), String.t()}]),
          # Subgraphs
          subgraphs: [subgraph()] | nil,
          # Rank constraints
          ranks: [{:same | :min | :max | :source | :sink, [Yog.node_id()]}] | nil,
          # Graph-level attributes
          graph_name: String.t(),
          layout: layout() | nil,
          rankdir: rank_dir() | nil,
          bgcolor: String.t() | nil,
          splines: splines() | nil,
          overlap: overlap() | nil,
          nodesep: float() | nil,
          ranksep: float() | nil,
          # Node styling
          node_shape: node_shape(),
          node_color: String.t(),
          node_style: style(),
          node_fontname: String.t(),
          node_fontsize: integer(),
          node_fontcolor: String.t(),
          # Edge styling
          edge_color: String.t(),
          edge_style: style(),
          edge_fontname: String.t(),
          edge_fontsize: integer(),
          edge_penwidth: float(),
          arrowhead: arrow_style() | nil,
          arrowtail: arrow_style() | nil,
          # Highlighting
          highlight_color: String.t(),
          highlight_penwidth: float()
        }

  @doc """
  Creates default DOT options with simple labeling and sensible styling.

  Default configuration:
  - Layout: Auto-detected by Graphviz
  - Direction: Top-to-bottom
  - Node shape: Ellipse
  - Colors: Light blue nodes, black edges
  - Font: Helvetica 12pt

  ## Examples

      iex> opts = Yog.Render.DOT.default_options()
      iex> opts.graph_name
      "G"
      iex> opts.node_shape
      :ellipse
      iex> opts.node_color
      "lightblue"
  """
  @spec default_options() :: options()
  def default_options do
    %{
      node_label: fn id, _data -> to_string(id) end,
      edge_label: fn weight -> to_string(weight) end,
      highlighted_nodes: nil,
      highlighted_edges: nil,
      # Per-element styling defaults
      node_attributes: fn _, _ -> [] end,
      edge_attributes: fn _, _, _ -> [] end,
      # Subgraphs and rank constraints
      subgraphs: nil,
      ranks: nil,
      # Graph-level
      graph_name: "G",
      layout: nil,
      rankdir: :tb,
      bgcolor: nil,
      splines: nil,
      overlap: nil,
      nodesep: nil,
      ranksep: nil,
      # Node styling
      node_shape: :ellipse,
      node_color: "lightblue",
      node_style: :filled,
      node_fontname: "Helvetica",
      node_fontsize: 12,
      node_fontcolor: "black",
      # Edge styling
      edge_color: "black",
      edge_style: :solid,
      edge_fontname: "Helvetica",
      edge_fontsize: 10,
      edge_penwidth: 1.0,
      arrowhead: nil,
      arrowtail: nil,
      # Highlighting
      highlight_color: "red",
      highlight_penwidth: 2.0
    }
  end

  @doc """
  Creates default DOT options with a custom edge formatter.

  Use this when your graph has non-String edge data (e.g., Int, Float, custom types).

  ## Example

      # For a graph with Int edge weights
      options = Yog.Render.DOT.default_options_with_edge_formatter(fn weight ->
        Integer.to_string(weight)
      end)
  """
  @spec default_options_with_edge_formatter((any() -> String.t())) :: options()
  def default_options_with_edge_formatter(edge_formatter) do
    %{default_options() | edge_label: edge_formatter}
  end

  @doc """
  Creates default DOT options with custom label formatters for both nodes and edges.

  ## Example

      options = Yog.Render.DOT.default_options_with(
        node_label: fn id, data -> "\#{data} (\#{id})" end,
        edge_label: fn weight -> "\#{weight} ms" end
      )
  """
  @spec default_options_with(
          node_label: (Yog.node_id(), any() -> String.t()),
          edge_label: (any() -> String.t())
        ) :: options()
  def default_options_with(node_label: node_label, edge_label: edge_label) do
    %{default_options() | node_label: node_label, edge_label: edge_label}
  end

  @doc """
  Converts a graph to DOT (Graphviz) syntax.

  Works with any node data type and edge data type. Use the options
  to customize labels, styling, and to define subgraphs.

  **Time Complexity:** O(V + E + S) where S is the total number of nodes
  across all subgraphs.

  ## Example

      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "Process")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")

      diagram = Yog.Render.DOT.to_dot(graph, Yog.Render.DOT.default_options())
  """
  @spec to_dot(Yog.graph(), options()) :: String.t()
  def to_dot(graph, options \\ default_options()) do
    nodes = extract_nodes(graph)
    edges = extract_edges(graph)
    kind = extract_kind(graph)

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

    # Convert highlight lists to MapSets for O(1) membership checks
    hl_nodes = to_mapset(options.highlighted_nodes)
    hl_edges = to_edge_set(options.highlighted_edges)
    options = %{options | highlighted_nodes: hl_nodes, highlighted_edges: hl_edges}

    # Generate nodes with per-element attributes
    nodes_str = build_node_lines(nodes, options)

    # Generate subgraphs
    subgraphs_str = build_subgraphs(options.subgraphs)

    # Generate rank constraints
    ranks_str = build_ranks(options.ranks)

    # Generate edges with per-element attributes
    edges_str = build_edge_lines(edges, options, arrow, kind)

    # Combine all parts
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

  @doc """
  Converts a shortest path result to highlighted DOT options.

  Creates a copy of the base options with the path's nodes and edges
  set to be highlighted. This is useful for visualizing algorithm results.

  ## Example

      case Yog.Pathfinding.Dijkstra.shortest_path(...) do
        {:ok, path} ->
          options = Yog.Render.DOT.path_to_options(path, Yog.Render.DOT.default_options())
          dot_string = Yog.Render.DOT.to_dot(graph, options)
        :error ->
          ""
      end
  """
  @spec path_to_options(map(), options()) :: options()
  def path_to_options(path, base_options \\ default_options()) do
    nodes = Map.get(path, :nodes, [])
    edges = path_to_edges(nodes)

    %{base_options | highlighted_nodes: nodes, highlighted_edges: edges}
  end

  @doc """
  Returns a pre-configured theme as DOT options.

  Available themes:
  - `:default` — Light blue nodes, black edges (same as `default_options/0`)
  - `:dark` — Dark background with neon accent colors, ideal for dark UIs
  - `:minimal` — Clean wireframe look with no fills and thin lines
  - `:presentation` — Large fonts and bold colors for slides and demos

  ## Examples

      iex> opts = Yog.Render.DOT.theme(:dark)
      iex> opts.bgcolor
      "#1a1a2e"
      iex> opts.node_color
      "#16213e"

      iex> opts = Yog.Render.DOT.theme(:minimal)
      iex> opts.node_style
      :solid

      iex> opts = Yog.Render.DOT.theme(:presentation)
      iex> opts.node_fontsize
      18
  """
  @spec theme(atom()) :: options()
  def theme(:default), do: default_options()

  def theme(:dark) do
    %{
      default_options()
      | bgcolor: "#1a1a2e",
        node_color: "#16213e",
        node_fontcolor: "#e0e0e0",
        node_style: :filled,
        node_shape: :box,
        edge_color: "#4a4a6a",
        edge_fontname: "Courier",
        highlight_color: "#e94560",
        highlight_penwidth: 2.5
    }
  end

  def theme(:minimal) do
    %{
      default_options()
      | node_color: "white",
        node_style: :solid,
        node_shape: :circle,
        node_fontsize: 10,
        edge_color: "#666666",
        edge_penwidth: 0.5,
        edge_fontsize: 8,
        highlight_color: "#333333",
        highlight_penwidth: 1.5
    }
  end

  def theme(:presentation) do
    %{
      default_options()
      | node_shape: :box,
        node_style: :filled,
        node_color: "#4361ee",
        node_fontname: "Helvetica-Bold",
        node_fontsize: 18,
        node_fontcolor: "white",
        edge_color: "#3a0ca3",
        edge_fontsize: 14,
        edge_penwidth: 2.0,
        highlight_color: "#f72585",
        highlight_penwidth: 3.5,
        nodesep: 0.8,
        ranksep: 1.0
    }
  end

  @doc """
  Creates DOT options that highlight an MST result.

  MST edges are highlighted and non-MST edges use default styling.

  ## Example

      result = Yog.MST.kruskal(graph)
      options = Yog.Render.DOT.mst_to_options(result)
      dot_string = Yog.Render.DOT.to_dot(graph, options)
  """
  @spec mst_to_options(Yog.MST.Result.t(), options()) :: options()
  def mst_to_options(%{edges: edges}, base_options \\ default_options()) do
    mst_edges = Enum.map(edges, fn %{from: f, to: t} -> {f, t} end)
    mst_nodes = Enum.flat_map(edges, fn %{from: f, to: t} -> [f, t] end) |> Enum.uniq()
    %{base_options | highlighted_edges: mst_edges, highlighted_nodes: mst_nodes}
  end

  @doc """
  Creates DOT options that color nodes by community assignment.

  Each community gets a distinct color from a generated palette. The palette
  cycles through visually distinct hues.

  ## Example

      result = Yog.Community.Louvain.detect(graph)
      options = Yog.Render.DOT.community_to_options(result)
      dot_string = Yog.Render.DOT.to_dot(graph, options)
  """
  @spec community_to_options(Yog.Community.Result.t(), options()) :: options()
  def community_to_options(
        %{assignments: assignments, num_communities: n},
        base_options \\ default_options()
      ) do
    palette = generate_palette(n)

    # Build community -> color mapping
    community_ids = assignments |> Map.values() |> Enum.uniq() |> Enum.sort()
    color_map = Enum.zip(community_ids, palette) |> Map.new()

    node_attrs = fn id, _data ->
      case Map.get(assignments, id) do
        nil -> []
        cid -> [{:fillcolor, Map.get(color_map, cid, "lightgrey")}, {:style, "filled"}]
      end
    end

    %{base_options | node_attributes: node_attrs}
  end

  @doc """
  Creates DOT options that color the source and sink sides of a min-cut.

  Source-side nodes are colored with `source_color` (default: light blue),
  sink-side nodes with `sink_color` (default: light coral).

  Requires the `MinCutResult` to have `source_side` and `sink_side` populated
  (use `track_partitions: true` or `extract_min_cut/1`).

  ## Example

      result = Yog.Flow.MinCut.global_min_cut(graph, track_partitions: true)
      options = Yog.Render.DOT.cut_to_options(result)
      dot_string = Yog.Render.DOT.to_dot(graph, options)
  """
  @spec cut_to_options(Yog.Flow.MinCutResult.t(), options()) :: options()
  def cut_to_options(%{source_side: source, sink_side: sink}, base_options \\ default_options()) do
    source_set = if source, do: MapSet.new(source), else: MapSet.new()
    sink_set = if sink, do: MapSet.new(sink), else: MapSet.new()

    node_attrs = fn id, _data ->
      cond do
        MapSet.member?(source_set, id) -> [{:fillcolor, "#a8d8ea"}, {:style, "filled"}]
        MapSet.member?(sink_set, id) -> [{:fillcolor, "#f08080"}, {:style, "filled"}]
        true -> []
      end
    end

    %{base_options | node_attributes: node_attrs}
  end

  @doc """
  Creates DOT options that highlight matched edges from a matching result.

  Works with results from both `Yog.Matching.hopcroft_karp/1` and
  `Yog.Matching.hungarian/2` (the matching map component).

  ## Example

      matching = Yog.Matching.hopcroft_karp(graph)
      options = Yog.Render.DOT.matching_to_options(matching)
      dot_string = Yog.Render.DOT.to_dot(graph, options)
  """
  @spec matching_to_options(%{Yog.node_id() => Yog.node_id()}, options()) :: options()
  def matching_to_options(matching, base_options \\ default_options()) when is_map(matching) do
    # Deduplicate bidirectional pairs
    edges =
      matching
      |> Enum.map(fn {u, v} -> if u <= v, do: {u, v}, else: {v, u} end)
      |> Enum.uniq()

    nodes = Map.keys(matching)
    %{base_options | highlighted_edges: edges, highlighted_nodes: nodes}
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  defp extract_nodes(graph) do
    case graph do
      %{nodes: n} when is_map(n) -> n
      _ -> %{}
    end
  end

  defp extract_edges(graph) do
    case graph do
      %{out_edges: e} when is_map(e) -> e
      _ -> %{}
    end
  end

  defp extract_kind(graph) do
    case graph do
      %{kind: k} -> k
      _ -> :directed
    end
  end

  defp build_graph_attrs(options) do
    attrs =
      [
        options.layout && "layout=#{layout_to_string(options.layout)}",
        options.rankdir && "rankdir=#{rankdir_to_string(options.rankdir)}",
        options.bgcolor && "bgcolor=\"#{options.bgcolor}\"",
        options.splines && "splines=#{splines_to_string(options.splines)}",
        options.overlap && "overlap=#{overlap_to_string(options.overlap)}",
        options.nodesep && "nodesep=#{options.nodesep}",
        options.ranksep && "ranksep=#{options.ranksep}"
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
      id_str = to_string(id)

      # Build attribute list starting with label
      attrs = [{:label, label}]

      # Add highlighting if applicable
      attrs =
        if options.highlighted_nodes && MapSet.member?(options.highlighted_nodes, id) do
          [{:fillcolor, options.highlight_color} | attrs]
        else
          attrs
        end

      # Merge custom attributes (these override highlighting and defaults)
      custom_attrs = options.node_attributes.(id, data)
      attrs = merge_attributes_list(attrs, custom_attrs)

      # Format attributes
      attr_str = format_attributes_list(attrs)

      "  #{id_str} [#{attr_str}];\n"
    end)
  end

  defp build_subgraphs(nil), do: ""

  defp build_subgraphs(subgraph_list) do
    Enum.map_join(subgraph_list, "", fn sub ->
      header = "  subgraph #{sub.name} {\n"

      label =
        if sub.label do
          "    label=\"#{sub.label}\";\n"
        else
          ""
        end

      style =
        if sub.style do
          "    style=#{style_to_string(sub.style)};\n"
        else
          ""
        end

      fillcolor =
        if sub.fillcolor do
          "    fillcolor=\"#{sub.fillcolor}\";\n"
        else
          ""
        end

      color =
        if sub.color do
          "    color=\"#{sub.color}\";\n"
        else
          ""
        end

      node_list =
        case sub.node_ids do
          [] ->
            ""

          ids ->
            Enum.map_join(ids, ";\n", &("    " <> to_string(&1))) <> ";\n"
        end

      header <> label <> style <> fillcolor <> color <> node_list <> "  }\n"
    end)
  end

  defp build_ranks(nil), do: ""

  defp build_ranks(rank_list) do
    Enum.map_join(rank_list, "", fn {rank_type, node_ids} ->
      rank_str = Atom.to_string(rank_type)
      nodes = Enum.map_join(node_ids, "; ", &to_string/1)
      "  {rank=#{rank_str}; #{nodes};}\n"
    end)
  end

  defp build_edge_lines(edges, options, arrow, kind) do
    edges
    |> Enum.flat_map(fn {from_id, targets} ->
      targets
      |> Enum.filter(fn {to_id, _weight} ->
        # Handle undirected deduplication
        case kind do
          :undirected -> from_id <= to_id
          :directed -> true
        end
      end)
      |> Enum.map(fn {to_id, weight} ->
        # Build attribute list starting with label
        label = options.edge_label.(weight)
        attrs = [{:label, label}]

        # Add highlighting if applicable
        is_highlighted =
          options.highlighted_edges &&
            (MapSet.member?(options.highlighted_edges, {from_id, to_id}) ||
               MapSet.member?(options.highlighted_edges, {to_id, from_id}))

        attrs =
          if is_highlighted do
            [
              {:penwidth, options.highlight_penwidth},
              {:color, options.highlight_color} | attrs
            ]
          else
            attrs
          end

        # Merge custom attributes (these override highlighting)
        custom_attrs = options.edge_attributes.(from_id, to_id, weight)
        attrs = merge_attributes_list(attrs, custom_attrs)

        # Format attributes
        attr_str = format_attributes_list(attrs)

        "  #{from_id} #{arrow} #{to_id} [#{attr_str}];\n"
      end)
    end)
    |> Enum.join("")
  end

  # Merge two attribute lists, with override taking precedence.
  # Uses a Map for O(B + O) merge instead of O(B × O) list scanning.
  defp merge_attributes_list(base, []), do: base

  defp merge_attributes_list(base, override) do
    override_map = Map.new(override)

    merged =
      Enum.reject(base, fn {key, _} -> Map.has_key?(override_map, key) end)

    override ++ merged
  end

  # Format a list of attributes as key="value", key2="value2"
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

  defp to_edge_set(nil), do: nil
  defp to_edge_set(list) when is_list(list), do: MapSet.new(list)
  defp to_edge_set(%MapSet{} = set), do: set

  # Generate a palette of n visually distinct colors using HSL with fixed S=70%, L=60%
  defp generate_palette(n) when n <= 0, do: []

  defp generate_palette(n) do
    Enum.map(0..(n - 1), fn i ->
      hue = rem(i * 137, 360)
      hsl_to_hex(hue, 70, 60)
    end)
  end

  defp hsl_to_hex(h, s, l) do
    s = s / 100
    l = l / 100
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(Float.round(:math.fmod(h / 60, 2), 10) - 1))
    m = l - c / 2

    {r1, g1, b1} =
      cond do
        h < 60 -> {c, x, 0.0}
        h < 120 -> {x, c, 0.0}
        h < 180 -> {0.0, c, x}
        h < 240 -> {0.0, x, c}
        h < 300 -> {x, 0.0, c}
        true -> {c, 0.0, x}
      end

    r = round((r1 + m) * 255)
    g = round((g1 + m) * 255)
    b = round((b1 + m) * 255)

    "#" <>
      String.pad_leading(Integer.to_string(r, 16), 2, "0") <>
      String.pad_leading(Integer.to_string(g, 16), 2, "0") <>
      String.pad_leading(Integer.to_string(b, 16), 2, "0")
  end

  # Helper to convert a list of nodes to a list of edges
  defp path_to_edges(nodes), do: do_path_to_edges(nodes, [])

  defp do_path_to_edges([], acc), do: Enum.reverse(acc)
  defp do_path_to_edges([_], acc), do: Enum.reverse(acc)

  defp do_path_to_edges([first, second | rest], acc) do
    do_path_to_edges([second | rest], [{first, second} | acc])
  end

  # =============================================================================
  # ENUM TO STRING CONVERSIONS
  # =============================================================================

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
  defp node_shape_to_string(:circle), do: "circle"
  defp node_shape_to_string(:ellipse), do: "ellipse"
  defp node_shape_to_string(:diamond), do: "diamond"
  defp node_shape_to_string(:hexagon), do: "hexagon"
  defp node_shape_to_string(:pentagon), do: "pentagon"
  defp node_shape_to_string(:octagon), do: "octagon"
  defp node_shape_to_string(:triangle), do: "triangle"
  defp node_shape_to_string(:rectangle), do: "rectangle"
  defp node_shape_to_string(:square), do: "square"
  defp node_shape_to_string(:rect), do: "rect"
  defp node_shape_to_string(:invtriangle), do: "invtriangle"
  defp node_shape_to_string(:house), do: "house"
  defp node_shape_to_string(:invhouse), do: "invhouse"
  defp node_shape_to_string(:parallelogram), do: "parallelogram"
  defp node_shape_to_string(:trapezoid), do: "trapezoid"
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
