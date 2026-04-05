#!/usr/bin/env elixir
# Benchmark: Arborescence Check (Directed Tree)
# Comparing Yog and libgraph

code = """
# Create tree-like structures for arborescence check
arborescence_graphs = fn n ->
  # Yog - create a star tree
  yog = Yog.directed()
  yog = Enum.reduce(0..(n - 1), yog, fn i, g -> Yog.add_node(g, i, nil) end)
  yog = Enum.reduce(1..(n - 1), yog, fn i, g ->
    {:ok, ng} = Yog.add_edge(g, 0, i, 1)
    ng
  end)

  # libgraph
  lib = Graph.new(type: :directed)
  lib = Enum.reduce(0..(n - 1), lib, fn i, g -> Graph.add_vertex(g, i) end)
  lib = Enum.reduce(1..(n - 1), lib, fn i, g ->
    Graph.add_edge(g, 0, i, weight: 1)
  end)

  {yog, lib}
end

{yog_s, lib_s} = arborescence_graphs.(50)
{yog_m, lib_m} = arborescence_graphs.(100)

inputs = %{
  "Small (50 nodes)" => {yog_s, lib_s},
  "Medium (100 nodes)" => {yog_m, lib_m}
}

IO.puts("\n== Arborescence Check (Directed Tree) ==\n")

Benchee.run(
  %{
    "Yog (arborescence?)" => fn {yog, _} -> Yog.Property.Structure.arborescence?(yog) end,
    "libgraph (is_arborescence?)" => fn {_, lib} -> Graph.Directed.is_arborescence?(lib) end
  },
  inputs: inputs,
  time: 2,
  warmup: 1
)
"""

Code.eval_string(code, [], __ENV__)
