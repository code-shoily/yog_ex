#!/usr/bin/env elixir

defmodule PathfindingBenchmark do
  @moduledoc """
  Benchmark comparing Dijkstra, A*, Bidirectional Dijkstra, and Bellman-Ford.
  """

  alias Yog.Pathfinding

  @iterations 30

  def run do
    IO.puts("Pathfinding Benchmark: Dijkstra vs A* vs Bidirectional vs Bellman-Ford")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("Each test runs #{@iterations} iterations and reports total / average time.\n")

    # 1. Very sparse networks (long paths)
    run_suite("Sparse Networks (Single Pair)", [
      {"1000 nodes, ~3000 edges", build_sparse_graph(1000, 3000), 0, 999},
      {"5000 nodes, ~15000 edges", build_sparse_graph(5000, 15000), 0, 4999}
    ])

    # 2. Dense networks
    run_suite("Dense Networks (Single Pair)", [
      {"500 nodes, ~25000 edges", build_dense_graph(500), 0, 499},
      {"1000 nodes, ~100000 edges", build_dense_graph(1000), 0, 999}
    ])

    # 3. Grid Networks (Where A* shines!)
    run_grid_suite("Grid Networks (Single Pair)", [
      {"20x20 grid", 20},
      {"50x50 grid", 50},
      {"100x100 grid", 100}
    ])

    # Correctness check
    IO.puts("\n== Correctness Check ==")

    sparse = build_sparse_graph(100, 300)
    {:ok, d_sparse} = Pathfinding.shortest_path(in: sparse, from: 0, to: 99)
    {:ok, b_sparse} = Pathfinding.bidirectional(in: sparse, from: 0, to: 99)
    {:ok, bf_sparse} = Pathfinding.bellman_ford(in: sparse, from: 0, to: 99)

    match_sparse =
      if d_sparse.weight == b_sparse.weight and b_sparse.weight == bf_sparse.weight,
        do: "✓",
        else: "✗"

    IO.puts(
      "  #{match_sparse} Sparse 100n: Dijkstra=#{d_sparse.weight}, Bidirectional=#{b_sparse.weight}, Bellman-Ford=#{bf_sparse.weight}"
    )

    grid20 = build_grid_graph(20)

    heuristic20 = fn u, v ->
      {ux, uy} = {div(u, 20), rem(u, 20)}
      {vx, vy} = {div(v, 20), rem(v, 20)}
      abs(ux - vx) + abs(uy - vy)
    end

    {:ok, d_grid} = Pathfinding.shortest_path(in: grid20, from: 0, to: 399)
    {:ok, b_grid} = Pathfinding.bidirectional(in: grid20, from: 0, to: 399)
    {:ok, a_grid} = Pathfinding.a_star(in: grid20, from: 0, to: 399, heuristic: heuristic20)

    match_grid =
      if d_grid.weight == b_grid.weight and b_grid.weight == a_grid.weight, do: "✓", else: "✗"

    IO.puts(
      "  #{match_grid} 20×20 grid: Dijkstra=#{d_grid.weight}, Bidirectional=#{b_grid.weight}, A*=#{a_grid.weight}"
    )

    # Yen's k-shortest paths correctness check
    yen_graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {1, 2, 1},
        {1, 3, 2},
        {2, 3, 1},
        {2, 4, 3},
        {3, 4, 1},
        {3, 5, 4},
        {4, 5, 1}
      ])

    {:ok, yen_paths} = Pathfinding.k_shortest_paths(yen_graph, 1, 5, 3)
    yen_weights = Enum.map(yen_paths, & &1.weight)
    match_yen = if yen_weights == [4, 4, 5], do: "✓", else: "✗"
    IO.puts("  #{match_yen} Yen k=3: weights=#{inspect(yen_weights)}")

    # Memory summary
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 on path result in words)")

    graph1k = build_sparse_graph(1000, 3000)
    {:ok, d_mem} = Pathfinding.shortest_path(in: graph1k, from: 0, to: 999)
    {:ok, b_mem} = Pathfinding.bidirectional(in: graph1k, from: 0, to: 999)

    d_size = :erts_debug.size(d_mem)
    b_size = :erts_debug.size(b_mem)

    IO.puts("\nSparse 1000 nodes:")
    IO.puts("  Dijkstra:      #{d_size} words (~#{format_bytes(d_size * 8)})")
    IO.puts("  Bidirectional: #{b_size} words (~#{format_bytes(b_size * 8)})")

    grid50 = build_grid_graph(50)

    heuristic50 = fn u, v ->
      {ux, uy} = {div(u, 50), rem(u, 50)}
      {vx, vy} = {div(v, 50), rem(v, 50)}
      abs(ux - vx) + abs(uy - vy)
    end

    {:ok, d_grid_mem} = Pathfinding.shortest_path(in: grid50, from: 0, to: 2499)
    {:ok, a_grid_mem} = Pathfinding.a_star(in: grid50, from: 0, to: 2499, heuristic: heuristic50)

    dg_size = :erts_debug.size(d_grid_mem)
    ag_size = :erts_debug.size(a_grid_mem)

    IO.puts("\n50×50 grid:")
    IO.puts("  Dijkstra: #{dg_size} words (~#{format_bytes(dg_size * 8)})")
    IO.puts("  A*:       #{ag_size} words (~#{format_bytes(ag_size * 8)})")

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("Summary:")
    IO.puts("- Dijkstra: Standard routing; explores uniformly in all directions.")

    IO.puts(
      "- Bidirectional: Meets in the middle; reduces search space from O(r^2) to O(2 * (r/2)^2)."
    )

    IO.puts("- A*: Directed exploration using heuristics; heavily outperforms Dijkstra on grids.")
    IO.puts("- Bellman-Ford: Slower but correctly handles negative weights (omitted for grids).")
  end

  defp run_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, graph, from, to} <- cases do
      IO.puts("  #{name} (Path: #{from} -> #{to})")

      node_count = map_size(graph.nodes)
      run_bellman_ford = node_count <= 1000

      d_avg = bench(fn -> Pathfinding.shortest_path(in: graph, from: from, to: to) end)
      b_avg = bench(fn -> Pathfinding.bidirectional(in: graph, from: from, to: to) end)

      results = [
        {"Dijkstra", d_avg},
        {"Bidirectional", b_avg}
      ]

      bf_avg =
        if run_bellman_ford do
          avg = bench(fn -> Pathfinding.bellman_ford(in: graph, from: from, to: to) end)
          [{"Bellman-Ford", avg} | results] |> Enum.reverse()
        else
          results
        end

      final_results =
        if is_list(bf_avg) and hd(bf_avg) |> elem(0) == "Bellman-Ford" do
          bf_avg
        else
          bf_avg
        end

      for {label, avg_ms} <- final_results do
        IO.puts("    #{String.pad_trailing(label <> ":", 16)} #{avg_ms}ms avg")
      end

      {fastest_label, _} = Enum.min_by(final_results, fn {_, t} -> t end)
      IO.puts("    → #{fastest_label} fastest")

      unless run_bellman_ford, do: IO.puts("    Bellman-Ford: Skipped (Network too large)")
      IO.puts("")
    end
  end

  defp run_grid_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, n} <- cases do
      graph = build_grid_graph(n)
      from = 0
      to = n * n - 1

      heuristic = fn u, v ->
        {ux, uy} = {div(u, n), rem(u, n)}
        {vx, vy} = {div(v, n), rem(v, n)}
        abs(ux - vx) + abs(uy - vy)
      end

      IO.puts("  #{name} (Path: #{from} -> #{to})")

      d_avg = bench(fn -> Pathfinding.shortest_path(in: graph, from: from, to: to) end)
      b_avg = bench(fn -> Pathfinding.bidirectional(in: graph, from: from, to: to) end)

      a_avg =
        bench(fn -> Pathfinding.a_star(in: graph, from: from, to: to, heuristic: heuristic) end)

      results = [
        {"Dijkstra", d_avg},
        {"Bidirectional", b_avg},
        {"A* (Manhattan)", a_avg}
      ]

      for {label, avg_ms} <- results do
        IO.puts("    #{String.pad_trailing(label <> ":", 16)} #{avg_ms}ms avg")
      end

      {fastest_label, _} = Enum.min_by(results, fn {_, t} -> t end)
      IO.puts("    → #{fastest_label} fastest")
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

  defp build_sparse_graph(n, m) when m > n do
    nodes = 0..(n - 1)
    g = Enum.reduce(nodes, Yog.directed(), &Yog.add_node(&2, &1, nil))

    # Random tree for connectivity guarantee from 0 to n-1
    g =
      Enum.reduce(1..(n - 1), g, fn i, acc ->
        parent = :rand.uniform(i) - 1
        Yog.add_edge_ensure(acc, parent, i, :rand.uniform(10) + 1)
      end)

    # Rest are random edges
    remaining = m - (n - 1)

    Enum.reduce(1..remaining, g, fn _, acc ->
      u = :rand.uniform(n) - 1
      v = :rand.uniform(n) - 1

      if u != v do
        Yog.add_edge_ensure(acc, u, v, :rand.uniform(10) + 1)
      else
        acc
      end
    end)
  end

  defp build_dense_graph(n) do
    nodes = 0..(n - 1)
    g = Enum.reduce(nodes, Yog.directed(), &Yog.add_node(&2, &1, nil))

    edges =
      for i <- 0..(n - 1),
          j <- 0..(n - 1),
          i != j,
          :rand.uniform(4) == 1,
          do: {i, j, :rand.uniform(10) + 1}

    Enum.reduce(edges, g, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end

  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.undirected(), fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = i * n + j
        acc = Yog.add_node(acc, node_id, nil)

        acc =
          if j < n - 1 do
            right_id = i * n + (j + 1)
            Yog.add_edge_ensure(acc, node_id, right_id, 1)
          else
            acc
          end

        acc =
          if i < n - 1 do
            down_id = (i + 1) * n + j
            Yog.add_edge_ensure(acc, node_id, down_id, 1)
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

PathfindingBenchmark.run()
