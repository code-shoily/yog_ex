defmodule Yog.Traversal.Sort do
  @moduledoc """
  Topological sorting algorithms — Kahn's algorithm and lexicographic variant.
  """

  alias Yog.PriorityQueue, as: PQ
  alias Yog.Queryable, as: Model

  @doc """
  Performs a topological sort on a directed graph using Kahn's algorithm.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Traversal.topological_sort(graph)
      {:ok, [1, 2, 3]}

      iex> # Graph with cycle
      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}])
      iex> Yog.Traversal.topological_sort(graph)
      {:error, :contains_cycle}
  """
  @spec topological_sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    in_degrees = build_degree_map(graph)

    queue =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _} -> id end)

    do_kahn(graph, queue, in_degrees, [], 0, Enum.count(graph))
  end

  @doc """
  Performs a lexicographically smallest topological sort. Compares by node_data. Breaks tie
  by ID.

  ## Example

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "c")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "b")
      ...>   |> Yog.add_edges!([{1, 3, 1}, {2, 3, 1}])
      iex> Yog.Traversal.lexicographical_topological_sort(graph, fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      {:ok, [2, 1, 3]}  # "a" comes before "c"
  """
  @spec lexicographical_topological_sort(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_topological_sort(graph, compare_nodes) do
    in_degrees = build_degree_map(graph)

    pq =
      PQ.new(fn {data_a, id_a}, {data_b, id_b} ->
        res = compare_nodes.(data_a, data_b)
        res == :lt or (res == :eq and id_a <= id_b)
      end)

    initial_pq =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _} -> {Model.node(graph, id), id} end)
      |> Enum.reduce(pq, fn item, acc -> PQ.push(acc, item) end)

    do_lexical_kahn_pq(graph, initial_pq, in_degrees, [], 0, Enum.count(graph))
  end

  # Build degree map
  defp build_degree_map(graph) do
    graph
    |> Enum.map(fn {id, _} -> {id, Model.in_degree(graph, id)} end)
    |> Map.new()
  end

  # Kahn's algorithm
  defp do_kahn(_graph, [], _in_degrees, acc, size, total_count) do
    if size == total_count do
      {:ok, Enum.reverse(acc)}
    else
      {:error, :contains_cycle}
    end
  end

  defp do_kahn(graph, [head | tail], in_degrees, acc, size, total_count) do
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

    do_kahn(graph, next_queue, next_in_degrees, [head | acc], size + 1, total_count)
  end

  # Lexicographic Kahn's with priority queue
  defp do_lexical_kahn_pq(_graph, _pq, _in_degrees, acc, _size, total_count)
       when total_count == 0 do
    if Enum.empty?(acc) do
      {:ok, []}
    else
      {:ok, Enum.reverse(acc)}
    end
  end

  defp do_lexical_kahn_pq(graph, pq, in_degrees, acc, size, total_count) do
    if PQ.empty?(pq) do
      if size == total_count do
        {:ok, Enum.reverse(acc)}
      else
        {:error, :contains_cycle}
      end
    else
      {:ok, {_, head}, rest_pq} = PQ.pop(pq)
      do_lexical_kahn_pq_step(graph, rest_pq, in_degrees, [head | acc], size + 1, total_count)
    end
  end

  defp do_lexical_kahn_pq_step(graph, pq, in_degrees, acc, size, total_count) do
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

    do_lexical_kahn_pq(graph, next_pq, next_in_degrees, acc, size, total_count)
  end
end
