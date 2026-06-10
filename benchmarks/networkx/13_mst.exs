#!/usr/bin/env elixir
# Benchmark: Spanning Tree (Kruskal and Prim MST)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared
alias Yog.Generator.Random

# Initialize Port
port = Shared.start_port()

# Generate undirected graphs
small = Random.erdos_renyi_gnp_with_type(100, 300 / (100 * 99), :undirected, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1500 / (500 * 499), :undirected, 42)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (100n, 300e)" => {:small, small},
  "Medium (500n, 1500e)" => {:medium, medium}
}

IO.puts("\n== Spanning Tree Comparison ==\n")

Benchee.run(
  %{
    "Yog (Kruskal)" => fn {_, yog} -> Yog.MST.kruskal(yog) end,
    "Yog (Prim)" => fn {_, yog} -> Yog.MST.prim(yog) end,
    "NetworkX (Kruskal)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "kruskal"})
    end,
    "NetworkX (Prim)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "prim"})
    end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
