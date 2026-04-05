#!/usr/bin/env elixir

defmodule PQBenchmark do
  alias Yog.PriorityQueue, as: YogPQ

  def run do
    IO.puts("Priority Queue Benchmark: Pairing Heap vs :gb_trees")
    IO.puts("=" |> String.duplicate(60))
    
    sizes = [100, 1_000, 5_000, 10_000]
    
    for n <- sizes do
      IO.puts("\n#{n} elements:")
      IO.puts("-" |> String.duplicate(40))
      
      elements = Enum.shuffle(1..n)
      
      # Build benchmark
      {yog_build_time, yog_pq} = :timer.tc(fn ->
        Enum.reduce(elements, YogPQ.new(), fn x, acc -> YogPQ.push(acc, x) end)
      end, :millisecond)
      
      {gb_build_time, gb_tree} = :timer.tc(fn ->
        Enum.reduce(elements, :gb_trees.empty(), fn x, acc -> 
          :gb_trees.insert(x, nil, acc)
        end)
      end, :millisecond)
      
      IO.puts("  Build (push n elements):")
      IO.puts("    Pairing Heap: #{yog_build_time}ms")
      IO.puts("    :gb_trees:     #{gb_build_time}ms")
      
      # Pop all elements benchmark
      {yog_pop_time, _} = :timer.tc(fn ->
        Enum.reduce(1..n, yog_pq, fn _, acc ->
          case YogPQ.pop(acc) do
            {:ok, _, new_pq} -> new_pq
            :error -> acc
          end
        end)
      end, :millisecond)
      
      {gb_pop_time, _} = :timer.tc(fn ->
        Enum.reduce(1..n, gb_tree, fn _, acc ->
          case :gb_trees.smallest(acc) do
            {key, _} -> 
              :gb_trees.delete(key, acc)
            _ -> acc
          end
        end)
      end, :millisecond)
      
      IO.puts("  Pop all elements:")
      IO.puts("    Pairing Heap: #{yog_pop_time}ms")
      IO.puts("    :gb_trees:     #{gb_pop_time}ms")
      
      # Mixed operations (Dijkstra-like pattern)
      {yog_mixed_time, _} = :timer.tc(fn ->
        Enum.reduce(1..div(n, 10), {YogPQ.new(), 0}, fn i, {pq, _acc} ->
          # Push 10 elements
          pq = Enum.reduce(i*10..(i*10+9), pq, fn x, p -> YogPQ.push(p, x) end)
          # Pop 1 element
          case YogPQ.pop(pq) do
            {:ok, v, new_pq} -> {new_pq, v}
            :error -> {pq, 0}
          end
        end)
      end, :millisecond)
      
      {gb_mixed_time, _} = :timer.tc(fn ->
        Enum.reduce(1..div(n, 10), {:gb_trees.empty(), 0}, fn i, {tree, _acc} ->
          # Push 10 elements
          tree = Enum.reduce(i*10..(i*10+9), tree, fn x, t -> 
            :gb_trees.insert(x, nil, t)
          end)
          # Pop 1 element (smallest)
          {key, _} = :gb_trees.smallest(tree)
          {:gb_trees.delete(key, tree), key}
        end)
      end, :millisecond)
      
      IO.puts("  Mixed (10 push : 1 pop ratio):")
      IO.puts("    Pairing Heap: #{yog_mixed_time}ms")
      IO.puts("    :gb_trees:     #{gb_mixed_time}ms")
      
      # Memory comparison (rough estimate via :erlang.memory processes)
      {yog_mem, _} = :erlang.spawn_monitor(fn ->
        pq = Enum.reduce(1..n, YogPQ.new(), fn x, acc -> YogPQ.push(acc, x) end)
        receive do _ -> nil end
      end)
      
      {gb_mem, _} = :erlang.spawn_monitor(fn ->
        tree = Enum.reduce(1..n, :gb_trees.empty(), fn x, acc -> 
          :gb_trees.insert(x, nil, acc)
        end)
        receive do _ -> nil end
      end)
      
      # Cancel the spawns
      Process.exit(yog_mem, :kill)
      Process.exit(gb_mem, :kill)
    end
    
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Summary:")
    IO.puts("- Pairing Heap: O(1) push, O(log n) amortized pop")
    IO.puts("- :gb_trees: O(log n) for all operations")
    IO.puts("- For high push:pop ratios, Pairing Heap should win")
    IO.puts("- For balanced operations, :gb_trees might be comparable")
  end
end

PQBenchmark.run()
