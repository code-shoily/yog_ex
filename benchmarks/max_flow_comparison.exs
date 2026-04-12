#!/usr/bin/env elixir

defmodule MaxFlowBenchmark do
  @moduledoc """
  Benchmark comparing Dinic's algorithm vs Edmonds-Karp for maximum flow.

  Dinic's algorithm builds a level graph via BFS and pushes blocking flows via DFS.
  It runs in O(V²E) in general and O(E·√V) for unit capacities, making it
  significantly faster than Edmonds-Karp (O(VE²)) on dense networks.
  """

  alias Yog.Flow.MaxFlow

  @iterations 50

  def run do
    IO.puts("Maximum Flow Benchmark: Dinic vs Edmonds-Karp")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Each test runs #{@iterations} iterations and reports total / average time.\n")

    # Grid networks
    run_suite("Grid Networks", [
      {"10×10 grid", build_grid_graph(10), 0, 10 * 10 - 1},
      {"20×20 grid", build_grid_graph(20), 0, 20 * 20 - 1},
      {"30×30 grid", build_grid_graph(30), 0, 30 * 30 - 1}
    ])

    # Dense networks
    run_suite("Dense Networks", [
      {"30 nodes, ~210 edges", build_dense_graph(30), 0, 29},
      {"60 nodes, ~900 edges", build_dense_graph(60), 0, 59},
      {"100 nodes, ~2500 edges", build_dense_graph(100), 0, 99}
    ])

    # Unit capacity bipartite networks
    run_suite("Unit Capacity Bipartite", [
      {"K_10,10 + source/sink", build_bipartite_flow_graph(10), :source, :sink},
      {"K_20,20 + source/sink", build_bipartite_flow_graph(20), :source, :sink},
      {"K_30,30 + source/sink", build_bipartite_flow_graph(30), :source, :sink}
    ])

    # Correctness check
    IO.puts("\n== Correctness Check ==")

    for {name, graph, s, t} <- [
          {"20×20 grid", build_grid_graph(20), 0, 399},
          {"100-node dense", build_dense_graph(100), 0, 99},
          {"K_20,20 unit", build_bipartite_flow_graph(20), :source, :sink}
        ] do
      ek_res = MaxFlow.edmonds_karp(graph, s, t)
      dinic_res = MaxFlow.dinic(graph, s, t)
      match = if ek_res.max_flow == dinic_res.max_flow, do: "✓", else: "✗"
      IO.puts("  #{match} #{name}: EK=#{ek_res.max_flow}, Dinic=#{dinic_res.max_flow}")
    end

    # Memory summary
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 on residual graph in words)")

    for n <- [20, 50] do
      graph = build_grid_graph(n)
      s = 0
      t = n * n - 1

      ek_res = MaxFlow.edmonds_karp(graph, s, t).residual_graph
      dinic_res = MaxFlow.dinic(graph, s, t).residual_graph

      ek_size = :erts_debug.size(ek_res)
      dinic_size = :erts_debug.size(dinic_res)

      IO.puts("\n#{n}×#{n} grid:")
      IO.puts("  Edmonds-Karp: #{ek_size} words (~#{format_bytes(ek_size * 8)})")
      IO.puts("  Dinic:        #{dinic_size} words (~#{format_bytes(dinic_size * 8)})")
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Summary:")
    IO.puts("- Edmonds-Karp: O(VE²), shortest augmenting path via BFS")
    IO.puts("- Dinic:        O(V²E), blocking flow via level graph + DFS")
    IO.puts("- Dinic dominates on larger / denser networks and unit capacities")
  end

  defp run_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, graph, s, t} <- cases do
      {ek_total, ek_flow} = bench_iterations(fn -> MaxFlow.edmonds_karp(graph, s, t) end)
      {dinic_total, dinic_flow} = bench_iterations(fn -> MaxFlow.dinic(graph, s, t) end)

      ek_avg = Float.round(ek_total / @iterations, 3)
      dinic_avg = Float.round(dinic_total / @iterations, 3)
      ratio = if ek_avg > 0, do: Float.round(ek_avg / dinic_avg, 2), else: 1.0

      winner =
        if dinic_avg < ek_avg,
          do: "Dinic #{ratio}x faster",
          else: "EK #{Float.round(dinic_avg / ek_avg, 2)}x faster"

      IO.puts("  #{name}")
      IO.puts("    Edmonds-Karp: #{ek_total}ms total, #{ek_avg}ms avg (flow=#{ek_flow})")
      IO.puts("    Dinic:        #{dinic_total}ms total, #{dinic_avg}ms avg (flow=#{dinic_flow})")
      IO.puts("    → #{winner}")
    end
  end

  defp bench_iterations(fun) do
    # Warmup
    _ = fun.()
    :erlang.garbage_collect()

    {total_us, result} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    {Float.round(total_us / 1000, 2), result.max_flow}
  end

  # Build an n×n directed grid with random capacities 1..20
  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.directed(), fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = i * n + j
        acc = Yog.add_node(acc, node_id, nil)

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

  # Build a dense directed graph with n nodes and ~n*(n/4) edges
  defp build_dense_graph(n) do
    nodes = 0..(n - 1)

    g =
      Enum.reduce(nodes, Yog.directed(), fn i, acc ->
        Yog.add_node(acc, i, nil)
      end)

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

  # Build a complete bipartite flow network K_{n,n} with unit capacities
  defp build_bipartite_flow_graph(n) do
    left = 1..n
    right = (n + 1)..(2 * n)

    g =
      Yog.directed()
      |> Yog.add_node(:source, nil)
      |> Yog.add_node(:sink, nil)

    g =
      Enum.reduce(left, g, fn i, acc ->
        Yog.add_node(acc, i, nil)
        |> Yog.add_edge_ensure(:source, i, 1)
      end)

    g =
      Enum.reduce(right, g, fn i, acc ->
        Yog.add_node(acc, i, nil)
        |> Yog.add_edge_ensure(i, :sink, 1)
      end)

    Enum.reduce(left, g, fn i, acc ->
      Enum.reduce(right, acc, fn j, inner_acc ->
        Yog.add_edge_ensure(inner_acc, i, j, 1)
      end)
    end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

MaxFlowBenchmark.run()
