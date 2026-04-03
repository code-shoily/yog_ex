defmodule Yog.PBT.MSTTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "MST Properties" do
    property "kruskal and prim agree on total weight for connected undirected graphs" do
      check all(graph <- undirected_graph_gen()) do
        components = Yog.Connectivity.connected_components(graph)

        for component <- components do
          sub = Yog.subgraph(graph, component)

          if length(component) > 1 do
            {:ok, kruskal_result} = Yog.MST.kruskal(in: sub, compare: &Yog.Utils.compare/2)
            [start_node | _] = component

            {:ok, prim_result} =
              Yog.MST.prim(in: sub, from: start_node, compare: &Yog.Utils.compare/2)

            assert kruskal_result.total_weight == prim_result.total_weight
          end
        end
      end
    end

    property "MST edge count equals V - c for a graph with c connected components" do
      check all(graph <- undirected_graph_gen()) do
        {:ok, result} = Yog.MST.kruskal(in: graph, compare: &Yog.Utils.compare/2)

        components = Yog.Connectivity.connected_components(graph)
        num_components = length(components)
        num_nodes = Yog.node_count(graph)

        expected_edges = max(0, num_nodes - num_components)
        assert result.edge_count == expected_edges
      end
    end

    property "MST is cycle-free (no duplicate undirected edges)" do
      check all(graph <- undirected_graph_gen()) do
        {:ok, result} = Yog.MST.kruskal(in: graph, compare: &Yog.Utils.compare/2)

        edge_pairs =
          Enum.map(result.edges, fn e ->
            [e.from, e.to] |> Enum.sort() |> List.to_tuple()
          end)

        assert length(edge_pairs) == length(Enum.uniq(edge_pairs))
      end
    end

    property "MST total weight is non-negative for non-negative weights" do
      check all(graph <- undirected_graph_gen()) do
        {:ok, result} = Yog.MST.kruskal(in: graph, compare: &Yog.Utils.compare/2)

        all_non_negative? =
          Enum.all?(Yog.all_edges(graph), fn {_u, _v, w} -> is_number(w) and w >= 0 end)

        if all_non_negative? do
          assert result.total_weight >= 0
        end
      end
    end

    property "MST of a tree is the tree itself" do
      check all(graph <- tree_gen()) do
        {:ok, result} = Yog.MST.kruskal(in: graph, compare: &Yog.Utils.compare/2)

        assert result.edge_count == Yog.edge_count(graph)

        assert result.total_weight ==
                 Enum.reduce(Yog.all_edges(graph), 0, fn {_u, _v, w}, acc -> acc + w end)
      end
    end

    property "directed graphs return error" do
      check all(graph <- directed_graph_gen()) do
        assert Yog.MST.kruskal(in: graph, compare: &Yog.Utils.compare/2) ==
                 {:error, :undirected_only}

        assert Yog.MST.prim(in: graph, compare: &Yog.Utils.compare/2) ==
                 {:error, :undirected_only}
      end
    end
  end
end
