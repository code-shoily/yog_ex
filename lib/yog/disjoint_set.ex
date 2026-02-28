defmodule Yog.DisjointSet do
  @moduledoc """
  A Disjoint Set (Union-Find) data structure.

  Provides O(α(n)) operations for dynamic connectivity queries.
  """

  @type t :: term()

  @doc """
  Creates a new, empty Disjoint Set.
  """
  @spec new() :: t()
  defdelegate new(), to: :yog@disjoint_set

  @doc """
  Creates a Disjoint Set from a list of pairs `[{a, b}]`, automatically unioning them.
  """
  @spec from_pairs([{term(), term()}]) :: t()
  defdelegate from_pairs(pairs), to: :yog@disjoint_set

  @doc """
  Adds a single element into its own new set.
  """
  @spec add(t(), term()) :: t()
  defdelegate add(dsu, element), to: :yog@disjoint_set

  @doc """
  Finds the root representative of an element's set, performing path compression.
  Returns `{updated_dsu, root}` so you can capture the compressed tree state.
  """
  @spec find(t(), term()) :: {t(), term()}
  defdelegate find(dsu, element), to: :yog@disjoint_set

  @doc """
  Merges the sets containing `element_1` and `element_2` using union by rank.
  """
  @spec union(t(), term(), term()) :: t()
  defdelegate union(dsu, element_1, element_2), to: :yog@disjoint_set

  @doc """
  Checks if two elements are in the same set. Returns `{updated_dsu, boolean}`.
  """
  @spec connected?(t(), term(), term()) :: {t(), boolean()}
  def connected?(dsu, element_1, element_2) do
    :yog@disjoint_set.connected(dsu, element_1, element_2)
  end

  @doc """
  Returns all disjoint sets as a list of lists.
  """
  @spec to_lists(t()) :: [[term()]]
  defdelegate to_lists(dsu), to: :yog@disjoint_set

  @doc """
  Returns the total number of unique elements tracked.
  """
  @spec size(t()) :: non_neg_integer()
  defdelegate size(dsu), to: :yog@disjoint_set

  @doc """
  Returns the number of disconnected components/sets.
  """
  @spec count_sets(t()) :: non_neg_integer()
  defdelegate count_sets(dsu), to: :yog@disjoint_set
end
