defmodule Yog.Layout.Multipartite do
  @moduledoc """
  Multipartite layout algorithm for positioning graph nodes in parallel layers.

  Arranges nodes in straight parallel lines (either vertical columns or horizontal rows)
  based on their partition/layer membership. This layout is standard for bipartite
  graphs, feedforward neural network visualizations, flow networks, or any layered
  hierarchical relationships.

  ## Mathematical Model

  Given a list of layers $L = [L_0, L_1, \\dots, L_{M-1}]$, where each $L_j$ is a list of node IDs, a bounding space of size $W \\times H$, and center $(c_x, c_y)$:

  If `:align` is `:vertical` (default):
  1. The $x$-coordinate for all nodes in layer $L_j$ is:
     $$x_j = \\left(c_x - \\frac{W}{2}\\right) + \\frac{j \\cdot W}{M - 1}$$
     (or $c_x$ if $M = 1$).
  2. For the $i$-th node in layer $L_j$ (where $0 \\le i < K$ and $K = |L_j|$):
     $$y_i = \\left(c_y - \\frac{H}{2}\\right) + \\frac{i \\cdot H}{K - 1}$$
     (or $c_y$ if $K = 1$).

  If `:align` is `:horizontal`:
  1. The $y$-coordinate for all nodes in layer $L_j$ is:
     $$y_j = \\left(c_y - \\frac{H}{2}\\right) + \\frac{j \\cdot H}{M - 1}$$
     (or $c_y$ if $M = 1$).
  2. For the $i$-th node in layer $L_j$ (where $0 \\le i < K$ and $K = |L_j|$):
     $$x_i = \\left(c_x - \\frac{W}{2}\\right) + \\frac{i \\cdot W}{K - 1}$$
     (or $c_x$ if $K = 1$).

  ## Complexities

  * **Time Complexity:** $O(V)$ where $V$ is the number of nodes.
  * **Space Complexity:** $O(V)$ auxiliary space.
  """

  alias Yog.Graph

  @doc """
  Positions nodes in parallel layers (columns or rows).

  Requires a list of layers, where each layer is a list of node IDs.

  ## Options

    * `:align` - Layer alignment direction: `:vertical` or `:horizontal` (default: `:vertical`).
    * `:width` - Bounding width (default: `1.0`).
    * `:height` - Bounding height (default: `1.0`).
    * `:center` - Center of layout space (default: `{0.0, 0.0}`).

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3])
      iex> pos = Yog.Layout.Multipartite.layout(graph, [[1], [2, 3]])
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

  """
  @spec layout(Graph.t(), [[Graph.node_id()]], keyword()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def layout(graph, layers, opts \\ []) do
    align = Keyword.get(opts, :align, :vertical)
    width = Keyword.get(opts, :width, 1.0)
    height = Keyword.get(opts, :height, 1.0)
    {cx, cy} = Keyword.get(opts, :center, {0.0, 0.0})

    nodes = Yog.all_nodes(graph)
    m = length(layers)

    cond do
      m == 0 ->
        %{}

      align not in [:vertical, :horizontal] ->
        raise ArgumentError, "Option :align must be either :vertical or :horizontal"

      Enum.any?(layers, &Enum.empty?/1) ->
        raise ArgumentError, "Layers must not contain empty lists"

      Enum.any?(layers, fn layer -> Enum.any?(layer, fn id -> id not in nodes end) end) ->
        raise ArgumentError, "All layer nodes must exist in the graph"

      true ->
        # Position each node in each layer
        layers
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {layer_nodes, j}, acc ->
          layer_pos = position_layer(layer_nodes, j, m, align, width, height, cx, cy)
          Map.merge(acc, layer_pos)
        end)
    end
  end

  defp position_layer(layer_nodes, j, m, :vertical, width, height, cx, cy) do
    k = length(layer_nodes)
    min_x = cx - width / 2.0
    min_y = cy - height / 2.0

    x = if m == 1, do: cx, else: min_x + j * width / (m - 1)

    layer_nodes
    |> Enum.with_index()
    |> Map.new(fn {node_id, i} ->
      y = if k == 1, do: cy, else: min_y + i * height / (k - 1)
      {node_id, {x, y}}
    end)
  end

  defp position_layer(layer_nodes, j, m, :horizontal, width, height, cx, cy) do
    k = length(layer_nodes)
    min_x = cx - width / 2.0
    min_y = cy - height / 2.0

    y = if m == 1, do: cy, else: min_y + j * height / (m - 1)

    layer_nodes
    |> Enum.with_index()
    |> Map.new(fn {node_id, i} ->
      x = if k == 1, do: cx, else: min_x + i * width / (k - 1)
      {node_id, {x, y}}
    end)
  end
end
