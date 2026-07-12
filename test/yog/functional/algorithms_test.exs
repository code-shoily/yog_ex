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

  describe "topsort edge cases" do
    test "topsort on empty graph" do
      assert {:ok, []} = Algorithms.topsort(Model.empty())
    end

    test "topsort on single-node graph" do
      graph = Model.empty() |> Model.put_node(1, "A")
      assert {:ok, [1]} = Algorithms.topsort(graph)
    end

    test "topsort handles self-loop as cycle" do
      graph = Model.empty() |> Model.put_node(1, "A") |> Model.add_edge!(1, 1)
      assert {:error, :cycle_detected} = Algorithms.topsort(graph)
    end

    test "topsort handles already-matched node in zero list" do
      # Create a graph where a zero-in-degree node gets added to the list
      # but is already processed by the time we get to it.
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(1, 3)

      {:ok, order} = Algorithms.topsort(g)
      assert hd(order) == 1
      assert Enum.sort(tl(order)) == [2, 3]
    end

    test "topsort with multiple valid roots" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 3)
        |> Model.add_edge!(2, 3)

      {:ok, order} = Algorithms.topsort(g)
      assert List.last(order) == 3
      assert Enum.sort(Enum.take(order, 2)) == [1, 2]
    end
  end

  describe "shortest_path edge cases" do
    test "shortest path returns no_path for missing source or target" do
      graph = Model.empty() |> Model.put_node(1, "A") |> Model.put_node(2, "B")

      assert {:error, :no_path} = Algorithms.shortest_path(graph, 99, 2)
      assert {:error, :no_path} = Algorithms.shortest_path(graph, 1, 99)
    end

    test "shortest path treats nil edge labels as weight 1" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, nil)

      assert {:ok, [1, 2], 1} = Algorithms.shortest_path(graph, 1, 2)
    end

    test "shortest path start equals target" do
      g = Model.empty() |> Model.put_node(1, "A")
      assert {:ok, [1], 0} = Algorithms.shortest_path(g, 1, 1)

      # Node not in graph
      assert {:error, :no_path} = Algorithms.shortest_path(g, 99, 99)
    end

    test "shortest path when start node has no outgoing edges" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(2, 1, 1)

      # Can't reach 2 from 1 since edge is 2->1
      assert {:error, :no_path} = Algorithms.shortest_path(g, 1, 2)
    end

    test "shortest path skips stale priority queue entries" do
      # A->B weight 10, A->C weight 1, C->B weight 1
      # B is first discovered with distance 10, then later with distance 2
      # The stale entry (10) should be skipped after B is settled at distance 2
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2, 10)
        |> Model.add_edge!(1, 3, 1)
        |> Model.add_edge!(3, 2, 1)

      assert {:ok, [1, 3, 2], 2} = Algorithms.shortest_path(g, 1, 2)
    end

    test "shortest path processes stale pq entry before target" do
      # Long chain where a stale PQ entry is popped before the target.
      # A->B weight 10, A->C weight 1, C->B weight 1,
      # then B->D1->D2->...->D8->Target with weight 1 each.
      # B is settled at distance 2. The stale B(10) is still in PQ.
      # By the time we reach the target at distance 10, the stale B(10)
      # may be popped first (depending on heap ordering), exercising the
      # already-settled skip path.
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D1")
        |> Model.put_node(5, "D2")
        |> Model.put_node(6, "D3")
        |> Model.put_node(7, "D4")
        |> Model.put_node(8, "D5")
        |> Model.put_node(9, "D6")
        |> Model.put_node(10, "D7")
        |> Model.put_node(11, "D8")
        |> Model.put_node(12, "Target")
        |> Model.add_edge!(1, 2, 10)
        |> Model.add_edge!(1, 3, 1)
        |> Model.add_edge!(3, 2, 1)
        |> Model.add_edge!(2, 4, 1)
        |> Model.add_edge!(4, 5, 1)
        |> Model.add_edge!(5, 6, 1)
        |> Model.add_edge!(6, 7, 1)
        |> Model.add_edge!(7, 8, 1)
        |> Model.add_edge!(8, 9, 1)
        |> Model.add_edge!(9, 10, 1)
        |> Model.add_edge!(10, 11, 1)
        |> Model.add_edge!(11, 12, 1)

      assert {:ok, path, 11} = Algorithms.shortest_path(g, 1, 12)
      assert hd(path) == 1
      assert List.last(path) == 12
      assert length(path) == 12
    end
  end

  describe "distances edge cases" do
    test "distances from missing source is empty" do
      graph = Model.empty() |> Model.put_node(1, "A")
      assert Algorithms.distances(graph, 99) == %{}
    end

    test "distances omit unreachable nodes" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2, 1)

      assert Algorithms.distances(graph, 1) == %{1 => 0, 2 => 1}
    end

    test "distances treats nil edge labels as weight 1" do
      graph =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, nil)

      assert Algorithms.distances(graph, 1) == %{1 => 0, 2 => 1}
    end

    test "distances skips already-settled nodes" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2, 1)
        |> Model.add_edge!(1, 3, 5)
        |> Model.add_edge!(2, 3, 1)

      dist = Algorithms.distances(g, 1)
      assert dist[3] == 2
    end
  end

  describe "mst_prim edge cases" do
    test "mst_prim on empty graph" do
      assert {:ok, []} = Algorithms.mst_prim(Model.empty())
    end

    test "mst_prim on single node" do
      g = Model.new(:undirected) |> Model.put_node(1, "A")
      assert {:ok, []} = Algorithms.mst_prim(g)
    end

    test "mst_prim treats nil edge labels as weight 1" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2, nil)

      assert {:ok, [{_, _, 1}]} = Algorithms.mst_prim(g)
    end

    test "mst_prim returns one component tree for disconnected graphs" do
      g =
        Model.new(:undirected)
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.put_node(4, "D")
        |> Model.add_edge!(1, 2, 1)
        |> Model.add_edge!(3, 4, 2)

      assert {:ok, edges} = Algorithms.mst_prim(g)
      assert length(edges) == 1
      assert Enum.map(edges, fn {_u, _v, w} -> w end) in [[1], [2]]
    end
  end

  describe "scc" do
    test "scc on empty graph" do
      assert Algorithms.scc(Model.empty()) == []
    end

    test "scc on single node graph" do
      graph = Model.empty() |> Model.put_node(1, "A")
      assert Algorithms.scc(graph) == [[1]]
    end

    test "scc with self-loop is one singleton component" do
      graph = Model.empty() |> Model.put_node(1, "A") |> Model.add_edge!(1, 1)
      assert Algorithms.scc(graph) == [[1]]
    end

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

    test "scc with disconnected nodes" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 1)

      sccs = Algorithms.scc(g)
      assert length(sccs) == 2
      comp_sets = Enum.map(sccs, &MapSet.new/1)
      assert MapSet.new([1, 2]) in comp_sets
      assert MapSet.new([3]) in comp_sets
    end

    test "scc with two-node cycle" do
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(2, 1)

      sccs = Algorithms.scc(g)
      assert length(sccs) == 1
      assert Enum.sort(hd(sccs)) == [1, 2]
    end

    test "scc with sink and cycle" do
      # 1 points to 2 and 3; 2 and 3 form a cycle
      # SCCs: {1} and {2, 3}
      g =
        Model.empty()
        |> Model.put_node(1, "A")
        |> Model.put_node(2, "B")
        |> Model.put_node(3, "C")
        |> Model.add_edge!(1, 2)
        |> Model.add_edge!(1, 3)
        |> Model.add_edge!(2, 3)
        |> Model.add_edge!(3, 2)

      sccs = Algorithms.scc(g)
      assert length(sccs) == 2
      comp_sets = Enum.map(sccs, &MapSet.new/1)
      assert MapSet.new([1]) in comp_sets
      assert MapSet.new([2, 3]) in comp_sets
    end

    test "scc throws on undirected graph" do
      g = Model.new(:undirected)
      assert_raise ArgumentError, fn -> Algorithms.scc(g) end
    end
  end
end
