defmodule Yog.DAG.AlgorithmTest do
  @moduledoc """
  Tests for Yog.DAG.Algorithms module.

  These algorithms leverage the acyclic structure of DAGs to provide
  efficient, total functions for operations like topological sorting,
  longest path, transitive closure, and more.
  """

  use ExUnit.Case

  doctest Yog.DAG.Algorithm

  alias Yog.DAG.Model

  alias Yog.DAG.Algorithm

  # Helper to build a DAG from edges
  defp build_dag(edges) do
    dag = Model.new(:directed)

    # Add all nodes first
    nodes =
      edges
      |> Enum.flat_map(fn {from, to, _} -> [from, to] end)
      |> Enum.uniq()

    dag = Enum.reduce(nodes, dag, fn node, d -> Model.add_node(d, node, node) end)

    # Add edges
    Enum.reduce(edges, {:ok, dag}, fn {from, to, weight}, {:ok, d} ->
      Model.add_edge(d, from, to, weight)
    end)
  end

  # ============================================================
  # Topological Sort Tests
  # ============================================================

  describe "topological_sort/1" do
    test "sorts simple linear DAG" do
      {:ok, dag} = build_dag([{:a, :b, 1}, {:b, :c, 2}])

      sorted = Algorithm.topological_sort(dag)
      assert sorted == [:a, :b, :c]
    end

    test "sorts diamond DAG" do
      # Diamond: a -> b, a -> c, b -> d, c -> d
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:a, :c, 2},
          {:b, :d, 3},
          {:c, :d, 4}
        ])

      sorted = Algorithm.topological_sort(dag)
      # :a must be first, :d must be last
      assert hd(sorted) == :a
      assert List.last(sorted) == :d
      # :b and :c must come between :a and :d
      a_index = Enum.find_index(sorted, &(&1 == :a))
      b_index = Enum.find_index(sorted, &(&1 == :b))
      c_index = Enum.find_index(sorted, &(&1 == :c))
      d_index = Enum.find_index(sorted, &(&1 == :d))

      assert a_index < b_index
      assert a_index < c_index
      assert b_index < d_index
      assert c_index < d_index
    end

    test "sorts complex DAG" do
      # More complex structure
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:a, :c, 2},
          {:b, :d, 3},
          {:c, :d, 4},
          {:d, :e, 5}
        ])

      sorted = Algorithm.topological_sort(dag)
      assert hd(sorted) == :a
      assert List.last(sorted) == :e
    end

    test "handles single node DAG" do
      dag = Model.new(:directed) |> Model.add_node(:a, "A")
      assert Algorithm.topological_sort(dag) == [:a]
    end

    test "handles empty DAG" do
      dag = Model.new(:directed)
      assert Algorithm.topological_sort(dag) == []
    end
  end

  # ============================================================
  # Topological Generations Tests
  # ============================================================

  describe "topological_generations/1" do
    test "generations for simple linear DAG" do
      {:ok, dag} = build_dag([{:a, :b, 1}, {:b, :c, 2}])

      assert Algorithm.topological_generations(dag) == [[:a], [:b], [:c]]
    end

    test "generations for diamond DAG" do
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:a, :c, 2},
          {:b, :d, 3},
          {:c, :d, 4}
        ])

      assert Algorithm.topological_generations(dag) == [[:a], [:b, :c], [:d]]
    end

    test "generations for disconnected DAG" do
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:c, :d, 1}
        ])

      gens = Algorithm.topological_generations(dag)
      assert length(gens) == 2
      assert hd(gens) == [:a, :c]
      assert List.last(gens) == [:b, :d]
    end

    test "generations for single node DAG" do
      dag = Model.new(:directed) |> Model.add_node(:a, "A")
      assert Algorithm.topological_generations(dag) == [[:a]]
    end

    test "generations for empty DAG" do
      dag = Model.new(:directed)
      assert Algorithm.topological_generations(dag) == []
    end

    test "generations respect longest-path distance" do
      # a -> b -> d
      # a -> c -> d
      #      c -> e
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:a, :c, 1},
          {:b, :d, 1},
          {:c, :d, 1},
          {:c, :e, 1}
        ])

      assert Algorithm.topological_generations(dag) == [[:a], [:b, :c], [:d, :e]]
    end
  end

  # ============================================================
  # Longest Path Tests
  # ============================================================

  describe "longest_path/1" do
    test "finds longest path in linear DAG" do
      {:ok, dag} = build_dag([{:a, :b, 1}, {:b, :c, 2}])

      path = Algorithm.longest_path(dag)
      assert path == [:a, :b, :c]
    end

    test "finds critical path in weighted DAG" do
      # Diamond with different weights
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:a, :c, 5},
          {:b, :d, 1},
          {:c, :d, 1}
        ])

      path = Algorithm.longest_path(dag)
      # Path a->c->d has weight 6, a->b->d has weight 2
      assert path == [:a, :c, :d]
    end

    test "handles single node" do
      dag = Model.new(:directed) |> Model.add_node(:a, "A")
      assert Algorithm.longest_path(dag) == [:a]
    end

    test "handles disconnected components" do
      # Two separate paths
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:c, :d, 10}
        ])

      path = Algorithm.longest_path(dag)
      # Should return the longest path (c->d)
      assert path == [:c, :d]
    end
  end

  # ============================================================
  # Lowest Common Ancestor Tests
  # ============================================================

  describe "lowest_common_ancestors/3" do
    test "finds single LCA in simple DAG" do
      #    a
      #   / \
      #  b   c
      #   \ /
      #    d
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:a, :c, 2},
          {:b, :d, 3},
          {:c, :d, 4}
        ])

      lcas = Algorithm.lowest_common_ancestors(dag, :b, :c)
      assert lcas == [:a]
    end

    test "finds LCAs in complex DAG" do
      #     x
      #    / \
      #   y   z
      #   |   |
      #   a   b
      {:ok, dag} =
        build_dag([
          {:x, :y, 1},
          {:x, :z, 2},
          {:y, :a, 3},
          {:z, :b, 4}
        ])

      lcas = Algorithm.lowest_common_ancestors(dag, :a, :b)
      assert :x in lcas
    end

    test "handles nodes with no common ancestors" do
      {:ok, dag} =
        build_dag([
          {:a, :b, 1},
          {:c, :d, 2}
        ])

      lcas = Algorithm.lowest_common_ancestors(dag, :b, :d)
      # No common ancestors (except maybe none)
      assert lcas == []
    end

    test "handles same node" do
      {:ok, dag} = build_dag([{:a, :b, 1}])

      lcas = Algorithm.lowest_common_ancestors(dag, :b, :b)
      # A node is its own ancestor in this context
      assert :b in lcas
    end
  end
end
