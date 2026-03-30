defmodule Yog.Community.Result do
  @moduledoc """
  Result of community detection algorithms.

  Represents a partition of nodes into non-overlapping communities, where
  each node belongs to exactly one community.

  ## Fields

  - `assignments` - Map from node ID to community ID
  - `num_communities` - Total number of distinct communities
  - `metadata` - Optional metadata (algorithm name, quality metrics, etc.)

  ## Examples

      iex> result = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1})
      iex> result.num_communities
      2
      iex> result.assignments[1]
      0
  """

  @type node_id :: Yog.Model.node_id()
  @type community_id :: any()

  @enforce_keys [:assignments, :num_communities]
  defstruct [:assignments, :num_communities, metadata: %{}]

  @type t :: %__MODULE__{
          assignments: %{node_id() => community_id()},
          num_communities: non_neg_integer(),
          metadata: map()
        }

  @doc """
  Creates a community result from an assignments map.

  Automatically calculates the number of communities.
  """
  @spec new(%{node_id() => community_id()}) :: t()
  def new(assignments) when is_map(assignments) do
    num = assignments |> Map.values() |> Enum.uniq() |> length()

    %__MODULE__{assignments: assignments, num_communities: num}
  end

  @doc """
  Creates a community result with explicit metadata and optional pre-computed values.

  ## Options

  - `:num_communities` - Pre-computed community count to avoid re-scanning

  ## Examples

      iex> result = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1}, %{}, num_communities: 2)
      iex> result.num_communities
      2
  """
  @spec new(%{node_id() => community_id()}, map(), keyword()) :: t()
  def new(assignments, metadata, opts \\ []) when is_map(assignments) and is_map(metadata) do
    num =
      case Keyword.get(opts, :num_communities) do
        nil -> assignments |> Map.values() |> Enum.uniq() |> length()
        n -> n
      end

    %__MODULE__{assignments: assignments, num_communities: num, metadata: metadata}
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{assignments: asgn, num_communities: num} = map) do
    metadata = Map.get(map, :metadata, %{})
    %__MODULE__{assignments: asgn, num_communities: num, metadata: metadata}
  end

  @doc """
  Convert to legacy map format (for gradual migration).
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    %{
      assignments: result.assignments,
      num_communities: result.num_communities
    }
  end
end
