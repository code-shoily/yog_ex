defmodule Yog.Flow.MaxFlow do
  @moduledoc """
  Maximum flow algorithms and min-cut extraction for network flow problems.

  This module solves the [maximum flow problem](https://en.wikipedia.org/wiki/Maximum_flow_problem):
  given a flow network with capacities on edges, find the maximum flow from a source
  node to a sink node. By the [max-flow min-cut theorem](https://en.wikipedia.org/wiki/Max-flow_min-cut_theorem),
  this equals the capacity of the minimum cut separating source from sink.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Edmonds-Karp](https://en.wikipedia.org/wiki/Edmonds%E2%80%93Karp_algorithm) | `edmonds_karp/8` | O(VE²) | General networks, guaranteed polynomial time |

  ## Key Concepts

  - **Flow Network**: Directed graph where edges have capacities (max flow allowed)
  - **Source**: Node where flow originates (no incoming flow in net balance)
  - **Sink**: Node where flow terminates (no outgoing flow in net balance)
  - **Residual Graph**: Shows remaining capacity after current flow assignment
  - **Augmenting Path**: Path from source to sink with available capacity
  - **Minimum Cut**: Partition separating source from sink with minimum total capacity

  ## Use Cases

  - **Network routing**: Maximize data throughput in communication networks
  - **Transportation**: Optimize goods flow through logistics networks
  - **Bipartite matching**: Convert to flow problem for max cardinality matching
  - **Image segmentation**: Min-cut/max-flow for foreground/background separation
  - **Project selection**: Maximize profit with prerequisite constraints

  ## Example

      graph =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = Yog.Flow.MaxFlow.edmonds_karp_int(graph, 1, 4)
      # => %{max_flow: 15, residual_graph: ..., source: 1, sink: 4}

  ## References

  - [Wikipedia: Maximum Flow Problem](https://en.wikipedia.org/wiki/Maximum_flow_problem)
  - [Wikipedia: Edmonds-Karp Algorithm](https://en.wikipedia.org/wiki/Edmonds%E2%80%93Karp_algorithm)
  - [Wikipedia: Max-Flow Min-Cut Theorem](https://en.wikipedia.org/wiki/Max-flow_min-cut_theorem)
  """

  @typedoc """
  Result of a max flow computation.

  Contains both the maximum flow value and information needed to extract
  the minimum cut.
  """
  @type max_flow_result(e) :: %{
          max_flow: e,
          residual_graph: Yog.graph(),
          source: Yog.node_id(),
          sink: Yog.node_id()
        }

  @typedoc """
  Represents a minimum cut in the network.

  A cut partitions the nodes into two sets: those reachable from the source
  in the residual graph (source_side) and the rest (sink_side).
  The capacity of the cut equals the max flow by the max-flow min-cut theorem.
  """
  @type min_cut :: %{
          source_side: MapSet.t(Yog.node_id()),
          sink_side: MapSet.t(Yog.node_id())
        }

  @doc """
  Finds the maximum flow using the Edmonds-Karp algorithm with custom numeric type.

  Edmonds-Karp is a specific implementation of the Ford-Fulkerson method
  that uses BFS to find the shortest augmenting path. This guarantees
  O(VE²) time complexity.

  ## Parameters

  - `graph` - The flow network with edge capacities
  - `source` - Source node ID where flow originates
  - `sink` - Sink node ID where flow terminates
  - `zero` - Zero value for the capacity type
  - `add` - Addition function for capacities
  - `subtract` - Subtraction function for capacities
  - `compare` - Comparison function for capacities
  - `min` - Minimum function for capacities

  ## Examples

  Simple example with bottleneck:

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MaxFlow.edmonds_karp_int(graph, 1, 3)
      iex> result.max_flow
      5
  """
  @spec edmonds_karp(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> any()),
          (any(), any() -> boolean()),
          (any(), any() -> any())
        ) :: max_flow_result(any())
  def edmonds_karp(graph, source, sink, zero, add, subtract, compare, min) do
    result =
      :yog@flow@max_flow.edmonds_karp(
        graph,
        source,
        sink,
        zero,
        add,
        subtract,
        compare,
        min
      )

    wrap_max_flow_result(result)
  end

  @doc """
  Finds the maximum flow using Edmonds-Karp with integer capacities.

  This is a simplified version that uses integer arithmetic.

  ## Examples

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MaxFlow.edmonds_karp_int(graph, 1, 3)
      iex> result.max_flow
      5

  A more complex example with multiple paths:

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "source")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_node(4, "sink")
      ...>   |> Yog.add_edges([
      ...>     {1, 2, 10},
      ...>     {1, 3, 5},
      ...>     {2, 3, 15},
      ...>     {2, 4, 10},
      ...>     {3, 4, 10}
      ...>   ])
      iex> result = Yog.Flow.MaxFlow.edmonds_karp_int(graph, 1, 4)
      iex> result.max_flow
      15
  """
  @spec edmonds_karp_int(Yog.graph(), Yog.node_id(), Yog.node_id()) ::
          max_flow_result(integer())
  def edmonds_karp_int(graph, source, sink) do
    result = :yog@flow@max_flow.edmonds_karp_int(graph, source, sink)
    wrap_max_flow_result(result)
  end

  @doc """
  Extracts the minimum cut from a max flow result.

  Given a max flow result, this function finds the minimum cut by identifying
  all nodes reachable from the source in the residual graph.

  Returns a map with `source_side` (nodes reachable from source) and
  `sink_side` (all other nodes).

  ## Examples

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MaxFlow.edmonds_karp_int(graph, 1, 3)
      iex> cut = Yog.Flow.MaxFlow.extract_min_cut(result)
      iex> MapSet.member?(cut.source_side, 1)
      true
      iex> MapSet.member?(cut.sink_side, 3)
      true
  """
  @spec extract_min_cut(max_flow_result(any())) :: min_cut()
  def extract_min_cut(result) do
    min_cut(result, 0, fn a, b -> a <= b end)
  end

  @doc """
  Extracts the minimum cut from a max flow result with custom numeric type.

  This version allows you to specify the zero element and comparison function
  for custom numeric types.

  ## Parameters

  - `result` - The max flow result from `edmonds_karp/8`
  - `zero` - Zero value for the capacity type
  - `compare` - Comparison function for capacities (returns true if a <= b)

  ## Examples

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MaxFlow.edmonds_karp(
      ...>   graph, 1, 3, 0, &(&1 + &2), &(&1 - &2), fn a, b -> a <= b end, &min/2
      ...> )
      iex> cut = Yog.Flow.MaxFlow.min_cut(result, 0, fn a, b -> a <= b end)
      iex> MapSet.member?(cut.source_side, 1)
      true
  """
  @spec min_cut(max_flow_result(any()), any(), (any(), any() -> boolean())) :: min_cut()
  def min_cut(
        %{max_flow: max_flow, residual_graph: residual, source: source, sink: sink},
        zero,
        compare
      ) do
    gleam_result = {:max_flow_result, max_flow, residual, source, sink}
    # Convert Elixir compare function to Gleam-style compare (returns :gt/:eq/:lt)
    gleam_compare = fn a, b ->
      cond do
        compare.(a, b) and compare.(b, a) -> :eq
        compare.(a, b) -> :lt
        true -> :gt
      end
    end

    result = :yog@flow@max_flow.min_cut(gleam_result, zero, gleam_compare)
    wrap_min_cut(result)
  end

  # Private helper to wrap Gleam result into Elixir map
  defp wrap_max_flow_result({:max_flow_result, max_flow, residual, source, sink}) do
    %{
      max_flow: max_flow,
      residual_graph: residual,
      source: source,
      sink: sink
    }
  end

  # Private helper to wrap Gleam min cut into Elixir map
  defp wrap_min_cut({:min_cut, source_set, sink_set}) do
    %{
      source_side: gleam_set_to_mapset(source_set),
      sink_side: gleam_set_to_mapset(sink_set)
    }
  end

  # Convert Gleam set to Elixir MapSet
  defp gleam_set_to_mapset(gleam_set) do
    gleam_set
    |> :gleam@set.to_list()
    |> MapSet.new()
  end
end
