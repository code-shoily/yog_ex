defmodule Yog.Layout.Circular do
  @moduledoc """
  Circular layout algorithm for positioning graph nodes in Elixir.
  """

  alias Yog.Graph

  @doc """
  Positions nodes uniformly spaced on a circle.

  ## Options

    * `:radius` - The radius of the circle (default: `1.0`).
    * `:center` - The `{x, y}` coordinates of the center of the circle (default: `{0.0, 0.0}`).

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3])
      iex> pos = Yog.Layout.Circular.layout(graph)
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

  """
  @spec layout(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def layout(graph, opts \\ []) do
    radius = Keyword.get(opts, :radius, 1.0)
    {cx, cy} = Keyword.get(opts, :center, {0.0, 0.0})

    nodes = Yog.all_nodes(graph)
    n = length(nodes)

    cond do
      n == 0 ->
        %{}

      n == 1 ->
        [single] = nodes
        Map.new([{single, {cx, cy}}])

      true ->
        two_pi = 2 * :math.pi()

        nodes
        |> Enum.with_index()
        |> Map.new(fn {node_id, index} ->
          theta = (two_pi * index) / n
          x = cx + radius * :math.cos(theta)
          y = cy + radius * :math.sin(theta)
          {node_id, {x, y}}
        end)
    end
  end
end
