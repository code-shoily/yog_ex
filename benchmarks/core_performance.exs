defmodule BenchmarkUtils do
  def measure(name, fun, iterations \\ 100) do
    IO.write(String.pad_trailing("  #{name}:", 40))

    # Warmup
    fun.()

    times =
      for _ <- 1..iterations do
        {t, _} = :timer.tc(fun)
        t
      end

    avg = Enum.sum(times) / iterations
    min = Enum.min(times)
    max = Enum.max(times)

    IO.puts(
      "avg: #{format_time(avg)} | min: #{format_time(min)} | max: #{format_time(max)}"
    )
  end

  defp format_time(μs) when μs < 1000, do: "#{Float.round(μs / 1.0, 2)}μs"
  defp format_time(μs), do: "#{Float.round(μs / 1000.0, 2)}ms"
end

# Setup
graph_size = 5000
edge_count = 20000

IO.puts("\nGenerating test graph (#{graph_size} nodes, #{edge_count} edges)...")
nodes = Enum.to_list(1..graph_size)
initial_graph = Yog.directed()
graph = Enum.reduce(nodes, initial_graph, fn i, acc -> Yog.add_node(acc, i, "Data #{i}") end)

# Add random edges
:rand.seed(:exsss, {1, 2, 3})
edges = for _ <- 1..edge_count do
  {Enum.random(1..graph_size), Enum.random(1..graph_size), :rand.uniform(100)}
end
{:ok, graph} = Yog.add_edges(graph, edges)
IO.puts("Done!\n")

IO.puts("Running Core Benchmarks...")
BenchmarkUtils.measure("Yog.all_nodes/1 (List Allocation)", fn ->
  graph |> Yog.all_nodes() |> Enum.each(fn _ -> :ok end)
end)

BenchmarkUtils.measure("Direct Map Iteration (Manual)", fn ->
  graph.nodes |> Enum.each(fn _ -> :ok end)
end)

BenchmarkUtils.measure("Yog.successors/2 (Map.to_list)", fn ->
  # Access successors for 50 nodes
  Enum.each(1..50, fn _ ->
    Yog.successors(graph, Enum.random(1..graph_size))
  end)
end, 20)

BenchmarkUtils.measure("Direct Edge Map Access (fetch)", fn ->
  Enum.each(1..50, fn _ ->
    case Map.fetch(graph.out_edges, Enum.random(1..graph_size)) do
      {:ok, _map} -> :ok
      :error -> :ok
    end
  end)
end, 20)

BenchmarkUtils.measure("Yog.Transform.to_undirected/1", fn ->
  Yog.Transform.to_undirected(graph, fn a, b -> a + b end)
end, 10)

BenchmarkUtils.measure("Yog.Operation.intersection/2", fn ->
  # Self-intersection
  Yog.Operation.intersection(graph, graph)
end, 10)
