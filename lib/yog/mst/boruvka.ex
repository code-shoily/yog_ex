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
  alias Yog.MST.Utils

  @doc """
  Computes the Minimum Spanning Tree (MST) using Borůvka's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges of the MST.

  ## Parameters

  - `graph`: The input weighted undirected graph.
  - `compare`: A function that compares two edge weights.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(1, 2, 5)
      ...> |> Yog.add_edge_ensure(2, 3, 10)
      ...> |> Yog.add_edge_ensure(1, 3, 15)
      iex> {:ok, result} = Yog.MST.Boruvka.compute(graph, &Yog.Utils.compare/2)
      iex> result.total_weight
      15
      iex> Enum.map(result.edges, fn e -> {e.from, e.to} end) |> Enum.sort()
      [{1, 2}, {2, 3}]
  """
  @spec compute(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) :: {:ok, Result.t()}
  def compute(graph, compare) do
    dsu =
      List.foldl(Map.keys(graph.nodes), DisjointSet.new(), fn node, acc ->
        DisjointSet.add(acc, node)
      end)

    edges = Utils.extract_edges(graph)
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

        do_boruvka_loop(graph, all_edges, new_dsu, new_mst, compare)
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
