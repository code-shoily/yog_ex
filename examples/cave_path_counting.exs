defmodule CavePathCounting do
  @moduledoc """
  Cave Path Counting Example

  Demonstrates custom DFS with backtracking
  """

  require Yog

  def run do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, "start")
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "b")
      |> Yog.add_node(3, "c")
      |> Yog.add_node(4, "d")
      |> Yog.add_node(5, "end")
      |> Yog.add_edge(from: 0, to: 1, with: nil)
      |> Yog.add_edge(from: 0, to: 2, with: nil)
      |> Yog.add_edge(from: 1, to: 3, with: nil)
      |> Yog.add_edge(from: 1, to: 2, with: nil)
      |> Yog.add_edge(from: 2, to: 4, with: nil)
      |> Yog.add_edge(from: 1, to: 5, with: nil)
      |> Yog.add_edge(from: 4, to: 5, with: nil)

    paths = count_paths(graph, 0, MapSet.new(), false)
    IO.puts("Found #{paths} valid paths through the cave system")
  end

  defp count_paths(graph, current, visited_small, can_revisit_one) do
    # Get node data from graph structure
    nodes = elem(graph, 2)
    cave_name = Map.get(nodes, current)

    case cave_name do
      "end" -> 1
      _ ->
        Yog.successors(graph, current)
        |> Enum.reduce(0, fn {neighbor_id, _}, count ->
          neighbor_name = Map.get(nodes, neighbor_id)
          is_small = String.downcase(neighbor_name) == neighbor_name
          already_visited = MapSet.member?(visited_small, neighbor_name)

          case {neighbor_name, is_small, already_visited} do
            {"start", _, _} ->
              count

            {_, false, _} ->
              count + count_paths(graph, neighbor_id, visited_small, can_revisit_one)

            {_, true, false} ->
              new_visited = MapSet.put(visited_small, neighbor_name)
              count + count_paths(graph, neighbor_id, new_visited, can_revisit_one)

            {_, true, true} when can_revisit_one ->
              count + count_paths(graph, neighbor_id, visited_small, false)

            {_, true, true} ->
              count
          end
        end)
    end
  end
end

CavePathCounting.run()
