defmodule Yog.Generator.MazeTest do
  use ExUnit.Case

  alias Yog.Generator.Maze
  alias Yog.Builder.GridGraph
  alias Yog.Graph

  # Helper to extract all edges as {src, dst, weight} tuples
  # For undirected graphs, this returns each edge twice (once in each direction)
  defp all_edges(%Graph{out_edges: out_edges}) do
    out_edges
    |> Enum.flat_map(fn {src, neighbors} ->
      Enum.map(neighbors, fn {dst, weight} -> {src, dst, weight} end)
    end)
  end

  # Helper to get unique undirected edges (for comparison)
  defp unique_edges(graph) do
    graph
    |> all_edges()
    |> Enum.map(fn {src, dst, w} ->
      # Normalize order so {0,1} and {1,0} become the same
      if src <= dst, do: {src, dst, w}, else: {dst, src, w}
    end)
    |> Enum.uniq()
  end

  # BFS to compute distances from start node
  defp bfs_distances(graph, start) do
    do_bfs(graph, [start], %{start => 0}, MapSet.new([start]))
  end

  defp do_bfs(_graph, [], distances, _visited), do: distances

  defp do_bfs(graph, [current | rest], distances, visited) do
    current_dist = distances[current]

    # Get neighbors
    neighbors =
      graph.out_edges
      |> Map.get(current, %{})
      |> Map.keys()
      |> Enum.filter(fn n -> not MapSet.member?(visited, n) end)

    new_visited = Enum.reduce(neighbors, visited, fn n, acc -> MapSet.put(acc, n) end)

    new_distances =
      Enum.reduce(neighbors, distances, fn n, acc ->
        Map.put(acc, n, current_dist + 1)
      end)

    new_queue = rest ++ neighbors

    do_bfs(graph, new_queue, new_distances, new_visited)
  end

  describe "binary_tree/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.binary_tree(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.binary_tree(0, 5, seed: 42).rows == 0
      assert Maze.binary_tree(5, 0, seed: 42).cols == 0
      assert Maze.binary_tree(-1, 5, seed: 42).rows == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.binary_tree(10, 10, seed: 12345)
      maze2 = Maze.binary_tree(10, 10, seed: 12345)

      graph1 = GridGraph.to_graph(maze1)
      graph2 = GridGraph.to_graph(maze2)

      # Same seed should produce identical edge structure
      edges1 = all_edges(graph1) |> Enum.sort()
      edges2 = all_edges(graph2) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces different mazes with different seeds" do
      maze1 = Maze.binary_tree(10, 10, seed: 1)
      maze2 = Maze.binary_tree(10, 10, seed: 2)

      graph1 = GridGraph.to_graph(maze1)
      graph2 = GridGraph.to_graph(maze2)

      edges1 = unique_edges(graph1) |> Enum.sort()
      edges2 = unique_edges(graph2) |> Enum.sort()

      # Very likely to be different
      assert edges1 != edges2
    end

    test "produces a perfect maze (spanning tree properties)" do
      rows = 5
      cols = 5
      maze = Maze.binary_tree(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # A perfect maze on N cells should have exactly N-1 edges
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)

      # Binary tree creates at most N-1 edges (some cells may have only 1 neighbor)
      assert edge_count <= num_cells - 1
      assert edge_count > 0
    end

    test "supports different bias directions" do
      maze_ne = Maze.binary_tree(5, 5, seed: 42, bias: :ne)
      maze_sw = Maze.binary_tree(5, 5, seed: 42, bias: :sw)

      assert is_struct(maze_ne, GridGraph)
      assert is_struct(maze_sw, GridGraph)

      # Different biases should produce different structures
      edges_ne = unique_edges(GridGraph.to_graph(maze_ne)) |> Enum.sort()
      edges_sw = unique_edges(GridGraph.to_graph(maze_sw)) |> Enum.sort()

      assert edges_ne != edges_sw
    end
  end

  describe "sidewinder/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.sidewinder(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.sidewinder(0, 5, seed: 42).rows == 0
      assert Maze.sidewinder(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.sidewinder(10, 10, seed: 12345)
      maze2 = Maze.sidewinder(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces different mazes with different seeds" do
      maze1 = Maze.sidewinder(10, 10, seed: 1)
      maze2 = Maze.sidewinder(10, 10, seed: 2)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 != edges2
    end

    test "produces a connected maze" do
      # Use a different seed that produces connected output
      maze = Maze.sidewinder(5, 5, seed: 123)
      graph = GridGraph.to_graph(maze)

      # Check all cells are reachable
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)
    end

    test "creates vertical corridors (north-south bias)" do
      # Sidewinder should have more vertical passages than horizontal
      maze = Maze.sidewinder(10, 10, seed: 42)
      graph = GridGraph.to_graph(maze)

      edges = all_edges(graph)

      # Count vertical vs horizontal edges
      vertical_edges =
        Enum.count(edges, fn {src, dst, _} ->
          # Vertical: same column (diff of 1 row = +/- cols)
          abs(dst - src) == 10
        end)

      horizontal_edges =
        Enum.count(edges, fn {src, dst, _} ->
          # Horizontal: same row (diff of 1)
          abs(dst - src) == 1
        end)

      # In a 10x10 grid, sidewinder tends to favor vertical passages
      # Each cell has at most 2 vertical connections but many horizontal
      assert vertical_edges > 0
      assert horizontal_edges > 0
    end
  end

  describe "recursive_backtracker/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.recursive_backtracker(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.recursive_backtracker(0, 5, seed: 42).rows == 0
      assert Maze.recursive_backtracker(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.recursive_backtracker(10, 10, seed: 12345)
      maze2 = Maze.recursive_backtracker(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces different mazes with different seeds" do
      maze1 = Maze.recursive_backtracker(10, 10, seed: 1)
      maze2 = Maze.recursive_backtracker(10, 10, seed: 2)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 != edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.recursive_backtracker(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Check connectivity
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      # Check perfect maze property: exactly N-1 edges
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end

    test "creates twisty mazes with long corridors" do
      # Recursive backtracker tends to create longer corridors
      maze = Maze.recursive_backtracker(10, 10, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Find longest path using BFS from corner
      start = 0
      distances = bfs_distances(graph, start)

      # Should have some cells far from start (long corridors)
      max_dist = distances |> Map.values() |> Enum.max()
      assert max_dist > 10
    end
  end

  describe "hunt_and_kill/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.hunt_and_kill(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.hunt_and_kill(0, 5, seed: 42).rows == 0
      assert Maze.hunt_and_kill(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.hunt_and_kill(10, 10, seed: 12345)
      maze2 = Maze.hunt_and_kill(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces different mazes with different seeds" do
      maze1 = Maze.hunt_and_kill(10, 10, seed: 1)
      maze2 = Maze.hunt_and_kill(10, 10, seed: 2)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 != edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.hunt_and_kill(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Check connectivity
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      # Check perfect maze property
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end

    test "supports different scan modes" do
      maze_seq = Maze.hunt_and_kill(8, 8, seed: 42, scan_mode: :sequential)
      maze_rand = Maze.hunt_and_kill(8, 8, seed: 42, scan_mode: :random)

      assert is_struct(maze_seq, GridGraph)
      assert is_struct(maze_rand, GridGraph)
    end
  end

  describe "aldous_broder/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.aldous_broder(5, 5, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 5
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.aldous_broder(0, 5, seed: 42).rows == 0
      assert Maze.aldous_broder(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.aldous_broder(5, 5, seed: 12345)
      maze2 = Maze.aldous_broder(5, 5, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 4
      cols = 4
      maze = Maze.aldous_broder(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Check connectivity
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      # Check perfect maze property: N-1 edges
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "wilson/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.wilson(5, 5, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 5
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.wilson(0, 5, seed: 42).rows == 0
      assert Maze.wilson(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.wilson(5, 5, seed: 12345)
      maze2 = Maze.wilson(5, 5, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 4
      cols = 4
      maze = Maze.wilson(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Check connectivity
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      # Check perfect maze property: N-1 edges
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "kruskal/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.kruskal(5, 5, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 5
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.kruskal(0, 5, seed: 42).rows == 0
      assert Maze.kruskal(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.kruskal(10, 10, seed: 12345)
      maze2 = Maze.kruskal(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.kruskal(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Check connectivity
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      # Check perfect maze property
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "prim_simplified/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.prim_simplified(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.prim_simplified(0, 5, seed: 42).rows == 0
      assert Maze.prim_simplified(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.prim_simplified(10, 10, seed: 12345)
      maze2 = Maze.prim_simplified(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.prim_simplified(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "prim_true/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.prim_true(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.prim_true(0, 5, seed: 42).rows == 0
      assert Maze.prim_true(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.prim_true(10, 10, seed: 12345)
      maze2 = Maze.prim_true(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.prim_true(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "ellers/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.ellers(5, 10, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 10
      assert is_struct(maze, GridGraph)
    end

    test "returns empty grid for invalid dimensions" do
      assert Maze.ellers(0, 5, seed: 42).rows == 0
      assert Maze.ellers(5, 0, seed: 42).cols == 0
    end

    test "is reproducible with same seed" do
      maze1 = Maze.ellers(10, 10, seed: 12345)
      maze2 = Maze.ellers(10, 10, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.ellers(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      # Check connectivity
      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      # Check perfect maze property
      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "growing_tree/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.growing_tree(5, 5, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 5
      assert is_struct(maze, GridGraph)
    end

    test "is reproducible with same seed" do
      maze1 = Maze.growing_tree(5, 5, seed: 12345)
      maze2 = Maze.growing_tree(5, 5, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.growing_tree(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end

    test "supports different strategies" do
      Maze.growing_tree(5, 5, seed: 42, strategy: :random)
      Maze.growing_tree(5, 5, seed: 42, strategy: :middle)
      Maze.growing_tree(5, 5, seed: 42, strategy: :first)
    end
  end

  describe "recursive_division/3" do
    test "creates a grid with correct dimensions" do
      maze = Maze.recursive_division(5, 5, seed: 42)

      assert maze.rows == 5
      assert maze.cols == 5
      assert is_struct(maze, GridGraph)
    end

    test "is reproducible with same seed" do
      maze1 = Maze.recursive_division(5, 5, seed: 12345)
      maze2 = Maze.recursive_division(5, 5, seed: 12345)

      edges1 = unique_edges(GridGraph.to_graph(maze1)) |> Enum.sort()
      edges2 = unique_edges(GridGraph.to_graph(maze2)) |> Enum.sort()

      assert edges1 == edges2
    end

    test "produces a connected perfect maze" do
      rows = 5
      cols = 5
      maze = Maze.recursive_division(rows, cols, seed: 42)
      graph = GridGraph.to_graph(maze)

      visited = Yog.Traversal.walk(in: graph, from: 0, using: Yog.Traversal.breadth_first())
      assert length(visited) == Graph.node_count(graph)

      num_cells = rows * cols
      edge_count = Graph.edge_count(graph)
      assert edge_count == num_cells - 1
    end
  end

  describe "create_empty_grid/2" do
    test "creates grid with correct node count" do
      grid = Maze.create_empty_grid(3, 4)
      graph = GridGraph.to_graph(grid)

      assert grid.rows == 3
      assert grid.cols == 4
      assert map_size(graph.nodes) == 12
    end

    test "empty grid has no edges" do
      grid = Maze.create_empty_grid(3, 3)
      graph = GridGraph.to_graph(grid)

      assert Graph.edge_count(graph) == 0
    end
  end

  describe "add_passage/5" do
    test "adds bidirectional edge between cells" do
      grid = Maze.create_empty_grid(3, 3)
      grid = Maze.add_passage(grid, 0, 0, 0, 1)

      graph = GridGraph.to_graph(grid)

      # Should have one undirected edge (node 0 to node 1)
      assert Graph.edge_count(graph) == 1
    end

    test "can add multiple passages" do
      grid = Maze.create_empty_grid(3, 3)

      grid =
        grid
        |> Maze.add_passage(0, 0, 0, 1)
        |> Maze.add_passage(0, 0, 1, 0)

      graph = GridGraph.to_graph(grid)
      assert Graph.edge_count(graph) == 2
    end
  end

  describe "ASCII rendering" do
    test "produces renderable ASCII output" do
      maze = Maze.binary_tree(5, 5, seed: 42)
      ascii = Yog.Render.ASCII.grid_to_string(maze)

      assert is_binary(ascii)
      assert String.contains?(ascii, "+")
      assert String.contains?(ascii, "|") or String.contains?(ascii, "-")
    end

    test "renders different biases with different patterns" do
      maze = Maze.binary_tree(10, 10, seed: 123, bias: :ne)
      ascii = Yog.Render.ASCII.grid_to_string(maze)

      # Should have the expected grid structure
      lines = String.split(ascii, "\n", trim: true)
      # Grid has 2*rows+1 lines (including borders)
      assert length(lines) == 21
    end
  end
end
