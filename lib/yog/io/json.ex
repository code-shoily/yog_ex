defmodule Yog.IO.JSON do
  @moduledoc """
  JSON format export for graph data exchange (WRITE-ONLY).

  This module provides comprehensive JSON export capabilities for graph data,
  supporting multiple formats used by popular visualization libraries.

  **Note:** This module currently supports WRITE operations only. Import/read
  functionality is not implemented. For bidirectional I/O, consider using
  GraphML, GDF, TGF, LEDA, or Pajek formats.

  ## Format Support

  - **Generic**: Full metadata with type preservation
  - **D3Force**: D3.js force-directed graphs
  - **Cytoscape**: Cytoscape.js network visualization
  - **VisJs**: vis.js network format
  - **NetworkX**: Python NetworkX compatibility

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "follows")
      iex>
      iex> json_string = Yog.IO.JSON.to_json(graph, Yog.IO.JSON.default_export_options())
      iex> String.contains?(json_string, "Alice")
      true
      iex> String.contains?(json_string, "Bob")
      true
  """

  @doc """
  Creates default export options for String node and edge data.
  """
  defdelegate default_export_options, to: :yog_io@json

  @doc """
  Creates export options with custom serializers for generic types.
  """
  defdelegate export_options_with(node_serializer, edge_serializer), to: :yog_io@json

  @doc """
  Converts a graph to a JSON string according to options.
  """
  defdelegate to_json(graph, options), to: :yog_io@json

  @doc """
  Exports a graph to a JSON file.
  """
  defdelegate to_json_file(graph, path, options), to: :yog_io@json

  @doc """
  Quick export for D3.js force-directed graphs with default settings.
  """
  defdelegate to_d3_json(graph, node_serializer, edge_serializer), to: :yog_io@json

  @doc """
  Quick export for Cytoscape.js with default settings.
  """
  defdelegate to_cytoscape_json(graph, node_serializer, edge_serializer), to: :yog_io@json

  @doc """
  Quick export for vis.js networks with default settings.
  """
  defdelegate to_visjs_json(graph, node_serializer, edge_serializer), to: :yog_io@json

  @doc """
  Writes a graph to a JSON file using default export options.
  """
  defdelegate write(path, graph), to: :yog_io@json

  @doc """
  Writes a graph to a JSON file with custom export options.
  """
  defdelegate write_with(path, options, graph), to: :yog_io@json

  @doc """
  Converts a multigraph to a JSON string.
  """
  def to_json_multi(graph, options) do
    gleam_graph = {
      :multi_graph,
      graph.kind,
      graph.nodes,
      graph.edges,
      graph.out_edge_ids,
      graph.in_edge_ids,
      graph.next_edge_id
    }

    :yog_io@json.to_json_multi(gleam_graph, options)
  end

  @doc """
  Exports a multigraph to a JSON file.
  """
  def to_json_file_multi(graph, path, options) do
    gleam_graph = {
      :multi_graph,
      graph.kind,
      graph.nodes,
      graph.edges,
      graph.out_edge_ids,
      graph.in_edge_ids,
      graph.next_edge_id
    }

    :yog_io@json.to_json_file_multi(gleam_graph, path, options)
  end

  @doc """
  Converts a JsonError to a string.
  """
  defdelegate error_to_string(error), to: :yog_io@json
end
