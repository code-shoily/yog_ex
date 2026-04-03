defmodule Yog.Generator.ClassicTest do
  use ExUnit.Case

  alias Yog.Generator.Classic

  doctest Yog.Generator.Classic

  # ============= Complete Graph Tests =============

  test "complete/1 creates K_n" do
    k5 = Classic.complete(5)
    assert Yog.Model.order(k5) == 5
    assert Yog.Model.edge_count(k5) == 10

    degrees = for v <- 0..4, do: length(Yog.neighbors(k5, v))
    assert Enum.all?(degrees, fn d -> d == 4 end)
  end

  test "complete_with_type/2 directed K_n" do
    k4 = Classic.complete_with_type(4, :directed)
    assert Yog.Model.type(k4) == :directed
    assert Yog.Model.order(k4) == 4
    # Directed complete graph: n*(n-1) = 12 edges
    assert Yog.Model.edge_count(k4) == 12
  end

  test "complete/1 edge case n=1" do
    k1 = Classic.complete(1)
    assert Yog.Model.order(k1) == 1
    assert Yog.Model.edge_count(k1) == 0
  end

  test "complete/1 edge case n=0" do
    k0 = Classic.complete(0)
    assert Yog.Model.order(k0) == 0
  end

  # ============= Cycle Graph Tests =============

  test "cycle/1 creates C_n" do
    c6 = Classic.cycle(6)
    assert Yog.Model.order(c6) == 6
    assert Yog.Model.edge_count(c6) == 6

    degrees = for v <- 0..5, do: length(Yog.neighbors(c6, v))
    assert Enum.all?(degrees, fn d -> d == 2 end)
  end

  test "cycle/1 edge case n < 3" do
    c2 = Classic.cycle(2)
    assert Yog.Model.order(c2) == 0
  end

  test "cycle_with_type/2 directed cycle" do
    c5 = Classic.cycle_with_type(5, :directed)
    assert Yog.Model.type(c5) == :directed
    assert Yog.Model.order(c5) == 5
    assert Yog.Model.edge_count(c5) == 5
  end

  # ============= Path Graph Tests =============

  test "path/1 creates P_n" do
    p5 = Classic.path(5)
    assert Yog.Model.order(p5) == 5
    assert Yog.Model.edge_count(p5) == 4

    assert length(Yog.neighbors(p5, 0)) == 1
    assert length(Yog.neighbors(p5, 4)) == 1
    assert length(Yog.neighbors(p5, 2)) == 2
  end

  test "path/1 edge cases" do
    assert Yog.Model.order(Classic.path(0)) == 0
    assert Yog.Model.order(Classic.path(1)) == 1
    assert Yog.Model.edge_count(Classic.path(1)) == 0
  end

  # ============= Star Graph Tests =============

  test "star/1 creates S_n" do
    s5 = Classic.star(5)
    assert Yog.Model.order(s5) == 5
    assert Yog.Model.edge_count(s5) == 4

    assert length(Yog.neighbors(s5, 0)) == 4
    assert length(Yog.neighbors(s5, 1)) == 1
  end

  test "star/1 edge cases" do
    assert Yog.Model.order(Classic.star(0)) == 0
    assert Yog.Model.order(Classic.star(1)) == 1
  end

  # ============= Wheel Graph Tests =============

  test "wheel/1 creates W_n" do
    w6 = Classic.wheel(6)
    assert Yog.Model.order(w6) == 6
    assert Yog.Model.edge_count(w6) == 10

    assert length(Yog.neighbors(w6, 0)) == 5
    assert length(Yog.neighbors(w6, 1)) == 3
  end

  test "wheel/1 edge case n < 4" do
    assert Yog.Model.order(Classic.wheel(3)) == 0
  end

  # ============= Binary Tree Tests =============

  test "binary_tree/1 creates full binary tree" do
    tree = Classic.binary_tree(3)
    assert Yog.Model.order(tree) == 15
    assert Yog.Model.edge_count(tree) == 14

    # Root has 2 children
    assert length(Yog.neighbors(tree, 0)) == 2
  end

  test "binary_tree/1 edge cases" do
    assert Yog.Model.order(Classic.binary_tree(0)) == 1
    assert Yog.Model.order(Classic.binary_tree(-1)) == 0
  end

  # ============= Petersen Graph Tests =============

  test "petersen/0 has correct properties" do
    p = Classic.petersen()
    assert Yog.Model.order(p) == 10
    assert Yog.Model.edge_count(p) == 15

    degrees = for v <- 0..9, do: length(Yog.neighbors(p, v))
    assert Enum.all?(degrees, fn d -> d == 3 end)
  end

  # ============= Empty Graph Tests =============

  test "empty/1 creates isolated nodes" do
    g = Classic.empty(5)
    assert Yog.Model.order(g) == 5
    assert Yog.Model.edge_count(g) == 0
  end

  test "empty/1 edge case n=0" do
    assert Yog.Model.order(Classic.empty(0)) == 0
  end

  # ============= Grid 2D Tests =============

  test "grid_2d/2 creates lattice" do
    grid = Classic.grid_2d(3, 4)
    assert Yog.Model.order(grid) == 12
    assert Yog.Model.edge_count(grid) == 17

    # Corner nodes have degree 2
    assert length(Yog.neighbors(grid, 0)) == 2
    # Interior nodes have degree 4
    assert length(Yog.neighbors(grid, 5)) == 4
  end

  test "grid_2d/2 edge cases" do
    assert Yog.Model.order(Classic.grid_2d(0, 5)) == 0
    assert Yog.Model.order(Classic.grid_2d(1, 1)) == 1
  end

  # ============= Complete Bipartite Tests =============

  test "complete_bipartite/2 creates K_{m,n}" do
    k34 = Classic.complete_bipartite(3, 4)
    assert Yog.Model.order(k34) == 7
    assert Yog.Model.edge_count(k34) == 12

    assert length(Yog.neighbors(k34, 0)) == 4
    assert length(Yog.neighbors(k34, 3)) == 3
  end

  test "complete_bipartite/2 edge case m=0" do
    k04 = Classic.complete_bipartite(0, 4)
    assert Yog.Model.order(k04) == 4
    assert Yog.Model.edge_count(k04) == 0
  end

  # ============= Hypercube Tests =============

  test "hypercube/1 creates n-dimensional hypercube" do
    cube = Classic.hypercube(3)
    assert Yog.Model.order(cube) == 8
    assert Yog.Model.edge_count(cube) == 12

    # All nodes have degree n
    degrees = for v <- 0..7, do: length(Yog.neighbors(cube, v))
    assert Enum.all?(degrees, fn d -> d == 3 end)
  end

  test "hypercube/1 Q4 has correct properties" do
    cube = Classic.hypercube(4)
    assert Yog.Model.order(cube) == 16
    assert Yog.Model.edge_count(cube) == 32

    degrees = for v <- 0..15, do: length(Yog.neighbors(cube, v))
    assert Enum.all?(degrees, fn d -> d == 4 end)
  end

  test "hypercube/1 edge case Q0" do
    cube = Classic.hypercube(0)
    assert Yog.Model.order(cube) == 1
    assert Yog.Model.edge_count(cube) == 0
  end

  test "hypercube/1 edge case Q1" do
    cube = Classic.hypercube(1)
    assert Yog.Model.order(cube) == 2
    assert Yog.Model.edge_count(cube) == 1
  end

  test "hypercube_with_type/2 directed hypercube" do
    cube = Classic.hypercube_with_type(3, :directed)
    assert Yog.Model.type(cube) == :directed
    assert Yog.Model.order(cube) == 8
  end

  # ============= Ladder Tests =============

  test "ladder/1 creates ladder graph with n rungs" do
    ladder = Classic.ladder(4)
    assert Yog.Model.order(ladder) == 8
    # 4 rungs + 3 bottom edges + 3 top edges = 10
    assert Yog.Model.edge_count(ladder) == 10
  end

  test "ladder/1 end nodes have degree 2" do
    ladder = Classic.ladder(4)
    # End nodes (0, 3, 4, 7) have degree 2
    assert length(Yog.neighbors(ladder, 0)) == 2
    assert length(Yog.neighbors(ladder, 3)) == 2
    assert length(Yog.neighbors(ladder, 4)) == 2
    assert length(Yog.neighbors(ladder, 7)) == 2
  end

  test "ladder/1 interior nodes have degree 3" do
    ladder = Classic.ladder(4)
    # Interior nodes have degree 3
    assert length(Yog.neighbors(ladder, 1)) == 3
    assert length(Yog.neighbors(ladder, 2)) == 3
    assert length(Yog.neighbors(ladder, 5)) == 3
    assert length(Yog.neighbors(ladder, 6)) == 3
  end

  test "ladder/1 single rung" do
    ladder = Classic.ladder(1)
    assert Yog.Model.order(ladder) == 2
    assert Yog.Model.edge_count(ladder) == 1
  end

  test "ladder/1 two rungs" do
    ladder = Classic.ladder(2)
    assert Yog.Model.order(ladder) == 4
    # 2 rungs + 1 bottom + 1 top = 4 edges
    assert Yog.Model.edge_count(ladder) == 4
  end

  # ============= Turan Tests =============

  test "turan/2 creates complete r-partite graph" do
    turan = Classic.turan(10, 3)
    assert Yog.Model.order(turan) == 10
    # Partition sizes: 4, 3, 3
    # Edges: 4*3 + 4*3 + 3*3 = 12 + 12 + 9 = 33
    assert Yog.Model.edge_count(turan) == 33
  end

  test "turan/2 T(n,2) is complete bipartite" do
    turan = Classic.turan(6, 2)
    assert Yog.Model.order(turan) == 6
    # K_{3,3} has 9 edges
    assert Yog.Model.edge_count(turan) == 9
  end

  test "turan/2 T(n,n) is complete graph" do
    turan = Classic.turan(5, 5)
    assert Yog.Model.order(turan) == 5
    # K_5 has 10 edges
    assert Yog.Model.edge_count(turan) == 10
  end

  test "turan/2 T(n,r) with r > n is complete graph" do
    turan = Classic.turan(5, 10)
    assert Yog.Model.order(turan) == 5
    assert Yog.Model.edge_count(turan) == 10
  end

  test "turan/2 chromatic number equals r" do
    # T(n, r) has chromatic number r (for n >= r)
    turan = Classic.turan(10, 3)
    # Check that the graph is 3-colorable but not 2-colorable
    assert Yog.Property.Bipartite.bipartite?(turan) == false
  end

  test "turan/2 no edges within partitions" do
    turan = Classic.turan(6, 2)
    # In T(6,2), nodes 0,1,2 are in partition 0
    # They should have no edges between them
    for i <- 0..2, j <- 0..2, i != j do
      assert not Yog.Model.has_edge?(turan, i, j)
    end
  end
end
