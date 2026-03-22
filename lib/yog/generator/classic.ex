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

  ## Example

      # Classic structures
      cycle = Yog.Generator.Classic.cycle(5)                    # C5 cycle graph
      complete = Yog.Generator.Classic.complete(4)              # K4 complete graph
      grid = Yog.Generator.Classic.grid_2d(3, 4)                # 3x4 lattice mesh
      tree = Yog.Generator.Classic.binary_tree(3)               # Depth-3 binary tree
      bipartite = Yog.Generator.Classic.complete_bipartite(3, 4) # K_{3,4}
      petersen = Yog.Generator.Classic.petersen()               # Famous Petersen graph

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

  ## Example

      k5 = Yog.Generator.Classic.complete(5)
      # K5 has 5 nodes and 10 edges

  ## Use Cases

  - Testing algorithms on dense graphs
  - Maximum connectivity scenarios
  - Clique detection benchmarks
  """
  @spec complete(integer()) :: Yog.graph()
  defdelegate complete(n), to: :yog@generator@classic

  @doc """
  Generates a complete graph with specified graph type.

  ## Example

      directed_k4 = Yog.Generator.Classic.complete_with_type(4, :directed)
  """
  @spec complete_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate complete_with_type(n, graph_type), to: :yog@generator@classic

  # ============= Cycle Graph =============

  @doc """
  Generates a cycle graph C_n where nodes form a ring.

  A cycle graph connects n nodes in a circular pattern:
  0 -> 1 -> 2 -> ... -> (n-1) -> 0. Each node has degree 2.

  Returns an empty graph if n < 3 (cycles require at least 3 nodes).

  **Time Complexity:** O(n)

  ## Example

      c6 = Yog.Generator.Classic.cycle(6)
      # C6: 0-1-2-3-4-5-0 (a hexagon)

  ## Use Cases

  - Ring network topologies
  - Circular dependency testing
  - Hamiltonian cycle benchmarks
  """
  @spec cycle(integer()) :: Yog.graph()
  defdelegate cycle(n), to: :yog@generator@classic

  @doc """
  Generates a cycle graph with specified graph type.
  """
  @spec cycle_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate cycle_with_type(n, graph_type), to: :yog@generator@classic

  # ============= Path Graph =============

  @doc """
  Generates a path graph P_n where nodes form a linear chain.

  A path graph connects n nodes in a line: 0 -> 1 -> 2 -> ... -> (n-1).
  End nodes have degree 1, interior nodes have degree 2.

  **Time Complexity:** O(n)

  ## Example

      p5 = Yog.Generator.Classic.path(5)
      # P5: 0-1-2-3-4

  ## Use Cases

  - Linear network topologies
  - Linked list representations
  - Pathfinding benchmarks
  """
  @spec path(integer()) :: Yog.graph()
  defdelegate path(n), to: :yog@generator@classic

  @doc """
  Generates a path graph with specified graph type.
  """
  @spec path_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate path_with_type(n, graph_type), to: :yog@generator@classic

  # ============= Star Graph =============

  @doc """
  Generates a star graph S_n with one central hub.

  A star graph has one central node (0) connected to all n-1 outer nodes.
  The center has degree n-1, outer nodes have degree 1.

  **Time Complexity:** O(n)

  ## Example

      s5 = Yog.Generator.Classic.star(5)
      # S5: center 0 connected to nodes 1, 2, 3, 4

  ## Use Cases

  - Hub-and-spoke networks
  - Client-server architectures
  - Broadcast scenarios
  """
  @spec star(integer()) :: Yog.graph()
  defdelegate star(n), to: :yog@generator@classic

  @doc """
  Generates a star graph with specified graph type.
  """
  @spec star_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate star_with_type(n, graph_type), to: :yog@generator@classic

  # ============= Wheel Graph =============

  @doc """
  Generates a wheel graph W_n - a cycle with a central hub.

  A wheel graph combines a star and a cycle: center (0) connects to all
  rim nodes (1..n-1), and rim nodes form a cycle.

  **Time Complexity:** O(n)

  ## Example

      w6 = Yog.Generator.Classic.wheel(6)
      # W6: center 0 connected to rim nodes 1-5, which form a cycle

  ## Use Cases

  - Wheel network topologies
  - Centralized routing with backup paths
  - Spoke-hub distribution
  """
  @spec wheel(integer()) :: Yog.graph()
  defdelegate wheel(n), to: :yog@generator@classic

  @doc """
  Generates a wheel graph with specified graph type.
  """
  @spec wheel_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate wheel_with_type(n, graph_type), to: :yog@generator@classic

  # ============= Bipartite Graphs =============

  @doc """
  Generates a complete bipartite graph K_{m,n}.

  In a complete bipartite graph, every node in the first partition
  connects to every node in the second partition.

  **Time Complexity:** O(mn)

  ## Example

      k34 = Yog.Generator.Classic.complete_bipartite(3, 4)
      # K_{3,4}: 3 nodes in left partition, 4 in right, all cross-edges

  ## Use Cases

  - Bipartite matching problems
  - Assignment problems
  - Recommender systems
  """
  @spec complete_bipartite(integer(), integer()) :: Yog.graph()
  defdelegate complete_bipartite(m, n), to: :yog@generator@classic

  @doc """
  Generates a complete bipartite graph with specified graph type.
  """
  @spec complete_bipartite_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate complete_bipartite_with_type(m, n, graph_type), to: :yog@generator@classic

  # ============= Trees =============

  @doc """
  Generates a binary tree of specified depth.

  A complete binary tree where each node (except leaves) has exactly 2 children.
  Total nodes: 2^(depth+1) - 1

  **Time Complexity:** O(2^depth)

  ## Example

      tree = Yog.Generator.Classic.binary_tree(3)
      # Depth-3 binary tree with 15 nodes (1 + 2 + 4 + 8)

  ## Use Cases

  - Hierarchical structures
  - Decision trees
  - Search tree benchmarks
  """
  @spec binary_tree(integer()) :: Yog.graph()
  defdelegate binary_tree(depth), to: :yog@generator@classic

  @doc """
  Generates a binary tree with specified graph type.
  """
  @spec binary_tree_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate binary_tree_with_type(depth, graph_type), to: :yog@generator@classic

  # ============= Grid Graphs =============

  @doc """
  Generates a 2D grid (lattice) graph with specified rows and columns.

  Each cell connects to its adjacent neighbors (up, down, left, right).

  **Time Complexity:** O(rows × cols)

  ## Example

      grid = Yog.Generator.Classic.grid_2d(3, 4)
      # 3x4 grid with 12 nodes

  ## Use Cases

  - Mesh networks
  - Image processing
  - Spatial simulations
  """
  @spec grid_2d(integer(), integer()) :: Yog.graph()
  defdelegate grid_2d(rows, cols), to: :yog@generator@classic

  @doc """
  Generates a 2D grid with specified graph type.
  """
  @spec grid_2d_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate grid_2d_with_type(rows, cols, graph_type), to: :yog@generator@classic

  # ============= Special Graphs =============

  @doc """
  Generates the Petersen graph - a famous graph in graph theory.

  The Petersen graph has 10 nodes, 15 edges, diameter 2, girth 5.
  It's a common counterexample in graph theory.

  **Time Complexity:** O(1)

  ## Example

      p = Yog.Generator.Classic.petersen()
      # The famous Petersen graph

  ## Properties

  - Non-planar
  - Non-Hamiltonian
  - Vertex-transitive
  - Chromatic number 3
  """
  @spec petersen() :: Yog.graph()
  defdelegate petersen(), to: :yog@generator@classic

  @doc """
  Generates the Petersen graph with specified graph type.
  """
  @spec petersen_with_type(Yog.graph_type()) :: Yog.graph()
  defdelegate petersen_with_type(graph_type), to: :yog@generator@classic

  # ============= Empty Graph =============

  @doc """
  Generates an empty graph with n isolated nodes (no edges).

  **Time Complexity:** O(n)

  ## Example

      empty5 = Yog.Generator.Classic.empty(5)
      # 5 nodes with no edges
  """
  @spec empty(integer()) :: Yog.graph()
  defdelegate empty(n), to: :yog@generator@classic

  @doc """
  Generates an empty graph with specified graph type.
  """
  @spec empty_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate empty_with_type(n, graph_type), to: :yog@generator@classic
end
