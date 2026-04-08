# maze_gallery.exs
# 
# Demonstrates several maze generation algorithms and renders them to ASCII.
# 
# Usage: mix run examples/maze_gallery.exs

alias Yog.Generator.Maze
alias Yog.Render.ASCII

rows = 10
cols = 20

algorithms = [
  {"Recursive Backtracker (Classic twisty corridors)", :recursive_backtracker, []},
  {"Wilson's Algorithm (Uniformly random, balanced)", :wilson, []},
  {"Kruskal's Algorithm (MST-based, many short corridors)", :kruskal, []},
  {"Eller's Algorithm (Memory-efficient, row-by-row)", :ellers, []},
  {"Prim's (Simplified) (Radial texture, many dead ends)", :prim_simplified, []},
  {"Growing Tree (Random strategy)", :growing_tree, [strategy: :random]},
  {"Recursive Division (Fractal chambers and rooms)", :recursive_division, []}
]

IO.puts("=== YogEx Maze Gallery ===")
IO.puts("Grid size: #{rows}x#{cols}")

Enum.each(algorithms, fn {description, func_name, extra_opts} ->
  IO.puts("\n" <> String.duplicate("-", 40))
  IO.puts("Algorithm: #{description}")
  IO.puts(String.duplicate("-", 40))

  # Call the generator with a fixed seed for demonstration
  maze = apply(Maze, func_name, [rows, cols, [seed: 42] ++ extra_opts])

  # Render to ASCII
  IO.puts(ASCII.grid_to_string(maze))
end)

IO.puts("\nGallery Complete!")
