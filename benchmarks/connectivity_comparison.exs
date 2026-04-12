#!/usr/bin/env elixir

defmodule ConnectivityBenchmark do
  @moduledoc """
  Benchmark comparing Kosaraju's and Tarjan's algorithms for strongly
  connected components (SCC) in directed graphs.

  Both algorithms run in O(V + E) time. Kosaraju uses two DFS passes
  (one on the graph, one on the transposed graph), while Tarjan finds
  SCCs in a single DFS pass using a stack and low-link values.
  """

  alias Yog.Connectivity.SCC

  @iterations 50

  def run do
    IO.puts("Strongly Connected Components Benchmark: Kosaraju vs Tarjan")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Each test runs #{@iterations} iterations and reports total / average time.\n")

    # Sparse directed networks
    run_suite("Sparse Directed Networks", [
      {"100 nodes, ~300 edges", build_sparse_graph(100, 300)},
      {"500 nodes, ~1_500 edges", build_sparse_graph(500, 1500)},
      {"1_000 nodes, ~3_000 edges", build_sparse_graph(1000, 3000)}
    ])

    # Dense directed networks
    run_suite("Dense Directed Networks", [
      {"50 nodes, ~600 edges", build_dense_graph(50)},
      {"100 nodes, ~2_500 edges", build_dense_graph(100)},
      {"200 nodes, ~10_000 edges", build_dense_graph(200)}
    ])

    # Structured SCC networks: path of cliques
    run_suite("Path of Cliques", [
      {"10 cliques × 10 nodes", build_cycle_of_cliques(10, 10)},
      {"20 cliques × 10 nodes", build_cycle_of_cliques(20, 10)},
      {"10 cliques × 50 nodes", build_cycle_of_cliques(10, 50)}
    ])

    # Correctness check
    IO.puts("\n== Correctness Check ==")

    for {name, graph} <- [
          {"100-node sparse", build_sparse_graph(100, 300)},
          {"100-node dense", build_dense_graph(100)},
          {"10×10 clique path", build_cycle_of_cliques(10, 10)}
        ] do
      kosaraju_sccs = SCC.kosaraju(graph)
      tarjan_sccs = SCC.strongly_connected_components(graph)

      kosaraju_count = length(kosaraju_sccs)
      tarjan_count = length(tarjan_sccs)

      kosaraju_sizes = Enum.map(kosaraju_sccs, &length/1) |> Enum.sort()
      tarjan_sizes = Enum.map(tarjan_sccs, &length/1) |> Enum.sort()

      match =
        if kosaraju_count == tarjan_count and kosaraju_sizes == tarjan_sizes do
          "✓"
        else
          "✗"
        end

      IO.puts("  #{match} #{name}: SCCs=#{kosaraju_count}")
    end

    # Memory summary
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 on SCC result in words)")

    for n <- [100, 500] do
      graph = build_sparse_graph(n, n * 3)

      k_size = :erts_debug.size(SCC.kosaraju(graph))
      t_size = :erts_debug.size(SCC.strongly_connected_components(graph))

      IO.puts("\nSparse #{n} nodes:")
      IO.puts("  Kosaraju: #{k_size} words (~#{format_bytes(k_size * 8)})")
      IO.puts("  Tarjan:   #{t_size} words (~#{format_bytes(t_size * 8)})")
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Summary:")
    IO.puts("- Kosaraju: O(V + E), two-pass DFS, conceptually simpler")
    IO.puts("- Tarjan:   O(V + E), single-pass DFS, lower constant factors in practice")
  end

  defp run_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, graph} <- cases do
      {k_total, k_count} = bench_iterations(fn -> SCC.kosaraju(graph) end)
      {t_total, t_count} = bench_iterations(fn -> SCC.strongly_connected_components(graph) end)

      k_avg = Float.round(k_total / @iterations, 3)
      t_avg = Float.round(t_total / @iterations, 3)

      winner =
        if t_avg < k_avg,
          do: "Tarjan #{Float.round(k_avg / t_avg, 2)}x faster",
          else: "Kosaraju #{Float.round(t_avg / k_avg, 2)}x faster"

      IO.puts("  #{name}")
      IO.puts("    Kosaraju: #{k_total}ms total, #{k_avg}ms avg (SCCs=#{k_count})")
      IO.puts("    Tarjan:   #{t_total}ms total, #{t_avg}ms avg (SCCs=#{t_count})")
      IO.puts("    → #{winner}")
    end
  end

  defp bench_iterations(fun) do
    # Warmup
    _ = fun.()
    :erlang.garbage_collect()

    {total_us, result} =
      :timer.tc(fn ->
        Enum.reduce(1..@iterations, nil, fn _, _ -> fun.() end)
      end)

    count = if is_list(result), do: length(result), else: :error
    {Float.round(total_us / 1000, 2), count}
  end

  # Build a sparse directed graph with n nodes and exactly m edges
  defp build_sparse_graph(n, m) when m > n do
    nodes = 0..(n - 1)

    g =
      Enum.reduce(nodes, Yog.directed(), fn i, acc ->
        Yog.add_node(acc, i, nil)
      end)

    # Start with a directed cycle to ensure reachability
    g =
      Enum.reduce(0..(n - 1), g, fn i, acc ->
        next = rem(i + 1, n)
        Yog.add_edge_ensure(acc, i, next, 1)
      end)

    remaining = m - n

    {g, _} =
      Stream.repeatedly(fn -> {:rand.uniform(n) - 1, :rand.uniform(n) - 1} end)
      |> Enum.reduce_while({g, remaining}, fn {u, v}, {acc, rem} ->
        if rem <= 0 do
          {:halt, {acc, rem}}
        else
          if u != v and not Yog.has_edge?(acc, u, v) do
            {:cont, {Yog.add_edge_ensure(acc, u, v, 1), rem - 1}}
          else
            {:cont, {acc, rem}}
          end
        end
      end)

    g
  end

  # Build a dense directed graph with n nodes and ~n*(n/4) edges
  defp build_dense_graph(n) do
    nodes = 0..(n - 1)

    g =
      Enum.reduce(nodes, Yog.directed(), fn i, acc ->
        Yog.add_node(acc, i, nil)
      end)

    edges =
      for i <- nodes,
          j <- nodes,
          i != j,
          :rand.uniform(4) == 1,
          do: {i, j, 1}

    Enum.reduce(edges, g, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end

  # Build a cycle of cliques: num_cliques cliques of size clique_size,
  # with one-way edges from every node in clique i to every node in clique i+1
  defp build_cycle_of_cliques(num_cliques, clique_size) do
    n = num_cliques * clique_size

    g =
      Enum.reduce(0..(n - 1), Yog.directed(), fn i, acc ->
        Yog.add_node(acc, i, nil)
      end)

    # Clique edges within each clique
    clique_edges =
      for c <- 0..(num_cliques - 1),
          base = c * clique_size,
          i <- base..(base + clique_size - 1),
          j <- base..(base + clique_size - 1),
          i != j,
          do: {i, j, 1}

    # Inter-clique edges: all-to-all from clique c to clique c+1 (no wrap-around)
    # This makes each clique its own SCC
    inter_edges =
      for c <- 0..(num_cliques - 2),
          next_c = c + 1,
          base = c * clique_size,
          next_base = next_c * clique_size,
          i <- base..(base + clique_size - 1),
          j <- next_base..(next_base + clique_size - 1),
          do: {i, j, 1}

    Enum.reduce(clique_edges ++ inter_edges, g, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

ConnectivityBenchmark.run()
