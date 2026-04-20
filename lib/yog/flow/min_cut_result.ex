defmodule Yog.Flow.MinCutResult do
  @moduledoc """
  Result of minimum cut computation.

  A cut partitions the nodes into two sets: the source side and the sink side.
  The cut value equals the total weight of edges crossing between the sets.

  ## Fields

  - `cut_value` - Total weight of the minimum cut
  - `source_side_size` - Number of nodes in the source partition
  - `sink_side_size` - Number of nodes in the sink partition
  - `source_side` - Optional `MapSet` of node IDs in the source partition
  - `sink_side` - Optional `MapSet` of node IDs in the sink partition
  - `algorithm` - Name of the algorithm used (optional)

  ## Examples

      iex> result = %Yog.Flow.MinCutResult{
      ...>   cut_value: 15,
      ...>   source_side_size: 2,
      ...>   sink_side_size: 3
      ...> }
      iex> result.source_side_size + result.sink_side_size
      5

  ## Backward Compatibility

  The `source_side` and `sink_side` fields are populated when using
  `global_min_cut/2` with `track_partitions: true` or when extracting
  a min-cut from a max-flow result.
  """

  @enforce_keys [:cut_value, :source_side_size, :sink_side_size]
  defstruct [
    :cut_value,
    :source_side_size,
    :sink_side_size,
    source_side: nil,
    sink_side: nil,
    algorithm: :stoer_wagner
  ]

  @type t :: %__MODULE__{
          cut_value: number(),
          source_side_size: non_neg_integer(),
          sink_side_size: non_neg_integer(),
          source_side: MapSet.t(Yog.node_id()) | nil,
          sink_side: MapSet.t(Yog.node_id()) | nil,
          algorithm: atom()
        }

  @doc """
  Creates a new min cut result.

  ## Examples

      iex> Yog.Flow.MinCutResult.new(10, 3, 4)
      %Yog.Flow.MinCutResult{
        cut_value: 10,
        source_side_size: 3,
        sink_side_size: 4,
        algorithm: :stoer_wagner
      }
  """
  @spec new(number(), non_neg_integer(), non_neg_integer()) :: t()
  def new(cut_value, source_side_size, sink_side_size) do
    new(cut_value, source_side_size, sink_side_size, nil, nil)
  end

  @doc """
  Creates a new min cut result with explicit partitions.
  """
  @spec new(
          number(),
          non_neg_integer(),
          non_neg_integer(),
          MapSet.t(Yog.node_id()) | nil,
          MapSet.t(Yog.node_id()) | nil
        ) :: t()
  def new(cut_value, source_side_size, sink_side_size, source_side, sink_side) do
    %__MODULE__{
      cut_value: cut_value,
      source_side_size: source_side_size,
      sink_side_size: sink_side_size,
      source_side: source_side,
      sink_side: sink_side
    }
  end

  @doc """
  Returns the total number of nodes in the graph.

  ## Examples

      iex> result = Yog.Flow.MinCutResult.new(10, 3, 4)
      iex> Yog.Flow.MinCutResult.total_nodes(result)
      7
  """
  @spec total_nodes(t()) :: non_neg_integer()
  def total_nodes(%__MODULE__{source_side_size: s, sink_side_size: t}), do: s + t

  @doc """
  Computes the product of partition sizes.

  ## Examples

      iex> result = Yog.Flow.MinCutResult.new(10, 3, 4)
      iex> Yog.Flow.MinCutResult.partition_product(result)
      12
  """
  @spec partition_product(t()) :: non_neg_integer()
  def partition_product(%__MODULE__{source_side_size: s, sink_side_size: t}), do: s * t
end
