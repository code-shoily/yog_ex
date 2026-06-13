defmodule FunctionalExample do
  @moduledoc """
  Functional Graph Example

  Demonstrates pure functional graph operations using inductive decomposition.
  """

  alias Yog.Functional.{Algorithms, Model}

  def run do
    # Create an inductive functional graph
    graph =
      Model.empty()
      |> Model.put_node(1, "A")
      |> Model.put_node(2, "B")
      |> Model.put_node(3, "C")
      |> Model.add_edge!(1, 2, 1)
      |> Model.add_edge!(2, 3, 2)

    # Inductive Top-Sort
    {:ok, order} = Algorithms.topsort(graph)
    IO.puts("Inductive topological sort order: #{inspect(order)}")

    # Inductive Dijkstra
    {:ok, path, weight} = Algorithms.shortest_path(graph, 1, 3)
    IO.puts("Inductive shortest path: #{inspect(path)} with weight: #{weight}")
  end
end

FunctionalExample.run()
