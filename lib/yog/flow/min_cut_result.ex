defmodule Yog.Flow.MinCutResult do
  @moduledoc """
  Result of minimum cut computation.

  A cut partitions the nodes into two sets: the source side and the sink side.
  The cut value equals the total weight of edges crossing between the sets.

  ## Fields

  - `cut_value` - Total weight of the minimum cut
  - `source_side_size` - Number of nodes in the source partition
  - `sink_side_size` - Number of nodes in the sink partition
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

  The previous version of this struct stored full `MapSet`s of node IDs.
  If you need the actual node partitions, use `global_min_cut/2` with the
  `track_partitions: true` option (not yet implemented).
  """

  @enforce_keys [:cut_value, :source_side_size, :sink_side_size]
  defstruct [
    :cut_value,
    :source_side_size,
    :sink_side_size,
    algorithm: :stoer_wagner
  ]

  @type t :: %__MODULE__{
          cut_value: number(),
          source_side_size: non_neg_integer(),
          sink_side_size: non_neg_integer(),
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
    %__MODULE__{
      cut_value: cut_value,
      source_side_size: source_side_size,
      sink_side_size: sink_side_size
    }
  end

  @doc """
  Creates a new min cut result from MapSet partitions (backward compatibility).

  ## Deprecated

  This function is kept for backward compatibility with code that tracks
  full node partitions. For new code, use `new/3` with partition sizes.

  ## Examples

      iex> source = MapSet.new([1, 2, 3])
      iex> sink = MapSet.new([4, 5])
      iex> Yog.Flow.MinCutResult.new(source, sink)
      %Yog.Flow.MinCutResult{
        cut_value: nil,
        source_side_size: 3,
        sink_side_size: 2,
        algorithm: :unknown
      }
  """
  @spec new(MapSet.t(), MapSet.t()) :: t()
  def new(source_side, sink_side) do
    %__MODULE__{
      cut_value: nil,
      source_side_size: MapSet.size(source_side),
      sink_side_size: MapSet.size(sink_side),
      algorithm: :unknown
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
  def total_nodes(%__MODULE__{source_side_size: s, sink_side_size: t}) do
    s + t
  end

  @doc """
  Computes the product of partition sizes.

  This is commonly needed for Advent of Code problems where the answer
  is the product of the two partition sizes.

  ## Examples

      iex> result = Yog.Flow.MinCutResult.new(10, 3, 4)
      iex> Yog.Flow.MinCutResult.partition_product(result)
      12
  """
  @spec partition_product(t()) :: non_neg_integer()
  def partition_product(%__MODULE__{source_side_size: s, sink_side_size: t}) do
    s * t
  end

  @doc """
  Compute the cut value from a graph and the partition.

  This function is kept for backward compatibility but requires
  the actual node sets to compute the value. For new code, use
  the `cut_value` field directly.

  ## Deprecated

  The cut value is now computed during the algorithm and stored
  in the `cut_value` field. Use that instead.
  """
  @deprecated "Use the cut_value field directly"
  @spec compute_cut_value(t(), Yog.graph()) :: number()
  def compute_cut_value(%__MODULE__{cut_value: cv}, _graph) when not is_nil(cv) do
    cv
  end

  def compute_cut_value(%__MODULE__{}, _graph) do
    # Fallback when cut_value is nil - can't compute without node sets
    0
  end

  # Backward compatibility aliases
  @deprecated "Use source_side_size/1 instead"
  def source_side(%__MODULE__{source_side_size: s}), do: s

  @deprecated "Use sink_side_size/1 instead"
  def sink_side(%__MODULE__{sink_side_size: s}), do: s
end
