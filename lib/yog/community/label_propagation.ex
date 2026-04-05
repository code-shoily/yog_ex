defmodule Yog.Community.LabelPropagation do
  @moduledoc """
  Label Propagation Algorithm (LPA) for community detection.

  A fast, near-linear time algorithm where each node adopts the label
  that most of its neighbors have. The algorithm converges when each
  node has the same label as the majority of its neighbors.

  ## When to Use

  - Very large graphs (near-linear time complexity)
  - Speed is more important than optimal quality
  - Large-scale network analysis

  ## Options

  - `:max_iterations` - Maximum iterations (default: 100)
  - `:seed` - Random seed for initialization (default: 0)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> communities = Yog.Community.LabelPropagation.detect(graph)
      iex> is_map(communities.assignments)
      true
  """

  alias Yog.Community.Result

  @doc """
  Returns default options for LPA.
  """
  @spec default_options() :: %{max_iterations: integer(), seed: integer()}
  def default_options do
    %{max_iterations: 100, seed: 0}
  end

  @doc """
  Detects communities using Label Propagation with default options.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> communities = Yog.Community.LabelPropagation.detect(graph)
      iex> is_map(communities.assignments)
      true
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    detect_with_options(graph, [])
  end

  @doc """
  Detects communities using Label Propagation with custom options.

  ## Options

    * `:max_iterations` - Maximum iterations (default: 100)
    * `:seed` - Random seed (default: 0)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> communities = Yog.Community.LabelPropagation.detect_with_options(graph,
      ...>   max_iterations: 200,
      ...>   seed: 42
      ...> )
      iex> is_map(communities.assignments)
      true
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Result.t()
  def detect_with_options(graph, opts) do
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    seed = Keyword.get(opts, :seed, 0)

    nodes = Map.keys(graph.nodes)

    if nodes == [] do
      Result.new(%{})
    else
      # Initialize each node with its own unique label
      initial_labels =
        :maps.fold(
          fn node, _, acc -> Map.put(acc, node, node) end,
          %{},
          graph.nodes
        )

      # Run label propagation
      final_labels = propagate_labels(graph, nodes, initial_labels, max_iterations, seed)

      # Renumber communities to be 0, 1, 2, ...
      unique_labels =
        :maps.fold(
          fn _, label, acc -> MapSet.put(acc, label) end,
          MapSet.new(),
          final_labels
        )
        |> MapSet.to_list()
        |> Enum.sort()

      label_to_community =
        unique_labels
        |> Enum.with_index()
        |> Map.new(fn {label, idx} -> {label, idx} end)

      assignments =
        :maps.fold(
          fn node, label, acc ->
            Map.put(acc, node, Map.get(label_to_community, label))
          end,
          %{},
          final_labels
        )

      Result.new(assignments)
    end
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp propagate_labels(_graph, _nodes, labels, 0, _seed), do: labels

  defp propagate_labels(graph, nodes, labels, iterations_remaining, seed) do
    shuffled_nodes = Yog.Utils.fisher_yates(nodes, iterations_remaining + seed)

    {new_labels, changed} =
      List.foldl(shuffled_nodes, {labels, false}, fn node, {acc_labels, has_changed} ->
        neighbor_freqs = calculate_neighbor_freqs(graph, node, acc_labels)

        if map_size(neighbor_freqs) == 0 do
          {acc_labels, has_changed}
        else
          current_label = acc_labels[node]
          most_frequent = most_frequent_label_fast(neighbor_freqs, current_label, seed)

          if most_frequent != current_label do
            {Map.put(acc_labels, node, most_frequent), true}
          else
            {acc_labels, has_changed}
          end
        end
      end)

    if changed do
      propagate_labels(graph, nodes, new_labels, iterations_remaining - 1, seed)
    else
      new_labels
    end
  end

  defp calculate_neighbor_freqs(
         %Yog.Graph{out_edges: out_edges, kind: kind, in_edges: in_edges},
         node,
         labels
       ) do
    # Optimization: count frequencies directly from edge maps
    out_freqs =
      case Map.fetch(out_edges, node) do
        {:ok, edges} ->
          :maps.fold(
            fn neighbor, _, acc ->
              label = Map.get(labels, neighbor)
              Map.update(acc, label, 1, &(&1 + 1))
            end,
            %{},
            edges
          )

        :error ->
          %{}
      end

    case kind do
      :undirected ->
        out_freqs

      :directed ->
        case Map.fetch(in_edges, node) do
          {:ok, edges} ->
            :maps.fold(
              fn neighbor, _, acc ->
                label = Map.get(labels, neighbor)
                Map.update(acc, label, 1, &(&1 + 1))
              end,
              out_freqs,
              edges
            )

          :error ->
            out_freqs
        end
    end
  end

  defp most_frequent_label_fast(freqs, current_label, seed) do
    max_count =
      :maps.fold(
        fn _, count, acc -> max(acc, count) end,
        0,
        freqs
      )

    candidates =
      :maps.fold(
        fn label, count, acc ->
          if count == max_count, do: [label | acc], else: acc
        end,
        [],
        freqs
      )

    if current_label in candidates do
      current_label
    else
      candidates
      |> Enum.map(fn label -> {:erlang.phash2({label, seed}), label} end)
      |> Enum.min_by(fn {hash, _} -> hash end)
      |> elem(1)
    end
  end
end
