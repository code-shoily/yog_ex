defmodule Yog.Generator.Classic do
  @moduledoc """
  Deterministic graph generators for common graph structures.

  Deterministic generators produce identical graphs given the same parameters,
  useful for testing algorithms, benchmarking, and creating known structures.

  ## Available Generators

  | Generator | Graph Type | Complexity | Edges |
  |-----------|------------|------------|-------|
  | `complete/1` | K_n | O(n²) | n(n-1)/2 |
  | `cycle/1` | C_n | O(n) | n |
  | `path/1` | P_n | O(n) | n-1 |
  | `star/1` | S_n | O(n) | n-1 |
  | `wheel/1` | W_n | O(n) | 2(n-1) |
  | `grid_2d/2` | Lattice | O(mn) | (m-1)n + m(n-1) |
  | `complete_bipartite/2` | K_{m,n} | O(mn) | mn |
  | `binary_tree/1` | Tree | O(2^d) | 2^(d+1) - 2 |
  | `petersen/0` | Petersen | O(1) | 15 |
  | `empty/1` | Isolated | O(n) | 0 |

  ## Examples

      # Generate a cycle graph C5
      iex> cycle = Yog.Generator.Classic.cycle(5)
      iex> Yog.Model.order(cycle)
      5

      # Generate a complete graph K4
      iex> complete = Yog.Generator.Classic.complete(4)
      iex> Yog.Model.order(complete)
      4

      # Generate a 3x4 grid
      iex> grid = Yog.Generator.Classic.grid_2d(3, 4)
      iex> Yog.Model.order(grid)
      12

      # Generate a depth-3 binary tree (15 nodes total)
      iex> tree = Yog.Generator.Classic.binary_tree(3)
      iex> Yog.Model.order(tree)
      15

      # Generate a complete bipartite graph K_{3,4}
      iex> bipartite = Yog.Generator.Classic.complete_bipartite(3, 4)
      iex> Yog.Model.order(bipartite)
      7

      # Generate the Petersen graph
      iex> petersen = Yog.Generator.Classic.petersen()
      iex> Yog.Model.order(petersen)
      10

  ## Use Cases

  - **Algorithm testing**: Verify correctness on known structures
  - **Benchmarking**: Compare performance across standard graphs
  - **Network modeling**: Represent specific topologies (star, grid, tree)
  - **Graph theory**: Study properties of well-known graphs

  ## References

  - [Wikipedia: Graph Generators](https://en.wikipedia.org/wiki/Graph_theory#Graph_generators)
  - [Complete Graph](https://en.wikipedia.org/wiki/Complete_graph)
  - [Cycle Graph](https://en.wikipedia.org/wiki/Cycle_graph)
  - [Petersen Graph](https://en.wikipedia.org/wiki/Petersen_graph)
  """

  # ============= Complete Graph =============

  @doc """
  Generates a complete graph K_n where every node connects to every other.

  In a complete graph with n nodes, there are n(n-1)/2 edges for undirected
  graphs and n(n-1) edges for directed graphs. All edges have unit weight (1).

  **Time Complexity:** O(n²)

  ## Examples

      iex> k5 = Yog.Generator.Classic.complete(5)
      iex> Yog.Model.order(k5)
      5
      iex> # K5 is undirected, each node has 4 neighbors
      ...> length(Yog.neighbors(k5, 0))
      4

  ## Use Cases

  - Testing algorithms on dense graphs
  - Maximum connectivity scenarios
  - Clique detection benchmarks
  """
  @spec complete(integer()) :: Yog.graph()
  def complete(n), do: complete_with_type(n, :undirected)

  @doc """
  Generates a complete graph with specified graph type.

  ## Examples

      iex> directed_k4 = Yog.Generator.Classic.complete_with_type(4, :directed)
      iex> Yog.Model.type(directed_k4)
      :directed
      iex> Yog.Model.order(directed_k4)
      4
  """
  @spec complete_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def complete_with_type(n, graph_type) when n > 0 do
    base = Yog.new(graph_type)

    # Add all nodes
    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Add all edges (each pair connects both ways for undirected)
    edges = for i <- 0..(n - 1)//1, j <- 0..(n - 1)//1, i != j, do: {i, j, 1}

    edges
    |> maybe_filter_undirected(graph_type)
    |> Enum.reduce(graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  def complete_with_type(_n, _graph_type), do: Yog.new(:undirected)

  defp maybe_filter_undirected(edges, :undirected) do
    # For undirected graphs, only keep edges where from < to
    Enum.filter(edges, fn {from, to, _} -> from < to end)
  end

  defp maybe_filter_undirected(edges, :directed), do: edges

  # ============= Cycle Graph =============

  @doc """
  Generates a cycle graph C_n where nodes form a ring.

  A cycle graph connects n nodes in a circular pattern:
  0 -> 1 -> 2 -> ... -> (n-1) -> 0. Each node has degree 2.

  Returns an empty graph if n < 3 (cycles require at least 3 nodes).

  **Time Complexity:** O(n)

  ## Examples

      iex> c6 = Yog.Generator.Classic.cycle(6)
      iex> Yog.Model.order(c6)
      6
      iex> # Each node in a cycle has degree 2
      ...> length(Yog.neighbors(c6, 0))
      2

  ## Use Cases

  - Ring network topologies
  - Circular dependency testing
  - Hamiltonian cycle benchmarks
  """
  @spec cycle(integer()) :: Yog.graph()
  def cycle(n), do: cycle_with_type(n, :undirected)

  @doc """
  Generates a cycle graph with specified graph type.
  """
  @spec cycle_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def cycle_with_type(n, _graph_type) when n < 3, do: Yog.new(:undirected)

  def cycle_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    edges = for i <- 0..(n - 1)//1, do: {i, rem(i + 1, n), 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Path Graph =============

  @doc """
  Generates a path graph P_n where nodes form a linear chain.

  A path graph connects n nodes in a line: 0 -> 1 -> 2 -> ... -> (n-1).
  End nodes have degree 1, interior nodes have degree 2.

  **Time Complexity:** O(n)

  ## Examples

      iex> p5 = Yog.Generator.Classic.path(5)
      iex> Yog.Model.order(p5)
      5
      iex> # End nodes have degree 1
      ...> length(Yog.neighbors(p5, 0))
      1
      iex> # Middle nodes have degree 2
      ...> length(Yog.neighbors(p5, 2))
      2

  ## Use Cases

  - Linear network topologies
  - Linked list representations
  - Pathfinding benchmarks
  """
  @spec path(integer()) :: Yog.graph()
  def path(n), do: path_with_type(n, :undirected)

  @doc """
  Generates a path graph with specified graph type.
  """
  @spec path_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def path_with_type(n, _graph_type) when n <= 0, do: Yog.new(:undirected)
  def path_with_type(1, graph_type), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def path_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    edges = if n >= 2, do: for(i <- 0..(n - 2)//1, do: {i, i + 1, 1}), else: []

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Star Graph =============

  @doc """
  Generates a star graph S_n with one central hub.

  A star graph has one central node (0) connected to all n-1 outer nodes.
  The center has degree n-1, outer nodes have degree 1.

  **Time Complexity:** O(n)

  ## Examples

      iex> s5 = Yog.Generator.Classic.star(5)
      iex> Yog.Model.order(s5)
      5
      iex> # Center (node 0) has degree 4
      ...> length(Yog.neighbors(s5, 0))
      4
      iex> # Leaf nodes have degree 1
      ...> length(Yog.neighbors(s5, 1))
      1

  ## Use Cases

  - Hub-and-spoke networks
  - Client-server architectures
  - Broadcast scenarios
  """
  @spec star(integer()) :: Yog.graph()
  def star(n), do: star_with_type(n, :undirected)

  @doc """
  Generates a star graph with specified graph type.
  """
  @spec star_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def star_with_type(n, _graph_type) when n <= 0, do: Yog.new(:undirected)
  def star_with_type(1, graph_type), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def star_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    edges = if n >= 2, do: for(i <- 1..(n - 1)//1, do: {0, i, 1}), else: []

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Wheel Graph =============

  @doc """
  Generates a wheel graph W_n - a cycle with a central hub.

  A wheel graph combines a star and a cycle: center (0) connects to all
  rim nodes (1..n-1), and rim nodes form a cycle.

  **Time Complexity:** O(n)

  ## Examples

      iex> w6 = Yog.Generator.Classic.wheel(6)
      iex> Yog.Model.order(w6)
      6
      iex> # Center has degree 5 (connected to all rim nodes)
      ...> length(Yog.neighbors(w6, 0))
      5
      iex> # Rim nodes have degree 3 (center + 2 neighbors in cycle)
      ...> length(Yog.neighbors(w6, 1))
      3

  ## Use Cases

  - Wheel network topologies
  - Centralized routing with backup paths
  - Spoke-hub distribution
  """
  @spec wheel(integer()) :: Yog.graph()
  def wheel(n), do: wheel_with_type(n, :undirected)

  @doc """
  Generates a wheel graph with specified graph type.
  """
  @spec wheel_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def wheel_with_type(n, _graph_type) when n < 4, do: Yog.new(:undirected)

  def wheel_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Add all nodes: 0 is center, 1..(n-1) are rim
    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Spokes: center (0) to each rim node
    spokes = for i <- 1..(n - 1), do: {0, i, 1}

    # Rim cycle: edges between consecutive rim nodes
    rim =
      for i <- 1..(n - 1)//1 do
        next = if(i == n - 1, do: 1, else: i + 1)
        {i, next, 1}
      end

    Enum.reduce(spokes ++ rim, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Bipartite Graphs =============

  @doc """
  Generates a complete bipartite graph K_{m,n}.

  In a complete bipartite graph, every node in the first partition
  connects to every node in the second partition.

  **Time Complexity:** O(mn)

  ## Examples

      iex> k34 = Yog.Generator.Classic.complete_bipartite(3, 4)
      iex> Yog.Model.order(k34)
      7
      iex> # First partition nodes (0-2) have degree 4
      ...> length(Yog.neighbors(k34, 0))
      4
      iex> # Second partition nodes (3-6) have degree 3
      ...> length(Yog.neighbors(k34, 3))
      3

  ## Use Cases

  - Bipartite matching problems
  - Assignment problems
  - Recommender systems
  """
  @spec complete_bipartite(integer(), integer()) :: Yog.graph()
  def complete_bipartite(m, n), do: complete_bipartite_with_type(m, n, :undirected)

  @doc """
  Generates a complete bipartite graph with specified graph type.
  """
  @spec complete_bipartite_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def complete_bipartite_with_type(m, n, graph_type) when m >= 0 and n >= 0 do
    base = Yog.new(graph_type)

    # Total nodes: m + n
    # First partition: 0..(m-1)
    # Second partition: m..(m+n-1)
    total = m + n

    graph =
      if total > 0 do
        Enum.reduce(0..(total - 1), base, fn i, g ->
          Yog.add_node(g, i, nil)
        end)
      else
        base
      end

    # All edges from first partition to second
    edges = for i <- 0..(m - 1)//1, j <- m..(total - 1)//1, do: {i, j, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Trees =============

  @doc """
  Generates a binary tree of specified depth.

  A complete binary tree where each node (except leaves) has exactly 2 children.
  Total nodes: 2^(depth+1) - 1

  **Time Complexity:** O(2^depth)

  ## Examples

      iex> tree = Yog.Generator.Classic.binary_tree(3)
      iex> # Depth-3 binary tree: 1 + 2 + 4 + 8 = 15 nodes
      ...> Yog.Model.order(tree)
      15

  ## Use Cases

  - Hierarchical structures
  - Decision trees
  - Search tree benchmarks
  """
  @spec binary_tree(integer()) :: Yog.graph()
  def binary_tree(depth), do: binary_tree_with_type(depth, :undirected)

  @doc """
  Generates a binary tree with specified graph type.
  """
  @spec binary_tree_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def binary_tree_with_type(depth, _graph_type) when depth < 0, do: Yog.new(:undirected)
  def binary_tree_with_type(0, graph_type), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def binary_tree_with_type(depth, graph_type) do
    base = Yog.new(graph_type)

    # Total nodes: 2^(depth+1) - 1
    total_nodes = Integer.pow(2, depth + 1) - 1

    graph =
      Enum.reduce(0..(total_nodes - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # For each non-leaf node, add edges to its children
    # Node i has children at 2i+1 and 2i+2
    edges =
      for i <- 0..(Integer.pow(2, depth) - 2)//1,
          left = 2 * i + 1,
          right = 2 * i + 2,
          do: [{i, left, 1}, {i, right, 1}]

    Enum.reduce(List.flatten(edges), graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Grid Graphs =============

  @doc """
  Generates a 2D grid (lattice) graph with specified rows and columns.

  Each cell connects to its adjacent neighbors (up, down, left, right).

  **Time Complexity:** O(rows × cols)

  ## Examples

      iex> grid = Yog.Generator.Classic.grid_2d(3, 4)
      iex> # 3x4 grid has 12 nodes
      ...> Yog.Model.order(grid)
      12
      iex> # Corner nodes have degree 2
      ...> length(Yog.neighbors(grid, 0))
      2
      iex> # Interior nodes have degree 4
      ...> length(Yog.neighbors(grid, 5))
      4

  ## Use Cases

  - Mesh networks
  - Image processing
  - Spatial simulations
  """
  @spec grid_2d(integer(), integer()) :: Yog.graph()
  def grid_2d(rows, cols), do: grid_2d_with_type(rows, cols, :undirected)

  @doc """
  Generates a 2D grid with specified graph type.
  """
  @spec grid_2d_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def grid_2d_with_type(rows, cols, _graph_type) when rows <= 0 or cols <= 0,
    do: Yog.new(:undirected)

  def grid_2d_with_type(rows, cols, graph_type) do
    base = Yog.new(graph_type)
    total = rows * cols

    graph =
      Enum.reduce(0..(total - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Generate edges between adjacent cells
    # Node at (r, c) has index r * cols + c
    horizontal_edges =
      if cols >= 2 do
        for r <- 0..(rows - 1)//1,
            c <- 0..(cols - 2)//1,
            do: {r * cols + c, r * cols + c + 1, 1}
      else
        []
      end

    vertical_edges =
      if rows >= 2 do
        for r <- 0..(rows - 2)//1,
            c <- 0..(cols - 1)//1,
            do: {r * cols + c, (r + 1) * cols + c, 1}
      else
        []
      end

    Enum.reduce(horizontal_edges ++ vertical_edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Special Graphs =============

  @doc """
  Generates the Petersen graph - a famous graph in graph theory.

  The Petersen graph has 10 nodes, 15 edges, diameter 2, girth 5.
  It's a common counterexample in graph theory.

  **Time Complexity:** O(1)

  ## Examples

      iex> p = Yog.Generator.Classic.petersen()
      iex> # Petersen graph has 10 nodes
      ...> Yog.Model.order(p)
      10
      iex> # All nodes have degree 3
      ...> length(Yog.neighbors(p, 0))
      3

  ## Properties

  - Non-planar
  - Non-Hamiltonian
  - Vertex-transitive
  - Chromatic number 3
  """
  @spec petersen() :: Yog.graph()
  def petersen, do: petersen_with_type(:undirected)

  @doc """
  Generates the Petersen graph with specified graph type.
  """
  @spec petersen_with_type(Yog.graph_type()) :: Yog.graph()
  def petersen_with_type(graph_type) do
    # Petersen graph has 10 nodes arranged as two pentagons:
    # - Outer pentagon: nodes 0, 1, 2, 3, 4 (5-cycle)
    # - Inner star: nodes 5, 6, 7, 8, 9 (5-cycle)
    # - Spokes connecting outer to inner

    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..9, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Outer pentagon edges (0-1-2-3-4-0)
    outer_edges = [{0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 0, 1}]

    # Inner star edges (5-7-9-6-8-5) - note this is a 5-pointed star
    inner_edges = [{5, 7, 1}, {7, 9, 1}, {9, 6, 1}, {6, 8, 1}, {8, 5, 1}]

    # Spokes connecting outer to inner (0-5, 1-6, 2-7, 3-8, 4-9)
    spokes = [{0, 5, 1}, {1, 6, 1}, {2, 7, 1}, {3, 8, 1}, {4, 9, 1}]

    Enum.reduce(outer_edges ++ inner_edges ++ spokes, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Empty Graph =============

  @doc """
  Generates an empty graph with n isolated nodes (no edges).

  **Time Complexity:** O(n)

  ## Examples

      iex> empty5 = Yog.Generator.Classic.empty(5)
      iex> Yog.Model.order(empty5)
      5
      iex> # No edges - isolated nodes have degree 0
      ...> length(Yog.neighbors(empty5, 0))
      0
  """
  @spec empty(integer()) :: Yog.graph()
  def empty(n), do: empty_with_type(n, :undirected)

  @doc """
  Generates an empty graph with specified graph type.
  """
  @spec empty_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def empty_with_type(n, _graph_type) when n <= 0, do: Yog.new(:undirected)

  def empty_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    Enum.reduce(0..(n - 1), base, fn i, g ->
      Yog.add_node(g, i, nil)
    end)
  end
end
