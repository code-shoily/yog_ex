#!/usr/bin/env elixir

defmodule CentralityBenchmark do
  @moduledoc """
  Benchmark comparing Degree, Closeness, Betweenness, and PageRank centralities.
  """

  alias Yog.Centrality

  @iterations 5

  def run do
    IO.puts("Centrality Benchmark: PageRank vs Betweenness vs Closeness vs Degree")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("Each test runs #{@iterations} iterations and reports total / average time.\n")

    # Star-like (Scale-free proxy)
    run_suite("Hub-and-Spoke Networks", [
      {"500 nodes (1 central hub)", build_star_graph(500)},
      {"2000 nodes (1 central hub)", build_star_graph(2000)}
    ])

    # Dense clusters
    run_suite("Dense Random Networks", [
      {"100 nodes, ~2500 edges", build_dense_graph(100)},
      {"300 nodes, ~22500 edges", build_dense_graph(300)}
    ])

    # Sparse graphs
    run_suite("Sparse Networks", [
      {"500 nodes, ~1500 edges", build_sparse_graph(500, 1500)},
      {"1000 nodes, ~3000 edges", build_sparse_graph(1000, 3000)}
    ])

    # Correctness check
    IO.puts("\n== Correctness Check ==")

    star = build_star_graph(100)
    degree_scores = Centrality.degree(star)
    max_degree_node = Enum.max_by(degree_scores, fn {_, v} -> v end) |> elem(0)
    IO.puts("  ✓ Star graph: highest degree node is #{max_degree_node} (expected 0)")

    path = build_path_graph(11)
    betweenness_scores = Centrality.betweenness(path)
    max_betweenness_node = Enum.max_by(betweenness_scores, fn {_, v} -> v end) |> elem(0)
    IO.puts("  ✓ Path graph: highest betweenness node is #{max_betweenness_node} (expected 5)")

    sparse = build_sparse_graph(100, 300)
    pr_scores = Centrality.pagerank(sparse)
    IO.puts("  ✓ PageRank returns #{map_size(pr_scores)} scores (expected 100)")

    # Memory summary
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 on result in words)")

    graph = build_dense_graph(100)

    d_size = :erts_debug.size(Centrality.degree(graph))
    pr_size = :erts_debug.size(Centrality.pagerank(graph))
    c_size = :erts_debug.size(Centrality.closeness(graph))
    b_size = :erts_debug.size(Centrality.betweenness(graph))

    IO.puts("\nDense 100 nodes:")
    IO.puts("  Degree:      #{d_size} words (~#{format_bytes(d_size * 8)})")
    IO.puts("  PageRank:    #{pr_size} words (~#{format_bytes(pr_size * 8)})")
    IO.puts("  Closeness:   #{c_size} words (~#{format_bytes(c_size * 8)})")
    IO.puts("  Betweenness: #{b_size} words (~#{format_bytes(b_size * 8)})")

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("Summary:")
    IO.puts("- Degree: Near instantaneous (O(V + E)).")
    IO.puts("- PageRank: Very fast iterative solution; scales linearly.")
    IO.puts("- Closeness: N shortest-path trees (O(V(V+E)logV)).")

    IO.puts(
      "- Betweenness: Extremely heavy (O(VE)). Brandes algorithm is optimized but fundamentally slow on dense graphs."
    )
  end

  defp run_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, graph} <- cases do
      IO.puts("  #{name}")

      node_count = map_size(graph.nodes)
      run_closeness = node_count <= 1000
      run_betweenness = node_count <= 500

      results = []
      results = [{"Degree", bench(fn -> Centrality.degree(graph) end)} | results]
      results = [{"PageRank", bench(fn -> Centrality.pagerank(graph) end)} | results]

      results =
        if run_closeness do
          [{"Closeness", bench(fn -> Centrality.closeness(graph) end)} | results]
        else
          results
        end

      results =
        if run_betweenness do
          [{"Betweenness", bench(fn -> Centrality.betweenness(graph) end)} | results]
        else
          results
        end

      results = Enum.reverse(results)

      for {label, avg_ms} <- results do
        IO.puts("    #{String.pad_trailing(label <> ":", 16)} #{avg_ms}ms avg")
      end

      if run_closeness and run_betweenness do
        {fastest_label, _} = Enum.min_by(results, fn {_, t} -> t end)
        IO.puts("    → #{fastest_label} fastest")
      end

      unless run_closeness, do: IO.puts("    Closeness:       Skipped (Network too large)")
      unless run_betweenness, do: IO.puts("    Betweenness:     Skipped (Network too large)")
      IO.puts("")
    end
  end

  defp bench(fun) do
    _ = fun.()
    :erlang.garbage_collect()

    {total_us, _} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    Float.round(total_us / 1000 / @iterations, 3)
  end

  # =========================================================================
  # Generators
  # =========================================================================

  defp build_star_graph(n) do
    g = Enum.reduce(0..(n - 1), Yog.undirected(), &Yog.add_node(&2, &1, nil))

    Enum.reduce(1..(n - 1), g, fn i, acc ->
      Yog.add_edge_ensure(acc, 0, i, 1)
    end)
  end

  defp build_path_graph(n) do
    g = Enum.reduce(0..(n - 1), Yog.undirected(), &Yog.add_node(&2, &1, nil))

    Enum.reduce(0..(n - 2), g, fn i, acc ->
      Yog.add_edge_ensure(acc, i, i + 1, 1)
    end)
  end

  defp build_sparse_graph(n, m) when m > n do
    nodes = 0..(n - 1)
    g = Enum.reduce(nodes, Yog.undirected(), &Yog.add_node(&2, &1, nil))

    # Random tree for connectivity
    g =
      Enum.reduce(1..(n - 1), g, fn i, acc ->
        parent = :rand.uniform(i) - 1
        Yog.add_edge_ensure(acc, parent, i, 1)
      end)

    # Rest are random edges
    remaining = m - (n - 1)

    Enum.reduce(1..remaining, g, fn _, acc ->
      u = :rand.uniform(n) - 1
      v = :rand.uniform(n) - 1

      if u != v do
        Yog.add_edge_ensure(acc, u, v, 1)
      else
        acc
      end
    end)
  end

  defp build_dense_graph(n) do
    nodes = 0..(n - 1)
    g = Enum.reduce(nodes, Yog.undirected(), &Yog.add_node(&2, &1, nil))

    edges =
      for i <- 0..(n - 1),
          j <- i..(n - 1),
          i != j,
          :rand.uniform(2) == 1,
          do: {i, j, 1}

    Enum.reduce(edges, g, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

CentralityBenchmark.run()
