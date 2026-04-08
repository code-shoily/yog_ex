# maze_solver_directional.exs
#
# Generates a maze and solves it using Dijkstra's algorithm,
# visualizing the solution path with directional arrows (^ v > <).
#
# Usage: mix run examples/maze_solver_directional.exs

alias Yog.Generator.Maze
alias Yog.Builder.GridGraph
alias Yog.Pathfinding
alias Yog.Render.ASCII

rows = 12
cols = 20

IO.puts("╔════════════════════════════════════════════════════════════╗")
IO.puts("║     MAZE SOLVER WITH DIRECTIONAL ARROWS (^ v > <)         ║")
IO.puts("╚════════════════════════════════════════════════════════════╝")

maze = Maze.recursive_backtracker(rows, cols, seed: 42)
graph = GridGraph.to_graph(maze)

start = 0
goal = rows * cols - 1

IO.puts("\nGenerating #{rows}×#{cols} maze...")
IO.puts("Start: node #{start} (top-left)")
IO.puts("Goal:  node #{goal} (bottom-right)")

case Pathfinding.shortest_path(in: graph, from: start, to: goal) do
  {:ok, path} ->
    IO.puts("\nPath found! Length: #{length(path.nodes)} nodes")

    occupants =
      path.nodes
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [current, next] ->
        direction =
          cond do
            next == current + 1 -> ">"
            next == current - 1 -> "<"
            next == current + cols -> "v"
            next == current - cols -> "^"
            true -> "·"
          end

        {current, direction}
      end)
      |> Map.new()
      |> Map.put(start, "S")
      |> Map.put(goal, "G")

    IO.puts("\nSolution with Directional Arrows:")
    IO.puts("   S = Start, G = Goal, >v<^ = Path direction")
    IO.puts("")
    IO.puts(ASCII.grid_to_string_unicode(maze, occupants))

  {:error, reason} ->
    IO.puts("No path found: #{inspect(reason)}")
end
