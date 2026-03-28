defmodule Yog.Property.CyclicityTest do
  use ExUnit.Case

  alias Yog.Property.Cyclicity

  doctest Yog.Property.Cyclicity

  # ============= Acyclic Tests =============

  test "acyclic_empty_graph_test" do
    graph = Yog.directed()
    assert Cyclicity.acyclic?(graph) == true
  end

  test "acyclic_single_node_test" do
    graph = Yog.directed() |> Yog.add_node(1, "A")
    assert Cyclicity.acyclic?(graph) == true
  end

  test "acyclic_simple_dag_test" do
    # Simple DAG: 1 -> 2 -> 3
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

    assert Cyclicity.acyclic?(graph) == true
  end

  test "acyclic_undirected_tree_test" do
    # Tree is acyclic
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 1)

    assert Cyclicity.acyclic?(graph) == true
  end

  # ============= Cyclic Tests =============

  test "cyclic_self_loop_test" do
    # Self loop creates a cycle
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_edge_ensure(from: 1, to: 1, with: 1)

    assert Cyclicity.cyclic?(graph) == true
    assert Cyclicity.acyclic?(graph) == false
  end

  test "cyclic_simple_directed_cycle_test" do
    # Simple cycle: 1 -> 2 -> 3 -> 1
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    assert Cyclicity.cyclic?(graph) == true
    assert Cyclicity.acyclic?(graph) == false
  end

  test "cyclic_undirected_triangle_test" do
    # Triangle is cyclic in undirected graph
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    assert Cyclicity.cyclic?(graph) == true
    assert Cyclicity.acyclic?(graph) == false
  end

  test "cyclic_complex_dag_with_cycle_test" do
    # DAG with one back edge creating a cycle
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      # Back edge creates cycle
      |> Yog.add_edge_ensure(from: 4, to: 1, with: 1)

    assert Cyclicity.cyclic?(graph) == true
    assert Cyclicity.acyclic?(graph) == false
  end

  # ============= Edge Cases =============

  test "acyclic_dag_diamond_test" do
    # Diamond DAG (no cycles)
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    assert Cyclicity.acyclic?(graph) == true
    assert Cyclicity.cyclic?(graph) == false
  end

  test "cyclic_empty_graph_is_acyclic_test" do
    graph = Yog.directed()

    assert Cyclicity.acyclic?(graph) == true
    assert Cyclicity.cyclic?(graph) == false
  end

  test "acyclic_disconnected_components_test" do
    # Two separate acyclic components
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    assert Cyclicity.acyclic?(graph) == true
    assert Cyclicity.cyclic?(graph) == false
  end

  test "cyclic_directed_2_cycle_test" do
    # 1 <-> 2
    g = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 1, 1, nil)
    assert Cyclicity.cyclic?(g)
  end

  test "cyclic_large_c6_test" do
    g =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 4, 1, nil)
      |> Yog.add_edge_ensure(4, 5, 1, nil)
      |> Yog.add_edge_ensure(5, 6, 1, nil)
      |> Yog.add_edge_ensure(6, 1, 1, nil)

    assert Cyclicity.cyclic?(g)
  end
end
