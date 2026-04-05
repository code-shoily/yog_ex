#!/usr/bin/env elixir
# Benchmark: Shortest Path (A*)
# Comparing Yog and libgraph on grid graphs

code = """
# Grid graph for A* (better suited for heuristic)
grid_graphs = fn size ->
  # Yog
  yog = Yog.directed()
  nodes = for x <- 0..(size - 1), y <- 0..(size - 1), do: {x, y}
  yog = Enum.reduce(nodes, yog, fn pos, g -> Yog.add_node(g, pos, nil) end)

  yog = Enum.reduce(nodes, yog, fn {x, y}, g ->
    g = if x < size - 1 do
      {:ok, ng} = Yog.add_edge(g, {x, y}, {x + 1, y}, 1)
      ng
    else
      g
    end
    g = if y < size - 1 do
      {:ok, ng} = Yog.add_edge(g, {x, y}, {x, y + 1}, 1)
      ng
    else
      g
    end
    g
  end)

  # libgraph
  lib = Graph.new(type: :directed)
  lib = Enum.reduce(nodes, lib, fn pos, g -> Graph.add_vertex(g, pos) end)

  lib = Enum.reduce(nodes, lib, fn {x, y}, g ->
    g = if x < size - 1, do: Graph.add_edge(g, {x, y}, {x + 1, y}, weight: 1), else: g
    g = if y < size - 1, do: Graph.add_edge(g, {x, y}, {x, y + 1}, weight: 1), else: g
    g
  end)

  start_pos = {0, 0}
  goal_pos = {size - 1, size - 1}

  # Zero heuristic (Dijkstra-like)
  lib_heuristic = fn {_x, _y} -> 0 end
  yog_heuristic = fn {_x1, _y1}, {_x2, _y2} -> 0 end

  {yog, lib, start_pos, goal_pos, yog_heuristic, lib_heuristic}
end

{yog_s, lib_s, start_s, goal_s, h_yog_s, h_lib_s} = grid_graphs.(10)
{yog_m, lib_m, start_m, goal_m, h_yog_m, h_lib_m} = grid_graphs.(20)

inputs = %{
  "Small (10x10 grid)" => {yog_s, lib_s, start_s, goal_s, h_yog_s, h_lib_s},
  "Medium (20x20 grid)" => {yog_m, lib_m, start_m, goal_m, h_yog_m, h_lib_m}
}

IO.puts("\n== Shortest Path (A*) ==\n")

Benchee.run(
  %{
    "Yog (A*)" => fn {yog, _, start, goal, h, _} ->
      Yog.Pathfinding.AStar.a_star(
        in: yog,
        from: start,
        to: goal,
        heuristic: h,
        zero: 0,
        combine: &(&1 + &2),
        compare: fn a, b ->
          cond do
            a < b -> :lt
            a > b -> :gt
            true -> :eq
          end
        end
      )
    end,
    "libgraph (A*)" => fn {_, lib, start, goal, _, h} ->
      Graph.Pathfinding.a_star(lib, start, goal, h)
    end
  },
  inputs: inputs,
  time: 3,
  warmup: 1
)
"""

Code.eval_string(code, [], __ENV__)
