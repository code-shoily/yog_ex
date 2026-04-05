# benchmarks/protocol_vs_list.exs

map_sizes = [10, 100, 1000, 10000]
iterations = 1000

IO.puts "Comparing Map Iteration Strategies (#{iterations} iterations per size)\n"
:io.format("~-10s| ~-17s| ~-17s| ~-24s~n", ["Size", "Enum.reduce (M)", ":maps.fold/3", "Map.to_list + List.foldl"])
IO.puts String.duplicate("-", 80)

for size <- map_sizes do
  map = Map.new(1..size, fn i -> {i, i} end)
  
  # Warm-up
  Enum.reduce(map, 0, fn {_, v}, acc -> acc + v end)
  :maps.fold(fn _, v, acc -> acc + v end, 0, map)
  List.foldl(Map.to_list(map), 0, fn {_, v}, acc -> acc + v end)

  {t1, _} = :timer.tc(fn ->
    for _ <- 1..iterations do
      Enum.reduce(map, 0, fn {_, v}, acc -> acc + v end)
    end
  end)

  {t2, _} = :timer.tc(fn ->
    for _ <- 1..iterations do
      :maps.fold(fn _, v, acc -> acc + v end, 0, map)
    end
  end)

  {t3, _} = :timer.tc(fn ->
    for _ <- 1..iterations do
      List.foldl(Map.to_list(map), 0, fn {_, v}, acc -> acc + v end)
    end
  end)

  avg1 = t1 / iterations
  avg2 = t2 / iterations
  avg3 = t3 / iterations

  :io.format("~-10w| ~-14.2fμs | ~-14.2fμs | ~-14.2fμs~n", [size, avg1, avg2, avg3])
end
