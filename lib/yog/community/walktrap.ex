defmodule Yog.Community.Walktrap do
  @moduledoc """
  Walktrap algorithm for community detection.

  Uses random walks to compute distances between nodes. Nodes are merged
  into communities based on these distances, creating a hierarchical
  structure that captures the graph's community organization.

  ## When to Use

  - When random walk structure is meaningful
  - For hierarchical community detection
  - Good for capturing local structure

  ## Options

  - `:walk_length` - Length of random walks (default: 4)
  - `:max_iterations` - Maximum merges (default: all)

  ## Example

      communities = Yog.Community.Walktrap.detect(graph)

      dendrogram = Yog.Community.Walktrap.detect_hierarchical(graph, walk_length: 5)
  """

  alias Yog.Community

  @doc """
  Returns default options for Walktrap.
  """
  @spec default_options() :: %{walk_length: integer(), max_iterations: integer()}
  def default_options do
    %{walk_length: 4, max_iterations: 1_000_000}
  end

  @doc """
  Detects communities using Walktrap with default options.
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@walktrap.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using Walktrap with custom options.

  ## Options

    * `:walk_length` - Length of random walks (default: 4)
    * `:max_iterations` - Maximum merges (default: 1_000_000)
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Community.communities()
  def detect_with_options(graph, opts) do
    walk_length = Keyword.get(opts, :walk_length, 4)
    max_iterations = Keyword.get(opts, :max_iterations, 1_000_000)

    options = {:walktrap_options, walk_length, max_iterations}

    {:communities, assignments, num} =
      :yog@community@walktrap.detect_with_options(graph, options)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects hierarchical community structure.

  ## Parameters

    * `graph` - The graph to analyze
    * `walk_length` - Length of random walks (default: 4)
  """
  @spec detect_hierarchical(Yog.graph(), integer()) :: Community.dendrogram()
  def detect_hierarchical(graph, walk_length \\ 4) do
    {:dendrogram, levels, merge_order} =
      :yog@community@walktrap.detect_hierarchical(graph, walk_length)

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
