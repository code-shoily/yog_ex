defmodule Yog.MST.Prim do
  @moduledoc """
  Prim's algorithm for Minimum Spanning Tree (MST).
  """

  alias Yog.MST.Result
  alias Yog.PairingHeap, as: PQ

  @doc """
  Computes MST using Prim's algorithm.
  """
  @spec compute(Yog.graph(), (term(), term() -> :lt | :eq | :gt), term() | nil) ::
          {:ok, Result.t()}
  def compute(graph, compare, start_node) do
    case start_node do
      nil ->
        node_ids = Map.keys(graph.nodes)

        case node_ids do
          [] ->
            {:ok, Result.new([], :prim, 0)}

          [start | _] ->
            do_prim(graph, start, compare)
        end

      start ->
        if Map.has_key?(graph.nodes, start) do
          do_prim(graph, start, compare)
        else
          {:ok, Result.new([], :prim, map_size(graph.nodes))}
        end
    end
  end

  defp do_prim(graph, start, compare) do
    initial_edges = get_all_edges_from_node(graph, start)

    initial_pq =
      PQ.new(fn a, b -> compare.(a.weight, b.weight) == :lt end)
      |> Yog.MST.push_all(initial_edges)

    initial_visited = %{start => true}

    result = do_prim_loop(graph, initial_pq, initial_visited, [], compare)
    {:ok, Result.new(result, :prim, map_size(graph.nodes))}
  end

  # Main Prim loop - grows MST from starting node.
  defp do_prim_loop(_graph, pq, _visited, acc, _compare) when pq == %{} do
    Enum.reverse(acc)
  end

  defp do_prim_loop(graph, pq, visited, acc, compare) do
    if PQ.empty?(pq) do
      Enum.reverse(acc)
    else
      {:ok, edge, rest_pq} = PQ.pop(pq)

      if Map.has_key?(visited, edge.to) do
        do_prim_loop(graph, rest_pq, visited, acc, compare)
      else
        new_visited = Map.put(visited, edge.to, true)
        new_acc = [edge | acc]

        new_edges = get_all_edges_from_node(graph, edge.to)

        # Filter and push edges in one pass using List.foldl
        new_pq =
          List.foldl(new_edges, rest_pq, fn e, acc_pq ->
            if Map.has_key?(new_visited, e.to) do
              acc_pq
            else
              PQ.push(acc_pq, e)
            end
          end)

        do_prim_loop(graph, new_pq, new_visited, new_acc, compare)
      end
    end
  end

  # Gets all outgoing edges from a specific node.
  defp get_all_edges_from_node(graph, from_id) do
    case Map.fetch(graph.out_edges, from_id) do
      {:ok, edges} ->
        Enum.map(edges, fn {to_id, weight} ->
          %{from: from_id, to: to_id, weight: weight}
        end)

      :error ->
        []
    end
  end
end
