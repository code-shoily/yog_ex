defmodule Yog.MST.Kruskal do
  @moduledoc """
  Kruskal's algorithm for finding the Minimum Spanning Tree (MST).

  Kruskal's algorithm is a greedy algorithm that finds a minimum spanning forest
  of an undirected edge-weighted graph. It sorts all edges by weight and adds
  them one by one if they don't form a cycle, using a Disjoint Set Union (DSU)
  data structure for efficient connectivity checks.

  ## Performance

  - **Time Complexity**: O(E log E) or O(E log V) due to sorting, where E is the
    number of edges and V is the number of vertices.
  - **Space Complexity**: O(V) to store the disjoint set.
  """

  alias Yog.DisjointSet
  alias Yog.MST.Result

  @doc """
  Computes the Minimum Spanning Tree (MST) using Kruskal's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges of the MST.

  ## Parameters

  - `graph`: The undirected graph to process.
  - `compare`: A comparison function `(a, b -> :lt | :eq | :gt)` used to order
    edge weights.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}, {1, 3, 20}])
      iex> {:ok, result} = Yog.MST.Kruskal.compute(graph, &Yog.Utils.compare/2)
      iex> result.total_weight
      15
      iex> Enum.map(result.edges, fn e -> {e.from, e.to} end) |> Enum.sort()
      [{1, 2}, {2, 3}]
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
