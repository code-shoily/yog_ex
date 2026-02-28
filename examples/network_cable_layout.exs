defmodule NetworkCableLayout do
  @moduledoc """
  Network Cable Layout Example

  Demonstrates Minimum Spanning Tree using Kruskal's algorithm
  """

  require Yog

  def run do
    buildings =
      Yog.undirected()
      |> Yog.add_node(1, "Building A")
      |> Yog.add_node(2, "Building B")
      |> Yog.add_node(3, "Building C")
      |> Yog.add_node(4, "Building D")
      |> Yog.add_edge(from: 1, to: 2, with: 100)
      |> Yog.add_edge(from: 1, to: 3, with: 150)
      |> Yog.add_edge(from: 2, to: 3, with: 50)
      |> Yog.add_edge(from: 2, to: 4, with: 200)
      |> Yog.add_edge(from: 3, to: 4, with: 100)

    cables = Yog.MST.kruskal(
      in: buildings,
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
    )

    total_cost = Enum.reduce(cables, 0, fn edge, sum -> sum + edge.weight end)

    IO.puts("Minimum cable cost is #{total_cost}")
  end
end

NetworkCableLayout.run()
