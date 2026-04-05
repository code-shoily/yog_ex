defmodule FunctionalComparisonBenchmark do
  @moduledoc """
  Benchmark comparing Yog.Functional (FGL) with Yog proper.
  
  This benchmark demonstrates the performance trade-offs between:
  - Yog proper: Adjacency-list representation with mutable operations
  - Yog.Functional: Inductive graph representation (FGL) with pure functional decomposition
  
  FGL excels at:
  - Teaching and correctness proofs
  - Recursive algorithm elegance
  - Functional transformations
  
  Yog proper excels at:
  - Raw performance
  - Large-scale graphs
  - Production workloads
  """

  # Number of iterations for each benchmark
  @iterations 100
  @warmup 20

  alias Yog.Functional.Model, as: FModel
  alias Yog.Functional.Algorithms, as: FAlgo

  def run do
    IO.puts("\n╔════════════════════════════════════════════════════════════════════╗")
    IO.puts("║     YOG.PROPER vs YOG.FUNCTIONAL (FGL) BENCHMARK                  ║")
    IO.puts("║     Adjacency List vs Inductive Graph Representation              ║")
    IO.puts("╚════════════════════════════════════════════════════════════════════╝\n")

    # Generate test graphs
    IO.puts("Generating test graphs...")
    
    # Small graphs (50 nodes, ~75 edges)
    {yog_small, fgl_small} = generate_graphs(50, 75)
    
    # Medium graphs (100 nodes, ~150 edges)
    {yog_medium, fgl_medium} = generate_graphs(100, 150)
    
    # Large graphs (200 nodes, ~400 edges) - FGL gets slow here
    {yog_large, fgl_large} = generate_graphs(200, 400)

    IO.puts("Done!\n")

    # Run benchmarks
    bench_graph_creation(50, 100, 200)
    bench_conversion(50, 100, 200)
    bench_topological_sort(yog_small, fgl_small, yog_medium, fgl_medium, yog_large, fgl_large)
    bench_dfs(yog_small, fgl_small, yog_medium, fgl_medium)
    bench_dijkstra(yog_small, fgl_small, yog_medium, fgl_medium, yog_large, fgl_large)
    bench_node_iteration(yog_small, fgl_small, yog_medium, fgl_medium, yog_large, fgl_large)
    bench_memory_usage(yog_large, fgl_large)

    IO.puts("\n╔════════════════════════════════════════════════════════════════════╗")
    IO.puts("║                    BENCHMARK COMPLETE                             ║")
    IO.puts("╚════════════════════════════════════════════════════════════════════╝\n")
  end

  # =============================================================================
  # Graph Creation Benchmark
  # =============================================================================
  defp bench_graph_creation(n1, n2, n3) do
    IO.puts("======================================================================")
    IO.puts("GRAPH CREATION (Building from scratch)")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (#{n1} nodes):")
    
    yog_stats = benchmark(fn -> create_yog_dag(n1, div(n1 * 3, 2)) end)
    fgl_stats = benchmark(fn -> create_fgl_dag(n1, div(n1 * 3, 2)) end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nMedium Graph (#{n2} nodes):")
    
    yog_stats = benchmark(fn -> create_yog_dag(n2, div(n2 * 3, 2)) end)
    fgl_stats = benchmark(fn -> create_fgl_dag(n2, div(n2 * 3, 2)) end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nLarge Graph (#{n3} nodes):")
    
    yog_stats = benchmark(fn -> create_yog_dag(n3, div(n3 * 3, 2)) end)
    fgl_stats = benchmark(fn -> create_fgl_dag(n3, div(n3 * 3, 2)) end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)
  end

  # =============================================================================
  # Conversion Benchmark
  # =============================================================================
  defp bench_conversion(n1, n2, n3) do
    IO.puts("\n======================================================================")
    IO.puts("GRAPH CONVERSION (Yog ↔ FGL)")
    IO.puts("======================================================================")

    yog_small = create_yog_dag(n1, div(n1 * 3, 2))
    yog_medium = create_yog_dag(n2, div(n2 * 3, 2))
    yog_large = create_yog_dag(n3, div(n3 * 3, 2))

    IO.puts("\nSmall Graph (#{n1} nodes):")
    
    to_fgl_stats = benchmark(fn -> FModel.from_adjacency_graph(yog_small) end)
    from_fgl_stats = benchmark(fn -> 
      fgl = FModel.from_adjacency_graph(yog_small)
      FModel.to_adjacency_graph(fgl)
    end)
    
    print_comparison("Yog → FGL", to_fgl_stats)
    print_comparison("Yog → FGL → Yog", from_fgl_stats)

    IO.puts("\nMedium Graph (#{n2} nodes):")
    
    to_fgl_stats = benchmark(fn -> FModel.from_adjacency_graph(yog_medium) end)
    from_fgl_stats = benchmark(fn -> 
      fgl = FModel.from_adjacency_graph(yog_medium)
      FModel.to_adjacency_graph(fgl)
    end)
    
    print_comparison("Yog → FGL", to_fgl_stats)
    print_comparison("Yog → FGL → Yog", from_fgl_stats)

    IO.puts("\nLarge Graph (#{n3} nodes):")
    
    to_fgl_stats = benchmark(fn -> FModel.from_adjacency_graph(yog_large) end)
    from_fgl_stats = benchmark(fn -> 
      fgl = FModel.from_adjacency_graph(yog_large)
      FModel.to_adjacency_graph(fgl)
    end)
    
    print_comparison("Yog → FGL", to_fgl_stats)
    print_comparison("Yog → FGL → Yog", from_fgl_stats)
  end

  # =============================================================================
  # Topological Sort Benchmark
  # =============================================================================
  defp bench_topological_sort(yog_s, fgl_s, yog_m, fgl_m, yog_l, fgl_l) do
    IO.puts("\n======================================================================")
    IO.puts("TOPOLOGICAL SORT (Kahn's algorithm)")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (50 nodes):")
    
    yog_stats = benchmark(fn -> Yog.Traversal.Sort.topological_sort(yog_s) end)
    fgl_stats = benchmark(fn -> FAlgo.topsort(fgl_s) end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nMedium Graph (100 nodes):")
    
    yog_stats = benchmark(fn -> Yog.Traversal.Sort.topological_sort(yog_m) end)
    fgl_stats = benchmark(fn -> FAlgo.topsort(fgl_m) end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nLarge Graph (200 nodes):")
    
    yog_stats = benchmark(fn -> Yog.Traversal.Sort.topological_sort(yog_l) end)
    fgl_stats = benchmark(fn -> FAlgo.topsort(fgl_l) end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)
  end

  # =============================================================================
  # DFS Traversal Benchmark
  # =============================================================================
  defp bench_dfs(yog_s, fgl_s, yog_m, fgl_m) do
    IO.puts("\n======================================================================")
    IO.puts("DEPTH-FIRST SEARCH (Full graph traversal)")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (50 nodes):")
    
    yog_stats = benchmark(fn -> 
      Yog.Traversal.Walk.walk(in: yog_s, from: 1, using: :depth_first)
    end)
    fgl_stats = benchmark(fn -> 
      Yog.Functional.Traversal.dfs(fgl_s, 1)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nMedium Graph (100 nodes):")
    
    yog_stats = benchmark(fn -> 
      Yog.Traversal.Walk.walk(in: yog_m, from: 1, using: :depth_first)
    end)
    fgl_stats = benchmark(fn -> 
      Yog.Functional.Traversal.dfs(fgl_m, 1)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)
  end

  # =============================================================================
  # Dijkstra Shortest Path Benchmark
  # =============================================================================
  defp bench_dijkstra(yog_s, fgl_s, yog_m, fgl_m, yog_l, fgl_l) do
    IO.puts("\n======================================================================")
    IO.puts("SHORTEST PATH (Dijkstra's Algorithm)")
    IO.puts("======================================================================")

    # Find source/target nodes for each graph
    source_s = 1
    target_s = 25
    source_m = 1
    target_m = 50
    source_l = 1
    target_l = 100

    IO.puts("\nSmall Graph (50 nodes, path #{source_s}→#{target_s}):")
    
    yog_stats = benchmark(fn -> 
      Yog.Pathfinding.Dijkstra.shortest_path(in: yog_s, from: source_s, to: target_s)
    end)
    fgl_stats = benchmark(fn -> 
      FAlgo.shortest_path(fgl_s, source_s, target_s)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nMedium Graph (100 nodes, path #{source_m}→#{target_m}):")
    
    yog_stats = benchmark(fn -> 
      Yog.Pathfinding.Dijkstra.shortest_path(in: yog_m, from: source_m, to: target_m)
    end)
    fgl_stats = benchmark(fn -> 
      FAlgo.shortest_path(fgl_m, source_m, target_m)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nLarge Graph (200 nodes, path #{source_l}→#{target_l}):")
    
    yog_stats = benchmark(fn -> 
      Yog.Pathfinding.Dijkstra.shortest_path(in: yog_l, from: source_l, to: target_l)
    end)
    fgl_stats = benchmark(fn -> 
      FAlgo.shortest_path(fgl_l, source_l, target_l)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)
  end

  # =============================================================================
  # Node Iteration Benchmark
  # =============================================================================
  defp bench_node_iteration(yog_s, fgl_s, yog_m, fgl_m, yog_l, fgl_l) do
    IO.puts("\n======================================================================")
    IO.puts("NODE ITERATION (Visiting all nodes)")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (50 nodes):")
    
    yog_stats = benchmark(fn -> 
      Yog.Model.all_nodes(yog_s) |> Enum.map(fn n -> n * 2 end)
    end)
    fgl_stats = benchmark(fn -> 
      FModel.nodes(fgl_s) |> Enum.map(fn ctx -> ctx.id * 2 end)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nMedium Graph (100 nodes):")
    
    yog_stats = benchmark(fn -> 
      Yog.Model.all_nodes(yog_m) |> Enum.map(fn n -> n * 2 end)
    end)
    fgl_stats = benchmark(fn -> 
      FModel.nodes(fgl_m) |> Enum.map(fn ctx -> ctx.id * 2 end)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)

    IO.puts("\nLarge Graph (200 nodes):")
    
    yog_stats = benchmark(fn -> 
      Yog.Model.all_nodes(yog_l) |> Enum.map(fn n -> n * 2 end)
    end)
    fgl_stats = benchmark(fn -> 
      FModel.nodes(fgl_l) |> Enum.map(fn ctx -> ctx.id * 2 end)
    end)
    
    print_comparison("Yog (adjacency)", yog_stats)
    print_comparison("FGL (inductive)", fgl_stats)
    print_speedup(yog_stats.avg, fgl_stats.avg)
  end

  # =============================================================================
  # Memory Usage Benchmark
  # =============================================================================
  defp bench_memory_usage(yog, fgl) do
    IO.puts("\n======================================================================")
    IO.puts("MEMORY USAGE (Large Graph - 200 nodes, ~400 edges)")
    IO.puts("======================================================================")

    # Estimate memory using :erts_debug.size/1
    yog_size = :erts_debug.size(yog)
    fgl_size = :erts_debug.size(fgl)

    IO.puts("\nMemory (in words, 1 word = 8 bytes on 64-bit):")
    IO.puts("  Yog (adjacency): #{format_number(yog_size)} words (#{format_bytes(yog_size * 8)})")
    IO.puts("  FGL (inductive): #{format_number(fgl_size)} words (#{format_bytes(fgl_size * 8)})")
    
    ratio = fgl_size / max(yog_size, 1)
    IO.puts("  FGL/Yog ratio: #{Float.round(ratio, 2)}x")
    
    winner = if yog_size < fgl_size, do: "Yog", else: "FGL"
    IO.puts("  Winner: #{winner}")
  end

  # =============================================================================
  # Graph Generators
  # =============================================================================
  defp generate_graphs(nodes, edges) do
    yog = create_yog_dag(nodes, edges)
    fgl = FModel.from_adjacency_graph(yog)
    {yog, fgl}
  end

  defp create_yog_dag(nodes, edges) do
    graph = Yog.directed()
    
    # Add nodes
    graph = Enum.reduce(1..nodes, graph, fn i, g ->
      Yog.add_node(g, i, "node_#{i}")
    end)

    # Add edges (ensure DAG by only connecting lower to higher IDs)
    added = :ets.new(:edges, [:set, :private])
    
    graph = Enum.reduce(1..edges, graph, fn _, g ->
      u = Enum.random(1..nodes - 1)
      v = Enum.random((u + 1)..nodes)
      
      key = {u, v}
      if :ets.insert_new(added, {key, true}) do
        case Yog.add_edge(g, u, v, 1) do
          {:ok, ng} -> ng
          {:error, _} -> g
        end
      else
        g
      end
    end)
    
    :ets.delete(added)
    graph
  end

  defp create_fgl_dag(nodes, edges) do
    graph = FModel.empty()
    
    # Add nodes
    graph = Enum.reduce(1..nodes, graph, fn i, g ->
      FModel.put_node(g, i, "node_#{i}")
    end)

    # Add edges (ensure DAG by only connecting lower to higher IDs)
    added = :ets.new(:edges, [:set, :private])
    
    graph = Enum.reduce(1..edges, graph, fn _, g ->
      u = Enum.random(1..nodes - 1)
      v = Enum.random((u + 1)..nodes)
      
      key = {u, v}
      if :ets.insert_new(added, {key, true}) do
        FModel.add_edge!(g, u, v)
      else
        g
      end
    end)
    
    :ets.delete(added)
    graph
  end

  # =============================================================================
  # Benchmark Helper
  # =============================================================================
  defp benchmark(fun) do
    # Warmup
    for _ <- 1..@warmup do
      fun.()
    end

    # Actual benchmark
    times = 
      for _ <- 1..@iterations do
        {time, _} = :timer.tc(fun)
        time
      end

    avg = Enum.sum(times) / length(times)
    min = Enum.min(times)
    max = Enum.max(times)
    p99 = Enum.sort(times) |> Enum.at(trunc(@iterations * 0.99) - 1)
    ips = 1_000_000 / avg

    %{avg: avg, min: min, max: max, p99: p99, ips: ips}
  end

  defp print_comparison(name, stats) do
    avg_str = format_time(stats.avg)
    min_str = format_time(stats.min)
    max_str = format_time(stats.max)
    p99_str = format_time(stats.p99)
    ips_str = format_number(round(stats.ips))
    
    IO.puts("  #{pad(name, 18)} avg: #{avg_str} | min: #{min_str} | max: #{max_str} | p99: #{p99_str} | #{ips_str} ops/s")
  end

  defp print_speedup(yog_time, fgl_time) do
    speedup = fgl_time / max(yog_time, 1)
    IO.puts("  Speedup: Yog is #{Float.round(speedup, 1)}x faster than FGL")
  end

  # =============================================================================
  # Utility Functions
  # =============================================================================
  defp format_time(microseconds) when microseconds < 1000, do: "#{round(microseconds)}μs"
  defp format_time(microseconds) when microseconds < 1_000_000, do: "#{Float.round(microseconds / 1000, 2)}ms"
  defp format_time(microseconds), do: "#{Float.round(microseconds / 1_000_000, 2)}s"

  defp format_number(n) when n < 1000, do: to_string(n)
  defp format_number(n) when n < 1_000_000, do: "#{div(n, 1000)}k"
  defp format_number(n), do: "#{div(n, 1_000_000)}M"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"

  defp pad(str, len) do
    String.pad_trailing(str, len)
  end
end

# Run the benchmark
FunctionalComparisonBenchmark.run()
