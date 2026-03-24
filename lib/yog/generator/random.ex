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
  | `random_regular/2` | d-regular | O(nd) | All nodes have degree d |

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
  def erdos_renyi_gnp(n, p), do: erdos_renyi_gnp_with_type(n, p, :undirected)

  @doc """
  Generates an Erdős-Rényi G(n, p) graph with specified graph type.
  """
  @spec erdos_renyi_gnp_with_type(integer(), float(), Yog.graph_type()) :: Yog.graph()
  def erdos_renyi_gnp_with_type(n, p, graph_type) when n > 0 and p >= 0.0 and p <= 1.0 do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Generate all possible edges and filter by probability
    all_pairs =
      case graph_type do
        :undirected ->
          for i <- 0..(n - 1), j <- (i + 1)..(n - 1)//1, i < j, do: {i, j}

        :directed ->
          for i <- 0..(n - 1), j <- 0..(n - 1)//1, i != j, do: {i, j}
      end

    edges = Enum.filter(all_pairs, fn _ -> :rand.uniform() <= p end)

    Enum.reduce(edges, graph, fn {from, to}, g ->
      Yog.add_edge!(g, from, to, 1)
    end)
  end

  def erdos_renyi_gnp_with_type(_n, _p, _graph_type), do: Yog.new(:undirected)

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
  def erdos_renyi_gnm(n, m), do: erdos_renyi_gnm_with_type(n, m, :undirected)

  @doc """
  Generates an Erdős-Rényi G(n, m) graph with specified graph type.
  """
  @spec erdos_renyi_gnm_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def erdos_renyi_gnm_with_type(n, m, graph_type) when n > 0 and m >= 0 do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # Generate all possible edges
    all_pairs =
      case graph_type do
        :undirected ->
          for i <- 0..(n - 1), j <- (i + 1)..(n - 1)//1, i < j, do: {i, j}

        :directed ->
          for i <- 0..(n - 1), j <- 0..(n - 1)//1, i != j, do: {i, j}
      end

    # Clamp m to max possible edges
    max_edges = length(all_pairs)
    actual_m = min(m, max_edges)

    # Shuffle and take first m
    selected_edges =
      all_pairs
      |> Enum.shuffle()
      |> Enum.take(actual_m)

    Enum.reduce(selected_edges, graph, fn {from, to}, g ->
      Yog.add_edge!(g, from, to, 1)
    end)
  end

  def erdos_renyi_gnm_with_type(_n, _m, _graph_type), do: Yog.new(:undirected)

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
  def barabasi_albert(n, m), do: barabasi_albert_with_type(n, m, :undirected)

  @doc """
  Generates a Barabási-Albert graph with specified graph type.
  """
  @spec barabasi_albert_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def barabasi_albert_with_type(n, m, graph_type) when n >= 1 and m >= 1 and m < n do
    base = Yog.new(graph_type)

    # Start with a small complete graph of m nodes
    initial_nodes = min(m, n)

    graph =
      Enum.reduce(0..(initial_nodes - 1), base, fn i, g ->
        g = Yog.add_node(g, i, nil)
        # Connect to all previous nodes
        Enum.reduce(0..(i - 1)//1, g, fn j, acc ->
          acc = Yog.add_edge!(acc, i, j, 1)
          if graph_type == :directed, do: Yog.add_edge!(acc, j, i, 1), else: acc
        end)
      end)

    # Add remaining nodes with preferential attachment
    Enum.reduce(initial_nodes..(n - 1), graph, fn new_node, g ->
      g = Yog.add_node(g, new_node, nil)

      # Get current nodes and their degrees
      existing_nodes = 0..(new_node - 1)

      if Enum.empty?(existing_nodes) do
        g
      else
        # Calculate degrees (for undirected, count all connections)
        degrees =
          Enum.map(existing_nodes, fn node ->
            neighbors = length(Yog.neighbors(g, node))
            {node, max(neighbors, 1)}
          end)

        total_degree = Enum.sum(Enum.map(degrees, &elem(&1, 1)))

        # Preferential attachment: select m nodes
        targets = select_preferential(degrees, total_degree, m, [])

        Enum.reduce(targets, g, fn target, acc ->
          acc = Yog.add_edge!(acc, new_node, target, 1)
          if graph_type == :directed, do: Yog.add_edge!(acc, target, new_node, 1), else: acc
        end)
      end
    end)
  end

  def barabasi_albert_with_type(n, _m, _graph_type) when n >= 1 do
    # m >= n case: just return n isolated nodes
    base = Yog.new(:undirected)

    Enum.reduce(0..(n - 1), base, fn i, g ->
      Yog.add_node(g, i, nil)
    end)
  end

  def barabasi_albert_with_type(_n, _m, _graph_type), do: Yog.new(:undirected)

  # Select m nodes with probability proportional to their degree
  defp select_preferential(_degrees, _total, 0, acc), do: Enum.uniq(acc)

  defp select_preferential(degrees, total, remaining, acc) when remaining > 0 do
    pick = :rand.uniform() * total

    {node, _} =
      Enum.reduce_while(degrees, {nil, 0.0}, fn {n, deg}, {_, cum} ->
        new_cum = cum + deg

        if new_cum >= pick do
          {:halt, {n, new_cum}}
        else
          {:cont, {n, new_cum}}
        end
      end)

    # Retry if we picked a duplicate (simple approach)
    if node in acc do
      select_preferential(degrees, total, remaining, acc)
    else
      select_preferential(degrees, total, remaining - 1, [node | acc])
    end
  end

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
  def watts_strogatz(n, k, p), do: watts_strogatz_with_type(n, k, p, :undirected)

  @doc """
  Generates a Watts-Strogatz graph with specified graph type.
  """
  @spec watts_strogatz_with_type(integer(), integer(), float(), Yog.graph_type()) :: Yog.graph()
  def watts_strogatz_with_type(n, k, p, graph_type)
      when n > k and k >= 2 and p >= 0.0 and p <= 1.0 do
    base = Yog.new(graph_type)

    # Add all nodes
    graph =
      Enum.reduce(0..(n - 1)//1, base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    # k must be even for the ring lattice construction
    k_half = div(k, 2)

    # Build ring lattice: each node connects to k/2 neighbors on each side
    # For undirected graphs, we create edges in both directions (each node connects forward)
    # For directed graphs, we create edges in one direction only
    lattice_edges =
      for i <- 0..(n - 1)//1,
          offset <- 1..k_half//1,
          do: {i, rem(i + offset, n)}

    # For undirected, also add the reverse edges to ensure each node has k neighbors
    all_lattice_edges =
      case graph_type do
        :undirected ->
          reverse_edges = Enum.map(lattice_edges, fn {i, j} -> {j, i} end)
          lattice_edges ++ reverse_edges

        :directed ->
          lattice_edges
      end

    # Rewire edges with probability p
    {final_edges, _} =
      Enum.reduce(all_lattice_edges, {[], MapSet.new()}, fn {from, to}, {edges, used} ->
        edge_key =
          case graph_type do
            :undirected -> {min(from, to), max(from, to)}
            :directed -> {from, to}
          end

        if MapSet.member?(used, edge_key) do
          # Skip duplicate edges
          {edges, used}
        else
          new_used = MapSet.put(used, edge_key)

          if :rand.uniform() <= p do
            # Rewire: connect to a random node
            candidates =
              0..(n - 1)
              |> Enum.filter(fn x ->
                x != from and
                  not MapSet.member?(used, {min(from, x), max(from, x)})
              end)

            if candidates == [] do
              {[{from, to} | edges], new_used}
            else
              new_to = Enum.random(candidates)
              new_edge_key = {min(from, new_to), max(from, new_to)}
              {[{from, new_to} | edges], MapSet.put(new_used, new_edge_key)}
            end
          else
            {[{from, to} | edges], new_used}
          end
        end
      end)

    Enum.reduce(final_edges, graph, fn {from, to}, g ->
      Yog.add_edge!(g, from, to, 1)
    end)
  end

  def watts_strogatz_with_type(_n, _k, _p, _graph_type), do: Yog.new(:undirected)

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
  def random_tree(n), do: random_tree_with_type(n, :undirected)

  @doc """
  Generates a random tree with specified graph type.
  """
  @spec random_tree_with_type(integer(), Yog.graph_type()) :: Yog.graph()
  def random_tree_with_type(n, _graph_type) when n <= 0, do: Yog.new(:undirected)
  def random_tree_with_type(1, graph_type), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def random_tree_with_type(n, graph_type) do
    base = Yog.new(graph_type)

    # Start with node 0
    graph = Yog.add_node(base, 0, nil)

    # Add remaining nodes, each connecting to a random existing node
    Enum.reduce(1..(n - 1), graph, fn new_node, g ->
      g = Yog.add_node(g, new_node, nil)
      parent = :rand.uniform(new_node) - 1
      g = Yog.add_edge!(g, new_node, parent, 1)
      if graph_type == :directed, do: Yog.add_edge!(g, parent, new_node, 1), else: g
    end)
  end

  # ============= Random Regular Graph =============

  @doc """
  Generates a random d-regular graph on n nodes.

  A d-regular graph has every node with exactly degree d. This implementation
  uses a configuration model approach with rewiring to ensure simplicity
  (no self-loops or parallel edges).

  **Preconditions:**
  - n × d must be even (required for any d-regular graph)
  - d < n (cannot have degree >= number of nodes in simple graph)
  - d >= 0

  **Properties:**
  - Uniform distribution over all d-regular graphs (approximate)
  - Exactly n nodes, (n × d) / 2 edges
  - All nodes have degree exactly d

  **Time Complexity:** O(n × d)

  ## Examples

      iex> # Generate a 3-regular graph with 10 nodes
      ...> reg = Yog.Generator.Random.random_regular(10, 3)
      iex> Yog.Model.order(reg)
      10
      iex> # Every node has degree 3
      ...> degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
      iex> Enum.all?(degrees, fn d -> d == 3 end)
      true
      iex> # Total edges = n*d/2 = 15
      ...> Yog.Model.edge_count(reg)
      15

  ## Algorithm

  Uses a configuration model:
  1. Create d "stubs" for each of the n nodes
  2. Randomly pair stubs to form edges
  3. Reject and retry if self-loops or parallel edges form

  ## Use Cases

  - Testing algorithms that need uniform degree distribution
  - Expander graph approximations
  - Network models where degree is constrained
  - Comparison with scale-free networks

  ## References

  - [Configuration Model](https://en.wikipedia.org/wiki/Configuration_model)
  - [Random Regular Graph](https://en.wikipedia.org/wiki/Random_regular_graph)
  """
  @spec random_regular(integer(), integer()) :: Yog.graph()
  def random_regular(n, d), do: random_regular_with_type(n, d, :undirected)

  @doc """
  Generates a random d-regular graph with specified graph type.
  """
  @spec random_regular_with_type(integer(), integer(), Yog.graph_type()) :: Yog.graph()
  def random_regular_with_type(n, d, _graph_type) when n <= 0 or d < 0 or d >= n,
    do: Yog.new(:undirected)

  def random_regular_with_type(n, d, _graph_type) when rem(n * d, 2) == 1,
    do: Yog.new(:undirected)

  def random_regular_with_type(1, 0, graph_type),
    do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def random_regular_with_type(n, 0, graph_type) do
    # 0-regular: just isolated nodes
    base = Yog.new(graph_type)

    Enum.reduce(0..(n - 1), base, fn i, g ->
      Yog.add_node(g, i, nil)
    end)
  end

  def random_regular_with_type(n, d, graph_type) do
    # Use configuration model with rejection sampling
    # Create d stubs per node, randomly match them
    generate_regular(n, d, graph_type, 100)
  end

  # Attempt to generate with max retries
  defp generate_regular(n, d, graph_type, retries) when retries > 0 do
    # Create stubs: each node i appears d times in the list
    stubs = for i <- 0..(n - 1), _ <- 1..d, do: i

    # Shuffle stubs and pair them
    shuffled = Enum.shuffle(stubs)

    case try_pairing(shuffled, n, graph_type) do
      {:ok, graph} -> graph
      :retry -> generate_regular(n, d, graph_type, retries - 1)
    end
  end

  defp generate_regular(_n, _d, _graph_type, _retries), do: Yog.new(:undirected)

  # Try to pair stubs without creating self-loops or parallel edges
  defp try_pairing(stubs, n, graph_type) do
    pairs = Enum.chunk_every(stubs, 2)

    # Check for invalid pairs (self-loops with odd length)
    if Enum.any?(pairs, fn
         [a, b] -> a == b
         _ -> true
       end) do
      :retry
    else
      # Check for parallel edges
      edge_set =
        pairs
        |> Enum.map(fn [a, b] -> {min(a, b), max(a, b)} end)
        |> MapSet.new()

      # If we have unique edges equal to pairs, we're good
      if MapSet.size(edge_set) == length(pairs) do
        {:ok, build_regular_graph(n, pairs, graph_type)}
      else
        :retry
      end
    end
  end

  defp build_regular_graph(n, pairs, graph_type) do
    base = Yog.new(graph_type)

    graph =
      Enum.reduce(0..(n - 1), base, fn i, g ->
        Yog.add_node(g, i, nil)
      end)

    Enum.reduce(pairs, graph, fn [from, to], g ->
      Yog.add_edge!(g, from, to, 1)
    end)
  end
end
