defmodule ComprehensiveBenchmark do
  @moduledoc """
  Comprehensive benchmark comparing Yog, libgraph, and :digraph as separate libraries.
  
  Similar to Gleam's benchmark style with statistical metrics (min, max, p99, IPS).
  """

  # Number of iterations for each benchmark
  @iterations 1000
  @warmup 100

  def run do
    IO.puts("\n╔════════════════════════════════════════════════════════════════════╗")
    IO.puts("║           COMPREHENSIVE GRAPH LIBRARY BENCHMARK                   ║")
    IO.puts("║           Yog vs libgraph vs Erlang :digraph                      ║")
    IO.puts("╚════════════════════════════════════════════════════════════════════╝\n")

    # Generate test graphs (separate for each library to avoid conversion overhead)
    IO.puts("Generating test graphs...")
    
    # Small graphs (100 nodes, ~150 edges)
    {yog_small, libgraph_small, digraph_small} = generate_graphs(100, 150)
    
    # Medium graphs (500 nodes, ~1000 edges)
    {yog_medium, libgraph_medium, digraph_medium} = generate_graphs(500, 1000)
    
    # Large graphs (1000 nodes, ~3000 edges)
    {yog_large, libgraph_large, digraph_large} = generate_graphs(1000, 3000)

    IO.puts("Done!\n")

    # Run benchmarks
    bench_topological_sort(yog_small, libgraph_small, digraph_small, yog_medium, libgraph_medium, digraph_medium)
    bench_connected_components(yog_small, libgraph_small, digraph_small, yog_medium, libgraph_medium, digraph_medium)
    bench_strongly_connected_components(yog_small, libgraph_small, digraph_small, yog_medium, libgraph_medium, digraph_medium)
    bench_shortest_path(yog_small, libgraph_small, digraph_small, yog_medium, libgraph_medium, digraph_medium)
    bench_graph_creation(100, 150, 500, 1000)
    bench_k_core(yog_small, libgraph_small, yog_medium, libgraph_medium)
    bench_mst(yog_small, libgraph_small, yog_medium, libgraph_medium)
    bench_memory_usage(yog_large, libgraph_large, digraph_large)

    # Cleanup
    :digraph.delete(digraph_small)
    :digraph.delete(digraph_medium)
    :digraph.delete(digraph_large)

    IO.puts("\n╔════════════════════════════════════════════════════════════════════╗")
    IO.puts("║                      BENCHMARK COMPLETE                           ║")
    IO.puts("╚════════════════════════════════════════════════════════════════════╝\n")
  end

  # =============================================================================
  # Topological Sort Benchmark
  # =============================================================================
  defp bench_topological_sort(yog_s, lib_s, dg_s, yog_m, lib_m, dg_m) do
    IO.puts("======================================================================")
    IO.puts("TOPOLOGICAL SORT")
    IO.puts("======================================================================")

    # Small graph
    IO.puts("\nSmall Graph (100 nodes, ~150 edges, DAG):")
    
    yog_stats = benchmark(fn -> Yog.Traversal.Sort.topological_sort(yog_s) end)
    lib_stats = benchmark(fn -> Graph.topsort(lib_s) end)
    dg_stats = benchmark(fn -> :digraph_utils.topsort(dg_s) end)
    
    print_comparison("Yog (Kahn)", yog_stats)
    print_comparison("libgraph (DFS)", lib_stats)
    print_comparison(":digraph (DFS)", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])

    # Medium graph
    IO.puts("\nMedium Graph (500 nodes, ~1000 edges, DAG):")
    
    yog_stats = benchmark(fn -> Yog.Traversal.Sort.topological_sort(yog_m) end)
    lib_stats = benchmark(fn -> Graph.topsort(lib_m) end)
    dg_stats = benchmark(fn -> :digraph_utils.topsort(dg_m) end)
    
    print_comparison("Yog (Kahn)", yog_stats)
    print_comparison("libgraph (DFS)", lib_stats)
    print_comparison(":digraph (DFS)", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])
  end

  # =============================================================================
  # Connected Components Benchmark
  # =============================================================================
  defp bench_connected_components(yog_s, lib_s, dg_s, yog_m, lib_m, dg_m) do
    IO.puts("\n======================================================================")
    IO.puts("CONNECTED COMPONENTS (Undirected)")
    IO.puts("======================================================================")

    # Convert to undirected for this benchmark
    yog_s_u = to_undirected_yog(yog_s)
    lib_s_u = to_undirected_libgraph(lib_s)
    dg_s_u = to_undirected_digraph(dg_s)
    
    yog_m_u = to_undirected_yog(yog_m)
    lib_m_u = to_undirected_libgraph(lib_m)
    dg_m_u = to_undirected_digraph(dg_m)

    IO.puts("\nSmall Graph (100 nodes, ~150 edges):")
    
    yog_stats = benchmark(fn -> Yog.Connectivity.Components.connected_components(yog_s_u) end)
    lib_stats = benchmark(fn -> Graph.components(lib_s_u) end)
    dg_stats = benchmark(fn -> :digraph_utils.strong_components(dg_s_u) end)
    
    print_comparison("Yog", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_comparison(":digraph", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])

    IO.puts("\nMedium Graph (500 nodes, ~1000 edges):")
    
    yog_stats = benchmark(fn -> Yog.Connectivity.Components.connected_components(yog_m_u) end)
    lib_stats = benchmark(fn -> Graph.components(lib_m_u) end)
    dg_stats = benchmark(fn -> :digraph_utils.strong_components(dg_m_u) end)
    
    print_comparison("Yog", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_comparison(":digraph", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])
  end

  # =============================================================================
  # Strongly Connected Components Benchmark
  # =============================================================================
  defp bench_strongly_connected_components(yog_s, lib_s, dg_s, yog_m, lib_m, dg_m) do
    IO.puts("\n======================================================================")
    IO.puts("STRONGLY CONNECTED COMPONENTS (Directed)")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (100 nodes, ~150 edges):")
    
    yog_stats = benchmark(fn -> Yog.Connectivity.SCC.strongly_connected_components(yog_s) end)
    lib_stats = benchmark(fn -> Graph.strong_components(lib_s) end)
    dg_stats = benchmark(fn -> :digraph_utils.strong_components(dg_s) end)
    
    print_comparison("Yog (Tarjan)", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_comparison(":digraph", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])

    IO.puts("\nMedium Graph (500 nodes, ~1000 edges):")
    
    yog_stats = benchmark(fn -> Yog.Connectivity.SCC.strongly_connected_components(yog_m) end)
    lib_stats = benchmark(fn -> Graph.strong_components(lib_m) end)
    dg_stats = benchmark(fn -> :digraph_utils.strong_components(dg_m) end)
    
    print_comparison("Yog (Tarjan)", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_comparison(":digraph", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])
  end

  # =============================================================================
  # Shortest Path Benchmark
  # =============================================================================
  defp bench_shortest_path(yog_s, lib_s, dg_s, yog_m, lib_m, dg_m) do
    IO.puts("\n======================================================================")
    IO.puts("SHORTEST PATH (50 random queries)")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (100 nodes, ~150 edges):")
    
    yog_stats = benchmark(fn -> 
      for i <- 1..50 do
        source = rem(i, 100) + 1
        target = rem(i * 7, 100) + 1
        Yog.Pathfinding.Dijkstra.shortest_path(in: yog_s, from: source, to: target)
      end
    end)
    
    lib_stats = benchmark(fn -> 
      for i <- 1..50 do
        source = rem(i, 100) + 1
        target = rem(i * 7, 100) + 1
        Graph.get_shortest_path(lib_s, source, target)
      end
    end)
    
    dg_stats = benchmark(fn -> 
      for i <- 1..50 do
        source = rem(i, 100) + 1
        target = rem(i * 7, 100) + 1
        :digraph.get_short_path(dg_s, source, target)
      end
    end)
    
    print_comparison("Yog (Dijkstra)", yog_stats)
    print_comparison("libgraph (BFS)", lib_stats)
    print_comparison(":digraph (BFS)", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])

    IO.puts("\nMedium Graph (500 nodes, ~1000 edges):")
    
    yog_stats = benchmark(fn -> 
      for i <- 1..50 do
        source = rem(i, 500) + 1
        target = rem(i * 7, 500) + 1
        Yog.Pathfinding.Dijkstra.shortest_path(in: yog_m, from: source, to: target)
      end
    end)
    
    lib_stats = benchmark(fn -> 
      for i <- 1..50 do
        source = rem(i, 500) + 1
        target = rem(i * 7, 500) + 1
        Graph.get_shortest_path(lib_m, source, target)
      end
    end)
    
    dg_stats = benchmark(fn -> 
      for i <- 1..50 do
        source = rem(i, 500) + 1
        target = rem(i * 7, 500) + 1
        :digraph.get_short_path(dg_m, source, target)
      end
    end)
    
    print_comparison("Yog (Dijkstra)", yog_stats)
    print_comparison("libgraph (BFS)", lib_stats)
    print_comparison(":digraph (BFS)", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])
  end

  # =============================================================================
  # Graph Creation Benchmark
  # =============================================================================
  defp bench_graph_creation(nodes_s, edges_s, nodes_m, edges_m) do
    IO.puts("\n======================================================================")
    IO.puts("GRAPH CREATION")
    IO.puts("======================================================================")

    IO.puts("\nSmall Graph (#{nodes_s} nodes, ~#{edges_s} edges):")
    
    yog_stats = benchmark(fn -> create_yog_graph(nodes_s, edges_s) end)
    lib_stats = benchmark(fn -> create_libgraph_graph(nodes_s, edges_s) end)
    dg_stats = benchmark(fn -> create_digraph_graph(nodes_s, edges_s) end)
    
    print_comparison("Yog", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_comparison(":digraph", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])

    IO.puts("\nMedium Graph (#{nodes_m} nodes, ~#{edges_m} edges):")
    
    yog_stats = benchmark(fn -> create_yog_graph(nodes_m, edges_m) end)
    lib_stats = benchmark(fn -> create_libgraph_graph(nodes_m, edges_m) end)
    dg_stats = benchmark(fn -> create_digraph_graph(nodes_m, edges_m) end)
    
    print_comparison("Yog", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_comparison(":digraph", dg_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}, {":digraph", dg_stats.avg}])
  end

  # =============================================================================
  # K-Core Benchmark (degeneracy)
  # =============================================================================
  defp bench_k_core(yog_s, lib_s, yog_m, lib_m) do
    IO.puts("\n======================================================================")
    IO.puts("K-CORE DEGENERACY")
    IO.puts("======================================================================")

    # Convert to undirected for k-core (k-core is typically for undirected graphs)
    yog_s_u = to_undirected_yog(yog_s)
    lib_s_u = to_undirected_libgraph(lib_s)
    yog_m_u = to_undirected_yog(yog_m)
    lib_m_u = to_undirected_libgraph(lib_m)

    IO.puts("\nSmall Graph (100 nodes, ~150 edges, undirected):")
    
    yog_stats = benchmark(fn -> Yog.Connectivity.KCore.degeneracy(yog_s_u) end)
    lib_stats = benchmark(fn -> Graph.degeneracy(lib_s_u) end)
    
    print_comparison("Yog (bucket-based)", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}])

    IO.puts("\nMedium Graph (500 nodes, ~1000 edges, undirected):")
    
    yog_stats = benchmark(fn -> Yog.Connectivity.KCore.degeneracy(yog_m_u) end)
    lib_stats = benchmark(fn -> Graph.degeneracy(lib_m_u) end)
    
    print_comparison("Yog (bucket-based)", yog_stats)
    print_comparison("libgraph", lib_stats)
    print_winner([{"Yog", yog_stats.avg}, {"libgraph", lib_stats.avg}])
  end

  # =============================================================================
  # MST Benchmark (Kruskal & Prim) - libgraph doesn't have built-in MST
  # =============================================================================
  defp bench_mst(_yog_s, _lib_s, _yog_m, _lib_m) do
    IO.puts("\n======================================================================")
    IO.puts("MINIMUM SPANNING TREE (Undirected)")
    IO.puts("======================================================================")

    # Create undirected weighted graphs for MST
    yog_s_u = create_yog_undirected_weighted(100, 150)
    yog_m_u = create_yog_undirected_weighted(500, 1000)

    IO.puts("\nSmall Graph (100 nodes, ~150 edges, undirected weighted):")
    
    IO.puts("  Kruskal's Algorithm:")
    yog_stats = benchmark(fn -> Yog.MST.kruskal(yog_s_u, &mst_compare/2) end)
    print_comparison("Yog (Kruskal)", yog_stats)
    IO.puts("  (Note: libgraph doesn't have built-in MST)")
    
    IO.puts("  Prim's Algorithm:")
    yog_stats = benchmark(fn -> Yog.MST.prim(yog_s_u, &mst_compare/2) end)
    print_comparison("Yog (Prim)", yog_stats)

    IO.puts("\nMedium Graph (500 nodes, ~1000 edges, undirected weighted):")
    
    IO.puts("  Kruskal's Algorithm:")
    yog_stats = benchmark(fn -> Yog.MST.kruskal(yog_m_u, &mst_compare/2) end)
    print_comparison("Yog (Kruskal)", yog_stats)
    
    IO.puts("  Prim's Algorithm:")
    yog_stats = benchmark(fn -> Yog.MST.prim(yog_m_u, &mst_compare/2) end)
    print_comparison("Yog (Prim)", yog_stats)
  end

  defp mst_compare(a, b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end

  defp create_yog_undirected_weighted(nodes, edges) do
    # Create Yog undirected graph with weights
    yog_graph = 
      1..nodes
      |> Enum.reduce(Yog.undirected(), fn i, g -> Yog.add_node(g, i, nil) end)

    added = :ets.new(:edges, [:set, :private])
    
    yog_graph =
      Enum.reduce(1..edges, yog_graph, fn i, g ->
        u = Enum.random(1..nodes)
        v = Enum.random(1..nodes)
        
        if u != v do
          # Normalize for undirected (store smaller first)
          key = if u < v, do: {u, v}, else: {v, u}
          
          if :ets.insert_new(added, {key, true}) do
            weight = rem(i, 100) + 1  # Random-ish weight 1-100
            case Yog.add_edge(g, u, v, weight) do
              {:ok, ng} -> ng
              {:error, _} -> g
            end
          else
            g
          end
        else
          g
        end
      end)
    
    :ets.delete(added)
    yog_graph
  end

  # =============================================================================
  # Memory Usage Benchmark
  # =============================================================================
  defp bench_memory_usage(yog, lib, dg) do
    IO.puts("\n======================================================================")
    IO.puts("MEMORY USAGE (Large Graph - 1000 nodes, ~3000 edges)")
    IO.puts("======================================================================")

    # Estimate memory using :erts_debug.size/1
    yog_size = :erts_debug.size(yog)
    lib_size = :erts_debug.size(lib)
    
    # :digraph uses ETS, so we use info
    dg_info = :digraph.info(dg)
    dg_memory = Keyword.get(dg_info, :memory, 0)

    IO.puts("\nMemory (in words, 1 word = 8 bytes on 64-bit):")
    IO.puts("  Yog:      #{format_number(yog_size)} words (#{format_bytes(yog_size * 8)})")
    IO.puts("  libgraph: #{format_number(lib_size)} words (#{format_bytes(lib_size * 8)})")
    IO.puts("  :digraph: #{format_number(dg_memory)} words (#{format_bytes(dg_memory * 8)})")
    
    # Find most memory efficient
    min_size = min(yog_size, min(lib_size, dg_memory))
    winner = 
      cond do
        yog_size == min_size -> "Yog"
        lib_size == min_size -> "libgraph"
        true -> ":digraph"
      end
    IO.puts("  Winner: #{winner}")
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
    
    IO.puts("  #{pad(name, 20)} avg: #{avg_str} | min: #{min_str} | max: #{max_str} | p99: #{p99_str} | #{ips_str} ops/s")
  end

  defp print_winner(results) do
    {winner, time} = Enum.min_by(results, fn {_, t} -> t end)
    IO.puts("  Winner: #{winner} (#{format_time(time)})")
  end

  # =============================================================================
  # Graph Generators
  # =============================================================================
  defp generate_graphs(nodes, edges) do
    yog = create_dag_yog(nodes, edges)
    lib = create_dag_libgraph(nodes, edges)
    dg = create_dag_digraph(nodes, edges)
    {yog, lib, dg}
  end

  defp create_dag_yog(nodes, edges) do
    graph = 
      1..nodes
      |> Enum.reduce(Yog.directed(), fn i, g -> Yog.add_node(g, i, nil) end)

    # Add edges (ensure DAG by only adding i -> j where i < j)
    added = :ets.new(:edges, [:set, :private])
    
    graph =
      Enum.reduce(1..edges, graph, fn _, g ->
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

  defp create_dag_libgraph(nodes, edges) do
    graph = 
      1..nodes
      |> Enum.reduce(Graph.new(type: :directed), fn i, g -> Graph.add_vertex(g, i) end)

    added = :ets.new(:edges, [:set, :private])
    
    graph =
      Enum.reduce(1..edges, graph, fn _, g ->
        u = Enum.random(1..nodes - 1)
        v = Enum.random((u + 1)..nodes)
        
        key = {u, v}
        if :ets.insert_new(added, {key, true}) do
          Graph.add_edge(g, u, v, weight: 1)
        else
          g
        end
      end)
    
    :ets.delete(added)
    graph
  end

  defp create_dag_digraph(nodes, edges) do
    dg = :digraph.new([:acyclic, :protected])
    
    Enum.each(1..nodes, fn i -> :digraph.add_vertex(dg, i) end)

    added = :ets.new(:edges, [:set, :private])
    
    Enum.each(1..edges, fn _ ->
      u = Enum.random(1..nodes - 1)
      v = Enum.random((u + 1)..nodes)
      
      key = {u, v}
      if :ets.insert_new(added, {key, true}) do
        :digraph.add_edge(dg, u, v)
      end
    end)
    
    :ets.delete(added)
    dg
  end

  defp create_yog_graph(nodes, edges) do
    graph = 
      1..nodes
      |> Enum.reduce(Yog.directed(), fn i, g -> Yog.add_node(g, i, nil) end)

    Enum.reduce(1..edges, graph, fn _, g ->
      u = Enum.random(1..nodes)
      v = Enum.random(1..nodes)
      if u != v do
        case Yog.add_edge(g, u, v, 1) do
          {:ok, ng} -> ng
          {:error, _} -> g
        end
      else
        g
      end
    end)
  end

  defp create_libgraph_graph(nodes, edges) do
    graph = 
      1..nodes
      |> Enum.reduce(Graph.new(type: :directed), fn i, g -> Graph.add_vertex(g, i) end)

    Enum.reduce(1..edges, graph, fn _, g ->
      u = Enum.random(1..nodes)
      v = Enum.random(1..nodes)
      if u != v do
        Graph.add_edge(g, u, v, weight: 1)
      else
        g
      end
    end)
  end

  defp create_digraph_graph(nodes, edges) do
    dg = :digraph.new([:protected])
    Enum.each(1..nodes, fn i -> :digraph.add_vertex(dg, i) end)

    Enum.each(1..edges, fn _ ->
      u = Enum.random(1..nodes)
      v = Enum.random(1..nodes)
      if u != v do
        :digraph.add_edge(dg, u, v)
      end
    end)
    
    dg
  end

  # =============================================================================
  # Utility Functions
  # =============================================================================
  defp to_undirected_yog(graph) do
    # For benchmarking, create a new undirected graph with same edges
    nodes = Yog.Model.all_nodes(graph)
    
    new_graph = 
      Enum.reduce(nodes, Yog.undirected(), fn n, g -> Yog.add_node(g, n, nil) end)
    
    Enum.reduce(Yog.Model.all_edges(graph), new_graph, fn {u, v, w}, g ->
      case Yog.add_edge(g, u, v, w) do
        {:ok, ng} -> ng
        {:error, _} -> g
      end
    end)
  end

  defp to_undirected_libgraph(graph) do
    # Convert to undirected by creating new graph
    vertices = Graph.vertices(graph)
    
    new_graph = Graph.new(type: :undirected)
    new_graph = Enum.reduce(vertices, new_graph, fn v, g -> Graph.add_vertex(g, v) end)
    
    Enum.reduce(Graph.edges(graph), new_graph, fn edge, g ->
      Graph.add_edge(g, edge.v1, edge.v2, weight: edge.weight)
    end)
  end

  defp to_undirected_digraph(dg) do
    # Create new digraph with bidirectional edges
    new_dg = :digraph.new([:protected])
    
    vertices = :digraph.vertices(dg)
    Enum.each(vertices, fn v -> :digraph.add_vertex(new_dg, v) end)
    
    edges = :digraph.edges(dg)
    Enum.each(edges, fn e ->
      {_, u, v, _} = :digraph.edge(dg, e)
      :digraph.add_edge(new_dg, u, v)
      :digraph.add_edge(new_dg, v, u)
    end)
    
    new_dg
  end

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
ComprehensiveBenchmark.run()
