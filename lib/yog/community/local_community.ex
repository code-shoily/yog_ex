defmodule Yog.Community.LocalCommunity do
  @moduledoc """
  Local community detection using fitness maximization.

  This module implements a local community detection algorithm that starts
  from a set of seed nodes and iteratively expands (or shrinks) the community
  to maximize a local fitness function. It is particularly useful for extracting
  the community surrounding a specific node without calculating the global
  community structure of the entire graph, making it efficient for massive or
  infinite (implicit) graphs.

  ## Algorithm

  The fitness function used is based on Lancichinetti et al. (2009):

      f(S) = k_in / (k_in + k_out)^alpha

  where:
  - `k_in` is the sum of internal degrees (twice the internal edge weights)
  - `k_out` is the sum of external degrees (edges to outside S)
  - `alpha` is a resolution parameter controlling community size

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Focus on specific node's neighborhood | ✓ Ideal |
  | Massive graphs | ✓ Only explores local region |
  | Streaming/infinite graphs | ✓ No full graph scan needed |
  | Global community structure | Use Louvain instead |

  ## Example

      # Find the local community around node 5
      community = Yog.Community.LocalCommunity.detect(graph, seeds: [5])
      # Returns a MapSet containing node IDs in the local community

      # With custom options
      options = [alpha: 0.8, max_iterations: 500]
      community = Yog.Community.LocalCommunity.detect_with_options(graph, [5], options)

  ## References

  - Lancichinetti et al. (2009). Detecting the overlapping and hierarchical community structure.
  - Clauset, A. (2005). Finding local community structure in networks.
  """

  use Yog.Algorithm

  @typedoc "Options for local community detection"
  @type local_options :: %{
          alpha: float(),
          max_iterations: integer()
        }

  @doc """
  Returns default options for local community detection.

  - `alpha`: 1.0 (resolution parameter)
  - `max_iterations`: 1000
  """
  @spec default_options() :: local_options()
  def default_options do
    %{
      alpha: 1.0,
      max_iterations: 1000
    }
  end

  @doc """
  Detects a local community starting from a list of seed nodes using default options.

  ## Example

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1, default: nil) |> Yog.add_edge_ensure(2, 3, 1, default: nil)
      iex> community = Yog.Community.LocalCommunity.detect(graph, seeds: [2])
      iex> MapSet.member?(community, 2)
      true
  """
  @spec detect(Yog.graph(), seeds: [Yog.node_id()]) :: MapSet.t(Yog.node_id())
  def detect(graph, seeds: seeds) do
    detect_with(graph, seeds, default_options(), fn _ -> 1.0 end)
  end

  @doc """
  Detects a local community from seeds with custom options.

  ## Options

    * `:alpha` - Resolution parameter (default: 1.0). Larger values yield smaller communities.
    * `:max_iterations` - Maximum iterations (default: 1000)

  ## Example

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1, default: nil) |> Yog.add_edge_ensure(2, 3, 1, default: nil)
      iex> opts = [alpha: 0.5, max_iterations: 100]
      iex> community = Yog.Community.LocalCommunity.detect_with_options(graph, [2], opts)
      iex> MapSet.member?(community, 2)
      true
  """
  @spec detect_with_options(Yog.graph(), [Yog.node_id()], keyword()) :: MapSet.t(Yog.node_id())
  def detect_with_options(graph, seeds, opts) do
    options = %{
      alpha: Keyword.get(opts, :alpha, 1.0),
      max_iterations: Keyword.get(opts, :max_iterations, 1000)
    }

    detect_with(graph, seeds, options, fn _ -> 1.0 end)
  end

  @doc """
  Detects a local community from seeds using a specific weight function.

  The weight function transforms edge weights to floats for calculations.
  """
  @spec detect_with(Yog.graph(), [Yog.node_id()], local_options(), (any() -> float())) ::
          MapSet.t(Yog.node_id())
  def detect_with(graph, seeds, options, weight_fn) do
    seeds_set = MapSet.new(seeds)
    initial_s = seeds_set

    # Compute initial degrees
    {k_in, k_out} = compute_k_out_in(graph, initial_s, weight_fn)

    {frontier, internal_weights} = initialize_frontier_and_weights(graph, initial_s, weight_fn)

    # Start with empty degrees cache
    degrees_cache = %{}

    do_detect(
      graph,
      initial_s,
      k_in,
      k_out,
      frontier,
      internal_weights,
      degrees_cache,
      options,
      0,
      weight_fn,
      seeds_set
    )
  end

  # ============================================================
  # Private Functions
  # ============================================================

  defp compute_k_out_in(graph, s, weight_fn) do
    Enum.reduce(s, {0.0, 0.0}, fn node, {k_in_acc, k_out_acc} ->
      Model.successors(graph, node)
      |> Enum.reduce({k_in_acc, k_out_acc}, fn {neighbor_id, w}, {kin, kout} ->
        w_float = weight_fn.(w)

        if MapSet.member?(s, neighbor_id) do
          {kin + w_float, kout}
        else
          {kin, kout + w_float}
        end
      end)
    end)
  end

  defp initialize_frontier_and_weights(graph, s, weight_fn) do
    Enum.reduce(s, {MapSet.new(), %{}}, fn node, {frontier_acc, weights_acc} ->
      Model.successors(graph, node)
      |> Enum.reduce({frontier_acc, weights_acc}, fn {neighbor_id, w}, {front, wacc} ->
        w_float = weight_fn.(w)

        if MapSet.member?(s, neighbor_id) do
          # Internal edge - update internal weight cache (only for nodes in S)
          new_wacc = Map.update(wacc, node, w_float, &(&1 + w_float))
          {front, new_wacc}
        else
          # External edge - add to frontier AND update internal weight of frontier node
          new_front = MapSet.put(front, neighbor_id)
          # The internal weight of neighbor_id is the sum of weights to S
          new_wacc = Map.update(wacc, neighbor_id, w_float, &(&1 + w_float))
          {new_front, new_wacc}
        end
      end)
    end)
  end

  defp update_frontier_on_add(graph, frontier, internal_weights, s, new_node, weight_fn) do
    # Remove added node from frontier
    frontier = MapSet.delete(frontier, new_node)

    # Scan neighbors of new_node
    Model.successors(graph, new_node)
    |> Enum.reduce({frontier, internal_weights}, fn {neighbor_id, w}, {front, wacc} ->
      w_float = weight_fn.(w)

      if MapSet.member?(s, neighbor_id) do
        new_wacc =
          wacc
          |> Map.update(new_node, w_float, &(&1 + w_float))
          |> Map.update(neighbor_id, w_float, &(&1 + w_float))

        {front, new_wacc}
      else
        {MapSet.put(front, neighbor_id), wacc}
      end
    end)
  end

  defp update_frontier_on_remove(graph, frontier, internal_weights, s, removed_node, weight_fn) do
    s_without_node = MapSet.delete(s, removed_node)

    # Scan neighbors of removed_node
    {new_frontier, new_internal_weights} =
      Model.successors(graph, removed_node)
      |> Enum.reduce({frontier, internal_weights}, fn {neighbor_id, w}, {front, wacc} ->
        w_float = weight_fn.(w)

        if neighbor_id != removed_node and MapSet.member?(s_without_node, neighbor_id) do
          new_wacc = Map.update(wacc, neighbor_id, 0.0, &(&1 - w_float))
          {MapSet.put(front, neighbor_id), new_wacc}
        else
          {front, wacc}
        end
      end)

    # Add removed_node to frontier if it has neighbors in S
    has_internal_neighbor =
      Model.successors(graph, removed_node)
      |> Enum.any?(fn {nid, _} -> MapSet.member?(s_without_node, nid) end)

    final_frontier =
      if has_internal_neighbor do
        MapSet.put(new_frontier, removed_node)
      else
        new_frontier
      end

    # Remove internal weights for removed_node
    final_weights = Map.delete(new_internal_weights, removed_node)

    {final_frontier, final_weights}
  end

  defp total_degree(graph, node, cache, weight_fn) do
    case Map.get(cache, node) do
      nil ->
        d =
          Model.successors(graph, node)
          |> Enum.reduce(0.0, fn {_, w}, acc -> acc + weight_fn.(w) end)

        {d, Map.put(cache, node, d)}

      d ->
        {d, cache}
    end
  end

  defp w_in_s_cached(internal_weights, node) do
    Map.get(internal_weights, node, 0.0)
  end

  defp fitness(k_in, k_out, alpha) do
    vol = k_in + k_out

    if vol <= 0.0 do
      0.0
    else
      denom = :math.pow(vol, alpha)
      k_in / denom
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp do_detect(
         graph,
         s,
         k_in,
         k_out,
         frontier,
         internal_weights,
         cache,
         opts,
         iters,
         weight_fn,
         seeds_set
       ) do
    current_f = fitness(k_in, k_out, opts.alpha)

    # Find the best ADD operation from frontier
    {best_add_op, best_add_f, cache_after_add} =
      Enum.reduce(frontier, {nil, current_f, cache}, fn node, {best_op, best_f, current_cache} ->
        {d, next_cache} = total_degree(graph, node, current_cache, weight_fn)

        w_in = w_in_s_cached(internal_weights, node)

        new_k_in = k_in + 2.0 * w_in
        new_k_out = k_out + d - 2.0 * w_in
        f = fitness(new_k_in, new_k_out, opts.alpha)

        if f > best_f do
          {{:add, node, new_k_in, new_k_out}, f, next_cache}
        else
          {best_op, best_f, next_cache}
        end
      end)

    # Find the best REMOVE operation from current community
    {best_op, _best_f, final_cache} =
      if MapSet.size(s) <= 1 do
        # Don't remove if it's the last node
        {best_add_op, best_add_f, cache_after_add}
      else
        Enum.reduce(
          s,
          {best_add_op, best_add_f, cache_after_add},
          fn node, {best_op_acc, best_f_acc, current_cache} ->
            {d, next_cache} = total_degree(graph, node, current_cache, weight_fn)

            w_in = w_in_s_cached(internal_weights, node)

            new_k_in = k_in - 2.0 * w_in
            new_k_out = k_out - d + 2.0 * w_in
            f = fitness(new_k_in, new_k_out, opts.alpha)

            is_seed = MapSet.member?(seeds_set, node)

            if f > best_f_acc and not is_seed do
              {{:remove, node, new_k_in, new_k_out}, f, next_cache}
            else
              {best_op_acc, best_f_acc, next_cache}
            end
          end
        )
      end

    case best_op do
      nil ->
        # Local maximum reached
        s

      {:add, node, nk_in, nk_out} ->
        new_s = MapSet.put(s, node)

        {new_frontier, new_internal_weights} =
          update_frontier_on_add(graph, frontier, internal_weights, s, node, weight_fn)

        if iters >= opts.max_iterations do
          new_s
        else
          do_detect(
            graph,
            new_s,
            nk_in,
            nk_out,
            new_frontier,
            new_internal_weights,
            final_cache,
            opts,
            iters + 1,
            weight_fn,
            seeds_set
          )
        end

      {:remove, node, nk_in, nk_out} ->
        new_s = MapSet.delete(s, node)

        {new_frontier, new_internal_weights} =
          update_frontier_on_remove(graph, frontier, internal_weights, s, node, weight_fn)

        if iters >= opts.max_iterations do
          new_s
        else
          do_detect(
            graph,
            new_s,
            nk_in,
            nk_out,
            new_frontier,
            new_internal_weights,
            final_cache,
            opts,
            iters + 1,
            weight_fn,
            seeds_set
          )
        end
    end
  end
end
