#!/usr/bin/env elixir
# Benchmark: Maximum Flow (Edmonds-Karp and Dinic)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared

# Initialize Port
port = Shared.start_port()

# Helper to build n x n grid graph
build_grid_graph = fn n ->
  Enum.reduce(0..(n - 1), Yog.directed(), fn i, g ->
    Enum.reduce(0..(n - 1), g, fn j, acc ->
      node_id = i * n + j
      acc = Yog.add_node(acc, node_id, nil)

      acc =
        if j < n - 1 do
          right_id = i * n + (j + 1)
          Yog.add_edge_ensure(acc, node_id, right_id, :rand.uniform(20) * 1.0)
        else
          acc
        end

      acc =
        if i < n - 1 do
          down_id = (i + 1) * n + j
          Yog.add_edge_ensure(acc, node_id, down_id, :rand.uniform(20) * 1.0)
        else
          acc
        end

      acc
    end)
  end)
end

# 10x10 grid
grid = build_grid_graph.(10)
Shared.register_graph(port, :grid, grid)

source = 0
target = 99

IO.puts("\n== Maximum Flow Comparison ==\n")
IO.puts("Graph: 10x10 Grid (100 nodes, ~200 edges)")
IO.puts("Source: #{source}, Target: #{target}\n")

Benchee.run(
  %{
    "Yog (Edmonds-Karp)" => fn ->
      Yog.Flow.MaxFlow.edmonds_karp(grid, source, target)
    end,
    "Yog (Dinic)" => fn ->
      Yog.Flow.MaxFlow.dinic(grid, source, target)
    end,
    "NetworkX (Edmonds-Karp)" =>
      Shared.benchmark_nx(port, :grid, "edmonds_karp", %{source: source, target: target}),
    "NetworkX (Dinic)" =>
      Shared.benchmark_nx(port, :grid, "dinic", %{source: source, target: target})
  },
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
