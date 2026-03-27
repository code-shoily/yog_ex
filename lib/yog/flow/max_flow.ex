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

  alias Yog.Flow.MaxFlowResult
  alias Yog.Flow.MinCutResult
  alias Yog.Model
  alias Yog.Traversal

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
      iex> result = Yog.Flow.MaxFlow.edmonds_karp(graph, 1, 3)
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
          (any(), any() -> :lt | :eq | :gt),
          (any(), any() -> any())
        ) :: max_flow_result()
  def edmonds_karp(
        graph,
        source,
        sink,
        zero \\ 0,
        add \\ &Kernel.+/2,
        subtract \\ &Kernel.-/2,
        compare \\ &Yog.Utils.compare/2,
        min_fn \\ &min/2
      ) do
    residual = build_residual_graph(graph, zero)

    {max_flow, final_residual} =
      do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn)

    final_residual_graph = residual_to_graph(graph, final_residual)
    MaxFlowResult.new(max_flow, final_residual_graph, source, sink)
  end

  # Extract all edges and their capacities from the graph
  defp build_residual_graph(graph, _zero) do
    nodes = Model.all_nodes(graph)

    Enum.reduce(nodes, %{}, fn from, acc ->
      successors = Model.successors(graph, from)

      Enum.reduce(successors, acc, fn {to, capacity}, acc2 ->
        key = {from, to}
        Map.put(acc2, key, capacity)
      end)
    end)
  end

  # Convert internal residual map back to a Yog.Graph structure
  defp residual_to_graph(original_graph, residual_map) do
    empty_graph =
      Model.all_nodes(original_graph)
      |> Enum.reduce(Yog.Graph.new(:directed), fn node, g ->
        Model.add_node(g, node, Map.get(original_graph.nodes, node))
      end)

    Enum.reduce(residual_map, empty_graph, fn {{u, v}, cap}, g ->
      case Model.add_edge(g, u, v, cap) do
        {:ok, new_g} -> new_g
        {:error, _} -> g
      end
    end)
  end

  # Edmonds-Karp loop
  defp do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn) do
    case find_augmenting_path(residual, source, sink, zero, compare) do
      nil ->
        {zero, residual}

      {path, bottleneck} ->
        new_residual =
          Enum.reduce(path, residual, fn {from, to}, acc ->
            old_cap = Map.get(acc, {from, to}, zero)
            new_cap = subtract.(old_cap, bottleneck)

            acc =
              if compare.(new_cap, zero) == :eq do
                Map.delete(acc, {from, to})
              else
                Map.put(acc, {from, to}, new_cap)
              end

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
    parents =
      Traversal.Implicit.implicit_fold(
        from: source,
        using: :breadth_first,
        successors_of: fn node ->
          residual
          |> Enum.filter(fn {{from, _}, cap} -> from == node and compare.(cap, zero) == :gt end)
          |> Enum.map(fn {{_, to}, _} -> to end)
        end,
        initial: %{},
        with: fn acc, node_id, meta ->
          new_acc = if meta.parent, do: Map.put(acc, node_id, meta.parent), else: acc

          if node_id == sink do
            {:halt, new_acc}
          else
            {:continue, new_acc}
          end
        end
      )

    if Map.has_key?(parents, sink) or source == sink do
      path_nodes = reconstruct_path_nodes(parents, sink, [])

      path_edges =
        path_nodes
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [u, v] -> {u, v} end)

      bottleneck = compute_bottleneck(residual, path_edges, zero, compare)
      {path_edges, bottleneck}
    else
      nil
    end
  end

  defp reconstruct_path_nodes(parents, node, acc) do
    case Map.get(parents, node) do
      nil -> [node | acc]
      parent -> reconstruct_path_nodes(parents, parent, [node | acc])
    end
  end

  # Compute bottleneck (minimum capacity along path)
  defp compute_bottleneck(residual, path, zero, compare) do
    Enum.reduce(path, nil, fn edge, acc ->
      cap = Map.get(residual, edge, zero)

      case acc do
        nil -> cap
        current -> if compare.(cap, current) == :lt, do: cap, else: current
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
      iex> result = Yog.Flow.MaxFlow.edmonds_karp(graph, 1, 3)
      iex> cut = Yog.Flow.MaxFlow.extract_min_cut(result)
      iex> MapSet.member?(cut.source_side, 1)
      true
      iex> MapSet.member?(cut.sink_side, 3)
      true
  """
  @spec extract_min_cut(max_flow_result()) :: min_cut()
  def extract_min_cut(%MaxFlowResult{residual_graph: residual, source: source}) do
    nodes = Model.all_nodes(residual) |> MapSet.new()
    source_side = bfs_reachable_with_compare(residual, source, nodes, 0, &Yog.Utils.compare/2)
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
  @spec min_cut(max_flow_result(), any(), (any(), any() -> :lt | :eq | :gt)) :: min_cut()
  def min_cut(
        %MaxFlowResult{residual_graph: residual, source: source},
        zero \\ 0,
        compare \\ &Yog.Utils.compare/2
      ) do
    nodes = Model.all_nodes(residual) |> MapSet.new()
    source_side = bfs_reachable_with_compare(residual, source, nodes, zero, compare)
    sink_side = MapSet.difference(nodes, source_side)

    MinCutResult.new(source_side, sink_side)
  end

  defp bfs_reachable_with_compare(residual, source, _all_nodes, zero, compare) do
    Traversal.Implicit.implicit_fold(
      from: source,
      using: :breadth_first,
      successors_of: fn node ->
        Model.successors(residual, node)
        |> Enum.filter(fn {_, cap} -> compare.(cap, zero) != :eq end)
        |> Enum.map(fn {to, _} -> to end)
      end,
      initial: MapSet.new(),
      with: fn acc, node_id, _meta -> {:continue, MapSet.put(acc, node_id)} end
    )
  end
end
