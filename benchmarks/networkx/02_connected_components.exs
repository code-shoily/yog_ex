#!/usr/bin/env elixir
# Benchmark: Connected Components (Undirected)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate undirected graphs
small = Random.erdos_renyi_gnp_with_type(100, 150 / (100 * 99), :undirected, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :undirected, 42)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (100n, 150e)" => {:small, small},
  "Medium (500n, 1000e)" => {:medium, medium}
}

IO.puts("\n== Connected Components Comparison ==\n")

Benchee.run(
  %{
    "Yog (Components)" => fn {_, yog} ->
      Yog.Connectivity.Components.connected_components(yog)
    end,
    "NetworkX (Connected Components)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "connected_components"})
    end
  },
  inputs: inputs,
  time: 2,
  warmup: 1
)

Shared.stop_port(port)
