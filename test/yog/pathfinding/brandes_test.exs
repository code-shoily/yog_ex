defmodule Yog.Pathfinding.BrandesTest do
  use ExUnit.Case, async: true

  alias Yog.Pathfinding.Brandes

  test "discovery with existing node" do
    # Simple path graph: 1 - 2 - 3
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(1, 2, 1)
      |> Yog.add_edge_ensure(2, 3, 2)

    {stack, preds, sigmas} = Brandes.discovery(graph, 1)

    assert 1 in stack
    assert 2 in stack
    assert 3 in stack
    assert sigmas[1] == 1
    assert sigmas[2] == 1
    assert sigmas[3] == 1
    assert preds[2] == [1]
    assert preds[3] == [2]
  end

  test "discovery with non-existent node returns empty structures" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)

    assert {[], %{}, %{}} = Brandes.discovery(graph, 99)
  end

  test "accumulate_node_dependencies and accumulate_edge_dependencies" do
    # Simple path graph: 1 - 2 - 3
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge_ensure(1, 2, 1)
      |> Yog.add_edge_ensure(2, 3, 1)

    {stack, preds, sigmas} = Brandes.discovery(graph, 1)

    node_deps = Brandes.accumulate_node_dependencies(stack, preds, sigmas)
    # Node 2 is the bottleneck between 1 and 3, so its dependency from 3 is accumulated.
    # dependency of 1 from 3 via 2 is 1.0.
    assert node_deps[2] == 1.0

    edge_deps = Brandes.accumulate_edge_dependencies(stack, preds, sigmas)
    assert edge_deps[{1, 2}] == 2.0
    assert edge_deps[{2, 3}] == 1.0
  end
end
