defmodule Yog.Traversal.Implicit do
  @moduledoc """
  Implicit graph traversal — BFS, DFS, Best-First, and Random on graphs defined by
  successor functions rather than materialized data structures.
  """

  alias Yog.PriorityQueue, as: PQ

  @doc """
  Traverse implicit graphs using BFS, DFS, Best-First, or Random order
  without materializing a `Graph`.

  ## Options
  - `:from`: Starting node.
  - `:using`: Traversal order. Options:
    - `:breadth_first` (BFS)
    - `:depth_first` (DFS)
    - `:best_first` - Prioritizes discovery based on a `:priority` function.
    - `:random` - Randomizes discovery order.
  - `:priority`: Required if `:using` is `:best_first`. A function taking `(node_id, meta)`.
  - `:successors_of`: Function returning `[node_id]`.
  - `:initial`: Initial accumulator.
  - `:with`: Folder function `(acc, node_id, meta)`.
  """
  @spec implicit_fold(keyword()) :: any()
  def implicit_fold(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    start_meta = %{depth: 0, parent: nil}

    case order do
      :breadth_first ->
        do_implicit_bfs(
          :queue.in({from, start_meta}, :queue.new()),
          MapSet.new(),
          initial,
          successors,
          folder
        )

      :depth_first ->
        do_implicit_dfs(
          [{from, start_meta}],
          MapSet.new(),
          initial,
          successors,
          folder
        )

      :best_first ->
        priority_fn = Keyword.fetch!(opts, :priority)

        do_implicit_best_first(
          PQ.new(fn {p1, _}, {p2, _} -> p1 <= p2 end)
          |> PQ.push({0, {from, start_meta}}),
          MapSet.new(),
          initial,
          successors,
          folder,
          priority_fn
        )

      :random ->
        do_implicit_best_first(
          PQ.new(fn {p1, _}, {p2, _} -> p1 <= p2 end)
          |> PQ.push({0, {from, start_meta}}),
          MapSet.new(),
          initial,
          successors,
          folder,
          fn _id, _meta -> :rand.uniform() end
        )
    end
  end

  @doc """
  Like `implicit_fold/1`, but deduplicates visited nodes by a custom key.
  """
  @spec implicit_fold_by(keyword()) :: any()
  def implicit_fold_by(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    key_fn = Keyword.fetch!(opts, :visited_by)
    folder = Keyword.fetch!(opts, :with)

    start_meta = %{depth: 0, parent: nil}

    case order do
      :breadth_first ->
        do_implicit_bfs_by(
          :queue.in({from, start_meta}, :queue.new()),
          MapSet.new(),
          initial,
          successors,
          key_fn,
          folder
        )

      :depth_first ->
        do_implicit_dfs_by(
          [{from, start_meta}],
          MapSet.new(),
          initial,
          successors,
          key_fn,
          folder
        )

      :best_first ->
        priority_fn = Keyword.fetch!(opts, :priority)

        do_implicit_best_first_by(
          PQ.new(fn {p1, _}, {p2, _} -> p1 <= p2 end)
          |> PQ.push({0, {from, start_meta}}),
          MapSet.new(),
          initial,
          successors,
          key_fn,
          folder,
          priority_fn
        )

      :random ->
        do_implicit_best_first_by(
          PQ.new(fn {p1, _}, {p2, _} -> p1 <= p2 end)
          |> PQ.push({0, {from, start_meta}}),
          MapSet.new(),
          initial,
          successors,
          key_fn,
          folder,
          fn _id, _meta -> :rand.uniform() end
        )
    end
  end

  @doc """
  Traverse an implicit weighted graph using Dijkstra's algorithm.
  """
  @spec implicit_dijkstra(keyword()) :: any()
  def implicit_dijkstra(opts) do
    from = Keyword.fetch!(opts, :from)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    frontier =
      PQ.new(fn {cost_a, _}, {cost_b, _} -> cost_a <= cost_b end)
      |> PQ.push({0, from})

    best = %{}

    do_implicit_dijkstra_pq(frontier, best, initial, successors, folder)
  end

  # Implicit BFS
  defp do_implicit_bfs(q, visited, acc, successors, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        if MapSet.member?(visited, node_id) do
          do_implicit_bfs(rest, visited, acc, successors, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_bfs(rest, new_visited, new_acc, successors, folder)

            :continue ->
              next_queue =
                Enum.reduce(successors.(node_id), rest, fn next_id, q2 ->
                  :queue.in(
                    {next_id, %{depth: metadata.depth + 1, parent: node_id}},
                    q2
                  )
                end)

              do_implicit_bfs(next_queue, new_visited, new_acc, successors, folder)
          end
        end
    end
  end

  # Implicit DFS
  defp do_implicit_dfs(stack, visited, acc, successors, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        if MapSet.member?(visited, node_id) do
          do_implicit_dfs(tail, visited, acc, successors, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_dfs(tail, new_visited, new_acc, successors, folder)

            :continue ->
              next_stack =
                Enum.reduce(Enum.reverse(successors.(node_id)), tail, fn next_id, stk ->
                  [{next_id, %{depth: metadata.depth + 1, parent: node_id}} | stk]
                end)

              do_implicit_dfs(next_stack, new_visited, new_acc, successors, folder)
          end
        end
    end
  end

  # Implicit BFS with custom key function for deduplication
  defp do_implicit_bfs_by(q, visited, acc, successors, key_fn, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        node_key = key_fn.(node_id)

        if MapSet.member?(visited, node_key) do
          do_implicit_bfs_by(rest, visited, acc, successors, key_fn, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_key)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_bfs_by(rest, new_visited, new_acc, successors, key_fn, folder)

            :continue ->
              next_queue =
                Enum.reduce(successors.(node_id), rest, fn next_id, q2 ->
                  :queue.in(
                    {next_id, %{depth: metadata.depth + 1, parent: node_id}},
                    q2
                  )
                end)

              do_implicit_bfs_by(next_queue, new_visited, new_acc, successors, key_fn, folder)
          end
        end
    end
  end

  # Implicit DFS with custom key function for deduplication
  defp do_implicit_dfs_by(stack, visited, acc, successors, key_fn, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        node_key = key_fn.(node_id)

        if MapSet.member?(visited, node_key) do
          do_implicit_dfs_by(tail, visited, acc, successors, key_fn, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_key)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_dfs_by(tail, new_visited, new_acc, successors, key_fn, folder)

            :continue ->
              next_stack =
                Enum.reduce(Enum.reverse(successors.(node_id)), tail, fn next_id, stk ->
                  [{next_id, %{depth: metadata.depth + 1, parent: node_id}} | stk]
                end)

              do_implicit_dfs_by(next_stack, new_visited, new_acc, successors, key_fn, folder)
          end
        end
    end
  end

  # Implicit Dijkstra with priority queue
  defp do_implicit_dijkstra_pq(pq, best, acc, successors, folder) do
    if PQ.empty?(pq) do
      acc
    else
      {:ok, {cost, node}, rest_pq} = PQ.pop(pq)

      case Map.get(best, node) do
        nil ->
          new_best = Map.put(best, node, cost)
          {control, new_acc} = folder.(acc, node, cost)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_implicit_dijkstra_pq(rest_pq, new_best, new_acc, successors, folder)

            :continue ->
              next_pq =
                Enum.reduce(successors.(node), rest_pq, fn {nb_node, edge_cost}, acc_pq ->
                  new_cost = cost + edge_cost

                  case Map.get(new_best, nb_node) do
                    nil -> PQ.push(acc_pq, {new_cost, nb_node})
                    prev_cost when prev_cost <= new_cost -> acc_pq
                    _ -> PQ.push(acc_pq, {new_cost, nb_node})
                  end
                end)

              do_implicit_dijkstra_pq(next_pq, new_best, new_acc, successors, folder)
          end

        prev_cost when prev_cost < cost ->
          do_implicit_dijkstra_pq(rest_pq, best, acc, successors, folder)

        _ ->
          do_implicit_dijkstra_pq(rest_pq, best, acc, successors, folder)
      end
    end
  end

  defp do_implicit_best_first(pq, visited, acc, successors, folder, priority_fn) do
    if PQ.empty?(pq) do
      acc
    else
      {:ok, {_priority, {node_id, meta}}, rest_pq} = PQ.pop(pq)

      if MapSet.member?(visited, node_id) do
        do_implicit_best_first(rest_pq, visited, acc, successors, folder, priority_fn)
      else
        {control, new_acc} = folder.(acc, node_id, meta)
        new_visited = MapSet.put(visited, node_id)

        case control do
          :halt ->
            new_acc

          :stop ->
            do_implicit_best_first(rest_pq, new_visited, new_acc, successors, folder, priority_fn)

          :continue ->
            next_pq =
              Enum.reduce(successors.(node_id), rest_pq, fn next_id, q_acc ->
                next_meta = %{depth: meta.depth + 1, parent: node_id}
                p = priority_fn.(next_id, next_meta)
                PQ.push(q_acc, {p, {next_id, next_meta}})
              end)

            do_implicit_best_first(next_pq, new_visited, new_acc, successors, folder, priority_fn)
        end
      end
    end
  end

  defp do_implicit_best_first_by(pq, visited, acc, successors, key_fn, folder, priority_fn) do
    if PQ.empty?(pq) do
      acc
    else
      {:ok, {_priority, {node_id, meta}}, rest_pq} = PQ.pop(pq)
      node_key = key_fn.(node_id)

      if MapSet.member?(visited, node_key) do
        do_implicit_best_first_by(rest_pq, visited, acc, successors, key_fn, folder, priority_fn)
      else
        {control, new_acc} = folder.(acc, node_id, meta)
        new_visited = MapSet.put(visited, node_key)

        case control do
          :halt ->
            new_acc

          :stop ->
            do_implicit_best_first_by(
              rest_pq,
              new_visited,
              new_acc,
              successors,
              key_fn,
              folder,
              priority_fn
            )

          :continue ->
            next_pq =
              Enum.reduce(successors.(node_id), rest_pq, fn next_id, q_acc ->
                next_meta = %{depth: meta.depth + 1, parent: node_id}
                p = priority_fn.(next_id, next_meta)
                PQ.push(q_acc, {p, {next_id, next_meta}})
              end)

            do_implicit_best_first_by(
              next_pq,
              new_visited,
              new_acc,
              successors,
              key_fn,
              folder,
              priority_fn
            )
        end
      end
    end
  end
end
