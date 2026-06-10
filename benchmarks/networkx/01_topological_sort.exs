#!/usr/bin/env elixir
# Benchmark: Topological Sort
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared

# Initialize Port
port = Shared.start_port()

# Helper to build a guaranteed DAG
build_dag = fn nodes, edges ->
  g = Yog.directed()
  g = Enum.reduce(0..(nodes - 1), g, fn i, acc -> Yog.add_node(acc, i, nil) end)

  Enum.reduce(1..edges, g, fn _, acc ->
    u = :rand.uniform(nodes) - 1
    v = :rand.uniform(nodes) - 1

    if u != v do
      {u, v} = if u < v, do: {u, v}, else: {v, u}
      Yog.add_edge_ensure(acc, u, v, 1)
    else
      acc
    end
  end)
end

small = build_dag.(100, 150)
medium = build_dag.(500, 1000)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (100n, 150e)" => {:small, small},
  "Medium (500n, 1000e)" => {:medium, medium}
}

IO.puts("\n== Topological Sort Comparison ==\n")

Benchee.run(
  %{
    "Yog (Kahn)" => fn {_, yog} -> Yog.Traversal.Sort.topological_sort(yog) end,
    "NetworkX (Topological Sort)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "topological_sort"})
    end
  },
  inputs: inputs,
  time: 2,
  warmup: 1
)

Shared.stop_port(port)
