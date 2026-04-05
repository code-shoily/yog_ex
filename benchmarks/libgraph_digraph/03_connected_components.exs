#!/usr/bin/env elixir
# Benchmark: Connected Components (Undirected)
# Comparing Yog, libgraph, and :digraph

code = """
alias Yog.Generator.Random

# Generate undirected graphs
small = Random.erdos_renyi_gnp_with_type(100, 150 / (100 * 99), :undirected, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :undirected, 42)

# libgraph (undirected)
lib_small = Graph.new(type: :undirected)
lib_small = Enum.reduce(0..99, lib_small, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(small)
lib_small = Enum.reduce(edges, lib_small, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

lib_medium = Graph.new(type: :undirected)
lib_medium = Enum.reduce(0..499, lib_medium, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(medium)
lib_medium = Enum.reduce(edges, lib_medium, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

# :digraph (undirected = cyclic)
dg_small = :digraph.new([:cyclic])
Enum.each(0..99, fn i -> :digraph.add_vertex(dg_small, i) end)
Enum.each(Yog.Model.all_edges(small), fn {u, v, _w} -> 
  :digraph.add_edge(dg_small, u, v)
  :digraph.add_edge(dg_small, v, u)
end)

dg_medium = :digraph.new([:cyclic])
Enum.each(0..499, fn i -> :digraph.add_vertex(dg_medium, i) end)
Enum.each(Yog.Model.all_edges(medium), fn {u, v, _w} -> 
  :digraph.add_edge(dg_medium, u, v)
  :digraph.add_edge(dg_medium, v, u)
end)

inputs = %{
  "Small" => {small, lib_small, dg_small},
  "Medium" => {medium, lib_medium, dg_medium}
}

IO.puts("\n== Connected Components (Undirected) ==\n")

Benchee.run(
  %{
    "Yog" => fn {yog, _, _} -> Yog.Connectivity.Components.connected_components(yog) end,
    "libgraph" => fn {_, lib, _} -> Graph.components(lib) end,
    ":digraph" => fn {_, _, dg} -> :digraph_utils.components(dg) end
  },
  inputs: inputs,
  time: 2,
  warmup: 1
)

:digraph.delete(dg_small)
:digraph.delete(dg_medium)
"""

Code.eval_string(code, [], __ENV__)
