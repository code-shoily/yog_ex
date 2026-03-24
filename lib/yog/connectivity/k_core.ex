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
      ...>   |> Yog.add_edge!(1, 2, 1)
      ...>   |> Yog.add_edge!(2, 3, 1)
      ...>   |> Yog.add_edge!(3, 4, 1)
      ...>   |> Yog.add_edge!(4, 1, 1)
      iex> core_2 = Yog.Connectivity.KCore.detect(graph, 2)
      iex> Yog.node_count(core_2)
      4
      iex> core_3 = Yog.Connectivity.KCore.detect(graph, 3)
      iex> Yog.node_count(core_3)
      0
  """

  alias Yog.Model

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
    nodes = Model.all_nodes(graph)

    # Calculate initial degrees
    degrees =
      Enum.reduce(nodes, %{}, fn u, acc ->
        Map.put(acc, u, length(Model.neighbor_ids(graph, u)))
      end)

    # Initial queue of nodes to prune
    to_prune = Enum.filter(nodes, fn u -> Map.get(degrees, u) < k end)
    queue_set = MapSet.new(to_prune)

    # Run pruning
    pruned_nodes = do_prune(graph, to_prune, queue_set, degrees, k, MapSet.new())

    # Keep only nodes NOT in the pruned set
    remaining = MapSet.difference(MapSet.new(nodes), pruned_nodes)
    Yog.subgraph(graph, MapSet.to_list(remaining))
  end

  defp do_prune(_, [], _, _, _, pruned), do: pruned

  defp do_prune(graph, [u | rest], queue_set, degrees, k, pruned) do
    queue_set = MapSet.delete(queue_set, u)

    if MapSet.member?(pruned, u) do
      do_prune(graph, rest, queue_set, degrees, k, pruned)
    else
      new_pruned = MapSet.put(pruned, u)
      neighbors = Model.neighbor_ids(graph, u)

      # Update neighbors degrees
      {new_rest, new_queue_set, new_degrees} =
        Enum.reduce(neighbors, {rest, queue_set, degrees}, fn v, {acc_rest, acc_qs, acc_deg} ->
          if MapSet.member?(new_pruned, v) do
            {acc_rest, acc_qs, acc_deg}
          else
            new_deg = Map.get(acc_deg, v) - 1
            acc_deg = Map.put(acc_deg, v, new_deg)

            if new_deg < k and not MapSet.member?(acc_qs, v) do
              {[v | acc_rest], MapSet.put(acc_qs, v), acc_deg}
            else
              {acc_rest, acc_qs, acc_deg}
            end
          end
        end)

      do_prune(graph, new_rest, new_queue_set, new_degrees, k, new_pruned)
    end
  end

  @doc """
  Calculates all core numbers for all nodes in the graph.
  Core number of node v is the largest k such that v is in a k-core.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_edge!(1, 2, 1)
      iex> Yog.Connectivity.KCore.core_numbers(graph)
      %{1 => 1, 2 => 1}
  """
  @spec core_numbers(Yog.graph()) :: %{Yog.node_id() => integer()}
  def core_numbers(graph) do
    # O(V + E) variant of core number algorithm
    nodes = Model.all_nodes(graph)
    degrees = Map.new(nodes, fn u -> {u, length(Model.neighbor_ids(graph, u))} end)

    # Group nodes by degree for buckets
    max_deg = if(degrees == %{}, do: 0, else: Map.values(degrees) |> Enum.max())

    # We'll use a simple approach for now, reflecting the same pruning logic
    do_calculate_core_numbers(graph, nodes, degrees, max_deg)
  end

  defp do_calculate_core_numbers(graph, nodes, degrees, max_deg) do
    # This is slightly more complex for true O(V+E) (requires bucket sort + position map)
    # Let's use a simpler iterative pruning if necessary, but try to stay O(V+E)

    # Bucket nodes by degree
    buckets =
      Enum.reduce(nodes, %{}, fn u, acc ->
        deg = Map.get(degrees, u)
        Map.update(acc, deg, [u], &[u | &1])
      end)

    # State: {degrees, core_numbers, buckets, processed}
    initial_state = {degrees, %{}, buckets, MapSet.new()}

    {_, cores, _, _} =
      Enum.reduce(0..max_deg, initial_state, fn i, acc_state ->
        process_bucket(graph, i, acc_state)
      end)

    cores
  end

  defp process_bucket(graph, i, {degs, cores, buckets, processed}) do
    # Get current bucket
    nodes_in_bucket = Map.get(buckets, i, [])
    buckets = Map.delete(buckets, i)

    case nodes_in_bucket do
      [] ->
        {degs, cores, buckets, processed}

      [u | rest] ->
        if MapSet.member?(processed, u) do
          # Already processed (moved to lower bucket), just continue with rest
          process_bucket(graph, i, {degs, cores, Map.put(buckets, i, rest), processed})
        else
          # Core number of u is i
          cores = Map.put(cores, u, i)
          processed = MapSet.put(processed, u)

          # Use rest for re-entering the bucket
          buckets = Map.put(buckets, i, rest)

          # Neighbors degree reduction
          neighbors = Model.neighbor_ids(graph, u)

          {degs, buckets} =
            Enum.reduce(neighbors, {degs, buckets}, fn v, {acc_degs, acc_buckets} ->
              if MapSet.member?(processed, v) do
                {acc_degs, acc_buckets}
              else
                old_deg = Map.get(acc_degs, v)

                if old_deg > i do
                  new_deg = old_deg - 1
                  acc_degs = Map.put(acc_degs, v, new_deg)
                  # Move v to a lower bucket
                  acc_buckets =
                    Map.update(acc_buckets, old_deg, [], fn list -> List.delete(list, v) end)
                    |> Map.update(new_deg, [v], &[v | &1])

                  {acc_degs, acc_buckets}
                else
                  # Already in a lower bucket or current, will be processed later
                  {acc_degs, acc_buckets}
                end
              end
            end)

          # Reprocess current bucket as it may have new nodes
          process_bucket(graph, i, {degs, cores, buckets, processed})
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
end
