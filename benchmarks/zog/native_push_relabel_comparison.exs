#!/usr/bin/env elixir

defmodule NativePushRelabelBenchmark do
  @moduledoc """
  Benchmark comparing Pure Elixir Edmonds-Karp, Zog Edmonds-Karp,
  and Zog Push-Relabel solvers.
  """

  alias Yog.Flow.MaxFlow
  alias Yog.Zog.Flow
  alias Yog.Zog.ResourceGraph

  @iterations 15

  def run do
    IO.puts("=== Maximum Flow Performance Comparison ===")
    IO.puts("Edmonds-Karp vs Push-Relabel")
    IO.puts("===========================================")
    IO.puts("Each test runs #{@iterations} iterations and reports average time.\n")

    run_suite("Grid Network (6x6)", build_grid_graph(6), "node_0", "node_35")
    run_suite("Grid Network (10x10)", build_grid_graph(10), "node_0", "node_99")

    run_suite(
      "Dense Random Graph (50 nodes, density 0.4)",
      build_dense_graph(50, 0.4),
      "node_0",
      "node_49"
    )
  end

  defp run_suite(name, elixir_graph, source, sink) do
    IO.puts("Suite: #{name}")

    # Pre-convert Zog structures
    zog_builder = Yog.Builder.Zog.from_graph(elixir_graph)
    zog_resource = ResourceGraph.new(zog_builder)

    # 1. Pure Elixir Edmonds-Karp
    {elixir_ek_avg, elixir_ek_flow} =
      bench_iterations(fn -> MaxFlow.edmonds_karp(elixir_graph, source, sink) end, :max_flow)

    # 2. Zog Edmonds-Karp (Copy-In/Out)
    {zog_ek_avg, zog_ek_flow} =
      bench_iterations(
        fn -> Flow.max_flow(zog_builder, source, sink, :edmonds_karp) end,
        :max_flow
      )

    # 3. Zog Push-Relabel (Copy-In/Out)
    {zog_pr_avg, zog_pr_flow} =
      bench_iterations(
        fn -> Flow.max_flow(zog_builder, source, sink, :push_relabel) end,
        :max_flow
      )

    # 4. Zog Edmonds-Karp (ResourceGraph)
    {res_ek_avg, res_ek_flow} =
      bench_iterations(
        fn -> ResourceGraph.max_flow(zog_resource, source, sink, :edmonds_karp) end,
        :max_flow
      )

    # 5. Zog Push-Relabel (ResourceGraph)
    {res_pr_avg, res_pr_flow} =
      bench_iterations(
        fn -> ResourceGraph.max_flow(zog_resource, source, sink, :push_relabel) end,
        :max_flow
      )

    # Clean up resource
    ResourceGraph.destroy(zog_resource)

    # Print results
    IO.puts("  Results (max flow value = #{elixir_ek_flow}):")
    IO.puts("    - Pure Elixir Edmonds-Karp:    #{elixir_ek_avg} ms")
    IO.puts("    - Zog EK Copy-In/Out:          #{zog_ek_avg} ms")
    IO.puts("    - Zog EK ResourceGraph:        #{res_ek_avg} ms")
    IO.puts("    - Zog Push-Relabel Copy-In/Out: #{zog_pr_avg} ms")

    IO.puts(
      "    - Zog Push-Relabel Resource:    #{res_pr_avg} ms  (#{ratio_str(elixir_ek_avg, res_pr_avg)})"
    )

    IO.puts("")

    # Sanity checks
    if elixir_ek_flow != zog_ek_flow or elixir_ek_flow != zog_pr_flow or
         elixir_ek_flow != res_ek_flow or elixir_ek_flow != res_pr_flow do
      IO.puts(
        "    [WARNING] Max flow mismatch! Elixir=#{elixir_ek_flow}, ZogEK=#{zog_ek_flow}, ZogPR=#{zog_pr_flow}"
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
        _ -> Map.get(res, key) || res.max_flow
      end

    {avg_ms, val}
  end

  # Generates directed grid graph with flows
  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.directed(), fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = "node_#{i * n + j}"

        acc =
          if j < n - 1 do
            right_id = "node_#{i * n + (j + 1)}"
            Yog.add_edge_ensure(acc, node_id, right_id, 10.0 + :rand.uniform(40))
          else
            acc
          end

        acc =
          if i < n - 1 do
            down_id = "node_#{(i + 1) * n + j}"
            Yog.add_edge_ensure(acc, node_id, down_id, 10.0 + :rand.uniform(40))
          else
            acc
          end

        acc
      end)
    end)
  end

  # Generates dense graph with density p and random capacities
  defp build_dense_graph(n, p) do
    g = Yog.directed()

    Enum.reduce(0..(n - 1), g, fn u, acc_g ->
      Enum.reduce(0..(n - 1), acc_g, fn v, acc_inner ->
        if u != v and :rand.uniform() < p do
          Yog.add_edge_ensure(acc_inner, "node_#{u}", "node_#{v}", 5.0 + :rand.uniform(25))
        else
          acc_inner
        end
      end)
    end)
  end
end

NativePushRelabelBenchmark.run()
