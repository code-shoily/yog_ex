defmodule Yog.Community.GirvanNewman do
  @moduledoc """
  Girvan-Newman algorithm for hierarchical community detection.

  Detects communities by iteratively removing edges with the highest
  edge betweenness centrality. Edges with high betweenness are "bridges"
  between communities.

  ## Algorithm

  1. **Calculate** edge betweenness centrality for all edges
  2. **Remove** the edge(s) with highest betweenness (batch removal)
  3. **Repeat** until no edges remain
  4. **Record** connected components at each step (hierarchy)

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Hierarchical structure needed | ✓ Excellent |
  | Small to medium graphs | ✓ Good |
  | Large graphs | ✗ Too slow (use Louvain/Leiden) |
  | Edge importance analysis | ✓ Provides edge betweenness |

  ## Complexity

  - **Time**: O(E² × V) or O(E³) in worst case - expensive!
  - **Space**: O(V + E)

  **Note**: This algorithm is significantly slower than Louvain/Leiden.
  Use only when you specifically need the hierarchical decomposition.

  ## Example

      # Basic usage - returns finest partition
      communities = Yog.Community.GirvanNewman.detect(graph)

      # With options - target specific number of communities
      {:ok, communities} = Yog.Community.GirvanNewman.detect_with_options(graph,
        target_communities: 2
      )

      # Full hierarchical detection
      dendrogram = Yog.Community.GirvanNewman.detect_hierarchical(graph)

  ## References

  - [Girvan & Newman 2002 - Community structure in social networks](https://doi.org/10.1073/pnas.122653799)
  - [Wikipedia: Girvan-Newman Algorithm](https://en.wikipedia.org/wiki/Girvan%E2%80%93Newman_algorithm)

  """

  alias Yog.Community.{Dendrogram, Result}
  alias Yog.PriorityQueue, as: PQ

  @typedoc "Options for Girvan-Newman algorithm"
  @type girvan_newman_options :: %{target_communities: integer() | nil}

  @doc """
  Returns default options for Girvan-Newman.

  ## Defaults

  - `target_communities`: nil - Full dendrogram (all levels)
  """
  @spec default_options() :: girvan_newman_options()
  def default_options do
    %{target_communities: nil}
  end

  @doc """
  Calculates edge betweenness centrality for all edges.

  Returns a map of `{node1, node2} => betweenness_score` where node1 < node2.

  ## Example

      betweenness = Yog.Community.GirvanNewman.edge_betweenness(graph)
      IO.inspect(betweenness)
  """
  @spec edge_betweenness(Yog.graph()) :: %{{Yog.node_id(), Yog.node_id()} => float()}
  def edge_betweenness(%Yog.Graph{nodes: nodes} = graph) do
    node_list = Map.keys(nodes)

    edge_scores =
      List.foldl(node_list, %{}, fn s, acc ->
        discovery = run_discovery(graph, s)
        edge_dependencies = accumulate_edge_dependencies(discovery)

        List.foldl(Map.to_list(edge_dependencies), acc, fn {edge, score}, inner_acc ->
          Map.update(inner_acc, edge, score, &(&1 + score))
        end)
      end)

    case graph do
      %Yog.Graph{kind: :undirected} ->
        Map.new(edge_scores, fn {k, v} -> {k, v / 2.0} end)

      _ ->
        edge_scores
    end
  end

  @doc """
  Detects communities using Girvan-Newman with default options.

  Returns the finest partition (most communities).
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    case detect_with_options(graph, []) do
      {:ok, communities} -> communities
      {:error, _} -> Result.new(%{})
    end
  end

  @doc """
  Detects communities using Girvan-Newman with custom options.

  ## Options

  - `:target_communities` - Stop when this many communities reached (default: nil = full)

  ## Example

      {:ok, communities} = Yog.Community.GirvanNewman.detect_with_options(graph,
        target_communities: 3
      )
  """
  @spec detect_with_options(Yog.graph(), keyword() | map()) ::
          {:ok, Result.t()} | {:error, String.t()}
  def detect_with_options(graph, opts) when is_list(opts) do
    detect_with_options(graph, Map.new(opts))
  end

  def detect_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
    dendrogram = detect_hierarchical(graph)

    case options.target_communities do
      nil ->
        case List.last(dendrogram.levels) do
          nil -> {:error, "Empty dendrogram"}
          communities -> {:ok, communities}
        end

      num_communities ->
        case Enum.find(dendrogram.levels, fn c -> c.num_communities >= num_communities end) do
          nil ->
            case List.last(dendrogram.levels) do
              nil -> {:error, "Could not find suitable community partition"}
              communities -> {:ok, communities}
            end

          communities ->
            {:ok, communities}
        end
    end
  end

  @doc """
  Full hierarchical Girvan-Newman detection.

  Returns a dendrogram with community structure at each level as edges are removed.

  ## Example

      dendrogram = Yog.Community.GirvanNewman.detect_hierarchical(graph)
      IO.inspect(length(dendrogram.levels))
  """
  @spec detect_hierarchical(Yog.graph()) :: Dendrogram.t()
  def detect_hierarchical(graph) do
    initial_comms = find_connected_components(graph)
    do_gn_split(graph, [initial_comms], initial_comms.num_communities)
  end

  # =============================================================================
  # EDGE BETWEENNESS CALCULATION (Brandes' Algorithm)
  # =============================================================================

  defp run_discovery(graph, source) do
    # Min-heap: smaller distances have higher priority
    compare_fn = fn {d1, _}, {d2, _} -> d1 <= d2 end

    queue =
      PQ.new(compare_fn)
      |> PQ.push({0, source})

    dists = %{source => 0}
    sigmas = %{source => 1}
    preds = %{}
    stack = []

    do_brandes_dijkstra(graph, queue, dists, sigmas, preds, stack)
  end

  defp do_brandes_dijkstra(
         %Yog.Graph{out_edges: out_edges} = graph,
         queue,
         dists,
         sigmas,
         preds,
         stack
       ) do
    case PQ.pop(queue) do
      :error ->
        {stack, preds, sigmas}

      {:ok, {d_v, v}, rest_q} ->
        current_best = Map.get(dists, v, d_v)

        if d_v > current_best do
          do_brandes_dijkstra(graph, rest_q, dists, sigmas, preds, stack)
        else
          new_stack = [v | stack]

          successors =
            case Map.fetch(out_edges, v) do
              {:ok, edges} -> Map.to_list(edges)
              :error -> []
            end

          {next_q, next_dists, next_sigmas, next_preds} =
            List.foldl(successors, {rest_q, dists, sigmas, preds}, fn {w, weight},
                                                                      {q, ds, ss, ps} ->
              weight_float = if is_nil(weight), do: 1.0, else: weight
              new_dist = d_v + weight_float

              case Map.get(ds, w) do
                nil ->
                  q2 = PQ.push(q, {new_dist, w})
                  ds2 = Map.put(ds, w, new_dist)
                  ss2 = Map.put(ss, w, get_sigma(ss, v))
                  ps2 = Map.put(ps, w, [v])
                  {q2, ds2, ss2, ps2}

                old_dist ->
                  cond do
                    new_dist < old_dist ->
                      q2 = PQ.push(q, {new_dist, w})
                      ds2 = Map.put(ds, w, new_dist)
                      ss2 = Map.put(ss, w, get_sigma(ss, v))
                      ps2 = Map.put(ps, w, [v])
                      {q2, ds2, ss2, ps2}

                    new_dist == old_dist ->
                      ss2 = Map.update(ss, w, 0, fn curr -> curr + get_sigma(ss, v) end)
                      ps2 = Map.update(ps, w, [], fn curr -> [v | curr] end)
                      {q, ds, ss2, ps2}

                    true ->
                      {q, ds, ss, ps}
                  end
              end
            end)

          do_brandes_dijkstra(graph, next_q, next_dists, next_sigmas, next_preds, new_stack)
        end
    end
  end

  defp get_sigma(sigmas, id) do
    Map.get(sigmas, id, 0)
  end

  defp accumulate_edge_dependencies({stack, preds, sigmas}) do
    node_deltas = %{}
    edge_deltas = %{}

    {_node_deltas, final_edge_deltas} =
      List.foldl(stack, {node_deltas, edge_deltas}, fn v, {nd, ed} ->
        sigma_v = get_sigma(sigmas, v) * 1.0
        delta_v = Map.get(nd, v, 0.0)
        v_preds = Map.get(preds, v, [])

        List.foldl(v_preds, {nd, ed}, fn u, {inner_nd, inner_ed} ->
          sigma_u = get_sigma(sigmas, u) * 1.0

          c = sigma_u / sigma_v * (1.0 + delta_v)

          edge =
            if u < v do
              {u, v}
            else
              {v, u}
            end

          new_nd = Map.update(inner_nd, u, c, fn curr -> curr + c end)
          new_ed = Map.update(inner_ed, edge, c, fn curr -> curr + c end)
          {new_nd, new_ed}
        end)
      end)

    final_edge_deltas
  end

  # =============================================================================
  # HIERARCHICAL SPLITTING
  # =============================================================================

  defp do_gn_split(graph, levels, prev_num_comms) do
    current_comms = find_connected_components(graph)
    current_num_comms = current_comms.num_communities

    # Only add level if number of communities increased
    new_levels =
      if current_num_comms > prev_num_comms do
        [current_comms | levels]
      else
        levels
      end

    edge_count = count_edges(graph)

    if edge_count == 0 do
      Dendrogram.new(Enum.reverse(new_levels), [])
    else
      ebc = edge_betweenness(graph)

      if map_size(ebc) == 0 do
        Dendrogram.new(Enum.reverse(new_levels), [])
      else
        max_val =
          ebc
          |> Map.values()
          |> Enum.max(fn -> 0.0 end)

        edges_to_remove =
          Enum.filter(ebc, fn {_edge, score} -> score == max_val end)
          |> Enum.map(fn {{u, v}, _score} -> {u, v} end)

        new_graph =
          List.foldl(edges_to_remove, graph, fn {u, v}, g ->
            Yog.remove_edge(g, u, v)
          end)

        do_gn_split(new_graph, new_levels, current_num_comms)
      end
    end
  end

  defp count_edges(%Yog.Graph{out_edges: out_edges, nodes: nodes}) do
    node_list = Map.keys(nodes)

    List.foldl(node_list, 0, fn node, acc ->
      case Map.fetch(out_edges, node) do
        {:ok, edges} -> acc + map_size(edges)
        :error -> acc
      end
    end)
  end

  defp find_connected_components(%Yog.Graph{nodes: nodes} = graph) do
    node_list = Map.keys(nodes)

    {_visited, assignments, _count} =
      List.foldl(node_list, {MapSet.new(), %{}, 0}, fn u, {visited, assignments, count} ->
        if MapSet.member?(visited, u) do
          {visited, assignments, count}
        else
          component = Yog.Traversal.walk(graph, u, :breadth_first)
          new_visited = Enum.reduce(component, visited, &MapSet.put(&2, &1))

          new_assignments =
            Enum.reduce(component, assignments, fn v, d ->
              Map.put(d, v, count)
            end)

          {new_visited, new_assignments, count + 1}
        end
      end)

    Result.new(assignments)
  end
end
