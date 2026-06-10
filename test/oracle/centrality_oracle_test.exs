defmodule Yog.Oracle.CentralityTest do
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

  defp assert_maps_close(m1, m2, delta: delta) do
    assert Map.keys(m1) |> Enum.sort() == Map.keys(m2) |> Enum.sort()

    for {k, v1} <- m1 do
      v2 = Map.fetch!(m2, k)
      assert_in_delta v1, v2, delta, "mismatch at #{inspect(k)}: yog=#{v1}, nx=#{v2}"
    end
  end

  # Generates simple edges without self-loops to avoid degree convention divergence.
  defp simple_edges_gen(num_nodes) do
    StreamData.list_of(
      {StreamData.integer(0..(num_nodes - 1)), StreamData.integer(0..(num_nodes - 1)),
       StreamData.integer(-100..100)},
      max_length: 30
    )
    |> StreamData.map(fn edges -> Enum.reject(edges, fn {u, v, _} -> u == v end) end)
  end

  # ---------------------------------------------------------------------------
  # Degree centrality — exact-output, robust
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-001 Degree centrality agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.degree(graph)

      nx_result = NetworkX.run("degree_centrality", graph, [])

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  @tag :oracle
  property "P-ORAC-CENT-002 In-degree centrality agrees with NetworkX on directed graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.degree(graph, :in_degree)

      nx_result = NetworkX.run("in_degree_centrality", graph, [])

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  @tag :oracle
  property "P-ORAC-CENT-003 Out-degree centrality agrees with NetworkX on directed graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.degree(graph, :out_degree)

      nx_result = NetworkX.run("out_degree_centrality", graph, [])

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  # ---------------------------------------------------------------------------
  # HITS — documented divergence (🔴), not oracle-tested.
  #
  # Yog and NetworkX use mathematically distinct HITS formulations:
  # Yog runs iterative power method with L2 normalization; NetworkX runs
  # scipy SVD on the adjacency matrix and L1-normalizes the result.
  # Both are valid implementations of the Kleinberg HITS algorithm,
  # but they give measurably different absolute values on near-degenerate
  # inputs (cycles, sparse digraphs, graphs with near-tied singular
  # values). See `lib/yog/centrality.ex:658` for Yog's L2 iterative
  # path and `nx.hits` (scipy branch) for NetworkX's SVD path.
  #
  # Yog's HITS is verified by unit tests in `test/yog/centrality_test.exs`
  # and the smoke test in `test/yog/centrality_smoke_test.exs`. The
  # oracle layer doesn't cover it.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # PageRank — tolerance-based, unweighted, with dangling-node handling
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-008 PageRank agrees with NetworkX on directed graphs" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 1..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      # Yog defaults are looser (tol=0.0001, max_iter=100) than the
      # adapter's (tol=1e-10, max_iter=1000). Tighten Yog here so both
      # converge to the same stationary distribution within 1e-9.
      yog_result =
        Yog.Centrality.pagerank(graph, tolerance: 1.0e-10, max_iterations: 1000)

      nx_result =
        NetworkX.run("pagerank", graph, %{
          "alpha" => 0.85,
          "tol" => 1.0e-10,
          "max_iter" => 1000
        })

      assert_maps_close(yog_result, nx_result, delta: 1.0e-6)
    end
  end

  # ---------------------------------------------------------------------------
  # Betweenness centrality — exact-output, unnormalized (Yog convention)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-006 Betweenness centrality agrees with NetworkX (undirected, weighted)" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 1..100),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      # Yog returns raw Brandes dependency counts with the undirected
      # /2 correction. NetworkX with normalized=False does the same:
      # it applies a 0.5 scale for undirected graphs (see _rescale in
      # networkx/algorithms/centrality/betweenness.py). Pin NX to that
      # convention by passing normalized=false.
      yog_result = Yog.Centrality.betweenness(graph)

      nx_result =
        NetworkX.run("betweenness_centrality", graph, %{
          "normalized" => false,
          "endpoints" => false
        })

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  @tag :oracle
  property "P-ORAC-CENT-007 Betweenness centrality agrees with NetworkX (directed, weighted)" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 1..100),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.betweenness(graph)

      nx_result =
        NetworkX.run("betweenness_centrality", graph, %{
          "normalized" => false,
          "endpoints" => false
        })

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  # ---------------------------------------------------------------------------
  # Closeness centrality — exact-output with WF correction on both sides
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-005 Closeness centrality agrees with NetworkX (Wasserman-Faust)" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 1..100),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      # Both sides use the Wasserman-Faust correction so partially-
      # connected nodes get a scaled-by-reachable-fraction score rather
      # than the Yog-default 0.0. Adapter passes wf_improved=True
      # (NetworkX default); Yog requires explicit opt-in.
      yog_result = Yog.Centrality.closeness(graph, wf_improved: true)
      nx_result = NetworkX.run("closeness_centrality", graph, %{"wf_improved" => true})

      assert_maps_close(yog_result, nx_result, delta: 1.0e-9)
    end
  end

  # ---------------------------------------------------------------------------
  # Harmonic centrality — exact-output, with normalization adjustment
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-004 Harmonic centrality agrees with NetworkX (after normalization)" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- Yog.Generators.weight_list_gen(length(nodes), 1..100),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Centrality.harmonic(graph)
      nx_result = NetworkX.run("harmonic_centrality", graph, [])

      # Convention delta: Yog normalizes by (n - 1), NetworkX does not
      # (Boldi & Vigna 2014). Scale Yog up to compare.
      n = length(nodes)
      scaled = Map.new(yog_result, fn {k, v} -> {k, v * (n - 1)} end)

      assert_maps_close(scaled, nx_result, delta: 1.0e-9)
    end
  end

  # ---------------------------------------------------------------------------
  # Eigenvector centrality
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-009 Eigenvector centrality agrees with NetworkX" do
    check all(
            graph <- connected_non_bipartite_graph_gen({3, 15}),
            max_runs: 50
          ) do
      # Set tight tolerances so both converge to the exact same vector
      yog_result = Yog.Centrality.eigenvector(graph, tolerance: 1.0e-9, max_iterations: 1000)

      nx_result =
        NetworkX.run("eigenvector_centrality", graph, %{
          "tol" => 1.0e-9,
          "max_iter" => 1000
        })

      assert_maps_close(yog_result, nx_result, delta: 1.0e-6)
    end
  end

  # ---------------------------------------------------------------------------
  # Katz centrality
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-CENT-010 Katz centrality agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(3, 15),
            edges <- simple_edges_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:directed, nodes, edges),
            max_runs: 50
          ) do
      # Use a safe alpha (0.01) to guarantee convergence (alpha < 1/max_degree)
      alpha = 0.01
      beta = 1.0

      yog_result =
        Yog.Centrality.katz(graph,
          alpha: alpha,
          beta: beta,
          tolerance: 1.0e-9,
          max_iterations: 1000
        )

      nx_result =
        NetworkX.run("katz_centrality", graph, %{
          "alpha" => alpha,
          "beta" => beta,
          "tol" => 1.0e-9,
          "max_iter" => 1000,
          "normalized" => false
        })

      assert_maps_close(yog_result, nx_result, delta: 1.0e-6)
    end
  end

  # ---------------------------------------------------------------------------
  # Helper Generators
  # ---------------------------------------------------------------------------

  # Generates connected, non-bipartite undirected graphs to guarantee convergence for Eigenvector centrality.
  # Starts with a triangle (nodes 0, 1, 2) to ensure aperiodicity, then attaches remaining nodes sequentially to ensure connectivity.
  defp connected_non_bipartite_graph_gen(node_range) do
    gen all(
          nodes <- Yog.Generators.node_list_gen(elem(node_range, 0), elem(node_range, 1)),
          # Random extra edges
          extra_edges <-
            StreamData.list_of(
              {StreamData.integer(0..(length(nodes) - 1)),
               StreamData.integer(0..(length(nodes) - 1)), StreamData.constant(1)},
              max_length: 20
            )
        ) do
      n = length(nodes)

      # Build the initial triangle backbone
      backbone_edges =
        cond do
          n > 3 ->
            [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}] ++
              Enum.map(3..(n - 1), fn i -> {i, Enum.random(0..(i - 1)), 1} end)

          n == 3 ->
            [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}]

          true ->
            # Fallback (though node_range should guarantee n >= 3)
            Enum.chunk_every(Enum.to_list(0..(n - 1)), 2, 1, :discard)
            |> Enum.map(fn [u, v] -> {u, v, 1} end)
        end

      all_edges = backbone_edges ++ extra_edges
      # Reject self-loops for cleaner comparison
      clean_edges = Enum.reject(all_edges, fn {u, v, _} -> u == v end)

      Yog.Generators.build_graph(:undirected, nodes, clean_edges)
    end
  end

  # ---------------------------------------------------------------------------
  # Remaining centrality measures
  #
  # HITS — 🔴 documented algorithmic divergence (see above); not
  # oracle-tested. Yog uses iterative power method (L2-normalized),
  # NetworkX uses scipy SVD on the adjacency matrix (L1-normalized).
  # The two methods give different absolute values on near-degenerate
  # inputs by construction. Yog's HITS is unit-tested separately.
  # ---------------------------------------------------------------------------
end
