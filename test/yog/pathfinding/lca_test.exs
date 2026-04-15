defmodule Yog.Pathfinding.LCATest do
  use ExUnit.Case

  alias Yog.Pathfinding.LCA
  doctest LCA

  # =============================================================================
  # Basic functionality
  # =============================================================================

  test "simple binary tree LCA queries" do
    #      1
    #     / \
    #    2   3
    #   / \
    #  4   5
    tree =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 1},
        {2, 4, 1},
        {2, 5, 1}
      ])

    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 4, 5) == {:ok, 2}
    assert LCA.lca(state, 4, 3) == {:ok, 1}
    assert LCA.lca(state, 2, 5) == {:ok, 2}
    assert LCA.lca(state, 1, 4) == {:ok, 1}
    assert LCA.tree_distance(state, 4, 3) == {:ok, 3}
    assert LCA.tree_distance(state, 4, 5) == {:ok, 2}
    assert LCA.tree_distance(state, 1, 3) == {:ok, 1}
  end

  test "simple chain" do
    # 1-2-3-4-5
    tree =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1},
        {3, 4, 1},
        {4, 5, 1}
      ])

    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 2, 4) == {:ok, 2}
    assert LCA.lca(state, 3, 5) == {:ok, 3}
    assert LCA.tree_distance(state, 2, 5) == {:ok, 3}
  end

  test "star graph" do
    #   1
    #  /|\
    # 2 3 4
    tree =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 1},
        {1, 4, 1}
      ])

    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 2, 3) == {:ok, 1}
    assert LCA.lca(state, 3, 4) == {:ok, 1}
    assert LCA.tree_distance(state, 2, 4) == {:ok, 2}
  end

  test "same node LCA is itself" do
    tree =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 1}
      ])

    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 2, 2) == {:ok, 2}
    assert LCA.tree_distance(state, 3, 3) == {:ok, 0}
  end

  test "single node tree" do
    tree = Yog.undirected() |> Yog.add_node(1, nil)
    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 1, 1) == {:ok, 1}
    assert LCA.tree_distance(state, 1, 1) == {:ok, 0}
  end

  test "large depth chain" do
    tree =
      Yog.undirected()
      |> Yog.add_nodes_from(Enum.map(1..1001, &{&1, nil}))
      |> Yog.add_edges!(Enum.map(1..1000, fn i -> {i, i + 1, 1} end))

    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 500, 800) == {:ok, 500}
    assert LCA.tree_distance(state, 250, 750) == {:ok, 500}
  end

  # =============================================================================
  # Error handling
  # =============================================================================

  test "returns error for non-existent root" do
    tree = Yog.undirected() |> Yog.add_node(1, nil)
    assert LCA.lca_preprocess(tree, 99) == {:error, :root_not_found}
  end

  test "returns error for disconnected graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)

    assert LCA.lca_preprocess(graph, 1) == {:error, :not_a_tree}
  end

  test "returns error for graph with cycle" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {2, 3, 1},
        {3, 1, 1}
      ])

    assert LCA.lca_preprocess(graph, 1) == {:error, :not_a_tree}
  end

  test "returns error for node not in preprocessed tree" do
    tree =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([{1, 2, 1}])

    {:ok, state} = LCA.lca_preprocess(tree, 1)

    assert LCA.lca(state, 2, 99) == {:error, :node_not_found}
    assert LCA.tree_distance(state, 99, 2) == {:error, :node_not_found}
  end

  # =============================================================================
  # Facade delegation
  # =============================================================================

  test "facade delegation through Yog.Pathfinding" do
    tree =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 1},
        {2, 4, 1}
      ])

    {:ok, state} = Yog.Pathfinding.lca_preprocess(tree, 1)
    assert Yog.Pathfinding.lca(state, 4, 3) == {:ok, 1}
    assert Yog.Pathfinding.tree_distance(state, 4, 3) == {:ok, 3}
  end
end
