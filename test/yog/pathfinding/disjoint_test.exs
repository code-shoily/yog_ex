defmodule Yog.Pathfinding.DisjointTest do
  use ExUnit.Case

  doctest Yog.Pathfinding.Disjoint

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
        {1, 2, nil},
        {2, 4, nil},
        {1, 3, nil},
        {3, 4, nil}
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
        {1, 2, 1},
        {2, 4, 1},
        {1, 3, 1},
        {3, 4, 1}
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
        {1, 2, 10},
        {2, 4, 10},
        {1, 3, 10},
        {3, 4, 10}
      ])

    # Multiply all edge weights by 2
    opts = [weight: fn w -> w * 2 end]
    {:ok, [p1, p2]} = Yog.Pathfinding.suurballe(graph, 1, 4, opts)
    assert p1.weight == 40
    assert p2.weight == 40
  end

  # =============================================================================
  # Edge cases
  # =============================================================================

  test "from == to returns :error (no two distinct disjoint paths)" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2])
      |> Yog.add_edges!([{1, 2, 1}])

    assert Disjoint.suurballe(graph, 1, 1) == :error
  end

  test "two-node graph with two parallel directed edges" do
    # Minimal disjoint pair: a → b via two separate routes through intermediaries
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 4, 1},
        {1, 3, 1},
        {3, 4, 1}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, 1, 4)

    assert p1.weight == 2
    assert p2.weight == 2

    # Verify edge-disjointness
    e1 = Enum.chunk_every(p1.nodes, 2, 1, :discard)
    e2 = Enum.chunk_every(p2.nodes, 2, 1, :discard)
    assert MapSet.disjoint?(MapSet.new(e1), MapSet.new(e2))
  end

  test "self-loop on source does not corrupt results" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 1, 1},
        {1, 2, 1},
        {2, 4, 1},
        {1, 3, 2},
        {3, 4, 2}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, 1, 4)

    # Self-loop should not appear in either path
    refute 1 in tl(Enum.take(p1.nodes, Kernel.length(p1.nodes) - 1)) and
             hd(p1.nodes) == 1 and
             List.last(p1.nodes) == 1 and
             Kernel.length(p1.nodes) == 2

    # Paths should still reach the target
    assert hd(p1.nodes) == 1
    assert List.last(p1.nodes) == 4
    assert hd(p2.nodes) == 1
    assert List.last(p2.nodes) == 4
  end

  test "asymmetric weights produce correct sort order" do
    # Path 1→2→4 costs 2, Path 1→3→4 costs 10
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 4, 1},
        {1, 3, 5},
        {3, 4, 5}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, 1, 4)

    # First path should be the lighter one
    assert p1.weight <= p2.weight
    assert p1.weight == 2
    assert p2.weight == 10
  end

  test "graph with more than 2 disjoint paths returns exactly 2 optimal" do
    # Three disjoint s→t paths with costs 2, 4, 6
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([:s, :a, :b, :c, :t])
      |> Yog.add_edges!([
        {:s, :a, 1},
        {:a, :t, 1},
        {:s, :b, 2},
        {:b, :t, 2},
        {:s, :c, 3},
        {:c, :t, 3}
      ])

    {:ok, paths} = Disjoint.suurballe(graph, :s, :t)

    assert Kernel.length(paths) == 2

    # Should pick the two cheapest paths (cost 2 and cost 4)
    [p1, p2] = paths
    assert p1.weight == 2
    assert p2.weight == 4
  end

  test "large integer weights do not cause errors" do
    big = 1_000_000_000

    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4])
      |> Yog.add_edges!([
        {1, 2, big},
        {2, 4, big},
        {1, 3, big},
        {3, 4, big}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, 1, 4)
    assert p1.weight == 2 * big
    assert p2.weight == 2 * big
  end

  test "nodes exist but no edges returns :error" do
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([1, 2, 3, 4, 5])

    assert Disjoint.suurballe(graph, 1, 5) == :error
  end

  test "disjoint paths sharing an intermediate node are traced correctly" do
    # Two edge-disjoint paths share node :v:
    # Path 1: s → a → v → b → t  (cost 4)
    # Path 2: s → c → v → d → t  (cost 4)
    # The old Map.new adjacency would drop one of v's outgoing edges.
    graph =
      Yog.directed()
      |> Yog.add_nodes_from([:s, :a, :b, :c, :d, :v, :t])
      |> Yog.add_edges!([
        {:s, :a, 1},
        {:a, :v, 1},
        {:v, :b, 1},
        {:b, :t, 1},
        {:s, :c, 1},
        {:c, :v, 1},
        {:v, :d, 1},
        {:d, :t, 1}
      ])

    {:ok, [p1, p2]} = Disjoint.suurballe(graph, :s, :t)

    # Both paths must start at :s and end at :t
    assert hd(p1.nodes) == :s
    assert List.last(p1.nodes) == :t
    assert hd(p2.nodes) == :s
    assert List.last(p2.nodes) == :t

    # Paths must be edge-disjoint
    e1 = Enum.chunk_every(p1.nodes, 2, 1, :discard)
    e2 = Enum.chunk_every(p2.nodes, 2, 1, :discard)
    assert MapSet.disjoint?(MapSet.new(e1), MapSet.new(e2))

    # Total cost should be 8 (4 + 4)
    assert p1.weight + p2.weight == 8
  end
end
