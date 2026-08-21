defmodule Yog.Property.TreeDecompositionTest do
  use ExUnit.Case
  alias Yog.Property.TreeDecomposition
  doctest TreeDecomposition

  test "valid?/2 returns true for valid tree decomposition" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
    {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert TreeDecomposition.valid?(td, graph)
  end

  test "valid?/2 raises ArgumentError on invalid struct inputs" do
    graph = Yog.from_edges(:undirected, [{1, 2, 1}])
    {:ok, td} = Yog.Approximate.tree_decomposition(graph)

    assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
      TreeDecomposition.valid?(td, :invalid)
    end

    assert_raise ArgumentError, ~r/expected a Yog.Property.TreeDecomposition struct/, fn ->
      TreeDecomposition.valid?(:invalid, graph)
    end
  end
end
