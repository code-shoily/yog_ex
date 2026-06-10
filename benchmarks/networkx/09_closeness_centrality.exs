#!/usr/bin/env elixir
# Benchmark: Closeness Centrality
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate undirected graphs
small = Random.erdos_renyi_gnp_with_type(50, 150 / (50 * 49), :undirected, 42)
medium = Random.erdos_renyi_gnp_with_type(150, 450 / (150 * 149), :undirected, 42)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (50n, 150e)" => {:small, small},
  "Medium (150n, 450e)" => {:medium, medium}
}

IO.puts("\n== Closeness Centrality Comparison ==\n")

Benchee.run(
  %{
    "Yog (Closeness)" => fn {_, yog} -> Yog.Centrality.closeness(yog) end,
    "NetworkX (Closeness)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "closeness_centrality"})
    end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
