#!/usr/bin/env elixir
# Benchmark: Shortest Path (Bellman-Ford)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate directed graph
n = 100
m = 300
medium = Random.erdos_renyi_gnp_with_type(n, m / (n * (n - 1)), :directed, 1)

Shared.register_graph(port, :medium, medium)

source = 0
target = 99

IO.puts("\n== Shortest Path (Bellman-Ford) ==\n")
IO.puts("Graph: #{n} nodes, #{m} edges")
IO.puts("Source: #{source}, Target: #{target}\n")

Benchee.run(
  %{
    "Yog (Bellman-Ford)" => fn ->
      Yog.Pathfinding.BellmanFord.bellman_ford(in: medium, from: source, to: target)
    end,
    "NetworkX (Bellman-Ford)" =>
      Shared.benchmark_nx(port, :medium, "bellman_ford", %{source: source, target: target})
  },
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
