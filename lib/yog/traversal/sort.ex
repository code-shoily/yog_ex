defmodule Yog.Traversal.Sort do
  @moduledoc """
  Topological sorting algorithms — Kahn's algorithm and lexicographic variant.
  """

  alias Yog.Model
  alias Yog.PriorityQueue, as: PQ

  @doc """
  Performs a topological sort on a directed graph using Kahn's algorithm.
  """
  @spec topological_sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    all_nodes = Model.all_nodes(graph)

    in_degrees =
      Enum.map(all_nodes, fn id ->
        degree =
          case Map.fetch(graph.in_edges, id) do
            {:ok, inner} -> map_size(inner)
            :error -> 0
          end

        {id, degree}
      end)
      |> Map.new()

    queue =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _} -> id end)

    do_kahn(graph, queue, in_degrees, [], length(all_nodes))
  end

  @doc """
  Performs a lexicographically smallest topological sort. The content is compared based
  on node data, not ID.
  """
  @spec lexicographical_topological_sort(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_topological_sort(graph, compare_nodes) do
    all_nodes = Model.all_nodes(graph)
    %Yog.Graph{in_edges: in_edges} = graph

    in_degrees =
      Enum.map(all_nodes, fn id ->
        degree =
          case Map.fetch(in_edges, id) do
            {:ok, inner} -> map_size(inner)
            :error -> 0
          end

        {id, degree}
      end)
      |> Map.new()

    pq_compare = fn {data_a, id_a}, {data_b, id_b} ->
      compare_nodes.(data_a, data_b) == :lt or
        (compare_nodes.(data_a, data_b) == :eq and id_a <= id_b)
    end

    pq = PQ.new(pq_compare)

    initial_pq =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _} -> {Model.node(graph, id), id} end)
      |> Enum.reduce(pq, fn item, acc -> PQ.push(acc, item) end)

    do_lexical_kahn_pq(graph, initial_pq, in_degrees, [], length(all_nodes))
  end

  # Kahn's algorithm
  defp do_kahn(_graph, [], _in_degrees, acc, total_count) do
    if length(acc) == total_count do
      {:ok, Enum.reverse(acc)}
    else
      {:error, :contains_cycle}
    end
  end

  defp do_kahn(graph, [head | tail], in_degrees, acc, total_count) do
    neighbors = Model.successor_ids(graph, head)

    {next_queue, next_in_degrees} =
      Enum.reduce(neighbors, {tail, in_degrees}, fn neighbor, {q, degrees} ->
        current_degree = Map.get(degrees, neighbor, 0)
        new_degree = current_degree - 1
        new_degrees = Map.put(degrees, neighbor, new_degree)

        new_q =
          if new_degree == 0 do
            [neighbor | q]
          else
            q
          end

        {new_q, new_degrees}
      end)

    do_kahn(graph, next_queue, next_in_degrees, [head | acc], total_count)
  end

  # Lexicographic Kahn's with priority queue
  defp do_lexical_kahn_pq(_graph, _pq, _in_degrees, acc, total_count)
       when total_count == 0 do
    if Enum.empty?(acc) do
      {:ok, []}
    else
      {:ok, Enum.reverse(acc)}
    end
  end

  defp do_lexical_kahn_pq(graph, pq, in_degrees, acc, total_count) do
    if PQ.empty?(pq) do
      if length(acc) == total_count do
        {:ok, Enum.reverse(acc)}
      else
        {:error, :contains_cycle}
      end
    else
      {:ok, {_, head}, rest_pq} = PQ.pop(pq)
      do_lexical_kahn_pq_step(graph, rest_pq, in_degrees, [head | acc], total_count)
    end
  end

  defp do_lexical_kahn_pq_step(graph, pq, in_degrees, acc, total_count) do
    head = hd(acc)
    neighbors = Model.successor_ids(graph, head)

    {next_pq, next_in_degrees} =
      Enum.reduce(neighbors, {pq, in_degrees}, fn neighbor, {acc_pq, degrees} ->
        current_degree = Map.get(degrees, neighbor, 0)
        new_degree = current_degree - 1
        new_degrees = Map.put(degrees, neighbor, new_degree)

        updated_pq =
          if new_degree == 0 do
            neighbor_data = Model.node(graph, neighbor)
            PQ.push(acc_pq, {neighbor_data, neighbor})
          else
            acc_pq
          end

        {updated_pq, new_degrees}
      end)

    do_lexical_kahn_pq(graph, next_pq, next_in_degrees, acc, total_count)
  end
end
