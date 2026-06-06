#!/usr/bin/env elixir

defmodule NativeVsElixirBenchmark do
  @moduledoc """
  Benchmark comparing pure Elixir Yog algorithms vs native Zig (Zog) NIFs.

  Three patterns are compared where applicable:
  1. **Pure Elixir** — no native code
  2. **Copy-In/Copy-Out** — rebuilds graph from flat arrays on every call
  3. **Resource Graph** — graph built once, algorithms run on native memory

  The Resource Graph pattern eliminates per-call reconstruction overhead and
  shows the true speedup of native code.
  """

  alias Yog.Builder.Zog, as: ZogBuilder

  @iterations 5

  def run do
    IO.puts("Native Zig (Zog) vs Pure Elixir Benchmark")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("Each test runs #{@iterations} iterations.\n")

    run_centrality_suite()
    run_community_suite()
    run_pathfinding_suite()
    run_coloring_suite()

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("Summary:")
    IO.puts("- Copy-In/Copy-Out:  Rebuilds graph on every call. Often SLOWER than pure Elixir")
    IO.puts("                     for small/medium graphs due to serialization overhead.")
    IO.puts("- Resource Graph:     When built once and reused, shows significant speedups.")
    IO.puts("                      The 'ResourceGraph' column measures ONLY the algorithm")
    IO.puts("                      time (graph build cost is amortized).")
  end

  # ===========================================================================
  # Centrality
  # ===========================================================================

  defp run_centrality_suite do
    IO.puts("== Centrality: Betweenness ==")

    for {name, n, m} <- [
          {"Sparse 100n, 300e", 100, 300},
          {"Sparse 300n, 900e", 300, 900},
          {"Sparse 500n, 1500e", 500, 1500}
        ] do
      builder = build_zog_sparse_graph(n, m)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Centrality.betweenness(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Centrality.betweenness_unweighted(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.betweenness_unweighted(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Copy-In/Out:   #{copyin_ms}ms")
      IO.puts("    ResourceGraph: #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end

    IO.puts("== Centrality: PageRank ==")

    for {name, n, m} <- [
          {"Sparse 500n, 1500e", 500, 1500},
          {"Sparse 2000n, 6000e", 2000, 6000},
          {"Sparse 5000n, 15000e", 5000, 15000}
        ] do
      builder = build_zog_sparse_graph(n, m)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Centrality.pagerank(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Centrality.pagerank(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.pagerank(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Copy-In/Out:   #{copyin_ms}ms")
      IO.puts("    ResourceGraph: #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end

    IO.puts("== Centrality: Closeness ==")

    for {name, n, m} <- [
          {"Sparse 100n, 300e", 100, 300},
          {"Sparse 300n, 900e", 300, 900},
          {"Sparse 500n, 1500e", 500, 1500}
        ] do
      builder = build_zog_sparse_graph(n, m)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Centrality.closeness(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Centrality.closeness_f64(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.closeness_f64(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Copy-In/Out:   #{copyin_ms}ms")
      IO.puts("    ResourceGraph: #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end
  end

  # ===========================================================================
  # Community Detection
  # ===========================================================================

  defp run_community_suite do
    IO.puts("== Community: Louvain ==")

    for {name, n, m} <- [
          {"Sparse 500n, 1500e", 500, 1500},
          {"Sparse 1000n, 3000e", 1000, 3000},
          {"Sparse 2000n, 6000e", 2000, 6000},
          {"Sparse 5000n, 15000e", 5000, 15000},
          {"Sparse 10000n, 30000e", 10000, 30000}
        ] do
      builder = build_zog_sparse_graph(n, m)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Community.Louvain.detect(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Community.louvain(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.louvain(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Copy-In/Out:   #{copyin_ms}ms")
      IO.puts("    ResourceGraph: #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end
  end

  # ===========================================================================
  # Pathfinding (APSP)
  # ===========================================================================

  defp run_pathfinding_suite do
    IO.puts("== Pathfinding: Floyd-Warshall ==")

    for {name, n} <- [
          {"Dense 50n", 50},
          {"Dense 100n", 100},
          {"Dense 200n", 200}
        ] do
      builder = build_zog_dense_graph(n)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Pathfinding.FloydWarshall.floyd_warshall(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Pathfinding.floyd_warshall(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.floyd_warshall(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Copy-In/Out:   #{copyin_ms}ms")
      IO.puts("    ResourceGraph: #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end

    IO.puts("== Pathfinding: Johnson's ==")

    for {name, n, m} <- [
          {"Sparse 100n, 300e", 100, 300},
          {"Sparse 500n, 1500e", 500, 1500},
          {"Sparse 1000n, 3000e", 1000, 3000}
        ] do
      builder = build_zog_sparse_graph(n, m)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Pathfinding.Johnson.johnson(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Pathfinding.johnsons(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.johnsons(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Copy-In/Out:   #{copyin_ms}ms")
      IO.puts("    ResourceGraph: #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end
  end

  # ===========================================================================
  # Benchmark helper
  # ===========================================================================

  defp bench(fun) do
    _ = fun.()
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    Float.round(total_us / 1000 / @iterations, 3)
  end

  defp bench_resource_amortized(build_fun, algo_fun) do
    # The REAL benefit: build once, run many algorithms
    graph = build_fun.()
    _ = algo_fun.(graph)
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ ->
          algo_fun.(graph)
        end)
      end)

    Yog.Zog.ResourceGraph.destroy(graph)

    Float.round(total_us / 1000 / @iterations, 3)
  end

  # ===========================================================================
  # Graph generators (ZogBuilder)
  # ===========================================================================

  defp build_zog_sparse_graph(n, m) do
    nodes = 0..(n - 1)
    g = Enum.reduce(nodes, ZogBuilder.undirected(), &ZogBuilder.add_node(&2, &1))

    # Random tree for connectivity
    g =
      Enum.reduce(1..(n - 1), g, fn i, acc ->
        parent = :rand.uniform(i) - 1
        ZogBuilder.add_edge(acc, parent, i, 1.0)
      end)

    # Rest are random edges
    remaining = max(m - (n - 1), 0)

    Enum.reduce(1..remaining, g, fn _, acc ->
      u = :rand.uniform(n) - 1
      v = :rand.uniform(n) - 1

      if u != v do
        ZogBuilder.add_edge(acc, u, v, 1.0)
      else
        acc
      end
    end)
  end

  defp build_zog_dense_graph(n) do
    nodes = 0..(n - 1)
    g = Enum.reduce(nodes, ZogBuilder.undirected(), &ZogBuilder.add_node(&2, &1))

    edges =
      for i <- 0..(n - 1),
          j <- (i + 1)..(n - 1),
          :rand.uniform(2) == 1,
          do: {i, j, 1.0}

    Enum.reduce(edges, g, fn {u, v, w}, acc ->
      ZogBuilder.add_edge(acc, u, v, w)
    end)
  end

  defp run_coloring_suite do
    IO.puts("== Coloring: Exact Coloring ==")

    for {name, n, p} <- [
          {"Random Graph 35n", 35, 0.5},
          {"Random Graph 40n", 40, 0.5},
          {"Random Graph 45n", 45, 0.5}
        ] do
      builder =
        Yog.Generator.Random.erdos_renyi_gnp_with_type(n, p, :undirected, 42)
        |> Yog.Builder.Zog.from_graph()

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Property.Coloring.coloring_exact(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Property.coloring_exact(builder)
        end)

      IO.puts("  #{name}")
      IO.puts("    Elixir:        #{elixir_ms}ms")
      IO.puts("    Zig Native:    #{copyin_ms}ms")

      if copyin_ms > 0 do
        speedup = Float.round(elixir_ms / copyin_ms, 1)
        IO.puts("    → Zig Native #{speedup}x faster than Elixir")
      end

      IO.puts("")
    end
  end
end

NativeVsElixirBenchmark.run()
