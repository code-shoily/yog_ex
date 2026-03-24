defmodule Yog.Connectivity.Components do
  @moduledoc """
  Algorithms for finding (weakly) connected components in graphs.
  """

  alias Yog.Model

  @type component :: [Yog.node_id()]

  @doc """
  Finds Connected Components in an **undirected graph**.

  A connected component is a maximal subgraph where every node is reachable
  from every other node via undirected edges.

  Time Complexity: O(V + E)
  """
  @spec connected_components(Yog.graph()) :: [component()]
  def connected_components(graph) do
    all_nodes = Model.all_nodes(graph)

    {_, components} =
      Enum.reduce(all_nodes, {MapSet.new(), []}, fn node, {visited, components} ->
        if MapSet.member?(visited, node) do
          {visited, components}
        else
          {new_visited, component} = dfs_component(graph, node, visited, [])
          {new_visited, [component | components]}
        end
      end)

    components
  end

  defp dfs_component(graph, node, visited, component) do
    visited = MapSet.put(visited, node)
    neighbors = Model.successor_ids(graph, node)

    Enum.reduce(neighbors, {visited, [node | component]}, fn neighbor, {acc_visited, acc_comp} ->
      if MapSet.member?(acc_visited, neighbor) do
        {acc_visited, acc_comp}
      else
        dfs_component(graph, neighbor, acc_visited, acc_comp)
      end
    end)
  end

  @doc """
  Finds Weakly Connected Components in a **directed graph**.

  A weakly connected component is a maximal subgraph where, if you ignore
  edge directions, all nodes are reachable from each other.

  Time Complexity: O(V + E)
  """
  @spec weakly_connected_components(Yog.graph()) :: [component()]
  def weakly_connected_components(graph) do
    all_nodes = Model.all_nodes(graph)

    {_, components} =
      Enum.reduce(all_nodes, {MapSet.new(), []}, fn node, {visited, components} ->
        if MapSet.member?(visited, node) do
          {visited, components}
        else
          {new_visited, component} = dfs_weak_component(graph, node, visited, [])
          {new_visited, [component | components]}
        end
      end)

    components
  end

  defp dfs_weak_component(graph, node, visited, component) do
    visited = MapSet.put(visited, node)

    # Get all neighbors (both successors and predecessors)
    successors = Model.successor_ids(graph, node)
    predecessors = Model.predecessors(graph, node) |> Enum.map(fn {id, _} -> id end)
    all_neighbors = Enum.uniq(successors ++ predecessors)

    Enum.reduce(all_neighbors, {visited, [node | component]}, fn neighbor,
                                                                 {acc_visited, acc_comp} ->
      if MapSet.member?(acc_visited, neighbor) do
        {acc_visited, acc_comp}
      else
        dfs_weak_component(graph, neighbor, acc_visited, acc_comp)
      end
    end)
  end
end
