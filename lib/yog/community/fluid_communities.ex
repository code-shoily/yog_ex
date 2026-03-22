defmodule Yog.Community.FluidCommunities do
  @moduledoc """
  Fluid Communities algorithm for community detection.

  A fast algorithm that finds exactly k communities by modeling
  communities as "fluids" that expand and compete for nodes. Good for
  finding a specific number of communities quickly.

  ## When to Use

  - When you know the exact number of communities
  - Fast detection with known k
  - Large-scale community detection

  ## Options

  - `:k` - Number of communities (default: auto-detect)
  - `:max_iterations` - Maximum iterations (default: 100)
  - `:seed` - Random seed (default: 42)

  ## Example

      communities = Yog.Community.FluidCommunities.detect(graph)

      communities = Yog.Community.FluidCommunities.detect_with_options(graph, k: 5)
  """

  alias Yog.Community

  @doc """
  Returns default options for Fluid Communities.
  """
  @spec default_options() :: %{k: integer() | nil, max_iterations: integer(), seed: integer()}
  def default_options do
    %{k: nil, max_iterations: 100, seed: 42}
  end

  @doc """
  Detects communities using Fluid Communities with default options.
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@fluid_communities.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using Fluid Communities with custom options.

  ## Options

    * `:k` - Number of communities (default: auto-detect)
    * `:max_iterations` - Maximum iterations (default: 100)
    * `:seed` - Random seed (default: 42)
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Community.communities()
  def detect_with_options(graph, opts) do
    k = Keyword.get(opts, :k)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 42)

    options = {:fluid_options, k, max_iterations, seed}

    {:communities, assignments, num} =
      :yog@community@fluid_communities.detect_with_options(graph, options)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities with weighted edges.
  """
  @spec detect_with_weights(Yog.graph(), integer(), integer()) :: Community.communities()
  def detect_with_weights(graph, max_iterations \\ 100, seed \\ 42) do
    {:communities, assignments, num} =
      :yog@community@fluid_communities.detect_with_weights(graph, max_iterations, seed)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
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
end
