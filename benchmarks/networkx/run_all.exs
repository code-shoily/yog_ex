#!/usr/bin/env elixir
# Runner script to execute all YogEx vs NetworkX benchmarks in sequence

IO.puts("Running all YogEx vs NetworkX benchmarks...")
IO.puts("==========================================")

# Find all benchmark files
scripts =
  (Path.wildcard("benchmarks/networkx/0*.exs") ++
     Path.wildcard("benchmarks/networkx/1*.exs"))
  |> Enum.sort()

# Run them one by one
Enum.each(scripts, fn script ->
  IO.puts("\n" <> String.duplicate("-", 80))
  IO.puts("Executing: #{script}")
  IO.puts(String.duplicate("-", 80) <> "\n")

  try do
    Code.eval_file(script)
  rescue
    e ->
      IO.puts("Error running #{script}: #{inspect(e)}")
  after
    # Small pause to allow port GC and cleanup
    Process.sleep(500)
  end
end)
