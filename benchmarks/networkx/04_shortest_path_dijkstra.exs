#!/usr/bin/env elixir
# Benchmark: Shortest Path (Dijkstra)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate directed graph
n = 500
m = 1000
medium = Random.erdos_renyi_gnp_with_type(n, m / (n * (n - 1)), :directed, 1)

Shared.register_graph(port, :medium, medium)

source = 0
target = 249

IO.puts("\n== Shortest Path (Dijkstra) ==\n")
IO.puts("Graph: #{n} nodes, #{m} edges")
IO.puts("Source: #{source}, Target: #{target}\n")

Benchee.run(
  %{
    "Yog (Dijkstra)" => fn ->
      Yog.Pathfinding.Dijkstra.shortest_path(in: medium, from: source, to: target)
    end,
    "NetworkX (Dijkstra)" =>
      Shared.benchmark_nx(port, :medium, "dijkstra", %{source: source, target: target})
  },
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
