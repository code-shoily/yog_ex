defmodule TaskScheduling do
  @moduledoc """
  Task Scheduling Example

  Demonstrates basic component ordering using topological sort.
  """

  require Yog

  def run do
    # Model tasks with dependencies
    tasks =
      Yog.directed()
      |> Yog.add_node(1, "Design")
      |> Yog.add_node(2, "Implement")
      |> Yog.add_node(3, "Test")
      |> Yog.add_node(4, "Deploy")
      # Design before Implement
      |> Yog.add_edge(from: 1, to: 2, with: nil)
      # Implement before Test
      |> Yog.add_edge(from: 2, to: 3, with: nil)
      # Test before Deploy
      |> Yog.add_edge(from: 3, to: 4, with: nil)

    case Yog.TopologicalSort.sort(tasks) do
      {:ok, order} ->
        # order = [1, 2, 3, 4] - valid execution order
        IO.puts("Execute tasks in order: #{inspect(order)}")

      {:error, :not_a_dag} ->
        IO.puts("Circular dependency detected!")
    end
  end
end

TaskScheduling.run()
