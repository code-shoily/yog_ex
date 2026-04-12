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
  | [Dinic](https://en.wikipedia.org/wiki/Dinic%27s_algorithm) | `dinic/8` | O(V²E) | Dense networks, unit capacities O(E√V) |

  ## Key Concepts

  - **Flow Network**: Directed graph where edges have capacities (max flow allowed)
  - **Source**: Node where flow originates (no incoming flow in net balance)
  - **Sink**: Node where flow terminates (no outgoing flow in net balance)
  - **Residual Graph**: Shows remaining capacity after current flow assignment
  - **Augmenting Path**: Path from source to sink with available capacity
  - **Minimum Cut**: Partition separating source from sink with minimum total capacity
  - **Level Graph**: BFS layering of nodes used by Dinic's algorithm

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

  ## Example: Maximum Flow

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    S [label="S"]; A [label="A"]; B [label="B"]; T [label="T"];

    S -> A [label="10", color="#6366f1", penwidth=2];
    S -> B [label="10", color="#6366f1", penwidth=2];
    A -> B [label="2", color="#6366f1", penwidth=2];
    A -> T [label="4", color="#6366f1", penwidth=2];
    B -> T [label="10", color="#6366f1", penwidth=2];
  }
  </div>

      iex> alias Yog.Flow.MaxFlow
      iex> graph = Yog.from_edges(:directed, [
      ...>   {"S", "A", 10}, {"S", "B", 10}, {"A", "B", 2},
      ...>   {"A", "T", 4}, {"B", "T", 10}
      ...> ])
      iex> result = MaxFlow.calculate(graph, "S", "T")
      iex> result.max_flow
      14

      result = Yog.Flow.MaxFlow.calculate(graph, 1, 4)
      # => %MaxFlowResult{max_flow: 15, residual_graph: ..., source: 1, sink: 4}

  ## Example: Dinic's Algorithm

  Dinic's algorithm builds a level graph via BFS and pushes blocking flows
  via DFS, making it efficient for dense networks.

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    S [label="S"]; A [label="A"]; B [label="B"]; C [label="C"]; T [label="T"];

    { rank=same; S; }
    { rank=same; A; B; }
    { rank=same; C; }
    { rank=same; T; }

    S -> A [label="10", color="#6366f1", penwidth=2];
    S -> B [label="5", color="#6366f1", penwidth=2];
    A -> C [label="8", color="#6366f1", penwidth=2];
    B -> C [label="3", color="#6366f1", penwidth=2];
    C -> T [label="7", color="#6366f1", penwidth=2];
  }
  </div>

      iex> graph = Yog.from_edges(:directed, [
      ...>   {"S", "A", 10}, {"S", "B", 5}, {"A", "C", 8},
      ...>   {"B", "C", 3}, {"C", "T", 7}
      ...> ])
      iex> result = Yog.Flow.MaxFlow.dinic(graph, "S", "T")
      iex> result.max_flow
      7

  ## References

  - [Wikipedia: Maximum Flow Problem](https://en.wikipedia.org/wiki/Maximum_flow_problem)
  - [Wikipedia: Edmonds-Karp Algorithm](https://en.wikipedia.org/wiki/Edmonds%E2%80%93Karp_algorithm)
  - [Wikipedia: Dinic's Algorithm](https://en.wikipedia.org/wiki/Dinic%27s_algorithm)
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

      MaxFlowResult.new(zero, return_graph, source, sink, :edmonds_karp, zero, compare)
    else
      residual = build_residual_graph(graph, zero)

      {max_flow, final_residual} =
        do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn, zero)

      final_residual_graph = residual_to_graph(graph, final_residual, zero, compare)

      MaxFlowResult.new(
        max_flow,
        final_residual_graph,
        source,
        sink,
        :edmonds_karp,
        zero,
        compare
      )
    end
  end

  @doc """
  Finds the maximum flow using Dinic's algorithm with custom numeric type.

  Dinic's algorithm builds a level graph using BFS, then finds blocking flows
  via DFS. For unit capacities it runs in O(E√V). It is generally faster than
  Edmonds-Karp for dense networks.

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
      iex> result = Yog.Flow.MaxFlow.dinic(graph, 1, 3)
      iex> result.max_flow
      5
  """
  @spec dinic(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          any(),
          (any(), any() -> any()),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt),
          (any(), any() -> any())
        ) :: max_flow_result()
  def dinic(
        graph,
        source,
        sink,
        zero \\ 0,
        add \\ &Kernel.+/2,
        subtract \\ &Kernel.-/2,
        compare \\ &Yog.Utils.compare/2,
        min_fn \\ &min/2
      ) do
    if source == sink do
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

      MaxFlowResult.new(zero, return_graph, source, sink, :dinic, zero, compare)
    else
      residual = build_residual_graph(graph, zero)

      {max_flow, final_residual} =
        do_dinic(residual, source, sink, zero, add, subtract, compare, min_fn, zero)

      final_residual_graph = residual_to_graph(graph, final_residual, zero, compare)

      MaxFlowResult.new(
        max_flow,
        final_residual_graph,
        source,
        sink,
        :dinic,
        zero,
        compare
      )
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
  defp residual_to_graph(original_graph, residual_map, zero, compare) do
    nodes = Map.keys(original_graph.nodes)
    original_nodes = original_graph.nodes

    graph =
      List.foldl(nodes, Model.new(:directed), fn node, acc ->
        data = Map.get(original_nodes, node)
        Model.add_node(acc, node, data)
      end)

    List.foldl(Map.to_list(residual_map), graph, fn {u, edges}, acc ->
      List.foldl(Map.to_list(edges), acc, fn {v, cap}, inner_acc ->
        if compare.(cap, zero) != :eq do
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

  defp do_edmonds_karp(residual, source, sink, zero, add, subtract, compare, min_fn, acc_flow) do
    case find_augmenting_path(residual, source, sink, zero, compare, min_fn) do
      nil ->
        {acc_flow, residual}

      {path, bottleneck} ->
        new_residual =
          List.foldl(path, residual, fn {from, to}, acc ->
            acc = update_forward_residual(acc, from, to, bottleneck, zero, subtract, compare)
            update_backward_residual(acc, to, from, bottleneck, zero, add)
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

  # Dinic's algorithm implementation
  defp do_dinic(residual, source, sink, zero, add, subtract, compare, min_fn, flow) do
    case bfs_level(residual, source, sink, zero, compare) do
      nil ->
        {flow, residual}

      level ->
        adj = build_adjacency(residual)
        ptr = Map.new(Map.keys(adj), fn u -> {u, Map.get(adj, u, [])} end)

        {new_flow, new_residual, _} =
          dfs_blocking_flow(
            residual,
            source,
            sink,
            level,
            ptr,
            zero,
            add,
            subtract,
            compare,
            min_fn,
            zero
          )

        if compare.(new_flow, zero) == :eq do
          {flow, new_residual}
        else
          do_dinic(
            new_residual,
            source,
            sink,
            zero,
            add,
            subtract,
            compare,
            min_fn,
            add.(flow, new_flow)
          )
        end
    end
  end

  defp bfs_level(residual, source, sink, zero, compare) do
    level =
      do_bfs_level(
        :queue.in(source, :queue.new()),
        residual,
        zero,
        compare,
        %{source => 0}
      )

    if Map.has_key?(level, sink) do
      level
    else
      nil
    end
  end

  defp do_bfs_level(queue, residual, zero, compare, level) do
    case :queue.out(queue) do
      {:empty, _} ->
        level

      {{:value, u}, rest_q} ->
        u_level = Map.fetch!(level, u)

        {next_q, next_level} =
          residual
          |> Map.get(u, %{})
          |> Map.to_list()
          |> List.foldl({rest_q, level}, fn {v, cap}, {q_acc, lvl_acc} ->
            if compare.(cap, zero) != :eq and not Map.has_key?(lvl_acc, v) do
              {:queue.in(v, q_acc), Map.put(lvl_acc, v, u_level + 1)}
            else
              {q_acc, lvl_acc}
            end
          end)

        do_bfs_level(next_q, residual, zero, compare, next_level)
    end
  end

  defp build_adjacency(residual) do
    Map.new(residual, fn {u, edges} -> {u, Map.keys(edges)} end)
  end

  defp dfs_blocking_flow(
         residual,
         source,
         sink,
         level,
         ptr,
         zero,
         add,
         subtract,
         compare,
         min_fn,
         total_flow
       ) do
    {pushed, new_residual, new_ptr} =
      dfs_send(
        residual,
        source,
        sink,
        level,
        ptr,
        zero,
        add,
        subtract,
        compare,
        min_fn,
        :infinity
      )

    if compare.(pushed, zero) == :eq do
      {total_flow, new_residual, new_ptr}
    else
      dfs_blocking_flow(
        new_residual,
        source,
        sink,
        level,
        new_ptr,
        zero,
        add,
        subtract,
        compare,
        min_fn,
        add.(total_flow, pushed)
      )
    end
  end

  defp dfs_send(residual, u, sink, level, ptr, zero, add, subtract, compare, min_fn, budget) do
    if u == sink do
      {budget, residual, ptr}
    else
      remaining = Map.get(ptr, u, [])

      dfs_send_from_list(
        residual,
        u,
        sink,
        level,
        ptr,
        zero,
        add,
        subtract,
        compare,
        min_fn,
        budget,
        remaining,
        zero
      )
    end
  end

  defp dfs_send_from_list(
         residual,
         u,
         sink,
         level,
         ptr,
         zero,
         add,
         subtract,
         compare,
         min_fn,
         budget,
         remaining,
         total_pushed
       ) do
    if (budget != :infinity and compare.(budget, zero) == :eq) or remaining == [] do
      {total_pushed, residual, ptr}
    else
      [v | rest] = remaining
      u_level = Map.fetch!(level, u)
      v_level = Map.get(level, v, -1)
      cap = get_residual_cap(residual, u, v, zero)

      if v_level == u_level + 1 and compare.(cap, zero) != :eq do
        child_budget = if budget == :infinity, do: cap, else: min_fn.(budget, cap)

        {pushed, new_residual, new_ptr} =
          dfs_send(
            residual,
            v,
            sink,
            level,
            ptr,
            zero,
            add,
            subtract,
            compare,
            min_fn,
            child_budget
          )

        if compare.(pushed, zero) != :eq do
          new_residual =
            update_forward_residual(new_residual, u, v, pushed, zero, subtract, compare)

          new_residual = update_backward_residual(new_residual, v, u, pushed, zero, add)

          new_budget = if budget == :infinity, do: :infinity, else: subtract.(budget, pushed)
          new_total = add.(total_pushed, pushed)

          # If edge was saturated, advance pointer past v; otherwise keep v
          {next_remaining, next_ptr} =
            if compare.(pushed, cap) == :eq do
              {rest, Map.put(new_ptr, u, rest)}
            else
              {remaining, new_ptr}
            end

          dfs_send_from_list(
            new_residual,
            u,
            sink,
            level,
            next_ptr,
            zero,
            add,
            subtract,
            compare,
            min_fn,
            new_budget,
            next_remaining,
            new_total
          )
        else
          next_ptr = Map.put(new_ptr, u, rest)

          dfs_send_from_list(
            residual,
            u,
            sink,
            level,
            next_ptr,
            zero,
            add,
            subtract,
            compare,
            min_fn,
            budget,
            rest,
            total_pushed
          )
        end
      else
        next_ptr = Map.put(ptr, u, rest)

        dfs_send_from_list(
          residual,
          u,
          sink,
          level,
          next_ptr,
          zero,
          add,
          subtract,
          compare,
          min_fn,
          budget,
          rest,
          total_pushed
        )
      end
    end
  end

  defp get_residual_cap(residual, u, v, zero) do
    Map.get(residual, u, %{}) |> Map.get(v, zero)
  end

  defp update_forward_residual(residual, u, v, flow, zero, subtract, compare) do
    from_edges = Map.get(residual, u, %{}) |> Map.put_new(v, zero)
    old_cap = Map.fetch!(from_edges, v)
    new_cap = subtract.(old_cap, flow)

    if compare.(new_cap, zero) == :eq do
      new_from_edges = Map.delete(from_edges, v)

      if map_size(new_from_edges) == 0 do
        Map.delete(residual, u)
      else
        Map.put(residual, u, new_from_edges)
      end
    else
      Map.put(residual, u, Map.put(from_edges, v, new_cap))
    end
  end

  defp update_backward_residual(residual, u, v, flow, zero, add) do
    to_edges = Map.get(residual, u, %{}) |> Map.put_new(v, zero)
    old_back = Map.fetch!(to_edges, v)
    new_back = add.(old_back, flow)
    Map.put(residual, u, Map.put(to_edges, v, new_back))
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
  def extract_min_cut(%MaxFlowResult{} = result) do
    min_cut(result, result.zero, result.compare)
  end

  @doc """
  Extracts the minimum cut from a max flow result with custom numeric type.

  This version allows you to specify the zero element and comparison function
  for custom numeric types.

  ## Parameters

  - `result` - The max flow result from `edmonds_karp/8` or `dinic/8`
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
        %MaxFlowResult{
          residual_graph: residual,
          source: source,
          max_flow: max_flow,
          algorithm: algorithm
        },
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
      algorithm: algorithm
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
