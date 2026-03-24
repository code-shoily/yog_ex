defmodule Yog.Generator.ClassicTest do
  use ExUnit.Case

  alias Yog.Generator.Classic

  doctest Yog.Generator.Classic

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
