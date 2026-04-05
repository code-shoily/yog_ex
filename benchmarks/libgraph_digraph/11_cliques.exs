#!/usr/bin/env elixir
# Benchmark: Clique Detection
# Comparing Yog and libgraph for finding cliques
# Note: Clique detection is NP-hard, so we use small graphs

alias Yog.Generator.Random

# Generate small undirected graphs (clique detection is expensive)
small = Random.erdos_renyi_gnp_with_type(30, 60 / (30 * 29), :undirected, 42)
medium = Random.erdos_renyi_gnp_with_type(50, 100 / (50 * 49), :undirected, 42)

# libgraph
lib_small = Graph.new(type: :undirected)
lib_small = Enum.reduce(0..29, lib_small, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(small)

lib_small =
  Enum.reduce(edges, lib_small, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

lib_medium = Graph.new(type: :undirected)
lib_medium = Enum.reduce(0..49, lib_medium, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(medium)

lib_medium =
  Enum.reduce(edges, lib_medium, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

inputs = %{
  "Small (30n, 60e)" => {small, lib_small},
  "Medium (50n, 100e)" => {medium, lib_medium}
}

IO.puts("\n== Clique Detection: Max Clique ==\n")

Benchee.run(
  %{
    "Yog (max_clique)" => fn {yog, _} -> Yog.Property.Clique.max_clique(yog) end,
    "libgraph (cliques)" => fn {_, lib} -> Graph.cliques(lib) end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)

IO.puts("\n== Clique Detection: K-Cliques (k=3) ==\n")

Benchee.run(
  %{
    "Yog (k_cliques 3)" => fn {yog, _} -> Yog.Property.Clique.k_cliques(yog, 3) end,
    "libgraph (k_cliques 3)" => fn {_, lib} -> Graph.k_cliques(lib, 3) end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)

IO.puts("\n== Clique Detection: K-Cliques (k=4) ==\n")

Benchee.run(
  %{
    "Yog (k_cliques 4)" => fn {yog, _} -> Yog.Property.Clique.k_cliques(yog, 4) end,
    "libgraph (k_cliques 4)" => fn {_, lib} -> Graph.k_cliques(lib, 4) end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)
