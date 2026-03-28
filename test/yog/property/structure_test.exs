defmodule Yog.Property.StructureTest do
  use ExUnit.Case

  alias Yog.Property.Structure

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

  # ============= Planarity Tests =============

  test "planar? basic checks" do
    # K4 is planar
    nodes = 1..4

    k4 =
      for u <- nodes, v <- nodes, u < v, reduce: Yog.undirected() do
        acc -> Yog.add_edge_ensure(acc, u, v, 1, nil)
      end

    assert Structure.planar?(k4)

    # K5 is NOT planar
    nodes = 1..5

    g_k5 =
      for u <- nodes, v <- nodes, u < v, reduce: Yog.undirected() do
        acc -> Yog.add_edge_ensure(acc, u, v, 1, nil)
      end

    assert not Structure.planar?(g_k5)

    # K3,3 is NOT planar
    k33 =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 4, 1, nil)
      |> Yog.add_edge_ensure(1, 5, 1, nil)
      |> Yog.add_edge_ensure(1, 6, 1, nil)
      |> Yog.add_edge_ensure(2, 4, 1, nil)
      |> Yog.add_edge_ensure(2, 5, 1, nil)
      |> Yog.add_edge_ensure(2, 6, 1, nil)
      |> Yog.add_edge_ensure(3, 4, 1, nil)
      |> Yog.add_edge_ensure(3, 5, 1, nil)
      |> Yog.add_edge_ensure(3, 6, 1, nil)

    assert not Structure.planar?(k33)
  end
end
