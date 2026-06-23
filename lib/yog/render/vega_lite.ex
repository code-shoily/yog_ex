defmodule Yog.Render.VegaLite do
  @moduledoc """
  Vega-Lite plot specification generator for graph layouts.

  This module requires the optional `vega_lite` dependency. It constructs and returns
  a `%VegaLite{}` specification structure representing the layered coordinates plot.
  """

  alias Yog.Graph

  @doc """
  Compiles the graph and its layout coordinates into a Vega-Lite spec.

  ## Options

    * `:width` - Pixel width of the plot (default: `500`).
    * `:height` - Pixel height of the plot (default: `400`).
    * `:node_color` - Hex color code for nodes (default: `"#3b82f6"`).
    * `:node_size` - Size parameter for circles (default: `400`).
    * `:edge_color` - Hex color code for edge lines (default: `"#9ca3af"`).
    * `:edge_width` - Line width for edges (default: `2`).

  ## Examples

      # In your mix.exs: {:vega_lite, "~> 0.1", optional: true}
      # Then inside a Livebook:
      iex> graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])
      iex> pos = Yog.Layout.circular(graph)
      iex> spec = Yog.Render.VegaLite.to_spec(graph, pos)
      iex> is_struct(spec, VegaLite)
      true

  """
  @spec to_spec(Graph.t(), %{Graph.node_id() => {float(), float()}}, keyword()) :: struct()
  def to_spec(graph, positions, opts \\ []) do
    unless Code.ensure_loaded?(VegaLite) do
      raise RuntimeError,
            "VegaLite module is not loaded. Please add `{:vega_lite, \"~> 0.1\"}` to your dependencies."
    end

    width = Keyword.get(opts, :width, 500)
    height = Keyword.get(opts, :height, 400)
    node_color = Keyword.get(opts, :node_color, "#3b82f6")
    node_size = Keyword.get(opts, :node_size, 400)
    edge_color = Keyword.get(opts, :edge_color, "#9ca3af")
    edge_width = Keyword.get(opts, :edge_width, 2)

    # Format Node Data
    node_data =
      Enum.map(positions, fn {id, {x, y}} ->
        %{"id" => to_string(id), "x" => x, "y" => y}
      end)

    # Format Edge Data
    edge_data =
      graph
      |> Yog.all_edges()
      |> Enum.flat_map(fn {src, dst, _} ->
        case {Map.get(positions, src), Map.get(positions, dst)} do
          {{x1, y1}, {x2, y2}} ->
            [
              %{"edge_group" => "#{src}-#{dst}", "x" => x1, "y" => y1},
              %{"edge_group" => "#{src}-#{dst}", "x" => x2, "y" => y2}
            ]

          _ ->
            []
        end
      end)

    VegaLite.new(width: width, height: height, background: "#f8fafc")
    |> VegaLite.data_from_values(node_data)
    |> VegaLite.encode_field(:x, "x",
      type: :quantitative,
      scale: [zero: false],
      axis: [title: nil, labels: false, ticks: false]
    )
    |> VegaLite.encode_field(:y, "y",
      type: :quantitative,
      scale: [zero: false],
      axis: [title: nil, labels: false, ticks: false]
    )
    |> VegaLite.layers([
      # Layer 1: Edges
      VegaLite.new()
      |> VegaLite.data_from_values(edge_data)
      |> VegaLite.mark(:line, stroke_width: edge_width, color: edge_color)
      |> VegaLite.encode_field(:detail, "edge_group"),

      # Layer 2: Nodes
      VegaLite.new()
      |> VegaLite.mark(:circle,
        size: node_size,
        color: node_color,
        opacity: 1.0,
        stroke: "#1e3a8a",
        stroke_width: 1.5
      ),

      # Layer 3: Labels
      VegaLite.new()
      |> VegaLite.mark(:text, dy: 4, color: "white", font_weight: "bold", font_size: 11)
      |> VegaLite.encode_field(:text, "id", type: :nominal)
    ])
  end
end
