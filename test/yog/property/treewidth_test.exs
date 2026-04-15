defmodule Yog.Property.TreewidthTest do
  use ExUnit.Case

  alias Yog.Property.TreeDecomposition
  alias Yog.Generator.Classic

  doctest Yog.Approximate, import: true
  doctest Yog.Property.Structure, import: true

  # ============= Treewidth Upper Bound Tests =============

  test "treewidth of empty graph is 0" do
    graph = Classic.empty(0)
    assert Yog.Approximate.treewidth_upper_bound(graph) == 0
    assert Yog.Property.treewidth_upper_bound(graph) == 0
  end

  test "treewidth of isolated vertices is 0" do
    graph = Classic.empty(5)
    assert Yog.Approximate.treewidth_upper_bound(graph) == 0
  end

  test "treewidth of tree is 1" do
    graph = Classic.binary_tree(3)
    assert Yog.Approximate.treewidth_upper_bound(graph) == 1
  end

  test "treewidth of path is 1" do
    graph = Classic.path(10)
    assert Yog.Approximate.treewidth_upper_bound(graph) == 1
  end

  test "treewidth of cycle is 2" do
    for n <- 3..8 do
      graph = Classic.cycle(n)

      assert Yog.Approximate.treewidth_upper_bound(graph) == 2,
             "C_#{n} should have treewidth 2"
    end
  end

  test "treewidth of complete graph K_n is n-1" do
    for n <- 1..7 do
      graph = Classic.complete(n)

      assert Yog.Approximate.treewidth_upper_bound(graph) == n - 1,
             "K_#{n} should have treewidth #{n - 1}"
    end
  end

  test "treewidth of k x k grid is k" do
    for k <- 2..5 do
      graph = Classic.grid_2d(k, k)
      bound = Yog.Approximate.treewidth_upper_bound(graph)
      assert bound == k, "#{k}x#{k} grid should have treewidth #{k}, got #{bound}"
    end
  end

  test "min-fill is at most min-degree" do
    graphs = [
      Classic.complete(5),
      Classic.cycle(7),
      Classic.grid_2d(3, 3),
      Classic.path(10),
      Classic.star(6),
      Classic.petersen()
    ]

    for graph <- graphs do
      min_degree = Yog.Approximate.treewidth_upper_bound(graph, heuristic: :min_degree)
      min_fill = Yog.Approximate.treewidth_upper_bound(graph, heuristic: :min_fill)

      assert min_fill <= min_degree,
             "min-fill (#{min_fill}) should be <= min-degree (#{min_degree})"
    end
  end

  # ============= Tree Decomposition Tests =============

  test "tree decomposition of empty graph is valid" do
    graph = Classic.empty(0)
    assert {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert td.width == 0
    assert td.bags == %{}
    assert TreeDecomposition.valid?(td, graph)
  end

  test "tree decomposition of tree is valid and has width 1" do
    graph = Classic.binary_tree(3)
    assert {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert td.width == 1
    assert TreeDecomposition.valid?(td, graph)
  end

  test "tree decomposition of cycle is valid and has width 2" do
    graph = Classic.cycle(5)
    assert {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert td.width == 2
    assert TreeDecomposition.valid?(td, graph)
  end

  test "tree decomposition of complete graph is valid" do
    graph = Classic.complete(4)
    assert {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert td.width == 3
    assert TreeDecomposition.valid?(td, graph)
  end

  test "tree decomposition of grid is valid" do
    graph = Classic.grid_2d(3, 3)
    assert {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert td.width == 3
    assert TreeDecomposition.valid?(td, graph)
  end

  test "tree decomposition works for disconnected graph" do
    graph =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(3, 4, 1, nil)

    assert {:ok, td} = Yog.Approximate.tree_decomposition(graph)
    assert TreeDecomposition.valid?(td, graph)
    assert td.width == 1
  end

  test "tree decomposition via Property facade" do
    graph = Classic.path(5)
    assert {:ok, td} = Yog.Property.tree_decomposition(graph)
    assert TreeDecomposition.valid?(td, graph)
    assert td.width == 1
  end

  # ============= Minimum Degree Tests =============

  test "minimum_degree of empty graph is 0" do
    assert Yog.Property.minimum_degree(Yog.undirected()) == 0
  end

  test "minimum_degree of path graph" do
    graph = Classic.path(4)
    assert Yog.Property.minimum_degree(graph) == 1
  end

  test "minimum_degree of cycle graph" do
    graph = Classic.cycle(5)
    assert Yog.Property.minimum_degree(graph) == 2
  end

  test "minimum_degree of star graph" do
    graph = Classic.star(5)
    assert Yog.Property.minimum_degree(graph) == 1
  end
end
