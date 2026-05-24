#!/usr/bin/env elixir

defmodule NativeMaxFlowBenchmark do
  @moduledoc """
  Benchmark comparing Pure Elixir Edmonds-Karp vs Native Zog Edmonds-Karp
  (both Copy-In/Out and persistent ResourceGraph modes).
  """

  alias Yog.Flow.MaxFlow
  alias Yog.Zog.Flow
  alias Yog.Zog.ResourceGraph

  @iterations 30

  def run do
    IO.puts("=== Maximum Flow Performance Comparison ===")
    IO.puts("Elixir (Edmonds-Karp) vs Zog Copy-In/Out vs Zog ResourceGraph")
    IO.puts("==========================================================")
    IO.puts("Each test runs #{@iterations} iterations and reports average time.\n")

    # Suites
    run_suite("Grid Network (10x10)", build_grid_graph(10), 0, 99)
    run_suite("Grid Network (15x15)", build_grid_graph(15), 0, 224)
    run_suite("Dense Network (50 nodes, ~600 edges)", build_dense_graph(50), 0, 49)
    run_suite("Dense Network (80 nodes, ~1500 edges)", build_dense_graph(80), 0, 79)
  end

  defp run_suite(name, elixir_graph, s, t) do
    IO.puts("Suite: #{name}")

    # Pre-convert Zog structures
    zog_builder = Yog.Builder.Zog.from_graph(elixir_graph)
    zog_resource = ResourceGraph.new(zog_builder)

    # 1. Pure Elixir
    {elixir_avg, elixir_flow} =
      bench_iterations(fn -> MaxFlow.edmonds_karp(elixir_graph, s, t) end)

    # 2. Zog Copy-In/Out
    {copy_avg, copy_flow} = bench_iterations(fn -> Flow.max_flow(zog_builder, s, t) end)

    # 3. Zog ResourceGraph
    {res_avg, res_flow} = bench_iterations(fn -> ResourceGraph.max_flow(zog_resource, s, t) end)

    # 4. Raw Zog NIF (no Elixir mapping overhead)
    s_idx = Yog.Builder.Zog.label_to_id(zog_builder, s)
    t_idx = Yog.Builder.Zog.label_to_id(zog_builder, t)

    {raw_avg, _raw_flow} =
      bench_iterations(fn -> ResourceGraph.nif_max_flow(zog_resource.resource, s_idx, t_idx) end)

    # Clean up resource
    ResourceGraph.destroy(zog_resource)

    # Print results
    IO.puts("  Results (max flow value = #{elixir_flow}):")
    IO.puts("    - Pure Elixir:      #{elixir_avg} ms")
    IO.puts("    - Zog Copy-In/Out:   #{copy_avg} ms")
    IO.puts("    - Zog ResourceGraph: #{res_avg} ms")
    IO.puts("    - Raw Zog NIF:      #{raw_avg} ms  (#{ratio_str(elixir_avg, raw_avg)})")
    IO.puts("")

    # Sanity checks
    if elixir_flow != copy_flow or elixir_flow != res_flow do
      IO.puts(
        "    [WARNING] Max flow mismatch! Elixir=#{elixir_flow}, Copy=#{copy_flow}, Resource=#{res_flow}"
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

  defp bench_iterations(fun) do
    # Warmup
    res = fun.()
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    avg_ms = Float.round(total_us / 1000 / @iterations, 3)
    {avg_ms, res.max_flow}
  end

  # Generators adapted from existing benchmark suite
  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.directed(), fn i, g ->
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

  defp build_dense_graph(n) do
    nodes = 0..(n - 1)
    g = Yog.directed()

    edges =
      for i <- nodes,
          j <- nodes,
          i != j,
          :rand.uniform(4) == 1,
          do: {i, j, :rand.uniform(50)}

    Enum.reduce(edges, g, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end
end

NativeMaxFlowBenchmark.run()
