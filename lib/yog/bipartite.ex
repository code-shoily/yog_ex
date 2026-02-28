defmodule Yog.Bipartite do
  @moduledoc """
  Algorithms for bipartite graphs, including matching and detection.

  A bipartite graph is a graph whose vertices can be divided into two disjoint sets
  such that every edge connects a vertex in one set to a vertex in the other set.

  This module handles:
  - Bipartite detection (2-coloring)
  - Extracting the two independent partitions
  - Finding the maximum unweighted matching
  - The Gale-Shapley algorithm for stable matchings
  """

  @type partition :: %{left: MapSet.t(Yog.node_id()), right: MapSet.t(Yog.node_id())}

  @doc """
  Checks if a graph is bipartite (2-colorable).
  """
  @spec is_bipartite?(Yog.graph()) :: boolean()
  def is_bipartite?(graph) do
    :yog@bipartite.is_bipartite(graph)
  end

  @doc """
  Attempts to partition the graph into two independent sets.

  Returns `{:ok, %{left: MapSet, right: MapSet}}` or `{:error, :not_bipartite}`.
  """
  @spec partition(Yog.graph()) :: {:ok, partition()} | {:error, :not_bipartite}
  def partition(graph) do
    case :yog@bipartite.partition(graph) do
      {:some, {:partition, left_set, right_set}} ->
        left = left_set |> :gleam@set.to_list() |> MapSet.new()
        right = right_set |> :gleam@set.to_list() |> MapSet.new()
        {:ok, %{left: left, right: right}}

      :none ->
        {:error, :not_bipartite}
    end
  end

  @doc """
  Finds maximum unweighted matching in a bipartite graph.

  Requires the partition.
  Returns a list of pairs `[{u, v}]` representing the matched edges.
  """
  @spec maximum_matching(Yog.graph(), partition()) :: [{Yog.node_id(), Yog.node_id()}]
  def maximum_matching(graph, partition) do
    gleam_part =
      {:partition, partition.left |> MapSet.to_list() |> :gleam@set.from_list(),
       partition.right |> MapSet.to_list() |> :gleam@set.from_list()}

    :yog@bipartite.maximum_matching(graph, gleam_part)
  end

  @doc """
  Finds a stable matching between two equally-sized groups using the Gale-Shapley algorithm.

  ## Options
  - `:left_prefs` - Map of `%{left_id => [preferred_right_ids...]}`
  - `:right_prefs` - Map of `%{right_id => [preferred_left_ids...]}`

  ## Returns
  A bidirectional map representing the optimal assignments `%{person_id => partner_id}`.
  Both `%{left_id => right_id}` and `%{right_id => left_id}` mappings are included.
  """
  @spec stable_marriage(keyword()) :: %{term() => term()}
  def stable_marriage(opts) do
    left_prefs_map = Keyword.fetch!(opts, :left_prefs)
    right_prefs_map = Keyword.fetch!(opts, :right_prefs)

    # All people who might be matched (from both sides)
    all_people = Map.keys(left_prefs_map) ++ Map.keys(right_prefs_map)

    left_prefs = wrap_elixir_map_to_gleam_dict(left_prefs_map)
    right_prefs = wrap_elixir_map_to_gleam_dict(right_prefs_map)

    result = :yog@bipartite.stable_marriage(left_prefs, right_prefs)

    unwrap_stable_marriage_result(result, all_people)
  end

  # The raw result is an Opaque StableMatching type. We can use get_partner/2 to unwrap it into a native Map.
  # The Gleam implementation stores bidirectional mappings, so we query all people from both sides.
  defp unwrap_stable_marriage_result(matching, all_people) do
    Enum.reduce(all_people, %{}, fn person, acc ->
      case :yog@bipartite.get_partner(matching, person) do
        {:some, partner} -> Map.put(acc, person, partner)
        :none -> acc
      end
    end)
  end

  defp wrap_elixir_map_to_gleam_dict(map) do
    map
    |> Map.to_list()
    |> :gleam@dict.from_list()
  end
end
