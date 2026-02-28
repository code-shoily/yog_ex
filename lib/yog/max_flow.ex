defmodule Yog.MaxFlow do
  @moduledoc """
  Algorithms for calculating maximum flow in a network.
  """

  @type flow_result :: %{
          max_flow: integer(),
          bottleneck_edges: [{Yog.node_id(), Yog.node_id()}]
        }

  @doc """
  Finds the maximum flow from a source to a sink using the Edmonds-Karp algorithm.

  Requires options: `:in` (graph), `:from`, `:to`, `:zero`, `:add`, `:subtract`,
  `:compare`, `:min`. Works for both directed and undirected graphs.
  """
  @spec edmonds_karp(keyword()) :: %{
          max_flow: term(),
          residual_graph: Yog.graph(),
          source: term(),
          sink: term()
        }
  def edmonds_karp(opts) do
    graph = Keyword.fetch!(opts, :in)
    source = Keyword.fetch!(opts, :from)
    sink = Keyword.fetch!(opts, :to)
    zero = Keyword.fetch!(opts, :zero)
    add = Keyword.fetch!(opts, :add)
    subtract = Keyword.fetch!(opts, :subtract)
    compare = Keyword.fetch!(opts, :compare)
    min_fn = Keyword.fetch!(opts, :min)

    {:max_flow_result, max_flow, residual, src, snk} =
      :yog@max_flow.edmonds_karp(graph, source, sink, zero, add, subtract, compare, min_fn)

    %{max_flow: max_flow, residual_graph: residual, source: src, sink: snk}
  end

  @doc """
  Finds the minimum s-t cut from a MaxFlowResult.

  Requires options: `:result` (from `edmonds_karp`), `:zero`, `:compare`.
  Returns `%{source_side: MapSet.t(), sink_side: MapSet.t()}`
  """
  @spec min_cut(keyword()) :: %{source_side: MapSet.t(), sink_side: MapSet.t()}
  def min_cut(opts) do
    result_map = Keyword.fetch!(opts, :result)
    zero = Keyword.fetch!(opts, :zero)
    compare = Keyword.fetch!(opts, :compare)

    gleam_result =
      {:max_flow_result, result_map.max_flow, result_map.residual_graph, result_map.source,
       result_map.sink}

    {:min_cut, source_side, sink_side} = :yog@max_flow.min_cut(gleam_result, zero, compare)

    %{
      source_side: source_side |> :gleam@set.to_list() |> MapSet.new(),
      sink_side: sink_side |> :gleam@set.to_list() |> MapSet.new()
    }
  end
end
