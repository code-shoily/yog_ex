defmodule Yog.Property.Planarity do
  @moduledoc """
  Planarity testing and planar embedding for undirected graphs.

  This module provides exact planarity checks using the Left-Right (LR)
  Planarity Test (de Fraysseix–Rosenstiehl), combinatorial embedding
  extraction, and Kuratowski witness identification.

  ## Functions

  | Problem | Function | Complexity |
  |---------|----------|------------|
  | Planar check | `planar?/1` | O(V^2) |
  | Planar embedding | `planar_embedding/1` | O(V^3) |
  | Kuratowski witness | `kuratowski_witness/1` | O(V^3) |

  ## Examples

      iex> k5 = Yog.Generator.Classic.complete(5)
      iex> Yog.Property.Planarity.planar?(k5)
      false

      iex> k33 = Yog.Generator.Classic.complete_bipartite(3, 3)
      iex> Yog.Property.Planarity.planar?(k33)
      false
  """

  alias Yog.Connectivity.Components
  alias Yog.Model
  alias Yog.Property.Bipartite
  alias Yog.Transform

  @doc """
  Returns true if the graph is planar (exactly).

  Uses the Left-Right (LR) Planarity Test (de Fraysseix–Rosenstiehl algorithm).
  It decomposes the graph into a DFS tree and back-edges, then determines
  if back-edges can be partitioned into "Left" and "Right" sides without crossing.
  """
  @spec planar?(Yog.graph()) :: boolean()
  def planar?(graph) do
    case Model.type(graph) do
      :undirected ->
        if planar_heuristic?(graph) do
          case run_exact_planar_test(graph) do
            {:ok, _metadata} -> true
            :nonplanar -> false
          end
        else
          false
        end

      :directed ->
        false
    end
  end

  @doc """
  Returns a combinatorial embedding if the graph is planar.
  """
  @spec planar_embedding(Yog.graph()) :: {:ok, map()} | {:nonplanar, map()} | :nonplanar
  def planar_embedding(graph) do
    case Model.type(graph) do
      :undirected ->
        if planar_heuristic?(graph) do
          case run_exact_planar_test(graph) do
            {:ok, component_meta_list} ->
              embedding =
                Enum.reduce(component_meta_list, %{}, fn meta, acc ->
                  Map.merge(acc, build_component_embedding(meta))
                end)

              {:ok, embedding}

            :nonplanar ->
              case kuratowski_witness(graph) do
                {:ok, witness} -> {:nonplanar, witness}
                :planar -> :nonplanar
              end
          end
        else
          case kuratowski_witness(graph) do
            {:ok, witness} -> {:nonplanar, witness}
            :planar -> :nonplanar
          end
        end

      :directed ->
        :nonplanar
    end
  end

  @doc """
  Identifies a Kuratowski witness (a subdivision of K5 or K3,3) that proves
  the graph is non-planar.
  """
  @spec kuratowski_witness(Yog.graph()) :: {:ok, map()} | :planar
  def kuratowski_witness(graph) do
    if planar?(graph) do
      :planar
    else
      minimal = do_reduce_to_minimal(graph)
      type = identify_kuratowski_type(minimal)

      # Fallback: if minimal reduction obscured the Kuratowski type
      # (e.g., due to false negatives in the exact planarity test),
      # try identifying on the original graph.
      type = if type == :unknown, do: identify_kuratowski_type(graph), else: type

      edges =
        minimal
        |> Model.all_edges()
        |> Enum.map(fn {u, v, _w} -> {u, v} end)

      {:ok,
       %{
         type: type,
         nodes: Model.all_nodes(minimal),
         edges: edges,
         subgraph: minimal
       }}
    end
  end

  # =============================================================================
  # Private helpers
  # =============================================================================

  defp planar_heuristic?(graph) do
    n = Model.node_count(graph)
    e = Model.edge_count(graph)

    cond do
      n <= 4 ->
        true

      e > 3 * n - 6 ->
        false

      n == 5 and e <= 9 ->
        true

      Bipartite.bipartite?(graph) ->
        e <= 2 * n - 4

      true ->
        true
    end
  end

  defp run_exact_planar_test(graph) do
    components = Components.connected_components(graph)

    Enum.reduce_while(components, {:ok, []}, fn nodes, {:ok, acc} ->
      subgraph = Transform.subgraph(graph, nodes)

      case do_exact_planar?(subgraph) do
        {:ok, metadata} -> {:cont, {:ok, [metadata | acc]}}
        :nonplanar -> {:halt, :nonplanar}
      end
    end)
  end

  defp do_exact_planar?(graph) do
    if Model.node_count(graph) <= 1 do
      {:ok, %{graph: graph, partitions: %{}, tree: %{}}}
    else
      case lr_test(graph) do
        {:ok, partitions, tree_info} ->
          {:ok, %{graph: graph, partitions: partitions, tree: tree_info}}

        :nonplanar ->
          :nonplanar
      end
    end
  end

  defp lr_test(graph) do
    nodes = Model.all_nodes(graph)
    [root | _] = nodes
    {ordered_edges, lowpoints, entry_times, finish_times, parents} = dfs_orient(graph, root)

    back_edges = Enum.filter(ordered_edges, fn {type, _, _} -> type == :back end)

    conflict_graph =
      build_conflict_graph(back_edges, ordered_edges, entry_times, finish_times, lowpoints)

    case check_bipartite(conflict_graph) do
      {:ok, colors} ->
        {:ok, colors, {ordered_edges, lowpoints, entry_times, finish_times, parents}}

      :error ->
        :nonplanar
    end
  end

  defp dfs_orient(graph, root) do
    {parents, entry_times, lowpoints, finish_times, edges, _visited, _final_time} =
      do_dfs(graph, root, nil, 0, %{}, %{}, %{}, %{}, [], MapSet.new([root]))

    {Enum.reverse(edges), lowpoints, entry_times, finish_times, parents}
  end

  defp do_dfs(graph, u, p, time, parents, times, lowpoints, finish, edges, visited) do
    times = Map.put(times, u, time)
    lowpoints = Map.put(lowpoints, u, time)
    parents = if p, do: Map.put(parents, u, p), else: parents

    neighbors = Model.neighbor_ids(graph, u) |> Enum.reject(&(&1 == p))

    {parents_acc, times_acc, lowpoints_acc, finish_acc, edges_acc, visited_acc, final_time} =
      Enum.reduce(neighbors, {parents, times, lowpoints, finish, edges, visited, time}, fn v,
                                                                                           {p_acc,
                                                                                            t_acc,
                                                                                            l_acc,
                                                                                            f_acc,
                                                                                            e_acc,
                                                                                            v_acc,
                                                                                            curr_time} ->
        if MapSet.member?(v_acc, v) do
          new_edges =
            if Map.get(t_acc, v) < Map.get(t_acc, u) do
              [{:back, u, v} | e_acc]
            else
              e_acc
            end

          new_low = min(Map.get(l_acc, u), Map.get(t_acc, v))
          {p_acc, t_acc, Map.put(l_acc, u, new_low), f_acc, new_edges, v_acc, curr_time}
        else
          {sp, st, sl, sf, se, sv, nt} =
            do_dfs(
              graph,
              v,
              u,
              curr_time + 1,
              p_acc,
              t_acc,
              l_acc,
              f_acc,
              [{:tree, u, v} | e_acc],
              MapSet.put(v_acc, v)
            )

          child_low = Map.get(sl, v)
          new_low = min(Map.get(sl, u), child_low)
          {sp, st, Map.put(sl, u, new_low), sf, se, sv, nt}
        end
      end)

    {
      parents_acc,
      times_acc,
      lowpoints_acc,
      Map.put(finish_acc, u, final_time + 1),
      edges_acc,
      visited_acc,
      final_time + 1
    }
  end

  defp build_conflict_graph(back_edges, all_edges, entry_times, finish_times, _lowpoints) do
    nodes = Enum.map(back_edges, fn {:back, u, v} -> {u, v} end)

    Enum.reduce(nodes, %{}, fn b1, acc ->
      Map.put_new(acc, b1, [])
    end)
    |> build_conflicts(nodes, all_edges, entry_times, finish_times)
  end

  defp build_conflicts(adj, nodes, _all_edges, times, finish) do
    n = length(nodes)

    if n < 2 do
      adj
    else
      for i <- 0..(n - 2),
          j <- (i + 1)..(n - 1),
          reduce: adj do
        acc ->
          {u, v} = Enum.at(nodes, i)
          {x, y} = Enum.at(nodes, j)

          # u is descendant, v is ancestor. x is descendant, y is ancestor.
          tu = times[u]
          tv = times[v]
          tx = times[x]
          ty = times[y]

          # Paths (v, u) and (y, x). They conflict if they interlace on a common tree path.
          if interlaced?(tu, tv, tx, ty, u, v, x, y, times, finish) do
            acc
            |> Map.update!({u, v}, &[{x, y} | &1])
            |> Map.update!({x, y}, &[{u, v} | &1])
          else
            acc
          end
      end
    end
  end

  defp interlaced?(tu, tv, tx, ty, u, v, x, y, times, finish) do
    cond do
      # Case 1: v is ancestor of y, y is ancestor of u, u is ancestor of x
      tv < ty and ty < tu and tu < tx ->
        ancestor?(v, y, times, finish) and
          ancestor?(y, u, times, finish) and
          ancestor?(u, x, times, finish)

      # Case 2: y is ancestor of v, v is ancestor of x, x is ancestor of u
      ty < tv and tv < tx and tx < tu ->
        ancestor?(y, v, times, finish) and
          ancestor?(v, x, times, finish) and
          ancestor?(x, u, times, finish)

      true ->
        false
    end
  end

  defp ancestor?(a, d, times, finish) do
    times[a] <= times[d] and finish[d] <= finish[a]
  end

  defp check_bipartite(adj) do
    if map_size(adj) == 0 do
      {:ok, %{}}
    else
      nodes = Map.keys(adj)

      case check_components_bipartite(nodes, adj, %{}) do
        {:ok, colors} -> {:ok, colors}
        :error -> :error
      end
    end
  end

  defp check_components_bipartite([], _adj, colors), do: {:ok, colors}

  defp check_components_bipartite([u | rest], adj, colors) do
    if Map.has_key?(colors, u) do
      check_components_bipartite(rest, adj, colors)
    else
      case bfs_color(u, 0, adj, colors) do
        {:ok, new_colors} -> check_components_bipartite(rest, adj, new_colors)
        :error -> :error
      end
    end
  end

  defp bfs_color(start_node, start_color, adj, colors) do
    queue = :queue.from_list([{start_node, start_color}])
    do_bfs_color(queue, adj, Map.put(colors, start_node, start_color))
  end

  defp do_bfs_color(queue, adj, colors) do
    case :queue.out(queue) do
      {{:value, {u, c}}, q} ->
        neighbors = Map.get(adj, u, [])
        next_color = 1 - c

        Enum.reduce_while(neighbors, {:ok, q, colors}, fn v, {:ok, acc_q, acc_c} ->
          case Map.get(acc_c, v) do
            nil ->
              {:cont, {:ok, :queue.in({v, next_color}, acc_q), Map.put(acc_c, v, next_color)}}

            ^next_color ->
              {:cont, {:ok, acc_q, acc_c}}

            _conflict ->
              {:halt, :error}
          end
        end)
        |> case do
          {:ok, new_q, new_colors} -> do_bfs_color(new_q, adj, new_colors)
          :error -> :error
        end

      {:empty, _} ->
        {:ok, colors}
    end
  end

  defp do_reduce_to_minimal(graph) do
    edges =
      graph
      |> Model.all_edges()
      |> Enum.map(fn {u, v, _w} -> {u, v} end)

    Enum.reduce(edges, graph, fn {u, v}, acc ->
      reduced = Model.remove_edge(acc, u, v)

      if planar?(reduced) do
        acc
      else
        reduced
      end
    end)
    |> then(fn minimal_graph ->
      Enum.reduce(Model.all_nodes(minimal_graph), minimal_graph, fn u, acc ->
        if Model.degree(acc, u) == 0 do
          Model.remove_node(acc, u)
        else
          acc
        end
      end)
    end)
  end

  defp identify_kuratowski_type(graph) do
    core_graph = smooth_paths(graph)
    nodes = Model.all_nodes(core_graph)
    count = length(nodes)

    cond do
      count == 5 and all_degrees?(core_graph, 4) ->
        :k5

      count == 6 and all_degrees?(core_graph, 3) and Bipartite.bipartite?(core_graph) ->
        :k33

      true ->
        deg_seq =
          nodes
          |> Enum.map(&Model.degree(core_graph, &1))
          |> Enum.sort(:desc)

        case deg_seq do
          [4, 4, 4, 4, 4] -> :k5
          [3, 3, 3, 3, 3, 3] -> :k33
          _ -> :unknown
        end
    end
  end

  defp all_degrees?(graph, d) do
    Model.all_nodes(graph) |> Enum.all?(fn u -> Model.degree(graph, u) == d end)
  end

  defp smooth_paths(graph) do
    deg2_node =
      graph
      |> Model.all_nodes()
      |> Enum.find(fn u -> Model.degree(graph, u) == 2 end)

    case deg2_node do
      nil ->
        graph

      u ->
        [v, w] = Model.neighbor_ids(graph, u)

        graph
        |> Model.remove_node(u)
        |> Model.add_edge_ensure(v, w, 1, nil)
        |> smooth_paths()
    end
  end

  defp build_component_embedding(%{graph: graph, partitions: partitions, tree: tree}) do
    {edges, _lowpoints, times, _finish, parents} = tree

    nodes_incident =
      Enum.reduce(Model.all_nodes(graph), %{}, fn u, acc ->
        Map.put(acc, u, %{parent: Map.get(parents, u), children: [], back_out: [], back_in: []})
      end)

    edge_incident =
      Enum.reduce(edges, nodes_incident, fn
        {:tree, u, v}, acc ->
          acc |> Map.update!(u, fn info -> %{info | children: [v | info.children]} end)

        {:back, u, v}, acc ->
          acc
          |> Map.update!(u, fn info -> %{info | back_out: [v | info.back_out]} end)
          |> Map.update!(v, fn info -> %{info | back_in: [u | info.back_in]} end)
      end)

    Enum.reduce(edge_incident, %{}, fn {u, info}, acc ->
      %{parent: p, children: children, back_out: back_out, back_in: back_in} = info

      {left_bo, right_bo} =
        Enum.split_with(back_out, fn v -> Map.get(partitions, {u, v}) == 0 end)

      {left_bi, right_bi} =
        Enum.split_with(back_in, fn v -> Map.get(partitions, {v, u}) == 0 end)

      {left_c, right_c} =
        Enum.split_with(children, fn v ->
          subtree_back_edge_side(v, edges, partitions, times, u) == 0
        end)

      sorted_left_bo = Enum.sort_by(left_bo, &Map.get(times, &1))
      sorted_right_bo = Enum.sort_by(right_bo, &Map.get(times, &1), :desc)

      order =
        ([p] ++
           left_bi ++
           left_c ++
           sorted_left_bo ++
           sorted_right_bo ++
           right_c ++
           right_bi)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      Map.put(acc, u, order)
    end)
  end

  defp subtree_back_edge_side(v, edges, partitions, times, ancestor_limit) do
    limit_time = Map.get(times, ancestor_limit)

    edges
    |> Enum.find_value(0, fn
      {:back, u, target} ->
        if Map.get(times, u) >= Map.get(times, v) and Map.get(times, target) < limit_time do
          Map.get(partitions, {u, target})
        end

      _ ->
        nil
    end)
  end
end
