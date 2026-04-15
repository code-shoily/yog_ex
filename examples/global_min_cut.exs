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
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 5, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 5, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 6, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 7, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 8, with: 1)
      |> Yog.add_edge_ensure(from: 4, to: 7, with: 1)
      |> Yog.add_edge_ensure(from: 4, to: 8, with: 1)
      |> Yog.add_edge_ensure(from: 7, to: 8, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 5, to: 3, with: 1)

    IO.puts("--- Global Minimum Cut ---")
    result = Yog.Flow.MinCut.global_min_cut(graph)

    IO.puts("Min cut weight: #{result.cut_value}")
    IO.puts("Group A size: #{result.source_side_size}")
    IO.puts("Group B size: #{result.sink_side_size}")

    answer = result.source_side_size * result.sink_side_size
    IO.puts("Multiplied sizes (AoC style): #{answer}")
  end
end

GlobalMinCut.run()
