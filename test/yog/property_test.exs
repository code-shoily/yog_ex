defmodule Yog.PropertyTest do
  use ExUnit.Case
  alias Yog.Property
  alias Yog.Property.WeisfeilerLehman
  doctest Yog.Property

  test "WeisfeilerLehman.graph_hash calculates deterministic hashes" do
    g1 = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
    g2 = Yog.from_edges(:undirected, [{:a, :b, 1}, {:b, :c, 1}])

    assert WeisfeilerLehman.graph_hash(g1) == WeisfeilerLehman.graph_hash(g2)
    assert Property.isomorphic?(g1, g2)
  end

  test "WeisfeilerLehman.graph_hash raises ArgumentError on invalid inputs" do
    assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
      WeisfeilerLehman.graph_hash(:invalid)
    end

    assert_raise ArgumentError, ~r/expected :iterations to be a non-negative integer/, fn ->
      WeisfeilerLehman.graph_hash(Yog.undirected(), iterations: -1)
    end

    assert_raise ArgumentError, ~r/expected :node_label_fn to be a 2-arity function/, fn ->
      WeisfeilerLehman.graph_hash(Yog.undirected(), node_label_fn: :not_a_func)
    end
  end
end
