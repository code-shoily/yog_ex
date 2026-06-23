defmodule Yog.Pathfinding.DisjointTest do
  use ExUnit.Case

  alias Yog.Pathfinding.Disjoint

  # =============================================================================
  # Basic functionality
  # =============================================================================

  test "suurballe finds two edge-disjoint paths in simple diamond graph" do
    # s --(1)--> a --(1)--> t
    # \                      /
    #  --(1)--> b --(1)--> t
    #  a --(0.5)--> b
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([:s, :a, :b, :t])
      |> Yog.add_edges!([
        {:s, :a, 1},
        {:a, :t, 1},
        {:s, :b, 1},
        {:b, :t, 1},
        {:a, :b, 0.5}
      ])

    {:ok, paths} = Disjoint.suurballe(graph, :s, :t)

    assert Enum.map(paths, & &1.weight) == [2, 2]
    assert Enum.map(paths, & &1.nodes) |> Enum.sort() == [[:s, :a, :t], [:s, :b, :t]]
  end

  test "suurballe correctly cancels overlapping path segments" do
    # s --(1)--> a --(1)--> b --(1)--> t  (Shortest path, length 3)
    # s --(2.5)--> b
    # a --(2.5)--> t
    # Edge-disjoint paths must cancel the a -> b segment, resulting in:
    # Path 1: s -> a -> t (weight 3.5)
    # Path 2: s -> b -> t (weight 3.5)
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([:s, :a, :b, :t])
      |> Yog.add_edges!([
        {:s, :a, 1},
        {:a, :b, 1},
        {:b, :t, 1},
        {:s, :b, 2.5},
        {:a, :t, 2.5}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, :s, :t)

    # Weights must be exactly 3.5 each
    assert p1.weight == 3.5
    assert p2.weight == 3.5

    # Edge sets must be disjoint
    e1 = Enum.chunk_every(p1.nodes, 2, 1, :discard)
    e2 = Enum.chunk_every(p2.nodes, 2, 1, :discard)
    assert MapSet.disjoint?(MapSet.new(e1), MapSet.new(e2))
  end

  test "disconnected graph returns :error" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3])

    assert Disjoint.suurballe(graph, 1, 3) == :error
  end

  test "graph with only one path returns :error" do
    # 1 -> 2 -> 3  (Only one path exists)
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3])
      |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}])

    assert Disjoint.suurballe(graph, 1, 3) == :error
  end

  test "works on undirected graphs by treating edges as directed bidirectionally" do
    # s -- a -- t
    # \         /
    #  -- b --
    graph =
      Yog.undirected()
      |> Yog.add_nodes_from([:s, :a, :b, :t])
      |> Yog.add_edges!([
        {:s, :a, 1},
        {:a, :t, 1},
        {:s, :b, 2},
        {:b, :t, 2}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, :s, :t)
    assert p1.nodes == [:s, :a, :t]
    assert p1.weight == 2
    assert p2.nodes == [:s, :b, :t]
    assert p2.weight == 4
  end

  test "works on unweighted graphs by defaulting weights to 1" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 2, nil}, {2, 4, nil},
        {1, 3, nil}, {3, 4, nil}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, 1, 4)
    assert p1.weight == 2
    assert p2.weight == 2
  end

  test "facade delegation through Yog.Pathfinding" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 2, 1}, {2, 4, 1},
        {1, 3, 1}, {3, 4, 1}
      ])

    {:ok, [p1, p2]} = Yog.Pathfinding.suurballe(graph, 1, 4)
    assert p1.nodes == [1, 2, 4]
    assert p2.nodes == [1, 3, 4]
  end

  test "handles custom options" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 2, 10}, {2, 4, 10},
        {1, 3, 10}, {3, 4, 10}
      ])

    # Multiply all edge weights by 2
    opts = [weight: fn w -> w * 2 end]
    {:ok, [p1, p2]} = Yog.Pathfinding.suurballe(graph, 1, 4, opts)
    assert p1.weight == 40
    assert p2.weight == 40
  end
end
