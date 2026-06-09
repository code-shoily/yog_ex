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
      yog_clique = Yog.Property.Clique.max_clique(graph)
      nx_result = NetworkX.run("graph_clique_number", graph, [])

      yog_size = if is_struct(yog_clique, MapSet), do: MapSet.size(yog_clique), else: 0

      assert yog_size == nx_result
    end
  end
end
