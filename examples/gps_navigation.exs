defmodule GpsNavigation do
  @moduledoc """
  GPS Navigation Example

  Demonstrates shortest path using A* and heuristics
  """

  require Yog

  def run do
    # Model road network with travel times
    road_network =
      Yog.undirected()
      |> Yog.add_node(1, "Home")
      |> Yog.add_node(2, "Office")
      |> Yog.add_node(3, "Mall")
      # 15 minutes
      |> Yog.add_edge(from: 1, to: 2, with: 15)
      |> Yog.add_edge(from: 2, to: 3, with: 10)
      |> Yog.add_edge(from: 1, to: 3, with: 30)

    # Use A* with straight-line distance heuristic
    straight_line_distance = fn from, to ->
      # Simplified: in reality would use coordinates
      if from == to do
        0
      else
        # Optimistic estimate
        5
      end
    end

    result = Yog.Pathfinding.astar(
      in: road_network,
      from: 1,
      to: 3,
      zero: 0,
      add: &(&1 + &2),
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
      heuristic: straight_line_distance
    )

    case result do
      {:some, {:path, _nodes, total_weight}} ->
        # Path(path: [1, 2, 3], total_weight: 25)
        # Prints: Fastest route takes 25 minutes
        IO.puts("Fastest route takes #{total_weight} minutes")

      :none ->
        IO.puts("No route found")
    end
  end
end

GpsNavigation.run()
