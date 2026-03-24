defmodule Yog.Community.Dendrogram do
  @moduledoc """
  Hierarchical community structure from algorithms like Louvain, Walktrap, Leiden.

  A dendrogram represents multiple levels of community structure, from fine-grained
  (many small communities) to coarse-grained (few large communities).

  ## Fields

  - `levels` - List of community partitions, ordered from finest to coarsest
  - `merge_order` - Sequence of community merges (optional)
  - `metadata` - Optional metadata (algorithm name, modularity scores, etc.)

  ## Examples

      iex> level1 = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})
      iex> level2 = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 0})
      iex> dend = Yog.Community.Dendrogram.new([level1, level2])
      iex> Yog.Community.Dendrogram.finest(dend).num_communities
      2
      iex> Yog.Community.Dendrogram.coarsest(dend).num_communities
      1
  """

  alias Yog.Community.Result

  @enforce_keys [:levels]
  defstruct [:levels, merge_order: [], metadata: %{}]

  @type t :: %__MODULE__{
          levels: [Result.t()],
          merge_order: [{non_neg_integer(), non_neg_integer()}],
          metadata: map()
        }

  @doc """
  Creates a new dendrogram from a list of community levels.
  """
  @spec new([Result.t()]) :: t()
  def new(levels) when is_list(levels) do
    %__MODULE__{levels: levels}
  end

  @doc """
  Creates a new dendrogram with merge order tracking.
  """
  @spec new([Result.t()], [{non_neg_integer(), non_neg_integer()}]) :: t()
  def new(levels, merge_order) when is_list(levels) and is_list(merge_order) do
    %__MODULE__{levels: levels, merge_order: merge_order}
  end

  @doc """
  Get the finest partition (most communities).
  """
  @spec finest(t()) :: Result.t()
  def finest(%__MODULE__{levels: [first | _]}), do: first
  def finest(%__MODULE__{levels: []}), do: Result.new(%{})

  @doc """
  Get the coarsest partition (fewest communities).
  """
  @spec coarsest(t()) :: Result.t()
  def coarsest(%__MODULE__{levels: levels}) do
    List.last(levels) || Result.new(%{})
  end

  @doc """
  Get partition with approximately n communities.

  Returns the first level with <= n communities.
  """
  @spec at_level(t(), non_neg_integer()) :: Result.t() | nil
  def at_level(%__MODULE__{levels: levels}, n) do
    Enum.find(levels, fn level -> level.num_communities <= n end)
  end

  @doc """
  Get partition at a specific level index.
  """
  @spec get_level(t(), non_neg_integer()) :: Result.t() | nil
  def get_level(%__MODULE__{levels: levels}, index) do
    Enum.at(levels, index)
  end

  @doc """
  Get the number of hierarchical levels.
  """
  @spec num_levels(t()) :: non_neg_integer()
  def num_levels(%__MODULE__{levels: levels}) do
    length(levels)
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{levels: levels, merge_order: merge_order}) do
    converted_levels = Enum.map(levels, &Result.from_map/1)
    %__MODULE__{levels: converted_levels, merge_order: merge_order}
  end

  def from_map(%{levels: levels}) do
    converted_levels = Enum.map(levels, &Result.from_map/1)
    %__MODULE__{levels: converted_levels}
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{levels: levels, merge_order: merge_order}) do
    %{
      levels: Enum.map(levels, &Result.to_map/1),
      merge_order: merge_order
    }
  end
end
