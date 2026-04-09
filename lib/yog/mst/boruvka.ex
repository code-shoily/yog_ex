defmodule Yog.MST.Boruvka do
  @moduledoc """
  Borůvka's algorithm for finding the Minimum Spanning Tree (MST).

  Borůvka's algorithm works in stages. In each stage, for each connected component,
  it finds the minimum-weight edge that connects that component to a different
  component. All such edges are added to the MST simultaneously. This process
  continues until only one component remains or no more edges can be added.

  ## Performance

  - **Time Complexity**: O(E log V), where E is the number of edges and V is the
    number of vertices.
  - **Space Complexity**: O(V) for the disjoint set and tracking component edges.
  """

  alias Yog.DisjointSet
  alias Yog.MST.Result

  @doc """
  Computes the Minimum Spanning Tree (MST) using Borůvka's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges of the MST.

  ## Parameters

  - `graph`: The undirected graph to process.
  - `compare`: A comparison function `(a, b -> :lt | :eq | :gt)` used to order
    edge weights.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}, {1, 3, 20}])
      iex> {:ok, result} = Yog.MST.Boruvka.compute(graph, &Yog.Utils.compare/2)
      iex> result.total_weight
      15
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
