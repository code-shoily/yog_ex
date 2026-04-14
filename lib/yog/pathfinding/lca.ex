defmodule Yog.Pathfinding.LCA do
  @moduledoc """
  Lowest Common Ancestor (LCA) queries using binary lifting.

  This module preprocesses a tree in O(V log V) time to answer LCA queries
  and tree distance queries in O(log V) time per query.

  ## Algorithm

  1. BFS from the root to compute depth and immediate parent for each node.
  2. Build a binary lifting table where `up[k][v]` is the 2^k-th ancestor of v.
  3. Answer LCA queries by lifting the deeper node up, then lifting both
     nodes together until their ancestors differ.

  ## Complexity

  - **Preprocessing:** O(V log V)
  - **LCA Query:** O(log V)
  - **Distance Query:** O(log V)

  ## Example

      iex> tree =
      ...>   Yog.undirected()
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}, {2, 4, 1}, {2, 5, 1}])
      iex> {:ok, state} = Yog.Pathfinding.LCA.lca_preprocess(tree, 1)
      iex> Yog.Pathfinding.LCA.lca(state, 4, 5)
      {:ok, 2}
      iex> Yog.Pathfinding.LCA.tree_distance(state, 4, 3)
      {:ok, 3}

  ## References

  - https://cp-algorithms.com/graph/lca_binary_lifting.html
  """

  alias Yog.Graph

  defmodule State do
    @moduledoc """
    Preprocessed state for LCA queries.

    Fields:
    - `:root` - The root node used for preprocessing
    - `:max_log` - Maximum power of two needed (log2(V) rounded up)
    - `:depth` - Map of node -> depth from root
    - `:up` - Binary lifting table as `%{k => %{node => ancestor}}`
    - `:graph` - Reference to the original graph
    """

    defstruct [:root, :max_log, :depth, :up, :graph]

    @type t :: %__MODULE__{
            root: Yog.node_id(),
            max_log: pos_integer(),
            depth: %{Yog.node_id() => non_neg_integer()},
            up: %{non_neg_integer() => %{Yog.node_id() => Yog.node_id() | nil}},
            graph: Graph.t()
          }
  end

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Preprocesses the tree for LCA queries.

  Returns `{:ok, state}` on success, or `{:error, reason}` if the graph
  is not a valid tree connected at the given root.

  ## Errors

    * `{:error, :root_not_found}` - The root node does not exist in the graph
    * `{:error, :not_a_tree}` - The graph contains a cycle or is disconnected
  """
  @spec lca_preprocess(Graph.t(), Yog.node_id()) ::
          {:ok, State.t()} | {:error, :root_not_found | :not_a_tree}
  def lca_preprocess(%Graph{} = graph, root) do
    if Yog.Model.has_node?(graph, root) do
      case bfs_tree(graph, root) do
        {:ok, depth, parent_0} ->
          nodes = Yog.Model.all_nodes(graph)
          n = length(nodes)
          max_log = if n <= 1, do: 1, else: trunc(:math.log2(n)) + 1

          up = build_binary_lifting_table(parent_0, nodes, max_log)

          state = %State{
            root: root,
            max_log: max_log,
            depth: depth,
            up: up,
            graph: graph
          }

          {:ok, state}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :root_not_found}
    end
  end

  @doc """
  Returns the lowest common ancestor of two nodes.

  ## Errors

    * `{:error, :node_not_found}` - One or both nodes are not in the tree
  """
  @spec lca(State.t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, Yog.node_id()} | {:error, :node_not_found}
  def lca(%State{} = state, a, b) do
    with :ok <- validate_node(state, a),
         :ok <- validate_node(state, b) do
      {:ok, do_lca(state, a, b)}
    end
  end

  @doc """
  Calculates the tree distance (number of edges) between two nodes.

  Computed as `depth[a] + depth[b] - 2 * depth[lca]`.

  ## Errors

    * `{:error, :node_not_found}` - One or both nodes are not in the tree
  """
  @spec tree_distance(State.t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, non_neg_integer()} | {:error, :node_not_found}
  def tree_distance(%State{} = state, a, b) do
    with {:ok, ancestor} <- lca(state, a, b) do
      depth_a = Map.fetch!(state.depth, a)
      depth_b = Map.fetch!(state.depth, b)
      depth_lca = Map.fetch!(state.depth, ancestor)
      {:ok, depth_a + depth_b - 2 * depth_lca}
    end
  end

  # =============================================================================
  # Private helpers
  # =============================================================================

  defp validate_node(%State{depth: depth}, node) do
    if Map.has_key?(depth, node), do: :ok, else: {:error, :node_not_found}
  end

  defp do_lca(state, u, v) do
    {u, v} = order_by_depth(state, u, v)

    diff = state.depth[u] - state.depth[v]

    # Lift u to the same depth as v
    u_lifted =
      Enum.reduce((state.max_log - 1)..0//-1, u, fn k, acc_u ->
        if Bitwise.band(diff, Bitwise.bsl(1, k)) != 0 do
          ancestor_at(state, k, acc_u)
        else
          acc_u
        end
      end)

    if u_lifted == v do
      u_lifted
    else
      {u_final, _v_final} =
        Enum.reduce((state.max_log - 1)..0//-1, {u_lifted, v}, fn k, {acc_u, acc_v} ->
          pu = ancestor_at(state, k, acc_u)
          pv = ancestor_at(state, k, acc_v)

          if pu != pv and not is_nil(pu) and not is_nil(pv) do
            {pu, pv}
          else
            {acc_u, acc_v}
          end
        end)

      ancestor_at(state, 0, u_final)
    end
  end

  defp order_by_depth(state, u, v) do
    if state.depth[u] < state.depth[v] do
      {v, u}
    else
      {u, v}
    end
  end

  defp ancestor_at(_state, _k, nil), do: nil

  defp ancestor_at(state, k, v) do
    state.up |> Map.fetch!(k) |> Map.get(v)
  end

  defp build_binary_lifting_table(parent_0, nodes, max_log) do
    up_0 = Map.new(nodes, fn v -> {v, Map.get(parent_0, v)} end)

    Enum.reduce(1..(max_log - 1)//1, %{0 => up_0}, fn k, acc ->
      prev = acc[k - 1]

      next =
        Map.new(nodes, fn v ->
          p = Map.get(prev, v)
          ancestor = if p, do: Map.get(prev, p), else: nil
          {v, ancestor}
        end)

      Map.put(acc, k, next)
    end)
  end

  defp bfs_tree(graph, root) do
    q = :queue.in({root, 0, nil}, :queue.new())
    do_bfs_tree(graph, q, %{}, %{}, MapSet.new([root]))
  end

  defp do_bfs_tree(graph, q, depth, parent, visited) do
    case :queue.out(q) do
      {:empty, _} ->
        all_nodes = Yog.Model.all_nodes(graph)

        if length(all_nodes) == map_size(depth) do
          {:ok, depth, parent}
        else
          {:error, :not_a_tree}
        end

      {{:value, {node, d, par}}, rest} ->
        depth = Map.put(depth, node, d)
        parent = Map.put(parent, node, par)

        neighbors =
          case Yog.Model.successors(graph, node) do
            [] -> []
            succs -> Enum.map(succs, &elem(&1, 0))
          end

        cycle? = Enum.any?(neighbors, fn nb -> nb != par and MapSet.member?(visited, nb) end)

        if cycle? do
          {:error, :not_a_tree}
        else
          new_neighbors = Enum.reject(neighbors, &MapSet.member?(visited, &1))
          next_visited = Enum.reduce(new_neighbors, visited, &MapSet.put(&2, &1))

          next_q =
            Enum.reduce(new_neighbors, rest, fn nb, acc ->
              :queue.in({nb, d + 1, node}, acc)
            end)

          do_bfs_tree(graph, next_q, depth, parent, next_visited)
        end
    end
  end
end
