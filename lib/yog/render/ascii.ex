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
  @spec grid_to_string(grid()) :: String.t()
  def grid_to_string(%Yog.Builder.GridGraph{rows: 0}), do: ""
  def grid_to_string(%Yog.Builder.GridGraph{cols: 0}), do: ""

  def grid_to_string(%Yog.Builder.GridGraph{graph: graph, rows: rows, cols: cols}) do
    top_line = draw_top_border(cols)

    body_lines =
      0..(rows - 1)
      |> Enum.flat_map(fn row ->
        [
          draw_cell_row(graph, rows, cols, row),
          draw_horizontal_walls(graph, rows, cols, row)
        ]
      end)

    ([top_line] ++ body_lines)
    |> Enum.join("\n")
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
  @spec draw_cell_row(Yog.graph(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          String.t()
  defp draw_cell_row(graph, _rows, cols, row) do
    0..(cols - 1)
    |> Enum.reduce("|", fn col, acc ->
      cell_id = Grid.coord_to_id(row, col, cols)
      right_id = Grid.coord_to_id(row, col + 1, cols)

      # Check if there's a passage to the right
      wall =
        if has_passage?(graph, cell_id, right_id) do
          # Passage - no wall
          "    "
        else
          # Wall
          "   |"
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
  @spec has_edge?(Yog.graph(), Yog.node_id(), Yog.node_id()) :: boolean()
  defp has_edge?(%Yog.Graph{out_edges: out_edges}, from, to) do
    case Map.get(out_edges, from) do
      nil -> false
      neighbors -> Map.has_key?(neighbors, to)
    end
  end
end
