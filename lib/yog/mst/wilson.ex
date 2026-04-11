defmodule Yog.MST.Wilson do
  @moduledoc """
  Wilson's algorithm for generating a Uniform Spanning Tree (UST).

  Wilson's algorithm uses loop-erased random walks to sample a spanning tree
  uniformly at random from the set of all possible spanning trees of a graph.
  Unlike Kruskal's or Prim's, it is not a "minimum" spanning tree algorithm,
  but a probabilistic one.

  ## Performance

  - **Time Complexity**: The expected time is the mean hitting time of the graph,
    which varies but is generally efficient for most graphs.
  - **Space Complexity**: O(V) to store the tree and the current walk.
  """

  alias Yog.Connectivity.Components
  alias Yog.MST.Result

  @doc """
  Generates a Uniform Spanning Tree (UST) using Wilson's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges of the spanning tree.

  ## Parameters

  - `graph`: The graph (usually undirected) to sample from.
  - `opts`: Options including:
    - `:root` - The node to start the tree from (initially in the tree).
    - `:seed` - (Optional) seed for the random number generator.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {1, 3, 1}])
      iex> {:ok, result} = Yog.MST.Wilson.compute(graph)
      iex> result.edge_count
      2
  """
  @spec compute(Yog.graph(), keyword()) :: {:ok, Result.t()}
  def compute(graph, opts \\ []) do
    node_ids = Map.keys(graph.nodes)

    if node_ids == [] do
      {:ok, Result.new([], :wilson, 0)}
    else
      # Since loop-erased random walks will infinitely loop if the walker is in
      # a disconnected component from the initial tree root, we must process
      # isolated components natively into a Spanning Forest.
      components = Components.connected_components(graph)

      edges =
        Enum.flat_map(components, fn comp ->
          # Safely define the root per-component
          target_root = opts[:root]
          root = Enum.find(comp, fn n -> n == target_root end) || hd(comp)

          tree = MapSet.new([root])
          unvisited = MapSet.new(comp) |> MapSet.delete(root)

          do_wilson(graph, unvisited, tree, [])
        end)

      {:ok, Result.new(edges, :wilson, map_size(graph.nodes))}
    end
  end

  defp do_wilson(graph, unvisited, tree, acc_edges) do
    if MapSet.size(unvisited) == 0 do
      acc_edges
    else
      start_node = Enum.random(unvisited)
      path_map = perform_lerw(graph, start_node, tree, %{})

      {new_tree, new_unvisited, path_edges} =
        add_path_to_tree(graph, start_node, path_map, tree, unvisited)

      do_wilson(graph, new_unvisited, new_tree, acc_edges ++ path_edges)
    end
  end

  # Performs a loop-erased random walk until hits tree
  defp perform_lerw(graph, current, tree, path_map) do
    if MapSet.member?(tree, current) do
      path_map
    else
      neighbors = Map.get(graph.out_edges, current, %{}) |> Map.keys()

      if neighbors == [] do
        path_map
      else
        next_node = Enum.random(neighbors)
        perform_lerw(graph, next_node, tree, Map.put(path_map, current, next_node))
      end
    end
  end

  # Follows the path from start until it hits the tree, updating tree/unvisited sets
  defp add_path_to_tree(graph, current, path_map, tree, unvisited) do
    if MapSet.member?(tree, current) do
      {tree, unvisited, []}
    else
      next_node = Map.get(path_map, current)
      weight = get_weight(graph, current, next_node)
      edge = %{from: current, to: next_node, weight: weight}

      new_tree = MapSet.put(tree, current)
      new_unvisited = MapSet.delete(unvisited, current)

      {final_tree, final_unvisited, rest_edges} =
        add_path_to_tree(graph, next_node, path_map, new_tree, new_unvisited)

      {final_tree, final_unvisited, [edge | rest_edges]}
    end
  end

  defp get_weight(graph, u, v) do
    Map.get(graph.out_edges[u], v, 1)
  end
end
