defmodule Yog.Render.ASCIITest do
  use ExUnit.Case

  alias Yog.Builder.Grid
  alias Yog.Builder.Toroidal
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

  describe "toroidal rendering" do
    test "renders ASCII toroidal hints" do
      grid = Toroidal.from_2d_list([[".", "."]], :undirected, Toroidal.always())
      result = ASCII.grid_to_string(grid)

      # Should contain wrapping arrows
      assert String.contains?(result, "v   v")
      assert String.contains?(result, "^   ^")
      assert String.contains?(result, "> |")
      assert String.contains?(result, "| <")
    end

    test "renders Unicode toroidal hints" do
      grid = Toroidal.from_2d_list([[".", "."]], :undirected, Toroidal.always())
      result = ASCII.grid_to_string_unicode(grid)

      # Should contain wrapping arrows
      assert String.contains?(result, "v   v")
      assert String.contains?(result, "ʌ   ʌ")
      assert String.contains?(result, "> │")
      assert String.contains?(result, "│ <")
    end

    test "zero row/col edge cases" do
      assert ASCII.grid_to_string(
               struct(Yog.Builder.GridGraph, rows: 0, cols: 0, graph: Yog.undirected())
             ) == ""

      assert ASCII.grid_to_string(
               struct(Yog.Builder.GridGraph, cols: 0, rows: 0, graph: Yog.undirected())
             ) == ""

      assert ASCII.grid_to_string(struct(Yog.Builder.ToroidalGraph, rows: 0)) == ""
      assert ASCII.grid_to_string(struct(Yog.Builder.ToroidalGraph, cols: 0)) == ""

      assert ASCII.grid_to_string_unicode(
               struct(Yog.Builder.GridGraph, rows: 0, cols: 0, graph: Yog.undirected())
             ) == ""

      assert ASCII.grid_to_string_unicode(
               struct(Yog.Builder.GridGraph, cols: 0, rows: 0, graph: Yog.undirected())
             ) == ""

      assert ASCII.grid_to_string_unicode(struct(Yog.Builder.ToroidalGraph, rows: 0)) == ""
      assert ASCII.grid_to_string_unicode(struct(Yog.Builder.ToroidalGraph, cols: 0)) == ""
    end

    test "various interior Unicode intersection cases" do
      # 2x2 grid has center intersection at (1,1)

      # Case 1: left = true (no edge 0-2, edges 0-1, 2-3, 1-3)
      g1 =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)

      grid1 = %Yog.Builder.GridGraph{graph: g1, rows: 2, cols: 2}
      unicode1 = ASCII.grid_to_string_unicode(grid1)
      # matches {false, false, true, false}
      assert String.contains?(unicode1, "─")

      # Case 2: right = true (no edge 1-3, edges 0-1, 2-3, 0-2)
      g2 =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 0, to: 2, with: 1)

      grid2 = %Yog.Builder.GridGraph{graph: g2, rows: 2, cols: 2}
      unicode2 = ASCII.grid_to_string_unicode(grid2)
      # matches {false, false, false, true}
      assert String.contains?(unicode2, "─")

      # Case 3: up = true, down = true (no edges 0-1, 2-3, edges 0-2, 1-3)
      g3 =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 0, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)

      grid3 = %Yog.Builder.GridGraph{graph: g3, rows: 2, cols: 2}
      unicode3 = ASCII.grid_to_string_unicode(grid3)
      # matches {true, true, false, false}
      assert String.contains?(unicode3, "│")

      # Case 4: up = true, down = false (no edge 0-1, edges 2-3, 0-2, 1-3)
      g4 =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 0, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)

      grid4 = %Yog.Builder.GridGraph{graph: g4, rows: 2, cols: 2}
      unicode4 = ASCII.grid_to_string_unicode(grid4)
      # matches {true, false, false, false}
      assert String.contains?(unicode4, "│")

      # Case 5: up = false, down = true (no edge 2-3, edges 0-1, 0-2, 1-3)
      g5 =
        Yog.undirected()
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 0, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)

      grid5 = %Yog.Builder.GridGraph{graph: g5, rows: 2, cols: 2}
      unicode5 = ASCII.grid_to_string_unicode(grid5)
      # matches {false, true, false, false}
      assert String.contains?(unicode5, "│")
    end
  end
end
