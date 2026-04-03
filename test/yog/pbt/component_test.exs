defmodule Yog.PBT.ComponentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Connectivity and Component Properties" do
    property "SCC partitioning: Strongly Connected Components partition the nodes" do
      check all(graph <- directed_graph_gen()) do
        sccs = Yog.Connectivity.strongly_connected_components(graph)
        all_nodes = Yog.all_nodes(graph) |> MapSet.new()
        scc_nodes = sccs |> List.flatten() |> MapSet.new()

        assert all_nodes == scc_nodes

        total_len = sccs |> Enum.map(&length/1) |> Enum.sum()
        assert total_len == MapSet.size(scc_nodes)
      end
    end

    property "MST logic: Kruskal and Prim produce the same total weight" do
      check all(graph <- undirected_graph_gen()) do
        components = Yog.Connectivity.connected_components(graph)

        for component <- components do
          sub = Yog.subgraph(graph, component)

          if length(component) > 1 do
            kruskal_edges = Yog.MST.kruskal(in: sub, compare: &Yog.Utils.compare/2)
            k_weight = Enum.reduce(kruskal_edges, 0, fn e, acc -> acc + e.weight end)

            [start_node | _] = component
            prim_edges = Yog.MST.prim(in: sub, from: start_node, compare: &Yog.Utils.compare/2)
            p_weight = Enum.reduce(prim_edges, 0, fn e, acc -> acc + e.weight end)

            assert k_weight == p_weight
          end
        end
      end
    end
  end
end
