defmodule Yog.Render.Mermaid do
  @moduledoc """
  Mermaid.js format export for embedding diagrams in web pages and documents.

  This module exports graphs to [Mermaid](https://mermaid.js.org/) syntax,
  a JavaScript-based diagramming tool that renders diagrams from text definitions.
  Mermaid is supported natively in GitHub, GitLab, Notion, and many other platforms.

  ## Quick Start

      # Export to Mermaid syntax
      mermaid = Yog.Render.Mermaid.to_mermaid(my_graph, Yog.Render.Mermaid.default_options())

      # Use in Markdown:
      # ```mermaid
      # graph TD
      #     A[Node 1] --> B[Node 2]
      # ```

  ## Supported Diagram Types

  This module generates flowchart-style diagrams:
  - **Graph TD**: Top-down (vertical) layout
  - **Graph LR**: Left-to-right (horizontal) layout
  - **Graph BT**: Bottom-to-top layout
  - **Graph RL**: Right-to-left layout

  ## Customization

  Control styling via `t:options/0`:
  - Node shapes (rounded, rectangular, circular, rhombus, hexagon, etc.)
  - Labels and edge annotations
  - Highlight specific nodes or edges
  - **Per-node and per-edge styling** (custom colors, stroke widths, etc.)
  - **Subgraphs** for visual grouping
  - Direction and orientation
  - CSS-based styling with custom lengths

  ## Per-Element Styling

  Provide custom attribute functions for fine-grained control:

      options = %{
        Yog.Render.Mermaid.default_options() |
        node_attributes: fn id, data ->
          case id do
            1 -> [{:fill, "#e1f5fe"}, {:stroke, "#0288d1"}]
            _ -> []
          end
        end,
        edge_attributes: fn from, to, weight ->
          if weight > 10 do
            [{:stroke, "#d32f2f"}, {:stroke_width, "3px"}]
          else
            []
          end
        end
      }

  ## Subgraphs

  Group nodes visually using subgraphs:

      options = %{
        Yog.Render.Mermaid.default_options() |
        subgraphs: [
          %{
            name: "Group A",
            label: "Cluster A",
            node_ids: [1, 2, 3]
          }
        ]
      }

  ## Embedding Options

  | Platform | Method |
  |----------|--------|
  | GitHub/GitLab | Native Markdown support |
  | Notion | Mermaid code block |
  | VS Code | Mermaid extension |
  | Static site | Mermaid.js library |
  | Jupyter | Mermaid magic commands |

  ## Live Editor

  Test and refine diagrams at [Mermaid Live Editor](https://mermaid.live/).

  ## References

  - [Mermaid Syntax](https://mermaid.js.org/syntax/flowchart.html)
  - [GitHub Mermaid Docs](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams)

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

  Each shape has a specific Mermaid syntax:
  - `:rounded_rect` - `[label]` - Rectangle with rounded corners
  - `:stadium` - `([label])` - Stadium shape (pill)
  - `:subroutine` - `[[label]]` - Subroutine shape (rectangle with side lines)
  - `:cylinder` - `[(label)]` - Cylindrical shape (database)
  - `:circle` - `((label))` - Circle
  - `:asymmetric` - `>label]` - Asymmetric shape (flag)
  - `:rhombus` - `{label}` - Rhombus (decision)
  - `:hexagon` - `{{label}}` - Hexagon
  - `:parallelogram` - `[/label/]` - Parallelogram
  - `:parallelogram_alt` - `[\\label\\]` - Parallelogram alt
  - `:trapezoid` - `[/label\\]` - Trapezoid
  - `:trapezoid_alt` - `[\\label/]` - Trapezoid alt
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

  @typedoc """
  CSS length unit for styling.

  Mermaid supports various CSS length units:
  - `:px` - Pixels (most common)
  - `:em` - Ems (relative to font size)
  - `:rem` - Rems (relative to root font size)
  - `:percent` - Percentage
  - `{:custom, string}` - Custom CSS value (for advanced users)
  """
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
          node_ids: [Yog.node_id()] | nil
        }

  @typedoc "Options for customizing Mermaid diagram rendering"
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
          # Graph-level attributes
          direction: direction(),
          # Node styling
          node_shape: node_shape(),
          highlight_fill: String.t(),
          highlight_stroke: String.t(),
          highlight_stroke_width: css_length(),
          # Edge styling
          link_thickness: css_length(),
          highlight_link_stroke: String.t(),
          highlight_link_stroke_width: css_length()
        }

  @doc """
  Creates default Mermaid options with simple labeling.

  Uses node ID as label and edge weight as-is.
  Default configuration:
  - Direction: Top-to-bottom (TD)
  - Node shape: Rounded rectangle
  - Highlight: Yellow fill with orange stroke

  ## Examples

      iex> opts = Yog.Render.Mermaid.default_options()
      iex> opts.direction
      :td
      iex> opts.node_shape
      :rounded_rect
      iex> opts.highlight_fill
      "#ffeb3b"
  """
  @spec default_options() :: options()
  def default_options do
    %{
      node_label: &Yog.Utils.to_label/2,
      edge_label: &Yog.Utils.to_weight_label/1,
      highlighted_nodes: nil,
      highlighted_edges: nil,
      # Per-element styling defaults
      node_attributes: fn _, _ -> [] end,
      edge_attributes: fn _, _, _ -> [] end,
      # Subgraphs
      subgraphs: nil,
      # Graph-level
      direction: :td,
      # Node styling
      node_shape: :rounded_rect,
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
  Creates default Mermaid options with a custom edge formatter.

  Use this when your graph has non-String edge data (e.g., Int, Float, custom types).

  ## Example

      # For a graph with Int edge weights
      options = Yog.Render.Mermaid.default_options_with_edge_formatter(fn weight ->
        Integer.to_string(weight)
      end)
  """
  @spec default_options_with_edge_formatter((any() -> String.t())) :: options()
  def default_options_with_edge_formatter(edge_formatter) do
    %{default_options() | edge_label: edge_formatter}
  end

  @doc """
  Creates default Mermaid options with custom label formatters for both nodes and edges.

  ## Example

      options = Yog.Render.Mermaid.default_options_with(
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
  Converts a graph to Mermaid diagram syntax.

  The graph's node data and edge data must be convertible to strings.
  Use the options to customize labels, styling, and to define subgraphs.

  **Time Complexity:** O(V + E + S) where S is the total number of nodes
  across all subgraphs.

  ## Example

      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "Process")
        |> Yog.add_node(3, "End")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")
        |> Yog.add_edge_ensure(from: 2, to: 3, with: "3")

      # Basic rendering
      diagram = Yog.Render.Mermaid.to_mermaid(graph, default_options())

      # Highlight a path
      options = %{
        default_options() |
        highlighted_nodes: [1, 2, 3],
        highlighted_edges: [{1, 2}, {2, 3}]
      }
      highlighted = Yog.Render.Mermaid.to_mermaid(graph, options)

  The output can be embedded in markdown:
  ````markdown
  ```mermaid
  graph TD
    1["Start"]
    2["Process"]
    3["End"]
    1 -->|5| 2
    2 -->|3| 3
  ```
  ````
  """
  @spec to_mermaid(Yog.graph(), options()) :: String.t()
  def to_mermaid(graph, options \\ default_options()) do
    nodes = extract_nodes(graph)
    edges = extract_edges(graph)
    kind = extract_kind(graph)

    # Graph type and direction
    graph_type = "graph #{direction_to_string(options.direction)}\n"

    # Style definitions for highlighting
    styles =
      if options.highlighted_nodes || options.highlighted_edges do
        node_highlight =
          "  classDef highlight fill:#{options.highlight_fill},stroke:#{options.highlight_stroke},stroke-width:#{css_length_to_string(options.highlight_stroke_width)}\n"

        edge_highlight =
          "  classDef highlightEdge stroke:#{options.highlight_link_stroke},stroke-width:#{css_length_to_string(options.highlight_link_stroke_width)}\n"

        node_highlight <> edge_highlight
      else
        ""
      end

    # Convert highlight lists to MapSets for O(1) membership checks
    hl_nodes = to_mapset(options.highlighted_nodes)
    hl_edges = to_edge_set(options.highlighted_edges)
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

  @doc """
  Converts a shortest path result to highlighted Mermaid options.

  Creates a copy of the base options with the path's nodes and edges
  set to be highlighted.

  ## Example

      case Yog.Pathfinding.Dijkstra.shortest_path(...) do
        {:ok, path} ->
          options = Yog.Render.Mermaid.path_to_options(path, Yog.Render.Mermaid.default_options())
          mermaid = Yog.Render.Mermaid.to_mermaid(graph, options)
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
  Returns a pre-configured theme as Mermaid options.

  Available themes:
  - `:default` — Yellow highlight, orange stroke (same as `default_options/0`)
  - `:dark` — Dark-friendly colors with neon accent colors
  - `:minimal` — Clean wireframe look with no fills and thin lines
  - `:presentation` — Large strokes and bold colors for slides and demos

  ## Examples

      iex> opts = Yog.Render.Mermaid.theme(:dark)
      iex> opts.highlight_fill
      "#16213e"
      iex> opts.highlight_stroke
      "#e94560"

      iex> opts = Yog.Render.Mermaid.theme(:minimal)
      iex> opts.link_thickness
      {:px, 1}

      iex> opts = Yog.Render.Mermaid.theme(:presentation)
      iex> opts.highlight_stroke_width
      {:px, 4}
  """
  @spec theme(atom()) :: options()
  def theme(:default), do: default_options()

  def theme(:dark) do
    %{
      default_options()
      | highlight_fill: "#16213e",
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
      | highlight_fill: "#ffffff",
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
      | highlight_fill: "#4361ee",
        highlight_stroke: "#f72585",
        highlight_stroke_width: {:px, 4},
        link_thickness: {:px, 3},
        highlight_link_stroke: "#f72585",
        highlight_link_stroke_width: {:px, 4}
    }
  end

  @doc """
  Creates Mermaid options that highlight an MST result.

  MST edges are highlighted and MST nodes use default styling.

  ## Example

      result = Yog.MST.kruskal(graph)
      options = Yog.Render.Mermaid.mst_to_options(result)
      mermaid = Yog.Render.Mermaid.to_mermaid(graph, options)
  """
  @spec mst_to_options(Yog.MST.Result.t(), options()) :: options()
  def mst_to_options(%{edges: edges}, base_options \\ default_options()) do
    mst_edges = Enum.map(edges, fn %{from: f, to: t} -> {f, t} end)
    mst_nodes = Enum.flat_map(edges, fn %{from: f, to: t} -> [f, t] end) |> Enum.uniq()
    %{base_options | highlighted_edges: mst_edges, highlighted_nodes: mst_nodes}
  end

  @doc """
  Creates Mermaid options that color nodes by community assignment.

  Each community gets a distinct color from a generated palette. The palette
  cycles through visually distinct hues using inline node styles.

  ## Example

      result = Yog.Community.Louvain.detect(graph)
      options = Yog.Render.Mermaid.community_to_options(result)
      mermaid = Yog.Render.Mermaid.to_mermaid(graph, options)
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
        cid -> [{:fill, Map.get(color_map, cid, "#eeeeee")}, {:stroke, "#333333"}]
      end
    end

    %{base_options | node_attributes: node_attrs}
  end

  @doc """
  Creates Mermaid options that color the source and sink sides of a min-cut.

  Source-side nodes are colored with `source_color` (default: light blue),
  sink-side nodes with `sink_color` (default: light coral).

  Requires the `MinCutResult` to have `source_side` and `sink_side` populated
  (use `track_partitions: true` or `extract_min_cut/1`).

  ## Example

      result = Yog.Flow.MinCut.global_min_cut(graph, track_partitions: true)
      options = Yog.Render.Mermaid.cut_to_options(result)
      mermaid = Yog.Render.Mermaid.to_mermaid(graph, options)
  """
  @spec cut_to_options(Yog.Flow.MinCutResult.t(), options()) :: options()
  def cut_to_options(%{source_side: source, sink_side: sink}, base_options \\ default_options()) do
    source_set = if source, do: MapSet.new(source), else: MapSet.new()
    sink_set = if sink, do: MapSet.new(sink), else: MapSet.new()

    node_attrs = fn id, _data ->
      cond do
        MapSet.member?(source_set, id) -> [{:fill, "#a8d8ea"}, {:stroke, "#0288d1"}]
        MapSet.member?(sink_set, id) -> [{:fill, "#f08080"}, {:stroke, "#c62828"}]
        true -> []
      end
    end

    %{base_options | node_attributes: node_attrs}
  end

  @doc """
  Creates Mermaid options that highlight matched edges from a matching result.

  Works with results from both `Yog.Matching.hopcroft_karp/1` and
  `Yog.Matching.hungarian/2` (the matching map component).

  ## Example

      matching = Yog.Matching.hopcroft_karp(graph)
      options = Yog.Render.Mermaid.matching_to_options(matching)
      mermaid = Yog.Render.Mermaid.to_mermaid(graph, options)
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

  defp to_mapset(nil), do: nil
  defp to_mapset(list) when is_list(list), do: MapSet.new(list)
  defp to_mapset(%MapSet{} = set), do: set

  defp to_edge_set(nil), do: nil
  defp to_edge_set(list) when is_list(list), do: MapSet.new(list)
  defp to_edge_set(%MapSet{} = set), do: set

  defp build_node_lines(nodes, options) do
    Enum.map_join(nodes, "\n", fn {id, data} ->
      label = options.node_label.(id, data)
      node_def = "  #{Yog.Utils.safe_string(id)}#{node_shape_brackets(options.node_shape, label)}"

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
            {:stroke_width, css_length_to_string(options.highlight_stroke_width)}
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
    # Mermaid subgraph names with spaces need quotes
    if String.contains?(name, " ") do
      "\"#{name}\""
    else
      name
    end
  end

  defp build_edge_lines(edges, options, kind) do
    flat_edges =
      edges
      |> Enum.flat_map(fn {from_id, targets} ->
        targets
        |> Enum.filter(fn {to_id, _weight} ->
          # For undirected graphs, only render each edge once (when from_id <= to_id)
          case kind do
            :undirected -> from_id <= to_id
            _ -> true
          end
        end)
        |> Enum.map(fn {to_id, weight} -> {from_id, to_id, weight} end)
      end)

    {edge_declarations, link_styles} =
      flat_edges
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{from_id, to_id, weight}, idx}, {defs_acc, styles_acc} ->
        # Choose arrow style based on graph type
        arrow =
          case kind do
            :directed -> "-->"
            :undirected -> "---"
          end

        label = options.edge_label.(weight)
        label_part = if label == "", do: "", else: "|#{label}|"

        edge_def =
          "  #{Yog.Utils.safe_string(from_id)} #{arrow}#{label_part} #{Yog.Utils.safe_string(to_id)}"

        # Check if this edge should be highlighted
        is_highlighted =
          options.highlighted_edges &&
            (MapSet.member?(options.highlighted_edges, {from_id, to_id}) ||
               MapSet.member?(options.highlighted_edges, {to_id, from_id}))

        # Build custom edge attributes
        custom_attrs = options.edge_attributes.(from_id, to_id, weight)

        {style_attrs, has_style} =
          if is_highlighted do
            attrs =
              [
                {:stroke, options.highlight_link_stroke},
                {:stroke_width, css_length_to_string(options.highlight_link_stroke_width)}
              ] ++ custom_attrs

            {attrs, true}
          else
            if custom_attrs != [] do
              base_width = css_length_to_string(options.link_thickness)

              attrs =
                [{:stroke_width, base_width} | custom_attrs]
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

  # Helper to convert a list of nodes to a list of edges
  defp path_to_edges(nodes), do: do_path_to_edges(nodes, [])

  defp do_path_to_edges([], acc), do: Enum.reverse(acc)
  defp do_path_to_edges([_], acc), do: Enum.reverse(acc)

  defp do_path_to_edges([first, second | rest], acc) do
    do_path_to_edges([second | rest], [{first, second} | acc])
  end

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

  # =============================================================================
  # ENUM TO STRING CONVERSIONS
  # =============================================================================

  @doc false
  @spec direction_to_string(direction()) :: String.t()
  def direction_to_string(:td), do: "TD"
  def direction_to_string(:lr), do: "LR"
  def direction_to_string(:bt), do: "BT"
  def direction_to_string(:rl), do: "RL"

  @doc false
  @spec css_length_to_string(css_length()) :: String.t()
  def css_length_to_string({:px, n}), do: "#{n}px"
  def css_length_to_string({:em, f}), do: "#{f}em"
  def css_length_to_string({:rem, f}), do: "#{f}rem"
  def css_length_to_string({:percent, f}), do: "#{f}%"
  def css_length_to_string({:custom, s}), do: s

  @doc false
  @spec node_shape_brackets(node_shape(), String.t()) :: String.t()
  def node_shape_brackets(:rounded_rect, label), do: "[\"#{escape_label(label)}\"]"
  def node_shape_brackets(:stadium, label), do: "([\"#{escape_label(label)}\"])"
  def node_shape_brackets(:subroutine, label), do: "[[\"#{escape_label(label)}\"]]"
  def node_shape_brackets(:cylinder, label), do: "[(\"#{escape_label(label)}\")]"
  def node_shape_brackets(:circle, label), do: "((\"#{escape_label(label)}\"))"
  def node_shape_brackets(:asymmetric, label), do: ">\"#{escape_label(label)}\"]"
  def node_shape_brackets(:rhombus, label), do: "{\"#{escape_label(label)}\"}"
  def node_shape_brackets(:hexagon, label), do: "{{\"#{escape_label(label)}\"}}"
  def node_shape_brackets(:parallelogram, label), do: "[/\"#{escape_label(label)}\"/]"

  def node_shape_brackets(:parallelogram_alt, label),
    do: "[\\\"#{escape_label(label)}\"\\]"

  def node_shape_brackets(:trapezoid, label), do: "[/\"#{escape_label(label)}\"\\]"
  def node_shape_brackets(:trapezoid_alt, label), do: "[\\\"#{escape_label(label)}\"/]"

  # Escape special characters in labels for Mermaid
  defp escape_label(label) do
    label
    |> String.replace("\"", "#quot;")
    |> String.replace("\n", "<br/>")
  end
end
