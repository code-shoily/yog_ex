defmodule Yog.Generator.Maze do
  @moduledoc """
  Maze generation algorithms for creating perfect mazes.

  Perfect mazes are spanning trees on a grid where every cell connects to every
  other cell via exactly one path (no loops, no isolated areas).

  Based on "Mazes for Programmers" by Jamis Buck.

  ## Quick Start

      # Generate a maze using the Recursive Backtracker algorithm
      maze = Yog.Generator.Maze.recursive_backtracker(20, 20, seed: 42)
      IO.puts(Yog.Render.ASCII.grid_to_string(maze))

  ## Algorithms

  | Algorithm | Speed | Bias | Best For |
  |-----------|-------|------|----------|
  | `binary_tree/3` | O(N) | Diagonal | Simplest, fastest |
  | `sidewinder/3` | O(N) | Vertical | Memory constrained |
  | `recursive_backtracker/3` | O(N) | Corridors | Games, roguelikes |
  | `hunt_and_kill/3` | O(N²) | Winding | Few dead ends |
  | `aldous_broder/3` | O(N²) | None | Uniform randomness |
  | `wilson/3` | O(N) avg | None | Efficient uniform |
  | `kruskal/3` | O(N log N) | None | Balanced corridors |
  | `prim_simplified/3` | O(N log N) | Radial | Many dead ends |
  | `ellers/3` | O(N) | Horizontal | Infinite height mazes |
  | `growing_tree/3` | O(N) | Varies | Versatility |
  | `recursive_division/3` | O(N log N) | Rectangular | Rooms, fractal feel |

  ## Output Format

  All algorithms return a `Yog.Builder.GridGraph` struct that can be:
  - Rendered with `Yog.Render.ASCII`
  - Converted to a plain graph with `Yog.Builder.GridGraph.to_graph/1`
  - Used with pathfinding algorithms

  ## Examples

      # Generate and render a binary tree maze
      iex> maze = Yog.Generator.Maze.binary_tree(10, 10, seed: 42)
      iex> is_struct(maze, Yog.Builder.GridGraph)
      true
      iex> maze.rows
      10

      # Get the underlying graph for pathfinding
      iex> maze = Yog.Generator.Maze.recursive_backtracker(5, 5)
      iex> graph = Yog.Builder.GridGraph.to_graph(maze)
      iex> Yog.graph?(graph)
      true

  ## References

  - *Mazes for Programmers* by Jamis Buck (Pragmatic Bookshelf, 2015)
  """

  alias Yog.Builder.GridGraph
  alias Yog.Model

  @typedoc "Maze generation options"
  @type maze_opts :: [seed: integer(), topology: :plane]

  # ============================================================================
  # Binary Tree Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Binary Tree algorithm.

  The simplest maze algorithm. For each cell, randomly carves a passage
  to either the north or east neighbor (or other chosen bias). Creates
  an unbroken corridor along two boundaries.

  ## Characteristics

  - **Time**: O(N) where N = rows × cols
  - **Space**: O(1) auxiliary
  - **Bias**: Strong diagonal (NE by default)
  - **Texture**: Distinctive diagonal corridors

  ## Options

  - `:seed` - Random seed for reproducibility
  - `:bias` - Direction bias: `:ne` (default), `:nw`, `:se`, `:sw`

  ## Examples

      iex> maze = Yog.Generator.Maze.binary_tree(5, 5, seed: 42)
      iex> maze.rows
      5
      iex> maze.cols
      5

  ## When to Use

  - When speed is critical
  - For educational demonstrations
  - When predictable texture is acceptable

  ## When NOT to Use

  - When uniform randomness is required
  - When aesthetic variety matters
  """
  @spec binary_tree(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def binary_tree(rows, cols, opts \\ [])

  def binary_tree(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)
    bias = Keyword.get(opts, :bias, :ne)

    grid = create_empty_grid(rows, cols)

    Enum.reduce(0..(rows - 1), grid, fn row, grid_acc ->
      Enum.reduce(0..(cols - 1), grid_acc, fn col, g ->
        carve_binary_tree(g, row, col, rows, cols, bias)
      end)
    end)
  end

  def binary_tree(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp carve_binary_tree(%GridGraph{} = grid, row, col, rows, cols, bias) do
    neighbors = valid_binary_tree_neighbors(row, col, rows, cols, bias)

    case neighbors do
      [] ->
        grid

      [_ | _] ->
        {n_row, n_col} = Enum.random(neighbors)
        add_passage(grid, row, col, n_row, n_col)
    end
  end

  defp valid_binary_tree_neighbors(row, col, rows, cols, bias) do
    case bias do
      :ne ->
        []
        |> add_if(row > 0, {row - 1, col})
        |> add_if(col < cols - 1, {row, col + 1})

      :nw ->
        []
        |> add_if(row > 0, {row - 1, col})
        |> add_if(col > 0, {row, col - 1})

      :se ->
        []
        |> add_if(row < rows - 1, {row + 1, col})
        |> add_if(col < cols - 1, {row, col + 1})

      :sw ->
        []
        |> add_if(row < rows - 1, {row + 1, col})
        |> add_if(col > 0, {row, col - 1})
    end
  end

  defp add_if(list, true, item), do: [item | list]
  defp add_if(list, false, _item), do: list

  # ============================================================================
  # Sidewinder Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Sidewinder algorithm.

  Row-based algorithm that creates vertical corridors. For each row:
  1. Start a "run" of cells
  2. Randomly decide to end the run (carve north) or continue east
  3. At row end, carve north from a random cell in the run

  ## Characteristics

  - **Time**: O(N) where N = rows × cols
  - **Space**: O(cols) - only tracks current run
  - **Bias**: Vertical corridors (north-south)
  - **Texture**: Long vertical passages with horizontal "rungs"

  ## Options

  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> maze = Yog.Generator.Maze.sidewinder(5, 5, seed: 42)
      iex> maze.rows
      5
      iex> maze.cols
      5

  ## When to Use

  - When you want vertical maze progression
  - Memory-constrained environments
  - Creating "floor" separation in games

  ## When NOT to Use

  - When you need horizontal bias (use Binary Tree with :ne/:nw bias)
  """
  @spec sidewinder(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def sidewinder(rows, cols, opts \\ [])

  def sidewinder(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)

    Enum.reduce(0..(rows - 1), grid, fn row, grid_acc ->
      carve_sidewinder_row(grid_acc, row, cols, row == rows - 1)
    end)
  end

  def sidewinder(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp carve_sidewinder_row(%GridGraph{} = grid, row, cols, is_last_row) do
    run_start = 0

    Enum.reduce(0..(cols - 1), {grid, run_start}, fn col, {g, run_start_col} ->
      at_east_end = col == cols - 1
      at_north_edge = row == 0

      should_close_run =
        if at_north_edge do
          false
        else
          at_east_end or :rand.uniform() > 0.5
        end

      cond do
        is_last_row and not at_east_end ->
          {add_passage(g, row, col, row, col + 1), run_start_col}

        is_last_row and at_east_end ->
          run_col = if run_start_col == col, do: col, else: Enum.random(run_start_col..col)
          g = add_passage(g, row, run_col, row - 1, run_col)
          {g, 0}

        at_north_edge and not at_east_end ->
          {add_passage(g, row, col, row, col + 1), run_start_col}

        at_north_edge and at_east_end ->
          {g, 0}

        should_close_run ->
          run_col = if run_start_col == col, do: col, else: Enum.random(run_start_col..col)
          g = add_passage(g, row, run_col, row - 1, run_col)
          {g, col + 1}

        true ->
          {add_passage(g, row, col, row, col + 1), run_start_col}
      end
    end)
    |> elem(0)
  end

  # ============================================================================
  # Recursive Backtracker Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Recursive Backtracker algorithm (DFS).

  Performs a random walk avoiding visited cells, backtracking when stuck.
  Creates twisty mazes with long corridors - the most popular algorithm for games.

  ## Characteristics

  - **Time**: O(N) where N = rows × cols
  - **Space**: O(N) for the explicit stack
  - **Bias**: Twisty passages, long corridors
  - **Texture**: Classic "roguelike" maze aesthetic

  ## Algorithm

  1. Start at a random cell, mark as visited
  2. While there are unvisited neighbors, pick one randomly and move there
  3. Carve passage and push current cell to stack
  4. When stuck (no unvisited neighbors), pop from stack and continue
  5. Repeat until stack is empty

  ## Options

  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> maze = Yog.Generator.Maze.recursive_backtracker(10, 10, seed: 42)
      iex> maze.rows
      10

  ## When to Use

  - Games and roguelikes (most popular choice)
  - When you want twisty, exploratory mazes
  - Longest path puzzles
  - Classic maze aesthetic

  ## Comparison

  vs Binary Tree: Much less bias, more interesting texture
  vs Sidewinder: More twisty, less predictable
  vs Hunt-and-Kill: Similar output but uses explicit stack
  """
  @spec recursive_backtracker(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def recursive_backtracker(rows, cols, opts \\ [])

  def recursive_backtracker(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)
    total_cells = rows * cols
    start_row = :rand.uniform(rows) - 1
    start_col = :rand.uniform(cols) - 1
    stack = [{start_row, start_col}]

    do_backtrack(grid, stack, MapSet.new(stack), rows, cols, total_cells)
  end

  def recursive_backtracker(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_backtrack(grid, [], _visited, _rows, _cols, _total), do: grid

  defp do_backtrack(%GridGraph{} = grid, [{row, col} | rest] = stack, visited, rows, cols, total) do
    neighbors = unvisited_neighbors({row, col}, visited, rows, cols)

    case neighbors do
      [] ->
        do_backtrack(grid, rest, visited, rows, cols, total)

      [_ | _] ->
        {n_row, n_col} = Enum.random(neighbors)

        new_grid = add_passage(grid, row, col, n_row, n_col)
        new_visited = MapSet.put(visited, {n_row, n_col})

        new_stack = [{n_row, n_col} | stack]

        do_backtrack(new_grid, new_stack, new_visited, rows, cols, total)
    end
  end

  # ============================================================================
  # Hunt-and-Kill Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Hunt-and-Kill algorithm.

  Similar to Recursive Backtracker but without explicit stack. Performs a
  random walk until stuck, then "hunts" for an unvisited cell adjacent to
  the visited region, connects it, and continues.

  ## Characteristics

  - **Time**: O(N²) worst case (due to hunt phase)
  - **Space**: O(1) auxiliary (no stack!)
  - **Bias**: Long, winding passages; fewer dead ends
  - **Texture**: Similar to Recursive Backtracker but more organic

  ## Algorithm

  1. Start at random cell, mark as visited
  2. Perform random walk to unvisited neighbors until stuck
  3. When stuck, scan grid for unvisited cell adjacent to visited region
  4. Connect that cell to the visited region
  5. Resume random walk from that cell
  6. Repeat until all cells visited

  ## Options

  - `:seed` - Random seed for reproducibility
  - `:scan_mode` - How to hunt: `:sequential` (default) or `:random`

  ## Examples

      iex> maze = Yog.Generator.Maze.hunt_and_kill(10, 10, seed: 42)
      iex> maze.rows
      10

  ## When to Use

  - When you want Recursive Backtracker texture without the stack
  - Memory-constrained environments
  - Longest path puzzles
  - Fewer dead ends than Recursive Backtracker

  ## Comparison

  vs Recursive Backtracker: Similar texture, no stack needed, hunt phase slower
  vs Binary Tree: Much less bias, more interesting
  """
  @spec hunt_and_kill(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def hunt_and_kill(rows, cols, opts \\ [])

  def hunt_and_kill(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)
    scan_mode = Keyword.get(opts, :scan_mode, :sequential)

    grid = create_empty_grid(rows, cols)

    total_cells = rows * cols

    start_row = :rand.uniform(rows) - 1
    start_col = :rand.uniform(cols) - 1
    visited = MapSet.new([{start_row, start_col}])
    do_hunt_and_kill(grid, {start_row, start_col}, visited, rows, cols, total_cells, scan_mode)
  end

  def hunt_and_kill(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_hunt_and_kill(grid, current, visited, rows, cols, total, scan_mode) do
    if MapSet.size(visited) >= total do
      grid
    else
      case random_unvisited_neighbor(current, visited, rows, cols) do
        nil ->
          case hunt_for_cell(visited, rows, cols, scan_mode) do
            nil ->
              grid

            {hunt_row, hunt_col} = hunted_cell ->
              visited_neighbor = find_visited_neighbor(hunted_cell, visited, rows, cols)

              new_grid =
                add_passage(
                  grid,
                  hunt_row,
                  hunt_col,
                  elem(visited_neighbor, 0),
                  elem(visited_neighbor, 1)
                )

              new_visited = MapSet.put(visited, hunted_cell)

              do_hunt_and_kill(new_grid, hunted_cell, new_visited, rows, cols, total, scan_mode)
          end

        next_cell ->
          {curr_row, curr_col} = current
          {next_row, next_col} = next_cell

          new_grid = add_passage(grid, curr_row, curr_col, next_row, next_col)
          new_visited = MapSet.put(visited, next_cell)

          do_hunt_and_kill(new_grid, next_cell, new_visited, rows, cols, total, scan_mode)
      end
    end
  end

  # ============================================================================
  # Aldous-Broder Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Aldous-Broder algorithm.

  A random-walk algorithm that produces a uniform spanning tree (all possible
  perfect mazes are equally likely). Extremely inefficient but mathematically
  unbiased.

  ## Characteristics

  - **Time**: O(N log N) to O(N²) depending on luck
  - **Space**: O(N) to track visited cells
  - **Bias**: None (Uniform Randomness)
  - **Texture**: Well-distributed passages, no corridors bias

  ## Algorithm

  1. Start at a random cell, mark as visited.
  2. While there are unvisited cells:
     a. Pick a random neighbor of the current cell.
     b. If the neighbor has not been visited:
        - Carve a passage between the current cell and neighbor.
        - Mark the neighbor as visited.
     c. Move to the neighbor.

  ## Options

  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> maze = Yog.Generator.Maze.aldous_broder(10, 10, seed: 42)
      iex> maze.rows
      10

  ## When to Use

  - When you need a truly uniform random maze without any geometric bias
  - When performance is secondary to mathematical purity
  - For small to medium grids

  ## When NOT to Use

  - Very large grids (can take a long time to finish)
  - When speed is a priority
  """
  @spec aldous_broder(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def aldous_broder(rows, cols, opts \\ [])

  def aldous_broder(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)
    total_cells = rows * cols

    start_row = :rand.uniform(rows) - 1
    start_col = :rand.uniform(cols) - 1
    start_cell = {start_row, start_col}

    visited = MapSet.new([start_cell])
    count = 1

    do_aldous_broder(grid, start_cell, visited, count, rows, cols, total_cells)
  end

  def aldous_broder(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_aldous_broder(grid, _current, _visited, count, _rows, _cols, total) when count >= total,
    do: grid

  defp do_aldous_broder(grid, {r, c} = _current, visited, count, rows, cols, total) do
    {nr, nc} = next_cell = pick_any_neighbor(r, c, rows, cols)

    if MapSet.member?(visited, next_cell) do
      do_aldous_broder(grid, next_cell, visited, count, rows, cols, total)
    else
      new_grid = add_passage(grid, r, c, nr, nc)
      new_visited = MapSet.put(visited, next_cell)
      do_aldous_broder(new_grid, next_cell, new_visited, count + 1, rows, cols, total)
    end
  end

  # ============================================================================
  # Wilson's Algorithm
  # ============================================================================

  @doc """
  Generates a maze using Wilson's algorithm.

  Produces a perfectly uniform spanning tree (like Aldous-Broder) but using
  loop-erased random walks. Much more efficient than Aldous-Broder while
  maintaining the same unbiased quality.

  ## Characteristics

  - **Time**: Faster than Aldous-Broder (O(N) to O(N log N) typical)
  - **Space**: O(N) for visited set and walk tracking
  - **Bias**: None (Uniform Randomness)
  - **Texture**: Well-distributed, no corridor bias

  ## Algorithm

  1. Pick a random cell and add to visited set.
  2. While there are unvisited cells:
     a. Pick a random unvisited cell.
     b. Perform random walk until hitting a visited cell.
     c. If walk crosses itself, the older path is overwritten (loop erasure).
     d. Add the final path to the visited set and carve passages.

  ## Options

  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> maze = Yog.Generator.Maze.wilson(10, 10, seed: 42)
      iex> maze.rows
      10

  ## When to Use

  - When you need a truly uniform random maze without any geometric bias
  - When performance is more important than in Aldous-Broder
  - For medium to large grids

  ## When NOT to Use

  - When speed is the absolute absolute priority (Binary Tree/Recursive Backtracker are faster)
  """
  @spec wilson(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def wilson(rows, cols, opts \\ [])

  def wilson(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)

    cells = for r <- 0..(rows - 1), c <- 0..(cols - 1), do: {r, c}

    [first | rest] = Enum.shuffle(cells)
    visited = MapSet.new([first])
    unvisited = MapSet.new(rest)

    do_wilson(grid, visited, unvisited, rows, cols)
  end

  def wilson(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_wilson(grid, visited, unvisited, rows, cols) do
    if MapSet.size(unvisited) == 0 do
      grid
    else
      start_cell = Enum.random(unvisited)

      arrows = random_walk_to_visited(start_cell, visited, %{}, rows, cols)

      {new_grid, new_visited, new_unvisited} =
        carve_path(grid, start_cell, visited, unvisited, arrows)

      do_wilson(new_grid, new_visited, new_unvisited, rows, cols)
    end
  end

  defp random_walk_to_visited(current, visited, arrows, rows, cols) do
    {r, c} = current
    next_cell = pick_any_neighbor(r, c, rows, cols)

    new_arrows = Map.put(arrows, current, next_cell)

    if MapSet.member?(visited, next_cell) do
      new_arrows
    else
      random_walk_to_visited(next_cell, visited, new_arrows, rows, cols)
    end
  end

  defp carve_path(grid, current, visited, unvisited, arrows) do
    next_cell = Map.get(arrows, current)

    {r1, c1} = current
    {r2, c2} = next_cell

    new_grid = add_passage(grid, r1, c1, r2, c2)
    new_visited = MapSet.put(visited, current)
    new_unvisited = MapSet.delete(unvisited, current)

    if MapSet.member?(visited, next_cell) do
      {new_grid, new_visited, new_unvisited}
    else
      carve_path(new_grid, next_cell, new_visited, new_unvisited, arrows)
    end
  end

  # ============================================================================
  # Kruskal's Algorithm
  # ============================================================================

  @doc """
  Generates a maze using Kruskal's algorithm.

  A randomized version of the Minimum Spanning Tree algorithm. It treats every
  cell as a separate set and randomly merges sets by carving passages until
  all cells are connected in a single set.

  ## Characteristics

  - **Time**: O(N log N) or O(N α(N)) depending on shuffling and DSU operations
  - **Space**: O(N) to store edges and the Disjoint Set structure
  - **Bias**: None (Uniform Randomness)
  - **Texture**: No obvious corridors or diagonal bias, very "balanced"

  ## Algorithm

  1. Create a set for each cell.
  2. Create a list of all potential edges between adjacent cells.
  3. Shuffle the list of edges.
  4. For each edge, if the two cells it connects are in different sets:
     a. Carve a passage between them.
     b. Merge the two sets.

  ## Options

  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> maze = Yog.Generator.Maze.kruskal(10, 10, seed: 42)
      iex> maze.rows
      10

  ## When to Use

  - When you want a uniform maze with a different structural feel than Wilson's
  - For randomized grid maps where you want an efficient "merge-based" generation

  ## When NOT to Use

  - Extremely large grids if memory for the edge list is constrained
  """
  @spec kruskal(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def kruskal(rows, cols, opts \\ [])

  def kruskal(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)

    horiz = for r <- 0..(rows - 1), c <- 0..(cols - 2), do: {{r, c}, {r, c + 1}}
    vert = for r <- 0..(rows - 2), c <- 0..(cols - 1), do: {{r, c}, {r + 1, c}}

    edges = Enum.shuffle(horiz ++ vert)
    dsu = Yog.DisjointSet.new()

    {final_grid, _dsu} =
      Enum.reduce(edges, {grid, dsu}, fn {u, v}, {g_acc, dsu_acc} ->
        {new_dsu_find, is_connected} = Yog.DisjointSet.connected?(dsu_acc, u, v)

        if is_connected do
          {g_acc, new_dsu_find}
        else
          {r1, c1} = u
          {r2, c2} = v
          new_g = add_passage(g_acc, r1, c1, r2, c2)
          new_dsu = Yog.DisjointSet.union(new_dsu_find, u, v)
          {new_g, new_dsu}
        end
      end)

    final_grid
  end

  def kruskal(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  # ============================================================================
  # Prim's Algorithm (Simplified)
  # ============================================================================

  @doc """
  Generates a maze using Simplified Prim's algorithm.

  Similar to Growing Tree with random selection. Creates mazes with strong
  radial texture and many dead ends.
  """
  @spec prim_simplified(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def prim_simplified(rows, cols, opts \\ [])

  def prim_simplified(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)
    start_cell = {:rand.uniform(rows) - 1, :rand.uniform(cols) - 1}
    visited = MapSet.new([start_cell])
    frontier = unvisited_neighbors(start_cell, visited, rows, cols)

    do_prim_simplified(grid, frontier, visited, rows, cols)
  end

  def prim_simplified(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_prim_simplified(grid, [], _visited, _rows, _cols), do: grid

  defp do_prim_simplified(grid, frontier, visited, rows, cols) do
    cell = Enum.random(frontier)
    {row, col} = cell
    {nr, nc} = find_visited_neighbor(cell, visited, rows, cols)

    new_grid = add_passage(grid, row, col, nr, nc)
    new_visited = MapSet.put(visited, cell)

    new_frontier =
      frontier
      |> List.delete(cell)
      |> Enum.concat(unvisited_neighbors(cell, new_visited, rows, cols))
      |> Enum.uniq()

    do_prim_simplified(new_grid, new_frontier, new_visited, rows, cols)
  end

  # ============================================================================
  # Prim's Algorithm (True)
  # ============================================================================

  @doc """
  Generates a maze using True Prim's algorithm.

  Each cell has a random weight. Always selects the lowest-weight cell
  from the frontier. Creates many short dead ends, jigsaw puzzle texture.
  """
  @spec prim_true(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def prim_true(rows, cols, opts \\ [])

  def prim_true(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)

    weights =
      for r <- 0..(rows - 1), c <- 0..(cols - 1), into: %{} do
        {{r, c}, :rand.uniform(1000)}
      end

    start_cell = {:rand.uniform(rows) - 1, :rand.uniform(cols) - 1}
    visited = MapSet.new([start_cell])

    frontier =
      unvisited_neighbors(start_cell, visited, rows, cols)
      |> Enum.map(fn cell -> {Map.get(weights, cell), cell} end)

    do_prim_true(grid, frontier, visited, weights, rows, cols)
  end

  def prim_true(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_prim_true(grid, [], _visited, _weights, _rows, _cols), do: grid

  defp do_prim_true(grid, frontier, visited, weights, rows, cols) do
    {_, cell} = Enum.min_by(frontier, fn {weight, _} -> weight end)
    {row, col} = cell
    {nr, nc} = find_visited_neighbor(cell, visited, rows, cols)

    new_grid = add_passage(grid, row, col, nr, nc)
    new_visited = MapSet.put(visited, cell)

    new_neighbors =
      unvisited_neighbors(cell, new_visited, rows, cols)
      |> Enum.map(fn c -> {Map.get(weights, c), c} end)

    new_frontier =
      frontier
      |> Enum.reject(fn {_, c} -> c == cell end)
      |> Enum.concat(new_neighbors)

    do_prim_true(new_grid, new_frontier, new_visited, weights, rows, cols)
  end

  # ============================================================================
  # Eller's Algorithm
  # ============================================================================

  @doc """
  Generates a maze using Eller's algorithm.

  A row-based algorithm that creates mazes of theoretically infinite height
  using constant memory (proportional only to grid width).

  ## Characteristics

  - **Time**: O(N) where N = rows × cols
  - **Space**: O(cols) auxiliary space for set tracking
  - **Bias**: None significant, though row-layering can be visible
  - **Texture**: Balanced, consistent corridors

  ## Algorithm (Row-by-Row)

  1. Assign unique sets to each cell in the first row.
  2. Randomly connect adjacent cells that are in different sets.
  3. For each unique set, randomly choose at least one cell and carve down.
  4. In the next row, cells with downward passages inherit their sets; others get new sets.
  5. Repeat for all rows. In the last row, connect all remaining disjoint sets.

  ## Options

  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> maze = Yog.Generator.Maze.ellers(10, 10, seed: 42)
      iex> maze.rows
      10
  """
  @spec ellers(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def ellers(rows, cols, opts \\ [])

  def ellers(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)
    row_state = %{}
    next_set_id = 0

    do_ellers(grid, 0, rows, cols, row_state, next_set_id)
  end

  def ellers(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_ellers(grid, r, rows, cols, row_state, next_set_id) when r == rows - 1 do
    {row_state, _next_set_id} = assign_sets(row_state, cols, next_set_id)

    {final_grid, _} =
      Enum.reduce(0..(cols - 2), {grid, row_state}, fn c, {g_acc, s_acc} ->
        set1 = Map.get(s_acc, c)
        set2 = Map.get(s_acc, c + 1)

        if set1 != set2 do
          new_g = add_passage(g_acc, r, c, r, c + 1)
          new_s = merge_sets(s_acc, set2, set1)
          {new_g, new_s}
        else
          {g_acc, s_acc}
        end
      end)

    final_grid
  end

  defp do_ellers(grid, r, rows, cols, row_state, next_set_id) do
    {row_state_1, next_set_id} = assign_sets(row_state, cols, next_set_id)

    {grid_0, row_state} =
      Enum.reduce(0..(cols - 2), {grid, row_state_1}, fn c, {g_acc, s_acc} ->
        set1 = Map.get(s_acc, c)
        set2 = Map.get(s_acc, c + 1)

        if set1 != set2 and :rand.uniform() > 0.5 do
          new_g = add_passage(g_acc, r, c, r, c + 1)
          new_s = merge_sets(s_acc, set2, set1)
          {new_g, new_s}
        else
          {g_acc, s_acc}
        end
      end)

    sets = row_state |> Map.values() |> Enum.uniq()

    {grid, next_row_state} =
      Enum.reduce(sets, {grid_0, %{}}, fn set_id, {g_acc, next_s_acc} ->
        cols_in_set =
          row_state
          |> Enum.filter(fn {_, s} -> s == set_id end)
          |> Enum.map(&elem(&1, 0))

        count = :rand.uniform(length(cols_in_set))
        to_carve = Enum.take_random(cols_in_set, count)

        new_g =
          Enum.reduce(to_carve, g_acc, fn c, g ->
            add_passage(g, r, c, r + 1, c)
          end)

        new_next_s =
          Enum.reduce(to_carve, next_s_acc, fn c, s ->
            Map.put(s, c, set_id)
          end)

        {new_g, new_next_s}
      end)

    do_ellers(grid, r + 1, rows, cols, next_row_state, next_set_id)
  end

  defp assign_sets(row_state, cols, next_set_id) do
    Enum.reduce(0..(cols - 1), {row_state, next_set_id}, fn c, {s_acc, id_acc} ->
      if Map.has_key?(s_acc, c) do
        {s_acc, id_acc}
      else
        {Map.put(s_acc, c, id_acc), id_acc + 1}
      end
    end)
  end

  defp merge_sets(row_state, old_set, new_set) do
    Enum.into(row_state, %{}, fn {c, s} ->
      if s == old_set, do: {c, new_set}, else: {c, s}
    end)
  end

  # ============================================================================
  # Growing Tree Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Growing Tree algorithm.

  A versatile algorithm that can simulate other algorithms (Recursive Backtracker,
  Prim's) depending on how the next cell is selected from the active list.

  ## Strategies

  - `:last` (Default): Selects the most recently added cell (simulates Recursive Backtracker).
  - `:random`: Selects a random cell (simulates Simplified Prim's).
  - `:middle`: Selects the median cell from the active list.
  - `:first`: Selects the oldest cell (creates a very long, straight corridor).

  ## Options

  - `:strategy`: One of `:last`, `:random`, `:middle`, `:first`.
  - `:mix`: A tuple `{strategy, probability}` to switch behaviors (e.g., `{:last, 0.5}`).
  - `:seed`: Random seed for reproducibility.
  """
  @spec growing_tree(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def growing_tree(rows, cols, opts \\ [])

  def growing_tree(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_empty_grid(rows, cols)
    start_cell = {:rand.uniform(rows) - 1, :rand.uniform(cols) - 1}
    active_cells = [start_cell]
    visited = MapSet.new([start_cell])

    do_growing_tree(grid, active_cells, visited, rows, cols, opts)
  end

  def growing_tree(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp do_growing_tree(grid, [], _visited, _rows, _cols, _opts), do: grid

  defp do_growing_tree(grid, active_cells, visited, rows, cols, opts) do
    strategy = Keyword.get(opts, :strategy, :last)

    index = select_index(active_cells, strategy, opts)
    cell = Enum.at(active_cells, index)

    case random_unvisited_neighbor(cell, visited, rows, cols) do
      nil ->
        new_active = List.delete_at(active_cells, index)
        do_growing_tree(grid, new_active, visited, rows, cols, opts)

      neighbor ->
        {r1, c1} = cell
        {r2, c2} = neighbor
        new_grid = add_passage(grid, r1, c1, r2, c2)
        new_visited = MapSet.put(visited, neighbor)
        new_active = [neighbor | active_cells]

        do_growing_tree(new_grid, new_active, new_visited, rows, cols, opts)
    end
  end

  defp select_index(list, strategy, opts) do
    len = length(list)

    case strategy do
      :last ->
        len - 1

      :first ->
        0

      :random ->
        :rand.uniform(len) - 1

      :middle ->
        div(len, 2)

      _ ->
        case Keyword.get(opts, :mix) do
          {:last, prob} when is_float(prob) ->
            if :rand.uniform() < prob, do: len - 1, else: :rand.uniform(len) - 1

          _ ->
            len - 1
        end
    end
  end

  # ============================================================================
  # Recursive Division Algorithm
  # ============================================================================

  @doc """
  Generates a maze using the Recursive Division algorithm.

  Unlike most other algorithms which start with an empty grid and add passages,
  this starts with a full grid and adds walls by removing passages.

  ## Characteristics

  - **Time**: O(N log N)
  - **Space**: O(log N) recursion depth
  - **Bias**: Large rectangles (the chambers formed during division)
  - **Texture**: Fractal-like, clearly organized into rectangular regions

  ## Options

  - `:seed` - Random seed for reproducibility
  """
  @spec recursive_division(non_neg_integer(), non_neg_integer(), keyword()) :: GridGraph.t()
  def recursive_division(rows, cols, opts \\ [])

  def recursive_division(rows, cols, opts) when rows > 0 and cols > 0 do
    if seed = opts[:seed], do: :rand.seed(:exsss, seed)

    grid = create_full_grid(rows, cols)
    divide(grid, 0, 0, rows, cols)
  end

  def recursive_division(_rows, _cols, _opts), do: create_empty_grid(0, 0)

  defp divide(grid, row, col, height, width) do
    cond do
      height < 2 or width < 2 ->
        grid

      height > width ->
        divide_horizontally(grid, row, col, height, width)

      width > height ->
        divide_vertically(grid, row, col, height, width)

      true ->
        if :rand.uniform() > 0.5,
          do: divide_horizontally(grid, row, col, height, width),
          else: divide_vertically(grid, row, col, height, width)
    end
  end

  defp divide_horizontally(grid, row, col, height, width) do
    wall_row = row + :rand.uniform(height - 1) - 1
    passage_col = col + :rand.uniform(width) - 1

    grid =
      Enum.reduce(col..(col + width - 1), grid, fn c, g ->
        if c == passage_col do
          g
        else
          remove_passage(g, wall_row, c, wall_row + 1, c)
        end
      end)

    grid
    |> divide(row, col, wall_row - row + 1, width)
    |> divide(wall_row + 1, col, row + height - wall_row - 1, width)
  end

  defp divide_vertically(grid, row, col, height, width) do
    wall_col = col + :rand.uniform(width - 1) - 1
    passage_row = row + :rand.uniform(height) - 1

    grid =
      Enum.reduce(row..(row + height - 1), grid, fn r, g ->
        if r == passage_row do
          g
        else
          remove_passage(g, r, wall_col, r, wall_col + 1)
        end
      end)

    grid
    |> divide(row, col, height, wall_col - col + 1)
    |> divide(row, wall_col + 1, height, col + width - wall_col - 1)
  end

  defp create_full_grid(rows, cols) do
    grid = create_empty_grid(rows, cols)

    grid_horizontal =
      Enum.reduce(0..(rows - 1), grid, fn r, g_r ->
        Enum.reduce(0..(cols - 2), g_r, fn c, g_c ->
          add_passage(g_c, r, c, r, c + 1)
        end)
      end)

    Enum.reduce(0..(rows - 2), grid_horizontal, fn r, g_r ->
      Enum.reduce(0..(cols - 1), g_r, fn c, g_c ->
        add_passage(g_c, r, c, r + 1, c)
      end)
    end)
  end

  defp remove_passage(%GridGraph{graph: graph, cols: cols} = grid, r1, c1, r2, c2) do
    from_id = r1 * cols + c1
    to_id = r2 * cols + c2
    %{grid | graph: Yog.Model.remove_edge(graph, from_id, to_id)}
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  @doc """
  Creates an empty grid graph with nodes but no edges.

  Each cell becomes a node with ID = row * cols + col.
  """
  @spec create_empty_grid(non_neg_integer(), non_neg_integer()) :: GridGraph.t()
  def create_empty_grid(rows, cols) when rows > 0 and cols > 0 do
    graph =
      Enum.reduce(0..(rows - 1), Model.new(:undirected), fn row, g_acc ->
        Enum.reduce(0..(cols - 1), g_acc, fn col, g ->
          node_id = row * cols + col
          Model.add_node(g, node_id, nil)
        end)
      end)

    GridGraph.new(graph, rows, cols)
  end

  def create_empty_grid(_rows, _cols) do
    GridGraph.new(Model.new(:undirected), 0, 0)
  end

  @doc """
  Adds a bidirectional passage between two adjacent cells.

  The cells are identified by their {row, col} coordinates.
  """
  @spec add_passage(
          GridGraph.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          GridGraph.t()
  def add_passage(%GridGraph{graph: graph, cols: cols} = grid, row1, col1, row2, col2) do
    from_id = row1 * cols + col1
    to_id = row2 * cols + col2

    new_graph =
      case Model.add_edge(graph, from_id, to_id, 1) do
        {:ok, g} -> g
        {:error, _} -> graph
      end

    %{grid | graph: new_graph}
  end

  # --- Internal Maze Helpers ---

  defp pick_any_neighbor(row, col, rows, cols) do
    neighbors(row, col, rows, cols) |> Enum.random()
  end

  defp neighbors(row, col, rows, cols) do
    [
      {row - 1, col},
      {row + 1, col},
      {row, col - 1},
      {row, col + 1}
    ]
    |> Enum.filter(fn {r, c} -> r >= 0 and r < rows and c >= 0 and c < cols end)
  end

  defp unvisited_neighbors({r, c}, visited, rows, cols) do
    neighbors(r, c, rows, cols) |> Enum.reject(&MapSet.member?(visited, &1))
  end

  defp visited_neighbors({r, c}, visited, rows, cols) do
    neighbors(r, c, rows, cols) |> Enum.filter(&MapSet.member?(visited, &1))
  end

  defp random_unvisited_neighbor(cell, visited, rows, cols) do
    case unvisited_neighbors(cell, visited, rows, cols) do
      [] -> nil
      list -> Enum.random(list)
    end
  end

  defp has_visited_neighbor(cell, visited, rows, cols) do
    visited_neighbors(cell, visited, rows, cols) != []
  end

  defp find_visited_neighbor(cell, visited, rows, cols) do
    visited_neighbors(cell, visited, rows, cols) |> Enum.random()
  end

  defp hunt_for_cell(visited, rows, cols, :sequential) do
    Enum.find_value(0..(rows - 1), fn r ->
      Enum.find_value(0..(cols - 1), fn c ->
        cell = {r, c}

        if not MapSet.member?(visited, cell) and has_visited_neighbor(cell, visited, rows, cols) do
          cell
        else
          nil
        end
      end)
    end)
  end

  defp hunt_for_cell(visited, rows, cols, :random) do
    for(r <- 0..(rows - 1), c <- 0..(cols - 1), !MapSet.member?(visited, {r, c}), do: {r, c})
    |> Enum.shuffle()
    |> Enum.find(&has_visited_neighbor(&1, visited, rows, cols))
  end
end
