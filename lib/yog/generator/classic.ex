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
  | `hypercube/1` | Q_n | O(n × 2^n) | n × 2^(n-1) |
  | `ladder/1` | Ladder | O(n) | 3n - 2 |
  | `turan/2` | T(n,r) | O(n²) | Complete r-partite |

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
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Add all edges directly without intermediate list allocation
    Enum.reduce(0..(n - 1), graph, fn i, g_i ->
      Enum.reduce(0..(n - 1), g_i, fn j, g_j ->
        if i != j && (graph_type == :directed || i < j) do
          Yog.add_edge!(g_j, i, j, 1)
        else
          g_j
        end
      end)
    end)
  end

  def complete_with_type(_n, _graph_type), do: Yog.new(:undirected)

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
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    Enum.reduce(0..(n - 1)//1, graph, fn i, g ->
      Yog.add_edge!(g, i, rem(i + 1, n), 1)
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
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    if n >= 2 do
      Enum.reduce(0..(n - 2)//1, graph, fn i, g ->
        Yog.add_edge!(g, i, i + 1, 1)
      end)
    else
      graph
    end
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
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    if n >= 2 do
      Enum.reduce(1..(n - 1)//1, graph, fn i, g ->
        Yog.add_edge!(g, 0, i, 1)
      end)
    else
      graph
    end
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
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Spokes: center (0) to each rim node
    graph_with_spokes =
      Enum.reduce(1..(n - 1)//1, graph, fn i, g ->
        Yog.add_edge!(g, 0, i, 1)
      end)

    # Rim cycle: edges between consecutive rim nodes
    Enum.reduce(1..(n - 1)//1, graph_with_spokes, fn i, g ->
      next = if(i == n - 1, do: 1, else: i + 1)
      Yog.add_edge!(g, i, next, 1)
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
    Enum.reduce(0..(m - 1)//1, graph, fn i, g_i ->
      Enum.reduce(m..(total - 1)//1, g_i, fn j, g_j ->
        Yog.add_edge!(g_j, i, j, 1)
      end)
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
    Enum.reduce(0..(Integer.pow(2, depth) - 2), graph, fn i, g ->
      left = 2 * i + 1
      right = 2 * i + 2

      g
      |> Yog.add_edge!(i, left, 1)
      |> Yog.add_edge!(i, right, 1)
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

    # Generate horizontal edges
    graph_h =
      if cols >= 2 do
        Enum.reduce(0..(rows - 1)//1, graph, fn r, g_r ->
          Enum.reduce(0..(cols - 2)//1, g_r, fn c, g_c ->
            Yog.add_edge!(g_c, r * cols + c, r * cols + c + 1, 1)
          end)
        end)
      else
        graph
      end

    # Generate vertical edges
    if rows >= 2 do
      Enum.reduce(0..(rows - 2)//1, graph_h, fn r, g_r ->
        Enum.reduce(0..(cols - 1)//1, g_r, fn c, g_c ->
          Yog.add_edge!(g_c, r * cols + c, (r + 1) * cols + c, 1)
        end)
      end)
    else
      graph_h
    end
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
    # Inner star edges (5-7-9-6-8-5) - note this is a 5-pointed star
    # Spokes connecting outer to inner (0-5, 1-6, 2-7, 3-8, 4-9)
    graph
    |> Yog.add_edge!(0, 1, 1)
    |> Yog.add_edge!(1, 2, 1)
    |> Yog.add_edge!(2, 3, 1)
    |> Yog.add_edge!(3, 4, 1)
    |> Yog.add_edge!(4, 0, 1)
    |> Yog.add_edge!(5, 7, 1)
    |> Yog.add_edge!(7, 9, 1)
    |> Yog.add_edge!(9, 6, 1)
    |> Yog.add_edge!(6, 8, 1)
    |> Yog.add_edge!(8, 5, 1)
    |> Yog.add_edge!(0, 5, 1)
    |> Yog.add_edge!(1, 6, 1)
    |> Yog.add_edge!(2, 7, 1)
    |> Yog.add_edge!(3, 8, 1)
    |> Yog.add_edge!(4, 9, 1)
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

  # ============= Hypercube Graph =============

  @doc """
  Generates an n-dimensional hypercube graph Q_n.

  The hypercube is a classic topology where each node represents a binary
  string of length n, and edges connect nodes that differ in exactly one bit.

  **Properties:**
  - Nodes: 2^n
  - Edges: n × 2^(n-1)
  - Regular degree: n
  - Diameter: n
  - Bipartite: yes

  **Time Complexity:** O(n × 2^n)

  ## Examples

      iex> cube = Yog.Generator.Classic.hypercube(3)
      iex> # 3-cube has 8 nodes
      ...> Yog.Model.order(cube)
      8
      iex> # Each node has degree 3
      ...> length(Yog.neighbors(cube, 0))
      3
      iex> # 3-cube has 12 edges
      ...> Yog.Model.edge_count(cube)
      12

  ## Use Cases

  - Distributed systems and parallel computing topologies
  - Error-correcting codes
  - Testing algorithms on regular, bipartite structures
  - Gray code applications

  ## References

  - [Wikipedia: Hypercube Graph](https://en.wikipedia.org/wiki/Hypercube_graph)
  """
  @spec hypercube(integer()) :: Yog.graph()
  def hypercube(n) when n >= 0 do
    hypercube_with_type(n, :undirected)
  end

  def hypercube(_n), do: Yog.new(:undirected)

  @doc """
  Generates a hypercube graph with specified graph type.
  """
  @spec hypercube_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def hypercube_with_type(n, _graph_type) when n < 0, do: Yog.new(:undirected)
  def hypercube_with_type(0, graph_type), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def hypercube_with_type(n, graph_type) do
    base = Yog.new(graph_type)
    num_nodes = Integer.pow(2, n)

    # Add all nodes (0 to 2^n - 1)
    graph =
      Enum.reduce(0..(num_nodes - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Add edges: connect nodes that differ by exactly one bit
    Enum.reduce(0..(num_nodes - 1)//1, graph, fn i, g_i ->
      Enum.reduce(0..(n - 1)//1, g_i, fn bit, g_j ->
        j = Bitwise.bxor(i, Bitwise.bsl(1, bit))

        if i < j do
          Yog.add_edge!(g_j, i, j, 1)
        else
          g_j
        end
      end)
    end)
  end

  # ============= Ladder Graph =============

  @doc """
  Generates a ladder graph with n rungs.

  A ladder graph consists of two parallel paths (rails) connected by n rungs.
  It is the Cartesian product of a path P_n and an edge K_2.

  **Properties:**
  - Nodes: 2n
  - Edges: 3n - 2
  - Planar: yes
  - Equivalent to grid_2d(2, n)

  **Time Complexity:** O(n)

  ## Examples

      iex> ladder = Yog.Generator.Classic.ladder(4)
      iex> # 4-rung ladder has 8 nodes
      ...> Yog.Model.order(ladder)
      8
      iex> # End nodes have degree 2
      ...> length(Yog.neighbors(ladder, 0))
      2
      iex> # Interior nodes have degree 3
      ...> length(Yog.neighbors(ladder, 2))
      3

  ## Use Cases

  - Basic network topologies
  - DNA and molecular structure modeling
  - Pathfinding benchmarks
  """
  @spec ladder(integer()) :: Yog.graph()
  def ladder(n) when n > 0 do
    ladder_with_type(n, :undirected)
  end

  def ladder(_n), do: Yog.new(:undirected)

  @doc """
  Generates a ladder graph with specified graph type.
  """
  @spec ladder_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def ladder_with_type(n, _graph_type) when n <= 0, do: Yog.new(:undirected)

  def ladder_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Nodes 0..n-1 are the bottom rail, n..2n-1 are the top rail
    graph =
      Enum.reduce(0..(2 * n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Bottom rail edges: (i, i+1) for i in 0..n-2
    graph_bottom =
      if n >= 2 do
        Enum.reduce(0..(n - 2)//1, graph, fn i, g ->
          Yog.add_edge!(g, i, i + 1, 1)
        end)
      else
        graph
      end

    # Top rail edges: (i, i+1) for i in n..2n-2
    graph_top =
      if n >= 2 do
        Enum.reduce(n..(2 * n - 2)//1, graph_bottom, fn i, g ->
          Yog.add_edge!(g, i, i + 1, 1)
        end)
      else
        graph_bottom
      end

    # Rung edges: (i, i+n) for i in 0..n-1
    Enum.reduce(0..(n - 1)//1, graph_top, fn i, g ->
      Yog.add_edge!(g, i, i + n, 1)
    end)
  end

  # ============= Turan Graph =============

  @doc """
  Generates the Turán graph T(n, r).

  The Turán graph is a complete r-partite graph with n vertices where
  partitions are as equal as possible. It maximizes the number of edges
  among all n-vertex graphs that do not contain K_{r+1} as a subgraph.

  **Properties:**
  - Complete r-partite with balanced partitions
  - Maximum edge count without containing K_{r+1}
  - Chromatic number: r (for n >= r)
  - Turán's theorem: extremal graph for forbidden cliques

  **Time Complexity:** O(n²)

  ## Examples

      iex> turan = Yog.Generator.Classic.turan(10, 3)
      iex> # T(10, 3) has 10 nodes
      ...> Yog.Model.order(turan)
      10
      iex> # Partition sizes are balanced: 4, 3, 3
      iex> # No edges within partitions, all edges between

      iex> # T(n, 2) is the complete bipartite graph
      ...> k33 = Yog.Generator.Classic.turan(6, 2)
      ...> Yog.Model.order(k33)
      6

  ## Use Cases

  - Extremal graph theory testing
  - Chromatic number benchmarks
  - Anti-clique (independence number) studies
  - Balanced multi-partite networks

  ## References

  - [Wikipedia: Turán Graph](https://en.wikipedia.org/wiki/Tur%C3%A1n_graph)
  - [Turán's Theorem](https://en.wikipedia.org/wiki/Tur%C3%A1n%27s_theorem)
  """
  @spec turan(integer(), integer()) :: Yog.graph()
  def turan(n, r) when n > 0 and r > 0 do
    turan_with_type(n, r, :undirected)
  end

  def turan(_n, _r), do: Yog.new(:undirected)

  @doc """
  Generates a Turán graph with specified graph type.
  """
  @spec turan_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def turan_with_type(n, _r, _graph_type) when n <= 0, do: Yog.new(:undirected)
  def turan_with_type(_n, r, _graph_type) when r <= 0, do: Yog.new(:undirected)

  def turan_with_type(n, r, graph_type) do
    base = Yog.new(graph_type)

    # Add all nodes
    graph =
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Handle case where r >= n (each node in its own partition = complete graph)
    # Handle case where n <= r: each node gets its own partition, complete graph
    partition_of = fn node ->
      if r >= n do
        # Each node in its own partition
        node
      else
        # r partitions, each of size either floor(n/r) or ceil(n/r)
        base_size = div(n, r)
        remainder = rem(n, r)

        # First 'remainder' partitions have base_size + 1 nodes
        # Remaining partitions have base_size nodes
        if node < remainder * (base_size + 1) do
          div(node, base_size + 1)
        else
          # Handle case where base_size could be 0
          if base_size == 0 do
            remainder - 1
          else
            remainder + div(node - remainder * (base_size + 1), base_size)
          end
        end
      end
    end

    # Add edges between nodes in different partitions
    edges =
      for i <- 0..(n - 1),
          j <- (i + 1)..(n - 1)//1,
          partition_of.(i) != partition_of.(j),
          do: {i, j, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end
end
