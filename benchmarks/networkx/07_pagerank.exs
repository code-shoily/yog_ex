#!/usr/bin/env elixir
# Benchmark: PageRank Centrality
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate directed graphs
small = Random.erdos_renyi_gnp_with_type(100, 300 / (100 * 99), :directed, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1500 / (500 * 499), :directed, 42)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (100n, 300e)" => {:small, small},
  "Medium (500n, 1500e)" => {:medium, medium}
}

IO.puts("\n== PageRank Centrality Comparison ==\n")

Benchee.run(
  %{
    "Yog (PageRank)" => fn {_, yog} -> Yog.Centrality.pagerank(yog) end,
    "NetworkX (PageRank)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "pagerank"})
    end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
