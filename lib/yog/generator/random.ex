defmodule Yog.Generator.Random do
  @moduledoc """
  Stochastic graph generators for random graph models.

  Random generators use randomness to model real-world networks with properties
  like scale-free distributions, small-world effects, and community structure.

  ## Available Generators

  | Generator | Model | Complexity | Key Property |
  |-----------|-------|------------|--------------|
  | `erdos_renyi_gnp/2` | G(n, p) | O(n²) | Each edge with probability p |
  | `erdos_renyi_gnm/2` | G(n, m) | O(m) | Exactly m random edges |
  | `barabasi_albert/2` | Preferential | O(nm) | Scale-free (power-law degrees) |
  | `watts_strogatz/3` | Small-world | O(nk) | High clustering + short paths |
  | `random_tree/1` | Uniform tree | O(n²) | Uniformly random spanning tree |

  ## Quick Start (Not Doctests - Random Output)

      # Random network models (output varies due to randomness)
      # sparse = Yog.Generator.Random.erdos_renyi_gnp(100, 0.05)      # Sparse random (p=5%)
      # exact = Yog.Generator.Random.erdos_renyi_gnm(50, 100)         # Exactly 100 edges
      # scale_free = Yog.Generator.Random.barabasi_albert(1000, 3)    # Scale-free network
      # small_world = Yog.Generator.Random.watts_strogatz(100, 6, 0.1) # Small-world (10% rewire)
      # tree = Yog.Generator.Random.random_tree(50)                   # Random spanning tree

  ## Network Models Explained

  ### Erdős-Rényi G(n, p)
  - Each possible edge included independently with probability p
  - Expected edges: p × n(n-1)/2 (undirected) or p × n(n-1) (directed)
  - Phase transition at p = 1/n (giant component emerges)
  - **Use for**: Random network modeling, percolation studies

  ### Erdős-Rényi G(n, m)
  - Exactly m edges added uniformly at random
  - Uniform distribution over all graphs with n nodes and m edges
  - **Use for**: Fixed edge count requirements, specific density testing

  ### Barabási-Albert (Preferential Attachment)
  - Starts with m₀ nodes, adds nodes connecting to m existing nodes
  - New nodes prefer high-degree nodes ("rich get richer")
  - Power-law degree distribution: P(k) ~ k^(-3)
  - **Use for**: Social networks, citation networks, web graphs

  ### Watts-Strogatz (Small-World)
  - Starts with ring lattice (high clustering)
  - Rewires edges with probability p (creates shortcuts)
  - Balances local clustering with global connectivity
  - **Use for**: Social networks, neural networks, epidemic modeling

  ### Random Tree
  - Builds tree by connecting new nodes to random existing nodes
  - Produces uniform distribution over all labeled trees
  - **Use for**: Spanning trees, hierarchical structures

  ## References

  - [Erdős-Rényi Model](https://en.wikipedia.org/wiki/Erd%C5%91s%E2%80%93R%C3%A9nyi_model)
  - [Barabási-Albert Model](https://en.wikipedia.org/wiki/Barab%C3%A1si%E2%80%93Albert_model)
  - [Watts-Strogatz Model](https://en.wikipedia.org/wiki/Watts%E2%80%93Strogatz_model)
  - [Scale-Free Networks](https://en.wikipedia.org/wiki/Scale-free_network)
  - [Small-World Network](https://en.wikipedia.org/wiki/Small-world_network)
  """

  # ============= Erdős-Rényi G(n, p) =============

  @doc """
  Generates a random graph using the Erdős-Rényi G(n, p) model.

  Each possible edge is included independently with probability p.
  For undirected graphs, each unordered pair is considered once.

  **Time Complexity:** O(n²)

  ## Examples

      iex> # Generate a sparse random graph (output varies)
      ...> sparse = Yog.Generator.Random.erdos_renyi_gnp(10, 0.3)
      iex> Yog.Model.order(sparse)
      10
      iex> # Generate a denser random graph
      ...> dense = Yog.Generator.Random.erdos_renyi_gnp(5, 0.8)
      iex> Yog.Model.order(dense)
      5

  ## Properties

  - Expected number of edges: p × n(n-1)/2 (undirected) or p × n(n-1) (directed)
  - Phase transition at p = 1/n (giant component emerges)

  ## Use Cases

  - Random network modeling
  - Percolation studies
  - Average-case algorithm analysis
  """
  @spec erdos_renyi_gnp(integer(), float()) :: Yog.graph()
  defdelegate erdos_renyi_gnp(n, p), to: :yog@generator@random

  @doc """
  Generates an Erdős-Rényi G(n, p) graph with specified graph type.
  """
  @spec erdos_renyi_gnp_with_type(integer(), float(), Yog.graph_type()) :: Yog.graph()
  defdelegate erdos_renyi_gnp_with_type(n, p, graph_type), to: :yog@generator@random

  # ============= Erdős-Rényi G(n, m) =============

  @doc """
  Generates a random graph using the Erdős-Rényi G(n, m) model.

  Exactly m edges are added uniformly at random from all possible edges.

  **Time Complexity:** O(m)

  ## Examples

      iex> graph = Yog.Generator.Random.erdos_renyi_gnm(10, 15)
      iex> Yog.Model.order(graph)
      10

  ## Properties

  - Uniform distribution over all graphs with n nodes and m edges
  - Fixed edge count (unlike G(n,p) which has random edge count)

  ## Use Cases

  - Fixed edge count requirements
  - Specific density testing
  - Comparative studies
  """
  @spec erdos_renyi_gnm(integer(), integer()) :: Yog.graph()
  defdelegate erdos_renyi_gnm(n, m), to: :yog@generator@random

  @doc """
  Generates an Erdős-Rényi G(n, m) graph with specified graph type.
  """
  @spec erdos_renyi_gnm_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate erdos_renyi_gnm_with_type(n, m, graph_type), to: :yog@generator@random

  # ============= Barabási-Albert =============

  @doc """
  Generates a scale-free graph using the Barabási-Albert preferential attachment model.

  Starts with m nodes and adds n-m new nodes. Each new node connects to m existing
  nodes with probability proportional to their degree ("rich get richer").

  **Time Complexity:** O(nm)

  ## Examples

      iex> ba = Yog.Generator.Random.barabasi_albert(20, 2)
      iex> Yog.Model.order(ba)
      20

  ## Properties

  - Power-law degree distribution: P(k) ~ k^(-3)
  - Scale-free: no characteristic node degree
  - High degree nodes (hubs) emerge naturally

  ## Use Cases

  - Social networks
  - Citation networks
  - Web graphs
  - Biological networks
  """
  @spec barabasi_albert(integer(), integer()) :: Yog.graph()
  defdelegate barabasi_albert(n, m), to: :yog@generator@random

  @doc """
  Generates a Barabási-Albert graph with specified graph type.
  """
  @spec barabasi_albert_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate barabasi_albert_with_type(n, m, graph_type), to: :yog@generator@random

  # ============= Watts-Strogatz =============

  @doc """
  Generates a small-world graph using the Watts-Strogatz model.

  Starts with a ring lattice where each node connects to k nearest neighbors.
  Then rewires each edge with probability p to create shortcuts.

  **Time Complexity:** O(nk)

  ## Examples

      iex> ws = Yog.Generator.Random.watts_strogatz(20, 4, 0.1)
      iex> Yog.Model.order(ws)
      20

  ## Properties

  - High clustering coefficient (like regular lattice)
  - Short average path length (like random graph)
  - Tunable with p: p=0 is regular, p=1 is random

  ## Use Cases

  - Social networks
  - Neural networks
  - Epidemic modeling
  - Power grids
  """
  @spec watts_strogatz(integer(), integer(), float()) :: Yog.graph()
  defdelegate watts_strogatz(n, k, p), to: :yog@generator@random

  @doc """
  Generates a Watts-Strogatz graph with specified graph type.
  """
  @spec watts_strogatz_with_type(integer(), integer(), float(), Yog.graph_type()) :: Yog.graph()
  defdelegate watts_strogatz_with_type(n, k, p, graph_type), to: :yog@generator@random

  # ============= Random Tree =============

  @doc """
  Generates a uniformly random tree on n nodes.

  Each labeled tree has equal probability of being generated.

  **Time Complexity:** O(n²)

  ## Examples

      iex> tree = Yog.Generator.Random.random_tree(10)
      iex> Yog.Model.order(tree)
      10
      iex> # A tree has exactly n-1 edges
      ...> Yog.Model.edge_count(tree)
      9

  ## Properties

  - Exactly n-1 edges
  - Connected and acyclic
  - Uniform distribution over all labeled trees

  ## Use Cases

  - Spanning trees
  - Hierarchical structures
  - Network design
  """
  @spec random_tree(integer()) :: Yog.graph()
  defdelegate random_tree(n), to: :yog@generator@random

  @doc """
  Generates a random tree with specified graph type.
  """
  @spec random_tree_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  defdelegate random_tree_with_type(n, graph_type), to: :yog@generator@random
end
