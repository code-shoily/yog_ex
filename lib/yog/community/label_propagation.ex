defmodule Yog.Community.LabelPropagation do
  @moduledoc """
  Label Propagation Algorithm (LPA) for community detection.

  A fast, near-linear time algorithm where each node adopts the label
  that most of its neighbors have. The algorithm converges when each
  node has the same label as the majority of its neighbors.

  ## When to Use

  - Very large graphs (near-linear time complexity)
  - Speed is more important than optimal quality
  - Large-scale network analysis

  ## Options

  - `:max_iterations` - Maximum iterations (default: 100)
  - `:seed` - Random seed for initialization (default: 0)

  ## Example

      communities = Yog.Community.LabelPropagation.detect(graph)

      communities = Yog.Community.LabelPropagation.detect_with_options(graph,
        max_iterations: 200,
        seed: 42
      )
  """

  alias Yog.Community

  @doc """
  Returns default options for LPA.
  """
  @spec default_options() :: %{max_iterations: integer(), seed: integer()}
  def default_options do
    %{max_iterations: 100, seed: 0}
  end

  @doc """
  Detects communities using Label Propagation with default options.
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@label_propagation.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using Label Propagation with custom options.

  ## Options

    * `:max_iterations` - Maximum iterations (default: 100)
    * `:seed` - Random seed (default: 0)
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Community.communities()
  def detect_with_options(graph, opts) do
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 0)

    options = {:label_propagation_options, max_iterations, seed}

    {:communities, assignments, num} =
      :yog@community@label_propagation.detect_with_options(graph, options)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Shuffles a list randomly (utility function).
  """
  @spec shuffle([any()]) :: [any()]
  def shuffle(list) do
    :yog@community@label_propagation.shuffle(list)
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
