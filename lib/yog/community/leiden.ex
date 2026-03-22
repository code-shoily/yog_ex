defmodule Yog.Community.Leiden do
  @moduledoc """
  Leiden algorithm for community detection.

  The Leiden algorithm is an improvement over Louvain that guarantees
  well-connected communities. It addresses a known issue where Louvain
  may produce disconnected communities.

  ## When to Use

  - When community quality is more important than speed
  - When you need guaranteed well-connected communities
  - Better modularity optimization than Louvain

  ## Options

  - `:min_modularity_gain` - Stop when gain < threshold (default: 0.000001)
  - `:max_iterations` - Max iterations per phase (default: 100)
  - `:refinement_iterations` - Refinement step iterations (default: 10)
  - `:seed` - Random seed for tie-breaking (default: 42)

  ## Example

      communities = Yog.Community.Leiden.detect(graph)

      communities = Yog.Community.Leiden.detect_with_options(graph,
        min_modularity_gain: 0.0001,
        refinement_iterations: 5
      )
  """

  alias Yog.Community

  @doc """
  Detects communities using the Leiden algorithm with default options.
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@leiden.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using the Leiden algorithm with custom options.

  ## Options

    * `:min_modularity_gain` - Minimum modularity gain (default: 0.000001)
    * `:max_iterations` - Maximum iterations per phase (default: 100)
    * `:refinement_iterations` - Refinement iterations (default: 10)
    * `:seed` - Random seed (default: 42)
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Community.communities()
  def detect_with_options(graph, opts) do
    min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    refinement_iterations = Keyword.get(opts, :refinement_iterations, 10)
    seed = Keyword.get(opts, :seed, 42)

    options = {:leiden_options, min_modularity_gain, max_iterations, refinement_iterations, seed}

    {:communities, assignments, num} =
      :yog@community@leiden.detect_with_options(graph, options)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects hierarchical community structure.
  """
  @spec detect_hierarchical(Yog.graph()) :: Community.dendrogram()
  def detect_hierarchical(graph) do
    {:dendrogram, levels, merge_order} = :yog@community@leiden.detect_hierarchical(graph)

    %{
      levels: Enum.map(levels, &wrap_communities/1),
      merge_order: merge_order
    }
  end

  @doc """
  Detects hierarchical community structure with custom options.
  """
  @spec detect_hierarchical_with_options(Yog.graph(), keyword()) :: Community.dendrogram()
  def detect_hierarchical_with_options(graph, opts) do
    min_modularity_gain = Keyword.get(opts, :min_modularity_gain, 0.000001)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    refinement_iterations = Keyword.get(opts, :refinement_iterations, 10)
    seed = Keyword.get(opts, :seed, 42)

    options = {:leiden_options, min_modularity_gain, max_iterations, refinement_iterations, seed}

    {:dendrogram, levels, merge_order} =
      :yog@community@leiden.detect_hierarchical_with_options(graph, options)

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
