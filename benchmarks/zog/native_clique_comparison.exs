#!/usr/bin/env elixir

defmodule NativeCliqueBenchmark do
  @moduledoc """
  Benchmark comparing Pure Elixir MapSet Bron-Kerbosch and
  Zog Native Bitset Bron-Kerbosch solvers.
  """

  alias Yog.Property.Clique
  alias Yog.Zog.Property

  @iterations 20

  def run do
    IO.puts("=== Bron-Kerbosch (Maximal Cliques) Performance Comparison ===")
    IO.puts("Pure Elixir vs Zog Native Bitset")
    IO.puts("==============================================================")
    IO.puts("Each test runs #{@iterations} iterations and reports average time.\n")

    run_suite("Complete Graph K12 (12 nodes, fully connected)", build_complete_graph(12))
    run_suite("Dense Random Graph (40 nodes, density 0.5)", build_dense_graph(40, 0.5))
    run_suite("Dense Random Graph (60 nodes, density 0.5)", build_dense_graph(60, 0.5))
    run_suite("Moon-Moser Graph (15 nodes, worst-case clique count)", build_moon_moser_graph(5))
  end

  defp run_suite(name, elixir_graph) do
    IO.puts("Suite: #{name}")

    # Pre-convert Zog builder
    zog_builder = Yog.Builder.Zog.from_graph(elixir_graph)

    # 1. Pure Elixir MapSet Bron-Kerbosch
    {elixir_avg, elixir_cliques} =
      bench_iterations(fn -> Clique.all_maximal_cliques(elixir_graph) end)

    # 2. Zog Native Bitset Bron-Kerbosch
    {zog_avg, zog_cliques} = bench_iterations(fn -> Property.all_maximal_cliques(zog_builder) end)

    # Print results
    cliques_count = length(elixir_cliques)
    IO.puts("  Results (total maximal cliques found = #{cliques_count}):")
    IO.puts("    - Pure Elixir MapSet:          #{elixir_avg} ms")

    IO.puts(
      "    - Zog Native Bitset:           #{zog_avg} ms  (#{ratio_str(elixir_avg, zog_avg)})"
    )

    IO.puts("")

    # Sanity checks
    if length(elixir_cliques) != length(zog_cliques) do
      IO.puts(
        "    [WARNING] Maximal cliques count mismatch! Elixir=#{length(elixir_cliques)}, Zog=#{length(zog_cliques)}"
      )
    end
  end

  defp ratio_str(base, current) do
    if current > 0 do
      speedup = Float.round(base / current, 1)
      "#{speedup}x speedup over Pure Elixir"
    else
      "N/A"
    end
  end

  defp bench_iterations(fun) do
    # Warmup
    res = fun.()
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    avg_ms = Float.round(total_us / 1000 / @iterations, 3)
    {avg_ms, res}
  end

  # Generates a complete graph of size n
  defp build_complete_graph(n) do
    g = Yog.undirected()

    Enum.reduce(0..(n - 1), g, fn u, acc_g ->
      Enum.reduce(0..(n - 1), acc_g, fn v, acc_inner ->
        if u < v do
          Yog.add_edge_ensure(acc_inner, "node_#{u}", "node_#{v}", 1.0)
        else
          acc_inner
        end
      end)
    end)
  end

  # Generates a dense random graph with density p
  defp build_dense_graph(n, p) do
    g = Yog.undirected()

    Enum.reduce(0..(n - 1), g, fn u, acc_g ->
      Enum.reduce(0..(n - 1), acc_g, fn v, acc_inner ->
        if u < v and :rand.uniform() < p do
          Yog.add_edge_ensure(acc_inner, "node_#{u}", "node_#{v}", 1.0)
        else
          acc_inner
        end
      end)
    end)
  end

  # Generates a Moon-Moser graph with k parts of size 3 (V = 3*k)
  # A Moon-Moser graph is a complete k-partite graph K_{3,3,...,3}.
  defp build_moon_moser_graph(k) do
    g = Yog.undirected()
    n = 3 * k

    Enum.reduce(0..(n - 1), g, fn u, acc_g ->
      Enum.reduce(0..(n - 1), acc_g, fn v, acc_inner ->
        part_u = div(u, 3)
        part_v = div(v, 3)

        if u < v and part_u != part_v do
          Yog.add_edge_ensure(acc_inner, "node_#{u}", "node_#{v}", 1.0)
        else
          acc_inner
        end
      end)
    end)
  end
end

NativeCliqueBenchmark.run()
