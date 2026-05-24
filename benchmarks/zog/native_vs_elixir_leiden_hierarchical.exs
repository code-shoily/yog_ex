#!/usr/bin/env elixir

defmodule NativeVsElixirLeidenHierarchicalBenchmark do
  @moduledoc """
  Benchmark comparing pure Elixir Hierarchical Leiden vs native Zog (Zig) Hierarchical Leiden.
  """

  alias Yog.Builder.Zog, as: ZogBuilder

  @iterations 3

  def run do
    IO.puts("Hierarchical Leiden Community Detection Benchmark")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("Comparing pure Elixir hierarchical Leiden vs native Zog (Zig) Leiden.")
    IO.puts("Each test runs #{@iterations} iterations.\n")

    for {name, n, m} <- [
          {"Sparse 100n, 300e", 100, 300},
          {"Sparse 300n, 900e", 300, 900},
          {"Sparse 500n, 1500e", 500, 1500},
          {"Sparse 1000n, 3000e", 1000, 3000}
        ] do
      builder = build_zog_sparse_graph(n, m)

      elixir_ms =
        bench(fn ->
          g = ZogBuilder.to_graph(builder)
          Yog.Community.Leiden.detect_hierarchical(g)
        end)

      copyin_ms =
        bench(fn ->
          Yog.Zog.Community.leiden_hierarchical(builder)
        end)

      resource_ms =
        bench_resource_amortized(
          fn -> Yog.Zog.ResourceGraph.new(builder) end,
          fn graph -> Yog.Zog.ResourceGraph.leiden_hierarchical(graph) end
        )

      IO.puts("  #{name}")
      IO.puts("    Pure Elixir:    #{elixir_ms}ms")
      IO.puts("    Zog Copy-In:    #{copyin_ms}ms")
      IO.puts("    ResourceGraph:  #{resource_ms}ms")

      if resource_ms > 0 do
        speedup = Float.round(elixir_ms / resource_ms, 1)
        IO.puts("    → ResourceGraph is #{speedup}x faster than pure Elixir")
      end

      IO.puts("")
    end
  end

  defp bench_resource_amortized(build_fun, algo_fun) do
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

  defp bench(fun) do
    # Warmup
    _ = fun.()
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    Float.round(total_us / 1000 / @iterations, 3)
  end

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
end

NativeVsElixirLeidenHierarchicalBenchmark.run()
