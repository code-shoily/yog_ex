defmodule YogGeneratorsRandomTest do
  use ExUnit.Case

  alias Yog.Generators.Random

  # ============= Erdős-Rényi G(n,p) Tests =============

  test "erdos_renyi_gnp_basic_test" do
    graph = Random.erdos_renyi_gnp(10, 0.0)

    assert length(Yog.all_nodes(graph)) == 10
  end

  test "erdos_renyi_gnp_complete_test" do
    graph = Random.erdos_renyi_gnp(5, 1.0)

    # With p=1, should be complete
    assert length(Yog.all_nodes(graph)) == 5
  end

  # ============= Erdős-Rényi G(n,m) Tests =============

  test "erdos_renyi_gnm_basic_test" do
    graph = Random.erdos_renyi_gnm(10, 15)

    assert length(Yog.all_nodes(graph)) == 10
  end

  # ============= Barabási-Albert Tests =============

  test "barabasi_albert_basic_test" do
    graph = Random.barabasi_albert(20, 3)

    assert length(Yog.all_nodes(graph)) == 20
  end

  test "barabasi_albert_connected_test" do
    graph = Random.barabasi_albert(30, 2)

    # BA graphs are always connected
    comps = Yog.Components.scc(graph)
    assert length(comps) == 1
  end

  # ============= Watts-Strogatz Tests =============

  test "watts_strogatz_basic_test" do
    graph = Random.watts_strogatz(20, 4, 0.0)

    assert length(Yog.all_nodes(graph)) == 20
  end

  # ============= Random Tree Tests =============

  test "random_tree_basic_test" do
    graph = Random.random_tree(10)

    assert length(Yog.all_nodes(graph)) == 10
  end

  test "random_tree_connected_test" do
    graph = Random.random_tree(20)

    # Tree should be connected
    comps = Yog.Components.scc(graph)
    assert length(comps) == 1
  end

  # ============= Property Tests =============

  test "all_generators_respect_node_count_test" do
    n = 15

    graphs = [
      Random.erdos_renyi_gnp(n, 0.3),
      Random.erdos_renyi_gnm(n, 20),
      Random.barabasi_albert(n, 3),
      Random.watts_strogatz(n, 4, 0.1),
      Random.random_tree(n)
    ]

    assert Enum.all?(graphs, fn g -> length(Yog.all_nodes(g)) == n end)
  end
end
