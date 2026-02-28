defmodule GlobalMinCut do
  @moduledoc """
  Global Minimum Cut Example

  Demonstrates the Stoer-Wagner algorithm for finding global minimum cut
  """

  require Yog

  def run do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "a")
      |> Yog.add_node(2, "b")
      |> Yog.add_node(3, "c")
      |> Yog.add_node(4, "d")
      |> Yog.add_node(5, "e")
      |> Yog.add_node(6, "f")
      |> Yog.add_node(7, "g")
      |> Yog.add_node(8, "h")
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 5, weight: 1)
      |> Yog.add_edge(from: 2, to: 5, weight: 1)
      |> Yog.add_edge(from: 2, to: 6, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)
      |> Yog.add_edge(from: 3, to: 7, weight: 1)
      |> Yog.add_edge(from: 3, to: 8, weight: 1)
      |> Yog.add_edge(from: 4, to: 7, weight: 1)
      |> Yog.add_edge(from: 4, to: 8, weight: 1)
      |> Yog.add_edge(from: 7, to: 8, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 5, to: 3, weight: 1)

    IO.puts("--- Global Minimum Cut ---")
    result = Yog.MinCut.global_min_cut(graph)

    IO.puts("Min cut weight: #{result.weight}")
    IO.puts("Group A size: #{result.group_a_size}")
    IO.puts("Group B size: #{result.group_b_size}")

    answer = result.group_a_size * result.group_b_size
    IO.puts("Multiplied sizes (AoC style): #{answer}")
  end
end

GlobalMinCut.run()
