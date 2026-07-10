defmodule Yog.Layout.Grid do
  @moduledoc """
  Grid layout algorithm for positioning graph nodes in Elixir.

  Positions nodes deterministically on a 2D grid based on user-supplied rows or columns.
  This layout is ideal for structured diagrams (e.g. architecture layouts, UMLs, C4 models)
  where predictability, alignment, and pixel-exact placement are required rather than
  organic force-directed aesthetics.

  ## Mathematical Model

  Given a 2D grid origin $(O_x, O_y)$ and cell dimensions $(W_{\text{cell}}, H_{\text{cell}})$:

  Each node positioned at grid coordinates $(\text{row}, \text{col})$ is mapped to:
  $$x = O_x + \text{col} \cdot W_{\text{cell}}$$
  $$y = O_y + \text{row} \cdot H_{\text{cell}}$$

  Empty cells can be specified using a placeholder (`nil` or `:_`), which leaves the slot empty
  and aligns subsequent elements correctly.

  ## Complexities

  * **Time Complexity:** $O(V)$ where $V$ is the number of nodes.
  * **Space Complexity:** $O(V)$ auxiliary space.
  """

  alias Yog.Graph

  @doc """
  Positions nodes on a grid using rows or columns.

  ## Options

    * `:rows` - List of lists of node IDs, representing rows of the grid.
    * `:columns` - List of lists of node IDs, representing columns of the grid.
    * `:cell` - A `{cell_width, cell_height}` tuple representing dimensions of each grid cell (default: `{1.0, 1.0}`).
    * `:cell_width` - Bypasses width from `:cell` if specified.
    * `:cell_height` - Bypasses height from `:cell` if specified.
    * `:origin` - A `{x_origin, y_origin}` tuple representing the top-left offset of the grid (default: `{0.0, 0.0}`).

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([:client, :api, :db])
      iex> pos = Yog.Layout.Grid.layout(graph, rows: [[:client], [:api], [:db]], cell: {100, 50})
      iex> pos[:client]
      {0.0, 0.0}
      iex> pos[:api]
      {0.0, 50.0}

  """
  @spec layout(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def layout(graph, opts) do
    rows = Keyword.get(opts, :rows)
    columns = Keyword.get(opts, :columns)
    cell = Keyword.get(opts, :cell, {1.0, 1.0})
    cell_width = Keyword.get(opts, :cell_width, elem(cell, 0)) * 1.0
    cell_height = Keyword.get(opts, :cell_height, elem(cell, 1)) * 1.0
    {ox, oy} = Keyword.get(opts, :origin, {0.0, 0.0})

    # Validate row/column exclusivity
    cond do
      rows && columns ->
        raise ArgumentError, "Must specify either :rows or :columns, not both"

      is_nil(rows) and is_nil(columns) ->
        raise ArgumentError, "Must specify either :rows or :columns"

      true ->
        :ok
    end

    grid_data = rows || columns
    flat_grid_nodes = grid_data |> List.flatten() |> Enum.reject(&placeholder?/1)

    # Validate duplicates
    if length(flat_grid_nodes) != MapSet.size(MapSet.new(flat_grid_nodes)) do
      duplicates =
        flat_grid_nodes
        |> Enum.frequencies()
        |> Enum.filter(fn {_, count} -> count > 1 end)
        |> Enum.map(&elem(&1, 0))

      raise ArgumentError, "Grid contains duplicate node IDs: #{inspect(duplicates)}"
    end

    # Validate against graph nodes
    graph_nodes = Yog.all_nodes(graph)
    graph_nodes_set = MapSet.new(graph_nodes)
    grid_set = MapSet.new(flat_grid_nodes)

    extra_in_grid = MapSet.difference(grid_set, graph_nodes_set)

    if MapSet.size(extra_in_grid) > 0 do
      raise ArgumentError,
            "Grid contains node IDs not present in the graph: #{inspect(MapSet.to_list(extra_in_grid))}"
    end

    missing_from_grid = MapSet.difference(graph_nodes_set, grid_set)

    if MapSet.size(missing_from_grid) > 0 do
      raise ArgumentError,
            "Graph contains node IDs missing from the grid: #{inspect(MapSet.to_list(missing_from_grid))}"
    end

    # Calculate coordinates
    if rows do
      grid_data
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {row_nodes, row}, acc ->
        row_nodes
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {node_id, col}, inner_acc ->
          if placeholder?(node_id) do
            inner_acc
          else
            x = ox + col * cell_width
            y = oy + row * cell_height
            Map.put(inner_acc, node_id, {x, y})
          end
        end)
      end)
    else
      grid_data
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {col_nodes, col}, acc ->
        col_nodes
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {node_id, row}, inner_acc ->
          if placeholder?(node_id) do
            inner_acc
          else
            x = ox + col * cell_width
            y = oy + row * cell_height
            Map.put(inner_acc, node_id, {x, y})
          end
        end)
      end)
    end
  end

  defp placeholder?(nil), do: true
  defp placeholder?(:_), do: true
  defp placeholder?(_), do: false
end
