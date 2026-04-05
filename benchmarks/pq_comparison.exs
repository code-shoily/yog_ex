#!/usr/bin/env elixir

defmodule PQBenchmark do
  @moduledoc """
  Priority Queue Benchmark: Pairing Heap vs :gb_trees using Benchee.
  """

  alias Yog.PriorityQueue, as: YogPQ

  def run do
    IO.puts("Priority Queue Benchmark: Pairing Heap vs :gb_trees")
    IO.puts("=" |> String.duplicate(60))

    sizes = [100, 1_000, 5_000, 10_000]

    # Build inputs for different sizes
    inputs =
      Map.new(sizes, fn n ->
        {"#{n} elements", Enum.shuffle(1..n)}
      end)

    # Build benchmark
    IO.puts("\n== Build (push n elements) ==")

    Benchee.run(
      %{
        "Pairing Heap" => fn elements ->
          Enum.reduce(elements, YogPQ.new(), fn x, acc -> YogPQ.push(acc, x) end)
        end,
        ":gb_trees" => fn elements ->
          Enum.reduce(elements, :gb_trees.empty(), fn x, acc ->
            :gb_trees.insert(x, nil, acc)
          end)
        end
      },
      inputs: inputs,
      time: 3,
      warmup: 1
    )

    # Pop all elements benchmark
    IO.puts("\n== Pop all elements ==")

    # Pre-build data structures for pop benchmark
    pop_inputs =
      Map.new(sizes, fn n ->
        elements = Enum.shuffle(1..n)

        yog_pq = Enum.reduce(elements, YogPQ.new(), fn x, acc -> YogPQ.push(acc, x) end)

        gb_tree =
          Enum.reduce(elements, :gb_trees.empty(), fn x, acc ->
            :gb_trees.insert(x, nil, acc)
          end)

        {"#{n} elements", %{yog: yog_pq, gb: gb_tree, n: n}}
      end)

    Benchee.run(
      %{
        "Pairing Heap" => fn %{yog: pq, n: n} ->
          Enum.reduce(1..n, pq, fn _, acc ->
            case YogPQ.pop(acc) do
              {:ok, _, new_pq} -> new_pq
              :error -> acc
            end
          end)
        end,
        ":gb_trees" => fn %{gb: tree, n: n} ->
          Enum.reduce(1..n, tree, fn _, acc ->
            case :gb_trees.smallest(acc) do
              {key, _} -> :gb_trees.delete(key, acc)
              _ -> acc
            end
          end)
        end
      },
      inputs: pop_inputs,
      time: 3,
      warmup: 1
    )

    # Mixed operations (Dijkstra-like pattern)
    IO.puts("\n== Mixed operations (10 push : 1 pop ratio) ==")

    mixed_inputs =
      Map.new(sizes, fn n ->
        {"#{n} elements", n}
      end)

    Benchee.run(
      %{
        "Pairing Heap" => fn n ->
          Enum.reduce(1..div(n, 10), {YogPQ.new(), 0}, fn i, {pq, _acc} ->
            # Push 10 elements
            pq = Enum.reduce((i * 10)..(i * 10 + 9), pq, fn x, p -> YogPQ.push(p, x) end)

            # Pop 1 element
            case YogPQ.pop(pq) do
              {:ok, v, new_pq} -> {new_pq, v}
              :error -> {pq, 0}
            end
          end)
        end,
        ":gb_trees" => fn n ->
          Enum.reduce(1..div(n, 10), {:gb_trees.empty(), 0}, fn i, {tree, _acc} ->
            # Push 10 elements
            tree =
              Enum.reduce((i * 10)..(i * 10 + 9), tree, fn x, t ->
                :gb_trees.insert(x, nil, t)
              end)

            # Pop 1 element (smallest)
            {key, _} = :gb_trees.smallest(tree)
            {:gb_trees.delete(key, tree), key}
          end)
        end
      },
      inputs: mixed_inputs,
      time: 3,
      warmup: 1
    )

    # Memory comparison
    IO.puts("\n== Memory Usage Summary ==")
    IO.puts("(Measured using :erts_debug.size/1 in words)")

    for n <- sizes do
      elements = Enum.shuffle(1..n)

      yog_pq = Enum.reduce(elements, YogPQ.new(), fn x, acc -> YogPQ.push(acc, x) end)

      gb_tree =
        Enum.reduce(elements, :gb_trees.empty(), fn x, acc ->
          :gb_trees.insert(x, nil, acc)
        end)

      yog_size = :erts_debug.size(yog_pq)
      gb_size = :erts_debug.size(gb_tree)

      IO.puts("\n#{n} elements:")
      IO.puts("  Pairing Heap: #{yog_size} words (~#{format_bytes(yog_size * 8)})")
      IO.puts("  :gb_trees:    #{gb_size} words (~#{format_bytes(gb_size * 8)})")
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Summary:")
    IO.puts("- Pairing Heap: O(1) push, O(log n) amortized pop")
    IO.puts("- :gb_trees: O(log n) for all operations")
    IO.puts("- For high push:pop ratios, Pairing Heap should win")
    IO.puts("- For balanced operations, :gb_trees might be comparable")
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

PQBenchmark.run()
