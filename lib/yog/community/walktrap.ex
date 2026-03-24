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

  > **Migration Note:** Migrated to pure Elixir in v0.53.0. Implements hierarchical
  > agglomerative clustering based on random walk distances.
  """

  alias Yog.Community
  alias Yog.Community.{Dendrogram, Result}
  alias Yog.Model

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
    nodes = Yog.all_nodes(graph)

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
  def detect_hierarchical(graph, walk_length \\ 4) do
    nodes = Yog.all_nodes(graph)

    # 1. Compute transition probabilities P^t
    p_t = compute_pt(graph, nodes, walk_length)

    # 2. Compute degrees for normalization
    degrees =
      Map.new(nodes, fn u ->
        {u, length(Model.successors(graph, u)) * 1.0}
      end)

    # 3. Initial communities: each node in its own community
    initial_assignments = Map.new(Enum.with_index(nodes), fn {node, i} -> {node, i} end)
    initial_communities = Result.new(initial_assignments)

    # 4. Hierarchical merging
    do_walktrap_merge([initial_communities], p_t, degrees, nodes)
  end

  # =============================================================================
  # RANDOM WALK COMPUTATION
  # =============================================================================

  defp compute_pt(graph, nodes, t) do
    # Initial P^1 (one-step transition matrix)
    p1 =
      Map.new(nodes, fn u ->
        neighbors = Model.successors(graph, u)
        d = length(neighbors) * 1.0

        row =
          if d > 0 do
            Map.new(neighbors, fn {v, _weight} -> {v, 1.0 / d} end)
          else
            %{}
          end

        {u, row}
      end)

    # Compute P^t via repeated multiplication
    Enum.reduce(1..(t - 1), p1, fn _, p_acc ->
      multiply_matrices(p_acc, p1, nodes)
    end)
  end

  defp multiply_matrices(a, b, nodes) do
    Map.new(nodes, fn i ->
      row_a = Map.get(a, i, %{})

      new_row =
        Enum.reduce(nodes, %{}, fn j, acc ->
          val =
            Enum.reduce(row_a, 0.0, fn {k, aik}, sum ->
              row_b_k = Map.get(b, k, %{})
              bkj = Map.get(row_b_k, j, 0.0)
              sum + aik * bkj
            end)

          if val > 0.0 do
            Map.put(acc, j, val)
          else
            acc
          end
        end)

      {i, new_row}
    end)
  end

  # =============================================================================
  # HIERARCHICAL MERGING
  # =============================================================================

  defp do_walktrap_merge(levels, p_t, degrees, nodes) do
    current_level = List.first(levels) || Result.new(%{})

    if current_level.num_communities <= 1 do
      Dendrogram.new(Enum.reverse(levels), [])
    else
      case find_best_merge(current_level, p_t, degrees) do
        nil ->
          Dendrogram.new(Enum.reverse(levels), [])

        {c1, c2} ->
          # Convert to map for merge, then back to Result
          map_level = Result.to_map(current_level)
          merged_map = Community.merge(map_level, source: c2, target: c1)
          next_level = Result.from_map(merged_map)
          do_walktrap_merge([next_level | levels], p_t, degrees, nodes)
      end
    end
  end

  defp find_best_merge(communities, p_t, degrees) do
    community_map = Community.to_dict(communities)
    ids = Map.keys(community_map)

    {best_pair, _best_dist} =
      Enum.reduce(ids, {nil, :infinity}, fn c1, best_acc ->
        Enum.reduce(ids, best_acc, fn c2, {_best_pair, best_dist} = inner_acc ->
          if c1 < c2 do
            dist = calculate_community_distance(c1, c2, community_map, p_t, degrees)

            if dist < best_dist do
              {{c1, c2}, dist}
            else
              inner_acc
            end
          else
            inner_acc
          end
        end)
      end)

    best_pair
  end

  defp calculate_community_distance(c1, c2, community_map, p_t, degrees) do
    nodes1 = Map.get(community_map, c1, MapSet.new()) |> MapSet.to_list()
    nodes2 = Map.get(community_map, c2, MapSet.new()) |> MapSet.to_list()

    p_c1 = compute_community_pt(nodes1, p_t)
    p_c2 = compute_community_pt(nodes2, p_t)

    node_ids = Map.keys(p_t)

    Enum.reduce(node_ids, 0.0, fn k, sum ->
      d_k = Map.get(degrees, k, 1.0)
      pk1 = Map.get(p_c1, k, 0.0)
      pk2 = Map.get(p_c2, k, 0.0)
      diff = pk1 - pk2
      sum + diff * diff / d_k
    end)
  end

  defp compute_community_pt(nodes, p_t) do
    count = length(nodes) * 1.0

    Enum.reduce(nodes, %{}, fn u, acc ->
      row = Map.get(p_t, u, %{})

      Enum.reduce(row, acc, fn {k, prob}, inner_acc ->
        current = Map.get(inner_acc, k, 0.0)
        Map.put(inner_acc, k, current + prob / count)
      end)
    end)
  end
end
