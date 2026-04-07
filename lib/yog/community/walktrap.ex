defmodule Yog.Community.Walktrap do
  @moduledoc """
  Walktrap algorithm for community detection.

  Uses random walks to compute distances between nodes. Nodes are merged
  into communities based on these distances, creating a hierarchical
  structure that captures the graph's community organization.

  ## Algorithm

  1. **Compute** transition probabilities P^t (t-step random walk)
  2. **Define** distance between nodes based on transition probability differences
  3. **Merge** closest communities iteratively (hierarchical agglomerative)
  4. **Return** hierarchy of community partitions

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Hierarchical structure | ✓ Good |
  | Local structure matters | ✓ Captures neighborhood via walks |
  | Large graphs | Consider faster alternatives |
  | Quality priority | Good balance of speed and quality |

  ## Complexity

  - **Time**: O(V² × log V) for hierarchical clustering
  - **Space**: O(V²) for distance matrix

  ## Example

      # Basic usage (walk_length=4 is default)
      communities = Yog.Community.Walktrap.detect(graph)

      # With options
      communities = Yog.Community.Walktrap.detect_with_options(graph,
        walk_length: 5,
        target_communities: 3
      )

      # Full hierarchical detection
      dendrogram = Yog.Community.Walktrap.detect_hierarchical(graph, 4)

  ## References

  - [Pons & Latapy 2006 - Computing communities with random walks](https://doi.org/10.1080/15427951.2007.10129237)
  - [Wikipedia: Walktrap Algorithm](https://en.wikipedia.org/wiki/Walktrap_community)

  """

  alias Yog.Community
  alias Yog.Community.{Dendrogram, Result}
  alias Yog.PairingHeap

  @typedoc "Options for Walktrap algorithm"
  @type walktrap_options :: %{
          walk_length: integer(),
          target_communities: integer() | nil
        }

  @doc """
  Returns default options for Walktrap.

  ## Defaults

  - `walk_length`: 4 - Number of steps in random walk
  - `target_communities`: nil - Full dendrogram (all levels)
  """
  @spec default_options() :: walktrap_options()
  def default_options do
    %{walk_length: 4, target_communities: nil}
  end

  @doc """
  Detects communities using Walktrap with default options.

  ## Example

      communities = Yog.Community.Walktrap.detect(graph)
      IO.inspect(communities.num_communities)
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    detect_with_options(graph, [])
  end

  @doc """
  Detects communities using Walktrap with custom options.

  ## Options

  - `:walk_length` - Length of random walks (default: 4)
  - `:target_communities` - Stop when this many communities reached (default: nil = full)

  ## Example

      communities = Yog.Community.Walktrap.detect_with_options(graph,
        walk_length: 5,
        target_communities: 3
      )
  """
  @spec detect_with_options(Yog.graph(), keyword() | map()) :: Result.t()
  def detect_with_options(graph, opts) when is_list(opts) do
    detect_with_options(graph, Map.new(opts))
  end

  def detect_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
    nodes = Map.keys(graph.nodes)

    case length(nodes) do
      0 ->
        Result.new(%{})

      1 ->
        [node] = nodes
        Result.new(%{node => 0})

      _ ->
        dendrogram = detect_hierarchical(graph, options.walk_length)

        case options.target_communities do
          nil ->
            List.last(dendrogram.levels) || Result.new(%{})

          target ->
            Enum.find(dendrogram.levels, fn c -> c.num_communities <= target end) ||
              List.last(dendrogram.levels) ||
              Result.new(%{})
        end
    end
  end

  @doc """
  Full hierarchical Walktrap detection.

  Returns a dendrogram with community structure at each merge level.

  ## Parameters

  - `graph` - The graph to analyze
  - `walk_length` - Number of steps in random walk (default: 4)

  ## Example

      dendrogram = Yog.Community.Walktrap.detect_hierarchical(graph, 4)
      IO.inspect(length(dendrogram.levels))
  """
  @spec detect_hierarchical(Yog.graph(), integer()) :: Dendrogram.t()
  def detect_hierarchical(
        %Yog.Graph{out_edges: out_edges, nodes: nodes} = graph,
        walk_length \\ 4
      ) do
    node_list = Map.keys(nodes)

    p_t = compute_pt(graph, node_list, walk_length)

    degrees =
      Map.new(node_list, fn u ->
        d =
          case Map.fetch(out_edges, u) do
            {:ok, edges} ->
              List.foldl(Map.to_list(edges), 0.0, fn {_, w}, acc -> acc + w end)

            :error ->
              0.0
          end

        {u, max(d, 1.0)}
      end)

    initial_assignments = Map.new(Enum.with_index(node_list), fn {node, i} -> {node, i} end)
    initial_communities = Result.new(initial_assignments)

    initial_pt_cache =
      Map.new(node_list, fn node ->
        {node, Map.get(p_t, node, %{})}
      end)

    do_walktrap_merge([initial_communities], p_t, degrees, node_list, initial_pt_cache)
  end

  # =============================================================================
  # RANDOM WALK COMPUTATION
  # =============================================================================

  defp compute_pt(%Yog.Graph{out_edges: out_edges}, nodes, t) do
    p1 =
      Map.new(nodes, fn u ->
        neighbors =
          case Map.fetch(out_edges, u) do
            {:ok, edges} -> Map.to_list(edges)
            :error -> []
          end

        total_weight = List.foldl(neighbors, 0.0, fn {_, w}, acc -> acc + w end)

        row =
          if total_weight > 0 do
            Map.new(neighbors, fn {v, weight} -> {v, weight / total_weight} end)
          else
            %{}
          end

        {u, row}
      end)

    Enum.reduce(1..(t - 1), p1, fn _, p_acc ->
      multiply_sparse_matrices(p_acc, p1)
    end)
  end

  defp multiply_sparse_matrices(a, b) do
    Map.new(a, fn {i, row_a} ->
      new_row =
        Enum.reduce(row_a, %{}, fn {k, aik}, acc ->
          row_b_k = Map.get(b, k, %{})

          Enum.reduce(row_b_k, acc, fn {j, bkj}, inner_acc ->
            val = aik * bkj
            Map.update(inner_acc, j, val, &(&1 + val))
          end)
        end)
        |> Enum.filter(fn {_, v} -> v > 1.0e-12 end)
        |> Map.new()

      {i, new_row}
    end)
  end

  # =============================================================================
  # HIERARCHICAL MERGING
  # =============================================================================
  defp do_walktrap_merge(levels, p_t, degrees, nodes, pt_cache) do
    current_level = List.first(levels)

    if current_level.num_communities <= 1 do
      Dendrogram.new(Enum.reverse(levels), [])
    else
      case find_best_merge_pq(current_level, pt_cache, degrees) do
        nil ->
          Dendrogram.new(Enum.reverse(levels), [])

        {c1, c2} ->
          map_level = Result.to_map(current_level)
          merged_map = Community.merge(map_level, source: c2, target: c1)
          next_level = Result.from_map(merged_map)

          p_c1 = Map.get(pt_cache, c1) || %{}
          p_c2 = Map.get(pt_cache, c2) || %{}
          merged_pt = merge_community_pt(p_c1, p_c2)

          next_pt_cache =
            pt_cache
            |> Map.delete(c2)
            |> Map.put(c1, merged_pt)

          do_walktrap_merge([next_level | levels], p_t, degrees, nodes, next_pt_cache)
      end
    end
  end

  defp find_best_merge_pq(communities, pt_cache, degrees) do
    community_map = Community.to_dict(communities)
    ids = Map.keys(community_map)

    case ids do
      [] ->
        nil

      [_single] ->
        nil

      _multiple ->
        pq =
          Enum.reduce(ids, PairingHeap.new(fn {d1, _}, {d2, _} -> d1 <= d2 end), fn c1, acc ->
            Enum.reduce(ids, acc, fn c2, inner_acc ->
              if c1 < c2 do
                dist = calculate_cached_distance(c1, c2, pt_cache, degrees)
                PairingHeap.push(inner_acc, {dist, {c1, c2}})
              else
                inner_acc
              end
            end)
          end)

        case PairingHeap.pop(pq) do
          {:ok, {_dist, pair}, _new_pq} -> pair
          :error -> nil
        end
    end
  end

  defp calculate_cached_distance(c1, c2, pt_cache, degrees) do
    p_c1 = Map.get(pt_cache, c1) || %{}
    p_c2 = Map.get(pt_cache, c2) || %{}

    all_nodes =
      Map.keys(p_c1)
      |> MapSet.new()
      |> MapSet.union(MapSet.new(Map.keys(p_c2)))
      |> MapSet.to_list()

    Enum.reduce(all_nodes, 0.0, fn k, sum ->
      d_k = Map.get(degrees, k, 1.0)
      pk1 = Map.get(p_c1, k, 0.0)
      pk2 = Map.get(p_c2, k, 0.0)
      diff = pk1 - pk2
      sum + diff * diff / d_k
    end)
  end

  defp merge_community_pt(nil, p_c2), do: p_c2
  defp merge_community_pt(p_c1, nil), do: p_c1

  defp merge_community_pt(p_c1, p_c2) do
    all_keys =
      Map.keys(p_c1)
      |> MapSet.new()
      |> MapSet.union(MapSet.new(Map.keys(p_c2)))

    Enum.reduce(all_keys, %{}, fn k, acc ->
      v1 = Map.get(p_c1, k, 0.0)
      v2 = Map.get(p_c2, k, 0.0)
      avg = (v1 + v2) / 2.0

      if avg > 0.0 do
        Map.put(acc, k, avg)
      else
        acc
      end
    end)
  end
end
