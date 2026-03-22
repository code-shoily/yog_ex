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
  """

  @typedoc "Grid type - opaque type from Gleam"
  @type grid :: tuple()

  @doc """
  Converts a grid to ASCII art using simple characters (+, -, |).

  Each cell is represented as a 3-character wide space. Walls are drawn
  where edges don't exist between adjacent cells.

  ## Examples

      # Note: This function delegates to the underlying Gleam implementation.
      # It accepts a Grid structure from Yog.Builder.Grid.
  """
  @spec grid_to_string(grid()) :: String.t()
  defdelegate grid_to_string(grid), to: :yog@render@ascii
end
