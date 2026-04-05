defmodule Yog.Connectivity.KCore do
  @moduledoc """
  Algorithms for k-core decomposition.

  A [k-core](https://en.wikipedia.org/wiki/Degeneracy_(graph_theory)) is a maximal subgraph
  in which every node has at least degree `k`.

  ## Algorithms

  | Problem | Function | Complexity |
  |---------|----------|------------|
  | Find k-core | `detect/2` | O(V + E) |
  | Highest core number | `degeneracy/1` | O(V + E) |
  | All core numbers | `core_numbers/1` | O(V + E) |

  ## Key Concepts

  - **k-Core**: Maximal subgraph where min degree >= k.
  - **Core Number**: For a node v, the largest k such that v is in a k-core.
  - **Degeneracy**: The maximum core number found in the graph.
  - **Pruning**: The process of iteratively removing nodes with degree < k.

  ## Applications

  - **Community Detection**: Finding clusters of highly-connected nodes.
  - **Graph Robustness**: Measuring the resilience of a network.
  - **Search Space Reduction**: Pruning nodes that cannot participate in cliques of size k+1.
  - **Visualization**: Filtering out peripheral nodes.

  ## Examples

      # Square graph has 2-core (all of it), but no 3-core
      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_node(4, nil)
      ...>   |> Yog.add_edge_ensure(1, 2, 1)
      ...>   |> Yog.add_edge_ensure(2, 3, 1)
      ...>   |> Yog.add_edge_ensure(3, 4, 1)
      ...>   |> Yog.add_edge_ensure(4, 1, 1)
      iex> core_2 = Yog.Connectivity.KCore.detect(graph, 2)
      iex> Yog.node_count(core_2)
      4
      iex> core_3 = Yog.Connectivity.KCore.detect(graph, 3)
      iex> Yog.node_count(core_3)
      0
  """

  @doc """
  Detects the k-core of a graph.
  Returns the maximal subgraph where every node has at least degree `k`.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
      iex> Yog.Connectivity.KCore.detect(graph, 1)
      # Empty graph (no nodes with degree 1)
      iex> Yog.node_count(Yog.Connectivity.KCore.detect(graph, 1))
      0

  ## Time Complexity

  O(V + E)
  """
  @spec detect(Yog.graph(), integer()) :: Yog.graph()
  def detect(graph, k) when k >= 0 do
    out_edges = graph.out_edges
    nodes = Map.keys(graph.nodes)

    degrees_ =
      :maps.fold(
        fn u, inner, acc ->
          Map.put(acc, u, map_size(inner))
        end,
        %{},
        out_edges
      )

    # Ensure all nodes have degree entries
    degrees =
      :maps.fold(
        fn u, _, acc ->
          Map.put_new(acc, u, 0)
        end,
        degrees_,
        graph.nodes
      )

    to_prune =
      :maps.fold(
        fn u, deg, acc ->
          if deg < k, do: [u | acc], else: acc
        end,
        [],
        degrees
      )

    queue_set = MapSet.new(to_prune)

    pruned_nodes = do_prune(out_edges, to_prune, queue_set, degrees, k, MapSet.new())

    remaining = MapSet.difference(MapSet.new(nodes), pruned_nodes)
    Yog.subgraph(graph, MapSet.to_list(remaining))
  end

  defp do_prune(_, [], _, _, _, pruned), do: pruned

  defp do_prune(out_edges, [u | rest], queue_set, degrees, k, pruned) do
    queue_set = MapSet.delete(queue_set, u)

    if MapSet.member?(pruned, u) do
      do_prune(out_edges, rest, queue_set, degrees, k, pruned)
    else
      new_pruned = MapSet.put(pruned, u)

      case Map.fetch(out_edges, u) do
        {:ok, neighbors} ->
          {new_rest, new_queue_set, new_degrees} =
            :maps.fold(
              fn v, _, {acc_rest, acc_qs, acc_deg} ->
                if MapSet.member?(new_pruned, v) do
                  {acc_rest, acc_qs, acc_deg}
                else
                  new_deg = Map.fetch!(acc_deg, v) - 1
                  acc_deg = Map.put(acc_deg, v, new_deg)

                  if new_deg < k and not MapSet.member?(acc_qs, v) do
                    {[v | acc_rest], MapSet.put(acc_qs, v), acc_deg}
                  else
                    {acc_rest, acc_qs, acc_deg}
                  end
                end
              end,
              {rest, queue_set, degrees},
              neighbors
            )

          do_prune(out_edges, new_rest, new_queue_set, new_degrees, k, new_pruned)

        :error ->
          do_prune(out_edges, rest, queue_set, degrees, k, new_pruned)
      end
    end
  end

  @doc """
  Calculates all core numbers for all nodes in the graph.
  Core number of node v is the largest k such that v is in a k-core.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_edge_ensure(1, 2, 1)
      iex> Yog.Connectivity.KCore.core_numbers(graph)
      %{1 => 1, 2 => 1}
  """
  @spec core_numbers(Yog.graph()) :: %{Yog.node_id() => integer()}
  def core_numbers(graph) do
    out_edges = graph.out_edges

    degrees_ =
      :maps.fold(
        fn u, inner, acc ->
          Map.put(acc, u, map_size(inner))
        end,
        %{},
        out_edges
      )

    # Ensure all nodes are present
    degrees =
      :maps.fold(
        fn u, _, acc ->
          Map.put_new(acc, u, 0)
        end,
        degrees_,
        graph.nodes
      )

    max_deg =
      if degrees == %{} do
        0
      else
        degrees |> Map.values() |> Enum.max()
      end

    do_calculate_core_numbers(out_edges, degrees, max_deg)
  end

  defp do_calculate_core_numbers(out_edges, degrees, max_deg) do
    buckets =
      :maps.fold(
        fn u, deg, acc ->
          Map.update(acc, deg, [u], &[u | &1])
        end,
        %{},
        degrees
      )

    initial_state = {degrees, %{}, buckets, MapSet.new()}

    {_, cores, _, _} =
      Enum.reduce(0..max_deg, initial_state, fn i, acc_state ->
        process_bucket(out_edges, i, acc_state)
      end)

    cores
  end

  defp process_bucket(out_edges, i, {degs, cores, buckets, processed} = state) do
    case Map.get(buckets, i, []) do
      [] ->
        state

      [u | rest] ->
        if MapSet.member?(processed, u) do
          process_bucket(out_edges, i, {degs, cores, Map.put(buckets, i, rest), processed})
        else
          cores = Map.put(cores, u, i)
          processed = MapSet.put(processed, u)

          {new_degs, new_buckets} =
            case Map.fetch(out_edges, u) do
              {:ok, neighbors} ->
                :maps.fold(
                  fn v, _, {d_acc, b_acc} ->
                    if MapSet.member?(processed, v) do
                      {d_acc, b_acc}
                    else
                      old_v_deg = Map.fetch!(d_acc, v)
                      new_v_deg = old_v_deg - 1

                      d_acc = Map.put(d_acc, v, new_v_deg)

                      target_bucket = max(new_v_deg, i)
                      b_acc = Map.update(b_acc, target_bucket, [v], &[v | &1])

                      {d_acc, b_acc}
                    end
                  end,
                  {degs, Map.put(buckets, i, rest)},
                  neighbors
                )

              :error ->
                {degs, Map.put(buckets, i, rest)}
            end

          process_bucket(out_edges, i, {new_degs, cores, new_buckets, processed})
        end
    end
  end

  @doc """
  Finds the degeneracy of the graph, which is the maximum core number.
  """
  @spec degeneracy(Yog.graph()) :: integer()
  def degeneracy(graph) do
    core_numbers(graph) |> Map.values() |> Enum.max(fn -> 0 end)
  end

  @doc """
  Groups nodes into their respective k-shells.
  A k-shell contains nodes that have a core number of exactly k.
  """
  @spec shell_decomposition(Yog.graph()) :: %{integer() => [Yog.node_id()]}
  def shell_decomposition(graph) do
    graph
    |> core_numbers()
    |> Enum.group_by(fn {_node, core} -> core end, fn {node, _core} -> node end)
  end
end
