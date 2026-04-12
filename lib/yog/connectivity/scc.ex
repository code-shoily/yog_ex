defmodule Yog.Connectivity.SCC do
  @moduledoc """
  Strongly Connected Components (SCC) algorithms.

  This module provides algorithms for finding strongly connected components in directed
  graphs. A strongly connected component is a maximal subgraph where every node is
  reachable from every other node via directed edges.

  ## Algorithms

  - **Tarjan's Algorithm**: `strongly_connected_components/1` - Single-pass DFS with
    low-link values. Time complexity O(V + E).
  - **Kosaraju's Algorithm**: `kosaraju/1` - Two-pass DFS on original and transposed
    graphs. Time complexity O(V + E).

  ## When to Use

  - **Tarjan's**: Preferred for most use cases; single pass, slightly more efficient
  - **Kosaraju's**: When you need the finish order for other algorithms, or prefer
    the conceptual simplicity of the two-pass approach

  ## Use Cases

  - Finding cycles in dependency graphs
  - Identifying mutually reachable regions in networks
  - Condensing graphs for easier analysis
  - Detecting bottlenecks in flow networks

  ## SCC Partition Visualization

  In a strongly connected component, every node can reach every other node.

  <div class="graphviz">
  digraph G {
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];

    subgraph cluster_scc1 {
      label="SCC 1 (Cycle)"; color="#6366f1"; style=rounded;
      A -> B; B -> C; C -> A;
    }

    subgraph cluster_scc2 {
      label="SCC 2 (Cycle)"; color="#f43f5e"; style=rounded;
      D -> E; E -> D;
    }

    // Bridge edge between SCCs
    B -> D [label="bridge", color="#94a3b8", style=dashed];
  }
  </div>

      iex> alias Yog.Connectivity.SCC
      iex> graph = Yog.from_edges(:directed, [
      ...>   {"A", "B", 1}, {"B", "C", 1}, {"C", "A", 1},
      ...>   {"D", "E", 1}, {"E", "D", 1}, {"B", "D", 1}
      ...> ])
      iex> sccs = SCC.strongly_connected_components(graph)
      iex> length(sccs)
      2

  ## Examples

      # Find SCCs in a graph with a cycle
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.Connectivity.SCC.strongly_connected_components(graph)
      [[1, 2, 3]]

      # Find SCCs in a graph with multiple cycles
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}, {3, 4, 1}, {4, 3, 1}])
      iex> sccs = Yog.Connectivity.SCC.strongly_connected_components(graph)
      iex> length(sccs)
      2
  """

  @doc """
  Finds Strongly Connected Components (SCC) using Tarjan's Algorithm.

  A strongly connected component is a maximal subgraph where every node is
  reachable from every other node via directed edges.

  Time Complexity: O(V + E)

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> sccs = Yog.Connectivity.SCC.strongly_connected_components(graph)
      iex> length(sccs)
      1
      iex> hd(sccs) |> Enum.sort()
      [1, 2, 3]

      iex> # Two separate cycles
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}, {3, 4, 1}, {4, 3, 1}])
      iex> sccs = Yog.Connectivity.SCC.strongly_connected_components(graph)
      iex> length(sccs)
      2
  """
  @spec strongly_connected_components(Yog.graph()) :: [[Yog.node_id()]]
  def strongly_connected_components(graph) do
    out_edges = graph.out_edges
    nodes = Map.keys(graph.nodes)

    {_, _, _, _, _, final_sccs} =
      do_tarjan_all(nodes, out_edges, 0, %{}, %{}, [], %{}, [])

    final_sccs
  end

  defp do_tarjan_all([], _, idx, ids, lows, st, os, sccs),
    do: {idx, ids, lows, st, os, sccs}

  defp do_tarjan_all([node | rest], out, idx, ids, lows, st, os, sccs) do
    if is_map_key(ids, node) do
      do_tarjan_all(rest, out, idx, ids, lows, st, os, sccs)
    else
      {idx2, ids2, lows2, st2, os2, sccs2} =
        tarjan_dfs(out, node, idx, ids, lows, st, os, sccs)

      do_tarjan_all(rest, out, idx2, ids2, lows2, st2, os2, sccs2)
    end
  end

  defp tarjan_dfs(out, node, index, indices, lowlinks, stack, on_stack, sccs) do
    neighbors = Map.get(out, node)

    {next_index, indices, lowlinks, stack, on_stack, sccs} =
      process_neighbors(
        neighbors,
        out,
        node,
        index + 1,
        Map.put(indices, node, index),
        Map.put(lowlinks, node, index),
        [node | stack],
        Map.put(on_stack, node, true),
        sccs
      )

    if Map.fetch!(lowlinks, node) == Map.fetch!(indices, node) do
      {new_scc, new_stack, new_on_stack} = pop_scc(stack, on_stack, node, [])
      {next_index, indices, lowlinks, new_stack, new_on_stack, [new_scc | sccs]}
    else
      {next_index, indices, lowlinks, stack, on_stack, sccs}
    end
  end

  defp process_neighbors(nil, _, _, idx, ids, lows, st, os, sccs),
    do: {idx, ids, lows, st, os, sccs}

  defp process_neighbors(neighbors, out, node, idx, ids, lows, st, os, sccs) do
    neighbor_list = Map.to_list(neighbors)

    List.foldl(
      neighbor_list,
      {idx, ids, lows, st, os, sccs},
      fn {neighbor, _}, {i, ids_acc, lows_acc, st_acc, os_acc, sccs_acc} ->
        case Map.get(ids_acc, neighbor) do
          nil ->
            # Unvisited - recursive DFS
            {i2, ids2, lows2, st2, os2, sccs2} =
              tarjan_dfs(out, neighbor, i, ids_acc, lows_acc, st_acc, os_acc, sccs_acc)

            # Update lowlink
            node_low = Map.fetch!(lows2, node)
            nb_low = Map.fetch!(lows2, neighbor)
            new_lows = if nb_low < node_low, do: Map.put(lows2, node, nb_low), else: lows2

            {i2, ids2, new_lows, st2, os2, sccs2}

          neighbor_index ->
            # Visited - check for back edge
            new_lows =
              if is_map_key(os_acc, neighbor) do
                node_low = Map.fetch!(lows_acc, node)

                if neighbor_index < node_low do
                  Map.put(lows_acc, node, neighbor_index)
                else
                  lows_acc
                end
              else
                lows_acc
              end

            {i, ids_acc, new_lows, st_acc, os_acc, sccs_acc}
        end
      end
    )
  end

  # Pop SCC from stack
  defp pop_scc([head | rest], os, target, acc) when head == target do
    {[head | acc], rest, Map.delete(os, head)}
  end

  defp pop_scc([head | rest], os, target, acc) do
    pop_scc(rest, Map.delete(os, head), target, [head | acc])
  end

  @doc """
  Finds Strongly Connected Components (SCC) using Kosaraju's Algorithm.

  Kosaraju's algorithm performs two passes of DFS:
  1. First pass on the original graph to get finish order
  2. Second pass on the transposed graph in reverse finish order

  Time Complexity: O(V + E)

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> sccs = Yog.Connectivity.SCC.kosaraju(graph)
      iex> length(sccs)
      1
      iex> hd(sccs) |> Enum.sort()
      [1, 2, 3]

      iex> # Acyclic graph - each node is its own SCC
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> sccs = Yog.Connectivity.SCC.kosaraju(graph)
      iex> length(sccs)
      3
  """
  @spec kosaraju(Yog.graph()) :: [[Yog.node_id()]]
  def kosaraju(graph) do
    out_edges = graph.out_edges
    in_edges = graph.in_edges
    nodes = Map.keys(graph.nodes)

    {finish_order, _} = kosaraju_first_pass(nodes, out_edges, [], %{})

    {_, sccs} =
      List.foldl(
        finish_order,
        {%{}, []},
        fn node, {visited, acc} ->
          if is_map_key(visited, node) do
            {visited, acc}
          else
            {new_visited, comp} = kosaraju_collect(in_edges, node, visited, [])
            {new_visited, [comp | acc]}
          end
        end
      )

    sccs
  end

  defp kosaraju_first_pass([], _, order, visited), do: {order, visited}

  defp kosaraju_first_pass([node | rest], out, order, visited) do
    if is_map_key(visited, node) do
      kosaraju_first_pass(rest, out, order, visited)
    else
      {new_order, new_visited} = kosaraju_finish(out, node, order, visited)
      kosaraju_first_pass(rest, out, new_order, new_visited)
    end
  end

  defp kosaraju_finish(out, node, order, visited) do
    if is_map_key(visited, node) do
      {order, visited}
    else
      visited = Map.put(visited, node, true)

      {new_order, new_visited} =
        case Map.fetch(out, node) do
          {:ok, neighbors} when map_size(neighbors) > 0 ->
            neighbor_list = Map.to_list(neighbors)
            kosaraju_finish_neighbors(neighbor_list, out, order, visited)

          _ ->
            {order, visited}
        end

      {[node | new_order], new_visited}
    end
  end

  defp kosaraju_finish_neighbors([], _, order, visited), do: {order, visited}

  defp kosaraju_finish_neighbors([{nb, _} | rest], out, order, visited) do
    {new_order, new_visited} = kosaraju_finish(out, nb, order, visited)
    kosaraju_finish_neighbors(rest, out, new_order, new_visited)
  end

  defp kosaraju_collect(in_edges, node, visited, acc) do
    if is_map_key(visited, node) do
      {visited, acc}
    else
      visited = Map.put(visited, node, true)

      {new_visited, new_acc} =
        case Map.fetch(in_edges, node) do
          {:ok, neighbors} when map_size(neighbors) > 0 ->
            neighbor_list = Map.to_list(neighbors)
            kosaraju_collect_neighbors(neighbor_list, in_edges, visited, [node | acc])

          _ ->
            {visited, [node | acc]}
        end

      {new_visited, new_acc}
    end
  end

  defp kosaraju_collect_neighbors([], _, visited, acc), do: {visited, acc}

  defp kosaraju_collect_neighbors([{nb, _} | rest], in_edges, visited, acc) do
    {new_visited, new_acc} = kosaraju_collect(in_edges, nb, visited, acc)
    kosaraju_collect_neighbors(rest, in_edges, new_visited, new_acc)
  end
end
