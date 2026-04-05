defmodule Yog.Connectivity.Components do
  @moduledoc """
  Connected components algorithms for undirected and directed graphs.

  This module provides algorithms for finding connected components:
  - **Connected Components**: For undirected graphs, finds maximal subgraphs where
    every node is reachable from every other node.
  - **Weakly Connected Components**: For directed graphs, finds maximal subgraphs
    where nodes are connected when edge directions are ignored.

  ## Algorithm Characteristics

  - **Time Complexity**: O(V + E) for both algorithms
  - **Space Complexity**: O(V) for the visited set
  - **Implementation**: DFS-based traversal with tail recursion

  ## When to Use

  - **Connected Components**: Use on undirected graphs to find disjoint subgraphs
  - **Weakly Connected Components**: Use on directed graphs when you care about
    connectivity regardless of direction

  ## Use Cases

  - Identifying isolated subgraphs in social networks
  - Finding disconnected regions in network topology
  - Analyzing graph structure and connectivity
  - Preprocessing for other graph algorithms

  ## Examples

      # Find connected components in an undirected graph
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Connectivity.Components.connected_components(graph)
      [[3, 2, 1]]

      # Find weakly connected components in a directed graph
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Connectivity.Components.weakly_connected_components(graph)
      [[3, 2, 1]]
  """

  @type component :: [Yog.node_id()]

  @doc """
  Finds Connected Components in an **undirected graph**.

  A connected component is a maximal subgraph where every node is reachable
  from every other node via undirected edges.

  Time Complexity: O(V + E)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> components = Yog.Connectivity.Components.connected_components(graph)
      iex> length(components)
      1

      iex> # Two separate components
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_node(4, "D")
      ...> |> Yog.add_edges!([{1, 2, 1}, {3, 4, 1}])
      iex> components = Yog.Connectivity.Components.connected_components(graph)
      iex> length(components)
      2
  """
  @spec connected_components(Yog.graph()) :: [component()]
  def connected_components(graph) do
    out_edges = graph.out_edges
    nodes = Map.keys(graph.nodes)

    {_, components} =
      do_components_all(nodes, out_edges, %{}, [])

    components
  end

  defp do_components_all([], _, _, comps), do: {%{}, comps}

  defp do_components_all([node | rest], out, visited, comps) do
    if is_map_key(visited, node) do
      do_components_all(rest, out, visited, comps)
    else
      {new_visited, comp} = dfs_component(out, node, visited, [])
      do_components_all(rest, out, new_visited, [comp | comps])
    end
  end

  defp dfs_component(out, node, visited, comp) do
    visited = Map.put(visited, node, true)

    case Map.fetch(out, node) do
      {:ok, neighbors} when map_size(neighbors) > 0 ->
        neighbor_list = Map.to_list(neighbors)
        dfs_component_neighbors(neighbor_list, out, visited, [node | comp])

      _ ->
        {visited, [node | comp]}
    end
  end

  defp dfs_component_neighbors([], _, visited, comp), do: {visited, comp}

  defp dfs_component_neighbors([{nb, _} | rest], out, visited, comp) do
    if is_map_key(visited, nb) do
      dfs_component_neighbors(rest, out, visited, comp)
    else
      {new_visited, new_comp} = dfs_component(out, nb, visited, comp)
      dfs_component_neighbors(rest, out, new_visited, new_comp)
    end
  end

  @doc """
  Finds Weakly Connected Components in a **directed graph**.

  A weakly connected component is a maximal subgraph where, if you ignore
  edge directions, all nodes are reachable from each other.

  Time Complexity: O(V + E)

  ## Examples

      iex> # Chain: 1 -> 2 -> 3 (weakly connected as one component)
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> wccs = Yog.Connectivity.Components.weakly_connected_components(graph)
      iex> length(wccs)
      1

      iex> # Two separate chains (two weakly connected components)
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {3, 4, 1}])
      iex> wccs = Yog.Connectivity.Components.weakly_connected_components(graph)
      iex> length(wccs)
      2
  """
  @spec weakly_connected_components(Yog.graph()) :: [component()]
  def weakly_connected_components(graph) do
    out_edges = graph.out_edges
    in_edges = graph.in_edges
    nodes = Map.keys(graph.nodes)

    {_, components} =
      do_wcc_all(nodes, out_edges, in_edges, %{}, [])

    components
  end

  defp do_wcc_all([], _, _, _, comps), do: {%{}, comps}

  defp do_wcc_all([node | rest], out, in_e, visited, comps) do
    if is_map_key(visited, node) do
      do_wcc_all(rest, out, in_e, visited, comps)
    else
      {new_visited, comp} = dfs_wcc(out, in_e, node, visited, [])
      do_wcc_all(rest, out, in_e, new_visited, [comp | comps])
    end
  end

  defp dfs_wcc(out, in_e, node, visited, comp) do
    visited = Map.put(visited, node, true)

    {v1, c1} =
      case Map.fetch(out, node) do
        {:ok, succs} when map_size(succs) > 0 ->
          succ_list = Map.to_list(succs)
          dfs_wcc_neighbors(succ_list, out, in_e, visited, [node | comp])

        _ ->
          {visited, [node | comp]}
      end

    case Map.fetch(in_e, node) do
      {:ok, preds} when map_size(preds) > 0 ->
        pred_list = Map.to_list(preds)
        dfs_wcc_neighbors(pred_list, out, in_e, v1, c1)

      _ ->
        {v1, c1}
    end
  end

  defp dfs_wcc_neighbors([], _, _, visited, comp), do: {visited, comp}

  defp dfs_wcc_neighbors([{nb, _} | rest], out, in_e, visited, comp) do
    if is_map_key(visited, nb) do
      dfs_wcc_neighbors(rest, out, in_e, visited, comp)
    else
      {new_visited, new_comp} = dfs_wcc(out, in_e, nb, visited, comp)
      dfs_wcc_neighbors(rest, out, in_e, new_visited, new_comp)
    end
  end
end
