#!/usr/bin/env elixir
# Benchmark: Shortest Path (Bellman-Ford with negative weights)
# Comparing Yog and libgraph

alias Yog.Generator.Random

# Generate graphs with negative weights
bellman_graphs = fn n, m ->
  yog = Random.erdos_renyi_gnp_with_type(n, m / (n * (n - 1)), :directed, 42)
  edges = Yog.Model.all_edges(yog)

  # Yog with negative weights
  yog = Yog.directed()
  yog = Enum.reduce(0..(n - 1), yog, fn i, g -> Yog.add_node(g, i, nil) end)

  yog =
    Enum.reduce(edges, yog, fn {u, v, w}, g ->
      new_weight = if rem(u, 5) == 0, do: -w, else: w

      case Yog.add_edge(g, u, v, new_weight) do
        {:ok, ng} -> ng
        {:error, _} -> g
      end
    end)

  # libgraph with negative weights
  lib = Graph.new(type: :directed)
  lib = Enum.reduce(0..(n - 1), lib, fn i, g -> Graph.add_vertex(g, i) end)

  lib =
    Enum.reduce(edges, lib, fn {u, v, w}, g ->
      new_weight = if rem(u, 5) == 0, do: -w, else: w
      Graph.add_edge(g, u, v, weight: new_weight)
    end)

  {yog, lib}
end

{yog_s, lib_s} = bellman_graphs.(50, 75)
{yog_m, lib_m} = bellman_graphs.(100, 150)

inputs = %{
  "Small (50n, 75e)" => {yog_s, lib_s},
  "Medium (100n, 150e)" => {yog_m, lib_m}
}

# Define compare function once
compare_fn = fn a, b ->
  cond do
    a < b -> :lt
    a > b -> :gt
    true -> :eq
  end
end

IO.puts("\n== Shortest Path (Bellman-Ford with negative weights) ==\n")

Benchee.run(
  %{
    "Yog (Bellman-Ford)" => fn {yog, _} ->
      Yog.Pathfinding.BellmanFord.bellman_ford(
        in: yog,
        from: 0,
        to: 25,
        zero: 0,
        combine: &(&1 + &2),
        compare: compare_fn
      )
    end,
    "libgraph (Bellman-Ford)" => fn {_, lib} ->
      Graph.Pathfinding.bellman_ford(lib, 0)
    end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)
