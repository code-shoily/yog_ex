defmodule Yog.Community.Infomap do
  @moduledoc """
  Infomap algorithm for community detection.

  An information-theoretic approach that models random walks on the network
  and finds the community structure that minimizes the description length
  of these walks (the "map equation").

  ## When to Use

  - When flow/dynamics on the network matters
  - For directed networks with flow patterns
  - Information-theoretic interpretation desired

  ## Options

  - `:max_iterations` - Maximum optimization iterations (default: 100)
  - `:seed` - Random seed (default: 42)
  - `:teleportation_probability` - Random walk restart probability (default: 0.15)

  ## Example

      communities = Yog.Community.Infomap.detect(graph)

      communities = Yog.Community.Infomap.detect_with_options(graph,
        teleportation_probability: 0.1,
        max_iterations: 200
      )
  """

  alias Yog.Community

  @doc """
  Returns default options for Infomap.
  """
  @spec default_options() :: %{
          max_iterations: integer(),
          seed: integer(),
          teleportation_probability: float()
        }
  def default_options do
    %{
      max_iterations: 100,
      seed: 42,
      teleportation_probability: 0.15
    }
  end

  @doc """
  Detects communities using Infomap with default options.
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@infomap.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using Infomap with custom options.

  ## Options

    * `:max_iterations` - Maximum optimization iterations (default: 100)
    * `:seed` - Random seed (default: 42)
    * `:teleportation_probability` - Random walk restart probability (default: 0.15)
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Community.communities()
  def detect_with_options(graph, opts) do
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 42)
    teleport = Keyword.get(opts, :teleportation_probability, 0.15)

    options = {:infomap_options, max_iterations, seed, teleport}

    {:communities, assignments, num} =
      :yog@community@infomap.detect_with_options(graph, options)

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
