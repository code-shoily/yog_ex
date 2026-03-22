defmodule Yog.Centrality do
  @moduledoc """
  Centrality measures for identifying important nodes in graphs.

  Provides degree, closeness, harmonic, betweenness, and PageRank centrality.
  All functions return a map of Node IDs to their scores.

  ## Overview

  | Measure | Function | Best For |
  |---------|----------|----------|
  | Degree | `degree/2` | Local connectivity |
  | Closeness | `closeness/2` | Distance to all others |
  | Harmonic | `harmonic/2` | Disconnected graphs |
  | Betweenness | `betweenness/2` | Bridge/gatekeeper detection |
  | PageRank | `pagerank/2` | Link-quality importance |
  | Eigenvector | `eigenvector/2` | Influence based on neighbor importance |
  | Katz | `katz/2` | Attenuated influence with base score |
  | Alpha | `alpha/2` | Directed graph influence |
  """

  @typedoc """
  A mapping of Node IDs to their calculated centrality scores.
  """
  @type centrality_scores :: %{Yog.node_id() => float()}

  @typedoc """
  Specifies which edges to consider for directed graphs.
  - `:in_degree` - Consider only incoming edges (Prestige)
  - `:out_degree` - Consider only outgoing edges (Gregariousness)
  - `:total_degree` - Consider both incoming and outgoing edges
  """
  @type degree_mode :: :in_degree | :out_degree | :total_degree

  @doc """
  Calculates the Degree Centrality for all nodes in the graph.

  For directed graphs, use `mode` to specify which edges to count.
  For undirected graphs, the `mode` is ignored.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.degree(graph)
      iex> # In a triangle, all nodes have degree 2, normalized is 2/2 = 1.0
      iex> scores[1] |> Float.round(3)
      1.0

      iex> # Directed graph with different modes
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> # Out-degree: Node 1 has 1 outgoing edge
      iex> scores = Yog.Centrality.degree(graph, :out_degree)
      iex> scores[1] |> Float.round(3)
      0.5
  """
  @spec degree(Yog.graph(), degree_mode()) :: centrality_scores()
  def degree(graph, mode \\ :total_degree) do
    :yog@centrality.degree(graph, mode)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Closeness Centrality for all nodes.

  Closeness centrality measures how close a node is to all other nodes
  in the graph. It is calculated as the reciprocal of the sum of the
  shortest path distances from the node to all other nodes.

  Formula: C(v) = (n - 1) / Σ d(v, u) for all u ≠ v

  Note: In disconnected graphs, nodes that cannot reach all other nodes
  will have a centrality of 0.0. Consider `harmonic/2` for disconnected graphs.

  **Time Complexity:** O(V * (V + E) log V) using Dijkstra from each node

  ## Options

  - `:zero` - The identity element for distances (e.g., 0 for integers)
  - `:add` - Function to add two distances
  - `:compare` - Function to compare two distances (returns `:lt`, `:eq`, or `:gt`)
  - `:to_float` - Function to convert distance type to Float for final score

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.closeness(graph,
      ...>   zero: 0,
      ...>   add: &Kernel.+/2,
      ...>   compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   to_float: fn x -> x * 1.0 end
      ...> )
      iex> # In a triangle, all nodes have closeness 1.0
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec closeness(Yog.graph(), keyword()) :: centrality_scores()
  def closeness(graph, opts) do
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    to_float = Keyword.fetch!(opts, :to_float)

    :yog@centrality.closeness(graph, zero, add, compare, to_float)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Harmonic Centrality for all nodes.

  Harmonic centrality is a variation of closeness centrality that handles
  disconnected graphs gracefully. It sums the reciprocals of the shortest
  path distances from a node to all reachable nodes.

  Formula: H(v) = Σ (1 / d(v, u)) / (n - 1) for all u ≠ v

  **Time Complexity:** O(V * (V + E) log V)

  ## Options

  - `:zero` - The identity element for distances
  - `:add` - Function to add two distances
  - `:compare` - Function to compare two distances (returns `:lt`, `:eq`, or `:gt`)
  - `:to_float` - Function to convert distance type to Float

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "Center")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}])
      iex> scores = Yog.Centrality.harmonic(graph,
      ...>   zero: 0,
      ...>   add: &Kernel.+/2,
      ...>   compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   to_float: fn x -> x * 1.0 end
      ...> )
      iex> # Center node: (1/1 + 1/1) / 2 = 1.0
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec harmonic(Yog.graph(), keyword()) :: centrality_scores()
  def harmonic(graph, opts) do
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    to_float = Keyword.fetch!(opts, :to_float)

    :yog@centrality.harmonic_centrality(graph, zero, add, compare, to_float)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Betweenness Centrality for all nodes.

  Betweenness centrality of a node v is the sum of the fraction of
  all-pairs shortest paths that pass through v.

  **Time Complexity:** O(VE) for unweighted, O(VE + V²logV) for weighted.

  ## Options

  - `:zero` - The identity element for distances
  - `:add` - Function to add two distances
  - `:compare` - Function to compare two distances (returns `:lt`, `:eq`, or `:gt`)
  - `:to_float` - Function to convert distance type to Float

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.betweenness(graph,
      ...>   zero: 0,
      ...>   add: &Kernel.+/2,
      ...>   compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   to_float: fn x -> x * 1.0 end
      ...> )
      iex> # In a path 1->2->3, node 2 lies on the shortest path from 1 to 3
      iex> scores[2] |> Float.round(3)
      1.0
  """
  @spec betweenness(Yog.graph(), keyword()) :: centrality_scores()
  def betweenness(graph, opts) do
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    compare = Keyword.fetch!(opts, :compare)
    to_float = Keyword.fetch!(opts, :to_float)

    :yog@centrality.betweenness(graph, zero, add, compare, to_float)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates PageRank centrality for all nodes.

  PageRank measures node importance based on the quality and quantity of
  incoming links. A node is important if it is linked to by other important
  nodes. Originally developed for ranking web pages, it's useful for:

  - Ranking nodes in directed networks
  - Identifying influential nodes in citation networks
  - Finding important entities in knowledge graphs
  - Recommendation systems

  The algorithm uses a "random surfer" model: with probability `damping`,
  the surfer follows a random outgoing link; otherwise, they jump to any
  random node.

  **Time Complexity:** O(max_iterations × (V + E))

  ## When to Use PageRank

  - **Directed graphs** where link direction matters
  - When you care about **link quality** (links from important nodes count more)
  - Citation networks, web graphs, recommendation systems

  For undirected graphs, consider `eigenvector/2` instead.

  ## Options

  - `:damping` - Probability of continuing to follow links (default: 0.85)
  - `:max_iterations` - Maximum iterations before returning (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.pagerank(graph)
      iex> # Scores should sum to approximately 1.0
      iex> Enum.sum(Map.values(scores)) |> Float.round(2)
      1.0
      iex> # With custom options
      iex> scores = Yog.Centrality.pagerank(graph, damping: 0.9, max_iterations: 50, tolerance: 0.001)
      iex> map_size(scores)
      3
  """
  @spec pagerank(Yog.graph(), keyword()) :: centrality_scores()
  def pagerank(graph, opts \\ []) do
    damping = Keyword.get(opts, :damping, 0.85)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    options = {:page_rank_options, damping, max_iterations, tolerance}

    :yog@centrality.pagerank(graph, options)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Eigenvector Centrality for all nodes.

  Eigenvector centrality measures a node's influence based on the centrality
  of its neighbors. A node is important if it is connected to other important
  nodes. Uses power iteration to converge on the principal eigenvector.

  **Time Complexity:** O(max_iterations * (V + E))

  ## Options

  - `:max_iterations` - Maximum number of power iterations (default: 100)
  - `:tolerance` - Convergence threshold for L2 norm (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "center")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}])
      iex> scores = Yog.Centrality.eigenvector(graph)
      iex> scores[1] > scores[2]
      true
  """
  @spec eigenvector(Yog.graph(), keyword()) :: centrality_scores()
  def eigenvector(graph, opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    :yog@centrality.eigenvector(graph, max_iterations, tolerance)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Katz Centrality for all nodes.

  Katz centrality is a variant of eigenvector centrality that adds an
  attenuation factor (alpha) to prevent the infinite accumulation of
  centrality in cycles. It also includes a constant term (beta) to give
  every node some base centrality.

  Formula: C(v) = α * Σ C(u) + β for all neighbors u

  **Time Complexity:** O(max_iterations * (V + E))

  ## Options

  - `:alpha` - Attenuation factor (must be < 1/largest_eigenvalue, typically 0.1-0.3)
  - `:beta` - Base centrality (typically 1.0)
  - `:max_iterations` - Maximum number of iterations (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.katz(graph, alpha: 0.1, beta: 1.0)
      iex> # All scores should be >= beta
      iex> scores[1] >= 1.0
      true
  """
  @spec katz(Yog.graph(), keyword()) :: centrality_scores()
  def katz(graph, opts \\ []) do
    alpha = Keyword.fetch!(opts, :alpha)
    beta = Keyword.fetch!(opts, :beta)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    :yog@centrality.katz(graph, alpha, beta, max_iterations, tolerance)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Alpha Centrality for all nodes.

  Alpha centrality is a generalization of Katz centrality for directed
  graphs. It measures the total number of paths from a node, weighted
  by path length with attenuation factor alpha.

  Unlike Katz, alpha centrality does not include a constant beta term
  and is particularly useful for analyzing influence in directed networks.

  **Time Complexity:** O(max_iterations * (V + E))

  ## Options

  - `:alpha` - Attenuation factor (typically 0.1-0.5)
  - `:initial` - Initial centrality value for all nodes
  - `:max_iterations` - Maximum number of iterations (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.alpha(graph, alpha: 0.3, initial: 1.0)
      iex> map_size(scores)
      3
  """
  @spec alpha(Yog.graph(), keyword()) :: centrality_scores()
  def alpha(graph, opts \\ []) do
    alpha = Keyword.fetch!(opts, :alpha)
    initial = Keyword.fetch!(opts, :initial)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    tolerance = Keyword.get(opts, :tolerance, 0.0001)

    :yog@centrality.alpha_centrality(graph, alpha, initial, max_iterations, tolerance)
    |> wrap_gleam_dict()
  end

  @doc """
  Closeness centrality with **Int** weights (e.g., unweighted graphs).
  Uses 0 as zero, `&Kernel.+/2`, integer comparison, and `&(&1 * 1.0)` for conversion.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.closeness_int(graph)
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec closeness_int(Yog.graph()) :: centrality_scores()
  def closeness_int(graph) do
    closeness(graph,
      zero: 0,
      add: &Kernel.+/2,
      compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      to_float: fn x -> x * 1.0 end
    )
  end

  @doc """
  Harmonic centrality with **Int** weights.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> scores = Yog.Centrality.harmonic_int(graph)
      iex> scores[1] |> Float.round(3)
      1.0
  """
  @spec harmonic_int(Yog.graph()) :: centrality_scores()
  def harmonic_int(graph) do
    harmonic(graph,
      zero: 0,
      add: &Kernel.+/2,
      compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      to_float: fn x -> x * 1.0 end
    )
  end

  @doc """
  Betweenness centrality with **Int** weights.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> scores = Yog.Centrality.betweenness_int(graph)
      iex> # Node 2 is on the shortest path from 1 to 3
      iex> scores[2] |> Float.round(3)
      1.0
  """
  @spec betweenness_int(Yog.graph()) :: centrality_scores()
  def betweenness_int(graph) do
    betweenness(graph,
      zero: 0,
      add: &Kernel.+/2,
      compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      to_float: fn x -> x * 1.0 end
    )
  end

  @doc """
  Degree centrality with default options for undirected graphs.
  Uses `:total_degree` mode.

  Same as `degree(graph, :total_degree)`.
  """
  @spec degree_total(Yog.graph()) :: centrality_scores()
  def degree_total(graph), do: degree(graph, :total_degree)

  defp wrap_gleam_dict(dict) do
    dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end
end
