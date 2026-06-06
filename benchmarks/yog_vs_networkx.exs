#!/usr/bin/env elixir

defmodule YogVsNetworkX do
  @moduledoc """
  Performance comparison benchmark between YogEx (Elixir), Zog (Native Zig NIFs),
  and NetworkX (Python) running PageRank, Louvain, and Floyd-Warshall.
  """

  def run do
    # Default parameters
    args = System.argv()
    n = if length(args) > 0, do: String.to_integer(Enum.at(args, 0)), else: 5000
    m = if length(args) > 1, do: String.to_integer(Enum.at(args, 1)), else: 3
    n_small = if length(args) > 2, do: String.to_integer(Enum.at(args, 2)), else: 200
    seed = if length(args) > 3, do: String.to_integer(Enum.at(args, 3)), else: 42

    IO.puts("==================================================================================")
    IO.puts(" PERFORMANCE RUN: YOG_EX (ELIXIR) VS. ZOG (ZIG NATIVE) VS. NETWORKX (PYTHON)")
    IO.puts("==================================================================================")
    IO.puts("Large Graph: Barabási-Albert (N = #{n}, E = ~#{n * m}) [PageRank, Louvain]")
    IO.puts("Small Dense Graph: Erdős-Rényi Directed (N = #{n_small}, p = 0.4) [Floyd-Warshall]")
    IO.puts("Seed: #{seed}")
    IO.puts("----------------------------------------------------------------------------------")
    IO.puts("Generating and running tests. Please wait...\n")

    # --- 1. Generate Large Graph ---
    large_graph = Yog.Generator.Random.barabasi_albert(n, m, seed)
    large_graph = Yog.Transform.map_edges(large_graph, fn _ -> 1.0 end)

    # Compile large graph to Zog builder & resource
    zog_builder_large = Yog.Builder.Zog.from_graph(large_graph)
    zog_large = Yog.Zog.ResourceGraph.new(zog_builder_large)

    # --- 2. Generate Small Graph ---
    small_graph = Yog.Generator.Random.erdos_renyi_gnp_with_type(n_small, 0.4, :directed, seed)
    small_graph = Yog.Transform.map_edges(small_graph, fn _ -> 1.0 end)

    # Compile small graph to Zog builder & resource
    zog_builder_small = Yog.Builder.Zog.from_graph(small_graph)
    zog_small = Yog.Zog.ResourceGraph.new(zog_builder_small)

    # --- PAGE RANK BENCHMARK ---
    {elixir_pr, _} =
      bench(fn ->
        Yog.Centrality.pagerank(large_graph, max_iterations: 20, tolerance: 1.0e-6)
      end)

    {zog_pr, _} =
      bench(fn ->
        Yog.Zog.ResourceGraph.pagerank(zog_large, max_iterations: 20, tolerance: 1.0e-6)
      end)

    # --- LOUVAIN BENCHMARK ---
    {elixir_louvain, _} =
      bench(fn ->
        Yog.Community.Louvain.detect(large_graph)
      end)

    {zog_louvain, _} =
      bench(fn ->
        Yog.Zog.ResourceGraph.louvain(zog_large)
      end)

    # --- DIJKSTRA BENCHMARK ---
    {elixir_dijkstra, _} =
      bench(fn ->
        Yog.Pathfinding.Dijkstra.shortest_path(large_graph, 0, n - 1)
      end)

    {zog_dijkstra, _} =
      bench(fn ->
        Yog.Zog.ResourceGraph.dijkstra(zog_large, 0, n - 1)
      end)

    # --- FLOYD-WARSHALL BENCHMARK ---
    {elixir_floyd, _} =
      bench(fn ->
        Yog.Pathfinding.FloydWarshall.floyd_warshall(small_graph)
      end)

    {zog_floyd, _} =
      bench(fn ->
        Yog.Zog.ResourceGraph.floyd_warshall(zog_small)
      end)

    # Cleanup Zog resources
    Yog.Zog.ResourceGraph.destroy(zog_large)
    Yog.Zog.ResourceGraph.destroy(zog_small)

    # --- Python NetworkX benchmark ---
    py_script = Path.join("benchmarks", "yog_vs_networkx.py")

    has_python = System.find_executable("python3") != nil

    py_metrics =
      if has_python do
        case System.cmd(
               "python3",
               [
                 py_script,
                 to_string(n),
                 to_string(m),
                 to_string(n_small),
                 to_string(seed)
               ],
               stderr_to_stdout: true
             ) do
          {py_output, 0} ->
            parse_python_output(py_output)

          {_error_msg, _status} ->
            nil
        end
      else
        nil
      end

    # --- Print Comparison Table ---
    IO.puts(String.duplicate("-", 100))

    if py_metrics do
      printf(
        "Algorithm",
        "YogEx (Elixir)",
        "Zog (Zig Native)",
        "NetworkX (Python)",
        "Zog vs. NetworkX Speedup"
      )

      IO.puts(String.duplicate("-", 100))

      print_row("PageRank", elixir_pr, zog_pr, py_metrics[:pagerank_time])
      print_row("Louvain", elixir_louvain, zog_louvain, py_metrics[:louvain_time])
      print_row("Dijkstra", elixir_dijkstra, zog_dijkstra, py_metrics[:dijkstra_time])
      print_row("Floyd-Warshall", elixir_floyd, zog_floyd, py_metrics[:floyd_time])
      IO.puts(String.duplicate("-", 100))

      IO.puts(
        "Note: Speedup = NetworkX time / Zog Native time. Speedup > 1.0 means Zog is faster."
      )
    else
      printf(
        "Algorithm",
        "YogEx (Elixir)",
        "Zog (Zig Native)",
        "NetworkX (Python)",
        "YogEx vs. Zog Speedup"
      )

      IO.puts(String.duplicate("-", 100))
      print_row_no_py("PageRank", elixir_pr, zog_pr)
      print_row_no_py("Louvain", elixir_louvain, zog_louvain)
      print_row_no_py("Dijkstra", elixir_dijkstra, zog_dijkstra)
      print_row_no_py("Floyd-Warshall", elixir_floyd, zog_floyd)
      IO.puts(String.duplicate("-", 100))

      IO.puts(
        "Note: Python NetworkX was not found or failed. Showing YogEx vs. Zog native comparison."
      )
    end
  end

  defp bench(fun) do
    # Run 3 iterations and take the minimum time for stability
    times =
      for _ <- 1..3 do
        t0 = System.monotonic_time(:microsecond)
        res = fun.()
        t1 = System.monotonic_time(:microsecond)
        {(t1 - t0) / 1000.0, res}
      end

    Enum.min_by(times, fn {t, _} -> t end)
  end

  defp parse_python_output(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [key, val] = String.split(line, ":")
      {String.to_atom(key), String.to_float(val)}
    end)
    |> Map.new()
  end

  defp printf(alg, yog, zog, nx, speedup) do
    IO.puts(
      String.pad_trailing(alg, 20) <>
        String.pad_leading(yog, 18) <>
        String.pad_leading(zog, 20) <>
        String.pad_leading(nx, 22) <>
        String.pad_leading(speedup, 20)
    )
  end

  defp print_row(alg, elixir_val, zog_val, nx_val) do
    elixir_str = :erlang.float_to_binary(elixir_val, decimals: 2) <> " ms"
    zog_str = :erlang.float_to_binary(zog_val, decimals: 2) <> " ms"
    nx_str = :erlang.float_to_binary(nx_val, decimals: 2) <> " ms"
    ratio = nx_val / zog_val
    ratio_str = :erlang.float_to_binary(ratio, decimals: 2) <> "x"

    printf(alg, elixir_str, zog_str, nx_str, ratio_str)
  end

  defp print_row_no_py(alg, elixir_val, zog_val) do
    elixir_str = :erlang.float_to_binary(elixir_val, decimals: 2) <> " ms"
    zog_str = :erlang.float_to_binary(zog_val, decimals: 2) <> " ms"
    ratio = elixir_val / zog_val
    ratio_str = :erlang.float_to_binary(ratio, decimals: 2) <> "x"

    printf(alg, elixir_str, zog_str, "N/A", ratio_str)
  end
end

YogVsNetworkX.run()
