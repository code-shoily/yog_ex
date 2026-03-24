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

  alias Yog.Model

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
    initial_s = MapSet.new(seeds)

    # Compute initial degrees
    {k_in, k_out} = compute_k_out_in(graph, initial_s, weight_fn)

    # Start with empty degrees cache
    degrees_cache = %{}

    do_detect(graph, initial_s, k_in, k_out, degrees_cache, options, 0, weight_fn, seeds)
  end

  # ============================================================
  # Private Functions
  # ============================================================

  defp compute_k_out_in(graph, s, weight_fn) do
    MapSet.to_list(s)
    |> Enum.reduce({0.0, 0.0}, fn node, {k_in_acc, k_out_acc} ->
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

  # Compute the boundary of S (nodes outside S that are neighbors of S)
  defp boundary_of(graph, s) do
    MapSet.to_list(s)
    |> Enum.reduce(MapSet.new(), fn node, acc ->
      Model.successors(graph, node)
      |> Enum.reduce(acc, fn {neighbor_id, _}, acc2 ->
        if MapSet.member?(s, neighbor_id) do
          acc2
        else
          MapSet.put(acc2, neighbor_id)
        end
      end)
    end)
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

  # Calculate sum of weights from node to nodes inside S
  defp w_in_s(graph, node, s, weight_fn) do
    Model.successors(graph, node)
    |> Enum.reduce(0.0, fn {neighbor_id, w}, acc ->
      if MapSet.member?(s, neighbor_id) do
        acc + weight_fn.(w)
      else
        acc
      end
    end)
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

  defp do_detect(graph, s, k_in, k_out, cache, opts, iters, weight_fn, seeds) do
    bound = boundary_of(graph, s)
    current_f = fitness(k_in, k_out, opts.alpha)

    # Find the best ADD operation from boundary
    {best_add_op, best_add_f, cache_after_add} =
      MapSet.to_list(bound)
      |> Enum.reduce({nil, current_f, cache}, fn node, {best_op, best_f, current_cache} ->
        {d, next_cache} = total_degree(graph, node, current_cache, weight_fn)
        w_in = w_in_s(graph, node, s, weight_fn)

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
        MapSet.to_list(s)
        |> Enum.reduce(
          {best_add_op, best_add_f, cache_after_add},
          fn node, {best_op_acc, best_f_acc, current_cache} ->
            {d, next_cache} = total_degree(graph, node, current_cache, weight_fn)
            s_without_node = MapSet.delete(s, node)
            w_in = w_in_s(graph, node, s_without_node, weight_fn)

            new_k_in = k_in - 2.0 * w_in
            new_k_out = k_out - d + 2.0 * w_in
            f = fitness(new_k_in, new_k_out, opts.alpha)

            # Never remove a seed node
            is_seed = node in seeds

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

        if iters >= opts.max_iterations do
          new_s
        else
          do_detect(graph, new_s, nk_in, nk_out, final_cache, opts, iters + 1, weight_fn, seeds)
        end

      {:remove, node, nk_in, nk_out} ->
        new_s = MapSet.delete(s, node)

        if iters >= opts.max_iterations do
          new_s
        else
          do_detect(graph, new_s, nk_in, nk_out, final_cache, opts, iters + 1, weight_fn, seeds)
        end
    end
  end
end
