defmodule Yog.Centrality do
  @moduledoc """
  Centrality measures for identifying important nodes in graphs.

  Provides degree, closeness, harmonic, betweenness, and PageRank centrality.
  """

  @type centrality_scores :: %{Yog.node_id() => float()}

  @doc """
  Calculates the Degree Centrality for all nodes in the graph.

  For directed graphs, specify the mode: `:in_degree`, `:out_degree`, or `:total_degree`.
  For undirected graphs, the mode is ignored.
  """
  @spec degree(Yog.graph(), :in_degree | :out_degree | :total_degree) :: centrality_scores()
  def degree(graph, mode \\ :total_degree) do
    :yog@centrality.degree(graph, mode)
    |> wrap_gleam_dict()
  end

  @doc """
  Calculates Closeness Centrality for all nodes.

  Requires options: `:zero`, `:add`, `:compare`, `:to_float`.
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

  Requires options: `:zero`, `:add`, `:compare`, `:to_float`.
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

  Requires options: `:zero`, `:add`, `:compare`, `:to_float`.
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

  Options:
  - `:damping` (default 0.85)
  - `:max_iterations` (default 100)
  - `:tolerance` (default 0.0001)
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
  of its neighbors. A node is important if it is connected to other important nodes.
  Uses power iteration to converge on the principal eigenvector.

  ## Options

  - `:max_iterations` - Maximum number of power iterations (default: 100)
  - `:tolerance` - Convergence threshold for L2 norm (default: 0.0001)

  ## Example

      scores = Yog.Centrality.eigenvector(graph, max_iterations: 100, tolerance: 0.0001)
      # => %{1 => 0.707, 2 => 1.0, 3 => 0.707}
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

  ## Options

  - `:alpha` - Attenuation factor (must be < 1/largest_eigenvalue, typically 0.1-0.3)
  - `:beta` - Base centrality (typically 1.0)
  - `:max_iterations` - Maximum number of iterations (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      scores = Yog.Centrality.katz(graph, alpha: 0.1, beta: 1.0)
      # => %{1 => 2.5, 2 => 3.0, 3 => 2.5}
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

  ## Options

  - `:alpha` - Attenuation factor (typically 0.1-0.5)
  - `:initial` - Initial centrality value for all nodes
  - `:max_iterations` - Maximum number of iterations (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Example

      scores = Yog.Centrality.alpha(graph, alpha: 0.3, initial: 1.0)
      # => %{1 => 2.0, 2 => 3.0, 3 => 2.0}
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

  defp wrap_gleam_dict(dict) do
    dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end
end
