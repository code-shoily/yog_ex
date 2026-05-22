defmodule Yog.Property.StructureTest do
  use ExUnit.Case

  alias Yog.Property.Structure
  doctest Structure

  # ============= Tree Tests =============

  test "tree? undirected" do
    # Path is a tree
    g = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 3, 1, nil)
    assert Structure.tree?(g)

    # Cycle is not a tree
    g = g |> Yog.add_edge_ensure(3, 1, 1)
    assert not Structure.tree?(g)

    # Disconnected is not a tree
    g = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
    assert not Structure.tree?(g)

    # Directed is not a tree
    g_dir = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil)
    assert not Structure.tree?(g_dir)
  end

  # ============= Arborescence Tests =============

  test "arborescence?" do
    # Simple star
    g = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(1, 3, 1, nil)
    assert Structure.arborescence?(g)
    assert Structure.arborescence_root(g) == 1

    # Two roots -> not an arborescence
    g2 = Yog.directed() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
    assert not Structure.arborescence?(g2)

    # Cycle -> not an arborescence
    g3 = g |> Yog.add_edge_ensure(3, 1, 1)
    assert not Structure.arborescence?(g3)

    # Node with two parents -> not an arborescence
    g4 = Yog.directed() |> Yog.add_edge_ensure(1, 3, 1, nil) |> Yog.add_edge_ensure(2, 3, 1, nil)
    assert not Structure.arborescence?(g4)
  end

  # ============= Complete Graph Tests =============

  test "complete?" do
    # Empty or single node is complete
    assert Structure.complete?(Yog.undirected())
    assert Structure.complete?(Yog.undirected() |> Yog.add_node(1, nil))

    # K3
    k3 =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 1, 1, nil)

    assert Structure.complete?(k3)

    # Not complete (missing edge)
    not_k3 =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)

    assert not Structure.complete?(not_k3)

    # Self loops make it not complete (by definition here)
    with_loop = k3 |> Yog.add_edge_ensure(1, 1, 1)
    assert not Structure.complete?(with_loop)
  end

  # ============= Regular Graph Tests =============

  test "regular?" do
    # Circle C4 is 2-regular
    c4 =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 4, 1, nil)
      |> Yog.add_edge_ensure(4, 1, 1, nil)

    assert Structure.regular?(c4, 2)
    assert not Structure.regular?(c4, 3)

    # K4 is 3-regular
    nodes = 1..4
    edges = for u <- nodes, v <- nodes, u < v, do: {u, v}

    k4 =
      Enum.reduce(edges, Yog.undirected(), fn {u, v}, acc ->
        Yog.add_edge_ensure(acc, u, v, 1, nil)
      end)

    assert Structure.regular?(k4, 3)
  end

  # ============= Connectivity Tests =============

  test "connected? undirected" do
    g = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1) |> Yog.add_node(3, nil)
    assert not Structure.connected?(g)
    g = g |> Yog.add_edge_ensure(2, 3, 1)
    assert Structure.connected?(g)
  end

  test "strongly_connected? directed" do
    g = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1) |> Yog.add_edge_ensure(2, 1, 1)
    assert Structure.strongly_connected?(g)
    g = g |> Yog.add_edge_ensure(2, 3, 1)
    assert not Structure.strongly_connected?(g)
    g = g |> Yog.add_edge_ensure(3, 1, 1)
    assert Structure.strongly_connected?(g)
  end

  test "weakly_connected? directed" do
    # 1 -> 2, 3 -> 2 (weakly connected but not strongly)
    g = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(3, 2, 1, nil)
    assert not Structure.strongly_connected?(g)
    assert Structure.weakly_connected?(g)

    # Disconnected
    g = g |> Yog.add_node(4, nil)
    assert not Structure.weakly_connected?(g)
  end

  # ============= Forest Tests =============

  test "forest? edge cases" do
    # Empty graph is a forest
    assert Structure.forest?(Yog.undirected())

    # Single tree
    tree =
      Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 3, 1, nil)

    assert Structure.forest?(tree)

    # Multiple disjoint trees
    forest =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(3, 4, 1, nil)
      |> Yog.add_edge_ensure(5, 6, 1, nil)

    assert Structure.forest?(forest)

    # Cycle is not a forest
    cycle =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 1, 1, nil)

    assert not Structure.forest?(cycle)

    # Directed graph is not a forest
    directed = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil)
    assert not Structure.forest?(directed)

    # Single isolated node is a forest
    isolated = Yog.undirected() |> Yog.add_node(1, nil)
    assert Structure.forest?(isolated)
  end

  # ============= Branching Tests =============

  test "branching? edge cases" do
    # Valid branching: two disjoint stars
    branch =
      Yog.directed()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(1, 3, 1, nil)
      |> Yog.add_edge_ensure(4, 5, 1, nil)

    assert Structure.branching?(branch)

    # Undirected graph is not a branching
    undirected = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1, nil)
    assert not Structure.branching?(undirected)

    # Cycle is not a branching
    cycle =
      Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 1, 1, nil)

    assert not Structure.branching?(cycle)

    # Node with in-degree 2 is not a branching
    bad = Yog.directed() |> Yog.add_edge_ensure(1, 3, 1, nil) |> Yog.add_edge_ensure(2, 3, 1, nil)
    assert not Structure.branching?(bad)

    # Empty directed graph is a branching (acyclic, all in-degrees 0)
    empty = Yog.directed()
    assert Structure.branching?(empty)

    # Single node directed graph is a branching
    single = Yog.directed() |> Yog.add_node(1, nil)
    assert Structure.branching?(single)
  end

  # ============= Complete Graph Tests =============

  test "complete? directed" do
    # Directed complete graph on 3 nodes (6 edges)
    k3_dir =
      Yog.directed()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 1, 1, nil)
      |> Yog.add_edge_ensure(1, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 1, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 2, 1, nil)

    assert Structure.complete?(k3_dir)

    # Missing one directed edge
    incomplete =
      Yog.directed()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 1, 1, nil)
      |> Yog.add_edge_ensure(1, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 1, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)

    assert not Structure.complete?(incomplete)
  end

  # ============= Regular Graph Tests =============

  test "regular? directed" do
    # Directed cycle C3: each node has in-degree 1 and out-degree 1
    c3_dir =
      Yog.directed()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 1, 1, nil)

    assert Structure.regular?(c3_dir, 1)
    assert not Structure.regular?(c3_dir, 2)

    # Empty graph is k-regular for any k
    assert Structure.regular?(Yog.undirected(), 0)
    assert Structure.regular?(Yog.undirected(), 5)
  end

  # ============= Minimum Degree Tests =============

  test "minimum_degree" do
    assert Structure.minimum_degree(Yog.undirected()) == 0
    assert Structure.minimum_degree(Yog.undirected() |> Yog.add_node(1, nil)) == 0

    path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
    assert Structure.minimum_degree(path) == 1

    star = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}])
    assert Structure.minimum_degree(star) == 1

    isolated = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
    assert Structure.minimum_degree(isolated) == 0
  end

  # ============= Connectivity Edge Cases =============

  test "connected? empty graph" do
    assert Structure.connected?(Yog.undirected())
    assert Structure.connected?(Yog.undirected() |> Yog.add_node(1, nil))
  end

  test "strongly_connected? empty graph" do
    assert Structure.strongly_connected?(Yog.undirected())
    assert Structure.strongly_connected?(Yog.directed())
  end

  test "weakly_connected? undirected and empty" do
    # Undirected graph delegates to connected?
    path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
    assert Structure.weakly_connected?(path)

    # Empty directed graph
    assert Structure.weakly_connected?(Yog.directed())
  end

  # ============= Chordality Tests =============

  test "chordal? undirected" do
    # Triangle is chordal
    g =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1)
      |> Yog.add_edge_ensure(2, 3, 1)
      |> Yog.add_edge_ensure(3, 1, 1)

    assert Structure.chordal?(g)

    # C4 is NOT chordal
    g2 =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1)
      |> Yog.add_edge_ensure(2, 3, 1)
      |> Yog.add_edge_ensure(3, 4, 1)
      |> Yog.add_edge_ensure(4, 1, 1)

    assert not Structure.chordal?(g2)

    # C4 with chord is chordal
    g3 = g2 |> Yog.add_edge_ensure(1, 3, 1)
    assert Structure.chordal?(g3)
  end

  test "chordal? directed" do
    directed = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil)
    assert not Structure.chordal?(directed)
  end

  test "chordal? empty graph" do
    assert Structure.chordal?(Yog.undirected())
  end
end
