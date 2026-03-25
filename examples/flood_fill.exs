defmodule LeetCode do
  @moduledoc """
  An image is represented by an m x n integer grid image where image[i][j] represents
  the pixel value of the image.

  You are also given three integers sr, sc, and color. You should perform a flood fill
  on the image starting from the pixel image[sr][sc].
  """

  def flood_fill(image, sr, sc, new_color) do
    cols = length(hd(image))

    # The starting color we want to replace
    start_color = Enum.at(Enum.at(image, sr), sc)

    # If the new color is the same as the start color, no work needed
    if start_color == new_color do
      image
    else
      # Step 1: Tell Grid Builder what makes a tile "connected" for our flood fill.
      # They are only connected if BOTH tiles share the specific `start_color`.
      is_same_color? = fn from_val, to_val ->
        from_val == start_color and to_val == start_color
      end

      # Step 2: Build the Grid (returns a GridGraph struct, not a raw graph)
      # It will only draw edges between adjacent pixels of the `start_color`
      grid =
        Yog.Builder.Grid.from_2d_list(image, :undirected, is_same_color?)

      # Step 3: Convert to graph for traversal
      graph = Yog.Builder.Grid.to_graph(grid)

      # Step 4: Find the starting Node ID
      start_node_id = Yog.Builder.Grid.coord_to_id(sr, sc, cols)

      # Step 5: Run a Traversal (Breadth-First Search)
      # Since our graph only has edges between pixels of the SAME `start_color`,
      # BFS will perfectly return every single pixel we need to paint!
      pixels_to_paint =
        Yog.Traversal.walk(
          in: graph,
          from: start_node_id,
          using: :breadth_first
        )

      # Step 6: Paint the new image
      # Convert the list of node IDs back into coordinates to easily update the grid
      coords_to_paint = Enum.map(pixels_to_paint, &Yog.Builder.Grid.id_to_coord(&1, cols))

      # A quick Elixir trick to update a 2D list format using our coordinate map.
      # (In a real app, you might just keep it as a Graph or a Map!)
      coords_set = MapSet.new(coords_to_paint)

      image
      |> Enum.with_index()
      |> Enum.map(fn {row, r_idx} ->
        row
        |> Enum.with_index()
        |> Enum.map(fn {val, c_idx} ->
          if MapSet.member?(coords_set, {r_idx, c_idx}), do: new_color, else: val
        end)
      end)
    end
  end

  # Helper to print the grid cleanly
  def print_grid(grid) do
    Enum.each(grid, fn row ->
      IO.inspect(row)
    end)
    IO.puts("")
  end
end

image = [
  [1, 1, 1],
  [1, 1, 0],
  [1, 0, 1]
]

IO.puts("Original Image:")
LeetCode.print_grid(image)

IO.puts("Flood Fill (sr=1, sc=1, color=2):")
result = LeetCode.flood_fill(image, 1, 1, 2)
LeetCode.print_grid(result)
