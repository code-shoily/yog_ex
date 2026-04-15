defmodule Yog.Pathfinding.ChinesePostman do
  @moduledoc """
  The [Chinese Postman Problem](https://en.wikipedia.org/wiki/Route_inspection_problem)
  (also known as the Route Inspection Problem).

  Finds the shortest closed walk that traverses every edge of an undirected graph
  at least once. For Eulerian graphs, this is simply the Eulerian circuit. For
  graphs with odd-degree vertices, the algorithm:

  1. Finds all odd-degree vertices
  2. Computes shortest paths between all pairs of odd vertices
  3. Finds a minimum-weight perfect matching on the odd vertices
  4. Duplicates the matched shortest-path edges to make the graph Eulerian
  5. Extracts an Eulerian circuit from the augmented multigraph

  ## Complexity

  - Finding odd vertices: O(V)
  - All-pairs shortest paths: O(k × (E + V log V)) where k = number of odd vertices
  - Minimum-weight perfect matching: O(k² × 2^k) via DP (efficient for small k)
  - Eulerian circuit: O(E)

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])
      iex> {:ok, _path, weight} = Yog.Pathfinding.ChinesePostman.chinese_postman(graph)
      iex> weight
      4
  """

  alias Yog.Graph
  alias Yog.Model
  alias Yog.Pathfinding.Dijkstra
  alias Yog.Pathfinding.Path, as: PathResult

  import Bitwise, only: [band: 2, bsr: 2, bsl: 2, bxor: 2]

  @doc """
  Solves the Chinese Postman Problem for an undirected graph.

  Returns `{:ok, path_nodes, total_weight}` where `path_nodes` is a closed walk
  covering every edge at least once, or `{:error, :no_solution}` if the graph is
  empty, directed, or disconnected.
  """
  @spec chinese_postman(Graph.t()) ::
          {:ok, [Yog.node_id()], number()} | {:error, :no_solution}
  def chinese_postman(%Graph{} = graph) do
    cond do
      Model.type(graph) != :undirected ->
        {:error, :no_solution}

      Model.all_nodes(graph) == [] ->
        {:error, :no_solution}

      not connected_ignoring_isolates?(graph) ->
        {:error, :no_solution}

      true ->
        solve(graph)
    end
  end

  # ==========================================================================
  # Main Solver
  # ==========================================================================

  defp solve(graph) do
    odd_vertices = find_odd_vertices(graph)
    original_weight = total_edge_weight(graph)

    if odd_vertices == [] do
      # Already Eulerian
      case Yog.Property.Eulerian.eulerian_circuit(graph) do
        {:ok, circuit} ->
          {:ok, circuit, original_weight}

        {:error, _} ->
          {:error, :no_solution}
      end
    else
      # Compute shortest paths between all pairs of odd vertices
      {distances, paths} = odd_vertex_distances(graph, odd_vertices)

      # Find minimum-weight perfect matching
      n = length(odd_vertices)
      matching_pairs = minimum_weight_perfect_matching(distances, n)

      # Build multigraph and duplicate matched paths
      multi = to_multigraph(graph)

      {augmented_multi, duplication_weight} =
        Enum.reduce(matching_pairs, {multi, 0}, fn {i, j}, {m, w} ->
          u = Enum.at(odd_vertices, i)
          v = Enum.at(odd_vertices, j)
          path_nodes = Map.fetch!(paths, {u, v})
          dist = distances[{i, j}]

          m2 = duplicate_path(m, path_nodes, graph)
          {m2, w + dist}
        end)

      # Extract Eulerian circuit
      case Yog.Multi.Eulerian.find_eulerian_circuit(augmented_multi) do
        {:ok, edge_ids} ->
          circuit = edge_ids_to_nodes(augmented_multi, edge_ids)
          {:ok, circuit, original_weight + duplication_weight}

        :error ->
          {:error, :no_solution}
      end
    end
  end

  # ==========================================================================
  # Helpers: Graph Properties
  # ==========================================================================

  defp find_odd_vertices(graph) do
    graph
    |> Model.all_nodes()
    |> Enum.filter(fn u -> rem(Model.degree(graph, u), 2) == 1 end)
  end

  defp total_edge_weight(graph) do
    graph
    |> Model.all_edges()
    |> Enum.reduce(0, fn {_, _, w}, acc -> acc + w end)
  end

  defp connected_ignoring_isolates?(graph) do
    non_isolated =
      Model.all_nodes(graph)
      |> Enum.filter(fn u -> Model.degree(graph, u) > 0 end)

    if non_isolated == [] do
      # Graph has only isolated vertices - treat as connected for CPP
      true
    else
      source = hd(non_isolated)
      visited = bfs_visited(graph, source)
      Enum.all?(non_isolated, &(&1 in visited))
    end
  end

  defp bfs_visited(graph, source) do
    do_bfs([source], MapSet.new([source]), graph)
  end

  defp do_bfs([], visited, _graph), do: MapSet.to_list(visited)

  defp do_bfs([current | queue], visited, graph) do
    neighbors = Model.neighbor_ids(graph, current)

    new_visited =
      Enum.reduce(neighbors, visited, fn n, acc ->
        if MapSet.member?(acc, n), do: acc, else: MapSet.put(acc, n)
      end)

    new_queue =
      queue ++ Enum.filter(neighbors, fn n -> not MapSet.member?(visited, n) end)

    do_bfs(new_queue, new_visited, graph)
  end

  # ==========================================================================
  # Helpers: Shortest Paths Between Odd Vertices
  # ==========================================================================

  defp odd_vertex_distances(graph, odd_vertices) do
    odd_vertices
    |> Enum.with_index()
    |> Enum.reduce({%{}, %{}}, fn {u, i}, {dist_acc, path_acc} ->
      # Run Dijkstra from u to all other odd vertices
      odd_vertices
      |> Enum.with_index()
      |> Enum.filter(fn {v, _} -> v != u end)
      |> Enum.reduce({dist_acc, path_acc}, fn {v, j}, {d_acc, p_acc} ->
        case Dijkstra.shortest_path(graph, u, v) do
          {:ok, %PathResult{nodes: nodes, weight: weight}} ->
            d_acc = Map.put(d_acc, {i, j}, weight)
            d_acc = Map.put(d_acc, {j, i}, weight)
            p_acc = Map.put(p_acc, {u, v}, nodes)
            p_acc = Map.put(p_acc, {v, u}, Enum.reverse(nodes))
            {d_acc, p_acc}

          :error ->
            # Should not happen in a connected graph
            {d_acc, p_acc}
        end
      end)
    end)
  end

  # ==========================================================================
  # Helpers: Minimum-Weight Perfect Matching (DP over subsets)
  # ==========================================================================

  defp minimum_weight_perfect_matching(distances, n) do
    full_mask = bsl(1, n) - 1

    {_dp_cost, dp_pair} =
      Enum.reduce(1..full_mask//1, {%{0 => 0}, %{}}, fn mask, {costs, pairs} ->
        if rem(popcount(mask), 2) == 1 do
          {costs, pairs}
        else
          i = first_set_bit(mask)

          {best_cost, best_j} =
            (i + 1)..(n - 1)//1
            |> Enum.filter(fn j -> bit_set?(mask, j) end)
            |> Enum.reduce({nil, nil}, fn j, {best, best_j} ->
              prev = bxor(bxor(mask, bsl(1, i)), bsl(1, j))
              cost = costs[prev] + distances[{i, j}]

              if is_nil(best) or cost < best do
                {cost, j}
              else
                {best, best_j}
              end
            end)

          costs = Map.put(costs, mask, best_cost)
          pairs = Map.put(pairs, mask, {i, best_j})
          {costs, pairs}
        end
      end)

    reconstruct_matching(full_mask, dp_pair, [])
  end

  defp reconstruct_matching(0, _pairs, acc), do: acc

  defp reconstruct_matching(mask, pairs, acc) do
    {i, j} = Map.fetch!(pairs, mask)
    prev = bxor(bxor(mask, bsl(1, i)), bsl(1, j))
    reconstruct_matching(prev, pairs, [{i, j} | acc])
  end

  defp popcount(0), do: 0
  defp popcount(x), do: 1 + popcount(band(x, x - 1))

  defp first_set_bit(mask) do
    if band(mask, 1) == 1 do
      0
    else
      1 + first_set_bit(bsr(mask, 1))
    end
  end

  defp bit_set?(mask, i), do: band(mask, bsl(1, i)) != 0

  # ==========================================================================
  # Helpers: Multigraph Construction & Edge Duplication
  # ==========================================================================

  defp to_multigraph(graph) do
    multi = Yog.Multi.Model.undirected()

    multi_with_nodes =
      Enum.reduce(Model.all_nodes(graph), multi, fn u, m ->
        Yog.Multi.Model.add_node(m, u, Model.node(graph, u))
      end)

    Enum.reduce(Model.all_edges(graph), multi_with_nodes, fn {u, v, w}, m ->
      {m2, _eid} = Yog.Multi.Model.add_edge(m, u, v, w)
      m2
    end)
  end

  defp duplicate_path(multi, path_nodes, original_graph) do
    path_nodes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(multi, fn [u, v], m ->
      w = edge_weight(original_graph, u, v)
      {m2, _eid} = Yog.Multi.Model.add_edge(m, u, v, w)
      m2
    end)
  end

  defp edge_weight(graph, u, v) do
    graph.out_edges
    |> Map.get(u, %{})
    |> Map.get(v, 1)
  end

  # ==========================================================================
  # Helpers: Convert Multigraph Edge IDs to Node Walk
  # ==========================================================================

  defp edge_ids_to_nodes(_multi, []), do: []

  defp edge_ids_to_nodes(multi, [first | rest]) do
    {a, b, _} = Map.fetch!(multi.edges, first)

    {_, nodes_rev} =
      Enum.reduce(rest, {b, [b, a]}, fn eid, {prev, acc} ->
        {x, y, _} = Map.fetch!(multi.edges, eid)
        next = if x == prev, do: y, else: x
        {next, [next | acc]}
      end)

    Enum.reverse(nodes_rev)
  end
end
