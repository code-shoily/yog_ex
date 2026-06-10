#!/usr/bin/env elixir
# Benchmark: Shortest Path (A*)
# Comparing YogEx and NetworkX

Code.require_file("shared.exs", __DIR__)
alias Benchmarks.NetworkX.Shared

# Initialize Port
port = Shared.start_port()

# Build a grid graph
build_grid_graph = fn n ->
  Enum.reduce(0..(n - 1), Yog.undirected(), fn i, g ->
    Enum.reduce(0..(n - 1), g, fn j, acc ->
      node_id = i * n + j
      acc = Yog.add_node(acc, node_id, nil)

      acc =
        if j < n - 1 do
          right_id = i * n + (j + 1)
          Yog.add_edge_ensure(acc, node_id, right_id, 1.0)
        else
          acc
        end

      acc =
        if i < n - 1 do
          down_id = (i + 1) * n + j
          Yog.add_edge_ensure(acc, node_id, down_id, 1.0)
        else
          acc
        end

      acc
    end)
  end)
end

grid_size = 50
grid = build_grid_graph.(grid_size)
Shared.register_graph(port, :grid, grid)

source = 0
target = grid_size * grid_size - 1

heuristic = fn u, v ->
  {ux, uy} = {div(u, grid_size), rem(u, grid_size)}
  {vx, vy} = {div(v, grid_size), rem(v, grid_size)}
  abs(ux - vx) + abs(uy - vy)
end

IO.puts("\n== Shortest Path (A*) ==\n")
IO.puts("Grid: #{grid_size}x#{grid_size} (#{grid_size * grid_size} nodes)")
IO.puts("Source: #{source}, Target: #{target}\n")

Benchee.run(
  %{
    "Yog (A*)" => fn ->
      Yog.Pathfinding.AStar.a_star(in: grid, from: source, to: target, heuristic: heuristic)
    end,
    "NetworkX (A*)" =>
      Shared.benchmark_nx(port, :grid, "a_star", %{
        source: source,
        target: target,
        grid_n: grid_size
      })
  },
  time: 3,
  warmup: 1
)

Shared.stop_port(port)
