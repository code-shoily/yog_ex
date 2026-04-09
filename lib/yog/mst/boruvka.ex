defmodule Yog.MST.Boruvka do
  @moduledoc """
  Borůvka's algorithm for Minimum Spanning Tree (MST).
  """

  alias Yog.DisjointSet
  alias Yog.MST.Result

  @doc """
  Computes MST using Borůvka's algorithm.
  """
  @spec compute(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) :: {:ok, Result.t()}
  def compute(graph, compare) do
    dsu =
      List.foldl(Map.keys(graph.nodes), DisjointSet.new(), fn node, acc ->
        DisjointSet.add(acc, node)
      end)

    edges = Yog.MST.extract_edges(graph)
    mst_edges = do_boruvka_loop(graph, edges, dsu, [], compare)
    {:ok, Result.new(mst_edges, :boruvka, map_size(graph.nodes))}
  end

  defp do_boruvka_loop(graph, all_edges, dsu, mst_edges, compare) do
    if DisjointSet.count_sets(dsu) <= 1 do
      mst_edges
    else
      # Find the cheapest edge leaving each component
      # We use a map to track the best edge for each component root
      cheapest = find_best_edges_for_components(all_edges, dsu, compare)

      if map_size(cheapest) == 0 do
        mst_edges
      else
        # Collect distinct edges to add (multiple components might pick the same edge)
        # We sort by node pairs to ensure stable identification
        edges_to_add =
          cheapest
          |> Map.values()
          |> Enum.uniq_by(fn e -> Enum.sort([e.from, e.to]) |> List.to_tuple() end)

        {new_dsu, new_mst} =
          List.foldl(edges_to_add, {dsu, mst_edges}, fn edge, {d_acc, m_acc} ->
            {DisjointSet.union(d_acc, edge.from, edge.to), [edge | m_acc]}
          end)

        # If we couldn't merge any components, we're done (disconnected graph)
        if map_size(new_dsu.parents) == map_size(dsu.parents) and
             DisjointSet.count_sets(new_dsu) == DisjointSet.count_sets(dsu) do
          mst_edges
        else
          do_boruvka_loop(graph, all_edges, new_dsu, new_mst, compare)
        end
      end
    end
  end

  defp find_best_edges_for_components(edges, dsu, compare) do
    List.foldl(edges, %{}, fn edge, acc ->
      {dsu1, root_u} = DisjointSet.find(dsu, edge.from)
      {_dsu2, root_v} = DisjointSet.find(dsu1, edge.to)

      if root_u == root_v do
        acc
      else
        acc
        |> update_best(root_u, edge, compare)
        |> update_best(root_v, edge, compare)
      end
    end)
  end

  defp update_best(best_map, root, edge, compare) do
    case Map.get(best_map, root) do
      nil ->
        Map.put(best_map, root, edge)

      existing ->
        if compare.(edge.weight, existing.weight) == :lt do
          Map.put(best_map, root, edge)
        else
          best_map
        end
    end
  end
end
