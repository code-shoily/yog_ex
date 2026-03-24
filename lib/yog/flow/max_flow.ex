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
      # => %MaxFlowResult{max_flow: 15, residual_graph: ..., source: 1, sink: 4}

  ## References

  - [Wikipedia: Maximum Flow Problem](https://en.wikipedia.org/wiki/Maximum_flow_problem)
  - [Wikipedia: Edmonds-Karp Algorithm](https://en.wikipedia.org/wiki/Edmonds%E2%80%93Karp_algorithm)
  - [Wikipedia: Max-Flow Min-Cut Theorem](https://en.wikipedia.org/wiki/Max-flow_min-cut_theorem)
  """

  alias Yog.Model
  alias Yog.Flow.MaxFlowResult
  alias Yog.Flow.MinCutResult

  @typedoc """
  Result of a max flow computation.

  Contains both the maximum flow value and information needed to extract
  the minimum cut.
  """
  @type max_flow_result :: MaxFlowResult.t()

  @typedoc """
  Represents a minimum cut in the network.

  A cut partitions the nodes into two sets: those reachable from the source
  in the residual graph (source_side) and the rest (sink_side).
  The capacity of the cut equals the max flow by the max-flow min-cut theorem.
  """
  @type min_cut :: MinCutResult.t()

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
        ) :: max_flow_result()
  def edmonds_karp(graph, source, sink, zero, add, subtract, compare, min_fn) do
    # Build initial residual graph with capacities
    residual = build_residual_graph(graph, zero)

    # Run Edmonds-Karp
    {max_flow, final_residual} =
      do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn)

    MaxFlowResult.new(max_flow, final_residual, source, sink)
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
          max_flow_result()
  def edmonds_karp_int(graph, source, sink) do
    edmonds_karp(graph, source, sink, 0, &+/2, &-/2, fn a, b -> a <= b end, &min/2)
  end

  # Build residual graph structure: {from, to} -> capacity
  defp build_residual_graph(graph, _zero) do
    # Extract all edges and their capacities from the graph
    nodes = Model.all_nodes(graph)

    Enum.reduce(nodes, %{}, fn from, acc ->
      successors = Model.successors(graph, from)

      Enum.reduce(successors, acc, fn {to, capacity}, acc2 ->
        key = {from, to}
        Map.put(acc2, key, capacity)
      end)
    end)
  end

  # Main Edmonds-Karp loop
  defp do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn) do
    case find_augmenting_path(residual, source, sink, zero, compare) do
      nil ->
        {zero, residual}

      {path, bottleneck} ->
        # Update residual capacities along the path
        new_residual =
          Enum.reduce(path, residual, fn {from, to}, acc ->
            # Decrease forward capacity
            old_cap = Map.get(acc, {from, to}, zero)
            new_cap = subtract.(old_cap, bottleneck)

            acc =
              if compare.(new_cap, zero) and compare.(zero, new_cap) do
                Map.delete(acc, {from, to})
              else
                Map.put(acc, {from, to}, new_cap)
              end

            # Increase backward capacity
            old_back = Map.get(acc, {to, from}, zero)
            new_back = add.(old_back, bottleneck)
            Map.put(acc, {to, from}, new_back)
          end)

        {flow_rest, final_residual} =
          do_edmonds_karp(new_residual, source, sink, zero, add, subtract, compare, min_fn)

        {add.(bottleneck, flow_rest), final_residual}
    end
  end

  # Find augmenting path using BFS
  defp find_augmenting_path(residual, source, sink, zero, compare) do
    # BFS to find shortest path with available capacity
    queue = :queue.in({source, []}, :queue.new())
    visited = MapSet.new([source])

    do_bfs(residual, queue, visited, sink, zero, compare)
  end

  defp do_bfs(residual, queue, visited, sink, zero, compare) do
    case :queue.out(queue) do
      {{:value, {current, path}}, rest} ->
        if current == sink do
          # Found path - compute bottleneck
          bottleneck = compute_bottleneck(residual, path, zero, compare)
          {path, bottleneck}
        else
          # Explore neighbors with remaining capacity
          {new_queue, new_visited} =
            residual
            |> Enum.filter(fn {{from, _}, cap} ->
              from == current and (compare.(zero, cap) and not compare.(cap, zero))
            end)
            |> Enum.reduce({rest, visited}, fn {{from, to}, _cap}, {q, v} ->
              if MapSet.member?(v, to) do
                {q, v}
              else
                new_q = :queue.in({to, path ++ [{from, to}]}, q)
                new_v = MapSet.put(v, to)
                {new_q, new_v}
              end
            end)

          do_bfs(residual, new_queue, new_visited, sink, zero, compare)
        end

      {:empty, _} ->
        nil
    end
  end

  # Compute bottleneck (minimum capacity along path)
  defp compute_bottleneck(residual, path, zero, compare) do
    Enum.reduce(path, nil, fn edge, acc ->
      cap = Map.get(residual, edge, zero)

      case acc do
        nil -> cap
        current -> if compare.(cap, current), do: cap, else: current
      end
    end)
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
  @spec extract_min_cut(max_flow_result()) :: min_cut()
  def extract_min_cut(%MaxFlowResult{residual_graph: residual, source: source}) do
    # Find all nodes reachable from source in residual graph
    nodes = get_all_nodes_from_residual(residual)
    source_side = bfs_reachable(residual, source, nodes)
    sink_side = MapSet.difference(nodes, source_side)

    MinCutResult.new(source_side, sink_side)
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
  @spec min_cut(max_flow_result(), any(), (any(), any() -> boolean())) :: min_cut()
  def min_cut(%MaxFlowResult{residual_graph: residual, source: source}, zero, compare) do
    nodes = get_all_nodes_from_residual(residual)
    source_side = bfs_reachable_with_compare(residual, source, nodes, zero, compare)
    sink_side = MapSet.difference(nodes, source_side)

    MinCutResult.new(source_side, sink_side)
  end

  # Get all nodes from residual graph
  defp get_all_nodes_from_residual(residual) do
    residual
    |> Map.keys()
    |> Enum.flat_map(fn {from, to} -> [from, to] end)
    |> Enum.uniq()
    |> MapSet.new()
  end

  # BFS to find reachable nodes from source
  defp bfs_reachable(residual, source, all_nodes) do
    bfs_reachable_with_compare(residual, source, all_nodes, 0, fn a, b -> a <= b end)
  end

  defp bfs_reachable_with_compare(residual, source, _all_nodes, zero, compare) do
    do_bfs_reachable(residual, [source], MapSet.new([source]), zero, compare)
  end

  defp do_bfs_reachable(_residual, [], visited, _zero, _compare), do: visited

  defp do_bfs_reachable(residual, [current | rest], visited, zero, compare) do
    # Find all neighbors with positive residual capacity
    neighbors =
      residual
      |> Enum.filter(fn {{from, _}, cap} ->
        from == current and not (compare.(cap, zero) and compare.(zero, cap))
      end)
      |> Enum.map(fn {{_, to}, _} -> to end)
      |> Enum.filter(fn n -> not MapSet.member?(visited, n) end)

    new_visited = Enum.reduce(neighbors, visited, fn n, acc -> MapSet.put(acc, n) end)
    do_bfs_reachable(residual, rest ++ neighbors, new_visited, zero, compare)
  end
end
