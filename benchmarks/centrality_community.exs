defmodule CentralityCommunityBenchmark do
  @moduledoc """
  Benchmark for Yog's analytical algorithms (Centrality, Community Detection).
  
  Since most Elixir libraries lack these, this benchmark focuses on Yog's 
  performance at different scales and compares different algorithmic approaches.
  """

  # Number of iterations for each benchmark (lowered for heavy analytics)
  @iterations 5
  @warmup 2

  def run do
    IO.puts("\n╔════════════════════════════════════════════════════════════════════╗")
    IO.puts("║             YOG ANALYTICS & COMMUNITY BENCHMARK                   ║")
    IO.puts("║           Centrality measures and Clustering algorithms           ║")
    IO.puts("╚════════════════════════════════════════════════════════════════════╝\n")

    # Generate realistic graphs for community detection
    # Stochastic Block Model (SBM) is perfect for this:
    # 5 communities of 100 nodes each (500 nodes total)
    IO.puts("Generating test graphs...")
    
    # Small Analytical Graph (500 nodes, 2500 edges, clear community structure)
    sbm_small = generate_sbm(5, 100, 0.1, 0.01)
    
    # Medium Analytical Graph (1,000 nodes, 5,000 edges)
    sbm_medium = generate_sbm(5, 200, 0.05, 0.005)
    
    IO.puts("Done!\n")

    bench_centrality(sbm_small, sbm_medium)
    bench_community_detection(sbm_small, sbm_medium)

    IO.puts("\n╔════════════════════════════════════════════════════════════════════╗")
    IO.puts("║                      BENCHMARK COMPLETE                           ║")
    IO.puts("╚════════════════════════════════════════════════════════════════════╝\n")
  end

  # =============================================================================
  # Centrality Measures Benchmark
  # =============================================================================
  defp bench_centrality(graph_s, graph_m) do
    IO.puts("======================================================================")
    IO.puts("STRESS-TESTING CENTRALITY MEASURES")
    IO.puts("======================================================================")

    # Degree Centrality (O(V))
    IO.puts("\nDegree Centrality (2,000 nodes):")
    stats = benchmark(fn -> Yog.Centrality.degree(graph_m) end)
    print_comparison("Yog (Degree)", stats)

    # PageRank (Iterative O(k * (V+E)))
    IO.puts("\nPageRank (10 iterations):")
    stats_s = benchmark(fn -> Yog.Centrality.pagerank(graph_s, max_iterations: 10) end)
    stats_m = benchmark(fn -> Yog.Centrality.pagerank(graph_m, max_iterations: 10) end)
    print_comparison("Small (500 node SBM)", stats_s)
    print_comparison("Medium (2000 node SBM)", stats_m)

    # Closeness Centrality (O(V * (V+E log V)) - heavy)
    IO.puts("\nCloseness Centrality (Small SBM):")
    stats = benchmark(fn -> Yog.Centrality.closeness(graph_s) end)
    print_comparison("Yog (Closeness)", stats)
  end

  # =============================================================================
  # Community Detection Benchmark
  # =============================================================================
  defp bench_community_detection(graph_s, graph_m) do
    IO.puts("\n======================================================================")
    IO.puts("COMMUNITY DETECTION PERFORMANCE (Louvain vs Leiden vs Label Prop)")
    IO.puts("======================================================================")

    IO.puts("\nSmall SBM Graph (500 nodes):")
    
    # Label Propagation (Fastest O(E))
    lp_stats = benchmark(fn -> Yog.Community.LabelPropagation.detect(graph_s) end)
    print_comparison("Label Propagation", lp_stats)
    
    # Leiden (refined Louvain)
    leiden_stats = benchmark(fn -> Yog.Community.Leiden.detect(graph_s) end)
    print_comparison("Leiden Detection", leiden_stats)

    # Louvain (modularity optimization)
    louvain_stats = benchmark(fn -> Yog.Community.Louvain.detect(graph_s) end)
    print_comparison("Louvain Detection", louvain_stats)

    IO.puts("\nMedium SBM Graph (2,000 nodes):")
    
    lp_stats = benchmark(fn -> Yog.Community.LabelPropagation.detect(graph_m) end)
    print_comparison("Label Propagation", lp_stats)
    
    louvain_stats = benchmark(fn -> Yog.Community.Louvain.detect(graph_m) end, iterations: 1, warmup: 0)
    print_comparison("Louvain Detection", louvain_stats)
    
    leiden_stats = benchmark(fn -> Yog.Community.Leiden.detect(graph_m) end)
    print_comparison("Leiden Detection", leiden_stats)
  end

  # =============================================================================
  # Benchmark Helpers
  # =============================================================================
  defp generate_sbm(communities, nodes_per_comm, p_in, p_out) do
    # Using Yog's SBM generator (n, k, p_in, p_out)
    total_nodes = communities * nodes_per_comm
    Yog.Generator.Random.sbm(total_nodes, communities, p_in, p_out)
  end

  defp benchmark(fun, opts \\ []) do
    iterations = opts[:iterations] || @iterations
    warmup = opts[:warmup] || @warmup

    # Warmup (only if > 0)
    if warmup > 0 do
      for _ <- 1..warmup, do: fun.()
    end

    # Actual benchmark (only if > 0)
    times = 
      if iterations > 0 do
        for _ <- 1..iterations do
          {time, _} = :timer.tc(fun)
          time
        end
      else
        []
      end

    if times == [] do
      %{avg: 0, min: 0, max: 0, p99: 0, ips: 0}
    else
      avg = Enum.sum(times) / length(times)
      min = Enum.min(times)
      max = Enum.max(times)
      p99 = Enum.sort(times) |> Enum.at(max(0, trunc(iterations * 0.99) - 1))
      ips = 1_000_000 / avg

      %{avg: avg, min: min, max: max, p99: p99, ips: ips}
    end
  end

  defp print_comparison(name, stats) do
    avg_str = format_time(stats.avg)
    min_str = format_time(stats.min)
    max_str = format_time(stats.max)
    p99_str = format_time(stats.p99)
    ips_str = format_number(round(stats.ips))
    
    IO.puts("  #{pad(name, 25)} avg: #{avg_str} | min: #{min_str} | max: #{max_str} | p99: #{p99_str} | #{ips_str} ops/s")
  end

  defp format_time(microseconds) when microseconds < 1000, do: "#{round(microseconds)}μs"
  defp format_time(microseconds) when microseconds < 1_000_000, do: "#{Float.round(microseconds / 1000, 2)}ms"
  defp format_time(microseconds), do: "#{Float.round(microseconds / 1_000_000, 2)}s"

  defp format_number(n) when n < 1000, do: to_string(n)
  defp format_number(n) when n < 1_000_000, do: "#{div(n, 1000)}k"
  defp format_number(n), do: "#{div(n, 1_000_000)}M"

  defp pad(str, len), do: String.pad_trailing(str, len)
end

# Run the benchmark
CentralityCommunityBenchmark.run()
