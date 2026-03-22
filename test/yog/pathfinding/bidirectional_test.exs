defmodule Yog.Pathfinding.BidirectionalTest do
  use ExUnit.Case

  alias Yog.Pathfinding.Bidirectional

  doctest Bidirectional

  test "shortest_path returns none for unreachable path" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)

    assert :none ==
             Bidirectional.shortest_path_int(
               in: graph,
               from: 1,
               to: 2
             )
  end
end
