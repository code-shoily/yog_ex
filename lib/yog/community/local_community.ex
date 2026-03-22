defmodule Yog.Community.LocalCommunity do
  @moduledoc """
  Local community detection via seed expansion.

  Finds the community around specific seed nodes without analyzing the
  entire graph. This is useful for massive graphs where global community
  detection is infeasible.

  ## When to Use

  - Massive graphs where global detection is too slow
  - When you only care about communities around specific nodes
  - Online/real-time community detection

  ## Options

  - `:max_expansions` - Maximum expansion steps (default: 10)
  - `:min_improvement` - Minimum modularity improvement (default: 0.0001)
  - `:method` - Expansion method: `:clauset` or `:lancichinetti` (default: `:clauset`)
  - `:weight_fn` - Function to extract edge weights (default: `& &1`)

  ## Example

      # Find community around node :a
      community = Yog.Community.LocalCommunity.detect(graph, [:a])

      # Find community around multiple seeds
      community = Yog.Community.LocalCommunity.detect(graph, [:a, :b, :c])

      # With custom options
      community = Yog.Community.LocalCommunity.detect_with(graph, [:a],
        max_expansions: 5,
        method: :lancichinetti,
        weight_fn: fn w -> w end
      )
  """

  @doc """
  Returns default options for local community detection.
  """
  @spec default_options() :: %{
          max_expansions: integer(),
          min_improvement: float(),
          method: :clauset | :lancichinetti
        }
  def default_options do
    %{
      max_expansions: 10,
      min_improvement: 0.0001,
      method: :clauset
    }
  end

  @doc """
  Detects the local community around given seed nodes.

  Returns a set of node IDs belonging to the local community.
  """
  @spec detect(Yog.graph(), [Yog.node_id()]) :: MapSet.t(Yog.node_id())
  def detect(graph, seeds) do
    result = :yog@community@local_community.detect(graph, seeds)
    MapSet.new(result)
  end

  @doc """
  Detects the local community with custom options.

  ## Options

    * `:max_expansions` - Maximum expansion steps (default: 10)
    * `:min_improvement` - Minimum modularity improvement (default: 0.0001)
    * `:method` - Expansion method: `:clauset` or `:lancichinetti` (default: `:clauset`)
    * `:weight_fn` - Function to extract edge weights (default: `& &1`)
  """
  @spec detect_with(Yog.graph(), [Yog.node_id()], keyword()) :: MapSet.t(Yog.node_id())
  def detect_with(graph, seeds, opts) do
    max_expansions = Keyword.get(opts, :max_expansions, 10)
    min_improvement = Keyword.get(opts, :min_improvement, 0.0001)
    method = Keyword.get(opts, :method, :clauset)
    weight_fn = Keyword.get(opts, :weight_fn, fn x -> x end)

    method_atom =
      case method do
        :clauset -> :clauset
        :lancichinetti -> :lancichinetti
        _ -> :clauset
      end

    options = {:local_community_options, max_expansions, min_improvement, method_atom}

    result = :yog@community@local_community.detect_with(graph, seeds, options, weight_fn)
    MapSet.new(result)
  end
end
