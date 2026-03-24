defmodule Yog.PBT.StructuralTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Structural Properties" do
    property "transpose is involutive: transpose(transpose(G)) == G" do
      check all(graph <- directed_graph_gen()) do
        assert graph == graph |> Yog.transpose() |> Yog.transpose()
      end
    end

    property "undirected graphs are symmetric" do
      check all(graph <- undirected_graph_gen()) do
        edges = Yog.all_edges(graph)

        for {u, v, w} <- edges do
          successors_v = Yog.successors(graph, v)
          assert {u, w} in successors_v
        end
      end
    end

    property "edge count consistency" do
      check all(graph <- graph_gen()) do
        count = Yog.edge_count(graph)
        edges = Yog.all_edges(graph)

        assert count == length(edges)
      end
    end

    property "to_undirected creates symmetry" do
      check all(graph <- directed_graph_gen()) do
        undir = Yog.Transform.to_undirected(graph, &min/2)
        assert undir.kind == :undirected

        edges = Yog.all_edges(undir)

        for {u, v, w} <- edges do
          successors_v = Yog.successors(undir, v)
          assert {u, w} in successors_v
        end
      end
    end
  end
end
