defmodule Yog.MST.Kruskal do
  @moduledoc """
  Kruskal's algorithm for Minimum Spanning Tree (MST).
  """

  alias Yog.DisjointSet
  alias Yog.MST.Result

  @doc """
  Computes MST using Kruskal's algorithm.
  """
  @spec compute(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) :: {:ok, Result.t()}
  def compute(graph, compare) do
    edges = Yog.MST.extract_edges(graph)
    sorted_edges = Enum.sort(edges, fn a, b -> compare.(a.weight, b.weight) == :lt end)

    result = do_kruskal(sorted_edges, DisjointSet.new(), [])
    {:ok, Result.new(result, :kruskal, map_size(graph.nodes))}
  end

  # Main Kruskal loop - processes edges in order, adding them if they don't form cycles.
  defp do_kruskal([], _disjoint_set, acc) do
    Enum.reverse(acc)
  end

  defp do_kruskal([edge | rest], disjoint_set, acc) do
    {ds1, root_from} = DisjointSet.find(disjoint_set, edge.from)

    # Optimization: early check if from and to are same set before second find
    case Map.fetch(ds1.parents, edge.to) do
      :error ->
        # to not in DS yet, add it and include edge
        ds2 = DisjointSet.add(ds1, edge.to)
        ds3 = DisjointSet.union(ds2, edge.from, edge.to)
        do_kruskal(rest, ds3, [edge | acc])

      {:ok, _} ->
        {ds2, root_to} = DisjointSet.find(ds1, edge.to)

        if root_from == root_to do
          do_kruskal(rest, ds2, acc)
        else
          ds3 = DisjointSet.union(ds2, edge.from, edge.to)
          do_kruskal(rest, ds3, [edge | acc])
        end
    end
  end
end
