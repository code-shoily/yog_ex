defmodule Yog.IO.GEXFHardeningTest do
  use ExUnit.Case
  alias Yog.IO.GEXF
  alias Yog.IO.GEXF.Multi

  test "GEXF.serialize does not crash on tuple IDs" do
    graph =
      Yog.undirected()
      |> Yog.add_node({1, :a}, "Node A")
      |> Yog.add_node({2, :b}, "Node B")
      |> Yog.add_edge_ensure({1, :a}, {2, :b}, "Edge AB")

    assert is_binary(GEXF.serialize(graph))
  end

  test "GEXF.Multi.serialize does not crash on tuple IDs" do
    graph =
      Yog.Multi.Model.undirected()
      |> Yog.Multi.Model.add_node({1, :a}, "Node A")
      |> Yog.Multi.Model.add_node({2, :b}, "Node B")
      |> then(fn g ->
        {new_g, _} = Yog.Multi.Model.add_edge(g, {1, :a}, {2, :b}, "Edge AB")
        new_g
      end)

    assert is_binary(Multi.serialize(graph))
  end
end
