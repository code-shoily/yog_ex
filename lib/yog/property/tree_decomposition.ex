defmodule Yog.Property.TreeDecomposition do
  @moduledoc """
  Represents a tree decomposition of a graph.

  A valid tree decomposition satisfies three properties:

  1. **Vertex coverage**: The union of all bags equals all vertices of the graph.
  2. **Edge coverage**: For each edge `(u, v)`, some bag contains both `u` and `v`.
  3. **Running intersection**: For each vertex `v`, the bags containing `v` form a
     connected subtree.

  The *width* of a tree decomposition is `max(|bag|) - 1`. The *treewidth* of a graph
  is the minimum width over all valid tree decompositions.

  ## Examples

      iex> td = %Yog.Property.TreeDecomposition{
      ...>   bags: %{0 => MapSet.new([1, 2]), 1 => MapSet.new([2, 3])},
      ...>   tree: Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1),
      ...>   width: 1
      ...> }
      iex> is_struct(td, Yog.Property.TreeDecomposition)
      true
  """

  alias Yog.Model

  @typedoc """
  A bag is a set of vertices from the original graph.
  """
  @type bag :: MapSet.t(Yog.node_id())

  @typedoc """
  A tree decomposition struct containing bags, a tree graph connecting bag indices,
  and the decomposition width.
  """
  @type t :: %__MODULE__{
          bags: %{non_neg_integer() => bag()},
          tree: Yog.Graph.t(),
          width: non_neg_integer()
        }

  defstruct [:bags, :tree, :width]

  @doc """
  Validates that a tree decomposition satisfies all three properties.

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> {:ok, td} = Yog.Approximate.tree_decomposition(graph)
      iex> Yog.Property.TreeDecomposition.valid?(td, graph)
      true
  """
  @spec valid?(t(), Yog.graph()) :: boolean()
  def valid?(%__MODULE__{} = td, graph) do
    vertices = MapSet.new(Model.all_nodes(graph))
    bag_indices = Map.keys(td.bags)

    # 1. Vertex coverage
    covered =
      td.bags
      |> Map.values()
      |> Enum.reduce(MapSet.new(), &MapSet.union/2)

    vertex_coverage = MapSet.equal?(covered, vertices)

    # 2. Edge coverage
    edge_coverage =
      if vertex_coverage do
        all_edges =
          for u <- Model.all_nodes(graph),
              v <- Model.neighbor_ids(graph, u),
              u <= v,
              do: {u, v}

        Enum.all?(all_edges, fn {u, v} ->
          Enum.any?(td.bags, fn {_idx, bag} ->
            MapSet.member?(bag, u) and MapSet.member?(bag, v)
          end)
        end)
      else
        false
      end

    # 3. Running intersection
    running_intersection =
      if edge_coverage do
        Enum.all?(Model.all_nodes(graph), fn v ->
          containing =
            Enum.filter(bag_indices, fn idx ->
              bag = Map.fetch!(td.bags, idx)
              MapSet.member?(bag, v)
            end)

          connected_in_tree?(td.tree, containing)
        end)
      else
        false
      end

    vertex_coverage and edge_coverage and running_intersection
  end

  # Check that a subset of bag indices induces a connected subgraph in the tree.
  defp connected_in_tree?(_tree, []), do: true
  defp connected_in_tree?(_tree, [_single]), do: true

  defp connected_in_tree?(tree, indices) do
    index_set = MapSet.new(indices)
    [start | _rest] = indices

    visited = bfs_tree(tree, start, index_set, MapSet.new([start]))
    MapSet.equal?(visited, index_set)
  end

  defp bfs_tree(_tree, [], _allowed, visited), do: visited

  defp bfs_tree(tree, [node | queue], allowed, visited) do
    neighbors =
      Model.neighbor_ids(tree, node)
      |> Enum.filter(fn n -> MapSet.member?(allowed, n) and not MapSet.member?(visited, n) end)

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    bfs_tree(tree, queue ++ neighbors, allowed, new_visited)
  end

  defp bfs_tree(tree, start, allowed, visited) do
    bfs_tree(tree, [start], allowed, visited)
  end
end
