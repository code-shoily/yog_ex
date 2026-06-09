defmodule Yog.Oracle.MSTTest do
  use ExUnit.Case, async: true
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

  # Builds a connected undirected graph with a path backbone + random edges.
  defp connected_undirected_graph_gen(node_range, weight_range) do
    gen all(
          nodes <- Yog.Generators.node_list_gen(elem(node_range, 0), elem(node_range, 1)),
          edges <- Yog.Generators.weight_list_gen(length(nodes), weight_range),
          indices = Enum.to_list(0..(length(nodes) - 1)),
          backbone = Enum.chunk_every(indices, 2, 1, :discard),
          backbone_edges = Enum.map(backbone, fn [u, v] -> {u, v, 1} end),
          all_edges = edges ++ backbone_edges
        ) do
      Yog.Generators.build_graph(:undirected, nodes, all_edges)
    end
  end

  # ---------------------------------------------------------------------------
  # Kruskal
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MST-001 Kruskal MST weight agrees with NetworkX" do
    check all(
            graph <- connected_undirected_graph_gen({3, 20}, 0..100),
            max_runs: 50
          ) do
      {:ok, yog_result} = Yog.MST.kruskal(graph)

      nx_weight =
        NetworkX.run("minimum_spanning_tree", graph,
          algorithm: "kruskal",
          weight: "weight"
        )

      assert_in_delta yog_result.total_weight, nx_weight, 1.0e-9
    end
  end

  # ---------------------------------------------------------------------------
  # Prim
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MST-002 Prim MST weight agrees with NetworkX" do
    check all(
            graph <- connected_undirected_graph_gen({3, 20}, 0..100),
            max_runs: 50
          ) do
      {:ok, yog_result} = Yog.MST.prim(graph)

      nx_weight =
        NetworkX.run("minimum_spanning_tree", graph,
          algorithm: "prim",
          weight: "weight"
        )

      assert_in_delta yog_result.total_weight, nx_weight, 1.0e-9
    end
  end

  # ---------------------------------------------------------------------------
  # Boruvka
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MST-003 Boruvka MST weight agrees with NetworkX" do
    check all(
            graph <- connected_undirected_graph_gen({3, 20}, 0..100),
            max_runs: 50
          ) do
      {:ok, yog_result} = Yog.MST.boruvka(graph)

      nx_weight =
        NetworkX.run("minimum_spanning_tree", graph,
          algorithm: "boruvka",
          weight: "weight"
        )

      assert_in_delta yog_result.total_weight, nx_weight, 1.0e-9
    end
  end

  # ---------------------------------------------------------------------------
  # Maximum Spanning Tree
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MST-004 Max ST weight agrees with NetworkX" do
    check all(
            graph <- connected_undirected_graph_gen({3, 20}, 0..100),
            max_runs: 50
          ) do
      {:ok, yog_result} = Yog.MST.maximum_spanning_tree(graph)

      nx_weight =
        NetworkX.run("maximum_spanning_tree", graph,
          algorithm: "kruskal",
          weight: "weight"
        )

      assert_in_delta yog_result.total_weight, nx_weight, 1.0e-9
    end
  end

  # ---------------------------------------------------------------------------
  # Minimum Spanning Arborescence (directed MST / Chu-Liu/Edmonds)
  # ---------------------------------------------------------------------------
  # NOTE: Divergence — NetworkX minimum_spanning_arborescence does not accept
  # a root parameter and may choose a different root than YogEx.  Comparing
  # total weights is therefore invalid.  This is documented in PARITY.md
  # as a 🔴 diverged row.  We verify YogEx correctness via structural
  # invariants instead of an oracle.
  #
  # @tag :oracle
  # property "P-ORAC-MST-005 Minimum arborescence weight agrees with NetworkX" do
  #   ...
  # end
end
