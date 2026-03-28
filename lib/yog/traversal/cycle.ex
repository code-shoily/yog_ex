defmodule Yog.Traversal.Cycle do
  @moduledoc """
  Cycle detection algorithms for directed and undirected graphs.
  """

  alias Yog.Model
  alias Yog.Traversal.Sort

  @doc """
  Determines if a graph contains any cycles.

  For directed graphs, uses Kahn's algorithm (topological sort).
  For undirected graphs, uses DFS-based back-edge detection.

  **Time Complexity:** O(V + E)
  """
  @spec cyclic?(Yog.graph()) :: boolean()
  def cyclic?(graph) do
    case graph.kind do
      :directed ->
        case Sort.topological_sort(graph) do
          {:error, :contains_cycle} -> true
          _ -> false
        end

      :undirected ->
        do_has_undirected_cycle(
          graph,
          Model.all_nodes(graph),
          MapSet.new()
        )
    end
  end

  @doc """
  Determines if a graph is acyclic (contains no cycles).

  **Time Complexity:** O(V + E)
  """
  @spec acyclic?(Yog.graph()) :: boolean()
  def acyclic?(graph) do
    not cyclic?(graph)
  end

  # Check for cycles in undirected graphs
  defp do_has_undirected_cycle(_graph, [], _visited), do: false

  defp do_has_undirected_cycle(graph, [node | rest], visited) do
    if MapSet.member?(visited, node) do
      do_has_undirected_cycle(graph, rest, visited)
    else
      {cycle?, new_visited} = check_undirected_cycle(graph, node, nil, visited)

      if cycle? do
        true
      else
        do_has_undirected_cycle(graph, rest, new_visited)
      end
    end
  end

  defp check_undirected_cycle(graph, node, parent, visited) do
    new_visited = MapSet.put(visited, node)
    neighbors = Model.successor_ids(graph, node)

    Enum.reduce_while(neighbors, {false, new_visited}, fn neighbor, {_, current_visited} ->
      if MapSet.member?(current_visited, neighbor) do
        if parent == neighbor do
          {:cont, {false, current_visited}}
        else
          {:halt, {true, current_visited}}
        end
      else
        {has_cycle?, next_visited} =
          check_undirected_cycle(graph, neighbor, node, current_visited)

        if has_cycle? do
          {:halt, {true, next_visited}}
        else
          {:cont, {false, next_visited}}
        end
      end
    end)
  end
end
