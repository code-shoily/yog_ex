defmodule Yog.Flow.MaxFlowResult do
  @moduledoc """
  Result of maximum flow computation (Edmonds-Karp, etc.).

  Contains the maximum flow value and the residual graph, which can be used
  to extract the minimum cut.

  ## Fields

  - `max_flow` - The maximum flow value from source to sink
  - `residual_graph` - The residual graph after flow computation
  - `source` - The source node ID
  - `sink` - The sink node ID
  - `algorithm` - Name of the algorithm used (optional)
  - `metadata` - Optional metadata (iterations, time, etc.)

  ## Examples

      iex> result = %Yog.Flow.MaxFlowResult{
      ...>   max_flow: 15,
      ...>   residual_graph: graph,
      ...>   source: 1,
      ...>   sink: 4,
      ...>   algorithm: :edmonds_karp
      ...> }
      iex> result.max_flow
      15
  """

  @enforce_keys [:max_flow, :residual_graph, :source, :sink]
  defstruct [
    :max_flow,
    :residual_graph,
    :source,
    :sink,
    algorithm: :unknown,
    metadata: %{},
    zero: 0,
    compare: &Yog.Utils.compare/2
  ]

  @type t :: %__MODULE__{
          max_flow: number(),
          residual_graph: Yog.graph(),
          source: Yog.Model.node_id(),
          sink: Yog.Model.node_id(),
          algorithm: atom(),
          metadata: map(),
          zero: any(),
          compare: (any(), any() -> :lt | :eq | :gt)
        }

  @doc """
  Creates a new max flow result.
  """
  @spec new(number(), Yog.graph(), Yog.Model.node_id(), Yog.Model.node_id()) :: t()
  def new(max_flow, residual_graph, source, sink) do
    %__MODULE__{
      max_flow: max_flow,
      residual_graph: residual_graph,
      source: source,
      sink: sink
    }
  end

  @doc """
  Creates a new max flow result with algorithm name.
  """
  @spec new(number(), Yog.graph(), Yog.Model.node_id(), Yog.Model.node_id(), atom()) :: t()
  def new(max_flow, residual_graph, source, sink, algorithm) do
    %__MODULE__{
      max_flow: max_flow,
      residual_graph: residual_graph,
      source: source,
      sink: sink,
      algorithm: algorithm
    }
  end

  @doc """
  Creates a new max flow result with algorithm name, zero element, and comparison function.
  """
  @spec new(
          number(),
          Yog.graph(),
          Yog.Model.node_id(),
          Yog.Model.node_id(),
          atom(),
          any(),
          (any(), any() -> :lt | :eq | :gt)
        ) :: t()
  def new(max_flow, residual_graph, source, sink, algorithm, zero, compare) do
    %__MODULE__{
      max_flow: max_flow,
      residual_graph: residual_graph,
      source: source,
      sink: sink,
      algorithm: algorithm,
      zero: zero,
      compare: compare
    }
  end

  @doc """
  Get flow value on a specific edge in the residual graph.
  """
  @spec residual_capacity(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: number()
  def residual_capacity(%__MODULE__{residual_graph: graph}, src, dst) do
    successors = Yog.Model.successors(graph, src)

    case Enum.find(successors, fn {id, _} -> id == dst end) do
      {_, capacity} -> capacity
      nil -> 0
    end
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{max_flow: mf, residual_graph: rg, source: s, sink: t} = map) do
    algorithm = Map.get(map, :algorithm, :unknown)
    metadata = Map.get(map, :metadata, %{})
    zero = Map.get(map, :zero, 0)
    compare = Map.get(map, :compare, &Yog.Utils.compare/2)

    %__MODULE__{
      max_flow: mf,
      residual_graph: rg,
      source: s,
      sink: t,
      algorithm: algorithm,
      metadata: metadata,
      zero: zero,
      compare: compare
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    %{
      max_flow: result.max_flow,
      residual_graph: result.residual_graph,
      source: result.source,
      sink: result.sink
    }
  end
end
