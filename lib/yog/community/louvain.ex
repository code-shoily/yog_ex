defmodule Yog.Community.Louvain do
  @moduledoc """
  Louvain method for community detection.

  The Louvain algorithm is a greedy optimization method that maximizes
  modularity. It works in two phases:
  1. Local optimization: Move nodes to neighboring communities to increase modularity
  2. Aggregation: Build a new graph where nodes are communities

  These phases repeat until no improvement is possible.

  ## When to Use

  - Large graphs (scales to millions of nodes)
  - When modularity is the primary quality metric
  - Fast, widely-used baseline algorithm

  ## Options

  - `:min_modularity_gain` - Stop when gain < threshold (default: 0.000001)
  - `:max_iterations` - Max iterations per phase (default: 100)
  - `:seed` - Random seed for tie-breaking (default: 42)

  ## Examples

      # Simple detection (creates communities for a triangle + square connected by an edge)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_node(5, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 4, to: 5, with: 1)
      iex> communities = Yog.Community.Louvain.detect(graph)
      iex> is_map(communities.assignments)
      true
      iex> communities.num_communities >= 1
      true
  """

  alias Yog.Community

  @doc """
  Detects communities using the Louvain algorithm with default options.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> communities = Yog.Community.Louvain.detect(graph)
      iex> is_map(communities.assignments)
      true
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@louvain.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using the Louvain algorithm with custom options.

  ## Options

    * `:min_modularity_gain` - Minimum modularity gain to continue (default: 0.000001)
    * `:max_iterations` - Maximum iterations per phase (default: 100)
    * `:seed` - Random seed for tie-breaking (default: 42)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> communities = Yog.Community.Louvain.detect_with_options(graph,
      ...>   min_modularity_gain: 0.0001,
      ...>   max_iterations: 50,
      ...>   seed: 123
      ...> )
      iex> is_map(communities.assignments)
      true
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Community.communities()
  def detect_with_options(graph, opts) do
    min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 42)

    options = {:louvain_options, min_modularity_gain, max_iterations, seed}

    {:communities, assignments, num} =
      :yog@community@louvain.detect_with_options(graph, options)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities with detailed statistics.

  Returns the communities along with modularity scores for each level.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> {communities, stats} = Yog.Community.Louvain.detect_with_stats(graph)
      iex> is_map(communities.assignments)
      true
      iex> is_map(stats)
      true
  """
  @spec detect_with_stats(Yog.graph(), keyword()) :: {Community.communities(), map()}
  def detect_with_stats(graph, opts \\ []) do
    min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 42)

    options = {:louvain_options, min_modularity_gain, max_iterations, seed}
    result = :yog@community@louvain.detect_with_stats(graph, options)

    case result do
      {{:communities, assignments, num}, stats} ->
        communities = %{
          assignments: wrap_gleam_dict(assignments),
          num_communities: num
        }

        # Convert stats tuple to map
        stats_map =
          case stats do
            {:louvain_stats, mod, levels, iters} ->
              %{modularity: mod, levels: levels, iterations: iters}

            _ ->
              %{}
          end

        {communities, stats_map}
    end
  end

  @doc """
  Detects hierarchical community structure.

  Returns a dendrogram showing community structure at multiple levels
  of granularity.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> dendrogram = Yog.Community.Louvain.detect_hierarchical(graph)
      iex> is_list(dendrogram.levels)
      true
  """
  @spec detect_hierarchical(Yog.graph()) :: Community.dendrogram()
  def detect_hierarchical(graph) do
    {:dendrogram, levels, merge_order} = :yog@community@louvain.detect_hierarchical(graph)

    %{
      levels: Enum.map(levels, &wrap_communities/1),
      merge_order: merge_order
    }
  end

  @doc """
  Detects hierarchical community structure with custom options.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> dendrogram = Yog.Community.Louvain.detect_hierarchical_with_options(graph,
      ...>   min_modularity_gain: 0.0001,
      ...>   max_iterations: 50
      ...> )
      iex> is_list(dendrogram.levels)
      true
  """
  @spec detect_hierarchical_with_options(Yog.graph(), keyword()) :: Community.dendrogram()
  def detect_hierarchical_with_options(graph, opts) do
    min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 42)

    options = {:louvain_options, min_modularity_gain, max_iterations, seed}

    {:dendrogram, levels, merge_order} =
      :yog@community@louvain.detect_hierarchical_with_options(graph, options)

    %{
      levels: Enum.map(levels, &wrap_communities/1),
      merge_order: merge_order
    }
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp wrap_gleam_dict(dict) do
    dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end

  defp wrap_communities({:communities, assignments, num}) do
    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end
end
