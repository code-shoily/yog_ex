# maze_solver.exs
#
# Generates a maze and solves it using Dijkstra's algorithm,
# visualizing the solution path using ASCII occupants.
#
# Usage: mix run examples/maze_solver.exs

alias Yog.Generator.Maze
alias Yog.Builder.GridGraph
alias Yog.Pathfinding
alias Yog.Render.ASCII

rows = 15
cols = 30

IO.puts("╔════════════════════════════════════════════════════════════╗")
IO.puts("║              MAZE SOLVER WITH DIJKSTRA                     ║")
IO.puts("╚════════════════════════════════════════════════════════════╝")

# Generate a maze using Recursive Backtracker (great for pathfinding)
IO.puts("\n🎲 Generating maze...")
maze = Maze.recursive_backtracker(rows, cols, seed: 42)
graph = GridGraph.to_graph(maze)

# Define start (top-left) and goal (bottom-right)
# {0, 0}
start = 0
# {rows-1, cols-1}
goal = rows * cols - 1

IO.puts("📍 Start: node #{start} (top-left)")
IO.puts("🎯 Goal:  node #{goal} (bottom-right)")

# Solve using Dijkstra's algorithm
IO.puts("\n🔍 Solving with Dijkstra's algorithm...")

case Pathfinding.shortest_path(in: graph, from: start, to: goal) do
  {:ok, path} ->
    IO.puts("✅ Path found!")
    IO.puts("   Length: #{length(path.nodes)} nodes")
    IO.puts("   Weight: #{path.weight}")

    # Create occupants map for the solution path
    # Use different characters for start, path, and goal
    occupants =
      path.nodes
      |> Enum.with_index()
      |> Enum.map(fn {node_id, _index} ->
        char =
          cond do
            # Start
            node_id == start -> "S"
            # Goal
            node_id == goal -> "G"
            # Path
            true -> "·"
          end

        {node_id, char}
      end)
      |> Map.new()

    # Render maze with solution path
    IO.puts("\n🗺️  Maze with Solution Path:")
    IO.puts("   S = Start, G = Goal, · = Path")
    IO.puts("")
    IO.puts(ASCII.grid_to_string_unicode(maze, occupants))

  {:error, reason} ->
    IO.puts("❌ No path found: #{inspect(reason)}")
end

# Bonus: Show all algorithms with solutions
IO.puts("\n" <> String.duplicate("═", 64))
IO.puts("🎨 BONUS: Compare Different Maze Types with Solutions")
IO.puts(String.duplicate("═", 64))

algorithms = [
  {"Recursive Backtracker", fn -> Maze.recursive_backtracker(8, 16, seed: 123) end},
  {"Wilson's Algorithm", fn -> Maze.wilson(8, 16, seed: 123) end},
  {"Kruskal's Algorithm", fn -> Maze.kruskal(8, 16, seed: 123) end}
]

Enum.each(algorithms, fn {name, generator} ->
  maze = generator.()
  graph = GridGraph.to_graph(maze)
  start = 0
  goal = 8 * 16 - 1

  case Pathfinding.shortest_path(in: graph, from: start, to: goal) do
    {:ok, path} ->
      occupants =
        Map.new(path.nodes, fn id ->
          char =
            cond do
              id == start -> "S"
              id == goal -> "G"
              true -> "·"
            end

          {id, char}
        end)

      IO.puts("\n#{name} (path length: #{length(path.nodes)})")
      IO.puts(ASCII.grid_to_string_unicode(maze, occupants))

    _ ->
      IO.puts("\n#{name}: No solution found")
  end
end)

IO.puts("\n✨ Maze solving complete!")
