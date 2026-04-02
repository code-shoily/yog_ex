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

  use Yog.Algorithm

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

    nodes = Model.all_nodes(graph)

    if nodes == [] do
      Result.new(%{})
    else
      # Initialize each node with its own unique label
      initial_labels = Map.new(nodes, fn node -> {node, node} end)

      # Run label propagation
      final_labels = propagate_labels(graph, nodes, initial_labels, max_iterations, seed)

      # Renumber communities to be 0, 1, 2, ...
      unique_labels = final_labels |> Map.values() |> Enum.uniq() |> Enum.sort()

      label_to_community =
        Map.new(Enum.with_index(unique_labels), fn {label, idx} -> {label, idx} end)

      assignments =
        Map.new(final_labels, fn {node, label} -> {node, label_to_community[label]} end)

      Result.new(assignments)
    end
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp propagate_labels(_graph, _nodes, labels, 0, _seed), do: labels

  defp propagate_labels(graph, nodes, labels, iterations_remaining, seed) do
    # Shuffle node order for this iteration - O(V) Fisher-Yates
    shuffled_nodes = Yog.Utils.fisher_yates(nodes, iterations_remaining + seed)

    # Update labels
    {new_labels, changed} =
      Enum.reduce(shuffled_nodes, {labels, false}, fn node, {acc_labels, has_changed} ->
        neighbors = get_neighbors(graph, node)

        if neighbors == [] do
          {acc_labels, has_changed}
        else
          # Get neighbor labels
          neighbor_labels = Enum.map(neighbors, fn n -> acc_labels[n] end)

          current_label = acc_labels[node]

          # Find most frequent label with tie-breaking logic:
          # - If current label is tied for majority, keep it (prevents oscillation)
          # - Otherwise use randomized tie-breaker (prevents lexicographical bias)
          most_frequent = most_frequent_label(neighbor_labels, current_label, seed)

          if most_frequent != current_label do
            {Map.put(acc_labels, node, most_frequent), true}
          else
            {acc_labels, has_changed}
          end
        end
      end)

    # If no labels changed, we've converged
    if changed do
      propagate_labels(graph, nodes, new_labels, iterations_remaining - 1, seed)
    else
      new_labels
    end
  end

  defp get_neighbors(graph, node) do
    Model.neighbor_ids(graph, node)
  end

  # Single-pass frequency count with current label preference and randomized tie-break
  # Returns {most_frequent_label, max_count} or nil if empty
  defp most_frequent_label(neighbor_labels, current_label, seed) do
    # Single-pass: count frequencies while tracking max
    {freqs, max_count} =
      Enum.reduce(neighbor_labels, {%{}, 0}, fn label, {acc, max_so_far} ->
        new_count = Map.get(acc, label, 0) + 1
        new_max = max(max_so_far, new_count)
        {Map.put(acc, label, new_count), new_max}
      end)

    # Get all labels with max frequency
    candidates =
      Enum.filter(freqs, fn {_, count} -> count == max_count end)
      |> Enum.map(fn {label, _} -> label end)

    # If current label is tied for max, keep it (prevents oscillation)
    if current_label in candidates do
      current_label
    else
      # Randomized tie-breaker using seed for determinism
      # Hash each candidate with seed and pick minimum hash
      candidates
      |> Enum.map(fn label -> {:erlang.phash2({label, seed}), label} end)
      |> Enum.min_by(fn {hash, _} -> hash end)
      |> elem(1)
    end
  end
end
