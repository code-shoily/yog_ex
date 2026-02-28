defmodule Yog.MinCut do
  @moduledoc """
  Algorithms for calculating global minimum cuts.
  """

  @type min_cut_result :: %{weight: integer(), group_a_size: integer(), group_b_size: integer()}

  @doc """
  Finds the global minimum cut in an **undirected** graph using the
  Stoer-Wagner algorithm.

  Returns `%{weight: int, group_a_size: int, group_b_size: int}`.
  """
  @spec global_min_cut(Yog.graph()) :: min_cut_result()
  def global_min_cut(graph) do
    {:min_cut, weight, a_size, b_size} = :yog@min_cut.global_min_cut(graph)
    %{weight: weight, group_a_size: a_size, group_b_size: b_size}
  end

  @doc """
  Alias for global_min_cut since it doesn't fail based on node count anymore.
  """
  @spec global_min_cut!(Yog.graph()) :: min_cut_result()
  def global_min_cut!(graph), do: global_min_cut(graph)
end
