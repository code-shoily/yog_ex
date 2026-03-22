defmodule Yog.Pathfinding.BidirectionalTest do
  use ExUnit.Case

  doctest Yog.Pathfinding.Bidirectional

  test "shortest_path returns none for unreachable path" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)

    assert :none ==
             Yog.Pathfinding.Bidirectional.shortest_path_int(
               in: graph,
               from: 1,
               to: 2
             )
  end
end
