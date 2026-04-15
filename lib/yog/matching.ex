defmodule Yog.Matching do
  @moduledoc """
  Graph matching algorithms.

  This module provides algorithms for finding matchings in graphs.
  A matching is a set of edges without common vertices.

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Maximum bipartite matching | [Hopcroft-Karp](https://en.wikipedia.org/wiki/Hopcroft%E2%80%93Karp_algorithm) | `hopcroft_karp/1` | O(E√V) |

  ## Key Concepts

  - **Matching**: A set of edges with no shared vertices
  - **Maximum Matching**: A matching with the largest possible number of edges
  - **Perfect Matching**: Every vertex is matched (requires equal partitions)

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{:a1, :b1, 1}, {:a1, :b2, 1}, {:a2, :b2, 1}, {:a2, :b3, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      4
      iex> matching[:a1] in [:b1, :b2]
      true
      iex> matching[:a2] in [:b2, :b3]
      true
      iex> matching[:a1] != matching[:a2]
  """

  alias Yog.Graph
  alias Yog.Model
  alias Yog.Property.Bipartite

  @nil_key :__hopcroft_karp_nil__

  @doc """
  Finds a maximum cardinality matching in a bipartite graph using the
  Hopcroft-Karp algorithm.

  The algorithm repeatedly finds a maximal set of shortest vertex-disjoint
  augmenting paths via BFS layering, then augments the matching along each
  path via DFS. This yields O(E√V) time complexity, significantly faster
  than the naive O(VE) augmenting-path approach on dense graphs.

  Returns a bidirectional map where each matched pair appears twice
  (`u => v` and `v => u`) for easy lookup in either direction.

  Raises `ArgumentError` if the input graph is not bipartite.

  ## Examples

      # Simple path graph
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      4

      # Star graph
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      2

      # Complete bipartite K_{2,2}
      iex> graph = Yog.from_edges(:undirected, [{:a1, :b1, 1}, {:a1, :b2, 1}, {:a2, :b1, 1}, {:a2, :b2, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      4

      # Empty graph
      iex> matching = Yog.Matching.hopcroft_karp(Yog.undirected())
      iex> matching == %{}
      true

  ## Time Complexity

  O(E√V)
  """
  @spec hopcroft_karp(Graph.t()) :: %{Yog.node_id() => Yog.node_id()}
  def hopcroft_karp(%Graph{} = graph) do
    case Bipartite.partition(graph) do
      {:ok, %{left: left, right: right}} ->
        do_hopcroft_karp(graph, left, right)

      {:error, :not_bipartite} ->
        raise ArgumentError, "hopcroft_karp/1 requires a bipartite graph"
    end
  end

  defp do_hopcroft_karp(graph, left, right) do
    u_nodes = MapSet.to_list(left)
    v_nodes = MapSet.to_list(right)

    adj =
      Map.new(u_nodes, fn u ->
        neighbors = Model.neighbor_ids(graph, u)
        valid = Enum.filter(neighbors, fn v -> MapSet.member?(right, v) end)
        {u, valid}
      end)

    pair_u = Map.new(u_nodes, fn u -> {u, @nil_key} end)
    pair_v = Map.new(v_nodes, fn v -> {v, @nil_key} end)

    {final_pair_u, _final_pair_v} = hk_loop(adj, u_nodes, pair_u, pair_v)

    Enum.reduce(u_nodes, %{}, fn u, acc ->
      case Map.fetch!(final_pair_u, u) do
        @nil_key -> acc
        v -> acc |> Map.put(u, v) |> Map.put(v, u)
      end
    end)
  end

  defp hk_loop(adj, u_nodes, pair_u, pair_v) do
    {dist, found_aug} = bfs(adj, u_nodes, pair_u, pair_v)

    if found_aug do
      {new_pair_u, new_pair_v} = dfs_all(u_nodes, adj, pair_u, pair_v, dist)
      hk_loop(adj, u_nodes, new_pair_u, new_pair_v)
    else
      {pair_u, pair_v}
    end
  end

  defp bfs(adj, u_nodes, pair_u, pair_v) do
    dist =
      Enum.reduce(u_nodes, %{}, fn u, acc ->
        if Map.fetch!(pair_u, u) == @nil_key do
          Map.put(acc, u, 0)
        else
          Map.put(acc, u, :infinity)
        end
      end)
      |> Map.put(@nil_key, :infinity)

    queue = :queue.from_list(Enum.filter(u_nodes, fn u -> Map.fetch!(pair_u, u) == @nil_key end))

    do_bfs(queue, adj, pair_v, dist)
  end

  defp do_bfs(queue, adj, pair_v, dist) do
    case :queue.out(queue) do
      {:empty, _} ->
        {dist, Map.fetch!(dist, @nil_key) != :infinity}

      {{:value, u}, rest_q} ->
        if Map.fetch!(dist, u) < Map.fetch!(dist, @nil_key) do
          neighbors = Map.get(adj, u, [])

          {new_dist, new_q} =
            Enum.reduce(neighbors, {dist, rest_q}, fn v, {d, q} ->
              u2 = Map.fetch!(pair_v, v)

              if Map.fetch!(d, u2) == :infinity do
                d2 = Map.put(d, u2, Map.fetch!(d, u) + 1)
                q2 = :queue.in(u2, q)
                {d2, q2}
              else
                {d, q}
              end
            end)

          do_bfs(new_q, adj, pair_v, new_dist)
        else
          do_bfs(rest_q, adj, pair_v, dist)
        end
    end
  end

  defp dfs_all(u_nodes, adj, pair_u, pair_v, dist) do
    {new_pair_u, new_pair_v, _} =
      Enum.reduce(u_nodes, {pair_u, pair_v, dist}, fn u, {pu, pv, d} ->
        if Map.fetch!(pu, u) == @nil_key do
          case dfs(u, adj, pu, pv, d) do
            {true, new_pu, new_pv, new_dist} ->
              {new_pu, new_pv, new_dist}

            {false, new_pu, new_pv, new_dist} ->
              {new_pu, new_pv, Map.put(new_dist, u, :infinity)}
          end
        else
          {pu, pv, d}
        end
      end)

    {new_pair_u, new_pair_v}
  end

  defp dfs(@nil_key, _adj, pair_u, pair_v, dist) do
    {true, pair_u, pair_v, dist}
  end

  defp dfs(u, adj, pair_u, pair_v, dist) do
    neighbors = Map.get(adj, u, [])

    result =
      Enum.reduce_while(neighbors, {false, pair_u, pair_v, dist}, fn v, {_success, pu, pv, d} ->
        u2 = Map.fetch!(pv, v)

        if Map.fetch!(d, u2) == Map.fetch!(d, u) + 1 do
          case dfs(u2, adj, pu, pv, d) do
            {true, new_pu, new_pv, new_dist} ->
              new_pu2 = Map.put(new_pu, u, v)
              new_pv2 = Map.put(new_pv, v, u)
              {:halt, {true, new_pu2, new_pv2, new_dist}}

            {false, new_pu, new_pv, new_dist} ->
              {:cont, {false, new_pu, new_pv, new_dist}}
          end
        else
          {:cont, {false, pu, pv, d}}
        end
      end)

    case result do
      {true, _, _, _} -> result
      {false, pu, pv, d} -> {false, pu, pv, Map.put(d, u, :infinity)}
    end
  end
end
