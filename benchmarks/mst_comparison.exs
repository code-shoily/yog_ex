#!/usr/bin/env elixir

defmodule MSTBenchmark do
  @moduledoc """
  Benchmark comparing Kruskal's, Prim's, and Borůvka's MST algorithms.

  All three algorithms find a minimum spanning tree (or forest) in an undirected
  weighted graph. Kruskal's sorts edges and uses union-find, Prim's grows the
  tree from a starting node using a priority queue, and Borůvka's repeatedly
  adds the cheapest edge leaving each component.
  """

  alias Yog.MST

  @iterations 50

  def run do
    IO.puts("Minimum Spanning Tree Benchmark: Kruskal vs Prim vs Boruvka")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Each test runs #{@iterations} iterations and reports total / average time.\n")

    # Sparse networks
    run_suite("Sparse Networks", [
      {"100 nodes, ~300 edges", build_sparse_graph(100, 300)},
      {"500 nodes, ~1_500 edges", build_sparse_graph(500, 1500)},
      {"1_000 nodes, ~3_000 edges", build_sparse_graph(1000, 3000)}
    ])

    # Dense networks
    run_suite("Dense Networks", [
      {"50 nodes, ~600 edges", build_dense_graph(50)},
      {"100 nodes, ~2_500 edges", build_dense_graph(100)},
      {"200 nodes, ~10_000 edges", build_dense_graph(200)}
    ])

    # Grid networks
    run_suite("Grid Networks", [
      {"10×10 grid", build_grid_graph(10)},
      {"20×20 grid", build_grid_graph(20)},
      {"30×30 grid", build_grid_graph(30)}
    ])

    # Correctness check
    IO.puts("\n== Correctness Check ==")

    for {name, graph} <- [
          {"100-node sparse", build_sparse_graph(100, 300)},
          {"100-node dense", build_dense_graph(100)},
          {"20×20 grid", build_grid_graph(20)}
        ] do
      {:ok, kruskal_res} = MST.kruskal(graph)
      {:ok, prim_res} = MST.prim(graph)
      {:ok, boruvka_res} = MST.boruvka(graph)

      k_w = kruskal_res.total_weight
      p_w = prim_res.total_weight
      b_w = boruvka_res.total_weight

      match = if k_w == p_w and p_w == b_w, do: "✓", else: "✗"
      IO.puts("  #{match} #{name}: K=#{k_w}, P=#{p_w}, B=#{b_w}")
    end

    # Memory summary
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 on MST result in words)")

    for n <- [100, 500] do
      graph = build_sparse_graph(n, n * 3)

      {:ok, k_res} = MST.kruskal(graph)
      {:ok, p_res} = MST.prim(graph)
      {:ok, b_res} = MST.boruvka(graph)

      k_size = :erts_debug.size(k_res)
      p_size = :erts_debug.size(p_res)
      b_size = :erts_debug.size(b_res)

      IO.puts("\nSparse #{n} nodes:")
      IO.puts("  Kruskal: #{k_size} words (~#{format_bytes(k_size * 8)})")
      IO.puts("  Prim:    #{p_size} words (~#{format_bytes(p_size * 8)})")
      IO.puts("  Boruvka: #{b_size} words (~#{format_bytes(b_size * 8)})")
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Summary:")
    IO.puts("- Kruskal: O(E log E), excellent for sparse graphs")
    IO.puts("- Prim:    O(E log V), often fastest on dense / grid graphs")
    IO.puts("- Boruvka: O(E log V), parallel-friendly, competitive on large sparse graphs")
  end

  defp run_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, graph} <- cases do
      {k_total, k_weight} = bench_iterations(fn -> MST.kruskal(graph) end)
      {p_total, p_weight} = bench_iterations(fn -> MST.prim(graph) end)
      {b_total, b_weight} = bench_iterations(fn -> MST.boruvka(graph) end)

      k_avg = Float.round(k_total / @iterations, 3)
      p_avg = Float.round(p_total / @iterations, 3)
      b_avg = Float.round(b_total / @iterations, 3)

      {_fastest, fastest_label} =
        [{k_avg, "Kruskal"}, {p_avg, "Prim"}, {b_avg, "Boruvka"}]
        |> Enum.min_by(fn {time, _} -> time end)

      IO.puts("  #{name}")
      IO.puts("    Kruskal: #{k_total}ms total, #{k_avg}ms avg (weight=#{k_weight})")
      IO.puts("    Prim:    #{p_total}ms total, #{p_avg}ms avg (weight=#{p_weight})")
      IO.puts("    Boruvka: #{b_total}ms total, #{b_avg}ms avg (weight=#{b_weight})")
      IO.puts("    → #{fastest_label} fastest")
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

    weight =
      case result do
        {:ok, %Yog.MST.Result{total_weight: w}} -> w
        _ -> :error
      end

    {Float.round(total_us / 1000, 2), weight}
  end

  # Build a sparse undirected graph with n nodes and exactly m edges
  defp build_sparse_graph(n, m) when m > n do
    nodes = 0..(n - 1)

    g =
      Enum.reduce(nodes, Yog.undirected(), fn i, acc ->
        Yog.add_node(acc, i, nil)
      end)

    # Start with a random tree to ensure connectivity
    g =
      Enum.reduce(1..(n - 1), g, fn i, acc ->
        parent = :rand.uniform(i) - 1
        Yog.add_edge_ensure(acc, parent, i, :rand.uniform(100))
      end)

    # Add remaining edges randomly
    remaining = m - (n - 1)

    all_pairs = for i <- 0..(n - 2), j <- (i + 1)..(n - 1), do: {i, j}
    shuffled = Enum.shuffle(all_pairs)

    {g, _} =
      Enum.reduce(shuffled, {g, remaining}, fn {i, j}, {acc, rem} ->
        if rem > 0 and not Yog.has_edge?(acc, i, j) do
          {Yog.add_edge_ensure(acc, i, j, :rand.uniform(100)), rem - 1}
        else
          {acc, rem}
        end
      end)

    g
  end

  # Build a dense undirected graph with n nodes and ~n*(n/4) edges
  defp build_dense_graph(n) do
    nodes = 0..(n - 1)

    g =
      Enum.reduce(nodes, Yog.undirected(), fn i, acc ->
        Yog.add_node(acc, i, nil)
      end)

    edges =
      for i <- 0..(n - 2),
          j <- (i + 1)..(n - 1),
          :rand.uniform(4) == 1,
          do: {i, j, :rand.uniform(100)}

    Enum.reduce(edges, g, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end

  # Build an n×n undirected grid with random weights 1..100
  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.undirected(), fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = i * n + j
        acc = Yog.add_node(acc, node_id, nil)

        acc =
          if j < n - 1 do
            right_id = i * n + (j + 1)
            Yog.add_edge_ensure(acc, node_id, right_id, :rand.uniform(100))
          else
            acc
          end

        acc =
          if i < n - 1 do
            down_id = (i + 1) * n + j
            Yog.add_edge_ensure(acc, node_id, down_id, :rand.uniform(100))
          else
            acc
          end

        acc
      end)
    end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

MSTBenchmark.run()
