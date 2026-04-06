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
  @spec erdos_renyi_gnp(integer(), float(), integer() | nil) :: Yog.graph()
  def erdos_renyi_gnp(n, p, seed \\ nil), do: erdos_renyi_gnp_with_type(n, p, :undirected, seed)

  @doc """
  Generates an Erdős-Rényi G(n, p) graph with specified graph type.
  """
  @spec erdos_renyi_gnp_with_type(integer(), float(), Yog.graph_type(), integer() | nil) ::
          Yog.graph()
  def erdos_renyi_gnp_with_type(n, p, graph_type, seed \\ nil)

  def erdos_renyi_gnp_with_type(n, p, graph_type, seed)
      when n > 0 and p >= 0.0 and p <= 1.0 do
    with_seed(seed, fn ->
      base = Yog.new(graph_type)

      graph =
        Enum.reduce(0..(n - 1), base, fn i, g ->
          Yog.add_node(g, i, nil)
        end)

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
    end)
  end

  def erdos_renyi_gnp_with_type(_n, _p, _graph_type, _seed),
    do: Yog.new(:undirected)

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
  @spec erdos_renyi_gnm(integer(), integer(), integer() | nil) :: Yog.graph()
  def erdos_renyi_gnm(n, m, seed \\ nil), do: erdos_renyi_gnm_with_type(n, m, :undirected, seed)

  @doc """
  Generates an Erdős-Rényi G(n, m) graph with specified graph type.
  """
  @spec erdos_renyi_gnm_with_type(integer(), integer(), Yog.graph_type(), integer() | nil) ::
          Yog.graph()
  def erdos_renyi_gnm_with_type(n, m, graph_type, seed \\ nil)

  def erdos_renyi_gnm_with_type(n, m, graph_type, seed)
      when n > 0 and m >= 0 do
    with_seed(seed, fn ->
      base = Yog.new(graph_type)

      graph =
        Enum.reduce(0..(n - 1), base, fn i, g ->
          Yog.add_node(g, i, nil)
        end)

      all_pairs =
        case graph_type do
          :undirected ->
            for i <- 0..(n - 1), j <- (i + 1)..(n - 1)//1, i < j, do: {i, j}

          :directed ->
            for i <- 0..(n - 1), j <- 0..(n - 1)//1, i != j, do: {i, j}
        end

      max_edges = length(all_pairs)
      actual_m = min(m, max_edges)

      selected_edges =
        all_pairs
        |> Enum.shuffle()
        |> Enum.take(actual_m)

      Enum.reduce(selected_edges, graph, fn {from, to}, g ->
        Yog.add_edge!(g, from, to, 1)
      end)
    end)
  end

  def erdos_renyi_gnm_with_type(_n, _m, _graph_type, _seed),
    do: Yog.new(:undirected)

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
  @spec barabasi_albert(integer(), integer(), integer() | nil) :: Yog.graph()
  def barabasi_albert(n, m, seed \\ nil), do: barabasi_albert_with_type(n, m, :undirected, seed)

  @doc """
  Generates a Barabási-Albert graph with specified graph type.
  """
  @spec barabasi_albert_with_type(integer(), integer(), Yog.graph_type(), integer() | nil) ::
          Yog.graph()
  def barabasi_albert_with_type(n, m, graph_type, seed \\ nil)

  def barabasi_albert_with_type(n, m, graph_type, seed)
      when n >= 1 and m >= 1 and m < n do
    with_seed(seed, fn ->
      base = Yog.new(graph_type)

      initial_nodes = min(m, n)

      graph =
        Enum.reduce(0..(initial_nodes - 1), base, fn i, g ->
          g = Yog.add_node(g, i, nil)

          Enum.reduce(0..(i - 1)//1, g, fn j, acc ->
            acc = Yog.add_edge!(acc, i, j, 1)
            if graph_type == :directed, do: Yog.add_edge!(acc, j, i, 1), else: acc
          end)
        end)

      Enum.reduce(initial_nodes..(n - 1), graph, fn new_node, g ->
        g = Yog.add_node(g, new_node, nil)

        existing_nodes = 0..(new_node - 1)

        if Enum.empty?(existing_nodes) do
          g
        else
          degrees =
            Enum.map(existing_nodes, fn node ->
              deg = Yog.Model.degree(g, node)
              {node, max(deg, 1)}
            end)

          total_degree = Enum.sum(Enum.map(degrees, &elem(&1, 1)))
          targets = select_preferential(degrees, total_degree, m, [])

          Enum.reduce(targets, g, fn target, acc ->
            acc = Yog.add_edge!(acc, new_node, target, 1)
            if graph_type == :directed, do: Yog.add_edge!(acc, target, new_node, 1), else: acc
          end)
        end
      end)
    end)
  end

  def barabasi_albert_with_type(n, _m, _graph_type, _seed) when n >= 1 do
    base = Yog.new(:undirected)

    Enum.reduce(0..(n - 1), base, fn i, g ->
      Yog.add_node(g, i, nil)
    end)
  end

  def barabasi_albert_with_type(_n, _m, _graph_type, _seed),
    do: Yog.new(:undirected)

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
  @spec watts_strogatz(integer(), integer(), float(), integer() | nil) :: Yog.graph()
  def watts_strogatz(n, k, p, seed \\ nil),
    do: watts_strogatz_with_type(n, k, p, :undirected, seed)

  @doc """
  Generates a Watts-Strogatz graph with specified graph type.
  """
  @spec watts_strogatz_with_type(integer(), integer(), float(), Yog.graph_type(), integer() | nil) ::
          Yog.graph()
  def watts_strogatz_with_type(n, k, p, graph_type, seed \\ nil)

  def watts_strogatz_with_type(n, k, p, graph_type, seed)
      when n > k and k >= 2 and p >= 0.0 and p <= 1.0 do
    with_seed(seed, fn ->
      base = Yog.new(graph_type)

      graph =
        Enum.reduce(0..(n - 1)//1, base, fn i, g ->
          Yog.add_node(g, i, nil)
        end)

      k_half = div(k, 2)

      lattice_edges =
        for i <- 0..(n - 1)//1,
            offset <- 1..k_half//1,
            do: {i, rem(i + offset, n)}

      all_lattice_edges =
        case graph_type do
          :undirected ->
            reverse_edges = Enum.map(lattice_edges, fn {i, j} -> {j, i} end)
            lattice_edges ++ reverse_edges

          :directed ->
            lattice_edges
        end

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
    end)
  end

  def watts_strogatz_with_type(_n, _k, _p, _graph_type, _seed),
    do: Yog.new(:undirected)

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
  @spec random_tree(integer(), integer() | nil) :: Yog.graph()
  def random_tree(n, seed \\ nil), do: random_tree_with_type(n, :undirected, seed)

  @doc """
  Generates a random tree with specified graph type.
  """
  @spec random_tree_with_type(integer(), Yog.graph_type(), integer() | nil) :: Yog.graph()
  def random_tree_with_type(n, graph_type, seed \\ nil)

  def random_tree_with_type(n, _graph_type, _seed) when n <= 0, do: Yog.new(:undirected)
  def random_tree_with_type(1, graph_type, _seed), do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def random_tree_with_type(n, graph_type, seed) when is_integer(n) and n > 1 do
    with_seed(seed, fn ->
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
    end)
  end

  # =============================================================================
  # Seed Handling Helpers
  # =============================================================================

  # Executes the given function with a temporarily seeded random number generator.
  # If seed is nil, uses the current global RNG state (no change).
  # If seed is provided, temporarily sets :rand to that seed, executes the function,
  # then restores the previous RNG state.
  defp with_seed(nil, fun), do: fun.()

  defp with_seed(seed, fun) do
    old_state = :rand.export_seed()
    :rand.seed(:exsss, seed)
    result = fun.()

    if old_state != :undefined do
      :rand.seed(old_state)
    end

    result
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
  @spec random_regular(integer(), integer(), integer() | nil) :: Yog.graph()
  def random_regular(n, d, seed \\ nil), do: random_regular_with_type(n, d, :undirected, seed)

  @doc """
  Generates a random d-regular graph with specified graph type.
  """
  @spec random_regular_with_type(integer(), integer(), Yog.graph_type(), integer() | nil) ::
          Yog.graph()
  def random_regular_with_type(n, d, graph_type, seed \\ nil)

  def random_regular_with_type(n, d, _graph_type, _seed) when n <= 0 or d < 0 or d >= n,
    do: Yog.new(:undirected)

  def random_regular_with_type(n, d, _graph_type, _seed) when rem(n * d, 2) == 1,
    do: Yog.new(:undirected)

  def random_regular_with_type(1, 0, graph_type, _seed),
    do: Yog.new(graph_type) |> Yog.add_node(0, nil)

  def random_regular_with_type(n, 0, graph_type, _seed) when is_integer(n) and n > 1 do
    # 0-regular: just isolated nodes
    base = Yog.new(graph_type)

    Enum.reduce(0..(n - 1), base, fn i, g ->
      Yog.add_node(g, i, nil)
    end)
  end

  def random_regular_with_type(n, d, graph_type, seed) do
    with_seed(seed, fn ->
      generate_regular(n, d, graph_type, 100)
    end)
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

  # ============= Stochastic Block Model =============

  @doc """
  Generates a graph using the Stochastic Block Model (SBM).

  Nodes are assigned to communities, and edges are added with probabilities
  depending on community membership (higher probability within communities).

  ## Parameters
    - `n` - Number of nodes
    - `k` - Number of communities
    - `p_in` - Probability of edge within community
    - `p_out` - Probability of edge between communities

  ## Options
    - `:seed` - Random seed for reproducibility
    - `:community_sizes` - List of community sizes (must sum to `n`)
    - `:balanced` - Whether to use equal-sized communities (default: `true`)

  ## Examples

      iex> sbm = Yog.Generator.Random.sbm(100, 4, 0.3, 0.05)
      iex> Yog.Model.order(sbm)
      100
  """
  @spec sbm(integer(), integer(), float(), float(), keyword()) :: Yog.graph()
  def sbm(n, k, p_in, p_out, opts \\ []) do
    {graph, _communities} = sbm_with_labels(n, k, p_in, p_out, opts)
    graph
  end

  @doc """
  Generates an SBM graph with specified graph type.
  """
  @spec sbm_with_type(integer(), integer(), float(), float(), Yog.graph_type(), keyword()) ::
          Yog.graph()
  def sbm_with_type(n, k, p_in, p_out, graph_type, opts \\ []) do
    {graph, _communities} = sbm_with_labels_and_type(n, k, p_in, p_out, graph_type, opts)
    graph
  end

  @doc """
  Returns the SBM graph along with community assignments.

  ## Examples

      iex> {_graph, communities} = Yog.Generator.Random.sbm_with_labels(100, 4, 0.3, 0.05)
      iex> map_size(communities)
      100
      iex> communities[0] in 0..3
      true
  """
  @spec sbm_with_labels(integer(), integer(), float(), float(), keyword()) ::
          {Yog.graph(), %{Yog.node_id() => integer()}}
  def sbm_with_labels(n, k, p_in, p_out, opts \\ []) do
    sbm_with_labels_and_type(n, k, p_in, p_out, :undirected, opts)
  end

  @spec sbm_with_labels_and_type(
          integer(),
          integer(),
          float(),
          float(),
          Yog.graph_type(),
          keyword()
        ) ::
          {Yog.graph(), %{Yog.node_id() => integer()}}
  def sbm_with_labels_and_type(n, k, p_in, p_out, graph_type, opts \\ [])

  def sbm_with_labels_and_type(n, k, p_in, p_out, graph_type, opts)
      when n > 0 and k >= 1 and p_in >= 0.0 and p_in <= 1.0 and p_out >= 0.0 and p_out <= 1.0 do
    with_seed(opts[:seed], fn ->
      community_sizes = get_community_sizes(n, k, opts)

      valid =
        length(community_sizes) == k and Enum.sum(community_sizes) == n and
          Enum.all?(community_sizes, &(&1 >= 0))

      if valid do
        base = Yog.new(graph_type)

        graph =
          Enum.reduce(0..(n - 1), base, fn i, g ->
            Yog.add_node(g, i, nil)
          end)

        communities = build_communities(community_sizes)

        edges =
          case graph_type do
            :undirected ->
              for u <- 0..(n - 1),
                  v <- (u + 1)..(n - 1)//1,
                  p = if(communities[u] == communities[v], do: p_in, else: p_out),
                  :rand.uniform() <= p,
                  do: {u, v}

            :directed ->
              for u <- 0..(n - 1),
                  v <- 0..(n - 1)//1,
                  u != v,
                  p = if(communities[u] == communities[v], do: p_in, else: p_out),
                  :rand.uniform() <= p,
                  do: {u, v}
          end

        final_graph =
          Enum.reduce(edges, graph, fn {from, to}, g ->
            Yog.add_edge!(g, from, to, 1)
          end)

        {final_graph, communities}
      else
        {Yog.new(:undirected), %{}}
      end
    end)
  end

  def sbm_with_labels_and_type(_n, _k, _p_in, _p_out, _graph_type, _opts),
    do: {Yog.new(:undirected), %{}}

  defp get_community_sizes(n, k, opts) when n > 0 and k > 0 do
    case Keyword.get(opts, :community_sizes) do
      nil ->
        base_size = div(n, k)
        remainder = rem(n, k)
        List.duplicate(base_size + 1, remainder) ++ List.duplicate(base_size, k - remainder)

      sizes ->
        sizes
    end
  end

  defp get_community_sizes(_n, _k, _opts), do: []

  defp build_communities(community_sizes) do
    community_sizes
    |> Enum.with_index()
    |> Enum.flat_map(fn {size, comm} ->
      start = Enum.sum(Enum.take(community_sizes, comm))
      Enum.map(start..(start + size - 1), fn node -> {node, comm} end)
    end)
    |> Map.new()
  end

  @doc """
  Generates a Degree-Corrected Stochastic Block Model (DCSBM).

  Extends SBM with node-specific degree parameters, allowing more realistic
  degree distributions while preserving community structure.

  ## Options
    - `:degree_dist` - Degree distribution: `:power_law`, `:poisson`, or custom list
    - `:gamma` - Power-law exponent (default: 2.5)
    - `:seed` - Random seed
    - `:community_sizes` - List of community sizes (must sum to `n`)

  ## Examples

      iex> dcsbm = Yog.Generator.Random.dcsbm(100, 3, 0.3, 0.02,
      ...>   degree_dist: :power_law, gamma: 2.5)
      iex> Yog.Model.order(dcsbm)
      100
  """
  @spec dcsbm(integer(), integer(), float(), float(), keyword()) :: Yog.graph()
  def dcsbm(n, k, p_in, p_out, opts \\ []) do
    with_seed(opts[:seed], fn ->
      community_sizes = get_community_sizes(n, k, opts)

      valid =
        n > 0 and k >= 1 and p_in >= 0.0 and p_in <= 1.0 and p_out >= 0.0 and p_out <= 1.0 and
          length(community_sizes) == k and Enum.sum(community_sizes) == n

      if valid do
        base = Yog.new(:undirected)

        graph =
          Enum.reduce(0..(n - 1), base, fn i, g ->
            Yog.add_node(g, i, nil)
          end)

        communities = build_communities(community_sizes)
        thetas = generate_thetas(n, opts) |> Enum.shuffle()

        edges =
          for u <- 0..(n - 1),
              v <- (u + 1)..(n - 1)//1,
              p_base = if(communities[u] == communities[v], do: p_in, else: p_out),
              p = min(1.0, Enum.at(thetas, u) * Enum.at(thetas, v) * p_base),
              :rand.uniform() <= p,
              do: {u, v}

        Enum.reduce(edges, graph, fn {from, to}, g ->
          Yog.add_edge!(g, from, to, 1)
        end)
      else
        Yog.new(:undirected)
      end
    end)
  end

  defp generate_thetas(n, opts) do
    degree_dist = Keyword.get(opts, :degree_dist, :power_law)
    gamma = Keyword.get(opts, :gamma, 2.5)

    thetas =
      case degree_dist do
        :power_law ->
          for i <- 1..n, do: :math.pow(i, -gamma)

        :poisson ->
          for _ <- 1..n, do: 0.5 + :rand.uniform()

        list when is_list(list) ->
          if length(list) == n, do: list, else: List.duplicate(1.0, n)

        _ ->
          List.duplicate(1.0, n)
      end

    mean = Enum.sum(thetas) / n
    if mean > 0, do: Enum.map(thetas, fn t -> t / mean end), else: thetas
  end

  @doc """
  Generates a hierarchical SBM with nested communities.

  ## Options
    - `:levels` - Number of hierarchy levels (default: 2)
    - `:branching` - Branching factor at each level (default: 2)
    - `:p_in` - Probability within leaf communities (default: 0.3)
    - `:p_out` - Probability between root communities (default: 0.01)
    - `:probs` - Explicit probability list of length `levels + 1`
    - `:seed` - Random seed

  ## Examples

      iex> hsbm = Yog.Generator.Random.hsbm(80,
      ...>   levels: 2, branching: 2, p_in: 0.4, p_mid: 0.1, p_out: 0.01)
      iex> Yog.Model.order(hsbm)
      80
  """
  @spec hsbm(integer(), keyword()) :: Yog.graph()
  def hsbm(n, opts \\ []) do
    with_seed(opts[:seed], fn ->
      levels = Keyword.get(opts, :levels, 2)
      branching = Keyword.get(opts, :branching, 2)

      valid = n > 0 and levels >= 1 and branching >= 2

      if valid do
        leaf_blocks = Integer.pow(branching, levels)
        base_leaf_size = div(n, leaf_blocks)

        if base_leaf_size >= 1 do
          probs = get_hsbm_probs(levels, opts)
          powers = for l <- 0..levels, do: Integer.pow(branching, l)

          graph =
            Enum.reduce(0..(n - 1), Yog.new(:undirected), fn i, g ->
              Yog.add_node(g, i, nil)
            end)

          edges =
            for u <- 0..(n - 1),
                v <- (u + 1)..(n - 1)//1,
                lca_level = hsbm_lca_level(u, v, base_leaf_size, n, powers),
                p = Enum.at(probs, lca_level, 0.0),
                :rand.uniform() <= p,
                do: {u, v}

          Enum.reduce(edges, graph, fn {from, to}, g ->
            Yog.add_edge!(g, from, to, 1)
          end)
        else
          Yog.new(:undirected)
        end
      else
        Yog.new(:undirected)
      end
    end)
  end

  defp get_hsbm_probs(levels, opts) do
    case Keyword.get(opts, :probs) do
      nil ->
        p_in = Keyword.get(opts, :p_in, 0.3)
        p_out = Keyword.get(opts, :p_out, 0.01)

        if levels == 2 and Keyword.has_key?(opts, :p_mid) do
          [p_in, opts[:p_mid], p_out]
        else
          for l <- 0..levels//1 do
            p_in + (p_out - p_in) * l / levels
          end
        end

      probs when is_list(probs) ->
        probs
    end
  end

  defp hsbm_lca_level(u, v, leaf_size, n, powers) do
    _leaf_blocks = div(n, leaf_size)
    bu = div(u, leaf_size)
    bv = div(v, leaf_size)

    if bu == bv do
      0
    else
      find_lca_level(bu, bv, powers)
    end
  end

  defp find_lca_level(bu, bv, powers) do
    Enum.find(1..(length(powers) - 1), length(powers) - 1, fn l ->
      div(bu, Enum.at(powers, l)) == div(bv, Enum.at(powers, l))
    end)
  end

  # ============= Configuration Model =============

  @doc """
  Generates a random graph with specified degree sequence using the configuration model.

  Creates a random graph where each node has exactly the degree specified,
  using the stub-matching (configuration model) approach.

  ## Parameters
    - `degrees` - List of desired degrees for each node [d1, d2, ..., dn]

  ## Options
    - `:seed` - Random seed for reproducibility
    - `:allow_multiedges` - Allow parallel edges (default: false)
    - `:allow_selfloops` - Allow self-loops (default: false)
    - `:max_retries` - Maximum attempts to create simple graph (default: 100)

  ## Returns
    `{:ok, graph}` on success, `{:error, reason}` if impossible or retries exceeded

  ## Examples

      iex> # Create graph with specific degree sequence
      ...> degrees = [3, 3, 2, 2, 2]
      ...> {:ok, g} = Yog.Generator.Random.configuration_model(degrees)
      iex> Yog.Model.order(g)
      5

  ## Algorithm

  1. Create stubs: For each node i, create d_i "half-edges"
  2. Random matching: Randomly pair up all stubs
  3. Form edges: Each pair of stubs becomes an edge

  For simple graphs (no self-loops or multi-edges), the algorithm rejects
  invalid configurations and retries up to max_retries.
  """
  @spec configuration_model([integer()], keyword()) ::
          {:ok, Yog.graph()} | {:error, term()}
  def configuration_model(degrees, opts \\ []) do
    opts =
      Keyword.merge(
        [seed: nil, allow_multiedges: false, allow_selfloops: false, max_retries: 100],
        opts
      )

    with_seed(opts[:seed], fn ->
      do_configuration_model(degrees, opts)
    end)
  end

  defp do_configuration_model(degrees, opts) do
    # Validate input
    cond do
      Enum.empty?(degrees) ->
        {:error, :empty_degree_sequence}

      Enum.any?(degrees, &(&1 < 0)) ->
        {:error, :negative_degrees}

      rem(Enum.sum(degrees), 2) != 0 ->
        {:error, :odd_degree_sum}

      true ->
        # Valid degree sequence - try to generate
        max_retries = opts[:max_retries]
        allow_selfloops = opts[:allow_selfloops]
        allow_multiedges = opts[:allow_multiedges]

        try_configuration_model(
          degrees,
          allow_selfloops,
          allow_multiedges,
          max_retries
        )
    end
  end

  defp try_configuration_model(_degrees, _allow_self, _allow_multi, 0) do
    {:error, :max_retries_exceeded}
  end

  defp try_configuration_model(degrees, allow_selfloops, allow_multiedges, retries) do
    # Create stubs: node i appears degrees[i] times
    stubs =
      degrees
      |> Enum.with_index()
      |> Enum.flat_map(fn {deg, node} -> List.duplicate(node, deg) end)

    # Shuffle and pair
    shuffled = Enum.shuffle(stubs)

    # Pair consecutive elements
    pairs = Enum.chunk_every(shuffled, 2)

    # Check all pairs are valid (have 2 elements)
    if Enum.any?(pairs, &(length(&1) != 2)) do
      # Should not happen with even sum, but handle gracefully
      {:error, :invalid_pairing}
    else
      # Build edge list
      edges =
        pairs
        |> Enum.map(fn [a, b] -> {min(a, b), max(a, b)} end)
        |> Enum.filter(fn {a, b} -> a != b or allow_selfloops end)

      # Check for issues
      has_selfloops = Enum.any?(pairs, fn [a, b] -> a == b end)
      edge_set = MapSet.new(edges)
      has_multiedges = MapSet.size(edge_set) < length(edges)

      # Validate
      valid =
        (not has_selfloops or allow_selfloops) and
          (not has_multiedges or allow_multiedges)

      if valid do
        # Build graph
        n = length(degrees)

        graph =
          Enum.reduce(0..(n - 1), Yog.new(:undirected), fn i, g ->
            Yog.add_node(g, i, nil)
          end)

        final_graph =
          Enum.reduce(MapSet.to_list(edge_set), graph, fn {from, to}, g ->
            Yog.add_edge!(g, from, to, 1)
          end)

        {:ok, final_graph}
      else
        # Retry
        try_configuration_model(
          degrees,
          allow_selfloops,
          allow_multiedges,
          retries - 1
        )
      end
    end
  end

  @doc """
  Generates a random graph matching the degree sequence of a given graph.

  Creates a randomized version of the input graph with the same degree
  sequence but random connections (configuration model applied to observed degrees).

  ## Options
    - `:seed` - Random seed for reproducibility
    - `:max_retries` - Maximum attempts (default: 100)

  ## Examples

      iex> original = Yog.Generator.Classic.star(5)
      ...> {:ok, randomized} = Yog.Generator.Random.randomize_degree_sequence(original)
      iex> Yog.Model.order(randomized)
      5

  ## Use Cases

  - Null models in network analysis
  - Degree-preserving randomization
  - Testing which network properties are explained by degree sequence alone
  """
  @spec randomize_degree_sequence(Yog.graph(), keyword()) ::
          {:ok, Yog.graph()} | {:error, term()}
  def randomize_degree_sequence(graph, opts \\ []) do
    nodes = Map.keys(graph.nodes)
    n = length(nodes)

    if n == 0 do
      {:ok, Yog.new(:undirected)}
    else
      # Extract degree sequence using actual node IDs
      degrees = Enum.map(nodes, &Yog.Model.degree(graph, &1))

      # Use configuration model with same degrees
      # Note: configuration_model creates nodes with integer IDs 0..n-1
      # We need to map back to original node IDs if they're not integers
      case configuration_model(degrees, opts) do
        {:ok, int_graph} ->
          # Remap node IDs if necessary
          if nodes == Enum.to_list(0..(n - 1)) do
            {:ok, int_graph}
          else
            {:ok, remap_node_ids(int_graph, nodes)}
          end

        error ->
          error
      end
    end
  end

  # Remaps integer node IDs (0, 1, 2, ...) to original node IDs
  defp remap_node_ids(graph, original_nodes) do
    # Create mapping from integer ID to original ID
    id_mapping =
      original_nodes
      |> Enum.with_index()
      |> Map.new(fn {orig, idx} -> {idx, orig} end)

    # Build new graph with remapped node IDs
    base = Yog.new(:undirected)

    # Add nodes with original IDs and their data
    graph_with_nodes =
      Enum.reduce(original_nodes, base, fn orig_id, g ->
        data = Map.get(graph.nodes, Map.get(id_mapping, orig_id, orig_id), nil)
        Yog.add_node(g, orig_id, data)
      end)

    # Add edges with remapped IDs
    Enum.reduce(Yog.all_edges(graph), graph_with_nodes, fn {from, to, weight}, g ->
      orig_from = Map.get(id_mapping, from, from)
      orig_to = Map.get(id_mapping, to, to)
      Yog.add_edge!(g, orig_from, orig_to, weight)
    end)
  end

  @doc """
  Generates a random graph with power-law degree distribution.

  Creates a graph with degrees following a power law P(k) ~ k^(-gamma),
  using the configuration model approach.

  ## Options
    - `:gamma` - Power-law exponent (default: 2.5, must be > 2)
    - `:k_min` - Minimum degree (default: 1)
    - `:k_max` - Maximum degree (default: n-1)
    - `:seed` - Random seed
    - `:max_retries` - Maximum attempts (default: 100)

  ## Examples

      iex> # Generate with fixed seed for reproducibility
      ...> result = Yog.Generator.Random.power_law_graph(50, gamma: 2.5, seed: 42)
      ...> case result do
      ...>   {:ok, pl} -> Yog.Model.order(pl)
      ...>   {:error, _} -> 0  # May fail due to retries
      ...> end
      50

  ## Notes

  The power-law distribution is generated using the configuration model,
  which differs from the Barabási-Albert preferential attachment model.
  This approach generates the degree sequence first, then randomizes connections.

  For gamma > 2, the expected degree is finite and the graph is well-defined.
  """
  @spec power_law_graph(integer(), keyword()) ::
          {:ok, Yog.graph()} | {:error, term()}
  def power_law_graph(n, opts \\ []) when n > 0 do
    gamma = Keyword.get(opts, :gamma, 2.5)
    k_min = Keyword.get(opts, :k_min, 1)
    k_max = min(Keyword.get(opts, :k_max, n - 1), n - 1)

    cond do
      gamma <= 2 ->
        {:error, :gamma_must_be_greater_than_2}

      k_min < 0 or k_max < k_min ->
        {:error, :invalid_degree_bounds}

      true ->
        with_seed(opts[:seed], fn ->
          # Generate power-law distributed degrees using discrete distribution
          degrees = generate_power_law_degrees(n, gamma, k_min, k_max)

          # Ensure even sum for handshaking lemma
          degrees = ensure_even_degree_sum(degrees, k_min, k_max)

          # Generate graph using configuration model
          configuration_model(degrees, opts)
        end)
    end
  end

  defp generate_power_law_degrees(n, gamma, k_min, k_max) do
    # Use inverse transform sampling for power law
    # CDF: F(k) = 1 - (k/k_min)^(1-gamma) for k >= k_min

    # Normalize constant
    zeta = :math.pow(k_min, 1 - gamma) - :math.pow(k_max + 1, 1 - gamma)

    for _ <- 1..n do
      u = :rand.uniform()

      # Inverse CDF
      k =
        :math.pow(
          :math.pow(k_min, 1 - gamma) - u * zeta,
          1 / (1 - gamma)
        )

      # Round and clamp
      round_k = round(k)
      max(k_min, min(k_max, round_k))
    end
  end

  defp ensure_even_degree_sum(degrees, k_min, k_max) do
    sum = Enum.sum(degrees)

    if rem(sum, 2) == 0 do
      degrees
    else
      # Make sum even by adjusting one node's degree
      # Prefer increasing if possible, otherwise decrease
      idx = :rand.uniform(length(degrees)) - 1
      current = Enum.at(degrees, idx)

      new_value =
        cond do
          current < k_max -> current + 1
          current > k_min -> current - 1
          true -> current
        end

      List.replace_at(degrees, idx, new_value)
    end
  end
end
