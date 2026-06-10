#!/usr/bin/env elixir
# Benchmark: Strongly Connected Components (Directed)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate directed graphs
small = Random.erdos_renyi_gnp_with_type(100, 150 / (100 * 99), :directed, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :directed, 42)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (100n, 150e)" => {:small, small},
  "Medium (500n, 1000e)" => {:medium, medium}
}

IO.puts("\n== Strongly Connected Components Comparison ==\n")

Benchee.run(
  %{
    "Yog (Kosaraju)" => fn {_, yog} ->
      Yog.Connectivity.SCC.strongly_connected_components(yog)
    end,
    "NetworkX (Strongly Connected Components)" => fn {id, _} ->
      Shared.call(port, "run", %{
        "graph_id" => id,
        "algorithm" => "strongly_connected_components"
      })
    end
  },
  inputs: inputs,
  time: 2,
  warmup: 1
)

Shared.stop_port(port)
