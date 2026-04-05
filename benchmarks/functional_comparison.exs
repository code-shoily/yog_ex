#!/usr/bin/env elixir

defmodule FunctionalComparisonBenchmark do
  @moduledoc """
  Benchmark comparing Yog.Functional (FGL) with Yog proper using Benchee.

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

  alias Yog.Functional.Model, as: FModel
  alias Yog.Functional.Algorithms, as: FAlgo

  def run do
    IO.puts("Generating test graphs...")

    # Small graphs (50 nodes, ~75 edges)
    {yog_small, fgl_small} = generate_graphs(50, 75)

    # Medium graphs (100 nodes, ~150 edges)
    {yog_medium, fgl_medium} = generate_graphs(100, 150)

    # Large graphs (200 nodes, ~400 edges) - FGL gets slow here
    {yog_large, fgl_large} = generate_graphs(200, 400)

    IO.puts("Done!\n")

    # Graph Creation Benchmark
    IO.puts("== Graph Creation ==")

    Benchee.run(
      %{
        "Yog (adjacency)" => fn n -> create_yog_dag(n, div(n * 3, 2)) end,
        "FGL (inductive)" => fn n -> create_fgl_dag(n, div(n * 3, 2)) end
      },
      inputs: %{
        "Small (50 nodes)" => 50,
        "Medium (100 nodes)" => 100,
        "Large (200 nodes)" => 200
      },
      time: 2,
      warmup: 1
    )

    # Conversion Benchmark
    IO.puts("\n== Graph Conversion (Yog ↔ FGL) ==")

    Benchee.run(
      %{
        "Yog → FGL" => fn g -> FModel.from_adjacency_graph(g) end,
        "Yog → FGL → Yog" => fn g ->
          fgl = FModel.from_adjacency_graph(g)
          FModel.to_adjacency_graph(fgl)
        end
      },
      inputs: %{
        "Small (50 nodes)" => yog_small,
        "Medium (100 nodes)" => yog_medium,
        "Large (200 nodes)" => yog_large
      },
      time: 2,
      warmup: 1
    )

    # Topological Sort Benchmark
    IO.puts("\n== Topological Sort (Kahn's algorithm) ==")

    Benchee.run(
      %{
        "Yog (adjacency)" => fn {yog, _} -> Yog.Traversal.Sort.topological_sort(yog) end,
        "FGL (inductive)" => fn {_, fgl} -> FAlgo.topsort(fgl) end
      },
      inputs: %{
        "Small (50 nodes)" => {yog_small, fgl_small},
        "Medium (100 nodes)" => {yog_medium, fgl_medium},
        "Large (200 nodes)" => {yog_large, fgl_large}
      },
      time: 3,
      warmup: 1
    )

    # DFS Traversal Benchmark
    IO.puts("\n== Depth-First Search (Full graph traversal) ==")

    Benchee.run(
      %{
        "Yog (adjacency)" => fn {yog, _} ->
          Yog.Traversal.Walk.walk(in: yog, from: 1, using: :depth_first)
        end,
        "FGL (inductive)" => fn {_, fgl} ->
          Yog.Functional.Traversal.dfs(fgl, 1)
        end
      },
      inputs: %{
        "Small (50 nodes)" => {yog_small, fgl_small},
        "Medium (100 nodes)" => {yog_medium, fgl_medium}
      },
      time: 3,
      warmup: 1
    )

    # Dijkstra Shortest Path Benchmark
    IO.puts("\n== Shortest Path (Dijkstra's Algorithm) ==")

    Benchee.run(
      %{
        "Yog (adjacency)" => fn {{yog, _}, source, target} ->
          Yog.Pathfinding.Dijkstra.shortest_path(in: yog, from: source, to: target)
        end,
        "FGL (inductive)" => fn {{_, fgl}, source, target} ->
          FAlgo.shortest_path(fgl, source, target)
        end
      },
      inputs: %{
        "Small (50 nodes, path 1→25)" => {{yog_small, fgl_small}, 1, 25},
        "Medium (100 nodes, path 1→50)" => {{yog_medium, fgl_medium}, 1, 50},
        "Large (200 nodes, path 1→100)" => {{yog_large, fgl_large}, 1, 100}
      },
      time: 5,
      warmup: 2
    )

    # Node Iteration Benchmark
    IO.puts("\n== Node Iteration (Visiting all nodes) ==")

    Benchee.run(
      %{
        "Yog (adjacency)" => fn {yog, _} ->
          Yog.Model.all_nodes(yog) |> Enum.map(fn n -> n * 2 end)
        end,
        "FGL (inductive)" => fn {_, fgl} ->
          FModel.nodes(fgl) |> Enum.map(fn ctx -> ctx.id * 2 end)
        end
      },
      inputs: %{
        "Small (50 nodes)" => {yog_small, fgl_small},
        "Medium (100 nodes)" => {yog_medium, fgl_medium},
        "Large (200 nodes)" => {yog_large, fgl_large}
      },
      time: 2,
      warmup: 1
    )

    # Memory Usage Comparison
    IO.puts("\n== Memory Usage (Large Graph - 200 nodes, ~400 edges) ==")
    yog_size = :erts_debug.size(yog_large)
    fgl_size = :erts_debug.size(fgl_large)

    IO.puts("Memory (in words, 1 word = 8 bytes on 64-bit):")
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
    graph =
      Enum.reduce(1..nodes, graph, fn i, g ->
        Yog.add_node(g, i, "node_#{i}")
      end)

    # Add edges (ensure DAG by only connecting lower to higher IDs)
    added = :ets.new(:edges, [:set, :private])

    graph =
      Enum.reduce(1..edges, graph, fn _, g ->
        u = Enum.random(1..(nodes - 1))
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
    graph =
      Enum.reduce(1..nodes, graph, fn i, g ->
        FModel.put_node(g, i, "node_#{i}")
      end)

    # Add edges (ensure DAG by only connecting lower to higher IDs)
    added = :ets.new(:edges, [:set, :private])

    graph =
      Enum.reduce(1..edges, graph, fn _, g ->
        u = Enum.random(1..(nodes - 1))
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
  # Utility Functions
  # =============================================================================
  defp format_number(n) when n < 1000, do: to_string(n)
  defp format_number(n) when n < 1_000_000, do: "#{div(n, 1000)}k"
  defp format_number(n), do: "#{div(n, 1_000_000)}M"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

# Run the benchmark
FunctionalComparisonBenchmark.run()
