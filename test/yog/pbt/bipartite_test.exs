defmodule Yog.PBT.BipartiteTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Property Properties: Bipartite" do
    property "Bipartite graph verification and matching bounds" do
      check all(
              nodes1 <- node_list_gen(1, 10, 50),
              nodes2 <- node_list_gen(1, 10, 50),
              weights <- weight_list_gen(length(nodes1) + length(nodes2), 1..10)
            ) do
        offset = 100
        nodes2 = Enum.map(nodes2, &(&1 + offset))

        graph = Yog.new(:undirected)
        graph = Enum.reduce(nodes1 ++ nodes2, graph, &Yog.add_node(&2, &1, nil))

        graph =
          Enum.reduce(weights, graph, fn {idx1, idx2, w}, g ->
            n1 = Enum.at(nodes1, rem(idx1, length(nodes1)))
            n2 = Enum.at(nodes2, rem(idx2, length(nodes2)))

            # Only cross edges
            case Yog.add_edge(g, n1, n2, w) do
              {:ok, new_g} -> new_g
              _ -> g
            end
          end)

        assert Yog.Property.Bipartite.bipartite?(graph)
        assert {:ok, p} = Yog.Property.Bipartite.partition(graph)

        matching = Yog.Property.Bipartite.maximum_matching(graph, p)
        # matching size cannot exceed min of component sizes
        assert length(matching) <= min(length(nodes1), length(nodes2))
      end
    end
  end
end
