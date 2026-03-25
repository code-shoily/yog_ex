defmodule Yog.Render.ASCIITest do
  use ExUnit.Case

  alias Yog.Builder.Grid
  alias Yog.Render.ASCII

  doctest ASCII

  describe "grid_to_string/1" do
    test "returns empty string for empty grid" do
      grid =
        Grid.from_2d_list(
          [],
          :undirected,
          Grid.always()
        )

      result = ASCII.grid_to_string(grid)
      assert result == ""
    end

    test "renders simple 2x2 grid" do
      grid =
        Grid.from_2d_list(
          [[".", "."], [".", "."]],
          :undirected,
          Grid.always()
        )

      result = ASCII.grid_to_string(grid)

      # Should contain ASCII art elements
      assert String.contains?(result, "+")
      assert String.contains?(result, "-")
      assert String.contains?(result, "|")
    end

    test "renders 3x3 grid" do
      grid =
        Grid.from_2d_list(
          [[".", ".", "."], [".", ".", "."], [".", ".", "."]],
          :undirected,
          Grid.always()
        )

      result = ASCII.grid_to_string(grid)

      # Count corner characters
      plus_count = result |> String.graphemes() |> Enum.count(&(&1 == "+"))

      # A 3x3 grid should have 4x4 = 16 corners
      assert plus_count == 16
    end

    test "renders maze with walls" do
      maze = [
        [".", ".", "#"],
        [".", "#", "."],
        [".", ".", "."]
      ]

      grid =
        Grid.from_2d_list(
          maze,
          :undirected,
          Grid.walkable(".")
        )

      result = ASCII.grid_to_string(grid)

      # Should still render the grid structure
      assert String.contains?(result, "+")
      assert String.contains?(result, "|")
    end

    test "renders with occupants" do
      grid = Grid.from_2d_list([[".", "."]], :undirected, Grid.always())
      result = ASCII.grid_to_string(grid, %{0 => "M", 1 => "@"})

      assert String.contains?(result, " M ")
      assert String.contains?(result, " @ ")
    end
  end

  describe "grid_to_string_unicode/1" do
    test "returns empty string for empty grid" do
      grid = Grid.from_2d_list([], :undirected, Grid.always())
      assert ASCII.grid_to_string_unicode(grid) == ""
    end

    test "renders simple 1x1 grid" do
      grid = Grid.from_2d_list([[1]], :undirected, Grid.always())
      result = ASCII.grid_to_string_unicode(grid)

      # Should contain Unicode corners
      assert String.contains?(result, "┌")
      assert String.contains?(result, "┐")
      assert String.contains?(result, "└")
      assert String.contains?(result, "┘")
      assert String.contains?(result, "───")
      assert String.contains?(result, "│")
    end

    test "renders 2x2 grid with center cross" do
      # 2x2 grid with no internal passages (= all walls)
      maze = [["#", "#"], ["#", "#"]]
      grid = Grid.from_2d_list(maze, :undirected, Grid.walkable("."))
      result = ASCII.grid_to_string_unicode(grid)

      # Should contain T-junctions
      assert String.contains?(result, "┬")
      assert String.contains?(result, "┴")
      assert String.contains?(result, "├")
      assert String.contains?(result, "┤")

      # Should contain center cross
      assert String.contains?(result, "┼")
    end

    test "renders with occupants" do
      grid = Grid.from_2d_list([[".", "."]], :undirected, Grid.always())
      result = ASCII.grid_to_string_unicode(grid, %{0 => "M", 1 => "R"})

      assert String.contains?(result, " M ")
      assert String.contains?(result, " R ")
    end
  end
end
