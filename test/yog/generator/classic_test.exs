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

  # ============= Platonic Solid Tests =============

  test "tetrahedron/0 generates K4" do
    tetra = Classic.tetrahedron()
    assert Yog.Model.order(tetra) == 4
    assert Yog.Model.edge_count(tetra) == 6
    # Regular degree 3
    for v <- 0..3 do
      assert length(Yog.neighbors(tetra, v)) == 3
    end

    # Complete graph - every pair connected
    for i <- 0..3, j <- (i + 1)..3//1, i < j do
      assert Yog.Model.has_edge?(tetra, i, j)
    end
  end

  test "cube/0 generates Q3" do
    cube = Classic.cube()
    assert Yog.Model.order(cube) == 8
    assert Yog.Model.edge_count(cube) == 12
    # Regular degree 3
    for v <- 0..7 do
      assert length(Yog.neighbors(cube, v)) == 3
    end
  end

  test "cube/0 is bipartite" do
    cube = Classic.cube()
    assert Yog.Property.Bipartite.bipartite?(cube) == true
  end

  test "octahedron/0 has correct structure" do
    octa = Classic.octahedron()
    assert Yog.Model.order(octa) == 6
    assert Yog.Model.edge_count(octa) == 12
    # Regular degree 4
    for v <- 0..5 do
      assert length(Yog.neighbors(octa, v)) == 4
    end
  end

  test "octahedron/0 is 4-regular" do
    octa = Classic.octahedron()
    degrees = for v <- 0..5, do: length(Yog.neighbors(octa, v))
    assert Enum.all?(degrees, fn d -> d == 4 end)
  end

  test "dodecahedron/0 has correct structure" do
    dodeca = Classic.dodecahedron()
    assert Yog.Model.order(dodeca) == 20
    assert Yog.Model.edge_count(dodeca) == 30
    # Regular degree 3
    for v <- 0..19 do
      assert length(Yog.neighbors(dodeca, v)) == 3
    end
  end

  test "dodecahedron/0 is 3-regular" do
    dodeca = Classic.dodecahedron()
    degrees = for v <- 0..19, do: length(Yog.neighbors(dodeca, v))
    assert Enum.all?(degrees, fn d -> d == 3 end)
  end

  test "dodecahedron/0 is planar" do
    dodeca = Classic.dodecahedron()
    # Euler's formula: V - E + F = 2, F = 12 (12 pentagonal faces)
    # V - E + 2 = F + 2 = 12 for planar graphs
    v = Yog.Model.order(dodeca)
    e = Yog.Model.edge_count(dodeca)
    # F = 2 - V + E = 2 - 20 + 30 = 12 faces ✓
    assert 2 - v + e == 12
  end

  test "icosahedron/0 has correct structure" do
    icosa = Classic.icosahedron()
    assert Yog.Model.order(icosa) == 12
    assert Yog.Model.edge_count(icosa) == 30
    # Regular degree 5
    for v <- 0..11 do
      assert length(Yog.neighbors(icosa, v)) == 5
    end
  end

  test "icosahedron/0 is 5-regular" do
    icosa = Classic.icosahedron()
    degrees = for v <- 0..11, do: length(Yog.neighbors(icosa, v))
    assert Enum.all?(degrees, fn d -> d == 5 end)
  end

  test "icosahedron/0 is planar" do
    icosa = Classic.icosahedron()
    # Euler's formula: V - E + F = 2, F = 20 (20 triangular faces)
    v = Yog.Model.order(icosa)
    e = Yog.Model.edge_count(icosa)
    # F = 2 - V + E = 2 - 12 + 30 = 20 faces ✓
    assert 2 - v + e == 20
  end

  test "platonic solids have correct vertex counts" do
    assert Yog.Model.order(Classic.tetrahedron()) == 4
    assert Yog.Model.order(Classic.cube()) == 8
    assert Yog.Model.order(Classic.octahedron()) == 6
    assert Yog.Model.order(Classic.dodecahedron()) == 20
    assert Yog.Model.order(Classic.icosahedron()) == 12
  end

  test "platonic solids have correct edge counts" do
    assert Yog.Model.edge_count(Classic.tetrahedron()) == 6
    assert Yog.Model.edge_count(Classic.cube()) == 12
    assert Yog.Model.edge_count(Classic.octahedron()) == 12
    assert Yog.Model.edge_count(Classic.dodecahedron()) == 30
    assert Yog.Model.edge_count(Classic.icosahedron()) == 30
  end

  test "platonic solids are undirected" do
    assert Yog.Model.type(Classic.tetrahedron()) == :undirected
    assert Yog.Model.type(Classic.cube()) == :undirected
    assert Yog.Model.type(Classic.octahedron()) == :undirected
    assert Yog.Model.type(Classic.dodecahedron()) == :undirected
    assert Yog.Model.type(Classic.icosahedron()) == :undirected
  end

  test "dual relationships hold" do
    # Cube (8 vertices, 12 edges) ↔ Octahedron (6 vertices, 12 edges)
    # Faces of cube = 6 = vertices of octahedron
    # Faces of octahedron = 8 = vertices of cube
    cube_v = Yog.Model.order(Classic.cube())
    cube_e = Yog.Model.edge_count(Classic.cube())
    octa_v = Yog.Model.order(Classic.octahedron())
    octa_e = Yog.Model.edge_count(Classic.octahedron())

    assert cube_e == octa_e
    assert cube_v == 8
    assert octa_v == 6

    # Dodecahedron (20 vertices) ↔ Icosahedron (12 vertices)
    # Both have 30 edges (dual graphs have same edge count)
    dodeca_v = Yog.Model.order(Classic.dodecahedron())
    dodeca_e = Yog.Model.edge_count(Classic.dodecahedron())
    icosa_v = Yog.Model.order(Classic.icosahedron())
    icosa_e = Yog.Model.edge_count(Classic.icosahedron())

    assert dodeca_e == icosa_e
    assert dodeca_e == 30
    assert dodeca_v == 20
    assert icosa_v == 12
  end

  # ============= k-ary Tree Tests =============

  test "kary_tree/2 creates correct node count" do
    # Ternary tree (arity 3) depth 2: 1 + 3 + 9 = 13 nodes
    tree = Classic.kary_tree(2, arity: 3)
    assert Yog.Model.order(tree) == 13
    # Edges: 13 - 1 = 12
    assert Yog.Model.edge_count(tree) == 12
  end

  test "kary_tree/2 with arity 2 is binary tree" do
    binary = Classic.kary_tree(3, arity: 2)
    # 2^4 - 1 = 15
    assert Yog.Model.order(binary) == 15
    assert Yog.Model.edge_count(binary) == 14
  end

  test "kary_tree/2 arity 1 creates path" do
    path = Classic.kary_tree(5, arity: 1)
    # depth + 1
    assert Yog.Model.order(path) == 6
    assert Yog.Model.edge_count(path) == 5
    # Check it's a path: end nodes have degree 1, interior have degree 2
    assert length(Yog.neighbors(path, 0)) == 1
    assert length(Yog.neighbors(path, 5)) == 1
    for i <- 1..4, do: assert(length(Yog.neighbors(path, i)) == 2)
  end

  test "kary_tree/2 star is depth 1" do
    star = Classic.kary_tree(1, arity: 5)
    # 1 root + 5 leaves
    assert Yog.Model.order(star) == 6
    assert Yog.Model.edge_count(star) == 5
    # Center has degree 5, leaves have degree 1
    assert length(Yog.neighbors(star, 0)) == 5
    for i <- 1..5, do: assert(length(Yog.neighbors(star, i)) == 1)
  end

  test "kary_tree/2 depth 0 is single node" do
    tree = Classic.kary_tree(0, arity: 5)
    assert Yog.Model.order(tree) == 1
    assert Yog.Model.edge_count(tree) == 0
  end

  test "kary_tree/2 parent-child relationships" do
    # In k-ary tree, node i has parent floor((i-1)/k)
    tree = Classic.kary_tree(2, arity: 3)
    # Node 1,2,3 have parent 0
    for child <- 1..3 do
      assert Yog.Model.has_edge?(tree, 0, child)
    end

    # Nodes 4,5,6 have parent 1
    for child <- 4..6 do
      assert Yog.Model.has_edge?(tree, 1, child)
    end
  end

  test "kary_tree/2 respects graph type" do
    directed = Classic.kary_tree(2, arity: 2, type: :directed)
    assert Yog.Model.type(directed) == :directed
  end

  # ============= Complete k-ary Tree Tests =============

  test "complete_kary/2 creates exactly n nodes" do
    for n <- [1, 5, 10, 20, 50] do
      tree = Classic.complete_kary(n, arity: 3)
      assert Yog.Model.order(tree) == n
      assert Yog.Model.edge_count(tree) == n - 1
    end
  end

  test "complete_kary/2 with arity 2 creates binary heap structure" do
    # Complete binary tree with 7 nodes
    tree = Classic.complete_kary(7, arity: 2)
    assert Yog.Model.order(tree) == 7
    # Perfect binary tree of depth 2
    assert Yog.Model.edge_count(tree) == 6
    # All non-leaf nodes have 2 children except possibly the last
  end

  test "complete_kary/2 is connected and acyclic" do
    tree = Classic.complete_kary(20, arity: 3)
    # A tree has n-1 edges and is connected
    assert Yog.Model.edge_count(tree) == 19
    assert Yog.Model.order(tree) == 20
  end

  test "complete_kary/2 arity 1 is a path" do
    path = Classic.complete_kary(5, arity: 1)
    assert Yog.Model.order(path) == 5
    assert Yog.Model.edge_count(path) == 4
    # Check linear structure
    for i <- 0..3, do: assert(Yog.Model.has_edge?(path, i, i + 1))
  end

  test "complete_kary/2 respects graph type" do
    directed = Classic.complete_kary(10, arity: 2, type: :directed)
    assert Yog.Model.type(directed) == :directed
  end

  # ============= Caterpillar Tests =============

  test "caterpillar/2 creates correct node count" do
    cat = Classic.caterpillar(20, spine_length: 5)
    assert Yog.Model.order(cat) == 20
    assert Yog.Model.edge_count(cat) == 19
  end

  test "caterpillar/2 spine path exists" do
    cat = Classic.caterpillar(15, spine_length: 4)
    # Spine nodes 0,1,2,3 form a path
    for i <- 0..2, do: assert(Yog.Model.has_edge?(cat, i, i + 1))
  end

  test "caterpillar/2 all non-spine nodes are leaves" do
    cat = Classic.caterpillar(20, spine_length: 5)
    # Non-spine nodes (5-19) should have degree 1
    for i <- 5..19 do
      assert length(Yog.neighbors(cat, i)) == 1
    end
  end

  test "caterpillar/2 spine nodes connect to leaves" do
    cat = Classic.caterpillar(10, spine_length: 3)
    # 10 nodes, 3 spine nodes, 7 leaves
    # Each spine node should have at least one leaf
    for spine <- 0..2 do
      neighbors = Yog.neighbors(cat, spine)
      # At least one leaf neighbor (not just spine neighbors)
      leaf_neighbors = Enum.filter(neighbors, fn n -> n >= 3 end)
      assert length(leaf_neighbors) >= 1
    end
  end

  test "caterpillar/2 with spine_length = n is a path" do
    cat = Classic.caterpillar(5, spine_length: 5)
    assert Yog.Model.order(cat) == 5
    assert Yog.Model.edge_count(cat) == 4
    # All nodes on spine, no leaves
    for i <- 0..4, do: assert(length(Yog.neighbors(cat, i)) <= 2)
  end

  test "caterpillar/2 with spine_length = 1 is a star" do
    cat = Classic.caterpillar(6, spine_length: 1)
    assert Yog.Model.order(cat) == 6
    # Node 0 is center connected to 5 leaves
    assert length(Yog.neighbors(cat, 0)) == 5
    for i <- 1..5, do: assert(length(Yog.neighbors(cat, i)) == 1)
  end

  test "caterpillar/2 single node" do
    cat = Classic.caterpillar(1, spine_length: 1)
    assert Yog.Model.order(cat) == 1
    assert Yog.Model.edge_count(cat) == 0
  end

  test "caterpillar/2 respects graph type" do
    directed = Classic.caterpillar(10, spine_length: 3, type: :directed)
    assert Yog.Model.type(directed) == :directed
  end

  # ============= Tree Property Tests =============

  test "all tree generators produce valid trees" do
    trees = [
      Classic.kary_tree(3, arity: 2),
      Classic.kary_tree(2, arity: 3),
      Classic.complete_kary(20, arity: 3),
      Classic.caterpillar(15, spine_length: 5)
    ]

    for tree <- trees do
      n = Yog.Model.order(tree)
      e = Yog.Model.edge_count(tree)
      # Tree property: n - 1 edges
      assert e == n - 1
    end
  end

  # ============= Circular Ladder Tests =============

  test "circular_ladder/1 creates correct structure" do
    cl = Classic.circular_ladder(5)
    # 2n vertices
    assert Yog.Model.order(cl) == 10
    # 3n edges
    assert Yog.Model.edge_count(cl) == 15
  end

  test "circular_ladder/1 is 3-regular for n > 2" do
    cl = Classic.circular_ladder(5)

    for v <- 0..9 do
      assert length(Yog.neighbors(cl, v)) == 3
    end
  end

  test "circular_ladder/1 CL_4 is isomorphic to cube" do
    # CL_4 and hypercube(3) both have 8 vertices and 12 edges
    cl4 = Classic.circular_ladder(4)
    cube = Classic.hypercube(3)
    assert Yog.Model.order(cl4) == Yog.Model.order(cube)
    assert Yog.Model.edge_count(cl4) == Yog.Model.edge_count(cube)
    # Both are 3-regular
    for v <- 0..7 do
      assert length(Yog.neighbors(cl4, v)) == 3
      assert length(Yog.neighbors(cube, v)) == 3
    end
  end

  test "circular_ladder/1 is bipartite when n is even" do
    # CL_4 should be bipartite
    cl4 = Classic.circular_ladder(4)
    assert Yog.Property.Bipartite.bipartite?(cl4) == true
  end

  test "circular_ladder/1 has two cycles of length n" do
    cl = Classic.circular_ladder(5)
    # Check inner cycle connections
    for i <- 0..4 do
      assert Yog.Model.has_edge?(cl, i, rem(i + 1, 5))
    end

    # Check outer cycle connections
    for i <- 5..9 do
      assert Yog.Model.has_edge?(cl, i, rem(i - 5 + 1, 5) + 5)
    end
  end

  test "circular_ladder/1 has rungs connecting cycles" do
    cl = Classic.circular_ladder(5)
    # Each inner node i connects to outer node i+n
    for i <- 0..4 do
      assert Yog.Model.has_edge?(cl, i, i + 5)
    end
  end

  test "circular_ladder/1 edge cases" do
    # n < 3 returns empty graph
    assert Yog.Model.order(Classic.circular_ladder(2)) == 0
    assert Yog.Model.order(Classic.circular_ladder(0)) == 0
    assert Yog.Model.order(Classic.circular_ladder(-1)) == 0
  end

  test "prism/1 is alias for circular_ladder/1" do
    prism = Classic.prism(5)
    cl = Classic.circular_ladder(5)
    assert Yog.Model.order(prism) == Yog.Model.order(cl)
    assert Yog.Model.edge_count(prism) == Yog.Model.edge_count(cl)
  end

  # ============= Möbius Ladder Tests =============

  test "mobius_ladder/1 creates correct structure" do
    ml = Classic.mobius_ladder(6)
    # 2n vertices
    assert Yog.Model.order(ml) == 12
    # 3n edges
    assert Yog.Model.edge_count(ml) == 18
  end

  test "mobius_ladder/1 is 3-regular" do
    ml = Classic.mobius_ladder(5)

    for v <- 0..9 do
      assert length(Yog.neighbors(ml, v)) == 3
    end
  end

  test "mobius_ladder/1 ML_4 has correct structure" do
    # ML_4 has 8 vertices, 12 edges
    ml4 = Classic.mobius_ladder(4)
    assert Yog.Model.order(ml4) == 8
    assert Yog.Model.edge_count(ml4) == 12
    # 3-regular
    for v <- 0..7 do
      assert length(Yog.neighbors(ml4, v)) == 3
    end

    # ML_n is bipartite when n is odd; ML_4 (n=4, even) is NOT bipartite
    assert Yog.Property.Bipartite.bipartite?(ml4) == false
  end

  test "mobius_ladder/1 ML_5 is bipartite" do
    # ML_5 (n=5, odd) should be bipartite
    ml5 = Classic.mobius_ladder(5)
    assert Yog.Property.Bipartite.bipartite?(ml5) == true
  end

  test "mobius_ladder/1 has cycle of length 2n" do
    ml = Classic.mobius_ladder(5)
    # Check main cycle edges
    for i <- 0..9 do
      assert Yog.Model.has_edge?(ml, i, rem(i + 1, 10))
    end
  end

  test "mobius_ladder/1 has twist edges" do
    ml = Classic.mobius_ladder(5)
    # Twist edges connect i to i+n (mod 2n)
    for i <- 0..4 do
      assert Yog.Model.has_edge?(ml, i, i + 5)
    end
  end

  test "mobius_ladder/1 edge cases" do
    # n < 2 returns empty graph
    assert Yog.Model.order(Classic.mobius_ladder(1)) == 0
    assert Yog.Model.order(Classic.mobius_ladder(0)) == 0
    assert Yog.Model.order(Classic.mobius_ladder(-1)) == 0
  end

  test "mobius_ladder/1 ML_3 is 6-vertex utility graph" do
    # ML_3 has 6 vertices, 9 edges
    ml3 = Classic.mobius_ladder(3)
    assert Yog.Model.order(ml3) == 6
    assert Yog.Model.edge_count(ml3) == 9
    # 3-regular
    for v <- 0..5 do
      assert length(Yog.neighbors(ml3, v)) == 3
    end
  end

  # ============= Ladder Graph Comparison Tests =============

  test "ladder vs circular_ladder comparison" do
    # Regular ladder (n=5): 10 vertices, 13 edges (no wraparound)
    ladder = Classic.ladder(5)
    # Circular ladder (n=5): 10 vertices, 15 edges (wraparound cycles)
    cl = Classic.circular_ladder(5)

    assert Yog.Model.order(ladder) == Yog.Model.order(cl)
    # Circular ladder has 2 more edges (the wraparound connections)
    assert Yog.Model.edge_count(cl) - Yog.Model.edge_count(ladder) == 2
  end

  test "circular vs mobius ladder structural difference" do
    # Both have 10 vertices, 15 edges for n=5
    cl = Classic.circular_ladder(5)
    ml = Classic.mobius_ladder(5)

    assert Yog.Model.order(cl) == Yog.Model.order(ml)
    assert Yog.Model.edge_count(cl) == Yog.Model.edge_count(ml)

    # Both are 3-regular
    for v <- 0..9 do
      assert length(Yog.neighbors(cl, v)) == 3
      assert length(Yog.neighbors(ml, v)) == 3
    end
  end

  # ============= Friendship Graph Tests =============

  test "friendship/1 creates correct structure" do
    f3 = Classic.friendship(3)
    # 2n + 1 = 7
    assert Yog.Model.order(f3) == 7
    # 3n = 9
    assert Yog.Model.edge_count(f3) == 9
  end

  test "friendship/1 center has degree 2n" do
    f5 = Classic.friendship(5)
    # Node 0 is center
    assert length(Yog.neighbors(f5, 0)) == 10
  end

  test "friendship/1 outer vertices have degree 2" do
    f4 = Classic.friendship(4)
    # Outer vertices are 1..8
    for v <- 1..8 do
      assert length(Yog.neighbors(f4, v)) == 2
    end
  end

  test "friendship/1 forms n triangles" do
    f3 = Classic.friendship(3)
    # Check 3 triangles: (0,1,2), (0,3,4), (0,5,6)
    assert Yog.Model.has_edge?(f3, 0, 1)
    assert Yog.Model.has_edge?(f3, 0, 2)
    assert Yog.Model.has_edge?(f3, 1, 2)

    assert Yog.Model.has_edge?(f3, 0, 3)
    assert Yog.Model.has_edge?(f3, 0, 4)
    assert Yog.Model.has_edge?(f3, 3, 4)
  end

  test "friendship/1 edge cases" do
    # n < 1 returns empty graph
    assert Yog.Model.order(Classic.friendship(0)) == 0
    assert Yog.Model.order(Classic.friendship(-1)) == 0

    # F_1 is just a triangle
    f1 = Classic.friendship(1)
    assert Yog.Model.order(f1) == 3
    assert Yog.Model.edge_count(f1) == 3
  end

  test "friendship theorem property" do
    # In friendship graph, every pair of vertices has exactly one common neighbor
    f3 = Classic.friendship(3)
    # 7 vertices numbered 0 to 6
    vertices = 0..6

    for u <- vertices, v <- vertices, u < v do
      common =
        Enum.filter(Yog.neighbors(f3, u), fn n -> n in Yog.neighbors(f3, v) end)

      assert length(common) == 1
    end
  end

  # ============= Windmill Graph Tests =============

  test "windmill/2 with clique_size 3 is friendship graph" do
    w3 = Classic.windmill(3, clique_size: 3)
    f3 = Classic.friendship(3)

    assert Yog.Model.order(w3) == Yog.Model.order(f3)
    assert Yog.Model.edge_count(w3) == Yog.Model.edge_count(f3)
  end

  test "windmill/2 creates correct node count" do
    # W_3^{(4)}: 3 cliques of size 4 sharing a vertex
    # Vertices: 1 + 3*(4-1) = 10
    w = Classic.windmill(3, clique_size: 4)
    assert Yog.Model.order(w) == 10
    # Edges: 3 * C(4,2) = 3 * 6 = 18
    assert Yog.Model.edge_count(w) == 18
  end

  test "windmill/2 center connects to all other vertices" do
    # In W_n^{(k)}, center connects to all n*(k-1) outer vertices
    w = Classic.windmill(4, clique_size: 3)
    # Center (0) should have degree 4*(3-1) = 8
    assert length(Yog.neighbors(w, 0)) == 8
  end

  test "windmill/2 each clique is complete" do
    # In W_2^{(4)}, we have two K_4's sharing the center
    w = Classic.windmill(2, clique_size: 4)
    # Clique 1: vertices 0, 1, 2, 3
    # All pairs should be connected
    for u <- [0, 1, 2, 3], v <- [0, 1, 2, 3], u < v do
      assert Yog.Model.has_edge?(w, u, v)
    end
  end

  test "windmill/2 default clique_size is 3" do
    w = Classic.windmill(3)
    f = Classic.friendship(3)
    assert Yog.Model.order(w) == Yog.Model.order(f)
  end

  test "windmill/2 edge cases" do
    # n < 1 returns empty
    assert Yog.Model.order(Classic.windmill(0)) == 0
    # k < 2 returns empty
    assert Yog.Model.order(Classic.windmill(3, clique_size: 1)) == 0
  end

  # ============= Book Graph Tests =============

  test "book/1 creates correct structure" do
    book = Classic.book(3)
    # n + 2 = 5
    assert Yog.Model.order(book) == 5
    # 2n + 1 = 7
    assert Yog.Model.edge_count(book) == 7
  end

  test "book/1 spine edge exists" do
    book = Classic.book(3)
    # Nodes 0 and 1 form the spine
    assert Yog.Model.has_edge?(book, 0, 1)
  end

  test "book/1 each page forms triangle with spine" do
    book = Classic.book(3)
    # Pages are nodes 2, 3, 4
    # Each page node should connect to both spine nodes (0 and 1)
    for page <- 2..4 do
      assert Yog.Model.has_edge?(book, 0, page)
      assert Yog.Model.has_edge?(book, 1, page)
    end
  end

  test "book/1 is outerplanar" do
    # Book graphs are outerplanar (can be drawn without crossing, all vertices on outer face)
    book = Classic.book(4)
    assert Yog.Model.order(book) == 6
    assert Yog.Model.edge_count(book) == 9
  end

  test "book/1 edge cases" do
    # n < 1 returns empty
    assert Yog.Model.order(Classic.book(0)) == 0

    # B_1 is a single triangle
    b1 = Classic.book(1)
    assert Yog.Model.order(b1) == 3
    assert Yog.Model.edge_count(b1) == 3
  end

  test "book vs friendship structural difference" do
    # Both have triangles, but:
    # - Friendship: triangles share a VERTEX
    # - Book: triangles share an EDGE

    f3 = Classic.friendship(3)
    b3 = Classic.book(3)

    # Same number of triangles (3)
    # Friendship: 7 vertices, Book: 5 vertices
    assert Yog.Model.order(f3) == 7
    assert Yog.Model.order(b3) == 5

    # Friendship: 9 edges, Book: 7 edges
    assert Yog.Model.edge_count(f3) == 9
    assert Yog.Model.edge_count(b3) == 7
  end

  # ============= Crown Graph Tests =============

  test "crown/1 creates correct structure" do
    crown = Classic.crown(4)
    # 2n vertices
    assert Yog.Model.order(crown) == 8
    # n(n-1) = 4*3 = 12
    assert Yog.Model.edge_count(crown) == 12
  end

  test "crown/1 is (n-1)-regular" do
    crown = Classic.crown(5)
    # Each vertex should have degree n-1 = 4
    for v <- 0..9 do
      assert length(Yog.neighbors(crown, v)) == 4
    end
  end

  test "crown/1 is bipartite" do
    crown = Classic.crown(4)
    assert Yog.Property.Bipartite.bipartite?(crown) == true
  end

  test "crown/1 perfect matching is removed" do
    crown = Classic.crown(4)
    # Edges (i, n+i) for i in 0..n-1 should NOT exist
    for i <- 0..3 do
      assert not Yog.Model.has_edge?(crown, i, i + 4)
    end
  end

  test "crown/1 all other bipartite edges exist" do
    crown = Classic.crown(3)
    # K_{3,3} has 9 edges, crown has 6 (removed 3)
    # For each i in left (0,1,2), it should connect to all in right (3,4,5) except n+i
    # Left 0 connects to 4, 5 (not 3)
    assert not Yog.Model.has_edge?(crown, 0, 3)
    assert Yog.Model.has_edge?(crown, 0, 4)
    assert Yog.Model.has_edge?(crown, 0, 5)
    # Left 1 connects to 3, 5 (not 4)
    assert Yog.Model.has_edge?(crown, 1, 3)
    assert not Yog.Model.has_edge?(crown, 1, 4)
    assert Yog.Model.has_edge?(crown, 1, 5)
    # Left 2 connects to 3, 4 (not 5)
    assert Yog.Model.has_edge?(crown, 2, 3)
    assert Yog.Model.has_edge?(crown, 2, 4)
    assert not Yog.Model.has_edge?(crown, 2, 5)
  end

  test "crown/1 crown(2) structure" do
    # crown(2): K_{2,2} minus perfect matching
    # K_{2,2} has 4 edges forming C4: (0,2), (0,3), (1,2), (1,3)
    # We remove (i, n+i) = (0,2), (1,3)
    # Result: two disjoint edges (0,3) and (1,2)
    c2 = Classic.crown(2)
    assert Yog.Model.order(c2) == 4
    # n(n-1) = 2*1 = 2 edges
    assert Yog.Model.edge_count(c2) == 2
    # Verify the remaining edges
    assert Yog.Model.has_edge?(c2, 0, 3)
    assert Yog.Model.has_edge?(c2, 1, 2)
    assert not Yog.Model.has_edge?(c2, 0, 2)
    assert not Yog.Model.has_edge?(c2, 1, 3)
  end

  test "crown/1 crown(3) is utility graph" do
    # crown(3) = K_{3,3} minus perfect matching = 9 - 3 = 6 edges
    c3 = Classic.crown(3)
    assert Yog.Model.order(c3) == 6
    # 3*2 = 6
    assert Yog.Model.edge_count(c3) == 6
  end

  test "crown/1 partitions are correct" do
    crown = Classic.crown(4)
    # Left partition nodes (0,1,2,3) should only connect to right partition (4,5,6,7)
    for u <- 0..3 do
      neighbors = Yog.neighbors(crown, u)
      neighbor_ids = Enum.map(neighbors, fn {id, _} -> id end)
      # All neighbors should be in right partition
      for v <- neighbor_ids do
        assert v >= 4 and v <= 7
      end
    end

    # Right partition nodes (4,5,6,7) should only connect to left partition (0,1,2,3)
    for u <- 4..7 do
      neighbors = Yog.neighbors(crown, u)
      neighbor_ids = Enum.map(neighbors, fn {id, _} -> id end)

      for v <- neighbor_ids do
        assert v >= 0 and v <= 3
      end
    end
  end

  test "crown/1 edge cases" do
    # n < 2 returns empty graph
    assert Yog.Model.order(Classic.crown(1)) == 0
    assert Yog.Model.order(Classic.crown(0)) == 0
    assert Yog.Model.order(Classic.crown(-1)) == 0
  end

  test "crown/1 larger n" do
    crown = Classic.crown(10)
    assert Yog.Model.order(crown) == 20
    # 10*9 = 90
    assert Yog.Model.edge_count(crown) == 90
    # All vertices have degree 9
    for v <- 0..19 do
      assert length(Yog.neighbors(crown, v)) == 9
    end
  end
end
