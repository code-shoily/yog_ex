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
  def detect(%Yog.Graph{} = graph) do
    detect_with_options(graph, [])
  end

  def detect(other) do
    raise ArgumentError, "expected a Yog.Graph struct, got: #{inspect(other)}"
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
  @spec detect_with_options(Yog.graph(), keyword() | map()) :: Result.t()
  def detect_with_options(%Yog.Graph{} = graph, opts) when is_list(opts) or is_map(opts) do
    opts_map = Map.new(opts)
    options = Map.merge(default_options(), opts_map)

    if not (is_integer(options.max_iterations) and options.max_iterations >= 0) do
      raise ArgumentError,
            "expected max_iterations to be an integer >= 0, got: #{inspect(options.max_iterations)}"
    end

    nodes = Map.keys(graph.nodes)

    if nodes == [] do
      Result.new(%{})
    else
      # Initialize each node with its own unique label
      initial_labels = Map.new(nodes, fn node -> {node, node} end)

      # Run label propagation
      final_labels =
        propagate_labels(graph, nodes, initial_labels, options.max_iterations, options.seed)

      # Renumber communities to be 0, 1, 2, ...
      unique_labels = final_labels |> Map.values() |> Enum.uniq() |> Enum.sort()

      label_to_community =
        Map.new(Enum.with_index(unique_labels), fn {label, idx} -> {label, idx} end)

      assignments =
        Map.new(final_labels, fn {node, label} -> {node, label_to_community[label]} end)

      Result.new(assignments)
    end
  end

  def detect_with_options(%Yog.Graph{}, opts) do
    raise ArgumentError, "expected options keyword list or map, got: #{inspect(opts)}"
  end

  def detect_with_options(other, _opts) do
    raise ArgumentError, "expected a Yog.Graph struct, got: #{inspect(other)}"
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp propagate_labels(_graph, _nodes, labels, 0, _seed), do: labels

  defp propagate_labels(graph, nodes, labels, iterations_remaining, seed) do
    shuffled_nodes = Yog.Utils.fisher_yates(nodes, iterations_remaining + seed)

    {new_labels, changed} =
      List.foldl(shuffled_nodes, {labels, false}, fn node, {acc_labels, has_changed} ->
        neighbors = get_neighbors(graph, node)

        if neighbors == [] do
          {acc_labels, has_changed}
        else
          neighbor_labels = Enum.map(neighbors, fn n -> acc_labels[n] end)

          current_label = acc_labels[node]

          most_frequent = most_frequent_label(neighbor_labels, current_label, seed)

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

  defp get_neighbors(%Yog.Graph{out_edges: out_edges, kind: kind, in_edges: in_edges}, node) do
    out =
      case Map.fetch(out_edges, node) do
        {:ok, edges} -> Map.keys(edges)
        :error -> []
      end

    case kind do
      :undirected ->
        out

      :directed ->
        in_neighbors =
          case Map.fetch(in_edges, node) do
            {:ok, edges} -> Map.keys(edges)
            :error -> []
          end

        Enum.uniq(out ++ in_neighbors)
    end
  end

  defp most_frequent_label(neighbor_labels, current_label, seed) do
    {freqs, max_count} =
      List.foldl(neighbor_labels, {%{}, 0}, fn label, {acc, max_so_far} ->
        new_count = Map.get(acc, label, 0) + 1
        new_max = max(max_so_far, new_count)
        {Map.put(acc, label, new_count), new_max}
      end)

    candidates =
      Enum.filter(freqs, fn {_, count} -> count == max_count end)
      |> Enum.map(fn {label, _} -> label end)

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
