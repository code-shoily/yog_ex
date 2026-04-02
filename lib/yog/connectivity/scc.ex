defmodule Yog.Connectivity.SCC do
  @moduledoc """
  Strongly Connected Components (SCC) algorithms.
  """

  alias Yog.Queryable, as: Model

  @doc """
  Finds Strongly Connected Components (SCC) using Tarjan's Algorithm.

  Time Complexity: O(V + E)
  """
  @spec strongly_connected_components(Yog.graph()) :: [[Yog.node_id()]]
  def strongly_connected_components(graph) do
    all_nodes = Model.all_nodes(graph)

    state = %{
      index: 0,
      indices: %{},
      lowlinks: %{},
      stack: [],
      on_stack: MapSet.new(),
      sccs: []
    }

    final_state =
      Enum.reduce(all_nodes, state, fn node, acc_state ->
        if Map.has_key?(acc_state.indices, node) do
          acc_state
        else
          tarjan_dfs(graph, node, acc_state)
        end
      end)

    final_state.sccs
  end

  defp tarjan_dfs(graph, node, state) do
    state =
      Map.update!(state, :indices, &Map.put(&1, node, state.index))
      |> Map.update!(:lowlinks, &Map.put(&1, node, state.index))
      |> Map.update!(:index, &(&1 + 1))
      |> Map.update!(:stack, &[node | &1])
      |> Map.update!(:on_stack, &MapSet.put(&1, node))

    neighbors = Model.successor_ids(graph, node)

    state_after_neighbors =
      Enum.reduce(neighbors, state, fn neighbor, acc_state ->
        case Map.fetch(acc_state.indices, neighbor) do
          :error ->
            new_state = tarjan_dfs(graph, neighbor, acc_state)

            new_lowlink =
              min(
                Map.fetch!(new_state.lowlinks, node),
                Map.fetch!(new_state.lowlinks, neighbor)
              )

            Map.update!(new_state, :lowlinks, &Map.put(&1, node, new_lowlink))

          {:ok, _} ->
            if MapSet.member?(acc_state.on_stack, neighbor) do
              new_lowlink =
                min(
                  Map.fetch!(acc_state.lowlinks, node),
                  Map.fetch!(acc_state.indices, neighbor)
                )

              Map.update!(acc_state, :lowlinks, &Map.put(&1, node, new_lowlink))
            else
              acc_state
            end
        end
      end)

    if Map.fetch!(state_after_neighbors.lowlinks, node) ==
         Map.fetch!(state_after_neighbors.indices, node) do
      {scc, new_stack, new_on_stack} =
        pop_scc(state_after_neighbors.stack, state_after_neighbors.on_stack, node, [])

      %{
        state_after_neighbors
        | stack: new_stack,
          on_stack: new_on_stack,
          sccs: [scc | state_after_neighbors.sccs]
      }
    else
      state_after_neighbors
    end
  end

  defp pop_scc([head | rest], on_stack, target, acc) when head == target do
    {Enum.reverse([head | acc]), rest, MapSet.delete(on_stack, head)}
  end

  defp pop_scc([head | rest], on_stack, target, acc) do
    pop_scc(rest, MapSet.delete(on_stack, head), target, [head | acc])
  end

  @doc """
  Strongly Connected Components (SCC) using Kosaraju's Algorithm.

  Time Complexity: O(V + E)
  """
  @spec kosaraju(Yog.graph()) :: [[Yog.node_id()]]
  def kosaraju(graph) do
    all_nodes = Model.all_nodes(graph)

    {_, finish_order} =
      Enum.reduce(all_nodes, {MapSet.new(), []}, fn node, {visited, order} ->
        if MapSet.member?(visited, node) do
          {visited, order}
        else
          dfs_finish(graph, node, visited, order)
        end
      end)

    {_, sccs} =
      Enum.reduce(finish_order, {MapSet.new(), []}, fn node, {visited, components} ->
        if MapSet.member?(visited, node) do
          {visited, components}
        else
          {new_visited, component} = dfs_collect_reversed(graph, node, visited, [])
          {new_visited, [component | components]}
        end
      end)

    sccs
  end

  defp dfs_finish(graph, node, visited, order) do
    visited = MapSet.put(visited, node)
    neighbors = Model.successor_ids(graph, node)

    {final_visited, final_order} =
      Enum.reduce(neighbors, {visited, order}, fn neighbor, {acc_visited, acc_order} ->
        if MapSet.member?(acc_visited, neighbor) do
          {acc_visited, acc_order}
        else
          dfs_finish(graph, neighbor, acc_visited, acc_order)
        end
      end)

    {final_visited, [node | final_order]}
  end

  defp dfs_collect_reversed(graph, node, visited, component) do
    visited = MapSet.put(visited, node)
    neighbors = Model.predecessor_ids(graph, node)

    Enum.reduce(neighbors, {visited, [node | component]}, fn neighbor, {acc_visited, acc_comp} ->
      if MapSet.member?(acc_visited, neighbor) do
        {acc_visited, acc_comp}
      else
        dfs_collect_reversed(graph, neighbor, acc_visited, acc_comp)
      end
    end)
  end
end
