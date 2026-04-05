#!/usr/bin/env elixir
# Benchmark: Topological Sort
# Comparing Yog (Kahn), libgraph (DFS), and :digraph (DFS)

code = """
alias Yog.Generator.Random

# Generate directed graphs
small = Random.erdos_renyi_gnp_with_type(100, 150 / (100 * 99), :directed, 42)
medium = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :directed, 42)

# libgraph
lib_small = Graph.new(type: :directed)
lib_small = Enum.reduce(0..99, lib_small, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(small)
lib_small = Enum.reduce(edges, lib_small, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

lib_medium = Graph.new(type: :directed)
lib_medium = Enum.reduce(0..499, lib_medium, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(medium)
lib_medium = Enum.reduce(edges, lib_medium, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

# :digraph
dg_small = :digraph.new()
Enum.each(0..99, fn i -> :digraph.add_vertex(dg_small, i) end)
Enum.each(Yog.Model.all_edges(small), fn {u, v, _w} -> :digraph.add_edge(dg_small, u, v) end)

dg_medium = :digraph.new()
Enum.each(0..499, fn i -> :digraph.add_vertex(dg_medium, i) end)
Enum.each(Yog.Model.all_edges(medium), fn {u, v, _w} -> :digraph.add_edge(dg_medium, u, v) end)

inputs = %{
  "Small (100n, 150e)" => {small, lib_small, dg_small},
  "Medium (500n, 1000e)" => {medium, lib_medium, dg_medium}
}

IO.puts("\n== Topological Sort Comparison ==\n")

Benchee.run(
  %{
    "Yog (Kahn)" => fn {yog, _, _} -> Yog.Traversal.Sort.topological_sort(yog) end,
    "libgraph (DFS)" => fn {_, lib, _} -> Graph.topsort(lib) end,
    ":digraph (DFS)" => fn {_, _, dg} -> :digraph_utils.topsort(dg) end
  },
  inputs: inputs,
  time: 2,
  warmup: 1
)

:digraph.delete(dg_small)
:digraph.delete(dg_medium)
"""

Code.eval_string(code, [], __ENV__)
