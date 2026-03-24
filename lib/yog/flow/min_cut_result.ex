defmodule Yog.Flow.MinCutResult do
  @moduledoc """
  Result of minimum cut computation.

  A cut partitions the nodes into two sets: the source side (reachable from source)
  and the sink side (the rest). The cut value equals the total capacity of edges
  crossing from source side to sink side.

  ## Fields

  - `source_side` - Set of nodes reachable from source in residual graph
  - `sink_side` - Set of nodes on the sink side of the cut
  - `cut_value` - Total capacity of the cut (optional, can be computed from max flow)
  - `cut_edges` - List of edges in the cut (optional)
  - `algorithm` - Name of the algorithm used (optional)
  - `metadata` - Optional metadata

  ## Examples

      iex> result = %Yog.Flow.MinCutResult{
      ...>   source_side: MapSet.new([1, 2]),
      ...>   sink_side: MapSet.new([3, 4]),
      ...>   cut_value: 15
      ...> }
      iex> MapSet.size(result.source_side)
      2
  """

  @enforce_keys [:source_side, :sink_side]
  defstruct [
    :source_side,
    :sink_side,
    cut_value: nil,
    cut_edges: [],
    algorithm: :unknown,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          source_side: MapSet.t(Yog.Model.node_id()),
          sink_side: MapSet.t(Yog.Model.node_id()),
          cut_value: number() | nil,
          cut_edges: [{Yog.Model.node_id(), Yog.Model.node_id()}],
          algorithm: atom(),
          metadata: map()
        }

  @doc """
  Creates a new min cut result.
  """
  @spec new(MapSet.t(Yog.Model.node_id()), MapSet.t(Yog.Model.node_id())) :: t()
  def new(source_side, sink_side) do
    %__MODULE__{
      source_side: source_side,
      sink_side: sink_side
    }
  end

  @doc """
  Creates a new min cut result with cut value.
  """
  @spec new(MapSet.t(Yog.Model.node_id()), MapSet.t(Yog.Model.node_id()), number()) :: t()
  def new(source_side, sink_side, cut_value) do
    %__MODULE__{
      source_side: source_side,
      sink_side: sink_side,
      cut_value: cut_value
    }
  end

  @doc """
  Check if a node is in the source partition.
  """
  @spec in_source?(t(), Yog.Model.node_id()) :: boolean()
  def in_source?(%__MODULE__{source_side: source}, node) do
    MapSet.member?(source, node)
  end

  @doc """
  Check if a node is in the sink partition.
  """
  @spec in_sink?(t(), Yog.Model.node_id()) :: boolean()
  def in_sink?(%__MODULE__{sink_side: sink}, node) do
    MapSet.member?(sink, node)
  end

  @doc """
  Compute the cut value from a graph and the partition.

  Sums the capacities of edges going from source side to sink side.
  """
  @spec compute_cut_value(t(), Yog.graph()) :: number()
  def compute_cut_value(%__MODULE__{source_side: source_side, sink_side: sink_side}, graph) do
    Enum.reduce(source_side, 0, fn src, acc ->
      edges_from_src = Yog.Model.successors(graph, src)

      Enum.reduce(edges_from_src, acc, fn {dst, weight}, inner_acc ->
        if MapSet.member?(sink_side, dst) do
          inner_acc + weight
        else
          inner_acc
        end
      end)
    end)
  end

  @doc """
  Extract the edges that cross the cut.

  Returns list of `{source_node, sink_node}` pairs.
  """
  @spec extract_cut_edges(t(), Yog.graph()) :: [{Yog.Model.node_id(), Yog.Model.node_id()}]
  def extract_cut_edges(%__MODULE__{source_side: source_side, sink_side: sink_side}, graph) do
    Enum.flat_map(source_side, fn src ->
      edges_from_src = Yog.Model.successors(graph, src)

      Enum.filter(edges_from_src, fn {dst, _weight} ->
        MapSet.member?(sink_side, dst)
      end)
      |> Enum.map(fn {dst, _weight} -> {src, dst} end)
    end)
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{source_side: ss, sink_side: ts} = map) do
    cut_value = Map.get(map, :cut_value)
    cut_edges = Map.get(map, :cut_edges, [])
    algorithm = Map.get(map, :algorithm, :unknown)
    metadata = Map.get(map, :metadata, %{})

    %__MODULE__{
      source_side: ss,
      sink_side: ts,
      cut_value: cut_value,
      cut_edges: cut_edges,
      algorithm: algorithm,
      metadata: metadata
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{source_side: ss, sink_side: ts}) do
    %{
      source_side: ss,
      sink_side: ts
    }
  end
end
