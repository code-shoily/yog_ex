defmodule Yog.PBT.StructureTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Tree Properties" do
    property "generated trees are indeed trees" do
      check all(graph <- tree_gen()) do
        assert Yog.tree?(graph)
        assert Yog.acyclic?(graph)
        assert Yog.edge_count(graph) == Yog.node_count(graph) - 1
      end
    end
  end

  describe "Arborescence Properties" do
    property "generated arborescences are valid" do
      check all(graph <- arborescence_gen()) do
        assert Yog.arborescence?(graph)
        root = Yog.arborescence_root(graph)
        assert root != nil

        nodes = Yog.all_nodes(graph)
        visited = Yog.Traversal.walk(graph, root, :breadth_first)
        assert length(visited) == length(nodes)

        for node <- nodes do
          if node == root do
            assert length(Yog.predecessors(graph, node)) == 0
          else
            assert length(Yog.predecessors(graph, node)) == 1
          end
        end
      end
    end
  end

  describe "Complete Graph Properties" do
    property "Kn is complete" do
      check all(n <- StreamData.integer(2..15)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.undirected()
        graph = Enum.reduce(nodes, graph, fn id, g -> Yog.add_node(g, id, nil) end)

        graph =
          for u <- nodes, v <- nodes, u < v, reduce: graph do
            acc -> Yog.add_edge!(acc, u, v, 1)
          end

        assert Yog.complete?(graph)
      end
    end

    property "Kn is (n-1)-regular" do
      check all(n <- StreamData.integer(2..15)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.undirected()
        graph = Enum.reduce(nodes, graph, fn id, g -> Yog.add_node(g, id, nil) end)

        graph =
          for u <- nodes, v <- nodes, u < v, reduce: graph do
            acc -> Yog.add_edge!(acc, u, v, 1)
          end

        assert Yog.regular?(graph, n - 1)
      end
    end

    property "Incomplete graph is not complete" do
      graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
      refute Yog.complete?(graph)
    end
  end
end
