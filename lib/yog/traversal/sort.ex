defmodule Yog.Traversal.Sort do
  @moduledoc """
  Topological sorting algorithms for directed acyclic graphs (DAGs).

  This module provides algorithms for producing a topological ordering of nodes in a DAG.
  A topological ordering is a linear ordering of nodes such that for every directed edge
  (u, v), node u comes before v in the ordering.

  ## Algorithms

  - **Kahn's Algorithm**: `topological_sort/1` - BFS-based approach using in-degrees.
    Time complexity O(V + E). Preferred for most use cases.
  - **Lexicographical Topological Sort**: `lexicographical_topological_sort/2` - Kahn's
    algorithm with a priority queue for deterministic ordering. Time complexity O((V + E) log V).

  ## Algorithm Characteristics

  - **Time Complexity**: O(V + E) for standard, O((V + E) log V) for lexicographical
  - **Space Complexity**: O(V) for the in-degree map and queue
  - **Cycle Detection**: Both algorithms detect cycles and return `{:error, :contains_cycle}`

  ## When to Use

  - **Standard**: Use when you just need any valid topological ordering
  - **Lexicographical**: Use when you need a deterministic ordering (e.g., alphabetical)

  ## Use Cases

  - Task scheduling with dependencies
  - Resolving symbol dependencies in compilers
  - Ordering of formula calculations in spreadsheets
  - Determining instruction sequences in dataflow programming

  ## Examples

      # Standard topological sort
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])
      iex> {:ok, order} = Yog.Traversal.Sort.topological_sort(graph)
      iex> order
      [1, 2, 3]

      # Lexicographical topological sort
      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "c")
      ...> |> Yog.add_node(2, "a")
      ...> |> Yog.add_node(3, "b")
      ...> |> Yog.add_edges!([{1, 3, 1}, {2, 3, 1}])
      iex> {:ok, order} = Yog.Traversal.Sort.lexicographical_topological_sort(graph, &<=/2)
      iex> order
      [2, 1, 3]
  """

  alias Yog.PriorityQueue, as: PQ

  @doc """
  Performs a topological sort on a directed graph using Kahn's algorithm.

  Time Complexity: O(V + E)
  """
  @spec topological_sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    out_edges = graph.out_edges
    in_edges = graph.in_edges
    total_count = Yog.Model.order(graph)

    in_degrees =
      :maps.fold(
        fn id, _, acc ->
          deg =
            case Map.fetch(in_edges, id) do
              {:ok, inner} -> map_size(inner)
              :error -> 0
            end

          Map.put(acc, id, deg)
        end,
        %{},
        graph.nodes
      )

    initial_q =
      :maps.fold(
        fn id, _, acc ->
          if Map.fetch!(in_degrees, id) == 0, do: [id | acc], else: acc
        end,
        [],
        graph.nodes
      )

    do_kahn(out_edges, initial_q, in_degrees, [], 0, total_count)
  end

  @doc """
  Performs a lexicographically smallest topological sort. Compares by node_data. Breaks tie
  by ID.

  Time Complexity: O((V + E) log V) due to priority queue operations
  """
  @spec lexicographical_topological_sort(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_topological_sort(graph, compare_nodes) do
    out_edges = graph.out_edges
    in_edges = graph.in_edges
    node_map = graph.nodes
    total_count = Yog.Model.order(graph)

    in_degrees =
      :maps.fold(
        fn id, _, acc ->
          deg =
            case Map.fetch(in_edges, id) do
              {:ok, inner} -> map_size(inner)
              :error -> 0
            end

          Map.put(acc, id, deg)
        end,
        %{},
        node_map
      )

    pq =
      PQ.new(fn {data_a, id_a}, {data_b, id_b} ->
        res = compare_nodes.(data_a, data_b)
        res == :lt or (res == :eq and id_a <= id_b)
      end)

    initial_pq =
      :maps.fold(
        fn id, _, acc_pq ->
          if Map.fetch!(in_degrees, id) == 0 do
            data = Map.fetch!(node_map, id)
            PQ.push(acc_pq, {data, id})
          else
            acc_pq
          end
        end,
        pq,
        node_map
      )

    do_lex_kahn(out_edges, node_map, initial_pq, in_degrees, [], 0, total_count, compare_nodes)
  end

  # Kahn's algorithm with simple queue (list)
  defp do_kahn(_out, [], _degrees, acc, size, total_count) do
    if size == total_count, do: {:ok, Enum.reverse(acc)}, else: {:error, :contains_cycle}
  end

  defp do_kahn(out, [head | tail], degrees, acc, size, total_count) do
    neighbors = Map.get(out, head)

    {next_q, next_degrees} =
      if neighbors && map_size(neighbors) > 0 do
        :maps.fold(
          fn nb, _, {q_acc, deg_acc} ->
            new_deg = Map.fetch!(deg_acc, nb) - 1
            new_deg_acc = Map.put(deg_acc, nb, new_deg)

            if new_deg == 0 do
              {[nb | q_acc], new_deg_acc}
            else
              {q_acc, new_deg_acc}
            end
          end,
          {tail, degrees},
          neighbors
        )
      else
        {tail, degrees}
      end

    do_kahn(out, next_q, next_degrees, [head | acc], size + 1, total_count)
  end

  # Lexicographic Kahn's with priority queue
  defp do_lex_kahn(_out, _nodes, _pq, _degrees, acc, size, total_count, _)
       when size == total_count and total_count > 0 do
    {:ok, Enum.reverse(acc)}
  end

  defp do_lex_kahn(_out, _nodes, _pq, _degrees, _acc, 0, 0, _) do
    {:ok, []}
  end

  defp do_lex_kahn(out, nodes, pq, degrees, acc, size, total_count, compare) do
    if PQ.empty?(pq) do
      if size == total_count do
        {:ok, Enum.reverse(acc)}
      else
        {:error, :contains_cycle}
      end
    else
      {:ok, {_, head}, rest_pq} = PQ.pop(pq)

      neighbors = Map.get(out, head)

      {next_pq, next_degrees} =
        if neighbors && map_size(neighbors) > 0 do
          :maps.fold(
            fn nb, _, {acc_pq, deg_acc} ->
              current_degree = Map.fetch!(deg_acc, nb)
              new_degree = current_degree - 1
              new_deg_acc = Map.put(deg_acc, nb, new_degree)

              if new_degree == 0 do
                neighbor_data = Map.fetch!(nodes, nb)
                {PQ.push(acc_pq, {neighbor_data, nb}), new_deg_acc}
              else
                {acc_pq, new_deg_acc}
              end
            end,
            {rest_pq, degrees},
            neighbors
          )
        else
          {rest_pq, degrees}
        end

      do_lex_kahn(out, nodes, next_pq, next_degrees, [head | acc], size + 1, total_count, compare)
    end
  end
end
