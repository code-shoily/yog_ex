defmodule Yog.Oracle.PropertiesTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Yog.Oracle.NetworkX

  setup_all do
    case NetworkX.adapter_health() do
      :ok ->
        :ok

      {:error, reason} ->
        {:skip, "NetworkX adapter not healthy: #{inspect(reason)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Bipartite
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PROP-001 Bipartite check agrees with NetworkX" do
    check all(
            graph <- Yog.Generators.graph_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Property.Bipartite.bipartite?(graph)
      nx_result = NetworkX.run("is_bipartite", graph, [])

      assert yog_result == nx_result
    end
  end

  # ---------------------------------------------------------------------------
  # Tree / Forest / DAG
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PROP-002 Tree check agrees with NetworkX" do
    check all(
            graph <- Yog.Generators.undirected_graph_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Property.Structure.tree?(graph)
      nx_result = NetworkX.run("is_tree", graph, [])

      assert yog_result == nx_result
    end
  end

  @tag :oracle
  property "P-ORAC-PROP-003 Forest check agrees with NetworkX" do
    check all(
            graph <- Yog.Generators.undirected_graph_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Property.Structure.forest?(graph)
      nx_result = NetworkX.run("is_forest", graph, [])

      assert yog_result == nx_result
    end
  end

  @tag :oracle
  property "P-ORAC-PROP-004 DAG check agrees with NetworkX" do
    check all(
            graph <- Yog.Generators.directed_graph_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Property.Cyclicity.acyclic?(graph)
      nx_result = NetworkX.run("is_directed_acyclic_graph", graph, [])

      assert yog_result == nx_result
    end
  end

  # ---------------------------------------------------------------------------
  # Clique number
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PROP-005 Clique number agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 20
          ) do
      case {Yog.Property.Clique.max_clique(graph), NetworkX.run("graph_clique_number", graph, [])} do
        {%MapSet{} = clique, nx_result} ->
          assert MapSet.size(clique) == nx_result

        {other, _nx_result} ->
          flunk("max_clique returned #{inspect(other)}, expected MapSet")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Isomorphism
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PROP-006 Graph isomorphism agrees with NetworkX" do
    check all(
            g1 <- Yog.Generators.graph_gen(),
            nodes = Map.keys(g1.nodes),
            shuffled = Enum.shuffle(nodes),
            mapping = Enum.zip(nodes, shuffled) |> Map.new(),
            g2 = Yog.Transform.relabel_nodes(g1, fn id -> Map.fetch!(mapping, id) end),
            g3 <- Yog.Generators.graph_of_kind_gen(g1.kind),
            max_runs: 50
          ) do
      # 1. G1 is isomorphic to its relabeled version G2
      assert Yog.Operation.isomorphic?(g1, g2) == true

      # Verify via NetworkX
      assert NetworkX.run("is_isomorphic", g1, other_graph: g2) == true

      # 2. G1 is isomorphic to G3 if and only if NetworkX agrees
      yog_iso = Yog.Operation.isomorphic?(g1, g3)
      nx_iso = NetworkX.run("is_isomorphic", g1, other_graph: g3)
      assert yog_iso == nx_iso
    end
  end

  # ---------------------------------------------------------------------------
  # Weisfeiler-Lehman Graph Hash
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-PROP-007 Weisfeiler-Lehman Graph Hash matches on isomorphic graphs" do
    check all(
            g1 <- Yog.Generators.graph_gen(),
            nodes = Map.keys(g1.nodes),
            shuffled = Enum.shuffle(nodes),
            mapping = Enum.zip(nodes, shuffled) |> Map.new(),
            g2 = Yog.Transform.relabel_nodes(g1, fn id -> Map.fetch!(mapping, id) end),
            max_runs: 50
          ) do
      hash1 = Yog.Property.WeisfeilerLehman.graph_hash(g1)
      hash2 = Yog.Property.WeisfeilerLehman.graph_hash(g2)
      assert hash1 == hash2
    end
  end

  @tag :oracle
  property "P-ORAC-PROP-008 Weisfeiler-Lehman Graph Hash equivalence matches NetworkX" do
    check all(
            g1 <- Yog.Generators.graph_gen(),
            g2 <- Yog.Generators.graph_of_kind_gen(g1.kind),
            max_runs: 50
          ) do
      nodes = Map.keys(g1.nodes)
      shuffled = Enum.shuffle(nodes)
      mapping = Enum.zip(nodes, shuffled) |> Map.new()
      g1_relabeled = Yog.Transform.relabel_nodes(g1, fn id -> Map.fetch!(mapping, id) end)

      yog_hash1 = Yog.Property.WeisfeilerLehman.graph_hash(g1)
      yog_hash_relabeled = Yog.Property.WeisfeilerLehman.graph_hash(g1_relabeled)
      assert yog_hash1 == yog_hash_relabeled

      nx_hash1 = NetworkX.run("weisfeiler_lehman_graph_hash", g1)
      nx_hash_relabeled = NetworkX.run("weisfeiler_lehman_graph_hash", g1_relabeled)
      assert nx_hash1 == nx_hash_relabeled

      yog_hash2 = Yog.Property.WeisfeilerLehman.graph_hash(g2)
      nx_hash2 = NetworkX.run("weisfeiler_lehman_graph_hash", g2)

      assert yog_hash1 == yog_hash2 == (nx_hash1 == nx_hash2)
    end
  end
end
