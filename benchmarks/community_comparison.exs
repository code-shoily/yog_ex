#!/usr/bin/env elixir

defmodule CommunityBenchmark do
  @moduledoc """
  Benchmark comparing Louvain, Label Propagation, and Fluid Communities.
  """

  alias Yog.Community

  @iterations 5

  def run do
    IO.puts("Community Detection Benchmark: Louvain vs Label Propagation vs Fluid")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("Each test runs #{@iterations} iterations and reports total / average time.\n")

    # Barbell Networks
    run_suite("Barbell Networks (2 Clear Communities)", [
      {"Barbell(100, 10)", Yog.Generator.Classic.barbell(100, 10), 2},
      {"Barbell(500, 50)", Yog.Generator.Classic.barbell(500, 50), 2}
    ])

    # Caveman graphs
    run_suite("Ring of Cliques (Multiple Clear Communities)", [
      {"10 cliques of 20 nodes (200 nodes)", build_caveman_graph(10, 20), 10},
      {"20 cliques of 50 nodes (1000 nodes)", build_caveman_graph(20, 50), 20}
    ])

    # Sparse random paths
    run_suite("Sparse Path Networks (No clear boundary)", [
      {"Path of 1000 nodes", build_path_graph(1000), 10},
      {"Grid of 30x30", build_grid_graph(30), 5}
    ])

    # Correctness check
    IO.puts("\n== Correctness Check ==")

    barbell = Yog.Generator.Classic.barbell(50, 5)
    lp_barbell = Community.LabelPropagation.detect(barbell)
    louvain_barbell = Community.Louvain.detect(barbell)
    fluid_barbell = Community.FluidCommunities.detect_with_options(barbell, target_communities: 2)

    IO.puts("  Barbell(50, 5):")
    IO.puts("    Label Prop: #{lp_barbell.num_communities} communities")
    IO.puts("    Louvain:    #{louvain_barbell.num_communities} communities")
    IO.puts("    Fluid:      #{fluid_barbell.num_communities} communities (target=2)")

    caveman = build_caveman_graph(5, 10)
    lp_caveman = Community.LabelPropagation.detect(caveman)
    louvain_caveman = Community.Louvain.detect(caveman)
    fluid_caveman = Community.FluidCommunities.detect_with_options(caveman, target_communities: 5)

    IO.puts("  Caveman(5, 10):")
    IO.puts("    Label Prop: #{lp_caveman.num_communities} communities")
    IO.puts("    Louvain:    #{louvain_caveman.num_communities} communities")
    IO.puts("    Fluid:      #{fluid_caveman.num_communities} communities (target=5)")

    # Memory summary
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 on result in words)")

    graph = build_caveman_graph(10, 20)

    lp_size = :erts_debug.size(Community.LabelPropagation.detect(graph))
    lv_size = :erts_debug.size(Community.Louvain.detect(graph))

    fl_size =
      :erts_debug.size(
        Community.FluidCommunities.detect_with_options(graph, target_communities: 10)
      )

    IO.puts("\nCaveman 10×20:")
    IO.puts("  Label Prop: #{lp_size} words (~#{format_bytes(lp_size * 8)})")
    IO.puts("  Louvain:    #{lv_size} words (~#{format_bytes(lv_size * 8)})")
    IO.puts("  Fluid:      #{fl_size} words (~#{format_bytes(fl_size * 8)})")

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("Summary:")
    IO.puts("- Label Propagation: Extremely fast, linear time, but can be highly variable.")

    IO.puts(
      "- Louvain: The gold standard for modularity. Slower agglomeration but very reliable."
    )

    IO.puts("- Fluid Communities: Allows defining exactly `k` communities. Fast fluid dynamics.")
  end

  defp run_suite(title, cases) do
    IO.puts("== #{title} ==")

    for {name, graph, k} <- cases do
      IO.puts("  #{name}")

      lp_avg = bench(fn -> Community.LabelPropagation.detect(graph) end)
      lv_avg = bench(fn -> Community.Louvain.detect(graph) end)

      fl_avg =
        bench(fn ->
          Community.FluidCommunities.detect_with_options(graph, target_communities: k)
        end)

      results = [
        {"Label Propagation", lp_avg},
        {"Louvain", lv_avg},
        {"Fluid (k=#{k})", fl_avg}
      ]

      for {label, avg_ms} <- results do
        IO.puts("    #{String.pad_trailing(label <> ":", 20)} #{avg_ms}ms avg")
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

  defp build_caveman_graph(num_cliques, clique_size) do
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
              do: {i, j, 1}

        Enum.reduce(edges, acc, fn {u, v, w}, g_acc ->
          Yog.add_edge_ensure(g_acc, u, v, w)
        end)
      end)

    # Bridge cliques in a ring
    Enum.reduce(0..(num_cliques - 1), g, fn c, acc ->
      next_c = rem(c + 1, num_cliques)

      # Connect last node of current clique to first node of next clique
      u = c * clique_size + clique_size - 1
      v = next_c * clique_size

      Yog.add_edge_ensure(acc, u, v, 1)
    end)
  end

  defp build_path_graph(n) do
    g = Enum.reduce(0..(n - 1), Yog.undirected(), &Yog.add_node(&2, &1, nil))

    Enum.reduce(0..(n - 2), g, fn i, acc ->
      Yog.add_edge_ensure(acc, i, i + 1, 1)
    end)
  end

  defp build_grid_graph(n) do
    Enum.reduce(0..(n - 1), Yog.undirected(), fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = i * n + j
        acc = Yog.add_node(acc, node_id, nil)

        acc =
          if j < n - 1 do
            Yog.add_edge_ensure(acc, node_id, node_id + 1, 1)
          else
            acc
          end

        acc =
          if i < n - 1 do
            Yog.add_edge_ensure(acc, node_id, node_id + n, 1)
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

CommunityBenchmark.run()
