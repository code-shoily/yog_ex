#!/usr/bin/env elixir
# Benchmark: Graph Creation & Memory Usage
# Comparing Yog, libgraph, and :digraph for building graphs from edge lists

code = """
alias Yog.Generator.Random

# Generate edge lists from Yog graphs
small_yog = Random.erdos_renyi_gnp_with_type(100, 150 / (100 * 99), :directed, 42)
medium_yog = Random.erdos_renyi_gnp_with_type(500, 1000 / (500 * 499), :directed, 42)
large_yog = Random.erdos_renyi_gnp_with_type(1000, 3000 / (1000 * 999), :directed, 42)

small_edges = Yog.Model.all_edges(small_yog)
medium_edges = Yog.Model.all_edges(medium_yog)
large_edges = Yog.Model.all_edges(large_yog)

IO.puts("\n== Graph Creation (from edge list) ==\n")

Benchee.run(
  %{
    "Yog" => fn {edges, n} ->
      g = Yog.directed()
      g = Enum.reduce(0..(n - 1), g, fn i, acc -> Yog.add_node(acc, i, nil) end)
      Enum.reduce(edges, g, fn {u, v, w}, acc ->
        case Yog.add_edge(acc, u, v, w) do
          {:ok, ng} -> ng
          {:error, _} -> acc
        end
      end)
    end,
    "libgraph" => fn {edges, n} ->
      g = Graph.new()
      g = Enum.reduce(0..(n - 1), g, fn i, acc -> Graph.add_vertex(acc, i) end)
      Enum.reduce(edges, g, fn {u, v, w}, acc -> Graph.add_edge(acc, u, v, weight: w) end)
    end,
    ":digraph" => fn {edges, n} ->
      dg = :digraph.new()
      Enum.each(0..(n - 1), fn i -> :digraph.add_vertex(dg, i) end)
      Enum.each(edges, fn {u, v, _w} -> :digraph.add_edge(dg, u, v) end)
      dg
    end
  },
  inputs: %{
    "Small (100n, 150e)" => {small_edges, 100},
    "Medium (500n, 1000e)" => {medium_edges, 500}
  },
  time: 3,
  warmup: 1
)

IO.puts("\n== Memory Usage (1000 nodes, 3000 edges) ==\n")

yog_size = :erts_debug.size(small_yog)
lib_size = :erts_debug.size(small_yog)
dg_test = :digraph.new()
Enum.each(0..999, fn i -> :digraph.add_vertex(dg_test, i) end)
Enum.each(large_edges, fn {u, v, _w} -> :digraph.add_edge(dg_test, u, v) end)
dg_size = :erts_debug.size(dg_test)
:digraph.delete(dg_test)

IO.puts("Memory (in words, 1 word = 8 bytes on 64-bit):")
IO.puts("  Yog:      #{yog_size} words (~#{Float.round(yog_size * 8 / 1024, 2)} KB)")
IO.puts("  libgraph: #{lib_size} words (~#{Float.round(lib_size * 8 / 1024, 2)} KB)")
IO.puts("  :digraph: #{dg_size} words (~#{Float.round(dg_size * 8 / 1024, 2)} KB)")
"""

Code.eval_string(code, [], __ENV__)
