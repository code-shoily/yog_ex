defmodule Yog.Zog.PropertyTest do
  use ExUnit.Case, async: true

  alias Yog.Zog.Property

  test "native all_maximal_cliques: complete graph K4" do
    builder =
      Yog.Builder.Zog.undirected()
      |> Yog.Builder.Zog.add_edge("A", "B", 1.0)
      |> Yog.Builder.Zog.add_edge("A", "C", 1.0)
      |> Yog.Builder.Zog.add_edge("A", "D", 1.0)
      |> Yog.Builder.Zog.add_edge("B", "C", 1.0)
      |> Yog.Builder.Zog.add_edge("B", "D", 1.0)
      |> Yog.Builder.Zog.add_edge("C", "D", 1.0)

    cliques = Property.all_maximal_cliques(builder)
    assert length(cliques) == 1
    assert MapSet.new(["A", "B", "C", "D"]) in cliques

    max_c = Property.max_clique(builder)
    assert MapSet.size(max_c) == 4
  end

  test "native all_maximal_cliques: disjoint triangles" do
    builder =
      Yog.Builder.Zog.undirected()
      # Triangle 1
      |> Yog.Builder.Zog.add_edge("a1", "a2", 1.0)
      |> Yog.Builder.Zog.add_edge("a2", "a3", 1.0)
      |> Yog.Builder.Zog.add_edge("a3", "a1", 1.0)
      # Triangle 2
      |> Yog.Builder.Zog.add_edge("b1", "b2", 1.0)
      |> Yog.Builder.Zog.add_edge("b2", "b3", 1.0)
      |> Yog.Builder.Zog.add_edge("b3", "b1", 1.0)

    cliques = Property.all_maximal_cliques(builder)
    assert length(cliques) == 2
    assert MapSet.new(["a1", "a2", "a3"]) in cliques
    assert MapSet.new(["b1", "b2", "b3"]) in cliques
  end
end
