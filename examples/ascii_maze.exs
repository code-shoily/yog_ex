# 1. Setup - Import the modules we need
alias Yog.Builder.Grid
alias Yog.Pathfinding.AStar
alias Yog.Pathfinding.Path
alias Yog.Render.ASCII

data = [
  [1, 1, 1, 0, 1],
  [0, 1, 1, 0, 1],
  [0, 1, 1, 1, 1],
  [0, 0, 1, 0, 1],
  [0, 0, 1, 1, 1]
]

width = 5
height = 5

IO.puts("--- Generating a #{width}x#{height} Maze ---")

maze = Grid.from_2d_list(data, :directed, Grid.including([1]))

start_node = 0
goal_node = width * height - 1

IO.puts("Start: #{start_node}, Goal: #{goal_node}")
IO.puts("--- Solving with A* ---")

# 3. Solved with A*
# We use Manhattan distance as the heuristic for grid movement.
heuristic = fn u, v -> Grid.manhattan_distance(u, v, width) end

case AStar.a_star(maze.graph, start_node, goal_node, heuristic) do
  :error ->
    IO.puts("❌ No path found! The random edges created a disconnected maze.")
    # Render the empty maze anyway so we can see the walls
    ASCII.grid_to_string_unicode(maze) |> IO.puts()

  {:ok, %Path{nodes: path_nodes, weight: cost}} ->
    IO.puts(
      "✅ Path found! Cost: #{cost}, Length: #{Path.length(%Path{nodes: path_nodes, weight: cost})}"
    )

    IO.puts("--- Rendering Result ---")

    occupants =
      path_nodes
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(%{}, fn [u, v], acc ->
        arrow =
          case v - u do
            1 -> ">"
            -1 -> "<"
            d when d == width -> "v"
            d when d == -width -> "^"
            _ -> "*"
          end

        # ASCII Validator: Ensure arrow is printable (32-126) and 1-char
        if String.length(arrow) == 1 and :binary.first(arrow) in 32..126 do
          Map.put(acc, u, arrow)
        else
          # Fallback to a safe character if validation fails
          Map.put(acc, u, "*")
        end
      end)
      # Mark Start and Goal distinctively (both are printable ASCII)
      |> Map.put(start_node, "S")
      |> Map.put(goal_node, "G")

    # 5. Render to Terminal (The Primitive)
    # The renderer is "dumb"—it just draws the structure and places the occupants.
    maze
    |> ASCII.grid_to_string_unicode(occupants)
    |> IO.puts()
end

# ------------------------- OUTPUT
# --- Generating a 5x5 Maze ---
# Start: 0, Goal: 24
# --- Solving with A* ---
# ✅ Path found! Cost: 8, Length: 8
# --- Rendering Result ---
# ┌───────────┬───┬───┐
# │ S   >   v │   │   │
# ├───┐       ├───┤   │
# │   │     v │   │   │
# ├───┤       └───┘   │
# │   │     >   >   v │
# ├───┼───┐   ┌───┐   │
# │   │   │   │   │ v │
# ├───┼───┤   └───┘   │
# │   │   │         G │
# └───┴───┴───────────┘
