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

      result = Yog.Flow.MaxFlow.calculate(graph, 1, 4)
      # => %MaxFlowResult{max_flow: 15, residual_graph: ..., source: 1, sink: 4}

  ## References

  - [Wikipedia: Maximum Flow Problem](https://en.wikipedia.org/wiki/Maximum_flow_problem)
  - [Wikipedia: Edmonds-Karp Algorithm](https://en.wikipedia.org/wiki/Edmonds%E2%80%93Karp_algorithm)
  - [Wikipedia: Max-Flow Min-Cut Theorem](https://en.wikipedia.org/wiki/Max-flow_min-cut_theorem)
  """

  alias Yog.Flow.MaxFlowResult
  alias Yog.Flow.MinCutResult
  alias Yog.Model

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
  Calculates the maximum flow from source to sink using Edmonds-Karp with standard integers.

  This is a convenience wrapper around `edmonds_karp/8` that uses default
  integer arithmetic operations.

  ## Parameters

  - `graph` - The flow network with edge capacities
  - `source` - Source node ID where flow originates
  - `sink` - Sink node ID where flow terminates

  ## Examples

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MaxFlow.calculate(graph, 1, 3)
      iex> result.max_flow
      5
  """
  @spec calculate(Yog.graph(), Yog.node_id(), Yog.node_id()) :: max_flow_result()
  def calculate(graph, source, sink) do
    edmonds_karp(graph, source, sink)
  end

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
    # Edge case: source equals sink - return 0 flow immediately
    if source == sink do
      # Build a copy of the original graph as the residual
      return_graph =
        List.foldl(Map.keys(graph.nodes), Model.new(graph.kind), fn node, acc ->
          Model.add_node(acc, node, Map.get(graph.nodes, node))
        end)

      return_graph =
        List.foldl(Map.to_list(graph.out_edges), return_graph, fn {src, inner}, acc ->
          List.foldl(Map.to_list(inner), acc, fn {dst, weight}, inner_acc ->
            case Model.add_edge(inner_acc, src, dst, weight) do
              {:ok, g} -> g
              {:error, _} -> inner_acc
            end
          end)
        end)

      MaxFlowResult.new(zero, return_graph, source, sink)
    else
      residual = build_residual_graph(graph, zero)

      {max_flow, final_residual} =
        do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn, zero)

      final_residual_graph = residual_to_graph(graph, final_residual)
      MaxFlowResult.new(max_flow, final_residual_graph, source, sink)
    end
  end

  # Extract all edges and their capacities from the graph
  # Uses direct out_edges access for performance
  defp build_residual_graph(graph, _zero) do
    nodes = Map.keys(graph.nodes)
    out_edges = graph.out_edges

    List.foldl(nodes, %{}, fn from, acc ->
      case Map.fetch(out_edges, from) do
        {:ok, successors} when map_size(successors) > 0 ->
          node_edges =
            List.foldl(Map.to_list(successors), %{}, fn {to, capacity}, acc2 ->
              Map.put(acc2, to, capacity)
            end)

          if map_size(node_edges) > 0 do
            Map.put(acc, from, node_edges)
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  # Convert internal residual map back to a Yog.Graph structure
  defp residual_to_graph(original_graph, residual_map) do
    nodes = Map.keys(original_graph.nodes)
    original_nodes = original_graph.nodes

    graph =
      List.foldl(nodes, Model.new(:directed), fn node, acc ->
        data = Map.get(original_nodes, node)
        Model.add_node(acc, node, data)
      end)

    List.foldl(Map.to_list(residual_map), graph, fn {u, edges}, acc ->
      List.foldl(Map.to_list(edges), acc, fn {v, cap}, inner_acc ->
        if cap != 0 do
          case Model.add_edge(inner_acc, u, v, cap) do
            {:ok, new_graph} -> new_graph
            {:error, _} -> inner_acc
          end
        else
          inner_acc
        end
      end)
    end)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn, acc_flow) do
    case find_augmenting_path(residual, source, sink, zero, compare, min_fn) do
      nil ->
        {acc_flow, residual}

      {path, bottleneck} ->
        new_residual =
          List.foldl(path, residual, fn {from, to}, acc ->
            # Update forward edge
            from_edges = Map.get(acc, from, %{}) |> Map.put_new(to, zero)
            old_cap = Map.fetch!(from_edges, to)
            new_cap = subtract.(old_cap, bottleneck)

            acc =
              if compare.(new_cap, zero) == :eq do
                new_from_edges = Map.delete(from_edges, to)

                if map_size(new_from_edges) == 0 do
                  Map.delete(acc, from)
                else
                  Map.put(acc, from, new_from_edges)
                end
              else
                Map.put(acc, from, Map.put(from_edges, to, new_cap))
              end

            # Update backward edge
            to_edges = Map.get(acc, to, %{}) |> Map.put_new(from, zero)
            old_back = Map.fetch!(to_edges, from)
            new_back = add.(old_back, bottleneck)
            Map.put(acc, to, Map.put(to_edges, from, new_back))
          end)

        do_edmonds_karp(
          new_residual,
          source,
          sink,
          zero,
          add,
          subtract,
          compare,
          min_fn,
          add.(acc_flow, bottleneck)
        )
    end
  end

  # Find augmenting path using BFS with bottleneck tracking
  defp find_augmenting_path(residual, source, sink, zero, compare, min_fn) do
    queue = :queue.in(source, :queue.new())

    state = %{
      parents: %{source => nil},
      bottlenecks: %{source => :infinity},
      visited: MapSet.new([source])
    }

    do_bfs(queue, residual, sink, zero, compare, min_fn, state)
  end

  defp do_bfs(queue, residual, sink, zero, compare, min_fn, state) do
    case :queue.out(queue) do
      {:empty, _} ->
        nil

      {{:value, current}, rest_q} ->
        if current == sink do
          path_edges = reconstruct_path_edges(state.parents, sink, [])
          bottleneck = Map.fetch!(state.bottlenecks, sink)
          {path_edges, bottleneck}
        else
          neighbors = Map.get(residual, current, %{})
          current_bot = Map.get(state.bottlenecks, current)

          {next_q, next_state} =
            List.foldl(Map.to_list(neighbors), {rest_q, state}, fn {to, cap},
                                                                   {q_acc, s_acc} = acc ->
              if MapSet.member?(s_acc.visited, to) or compare.(cap, zero) == :eq do
                acc
              else
                path_bottleneck =
                  if current_bot == :infinity,
                    do: cap,
                    else: min_fn.(current_bot, cap)

                new_q = :queue.in(to, q_acc)

                new_s = %{
                  s_acc
                  | parents: Map.put(s_acc.parents, to, current),
                    bottlenecks: Map.put(s_acc.bottlenecks, to, path_bottleneck),
                    visited: MapSet.put(s_acc.visited, to)
                }

                {new_q, new_s}
              end
            end)

          do_bfs(next_q, residual, sink, zero, compare, min_fn, next_state)
        end
    end
  end

  defp reconstruct_path_edges(parents, sink, acc) do
    case Map.fetch!(parents, sink) do
      nil -> acc
      parent -> reconstruct_path_edges(parents, parent, [{parent, sink} | acc])
    end
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
      iex> cut.cut_value
      5
      iex> cut.source_side_size + cut.sink_side_size
      3
  """
  @spec extract_min_cut(max_flow_result()) :: min_cut()
  def extract_min_cut(%MaxFlowResult{
        residual_graph: residual,
        source: source,
        max_flow: max_flow
      }) do
    nodes = Map.keys(residual.nodes) |> MapSet.new()
    source_side = bfs_reachable_with_compare(residual, source, nodes, 0, &Yog.Utils.compare/2)
    sink_side = MapSet.difference(nodes, source_side)

    %Yog.Flow.MinCutResult{
      cut_value: max_flow,
      source_side_size: MapSet.size(source_side),
      sink_side_size: MapSet.size(sink_side),
      algorithm: :edmonds_karp
    }
  end

  @doc """
  Extracts the minimum cut from a max flow result with custom numeric type.

  This version allows you to specify the zero element and comparison function
  for custom numeric types.

  ## Parameters

  - `result` - The max flow result from `edmonds_karp/8`
  - `zero` - Zero value for the capacity type
  - `compare` - Comparison function for capacities (returns `:lt`, `:eq`, or `:gt`)

  ## Examples

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MaxFlow.edmonds_karp(graph, 1, 3)
      iex> cut = Yog.Flow.MaxFlow.min_cut(result)
      iex> cut.cut_value
      5
  """
  @spec min_cut(max_flow_result(), any(), (any(), any() -> :lt | :eq | :gt)) :: min_cut()
  def min_cut(
        %MaxFlowResult{residual_graph: residual, source: source, max_flow: max_flow},
        zero \\ 0,
        compare \\ &Yog.Utils.compare/2
      ) do
    nodes = Map.keys(residual.nodes) |> MapSet.new()
    source_side = bfs_reachable_with_compare(residual, source, nodes, zero, compare)
    sink_side = MapSet.difference(nodes, source_side)

    %Yog.Flow.MinCutResult{
      cut_value: max_flow,
      source_side_size: MapSet.size(source_side),
      sink_side_size: MapSet.size(sink_side),
      algorithm: :edmonds_karp
    }
  end

  # BFS to find all nodes reachable from source in residual graph
  # Uses direct out_edges access for performance
  defp bfs_reachable_with_compare(residual, source, _all_nodes, zero, compare) do
    queue = :queue.in(source, :queue.new())
    visited = MapSet.new([source])
    out_edges = residual.out_edges

    do_reachable_bfs(queue, out_edges, zero, compare, visited)
  end

  defp do_reachable_bfs(queue, out_edges, zero, compare, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, current}, rest_q} ->
        neighbors =
          case Map.fetch(out_edges, current) do
            {:ok, edges} ->
              edges
              |> Map.to_list()
              |> Enum.filter(fn {_to, cap} -> compare.(cap, zero) != :eq end)
              |> Enum.map(fn {to, _} -> to end)

            :error ->
              []
          end

        {next_q, next_visited} =
          List.foldl(neighbors, {rest_q, visited}, fn neighbor, {q_acc, visited_acc} ->
            if MapSet.member?(visited_acc, neighbor) do
              {q_acc, visited_acc}
            else
              {:queue.in(neighbor, q_acc), MapSet.put(visited_acc, neighbor)}
            end
          end)

        do_reachable_bfs(next_q, out_edges, zero, compare, next_visited)
    end
  end
end
