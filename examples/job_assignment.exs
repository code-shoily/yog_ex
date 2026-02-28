defmodule JobAssignment do
  @moduledoc """
  Job Assignment Example

  Demonstrates bipartite maximum matching
  """

  require Yog

  def run do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Charlie")
      |> Yog.add_node(4, "Programming")
      |> Yog.add_node(5, "Design")
      |> Yog.add_node(6, "Testing")
      |> Yog.add_edge(from: 1, to: 4, with: nil)
      |> Yog.add_edge(from: 1, to: 5, with: nil)
      |> Yog.add_edge(from: 2, to: 4, with: nil)
      |> Yog.add_edge(from: 3, to: 5, with: nil)
      |> Yog.add_edge(from: 3, to: 6, with: nil)

    IO.puts("--- Bipartite Job Assignment ---")

    case Yog.Bipartite.partition(graph) do
      {:ok, partition} ->
        matching = Yog.Bipartite.maximum_matching(graph, partition)
        IO.puts("Maximum assignments found: #{length(matching)}")

        Enum.each(matching, fn {worker_id, task_id} ->
          IO.puts("Worker #{worker_id} -> Task #{task_id}")
        end)

      {:error, _} ->
        IO.puts("This graph is not bipartite!")
    end
  end
end

JobAssignment.run()
