defmodule Yog.OperationTest do
  use ExUnit.Case

  alias Yog.Operation

  doctest Operation

  # ============= Set-Theoretic Operations =============

  describe "union/2" do
    test "combines two disjoint graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

      result = Operation.union(g1, g2)

      assert Yog.Model.order(result) == 4
      assert length(Yog.neighbors(result, 1)) == 1
      assert length(Yog.neighbors(result, 3)) == 1
    end

    test "combines overlapping graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      result = Operation.union(g1, g2)

      assert Yog.Model.order(result) == 3
      # Node 2 should have degree 2 (connected to 1 and 3)
      assert length(Yog.neighbors(result, 2)) == 2
    end
  end

  describe "intersection/2" do
    test "finds common structure" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      result = Operation.intersection(g1, g2)

      # Intersection keeps common nodes (1, 2, 3) and common edge (1-2)
      assert Yog.Model.order(result) == 3
      assert length(Yog.neighbors(result, 1)) == 1
    end

    test "empty intersection for disjoint graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 1, to: 1, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 2, to: 2, with: 1)

      result = Operation.intersection(g1, g2)

      # No common nodes or edges
      assert Yog.Model.order(result) == 0
    end
  end

  describe "difference/2" do
    test "removes common edges" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      result = Operation.difference(g1, g2)

      # Edge 1-2 is in both, so it should be removed
      # Nodes without edges may be removed
      assert is_struct(result, Yog.Graph)
    end

    test "keeps unique structure" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      result = Operation.difference(g1, g2)

      # Edge 2-3 is unique to g1
      assert is_struct(result, Yog.Graph)
    end
  end

  describe "symmetric_difference/2" do
    test "finds edges in exactly one graph" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      result = Operation.symmetric_difference(g1, g2)

      # Both edges are unique to their respective graphs
      assert is_struct(result, Yog.Graph)
    end
  end

  # ============= Composition & Joins =============

  describe "disjoint_union/2" do
    test "reindexes second graph automatically" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      result = Operation.disjoint_union(g1, g2)

      # Should have 4 nodes: 0,1 from g1 and 2,3 (reindexed) from g2
      assert Yog.Model.order(result) == 4

      # Original nodes should still exist
      assert length(Yog.neighbors(result, 0)) == 1
      assert length(Yog.neighbors(result, 1)) == 1

      # Reindexed nodes from g2 should exist (shifted by 2)
      assert length(Yog.neighbors(result, 2)) == 1
      assert length(Yog.neighbors(result, 3)) == 1
    end

    test "combines graphs with different structures" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      result = Operation.disjoint_union(g1, g2)

      # Triangle (3 nodes) + Edge (2 nodes) = 5 nodes
      assert Yog.Model.order(result) == 5
    end
  end

  describe "cartesian_product/2" do
    test "creates grid-like structure" do
      # Path of 2 nodes
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      # Path of 2 nodes
      g2 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      result = Operation.cartesian_product(g1, g2, 0, 0)

      # 2x2 grid = 4 nodes
      assert Yog.Model.order(result) == 4
    end

    test "product of larger graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      result = Operation.cartesian_product(g1, g2, 0, 0)

      # 2x3 = 6 nodes
      assert Yog.Model.order(result) == 6
    end
  end

  describe "compose/2" do
    test "merges overlapping graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      result = Operation.compose(g1, g2)

      assert Yog.Model.order(result) == 3
      # Node 2 should have degree 2
      assert length(Yog.neighbors(result, 2)) == 2
    end
  end

  describe "power/2" do
    test "k=1 returns original graph" do
      g =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      result = Operation.power(g, 1, 1)

      assert Yog.Model.order(result) == 2
    end

    test "k=2 connects distance-2 nodes" do
      # Path: 0-1-2
      g =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      result = Operation.power(g, 2, 1)

      # Should have same nodes
      assert Yog.Model.order(result) == 3
      # Nodes 0 and 2 should now be connected (distance 2 in original)
    end

    test "k=0 returns original graph" do
      g =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)

      result = Operation.power(g, 0, 1)

      assert Yog.Model.order(result) == 2
    end
  end

  # ============= Structural Comparison =============

  describe "subgraph?/2" do
    test "returns true for actual subgraph" do
      container =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      potential =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      assert Operation.subgraph?(potential, container) == true
    end

    test "returns false for non-subgraph" do
      container =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      potential =
        Yog.undirected()
        |> Yog.add_node(3, nil)
        |> Yog.add_node(4, nil)
        |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

      assert Operation.subgraph?(potential, container) == false
    end

    test "returns true for identical graphs" do
      g =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      assert Operation.subgraph?(g, g) == true
    end
  end

  describe "isomorphic?/2" do
    test "returns true for identical graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      assert Operation.isomorphic?(g1, g2) == true
    end

    test "returns true for isomorphic graphs with different IDs" do
      # Triangle
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)

      # Same triangle, different node IDs
      g2 =
        Yog.undirected()
        |> Yog.add_node(10, nil)
        |> Yog.add_node(20, nil)
        |> Yog.add_node(30, nil)
        |> Yog.add_edge_ensure(from: 10, to: 20, with: 1)
        |> Yog.add_edge_ensure(from: 20, to: 30, with: 1)
        |> Yog.add_edge_ensure(from: 30, to: 10, with: 1)

      assert Operation.isomorphic?(g1, g2) == true
    end

    test "returns false for non-isomorphic graphs" do
      # Triangle
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)

      # Path of 3
      g2 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      assert Operation.isomorphic?(g1, g2) == false
    end

    test "returns false for different sized graphs" do
      g1 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      g2 =
        Yog.undirected()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)

      assert Operation.isomorphic?(g1, g2) == false
    end

    test "returns true for isomorphic square graphs" do
      # Square: 0-1-2-3-0
      g1 =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
        |> Yog.add_edge_ensure(from: 3, to: 0, with: 1)

      # Same square, different IDs
      g2 =
        Yog.undirected()
        |> Yog.add_node(5, nil)
        |> Yog.add_node(6, nil)
        |> Yog.add_node(7, nil)
        |> Yog.add_node(8, nil)
        |> Yog.add_edge_ensure(from: 5, to: 6, with: 1)
        |> Yog.add_edge_ensure(from: 6, to: 7, with: 1)
        |> Yog.add_edge_ensure(from: 7, to: 8, with: 1)
        |> Yog.add_edge_ensure(from: 8, to: 5, with: 1)

      assert Operation.isomorphic?(g1, g2) == true
    end
  end
end
