#!/usr/bin/env elixir

defmodule NativeMinCutBenchmark do
  @moduledoc """
  Benchmark comparing Pure Elixir Stoer-Wagner vs Native Zog Stoer-Wagner
  (both Copy-In/Out and persistent ResourceGraph modes).
  """

  alias Yog.Flow.MinCut
  alias Yog.Zog.Flow
  alias Yog.Zog.ResourceGraph

  @iterations 30

  def run do
    IO.puts("=== Global Minimum Cut Performance Comparison ===")
    IO.puts("Elixir (Stoer-Wagner) vs Zog Copy-In/Out vs Zog ResourceGraph")
    IO.puts("==========================================================")
    IO.puts("Each test runs #{@iterations} iterations and reports average time.\n")

    # Suites
    run_suite("Grid Network (6x6)", build_grid_graph(6))
    run_suite("Grid Network (8x8)", build_grid_graph(8))
    run_suite("Barbell Graph (2 cliques of 15 connected by 1 edge)", build_barbell_graph(15))
    run_suite("Barbell Graph (2 cliques of 25 connected by 1 edge)", build_barbell_graph(25))
  end

  defp run_suite(name, elixir_graph) do
    IO.puts("Suite: #{name}")

    # Pre-convert Zog structures
    zog_builder = Yog.Builder.Zog.from_graph(elixir_graph)
    zog_resource = ResourceGraph.new(zog_builder)

    # 1. Pure Elixir
    {elixir_avg, elixir_cut} =
      bench_iterations(fn -> MinCut.global_min_cut(elixir_graph) end, :cut_value)

    # 2. Zog Copy-In/Out
    {copy_avg, copy_cut} =
      bench_iterations(fn -> Flow.global_min_cut(zog_builder) end, :cut_value)

    # 3. Zog ResourceGraph
    {res_avg, res_cut} =
      bench_iterations(fn -> ResourceGraph.global_min_cut(zog_resource) end, :cut_value)

    # 4. Raw Zog NIF (no Elixir mapping overhead)
    {raw_avg, _raw_cut} =
      bench_iterations(
        fn -> ResourceGraph.nif_global_min_cut(zog_resource.resource) end,
        :cut_value
      )

    # Clean up resource
    ResourceGraph.destroy(zog_resource)

    # Print results
    IO.puts("  Results (min cut value = #{elixir_cut}):")
    IO.puts("    - Pure Elixir:      #{elixir_avg} ms")
    IO.puts("    - Zog Copy-In/Out:   #{copy_avg} ms")
    IO.puts("    - Zog ResourceGraph: #{res_avg} ms")
    IO.puts("    - Raw Zog NIF:      #{raw_avg} ms  (#{ratio_str(elixir_avg, raw_avg)})")
    IO.puts("")

    # Sanity checks
    if elixir_cut != copy_cut or elixir_cut != res_cut do
      IO.puts(
        "    [WARNING] Min cut mismatch! Elixir=#{elixir_cut}, Copy=#{copy_cut}, Resource=#{res_cut}"
      )
    end
  end

  defp ratio_str(base, current) do
    if current > 0 do
      speedup = Float.round(base / current, 1)
      "#{speedup}x speedup"
    else
      "N/A"
    end
  end

  defp bench_iterations(fun, key) do
    # Warmup
    res = fun.()
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    avg_ms = Float.round(total_us / 1000 / @iterations, 3)

    val =
      case res do
        %{^key => v} -> v
        # Raw NIF returns atom map or struct
        _ -> Map.get(res, key) || res.cut_value
      end

    {avg_ms, val}
  end

  # Generates undirected grid graph
  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.undirected(), fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = i * n + j

        acc =
          if j < n - 1 do
            right_id = i * n + (j + 1)
            Yog.add_edge_ensure(acc, node_id, right_id, :rand.uniform(20))
          else
            acc
          end

        acc =
          if i < n - 1 do
            down_id = (i + 1) * n + j
            Yog.add_edge_ensure(acc, node_id, down_id, :rand.uniform(20))
          else
            acc
          end

        acc
      end)
    end)
  end

  # Generates barbell graph of two cliques of size `c_size` connected by a single bridge
  defp build_barbell_graph(c_size) do
    g = Yog.undirected()

    # Clique 1
    g =
      Enum.reduce(1..c_size, g, fn u, acc_g ->
        if u < c_size do
          Enum.reduce((u + 1)..c_size, acc_g, fn v, acc_inner ->
            Yog.add_edge_ensure(acc_inner, "a#{u}", "a#{v}", 10)
          end)
        else
          acc_g
        end
      end)

    # Clique 2
    g =
      Enum.reduce(1..c_size, g, fn u, acc_g ->
        if u < c_size do
          Enum.reduce((u + 1)..c_size, acc_g, fn v, acc_inner ->
            Yog.add_edge_ensure(acc_inner, "b#{u}", "b#{v}", 10)
          end)
        else
          acc_g
        end
      end)

    # Bridge connecting them
    Yog.add_edge_ensure(g, "a#{c_size}", "b1", 1)
  end
end

NativeMinCutBenchmark.run()
