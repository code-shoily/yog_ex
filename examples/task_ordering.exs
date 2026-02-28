defmodule TaskOrdering do
  @moduledoc """
  Task Ordering Example

  Demonstrates lexicographical topological sort
  """

  require Yog

  def run do
    # Dependencies: C must complete before A
    dependencies = [{"C", "A"}]

    tasks = ["A", "B", "C", "D"]

    # Convert task names to ASCII values for lexicographical ordering
    task_to_id = tasks
                 |> Enum.with_index()
                 |> Enum.map(fn {task, idx} -> {task, idx + 1} end)
                 |> Map.new()

    id_to_task = task_to_id
                 |> Enum.map(fn {k, v} -> {v, k} end)
                 |> Map.new()

    graph = dependencies
            |> Enum.reduce(Yog.directed(), fn {from, to}, g ->
              from_id = task_to_id[from]
              to_id = task_to_id[to]
              g
              |> Yog.add_node(from_id, from)
              |> Yog.add_node(to_id, to)
              |> Yog.add_edge(from: from_id, to: to_id, with: nil)
            end)

    # Add any tasks that weren't in dependencies
    graph = tasks
            |> Enum.reduce(graph, fn task, g ->
              task_id = task_to_id[task]
              Yog.add_node(g, task_id, task)
            end)

    case Yog.TopologicalSort.lexicographical_sort(
      graph,
      fn a, b ->
        task_a = id_to_task[a]
        task_b = id_to_task[b]
        cond do
          task_a < task_b -> :lt
          task_a > task_b -> :gt
          true -> :eq
        end
      end
    ) do
      {:ok, order} ->
        task_names = order
                     |> Enum.map(fn id -> id_to_task[id] end)
                     |> Enum.join(", ")
        IO.puts("Lexicographical task order: #{task_names}")

      {:error, :contains_cycle} ->
        IO.puts("Circular dependency detected!")
    end
  end
end

TaskOrdering.run()
