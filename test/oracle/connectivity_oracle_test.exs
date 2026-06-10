defmodule Yog.Oracle.ConnectivityTest do
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
  # Helpers
  # ---------------------------------------------------------------------------

  defp assert_sets_equal(list1, list2) do
    set1 = list1 |> Enum.map(&Enum.sort/1) |> Enum.sort() |> MapSet.new()
    set2 = list2 |> Enum.map(&Enum.sort/1) |> Enum.sort() |> MapSet.new()
    assert set1 == set2
  end

  # ---------------------------------------------------------------------------
  # Strongly connected components
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CONN-001 SCC agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 20),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Connectivity.SCC.strongly_connected_components(graph)

      nx_result = NetworkX.run("strongly_connected_components", graph, [])

      assert_sets_equal(yog_result, nx_result)
    end
  end

  # ---------------------------------------------------------------------------
  # Connected components (undirected)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CONN-002 Connected components agree with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 20),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Connectivity.Components.connected_components(graph)

      nx_result = NetworkX.run("connected_components", graph, [])

      assert_sets_equal(yog_result, nx_result)
    end
  end

  # ---------------------------------------------------------------------------
  # Weakly connected components (directed)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CONN-003 Weakly connected components agree with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 20),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Connectivity.Components.weakly_connected_components(graph)

      nx_result = NetworkX.run("weakly_connected_components", graph, [])

      assert_sets_equal(yog_result, nx_result)
    end
  end

  # ---------------------------------------------------------------------------
  # Tarjan's Bridges & Articulation Points (undirected)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CONN-004 Bridges agree with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Connectivity.analyze(graph)

      yog_bridges =
        Enum.map(yog_result.bridges, fn {u, v} -> Enum.sort([u, v]) end) |> Enum.sort()

      nx_result = NetworkX.run("bridges", graph, [])
      nx_bridges = Enum.map(nx_result, &Enum.sort/1) |> Enum.sort()

      assert yog_bridges == nx_bridges
    end
  end

  @tag :oracle
  property "P-ORAC-CONN-005 Articulation points agree with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 25),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Connectivity.analyze(graph)
      yog_points = Enum.sort(yog_result.articulation_points)

      nx_result = NetworkX.run("articulation_points", graph, [])
      nx_points = Enum.sort(nx_result)

      assert yog_points == nx_points
    end
  end
end
