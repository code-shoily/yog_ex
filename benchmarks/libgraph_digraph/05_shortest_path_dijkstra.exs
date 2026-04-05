#!/usr/bin/env elixir
# Benchmark: Shortest Path (Dijkstra)
# Comparing Yog, libgraph, and :digraph

alias Yog.Generator.Random

# Generate directed graphs
medium = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :directed, 42)

# libgraph
lib_medium = Graph.new(type: :directed)
lib_medium = Enum.reduce(0..499, lib_medium, fn i, g -> Graph.add_vertex(g, i) end)
edges = Yog.Model.all_edges(medium)

lib_medium =
  Enum.reduce(edges, lib_medium, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

# :digraph
dg_medium = :digraph.new()
Enum.each(0..499, fn i -> :digraph.add_vertex(dg_medium, i) end)
Enum.each(Yog.Model.all_edges(medium), fn {u, v, _w} -> :digraph.add_edge(dg_medium, u, v) end)

source = 0
target = 249

IO.puts("\n== Shortest Path (Dijkstra) ==\n")
IO.puts("Graph: 500 nodes, 1000 edges")
IO.puts("Source: #{source}, Target: #{target}\n")

Benchee.run(
  %{
    "Yog (Dijkstra)" => fn ->
      Yog.Pathfinding.Dijkstra.shortest_path(in: medium, from: source, to: target)
    end,
    "libgraph (Dijkstra)" => fn -> Graph.dijkstra(lib_medium, source, target) end,
    ":digraph (BFS)" => fn -> :digraph.get_short_path(dg_medium, source, target) end
  },
  time: 3,
  warmup: 1
)

:digraph.delete(dg_medium)
