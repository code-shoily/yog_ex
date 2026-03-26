defmodule Yog.IO.Generators do
  @moduledoc """
  Specialized generators for IO property-based tests.
  """
  use ExUnitProperties
  import Yog.Generators

  @doc """
  Generates a graph with string labels for nodes and edges.
  """
  def string_graph_gen do
    gen all(
          graph <- graph_gen(),
          node_labels <-
            StreamData.list_of(StreamData.string(:alphanumeric, min_length: 1, max_length: 10),
              length: Yog.node_count(graph)
            ),
          edge_labels <-
            StreamData.list_of(StreamData.string(:alphanumeric, min_length: 1, max_length: 10),
              length: Yog.edge_count(graph)
            )
        ) do
      # Replace node data with strings
      node_ids = graph.nodes |> Map.keys() |> Enum.sort()
      node_map = Enum.zip(node_ids, node_labels) |> Enum.into(%{})

      graph_with_nodes =
        Enum.reduce(node_map, graph, fn {id, data}, acc ->
          Yog.add_node(acc, id, data)
        end)

      # Replace edge data with strings
      edges = Yog.all_edges(graph_with_nodes)
      edge_data_map = Enum.zip(edges, edge_labels)

      Enum.reduce(edge_data_map, graph_with_nodes, fn {{u, v, _w}, data}, acc ->
        {:ok, new_acc} = Yog.add_edge(acc, u, v, data)
        new_acc
      end)
    end
  end

  @doc """
  Generates a directed graph with string labels.
  """
  def directed_string_graph_gen do
    gen all(graph <- string_graph_gen()) do
      %{graph | kind: :directed}
    end
  end

  @doc """
  Generates an undirected graph with string labels.
  """
  def undirected_string_graph_gen do
    gen all(graph <- string_graph_gen()) do
      %{graph | kind: :undirected}
    end
  end

  @doc """
  Check if two graphs have the same structure (same nodes, edges, and connectivity).
  """
  def graphs_structurally_equal?(g1, g2) do
    # Must have same type
    # Must have same number of nodes
    # Must have same number of edges
    # Must have same nodes (by ID and data)
    # Must have same connectivity
    g1.kind == g2.kind &&
      Yog.node_count(g1) == Yog.node_count(g2) &&
      Yog.edge_count(g1) == Yog.edge_count(g2) &&
      g1.nodes == g2.nodes &&
      normalize_edges(g1) == normalize_edges(g2)
  end

  defp normalize_edges(graph) do
    Yog.all_edges(graph)
    |> Enum.map(fn {u, v, w} ->
      if graph.kind == :undirected && u > v, do: {v, u, w}, else: {u, v, w}
    end)
    |> Enum.sort()
  end
end
