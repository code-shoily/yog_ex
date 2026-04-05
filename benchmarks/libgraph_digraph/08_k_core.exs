#!/usr/bin/env elixir
# Benchmark: K-Core Decomposition
# Comparing Yog and libgraph

code = """
alias Yog.Generator.Random

# Generate undirected graphs
small = Random.erdos_renyi_gnp_with_type(100, 150 / (100 * 99), :undirected, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :undirected, 42)

# libgraph
lib_small = Graph.new(type: :undirected)
lib_small = Enum.reduce(0..99, lib_small, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(small)
lib_small = Enum.reduce(edges, lib_small, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

lib_medium = Graph.new(type: :undirected)
lib_medium = Enum.reduce(0..499, lib_medium, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(medium)
lib_medium = Enum.reduce(edges, lib_medium, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

inputs = %{
  "Small" => {small, lib_small},
  "Medium" => {medium, lib_medium}
}

IO.puts("\n== K-Core Decomposition ==\n")

Benchee.run(
  %{
    "Yog (core_numbers)" => fn {yog, _} -> Yog.Connectivity.KCore.core_numbers(yog) end,
    "libgraph (k_core_components)" => fn {_, lib} -> Graph.k_core_components(lib) end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)
"""

Code.eval_string(code, [], __ENV__)
