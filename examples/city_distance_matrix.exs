defmodule CityDistanceMatrix do
  @moduledoc """
  City Distance Matrix Example

  Demonstrates Floyd-Warshall for all-pairs shortest paths
  """

  require Yog

  def run do
    # Create a graph of 4 cities
    graph =
      Yog.directed()
      |> Yog.add_node(1, "City A")
      |> Yog.add_node(2, "City B")
      |> Yog.add_node(3, "City C")
      |> Yog.add_node(4, "City D")
      |> Yog.add_edge(from: 1, to: 2, with: 3)
      |> Yog.add_edge(from: 2, to: 1, with: 8)
      |> Yog.add_edge(from: 1, to: 4, with: 7)
      |> Yog.add_edge(from: 4, to: 1, with: 2)
      |> Yog.add_edge(from: 2, to: 3, with: 2)
      |> Yog.add_edge(from: 3, to: 1, with: 5)
      |> Yog.add_edge(from: 3, to: 4, with: 1)

    IO.puts("--- All-Pairs Shortest Paths (Floyd-Warshall) ---")

    case Yog.Pathfinding.floyd_warshall(
      in: graph,
      zero: 0,
      add: &(&1 + &2),
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
    ) do
      {:ok, matrix} ->
        # Matrix is Map(NodeId => Map(NodeId => Weight))
        Enum.each(matrix, fn {from, rows} ->
          Enum.each(rows, fn {to, weight} ->
            IO.puts("From #{from} to #{to}: #{weight}")
          end)
        end)

      {:error, _} ->
        IO.puts("Negative cycle detected!")
    end
  end
end

CityDistanceMatrix.run()
