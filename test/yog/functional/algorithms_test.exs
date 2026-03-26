defmodule Yog.Functional.AlgorithmsTest do
  use ExUnit.Case, async: true
  alias Yog.Functional.Model
  alias Yog.Functional.Algorithms
  doctest Yog.Functional.Algorithms

  setup do
    g =
      Model.empty()
      |> Model.put_node(1, "A")
      |> Model.put_node(2, "B")
      |> Model.put_node(3, "C")
      |> Model.put_node(4, "D")

    {:ok, graph: g}
  end

  describe "topsort" do
    test "topological sort of a DAG", %{graph: graph} do
      g =
        graph
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(1, 4)
        |> Model.add_edge!(4, 3)

      {:ok, order} = Algorithms.topsort(g)
      assert order == [1, 4, 2, 3] or order == [1, 2, 4, 3]
    end

    test "topological sort of a cyclic graph", %{graph: graph} do
      g =
        graph
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)

      assert {:error, :cycle_detected} = Algorithms.topsort(g)
    end
  end

  describe "shortest_path" do
    test "shortest path with Dijkstra", %{graph: graph} do
      g =
        graph
        |> Model.add_edge!(1, 2, 1)
        |> Model.add_edge!(2, 3, 2)
        |> Model.add_edge!(1, 4, 4)
        |> Model.add_edge!(4, 3, 1)
        |> Model.add_edge!(1, 3, 5)

      {:ok, path, dist} = Algorithms.shortest_path(g, 1, 3)
      assert path == [1, 2, 3]
      assert dist == 3
    end

    test "shortest path when unreachable", %{graph: graph} do
      g = graph |> Model.add_edge!(1, 2, 1)

      assert {:error, :no_path} = Algorithms.shortest_path(g, 1, 3)
    end
  end

  describe "distances" do
    test "computes all distances from source", %{graph: graph} do
      g =
        graph
        |> Model.add_edge!(1, 2, 1)
        |> Model.add_edge!(2, 3, 2)
        |> Model.add_edge!(1, 4, 4)

      dist_map = Algorithms.distances(g, 1)
      assert dist_map == %{1 => 0, 2 => 1, 3 => 3, 4 => 4}
    end
  end

  describe "mst_prim" do
    test "minimum spanning tree" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.add_edge!(1, 2, 1)
        |> Model.add_edge!(2, 3, 2)
        |> Model.add_edge!(1, 4, 4)
        |> Model.add_edge!(4, 3, 1)
        |> Model.add_edge!(1, 3, 5)

      {:ok, edges} = Algorithms.mst_prim(g)

      # Kruskal/Prim MST edges: (1,2) weight 1, (4,3) weight 1, (2,3) weight 2 -> total 4
      total_weight = Enum.reduce(edges, 0, fn {_, _, w}, acc -> acc + w end)
      assert total_weight == 4
      assert length(edges) == 3
    end
  end

  describe "scc" do
    test "strongly connected components", %{graph: graph} do
      g =
        graph
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 1)
        |> Model.add_edge!(3, 4)

      sccs = Algorithms.scc(g)
      assert length(sccs) == 2
      assert [4] in sccs

      # The cycle component can be in any order
      cycle_scc = Enum.find(sccs, fn c -> length(c) == 3 end)
      assert Enum.sort(cycle_scc) == [1, 2, 3]
    end

    test "scc throws on undirected graph" do
      g = Model.new(:undirected)
      assert_raise ArgumentError, fn -> Algorithms.scc(g) end
    end
  end
end
