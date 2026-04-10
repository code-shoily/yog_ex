defmodule Yog.Pathfinding.Brandes do
  @moduledoc """
  Ulrik Brandes' algorithm for betweenness centrality.

  This module provides the core building blocks for computing node and edge
  betweenness centrality. The algorithm consists of two phases:
  1. **Discovery**: A Dijkstra-like breadth-first search to find shortest paths.
  2. **Accumulation**: A back-propagation phase to calculate dependencies.

  ## Reference

  Brandes, U. (2001). A faster algorithm for betweenness centrality.
  Journal of Mathematical Sociology, 25(2), 163-177.
  """

  alias Yog.PairingHeap, as: PQ

  @type discovery_result ::
          {[Yog.node_id()], %{Yog.node_id() => [Yog.node_id()]}, %{Yog.node_id() => number()}}

  @doc """
  Runs the discovery phase of Brandes' algorithm.

  Returns a tuple `{stack, predecessors, sigmas}`:
  - `stack`: Nodes in non-decreasing order of distance.
  - `predecessors`: A map from node to a list of its predecessors on all shortest paths.
  - `sigmas`: A map from node to the number of shortest paths from source to it.
  """
  @spec discovery(
          Yog.graph(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: discovery_result()
        when weight: var
  def discovery(
        graph,
        source,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    # Use a priority queue for weighted graphs
    pq = PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
    queue = PQ.push(pq, {zero, source})

    dist = %{source => zero}
    sigma = %{source => 1}
    preds = %{}
    stack = []

    do_brandes_loop(graph, queue, dist, sigma, preds, stack, add, compare)
  end

  defp do_brandes_loop(graph, pq, dist, sigma, preds, stack, add, compare) do
    case PQ.pop(pq) do
      :error ->
        {stack, preds, sigma}

      {:ok, {d_v, v}, rest_q} ->
        maybe_visit_node(graph, v, d_v, rest_q, dist, sigma, preds, stack, add, compare)
    end
  end

  defp maybe_visit_node(graph, v, d_v, rest_q, dist, sigma, preds, stack, add, compare) do
    current_best = Map.get(dist, v)

    if not is_nil(current_best) and compare.(d_v, current_best) == :gt do
      do_brandes_loop(graph, rest_q, dist, sigma, preds, stack, add, compare)
    else
      visit_node(graph, v, d_v, rest_q, dist, sigma, preds, stack, add, compare)
    end
  end

  defp visit_node(graph, v, d_v, rest_q, dist, sigma, preds, stack, add, compare) do
    successors = Map.get(graph.out_edges, v, %{})

    {new_q, new_dist, new_sigma, new_preds} =
      Enum.reduce(successors, {rest_q, dist, sigma, preds}, fn {w, weight}, acc ->
        relax_neighbor(acc, v, d_v, w, weight, add, compare)
      end)

    do_brandes_loop(graph, new_q, new_dist, new_sigma, new_preds, [v | stack], add, compare)
  end

  defp relax_neighbor({q, ds, ss, ps}, v, d_v, w, weight, add, compare) do
    # Handle optional weights
    weight_val = if is_nil(weight), do: 1, else: weight
    new_dist_w = add.(d_v, weight_val)
    old_dist_w = Map.get(ds, w)

    cond do
      is_nil(old_dist_w) or compare.(new_dist_w, old_dist_w) == :lt ->
        # Found a strictly shorter path
        sigma_v = Map.get(ss, v, 0)

        {
          PQ.push(q, {new_dist_w, w}),
          Map.put(ds, w, new_dist_w),
          Map.put(ss, w, sigma_v),
          Map.put(ps, w, [v])
        }

      compare.(new_dist_w, old_dist_w) == :eq ->
        # Found an alternative path of the same length
        sigma_v = Map.get(ss, v, 0)
        new_ss = Map.update(ss, w, sigma_v, &(&1 + sigma_v))
        new_ps = Map.update(ps, w, [v], &[v | &1])
        {q, ds, new_ss, new_ps}

      true ->
        # Path is longer, ignore
        {q, ds, ss, ps}
    end
  end

  @doc """
  Accumulates node dependencies for betweenness calculation.

  Returns a map of node IDs to their dependency scores.
  """
  @spec accumulate_node_dependencies([Yog.node_id()], %{Yog.node_id() => [Yog.node_id()]}, %{
          Yog.node_id() => number()
        }) :: %{Yog.node_id() => float()}
  def accumulate_node_dependencies(stack, preds, sigmas) do
    Enum.reduce(stack, %{}, fn v, deltas ->
      sigma_v = Map.get(sigmas, v, 0)
      delta_v = Map.get(deltas, v, 0.0)
      v_preds = Map.get(preds, v, [])

      Enum.reduce(v_preds, deltas, fn u, acc_deltas ->
        sigma_u = Map.get(sigmas, u, 0)
        fraction = sigma_u / sigma_v * (1.0 + delta_v)
        Map.update(acc_deltas, u, fraction, &(&1 + fraction))
      end)
    end)
  end

  @doc """
  Accumulates edge dependencies for betweenness calculation.

  Returns a map of `{u, v}` pairs (where u < v) to their dependency scores.
  """
  @spec accumulate_edge_dependencies([Yog.node_id()], %{Yog.node_id() => [Yog.node_id()]}, %{
          Yog.node_id() => number()
        }) :: %{{Yog.node_id(), Yog.node_id()} => float()}
  def accumulate_edge_dependencies(stack, preds, sigmas) do
    {_node_deltas, edge_deltas} =
      Enum.reduce(stack, {%{}, %{}}, fn v, {node_deltas, edge_deltas} ->
        sigma_v = Map.get(sigmas, v, 0) * 1.0
        delta_v = Map.get(node_deltas, v, 0.0)
        v_preds = Map.get(preds, v, [])

        Enum.reduce(v_preds, {node_deltas, edge_deltas}, fn u, {nd, ed} ->
          sigma_u = Map.get(sigmas, u, 0) * 1.0
          c = sigma_u / sigma_v * (1.0 + delta_v)

          # Use consistent undirected edge key order
          edge = if u < v, do: {u, v}, else: {v, u}

          new_nd = Map.update(nd, u, c, &(&1 + c))
          new_ed = Map.update(ed, edge, c, &(&1 + c))
          {new_nd, new_ed}
        end)
      end)

    edge_deltas
  end
end
