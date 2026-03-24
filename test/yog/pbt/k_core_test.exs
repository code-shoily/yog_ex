defmodule Yog.PBT.KCoreTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "K-Core Properties" do
    property "k-core nodes have degree >= k" do
      check all(
              graph <- undirected_graph_gen(),
              k <- StreamData.integer(1..5)
            ) do
        core = Yog.k_core(graph, k)

        # All nodes in core must have at least degree k IN THE SUBGRAPH
        for node <- Yog.all_nodes(core) do
          assert length(Yog.neighbor_ids(core, node)) >= k
        end
      end
    end

    property "core_numbers are consistent with k-cores" do
      check all(graph <- undirected_graph_gen()) do
        cores = Yog.Connectivity.KCore.core_numbers(graph)

        for {node, k} <- cores do
          # Node must be in k-core but not in (k+1)-core
          # Actually node must be in k-core and if k+1-core exists it must not be in it
          core = Yog.k_core(graph, k)
          assert Yog.has_node?(core, node)

          # Check one higher
          higher_core = Yog.k_core(graph, k + 1)
          refute Yog.has_node?(higher_core, node)
        end
      end
    end

    property "complete graph Kn has (n-1)-core" do
      check all(n <- StreamData.integer(3..10)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.undirected()
        graph = Enum.reduce(nodes, graph, fn id, g -> Yog.add_node(g, id, nil) end)

        graph =
          for u <- nodes, v <- nodes, u < v, reduce: graph do
            acc -> Yog.add_edge!(acc, u, v, 1)
          end

        # (n-1)-core is the whole graph
        core = Yog.k_core(graph, n - 1)
        assert Yog.node_count(core) == n

        # n-core should be empty
        empty_core = Yog.k_core(graph, n)
        assert Yog.node_count(empty_core) == 0
      end
    end
  end
end
