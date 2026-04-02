defmodule Yog.Render.ASCII do
  @moduledoc """
  ASCII art rendering for grid graphs - quick visualization in terminal output.

  This module provides ASCII-based visualizations of grid graphs, useful for:
  - Quick debugging and exploration in REPL/terminal sessions
  - Console-based tools and CLI applications
  - Visualizing maze structures and grid-based pathfinding results
  - Lightweight visualization without external dependencies

  ## Quick Start

      # Create a grid and render it
      grid = Yog.Builder.Grid.from_2d_list([[".", "."], [".", "."]], :undirected)
      ascii = Yog.Render.ASCII.grid_to_string(grid)
      IO.puts(ascii)

  ## Output Format

  The ASCII renderer produces a text representation using:
  - `+` - Corner intersections
  - `-` | `|` - Walls between non-adjacent cells
  - Spaces - Passable paths between adjacent cells

  ## Examples

  A simple 3x3 grid:

  ```
  +---+---+---+
  |   |   |   |
  +---+---+---+
  |   |   |   |
  +---+---+---+
  |   |   |   |
  +---+---+---+
  ```

  A grid with walls (missing edges):

  ```
  +---+---+---+
  |   |   |   |
  +---+---+   +
  |   |   |   |
  +   +---+---+
  |   |   |   |
  +---+---+---+
  ```

  ## Limitations

  - ASCII art is best for small grids (under 30x30)
  - Only works with `Yog.Builder.Grid` or `Yog.Builder.ToroidalGrid` structures
  - Cell content is not displayed, only the grid structure

  ## Comparison with Other Renderers

  | Feature | ASCII | DOT | Mermaid | JSON |
  |---------|-------|-----|---------|------|
  | Dependencies | None | Graphviz | Mermaid.js | None |
  | Output | Text | Text | Text | Data |
  | Best For | Debugging | Publication | Web docs | Interop |
  | Styling | Limited | Extensive | Moderate | N/A |

  ## References

  - Inspired by terminal-based maze visualizers
  - Similar to ASCII output in grid-based games
  - Perfect for "Mazes for Programmers" book examples
  """

  alias Yog.Builder.Grid
  alias Yog.Builder.GridGraph
  alias Yog.Builder.ToroidalGraph
  alias Yog.Queryable, as: Model

  @typedoc "Grid type from Yog.Builder.Grid"
  @type grid :: GridGraph.t()

  @doc """
  Converts a grid to ASCII art using simple characters (+, -, |).

  Each cell is represented as a 3-character wide space. Walls are drawn
  where edges don't exist between adjacent cells.

  ## Time Complexity

  O(rows * cols) - visits each cell twice (once for cell row, once for horizontal walls)

  ## Examples

      iex> grid = Yog.Builder.Grid.from_2d_list([[".", "."]], :undirected, Yog.Builder.Grid.always())
      iex> ascii = Yog.Render.ASCII.grid_to_string(grid)
      iex> String.contains?(ascii, "+")
      true

      iex> grid = Yog.Builder.Grid.from_2d_list([], :undirected, Yog.Builder.Grid.always())
      iex> Yog.Render.ASCII.grid_to_string(grid)
      ""
  """
  @spec grid_to_string(grid() | ToroidalGraph.t(), map()) :: String.t()
  def grid_to_string(grid, occupants \\ %{})
  def grid_to_string(%GridGraph{rows: 0}, _), do: ""
  def grid_to_string(%GridGraph{cols: 0}, _), do: ""
  def grid_to_string(%ToroidalGraph{rows: 0}, _), do: ""
  def grid_to_string(%ToroidalGraph{cols: 0}, _), do: ""

  def grid_to_string(%ToroidalGraph{} = toroidal, occupants) do
    grid = ToroidalGraph.to_grid_graph(toroidal)
    base_ascii = grid_to_string(grid, occupants)
    add_toroidal_hints(base_ascii, toroidal.rows, toroidal.cols)
  end

  def grid_to_string(%GridGraph{graph: graph, rows: rows, cols: cols}, occupants) do
    top_line = draw_top_border(cols)

    body_lines =
      0..(rows - 1)
      |> Enum.flat_map(fn row ->
        [
          draw_cell_row(graph, rows, cols, row, occupants),
          draw_horizontal_walls(graph, rows, cols, row)
        ]
      end)

    ([top_line] ++ body_lines)
    |> Enum.join("\n")
  end

  @doc """
  Converts a grid to ASCII art using Unicode box-drawing characters.

  Provides a more "premium" visual representation compared to `grid_to_string/1`,
  using characters like ┌, ─, ┬, ┼, etc., to correctly render corners and
  intersections.

  ## Parameters
  - `grid` - The grid graph structure to render
  - `occupants` - Optional map of `{node_id, string}` to place in cells

  ## Examples

      iex> grid = Yog.Builder.Grid.from_2d_list([[".", "."]], :undirected, Yog.Builder.Grid.always())
      iex> unicode = Yog.Render.ASCII.grid_to_string_unicode(grid)
      iex> String.contains?(unicode, "┌")
      true

      iex> # With occupants
      iex> grid = Yog.Builder.Grid.from_2d_list([[".", "."]], :undirected, Yog.Builder.Grid.always())
      iex> unicode = Yog.Render.ASCII.grid_to_string_unicode(grid, %{0 => "@"})
      iex> String.contains?(unicode, "@")
      true

  ## Time Complexity
  O(rows * cols)
  """
  @spec grid_to_string_unicode(grid() | ToroidalGraph.t(), map()) :: String.t()
  def grid_to_string_unicode(grid, occupants \\ %{})
  def grid_to_string_unicode(%GridGraph{rows: 0}, _), do: ""
  def grid_to_string_unicode(%GridGraph{cols: 0}, _), do: ""
  def grid_to_string_unicode(%ToroidalGraph{rows: 0}, _), do: ""
  def grid_to_string_unicode(%ToroidalGraph{cols: 0}, _), do: ""

  def grid_to_string_unicode(%ToroidalGraph{} = toroidal, occupants) do
    grid = ToroidalGraph.to_grid_graph(toroidal)
    base_unicode = grid_to_string_unicode(grid, occupants)
    add_toroidal_hints_unicode(base_unicode, toroidal.rows, toroidal.cols)
  end

  def grid_to_string_unicode(
        %GridGraph{graph: graph, rows: rows, cols: cols},
        occupants
      ) do
    # Render line by line
    0..rows
    |> Enum.map_join("\n", fn i_r ->
      intersection_row = draw_unicode_intersection_row(graph, rows, cols, i_r)

      if i_r < rows do
        cell_row = draw_unicode_cell_row(graph, rows, cols, i_r, occupants)
        intersection_row <> "\n" <> cell_row
      else
        intersection_row
      end
    end)
  end

  # =============================================================================
  # ASCII RENDERING (using +, -, |)
  # =============================================================================

  # Draws the top border of the grid
  @spec draw_top_border(non_neg_integer()) :: String.t()
  defp draw_top_border(cols) do
    "+" <> String.duplicate("---+", cols)
  end

  # Draws a single row of cells (the interior content and right walls)
  @spec draw_cell_row(
          Yog.graph(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          map()
        ) ::
          String.t()
  defp draw_cell_row(graph, _rows, cols, row, occupants) do
    0..(cols - 1)
    |> Enum.reduce("|", fn col, acc ->
      cell_id = Grid.coord_to_id(row, col, cols)
      right_id = Grid.coord_to_id(row, col + 1, cols)

      # Get cell content (centered in 3 spaces)
      content = Map.get(occupants, cell_id, " ")
      cell_text = " #{content} "

      # Check if there's a passage to the right
      wall =
        if has_passage?(graph, cell_id, right_id) do
          # Passage - no wall
          cell_text <> " "
        else
          # Wall
          cell_text <> "|"
        end

      acc <> wall
    end)
  end

  # Draws the horizontal walls below a row of cells
  @spec draw_horizontal_walls(
          Yog.graph(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  defp draw_horizontal_walls(graph, _rows, cols, row) do
    0..(cols - 1)
    |> Enum.reduce("+", fn col, acc ->
      cell_id = Grid.coord_to_id(row, col, cols)
      below_id = Grid.coord_to_id(row + 1, col, cols)

      # Check if there's a passage below
      wall =
        if has_passage?(graph, cell_id, below_id) do
          # Passage - no wall
          "   +"
        else
          # Wall
          "---+"
        end

      acc <> wall
    end)
  end

  # =============================================================================
  # UNICODE RENDERING (using ┌, ─, │, ┼, etc.)
  # =============================================================================

  defp draw_unicode_intersection_row(graph, rows, cols, i_r) do
    0..cols
    |> Enum.map_join("", fn i_c ->
      intersection = get_unicode_intersection(graph, rows, cols, i_r, i_c)

      if i_c < cols do
        if horizontal_wall?(graph, rows, cols, i_r, i_c) do
          intersection <> "───"
        else
          intersection <> "   "
        end
      else
        intersection
      end
    end)
  end

  defp draw_unicode_cell_row(graph, rows, cols, r, occupants) do
    0..cols
    |> Enum.map_join("", fn c ->
      wall =
        if vertical_wall?(graph, rows, cols, r, c) do
          "│"
        else
          " "
        end

      if c < cols do
        cell_id = Grid.coord_to_id(r, c, cols)
        content = Map.get(occupants, cell_id, " ")
        wall <> " #{content} "
      else
        wall
      end
    end)
  end

  defp get_unicode_intersection(graph, rows, cols, i_r, i_c) do
    up = i_r > 0 && vertical_wall?(graph, rows, cols, i_r - 1, i_c)
    down = i_r < rows && vertical_wall?(graph, rows, cols, i_r, i_c)
    left = i_c > 0 && horizontal_wall?(graph, rows, cols, i_r, i_c - 1)
    right = i_c < cols && horizontal_wall?(graph, rows, cols, i_r, i_c)

    case {up, down, left, right} do
      {false, false, false, false} -> " "
      {false, false, true, true} -> "─"
      {false, false, true, false} -> "─"
      {false, false, false, true} -> "─"
      {true, true, false, false} -> "│"
      {true, false, false, false} -> "│"
      {false, true, false, false} -> "│"
      {false, true, false, true} -> "┌"
      {false, true, true, false} -> "┐"
      {true, false, false, true} -> "└"
      {true, false, true, false} -> "┘"
      {false, true, true, true} -> "┬"
      {true, false, true, true} -> "┴"
      {true, true, false, true} -> "├"
      {true, true, true, false} -> "┤"
      {true, true, true, true} -> "┼"
    end
  end

  defp vertical_wall?(graph, _rows, cols, r, c) do
    cond do
      c == 0 -> true
      c == cols -> true
      true -> !has_passage?(graph, Grid.coord_to_id(r, c - 1, cols), Grid.coord_to_id(r, c, cols))
    end
  end

  defp horizontal_wall?(graph, rows, cols, r, c) do
    cond do
      r == 0 -> true
      r == rows -> true
      true -> !has_passage?(graph, Grid.coord_to_id(r - 1, c, cols), Grid.coord_to_id(r, c, cols))
    end
  end

  # =============================================================================
  # TOROIDAL HINTS
  # =============================================================================

  defp add_toroidal_hints(ascii, _rows, cols) do
    lines = String.split(ascii, "\n")

    # Top arrow line
    top_arrows = "  " <> Enum.map_join(0..(cols - 1), "   ", fn _ -> "v" end)

    # Middle side arrows
    body_with_sides =
      lines
      |> Enum.with_index()
      |> Enum.map(fn {line, idx} ->
        # Cell rows are at odd indices (1, 3, 5...)
        if rem(idx, 2) == 1 do
          "> " <> line <> " <"
        else
          "  " <> line
        end
      end)

    # Bottom arrow line
    bottom_arrows = "  " <> Enum.map_join(0..(cols - 1), "   ", fn _ -> "^" end)

    # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
    ([top_arrows] ++ body_with_sides ++ [bottom_arrows])
    |> Enum.join("\n")
  end

  defp add_toroidal_hints_unicode(unicode, _rows, cols) do
    lines = String.split(unicode, "\n")

    # Top arrow line (v)
    top_arrows = "  " <> Enum.map_join(0..(cols - 1), "   ", fn _ -> "v" end)

    # Middle side arrows
    body_with_sides =
      lines
      |> Enum.with_index()
      |> Enum.map(fn {line, idx} ->
        # Intersection rows are 0, 2, 4...
        # Cell rows are 1, 3, 5...
        if rem(idx, 2) == 1 do
          "> " <> line <> " <"
        else
          "  " <> line
        end
      end)

    # Bottom arrow line (ʌ) - using small letter lambda or a chevron
    # Using ʌ (U+028C) or ^
    bottom_arrows = "  " <> Enum.map_join(0..(cols - 1), "   ", fn _ -> "ʌ" end)

    # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
    ([top_arrows] ++ body_with_sides ++ [bottom_arrows])
    |> Enum.join("\n")
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  # Checks if there's a passage (edge) between two cells.
  #
  # A passage exists if there's an edge in either direction
  # (since mazes can be directed or undirected).
  @spec has_passage?(Yog.graph(), Yog.node_id(), Yog.node_id()) :: boolean()
  defp has_passage?(graph, from, to) do
    has_edge?(graph, from, to) || has_edge?(graph, to, from)
  end

  # Checks if an edge exists from one node to another.
  @spec has_edge?(Yog.Graph.t(), Yog.node_id(), Yog.node_id()) :: boolean()
  defp has_edge?(graph, from, to) do
    successors = Model.successors(graph, from)
    Enum.any?(successors, fn {id, _weight} -> id == to end)
  end
end
