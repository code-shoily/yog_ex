defmodule Yog.Property.WeisfeilerLehman do
  @moduledoc """
  Implements the Weisfeiler-Lehman (WL) graph hashing algorithm.

  Provides a structural graph hash that iteratively gathers and sorts neighbor
  labels to construct a deterministic characteristic signature evaluating
  isomorphism and topological caching.
  """

  alias Yog.Graph

  @doc """
  Calculates the WL structural hash for a given graph.

  ## Options

  - `:iterations` - The number of message-passing iterations (default: 3).
    Higher iterations provide strong isomorphism testing guarantees.
  - `:node_label_fn` - A custom function `(graph, node -> String.t())` mapping nodes
    to base initialization labels. Defaults to stringified structural node degrees.
  """
  @spec graph_hash(Graph.t(), keyword()) :: String.t()
  def graph_hash(graph, opts \\ [])

  def graph_hash(%Graph{} = graph, opts) when is_list(opts) do
    iterations = Keyword.get(opts, :iterations, 3)

    unless is_integer(iterations) and iterations >= 0 do
      raise ArgumentError,
            "expected :iterations to be a non-negative integer, got: #{inspect(iterations)}"
    end

    node_label_fn =
      Keyword.get(opts, :node_label_fn, fn g, node ->
        Yog.Model.degree(g, node) |> to_string()
      end)

    unless is_function(node_label_fn, 2) do
      raise ArgumentError,
            "expected :node_label_fn to be a 2-arity function, got: #{inspect(node_label_fn)}"
    end

    initial_labels =
      Yog.Utils.map_fold(graph.nodes, %{}, fn node, _data, acc ->
        Map.put(acc, node, node_label_fn.(graph, node))
      end)

    final_labels =
      if iterations > 0 do
        Enum.reduce(1..iterations, initial_labels, fn _i, current_labels ->
          Yog.Utils.map_fold(current_labels, %{}, fn node, label, acc ->
            neighbor_labels =
              Yog.Model.neighbor_ids(graph, node)
              |> Enum.map(&Map.fetch!(current_labels, &1))
              |> Enum.sort()

            combined = [label | neighbor_labels] |> Enum.join("")
            new_label = :crypto.hash(:md5, combined) |> Base.encode16(case: :lower)

            Map.put(acc, node, new_label)
          end)
        end)
      else
        initial_labels
      end

    final_combined =
      final_labels
      |> Map.values()
      |> Enum.sort()
      |> Enum.join("")

    :crypto.hash(:md5, final_combined) |> Base.encode16(case: :lower)
  end

  def graph_hash(%Yog.DAG{graph: graph}, opts), do: graph_hash(graph, opts)

  def graph_hash(other, _opts) do
    raise ArgumentError, "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(other)}"
  end
end
