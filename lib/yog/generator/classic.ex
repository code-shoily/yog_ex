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
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    edges = for i <- 0..(n - 1)//1, j <- 0..(n - 1)//1, i != j, do: {i, j, 1}

    edges
    |> maybe_filter_undirected(graph_type)
    |> Enum.reduce(graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  def complete_with_type(_n, _graph_type), do: Yog.new(:undirected)

  defp maybe_filter_undirected(edges, :undirected) do
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

  # ============= General Tree Generators =============

  @doc """
  Generates a complete k-ary tree of given depth.

  A complete k-ary tree where each node has exactly k children (except leaves).
  Total nodes = (k^(depth+1) - 1) / (k - 1) for k > 1.
  For k = 1, this is a path with depth+1 nodes.

  ## Options
    - `:arity` - Branching factor k (default: 2, binary tree)
    - `:type` - Graph type (:undirected or :directed, default: :undirected)

  ## Examples

      iex> # Ternary tree (arity 3) of depth 2
      ...> tree = Yog.Generator.Classic.kary_tree(2, arity: 3)
      iex> Yog.Model.order(tree)
      13

      iex> # Star is kary_tree with depth 1
      ...> star = Yog.Generator.Classic.kary_tree(1, arity: 5)
      iex> Yog.Model.order(star)
      6

  ## Properties

  - Regular tree structure useful for k-ary heaps
  - Node i has parent at floor((i-1)/k)
  - Node i has children at k*i+1 through k*i+k

  ## Use Cases

  - k-ary heap implementations
  - Trie structures
  - B-tree testing
  """
  @spec kary_tree(non_neg_integer(), keyword()) :: Yog.graph()
  def kary_tree(depth, opts \\ []) when is_integer(depth) and depth >= 0 do
    arity = Keyword.get(opts, :arity, 2)
    graph_type = Keyword.get(opts, :type, :undirected)
    kary_tree_with_type(depth, arity, graph_type)
  end

  @doc """
  Generates a k-ary tree with specified graph type.
  """
  @spec kary_tree_with_type(non_neg_integer(), pos_integer(), Yog.graph_type()) :: Yog.graph()
  def kary_tree_with_type(depth, _arity, _graph_type) when not is_integer(depth) or depth < 0,
    do: Yog.new(:undirected)

  def kary_tree_with_type(0, _arity, graph_type), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def kary_tree_with_type(depth, 1, graph_type) do
    # k=1 is a path
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..depth//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    edges = for i <- 0..(depth - 1)//1, do: {i, i + 1, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  def kary_tree_with_type(depth, arity, graph_type) when is_integer(arity) and arity > 1 do
    base = Yog.new(graph_type)

    # Total nodes: (arity^(depth+1) - 1) / (arity - 1)
    total_nodes = div(Integer.pow(arity, depth + 1) - 1, arity - 1)

    graph =
      Enum.reduce(0..(total_nodes - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Number of non-leaf nodes: (arity^depth - 1) / (arity - 1)
    non_leaf_count = div(Integer.pow(arity, depth) - 1, arity - 1)

    # For each non-leaf node, add edges to its k children
    # Node i has children at k*i+1, k*i+2, ..., k*i+k
    edges =
      for i <- 0..(non_leaf_count - 1)//1,
          child <- (arity * i + 1)..(arity * i + arity)//1,
          do: {i, child, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Generates a complete m-ary tree with exactly n nodes.

  Creates a tree that is as complete as possible - all levels are fully
  filled except possibly the last, which is filled from left to right.

  ## Options
    - `:arity` - Branching factor (default: 2)
    - `:type` - Graph type (:undirected or :directed, default: :undirected)

  ## Examples

      iex> tree = Yog.Generator.Classic.complete_kary(20, arity: 3)
      iex> Yog.Model.order(tree)
      20

      iex> tree = Yog.Generator.Classic.complete_kary(7, arity: 2)
      iex> Yog.Model.edge_count(tree)
      6

  ## Use Cases

  - Complete binary trees for heap implementations
  - Testing tree algorithms with specific node counts
  - B-tree node structure validation
  """
  @spec complete_kary(integer(), keyword()) :: Yog.graph()
  def complete_kary(n, opts \\ []) when is_integer(n) and n >= 0 do
    arity = Keyword.get(opts, :arity, 2)
    graph_type = Keyword.get(opts, :type, :undirected)
    complete_kary_with_type(n, arity, graph_type)
  end

  @doc """
  Generates a complete m-ary tree with specified graph type.
  """
  @spec complete_kary_with_type(integer(), pos_integer(), Yog.graph_type()) :: Yog.graph()
  def complete_kary_with_type(n, _arity, _graph_type) when n <= 0, do: Yog.new(:undirected)

  def complete_kary_with_type(1, _arity, graph_type),
    do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def complete_kary_with_type(n, arity, graph_type) when is_integer(arity) and arity >= 1 do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # For node i, children are at k*i+1 to k*i+k, if they exist
    edges =
      for i <- 0..(n - 2)//1,
          child_start = arity * i + 1,
          child_end = min(arity * i + arity, n - 1),
          child <- child_start..child_end//1,
          do: {i, child, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Generates a caterpillar tree.

  A caterpillar is a tree where removing all leaves leaves a path (the "spine").

  ## Options
    - `:spine_length` - Length of central path (default: max(1, div(n, 3)))
    - `:type` - Graph type (:undirected or :directed, default: :undirected)

  ## Examples

      iex> cat = Yog.Generator.Classic.caterpillar(20, spine_length: 5)
      iex> Yog.Model.order(cat)
      20

  ## Properties

  - All vertices are within distance 1 of the central path
  - Useful for testing algorithms sensitive to tree structure
  - Interpolates between paths (spine_length = n) and stars (spine_length = 1)

  ## Use Cases

  - Testing tree isomorphism algorithms
  - Algorithms with different behavior on paths vs stars
  - Graph drawing and layout algorithms
  """
  @spec caterpillar(integer(), keyword()) :: Yog.graph()
  def caterpillar(n, opts \\ []) when is_integer(n) and n >= 0 do
    spine_length = Keyword.get(opts, :spine_length, max(1, div(n, 3)))
    graph_type = Keyword.get(opts, :type, :undirected)
    caterpillar_with_type(n, spine_length, graph_type)
  end

  @doc """
  Generates a caterpillar tree with specified graph type.
  """
  @spec caterpillar_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def caterpillar_with_type(n, _spine_length, _graph_type) when n <= 0,
    do: Yog.new(:undirected)

  def caterpillar_with_type(1, _spine_length, graph_type),
    do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def caterpillar_with_type(n, spine_length, graph_type) do
    spine_length = min(spine_length, n)
    leaf_count = n - spine_length

    base = Yog.new(graph_type)

    # Add all nodes
    graph =
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Create spine path (nodes 0 to spine_length-1)
    spine_edges =
      for i <- 0..(spine_length - 2)//1, do: {i, i + 1, 1}

    # Distribute leaves evenly across spine nodes
    # Leaves are numbered from spine_length to n-1
    leaves_per_spine = div(leaf_count, spine_length)
    extra_leaves = rem(leaf_count, spine_length)

    {leaf_edges, _next_leaf} =
      Enum.reduce(0..(spine_length - 1)//1, {[], spine_length}, fn spine_idx,
                                                                   {edges, next_leaf} ->
        num_leaves = leaves_per_spine + if spine_idx < extra_leaves, do: 1, else: 0

        new_edges =
          if num_leaves > 0 do
            for i <- 0..(num_leaves - 1)//1, do: {spine_idx, next_leaf + i, 1}
          else
            []
          end

        {edges ++ new_edges, next_leaf + num_leaves}
      end)

    all_edges = spine_edges ++ leaf_edges

    Enum.reduce(all_edges, graph, fn {from, to, weight}, g ->
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

  @doc """
  Generates the Sedgewick maze graph.

  A small maze with a cycle used in Sedgewick's *Algorithms*, 3rd Edition,
  Part 5, Graph Algorithms, Chapter 18 (Figure 18.2). It has 8 nodes and
  10 edges.

  ## Examples

      iex> maze = Yog.Generator.Classic.sedgewick_maze()
      iex> Yog.Model.order(maze)
      8
      iex> Yog.Model.edge_count(maze)
      10

  ## References

  - Figure 18.2, Chapter 18, Graph Algorithms (3rd Ed), Sedgewick
  """
  @spec sedgewick_maze() :: Yog.graph()
  def sedgewick_maze, do: sedgewick_maze_with_type(:undirected)

  @doc """
  Generates the Sedgewick maze graph with specified graph type.
  """
  @spec sedgewick_maze_with_type(Yog.graph_type()) :: Yog.graph()
  def sedgewick_maze_with_type(graph_type) do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..7, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    edges = [
      {0, 2, 1},
      {0, 7, 1},
      {0, 5, 1},
      {1, 7, 1},
      {2, 6, 1},
      {3, 4, 1},
      {3, 5, 1},
      {4, 5, 1},
      {4, 7, 1},
      {4, 6, 1}
    ]

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Generates the Tutte graph.

  The Tutte graph is a 3-regular (cubic) polyhedral graph with 46 vertices
  and 69 edges. It is non-Hamiltonian and serves as a counterexample to
  Tait's conjecture that every 3-regular polyhedron has a Hamiltonian cycle.

  ## Examples

      iex> tutte = Yog.Generator.Classic.tutte()
      iex> Yog.Model.order(tutte)
      46
      iex> Yog.Model.edge_count(tutte)
      69

  ## Properties

  - Vertices: 46
  - Edges: 69
  - Degree: 3 (cubic)
  - Non-Hamiltonian
  - Planar

  ## References

  - [Wikipedia: Tutte Graph](https://en.wikipedia.org/wiki/Tutte_graph)
  """
  @spec tutte() :: Yog.graph()
  def tutte, do: tutte_with_type(:undirected)

  @doc """
  Generates the Tutte graph with specified graph type.
  """
  @spec tutte_with_type(Yog.graph_type()) :: Yog.graph()
  def tutte_with_type(graph_type) do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..45, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    adjacency = [
      [1, 2, 3],
      [4, 26],
      [10, 11],
      [18, 19],
      [5, 33],
      [6, 29],
      [7, 27],
      [8, 14],
      [9, 38],
      [10, 37],
      [39],
      [12, 39],
      [13, 35],
      [14, 15],
      [34],
      [16, 22],
      [17, 44],
      [18, 43],
      [45],
      [20, 45],
      [21, 41],
      [22, 23],
      [40],
      [24, 27],
      [25, 32],
      [26, 31],
      [33],
      [28],
      [29, 32],
      [30],
      [31, 33],
      [32],
      [],
      [],
      [35, 38],
      [36],
      [37, 39],
      [38],
      [],
      [],
      [41, 44],
      [42],
      [43, 45],
      [44],
      [],
      []
    ]

    adjacency
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {neighbors, u}, acc_graph ->
      Enum.reduce(neighbors, acc_graph, fn v, g ->
        Yog.add_edge!(g, u, v, 1)
      end)
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
    edges =
      for i <- 0..(num_nodes - 1),
          bit <- 0..(n - 1),
          j = Bitwise.bxor(i, Bitwise.bsl(1, bit)),
          # Avoid duplicates for undirected
          i < j,
          do: {i, j, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
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
    bottom_edges = if n >= 2, do: for(i <- 0..(n - 2), do: {i, i + 1, 1}), else: []

    # Top rail edges: (i, i+1) for i in n..2n-2
    top_edges = if n >= 2, do: for(i <- n..(2 * n - 2), do: {i, i + 1, 1}), else: []

    # Rung edges: (i, i+n) for i in 0..n-1
    rung_edges = for(i <- 0..(n - 1), do: {i, i + n, 1})

    Enum.reduce(bottom_edges ++ top_edges ++ rung_edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Circular and Möbius Ladder Graphs =============

  @doc """
  Generates a circular ladder graph (prism graph) with n rungs.

  The circular ladder CL_n consists of two concentric n-cycles with
  corresponding vertices connected by rungs. It's equivalent to the
  Cartesian product C_n × K_2 (cycle × edge).

  ## Examples

      iex> cl = Yog.Generator.Classic.circular_ladder(5)
      iex> Yog.Model.order(cl)
      10

      iex> # CL_4 is the cube graph (isomorphic to hypercube(3))
      ...> cl4 = Yog.Generator.Classic.circular_ladder(4)
      ...> Yog.Model.order(cl4)
      8

  ## Properties

  - Vertices: 2n
  - Edges: 3n (2n cycle edges + n rungs)
  - 3-regular (cubic) for n > 2
  - Planar (can be drawn on a cylinder)
  - Hamiltonian
  - Bipartite when n is even

  ## Use Cases

  - Prism graphs in chemistry (molecular structures)
  - Network topologies with wraparound
  - Topological graph theory (cylindrical embeddings)
  """
  @spec circular_ladder(integer()) :: Yog.graph()
  def circular_ladder(n) when is_integer(n) and n >= 3 do
    circular_ladder_with_type(n, :undirected)
  end

  def circular_ladder(_n), do: Yog.new(:undirected)

  @doc """
  Generates a circular ladder graph with specified graph type.
  """
  @spec circular_ladder_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def circular_ladder_with_type(n, _graph_type) when not is_integer(n) or n < 3,
    do: Yog.new(:undirected)

  def circular_ladder_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Nodes 0..n-1 are inner cycle, n..2n-1 are outer cycle
    graph =
      Enum.reduce(0..(2 * n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Inner cycle edges: (i, (i+1) mod n) for i in 0..n-1
    inner_edges = for i <- 0..(n - 1)//1, do: {i, rem(i + 1, n), 1}

    # Outer cycle edges: (i+n, ((i+1) mod n)+n) for i in 0..n-1
    outer_edges = for i <- 0..(n - 1)//1, do: {i + n, rem(i + 1, n) + n, 1}

    # Rung edges: (i, i+n) for i in 0..n-1
    rung_edges = for i <- 0..(n - 1)//1, do: {i, i + n, 1}

    Enum.reduce(inner_edges ++ outer_edges ++ rung_edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Alias for `circular_ladder/1`.

  The n-sided prism graph is exactly the circular ladder CL_n.
  """
  @spec prism(integer()) :: Yog.graph()
  def prism(n), do: circular_ladder(n)

  @doc """
  Generates a prism graph with specified graph type.

  The n-sided prism graph is exactly the circular ladder CL_n.
  """
  @spec prism_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def prism_with_type(n, graph_type), do: circular_ladder_with_type(n, graph_type)

  @doc """
  Generates a Möbius ladder graph with n rungs.

  The Möbius ladder ML_n is formed from a circular ladder by giving it
  a half-twist before connecting the ends, creating a Möbius strip topology.

  ## Examples

      iex> ml = Yog.Generator.Classic.mobius_ladder(6)
      iex> Yog.Model.order(ml)
      12

      iex> # ML_4 is K_{3,3} (complete bipartite graph)
      ...> ml4 = Yog.Generator.Classic.mobius_ladder(4)
      ...> Yog.Model.order(ml4)
      8

  ## Properties

  - Vertices: 2n
  - Edges: 3n
  - 3-regular (cubic)
  - Non-planar for n ≥ 3
  - ML_4 = K_{3,3} (canonical non-planar graph)
  - ML_3 = 6-vertex utility graph (K_{3,3} minus an edge)
  - Bipartite when n is odd

  ## Use Cases

  - Non-orientable embeddings in topological graph theory
  - Planarity testing (contains K_{3,3} minor)
  - Chemical graph theory (Möbius molecules)
  - Network design with twisted topology
  """
  @spec mobius_ladder(integer()) :: Yog.graph()
  def mobius_ladder(n) when is_integer(n) and n >= 2 do
    mobius_ladder_with_type(n, :undirected)
  end

  def mobius_ladder(_n), do: Yog.new(:undirected)

  @doc """
  Generates a Möbius ladder graph with specified graph type.
  """
  @spec mobius_ladder_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def mobius_ladder_with_type(n, _graph_type) when not is_integer(n) or n < 2,
    do: Yog.new(:undirected)

  def mobius_ladder_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Nodes 0..2n-1 arranged in a cycle
    graph =
      Enum.reduce(0..(2 * n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Cycle edges: (i, (i+1) mod 2n) for i in 0..2n-1
    cycle_edges = for i <- 0..(2 * n - 1)//1, do: {i, rem(i + 1, 2 * n), 1}

    # Twist edges (rungs with twist): (i, (i+n) mod 2n) for i in 0..n-1
    # These connect opposite vertices in the cycle, creating the twist
    twist_edges = for i <- 0..(n - 1)//1, do: {i, rem(i + n, 2 * n), 1}

    Enum.reduce(cycle_edges ++ twist_edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Friendship and Windmill Graphs =============

  @doc """
  Generates the friendship graph F_n with n triangles.

  The friendship graph consists of n triangles all sharing a common vertex.
  Also known as the Dutch windmill graph W_n^{(3)} or the friendship theorem graph.

  Famous for the **Friendship Theorem**: if every pair of vertices in a finite
  graph has exactly one common neighbor, then the graph must be a friendship graph.

  ## Examples

      iex> f3 = Yog.Generator.Classic.friendship(3)
      iex> Yog.Model.order(f3)
      7
      iex> Yog.Model.edge_count(f3)
      9

  ## Properties

  - Vertices: 2n + 1 (1 center + 2n outer vertices)
  - Edges: 3n (n triangles, each with 3 edges)
  - Center has degree 2n, outer vertices have degree 2
  - Chromatic number: 3
  - Diameter: 2, Radius: 1
  - Planar

  ## Use Cases

  - Graph theory education (Friendship Theorem)
  - Testing graphs with specific local properties
  - Social network models (hub with triadic closure)
  """
  @spec friendship(integer()) :: Yog.graph()
  def friendship(n) when is_integer(n) and n >= 1 do
    friendship_with_type(n, :undirected)
  end

  def friendship(_n), do: Yog.new(:undirected)

  @doc """
  Generates the friendship graph with specified graph type.
  """
  @spec friendship_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def friendship_with_type(n, _graph_type) when not is_integer(n) or n < 1,
    do: Yog.new(:undirected)

  def friendship_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Node 0 is the center
    # Nodes 1..2n are outer vertices (n pairs forming triangles with center)
    total_vertices = 2 * n + 1

    graph =
      Enum.reduce(0..(total_vertices - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Create n triangles: (0, 2i-1, 2i) for i in 1..n
    # Using 1-based indexing for pairs: pair i consists of nodes 2i-1 and 2i
    edges =
      for i <- 1..n//1,
          outer1 = 2 * i - 1,
          outer2 = 2 * i,
          # Triangle edges: center to both outer, and outer to outer
          edge <- [{0, outer1, 1}, {0, outer2, 1}, {outer1, outer2, 1}],
          do: edge

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Generates the windmill graph W_n^{(k)}.

  Generalization of the friendship graph where n copies of K_k (complete graph
  on k vertices) share a common vertex. The friendship graph is W_n^{(3)}.

  ## Options
    - `:clique_size` - Size k of the cliques (default: 3)

  ## Examples

      iex> # Windmill of 4 triangles (same as friendship(4))
      ...> w4 = Yog.Generator.Classic.windmill(4, clique_size: 3)
      iex> Yog.Model.order(w4)
      9

      iex> # Windmill of 3 squares (4-cliques sharing a vertex)
      ...> w3_4 = Yog.Generator.Classic.windmill(3, clique_size: 4)
      iex> Yog.Model.order(w3_4)
      10

  ## Properties

  - Vertices: 1 + n(k-1)
  - Edges: n × C(k,2) = n × k(k-1)/2
  - Center has degree n(k-1)

  ## Use Cases

  - Generalized friendship graphs
  - Intersection graph theory
  - Clique decomposition studies
  """
  @spec windmill(integer(), keyword()) :: Yog.graph()
  def windmill(n, opts \\ [])

  def windmill(n, opts) when is_integer(n) and n >= 1 do
    k = Keyword.get(opts, :clique_size, 3)
    graph_type = Keyword.get(opts, :type, :undirected)
    windmill_with_type(n, k, graph_type)
  end

  def windmill(_n, _opts), do: Yog.new(:undirected)

  @doc """
  Generates the windmill graph with specified graph type.
  """
  @spec windmill_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def windmill_with_type(n, _k, _graph_type) when not is_integer(n) or n < 1,
    do: Yog.new(:undirected)

  def windmill_with_type(_n, k, _graph_type) when not is_integer(k) or k < 2,
    do: Yog.new(:undirected)

  def windmill_with_type(n, k, graph_type) do
    base = Yog.new(graph_type)

    # Node 0 is the center shared by all cliques
    # Each clique adds k-1 new vertices
    total_vertices = 1 + n * (k - 1)

    graph =
      Enum.reduce(0..(total_vertices - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # For each of the n cliques:
    # - Clique i uses vertices: 0 (center), and vertices from (1 + i*(k-1)) to (1 + (i+1)*(k-1) - 1)
    # - Add all edges within each clique (complete graph)
    edges =
      for i <- 0..(n - 1)//1,
          # Vertices in this clique (excluding center)
          clique_start = 1 + i * (k - 1),
          clique_end = clique_start + k - 2,
          clique_vertices = [0 | Enum.to_list(clique_start..clique_end//1)],
          # All pairs in the clique form edges
          {u, v} <- pairs(clique_vertices),
          do: {u, v, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # Helper function to generate all unordered pairs from a list
  defp pairs([]), do: []
  defp pairs([_]), do: []

  defp pairs([h | t]) do
    head_pairs = for elem <- t, do: {h, elem}
    head_pairs ++ pairs(t)
  end

  @doc """
  Generates the book graph B_n.

  The book graph consists of n triangles (4-cycles in the general definition,
  but commonly triangles) all sharing a common edge (the "spine").

  ## Examples

      iex> book = Yog.Generator.Classic.book(3)
      iex> Yog.Model.order(book)
      5
      iex> Yog.Model.edge_count(book)
      7

  ## Properties

  - Vertices: n + 2 (2 spine vertices + n page vertices)
  - Edges: 2n + 1 (n triangles sharing the spine edge)
  - Planar
  - Outerplanar

  ## Use Cases

  - Graph drawing and book embeddings
  - Outerplanar graph studies
  - Pagenumber of graphs
  """
  @spec book(integer()) :: Yog.graph()
  def book(n) when is_integer(n) and n >= 1 do
    book_with_type(n, :undirected)
  end

  def book(_n), do: Yog.new(:undirected)

  @doc """
  Generates the book graph with specified graph type.
  """
  @spec book_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def book_with_type(n, _graph_type) when not is_integer(n) or n < 1,
    do: Yog.new(:undirected)

  def book_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Nodes 0 and 1 form the spine (shared edge)
    # Nodes 2..(n+1) are the page vertices (each forms a triangle with spine)
    total_vertices = n + 2

    graph =
      Enum.reduce(0..(total_vertices - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Spine edge
    edges = [{0, 1, 1}]

    # Each page vertex forms a triangle with the spine
    page_edges =
      for i <- 2..(n + 1)//1,
          edge <- [{0, i, 1}, {1, i, 1}],
          do: edge

    Enum.reduce(edges ++ page_edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Crown Graph =============

  @doc """
  Generates the crown graph S_n^0 with 2n vertices.

  The crown graph is the complete bipartite graph K_{n,n} minus a perfect
  matching. It has important applications in edge coloring and extremal
  graph theory.

  ## Examples

      iex> crown = Yog.Generator.Classic.crown(4)
      iex> Yog.Model.order(crown)
      8
      iex> Yog.Model.edge_count(crown)
      12

      iex> # crown(2) is C_4 (cycle on 4 vertices)
      ...> c2 = Yog.Generator.Classic.crown(2)
      ...> Yog.Model.order(c2)
      4

  ## Properties

  - Vertices: 2n
  - Edges: n(n-1) = n² - n
  - (n-1)-regular (each vertex has degree n-1)
  - Bipartite
  - Diameter: 3 for n ≥ 3
  - Girth: 4 for n ≥ 3

  ## Special Cases

  - crown(2) = C₄ (4-cycle)
  - crown(3) is the utility graph (K_{3,3} minus a perfect matching)

  ## Use Cases

  - Edge coloring tests (chromatic index demonstrations)
  - Extremal graph theory examples
  - Bipartite graph testing with symmetric structure
  """
  @spec crown(integer()) :: Yog.graph()
  def crown(n) when is_integer(n) and n >= 2 do
    crown_with_type(n, :undirected)
  end

  def crown(_n), do: Yog.new(:undirected)

  @doc """
  Generates the crown graph with specified graph type.
  """
  @spec crown_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def crown_with_type(n, _graph_type) when not is_integer(n) or n < 2,
    do: Yog.new(:undirected)

  def crown_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Two partitions: U = {0, ..., n-1}, V = {n, ..., 2n-1}
    graph =
      Enum.reduce(0..(2 * n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # All edges between U and V EXCEPT (i, n+i) for i in 0..n-1
    # This removes the perfect matching
    edges =
      for i <- 0..(n - 1)//1,
          j <- 0..(n - 1)//1,
          # Skip the perfect matching edges where i == j
          i != j,
          do: {i, n + j, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Lollipop Graph =============

  @doc """
  Generates the lollipop graph L(m, n).

  The lollipop graph consists of a complete graph K_m connected to a path P_n
  by a single bridge edge. This is an extremal example in the study of random
  walks on graphs.

  ## Examples

      iex> lol = Yog.Generator.Classic.lollipop(4, 3)
      iex> Yog.Model.order(lol)
      7
      iex> Yog.Model.edge_count(lol)
      9

  ## Properties

  - Vertices: m + n
  - Edges: m(m-1)/2 + n
  - Diameter: n + 1 (for m > 1 and n > 0)

  ## References

  - [Wikipedia: Lollipop Graph](https://en.wikipedia.org/wiki/Lollipop_graph)
  """
  @spec lollipop(integer(), integer()) :: Yog.graph()
  def lollipop(m, n), do: lollipop_with_type(m, n, :undirected)

  @doc """
  Generates the lollipop graph with specified graph type.
  """
  @spec lollipop_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def lollipop_with_type(m, _n, graph_type) when not is_integer(m) or m < 1,
    do: Yog.new(graph_type)

  def lollipop_with_type(m, n, graph_type) when is_integer(n) and n >= 0 do
    base = Yog.new(graph_type)

    total = m + n

    graph =
      if total > 0 do
        Enum.reduce(0..(total - 1), base, fn i, g ->
          Yog.add_node(g, i, nil)
        end)
      else
        base
      end

    # Clique edges for K_m
    clique_edges =
      if m >= 2 do
        for i <- 0..(m - 2)//1, j <- (i + 1)..(m - 1)//1, do: {i, j, 1}
      else
        []
      end

    # Path edges for P_n
    path_edges =
      if n >= 2 do
        for i <- 0..(n - 2)//1, do: {m + i, m + i + 1, 1}
      else
        []
      end

    # Bridge edge connecting K_m to P_n
    bridge_edges =
      if n > 0, do: [{m - 1, m, 1}], else: []

    Enum.reduce(clique_edges ++ path_edges ++ bridge_edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  def lollipop_with_type(_m, _n, graph_type), do: Yog.new(graph_type)

  # ============= Barbell Graph =============

  @doc """
  Generates the barbell graph B(m1, m2).

  The barbell graph consists of two complete graphs K_{m1} connected by a path
  of m2 nodes. If m2 = 0, the two cliques are joined by a single edge.

  ## Examples

      iex> bar = Yog.Generator.Classic.barbell(4, 2)
      iex> Yog.Model.order(bar)
      10
      iex> Yog.Model.edge_count(bar)
      15

  ## Properties

  - Vertices: 2*m1 + m2
  - Edges: m1*(m1-1) + m2 + 1
  - Diameter: m2 + 2 (for m2 > 0)

  ## References

  - [Wikipedia: Barbell Graph](https://en.wikipedia.org/wiki/Barbell_graph)
  """
  @spec barbell(integer(), integer()) :: Yog.graph()
  def barbell(m1, m2), do: barbell_with_type(m1, m2, :undirected)

  @doc """
  Generates the barbell graph with specified graph type.
  """
  @spec barbell_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def barbell_with_type(m1, _m2, graph_type) when not is_integer(m1) or m1 < 1,
    do: Yog.new(graph_type)

  def barbell_with_type(m1, m2, graph_type) when is_integer(m2) and m2 >= 0 do
    base = Yog.new(graph_type)

    total = 2 * m1 + m2

    graph =
      if total > 0 do
        Enum.reduce(0..(total - 1), base, fn i, g ->
          Yog.add_node(g, i, nil)
        end)
      else
        base
      end

    # First clique edges (nodes 0..m1-1)
    clique1_edges =
      if m1 >= 2 do
        for i <- 0..(m1 - 2)//1, j <- (i + 1)..(m1 - 1)//1, do: {i, j, 1}
      else
        []
      end

    # Second clique edges (nodes m1+m2..2*m1+m2-1)
    clique2_start = m1 + m2

    clique2_edges =
      if m1 >= 2 do
        for i <- 0..(m1 - 2)//1,
            j <- (i + 1)..(m1 - 1)//1,
            do: {clique2_start + i, clique2_start + j, 1}
      else
        []
      end

    # Path edges (nodes m1..m1+m2-1)
    path_edges =
      if m2 >= 2 do
        for i <- 0..(m2 - 2)//1, do: {m1 + i, m1 + i + 1, 1}
      else
        []
      end

    # Bridge edges connecting cliques to path
    bridge_edges =
      if m2 > 0 do
        [{m1 - 1, m1, 1}, {m1 + m2 - 1, m1 + m2, 1}]
      else
        [{m1 - 1, m1, 1}]
      end

    Enum.reduce(clique1_edges ++ clique2_edges ++ path_edges ++ bridge_edges, graph, fn {from, to,
                                                                                         weight},
                                                                                        g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  def barbell_with_type(_m1, _m2, graph_type), do: Yog.new(graph_type)

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
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Handle case where r >= n (each node in its own partition = complete graph)
    # Handle case where n <= r: each node gets its own partition, complete graph
    partition_of = fn node ->
      if r >= n do
        node
      else
        base_size = div(n, r)
        remainder = rem(n, r)

        if node < remainder * (base_size + 1) do
          div(node, base_size + 1)
        else
          if base_size == 0 do
            remainder - 1
          else
            remainder + div(node - remainder * (base_size + 1), base_size)
          end
        end
      end
    end

    edges =
      for i <- 0..(n - 1),
          j <- (i + 1)..(n - 1)//1,
          partition_of.(i) != partition_of.(j),
          do: {i, j, 1}

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  # ============= Platonic Solids =============

  @doc """
  Generates the tetrahedron graph K₄ (complete graph on 4 vertices).

  The tetrahedron is the simplest Platonic solid with 4 vertices and 6 edges.
  Each vertex has degree 3. It is a complete graph K₄.

  ## Examples

      iex> tetra = Yog.Generator.Classic.tetrahedron()
      iex> Yog.Model.order(tetra)
      4
      iex> Yog.Model.edge_count(tetra)
      6

  ## Properties

  - Vertices: 4
  - Edges: 6
  - Degree: 3 (regular)
  - Diameter: 1
  - Girth: 3
  - Chromatic number: 4
  """
  @spec tetrahedron() :: Yog.graph()
  def tetrahedron do
    # Tetrahedron is K₄ - complete graph on 4 vertices
    complete(4)
  end

  @doc """
  Generates the cube graph Q₃ (3-dimensional hypercube).

  The cube has 8 vertices and 12 edges. Each vertex has degree 3.
  It is bipartite, planar, and is the 3D hypercube.

  ## Examples

      iex> cube = Yog.Generator.Classic.cube()
      iex> Yog.Model.order(cube)
      8
      iex> Yog.Model.edge_count(cube)
      12

  ## Properties

  - Vertices: 8
  - Edges: 12
  - Degree: 3 (regular)
  - Diameter: 3
  - Girth: 4
  - Chromatic number: 2 (bipartite)
  """
  @spec cube() :: Yog.graph()
  def cube do
    # Cube is the 3D hypercube
    hypercube(3)
  end

  @doc """
  Generates the octahedron graph.

  The octahedron has 6 vertices and 12 edges. Each vertex has degree 4.
  It is the dual of the cube. Vertices can be viewed as the coordinate axes
  (±1, 0, 0), (0, ±1, 0), (0, 0, ±1) - each vertex connects to all except its opposite.

  ## Examples

      iex> octa = Yog.Generator.Classic.octahedron()
      iex> Yog.Model.order(octa)
      6
      iex> Yog.Model.edge_count(octa)
      12

  ## Properties

  - Vertices: 6
  - Edges: 12
  - Degree: 4 (regular)
  - Diameter: 2
  - Girth: 3
  - Chromatic number: 3
  """
  @spec octahedron() :: Yog.graph()
  def octahedron do
    base = Yog.undirected()

    # Add 6 vertices
    graph =
      Enum.reduce(0..5, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Octahedron: opposite pairs are (0,3), (1,4), (2,5)
    # Each vertex connects to all vertices EXCEPT its opposite
    edges = [
      # Vertex 0 connects to 1,2,4,5 (not 3)
      {0, 1, 1},
      {0, 2, 1},
      {0, 4, 1},
      {0, 5, 1},
      # Vertex 1 connects to 0,2,3,5 (not 4)
      {1, 2, 1},
      {1, 3, 1},
      {1, 5, 1},
      # Vertex 2 connects to 0,1,3,4 (not 5)
      {2, 3, 1},
      {2, 4, 1},
      # Vertex 3 connects to 1,2,4,5 (not 0)
      {3, 4, 1},
      {3, 5, 1},
      # Vertex 4 connects to 0,2,3,5 (not 1)
      {4, 5, 1}
      # Vertex 5 already covered
    ]

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Generates the dodecahedron graph.

  The dodecahedron has 20 vertices and 30 edges. Each vertex has degree 3.
  Famous as the basis of Hamilton's "Icosian game" and Hamiltonian cycle puzzles.
  It has girth 5 (smallest cycle has 5 edges).

  ## Examples

      iex> dodec = Yog.Generator.Classic.dodecahedron()
      iex> Yog.Model.order(dodec)
      20
      iex> Yog.Model.edge_count(dodec)
      30

  ## Properties

  - Vertices: 20
  - Edges: 30
  - Degree: 3 (regular)
  - Diameter: 5
  - Girth: 5
  - Chromatic number: 3
  """
  @spec dodecahedron() :: Yog.graph()
  def dodecahedron do
    base = Yog.undirected()

    # Add 20 vertices
    graph =
      Enum.reduce(0..19, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Dodecahedron edge structure:
    # Three concentric rings: outer pentagon (0-4), middle decagon (5-14), inner pentagon (15-19)
    edges =
      [
        # Outer pentagon
        {0, 1},
        {1, 2},
        {2, 3},
        {3, 4},
        {4, 0},
        # Inner pentagon
        {15, 16},
        {16, 17},
        {17, 18},
        {18, 19},
        {19, 15},
        # Middle ring (two intertwined pentagons)
        {5, 6},
        {6, 7},
        {7, 8},
        {8, 9},
        {9, 10},
        {10, 11},
        {11, 12},
        {12, 13},
        {13, 14},
        {14, 5},
        # Connections: outer to middle
        {0, 5},
        {1, 6},
        {2, 7},
        {3, 8},
        {4, 9},
        # Connections: middle to inner
        {10, 15},
        {11, 16},
        {12, 17},
        {13, 18},
        {14, 19}
      ]
      |> Enum.map(fn {u, v} -> {u, v, 1} end)

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  @doc """
  Generates the icosahedron graph.

  The icosahedron has 12 vertices and 30 edges. Each vertex has degree 5.
  It is the dual of the dodecahedron. It has the largest number of faces (20)
  of any Platonic solid.

  ## Examples

      iex> icosa = Yog.Generator.Classic.icosahedron()
      iex> Yog.Model.order(icosa)
      12
      iex> Yog.Model.edge_count(icosa)
      30

  ## Properties

  - Vertices: 12
  - Edges: 30
  - Degree: 5 (regular)
  - Diameter: 3
  - Girth: 3
  - Chromatic number: 4
  """
  @spec icosahedron() :: Yog.graph()
  def icosahedron do
    base = Yog.undirected()

    # Add 12 vertices
    graph =
      Enum.reduce(0..11, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Icosahedron: can be thought of as two pentagonal pyramids (top/bottom)
    # with a ring of 10 vertices between them
    # Layout: 0 = north pole, 11 = south pole, 1-5 and 6-10 in alternating rings
    edges =
      [
        # North pole (0) connects to vertices 1-5
        {0, 1},
        {0, 2},
        {0, 3},
        {0, 4},
        {0, 5},
        # South pole (11) connects to vertices 6-10
        {11, 6},
        {11, 7},
        {11, 8},
        {11, 9},
        {11, 10},
        # Upper ring connections (1-5)
        {1, 2},
        {2, 3},
        {3, 4},
        {4, 5},
        {5, 1},
        # Lower ring connections (6-10)
        {6, 7},
        {7, 8},
        {8, 9},
        {9, 10},
        {10, 6},
        # Cross connections between rings (each upper connects to 2 lower)
        {1, 6},
        {1, 10},
        {2, 6},
        {2, 7},
        {3, 7},
        {3, 8},
        {4, 8},
        {4, 9},
        {5, 9},
        {5, 10}
      ]
      |> Enum.map(fn {u, v} -> {u, v, 1} end)

    Enum.reduce(edges, graph, fn {from, to, weight}, g ->
      Yog.add_edge!(g, from, to, weight)
    end)
  end
end
