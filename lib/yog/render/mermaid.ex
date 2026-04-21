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
  - Direction and orientation
  - CSS-based styling with custom lengths

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

  @typedoc "Options for customizing Mermaid diagram rendering"
  @type options :: %{
          node_label: (Yog.node_id(), any() -> String.t()),
          edge_label: (any() -> String.t()),
          highlighted_nodes: [Yog.node_id()] | nil,
          highlighted_edges: [{Yog.node_id(), Yog.node_id()}] | nil,
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
  Converts a graph to Mermaid diagram syntax.

  The graph's node data and edge data must be convertible to strings.
  Use the options to customize labels and highlight specific paths.

  **Time Complexity:** O(V + E)

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

    # Generate node declarations
    nodes_str = build_node_lines(nodes, options)

    # Generate edge declarations
    edges_str = build_edge_lines(edges, options, kind)

    graph_type <> styles <> nodes_str <> "\n" <> edges_str
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

  defp build_node_lines(nodes, options) do
    Enum.map_join(nodes, "\n", fn {id, data} ->
      label = options.node_label.(id, data)
      node_def = "  #{Yog.Utils.safe_string(id)}#{node_shape_brackets(options.node_shape, label)}"

      # Add highlight class if this node is in the highlighted list
      if options.highlighted_nodes && id in options.highlighted_nodes do
        node_def <> ":::highlight"
      else
        node_def
      end
    end)
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
            ({from_id, to_id} in options.highlighted_edges ||
               {to_id, from_id} in options.highlighted_edges)

        if is_highlighted do
          style_str =
            "  linkStyle #{idx} stroke:#{options.highlight_link_stroke},stroke-width:#{css_length_to_string(options.highlight_link_stroke_width)}"

          {[edge_def | defs_acc], [style_str | styles_acc]}
        else
          {[edge_def | defs_acc], styles_acc}
        end
      end)

    edges_str =
      edge_declarations
      |> Enum.reverse()
      |> Enum.join("\n")

    styles_str =
      link_styles
      |> Enum.reverse()
      |> Enum.join("\n")

    if String.trim(styles_str) == "" do
      edges_str
    else
      edges_str <> "\n" <> styles_str
    end
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
