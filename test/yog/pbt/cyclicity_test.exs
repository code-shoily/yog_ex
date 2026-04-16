defmodule Yog.PBT.CyclicityTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Property Properties: Cyclicity" do
    property "DAG generated using numeric order edges is acyclic" do
      check all(
              nodes <- node_list_gen(2, 20, 500),
              weights <- weight_list_gen(length(nodes))
            ) do
        sorted_nodes = Enum.sort(nodes) |> Enum.uniq()

        graph = Enum.reduce(sorted_nodes, Yog.new(:directed), &Yog.add_node(&2, &1, nil))

        graph =
          Enum.reduce(weights, graph, fn {idx1, idx2, w}, g ->
            min_idx = min(idx1, idx2)
            max_idx = max(idx1, idx2)

            if min_idx != max_idx do
              n_from = Enum.at(sorted_nodes, rem(min_idx, length(sorted_nodes)))
              n_to = Enum.at(sorted_nodes, rem(max_idx, length(sorted_nodes)))

              {n1, n2} = if n_from < n_to, do: {n_from, n_to}, else: {n_to, n_from}

              if n1 != n2 do
                case Yog.add_edge(g, n1, n2, w) do
                  {:ok, new_g} -> new_g
                  _ -> g
                end
              else
                g
              end
            else
              g
            end
          end)

        assert Yog.Property.Cyclicity.acyclic?(graph)
        refute Yog.Property.Cyclicity.cyclic?(graph)
      end
    end
  end
end
