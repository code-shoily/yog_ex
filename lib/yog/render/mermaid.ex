defmodule Yog.Render.Mermaid do
  @moduledoc """
  Mermaid.js format export for embedding diagrams in web pages and documents.

  This module exports graphs to [Mermaid](https://mermaid.js.org/) syntax,
  a JavaScript-based diagramming tool that renders diagrams from text definitions.
  Mermaid is supported natively in GitHub, GitLab, Notion, and many other platforms.

  ## Quick Start

      # Export to Mermaid syntax
      mermaid = Yog.Render.Mermaid.to_mermaid(my_graph, Yog.Render.Mermaid.default_options())

      # Use in Markdown
      ```mermaid
      graph TD
          A[Node 1] --> B[Node 2]
      ```

  ## Supported Diagram Types

  This module generates flowchart-style diagrams:
  - **Graph TD**: Top-down (vertical) layout
  - **Graph LR**: Left-to-right (horizontal) layout
  - **Graph BT**: Bottom-to-top layout
  - **Graph RL**: Right-to-left layout

  ## Customization

  Control styling via `t:options/0`:
  - Node shapes (rounded, rectangular, circular)
  - Labels and edge annotations
  - Highlight specific nodes or edges
  - Direction and orientation

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

  - [Mermaid Documentation](https://mermaid.js.org/intro/)
  - [Flowchart Syntax](https://mermaid.js.org/syntax/flowchart.html)
  - [GitHub Mermaid Support](https://github.blog/2022-02-14-include-diagrams-markdown-files-mermaid/)
  """

  @typedoc "Diagram direction/orientation"
  @type direction :: :td | :lr | :bt | :rl

  @typedoc "Node visual style"
  @type node_shape :: :rounded_rect | :circle | :rhombus | :stadium | :subroutine | :cylinder

  @typedoc "Options for customizing Mermaid.js diagram rendering"
  @type options :: %{
          direction: direction(),
          node_shape: node_shape(),
          node_label: (Yog.node_id(), any() -> String.t()),
          edge_label: (any() -> String.t()),
          highlighted_nodes: [Yog.node_id()] | nil,
          highlighted_edges: [{Yog.node_id(), Yog.node_id()}] | nil,
          highlight_fill: String.t(),
          highlight_stroke: String.t()
        }

  @doc """
  Creates default Mermaid options with top-down layout and rounded rectangles.

  Default styling:
  - Direction: Top-down
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
      direction: :td,
      node_shape: :rounded_rect,
      node_label: fn id, _data -> "Node #{id}" end,
      edge_label: fn weight ->
        case weight do
          nil -> ""
          "" -> ""
          w -> to_string(w)
        end
      end,
      highlighted_nodes: nil,
      highlighted_edges: nil,
      highlight_fill: "#ffeb3b",
      highlight_stroke: "#f57c00"
    }
  end

  @doc """
  Converts a graph to Mermaid.js flowchart syntax.

  Works with any node data type. The default options use a simple label
  showing the node ID, but you can customize with your own label function.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Start")
      ...> |> Yog.add_node(2, "End")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "5")
      iex> mermaid = Yog.Render.Mermaid.to_mermaid(graph, Yog.Render.Mermaid.default_options())
      iex> String.contains?(mermaid, "graph TD")
      true
      iex> String.contains?(mermaid, "-->")
      true

      # Undirected graph
      iex> undirected = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "1")
      iex> mermaid = Yog.Render.Mermaid.to_mermaid(undirected, Yog.Render.Mermaid.default_options())
      iex> String.contains?(mermaid, "---")
      true
      iex> refute String.contains?(mermaid, "-->")
  """
  @spec to_mermaid(Yog.graph(), options()) :: String.t()
  def to_mermaid(graph, options) do
    nodes = extract_nodes(graph)
    edges = extract_edges(graph)
    kind = extract_kind(graph)

    # Graph type and direction
    dir_str = direction_to_string(options.direction)
    arrow = if kind == :directed, do: "-->", else: "---"

    [
      "graph #{dir_str}",
      build_highlight_defs(options)
      | build_node_lines(nodes, options) ++
          build_edge_lines(edges, options, arrow)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp extract_nodes(graph) do
    case graph do
      %{nodes: n} when is_map(n) -> n
      {:graph, _, n, _, _} when is_map(n) -> n
      _ -> %{}
    end
  end

  defp extract_edges(graph) do
    case graph do
      %{out_edges: e} when is_map(e) -> e
      {:graph, _, _, e, _} when is_map(e) -> e
      _ -> %{}
    end
  end

  defp extract_kind(graph) do
    case graph do
      %{kind: k} -> k
      {:graph, k, _, _, _} -> k
      _ -> :directed
    end
  end

  defp build_highlight_defs(options) do
    if options.highlighted_nodes != nil or options.highlighted_edges != nil do
      "  classDef highlight fill:#{options.highlight_fill},stroke:#{options.highlight_stroke},stroke-width:3px"
    else
      ""
    end
  end

  defp build_node_lines(nodes, options) do
    Enum.map(nodes, fn {id, data} ->
      label = options.node_label.(id, data)
      brackets = node_shape_brackets(options.node_shape, label)
      line = "  #{id}#{brackets}"

      if node_highlighted?(id, options) do
        line <> ":::highlight"
      else
        line
      end
    end)
  end

  defp node_highlighted?(id, options) do
    options.highlighted_nodes != nil and id in options.highlighted_nodes
  end

  defp build_edge_lines(edges, options, arrow) do
    Enum.flat_map(edges, fn {from, targets} ->
      build_edge_lines_for_node(from, targets, options, arrow)
    end)
  end

  defp build_edge_lines_for_node(from, targets, options, arrow) do
    if is_map(targets) do
      Enum.map(targets, fn {to, weight} ->
        build_single_edge_line(from, to, weight, arrow, options)
      end)
    else
      []
    end
  end

  defp build_single_edge_line(from, to, weight, arrow, options) do
    label = options.edge_label.(weight)

    edge_str =
      if label != "" do
        "  #{from} #{arrow}|\"#{label}\"| #{to}"
      else
        "  #{from} #{arrow} #{to}"
      end

    if edge_highlighted?(from, to, options) do
      edge_str <> ":::highlight"
    else
      edge_str
    end
  end

  defp edge_highlighted?(from, to, options) do
    edges = options.highlighted_edges

    edges != nil and
      ({from, to} in edges or {to, from} in edges)
  end

  defp direction_to_string(:td), do: "TD"
  defp direction_to_string(:lr), do: "LR"
  defp direction_to_string(:bt), do: "BT"
  defp direction_to_string(:rl), do: "RL"

  defp node_shape_brackets(:rounded_rect, label), do: "[\"#{label}\"]"
  defp node_shape_brackets(:stadium, label), do: "([\"#{label}\"])"
  defp node_shape_brackets(:subroutine, label), do: "[[\"#{label}\"]]"
  defp node_shape_brackets(:cylinder, label), do: "[(\"#{label}\")]"
  defp node_shape_brackets(:circle, label), do: "((\"#{label}\"))"
  defp node_shape_brackets(:rhombus, label), do: "{\"#{label}\"}"
  defp node_shape_brackets(_, label), do: "[\"#{label}\"]"

  @doc """
  Converts a shortest path result to highlighted Mermaid options.

  Creates a copy of the base options with the path's nodes and edges
  set to be highlighted. This is useful for visualizing algorithm results.

  ## Examples

      iex> base_opts = Yog.Render.Mermaid.default_options()
      iex> path = %{nodes: [1, 2, 3], weight: 10}
      iex> highlighted_opts = Yog.Render.Mermaid.path_to_options(path, base_opts)
      iex> highlighted_opts.highlighted_nodes
      [1, 2, 3]
      iex> highlighted_opts.highlighted_edges
      [{1, 2}, {2, 3}]
  """
  @spec path_to_options(map(), options()) :: options()
  def path_to_options(path, base_options) do
    nodes = path.nodes
    edges = path_to_edges(nodes)

    Map.merge(base_options, %{
      highlighted_nodes: nodes,
      highlighted_edges: edges
    })
  end

  defp path_to_edges([]), do: []
  defp path_to_edges([_]), do: []

  defp path_to_edges([first, second | rest]) do
    [{first, second} | path_to_edges([second | rest])]
  end
end
