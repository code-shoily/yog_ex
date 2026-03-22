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
    nodes =
      case graph do
        %{nodes: n} when is_map(n) -> n
        {:graph, _, n, _, _} when is_map(n) -> n
        _ -> %{}
      end

    edges =
      case graph do
        %{out_edges: e} when is_map(e) -> e
        {:graph, _, _, e, _} when is_map(e) -> e
        _ -> %{}
      end

    kind =
      case graph do
        %{kind: k} -> k
        {:graph, k, _, _, _} -> k
        _ -> :directed
      end

    # Graph type and direction
    dir = direction_to_string(options.direction)
    lines = ["graph #{dir}"]

    # Style definitions for highlighting
    styles =
      if options.highlighted_nodes != nil or options.highlighted_edges != nil do
        [
          "  classDef highlight fill:#{options.highlight_fill},stroke:#{options.highlight_stroke},stroke-width:3px"
        ]
      else
        []
      end

    lines = lines ++ styles

    # Generate node declarations
    node_lines =
      Enum.map(nodes, fn {id, data} ->
        label = options.node_label.(id, data)
        brackets = node_shape_brackets(options.node_shape, label)

        line = "  #{id}#{brackets}"

        # Add highlight class if applicable
        if options.highlighted_nodes != nil and id in options.highlighted_nodes do
          line <> ":::highlight"
        else
          line
        end
      end)

    lines = lines ++ node_lines

    # Generate edge declarations
    arrow = if kind == :directed, do: "-->", else: "---"

    edge_lines =
      Enum.flat_map(edges, fn {from, targets} ->
        case targets do
          t when is_map(t) ->
            Enum.map(t, fn {to, weight} ->
              label = options.edge_label.(weight)

              edge_str =
                if label != "" do
                  "  #{from} #{arrow}|\"#{label}\"| #{to}"
                else
                  "  #{from} #{arrow} #{to}"
                end

              # Add highlight class if applicable
              if options.highlighted_edges != nil and
                   ({from, to} in options.highlighted_edges or
                      {to, from} in options.highlighted_edges) do
                edge_str <> ":::highlight"
              else
                edge_str
              end
            end)

          _ ->
            []
        end
      end)

    lines = lines ++ edge_lines

    Enum.join(lines, "\n")
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
