#!/usr/bin/env elixir
# Benchmark: Louvain Community Detection
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared

# Initialize Port
port = Shared.start_port()

# Helper to build caveman graph
build_caveman_graph = fn num_cliques, clique_size ->
  g = Yog.undirected()
  total_nodes = num_cliques * clique_size
  g = Enum.reduce(0..(total_nodes - 1), g, &Yog.add_node(&2, &1, nil))

  # Add cliques
  g =
    Enum.reduce(0..(num_cliques - 1), g, fn c, acc ->
      start_idx = c * clique_size
      end_idx = start_idx + clique_size - 1

      edges =
        for i <- start_idx..end_idx//1,
            j <- (i + 1)..end_idx//1,
            i < j,
            do: {i, j, 1.0}

      Enum.reduce(edges, acc, fn {u, v, w}, g_acc ->
        Yog.add_edge_ensure(g_acc, u, v, w)
      end)
    end)

  # Bridge cliques in a ring
  Enum.reduce(0..(num_cliques - 1), g, fn c, acc ->
    next_c = rem(c + 1, num_cliques)
    u = c * clique_size + clique_size - 1
    v = next_c * clique_size
    Yog.add_edge_ensure(acc, u, v, 1.0)
  end)
end

small = build_caveman_graph.(5, 10)
medium = build_caveman_graph.(10, 20)

Shared.register_graph(port, :small, small)
Shared.register_graph(port, :medium, medium)

inputs = %{
  "Small (5 cliques of 10 nodes)" => {:small, small},
  "Medium (10 cliques of 20 nodes)" => {:medium, medium}
}

IO.puts("\n== Louvain Community Detection Comparison ==\n")

Benchee.run(
  %{
    "Yog (Louvain)" => fn {_, yog} -> Yog.Community.Louvain.detect(yog) end,
    "NetworkX (Louvain)" => fn {id, _} ->
      Shared.call(port, "run", %{"graph_id" => id, "algorithm" => "louvain"})
    end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
