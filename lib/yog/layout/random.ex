defmodule Yog.Layout.Random do
  @moduledoc """
  Random layout algorithm for positioning graph nodes in Elixir.
  """

  alias Yog.Graph

  @doc """
  Positions nodes randomly within a specified bounding box.

  ## Options

    * `:width` - The width of the bounding box (default: `1.0`).
    * `:height` - The height of the bounding box (default: `1.0`).
    * `:center` - The `{x, y}` coordinates of the center of the bounding box (default: `{0.0, 0.0}`).
    * `:seed` - Optional integer seed or term for reproducible random positioning.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3])
      iex> pos = Yog.Layout.Random.layout(graph)
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

  """
  @spec layout(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def layout(graph, opts \\ []) do
    width = Keyword.get(opts, :width, 1.0)
    height = Keyword.get(opts, :height, 1.0)
    {cx, cy} = Keyword.get(opts, :center, {0.0, 0.0})
    seed = Keyword.get(opts, :seed)

    if seed do
      :rand.seed(:exsss, seed)
    end

    nodes = Yog.all_nodes(graph)
    min_x = cx - width / 2.0
    min_y = cy - height / 2.0

    Map.new(nodes, fn node_id ->
      x = min_x + :rand.uniform() * width
      y = min_y + :rand.uniform() * height
      {node_id, {x, y}}
    end)
  end
end
