defmodule Yog.Render.SVG do
  @moduledoc """
  Pure Elixir SVG visualization generator for graphs.

  This module renders a graph and its associated 2D layout coordinates (computed
  by `Yog.Layout` functions) into a raw XML/SVG string. The output can be written
  to a file, rendered directly in Phoenix/LiveView templates, or displayed in Livebook
  (by wrapping it in `Kino.HTML.new/1`).

  ## Styling Options

  Customize elements by passing options:
  - Node radius and color.
  - Node stroke color and stroke width.
  - Edge color and stroke width.
  - Show/hide text labels inside nodes.
  """

  alias Yog.Graph

  @doc """
  Generates a raw XML/SVG string representing the graph layout.

  ## Options

    * `:width` - The canvas pixel width (default: `600`).
    * `:height` - The canvas pixel height (default: `400`).
    * `:padding` - Bounding space padding around layout margins (default: `40`).
    * `:node_radius` - Radius of node circles (default: `12`).
    * `:node_color` - Fill color of nodes (default: `"#3b82f6"`).
    * `:node_stroke` - Stroke color of nodes (default: `"#1e3a8a"`).
    * `:node_stroke_width` - Node stroke width (default: `2`).
    * `:edge_color` - Stroke color of edges (default: `"#9ca3af"`).
    * `:edge_width` - Stroke width of edges (default: `2`).
    * `:show_labels` - Boolean indicating whether to show node ID text labels (default: `true`).
    * `:text_color` - Text color for node labels (default: `"white"`).
    * `:text_size` - Font size for node labels (default: `10`).

  ## Examples

      iex> graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])
      iex> pos = Yog.Layout.circular(graph)
      iex> svg = Yog.Render.SVG.to_svg(graph, pos)
      iex> String.starts_with?(svg, "<svg")
      true

  """
  @spec to_svg(Graph.t(), %{Graph.node_id() => {float(), float()}}, keyword()) :: String.t()
  def to_svg(graph, positions, opts \\ []) do
    width = Keyword.get(opts, :width, 600)
    height = Keyword.get(opts, :height, 400)
    padding = Keyword.get(opts, :padding, 40)
    node_radius = Keyword.get(opts, :node_radius, 12)
    node_color = Keyword.get(opts, :node_color, "#3b82f6")
    node_stroke = Keyword.get(opts, :node_stroke, "#1e3a8a")
    node_stroke_width = Keyword.get(opts, :node_stroke_width, 2)
    edge_color = Keyword.get(opts, :edge_color, "#9ca3af")
    edge_width = Keyword.get(opts, :edge_width, 2)
    show_labels = Keyword.get(opts, :show_labels, true)
    text_color = Keyword.get(opts, :text_color, "white")
    text_size = Keyword.get(opts, :text_size, 10)

    scaled_positions = scale_to_pixels(positions, width, height, padding)

    edges_svg =
      graph
      |> Yog.all_edges()
      |> Enum.map(fn {src, dst, _} ->
        case {Map.get(scaled_positions, src), Map.get(scaled_positions, dst)} do
          {{x1, y1}, {x2, y2}} ->
            ~s(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{edge_color}" stroke-width="#{edge_width}" />)

          _ ->
            ""
        end
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n  ")

    nodes_svg =
      scaled_positions
      |> Enum.map(fn {node_id, {x, y}} ->
        label =
          if show_labels do
            ~s(<text x="#{x}" y="#{y + 4}" font-family="sans-serif" font-size="#{text_size}" fill="#{text_color}" font-weight="bold" text-anchor="middle">#{node_id}</text>)
          else
            ""
          end

        ~s"""
        <g>
            <circle cx="#{x}" cy="#{y}" r="#{node_radius}" fill="#{node_color}" stroke="#{node_stroke}" stroke-width="#{node_stroke_width}" />
            #{label}
          </g>
        """
      end)
      |> Enum.join("\n  ")

    """
    <svg width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" style="background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px;">
      #{edges_svg}
      #{nodes_svg}
    </svg>
    """
  end

  defp scale_to_pixels(positions, w, h, padding) do
    pos_values = Map.values(positions)

    {min_x, max_x, min_y, max_y} =
      case pos_values do
        [] ->
          {0.0, 0.0, 0.0, 0.0}

        [{x0, y0} | rest] ->
          Enum.reduce(rest, {x0, x0, y0, y0}, fn {x, y}, {min_x, max_x, min_y, max_y} ->
            {min(min_x, x), max(max_x, x), min(min_y, y), max(max_y, y)}
          end)
      end

    w_span = max_x - min_x
    h_span = max_y - min_y

    Map.new(positions, fn {id, {x, y}} ->
      px = if w_span > 0, do: padding + (x - min_x) * (w - 2 * padding) / w_span, else: w / 2.0
      py = if h_span > 0, do: padding + (y - min_y) * (h - 2 * padding) / h_span, else: h / 2.0
      {id, {px, py}}
    end)
  end
end
