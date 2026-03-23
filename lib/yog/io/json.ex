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
  def default_export_options do
    {:json_export_options, :yog_generic, true, &default_node_serializer/1,
     &default_edge_serializer/1, false, %{}}
  end

  @doc """
  Creates export options with custom serializers for generic types.
  """
  def export_options_with(node_serializer, edge_serializer) do
    {:json_export_options, :yog_generic, true, node_serializer, edge_serializer, false, %{}}
  end

  @doc """
  Converts a graph to a JSON string according to options.
  """
  def to_json(graph, options) do
    {:json_export_options, format, include_metadata?, node_ser, edge_ser, _pretty?, _meta} =
      options

    case format do
      :yog_generic ->
        to_generic_format(graph, node_ser, edge_ser, include_metadata?)

      :network_x ->
        to_networkx_format(graph, node_ser, edge_ser, include_metadata?)

      :d3_force ->
        to_d3_format(graph, node_ser, edge_ser)

      :cytoscape ->
        to_cytoscape_format(graph, node_ser, edge_ser)

      :visjs ->
        to_visjs_format(graph, node_ser, edge_ser)

      _ ->
        to_generic_format(graph, node_ser, edge_ser, include_metadata?)
    end
    |> Jason.encode!()
  end

  @doc """
  Exports a graph to a JSON file.
  """
  def to_json_file(graph, path, options) do
    json_string = to_json(graph, options)

    case File.write(path, json_string) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Quick export for D3.js force-directed graphs with default settings.
  """
  def to_d3_json(graph, node_serializer, edge_serializer) do
    options =
      {:json_export_options, :d3_force, false, node_serializer, edge_serializer, false, %{}}

    to_json(graph, options)
  end

  @doc """
  Quick export for Cytoscape.js with default settings.
  """
  def to_cytoscape_json(graph, node_serializer, edge_serializer) do
    options =
      {:json_export_options, :cytoscape, false, node_serializer, edge_serializer, false, %{}}

    to_json(graph, options)
  end

  @doc """
  Quick export for vis.js networks with default settings.
  """
  def to_visjs_json(graph, node_serializer, edge_serializer) do
    options = {:json_export_options, :visjs, false, node_serializer, edge_serializer, false, %{}}
    to_json(graph, options)
  end

  @doc """
  Writes a graph to a JSON file using default export options.
  """
  def write(path, graph) do
    to_json_file(graph, path, default_export_options())
  end

  @doc """
  Writes a graph to a JSON file with custom export options.
  """
  def write_with(path, options, graph) do
    to_json_file(graph, path, options)
  end

  @doc """
  Converts a multigraph to a JSON string.
  """
  def to_json_multi(graph, options) do
    {:json_export_options, _format, include_metadata?, node_ser, edge_ser, _pretty?, _meta} =
      options

    to_generic_multi_format(graph, node_ser, edge_ser, include_metadata?)
    |> Jason.encode!()
  end

  @doc """
  Exports a multigraph to a JSON file.
  """
  def to_json_file_multi(graph, path, options) do
    json_string = to_json_multi(graph, options)
    File.write(path, json_string)
  end

  @doc """
  Converts a JsonError to a string.
  """
  def error_to_string(error) do
    inspect(error)
  end

  # Private functions

  defp default_node_serializer(data) do
    data
  end

  defp default_edge_serializer(data) do
    data
  end

  # Convert Gleam JSON iolist to Elixir term
  defp gleam_json_to_term(iolist) when is_list(iolist) do
    iolist
    |> IO.iodata_to_binary()
    |> Jason.decode!()
  end

  defp gleam_json_to_term(other), do: other

  # Serialize data using the provided serializer
  defp serialize_data(data, serializer) do
    result = serializer.(data)

    # Check if result is a Gleam JSON iolist (starts with numbers or nested lists)
    if is_list(result) and (is_integer(List.first(result)) or is_list(List.first(result))) do
      gleam_json_to_term(result)
    else
      result
    end
  end

  defp to_generic_format(graph, node_ser, edge_ser, include_metadata?) do
    {:graph, type, nodes_map, _, _} = graph
    graph_type = if type == :directed, do: "directed", else: "undirected"
    edges = get_all_edges(graph)

    nodes_json =
      Enum.map(nodes_map, fn {id, data} ->
        %{
          id: id,
          data: serialize_data(data, node_ser)
        }
      end)

    edges_json =
      Enum.map(edges, fn {from, to, weight} ->
        %{
          source: from,
          target: to,
          weight: serialize_data(weight, edge_ser)
        }
      end)

    result = %{
      format: "yog-generic",
      version: "2.0",
      graph_type: graph_type,
      nodes: nodes_json,
      edges: edges_json
    }

    if include_metadata? do
      Map.put(result, :metadata, build_metadata(graph))
    else
      result
    end
  end

  defp to_networkx_format(graph, node_ser, edge_ser, include_metadata?) do
    {:graph, type, nodes_map, _, _} = graph
    directed = type == :directed
    edges = get_all_edges(graph)

    nodes_json =
      Enum.map(nodes_map, fn {id, data} ->
        %{
          id: id,
          data: serialize_data(data, node_ser)
        }
      end)

    links_json =
      Enum.map(edges, fn {from, to, weight} ->
        %{
          source: from,
          target: to,
          weight: serialize_data(weight, edge_ser)
        }
      end)

    result = %{
      directed: directed,
      multigraph: false,
      graph: %{},
      nodes: nodes_json,
      links: links_json
    }

    if include_metadata? do
      Map.put(result, :metadata, build_metadata(graph))
    else
      result
    end
  end

  defp to_d3_format(graph, node_ser, edge_ser) do
    {:graph, _, nodes_map, _, _} = graph
    edges = get_all_edges(graph)

    nodes_json =
      Enum.map(nodes_map, fn {id, data} ->
        %{
          id: id,
          data: serialize_data(data, node_ser)
        }
      end)

    links_json =
      Enum.map(edges, fn {from, to, weight} ->
        %{
          source: from,
          target: to,
          weight: serialize_data(weight, edge_ser)
        }
      end)

    %{
      nodes: nodes_json,
      links: links_json
    }
  end

  defp to_cytoscape_format(graph, node_ser, edge_ser) do
    {:graph, _, nodes_map, _, _} = graph
    edges = get_all_edges(graph)

    nodes_elements =
      Enum.map(nodes_map, fn {id, data} ->
        %{
          data: %{
            id: id,
            label: serialize_data(data, node_ser)
          }
        }
      end)

    edges_elements =
      Enum.map(edges, fn {from, to, weight} ->
        %{
          data: %{
            source: from,
            target: to,
            weight: serialize_data(weight, edge_ser)
          }
        }
      end)

    %{
      elements: nodes_elements ++ edges_elements
    }
  end

  defp to_visjs_format(graph, node_ser, edge_ser) do
    {:graph, _, nodes_map, _, _} = graph
    edges = get_all_edges(graph)

    nodes_json =
      Enum.map(nodes_map, fn {id, data} ->
        %{
          id: id,
          label: serialize_data(data, node_ser)
        }
      end)

    edges_json =
      Enum.map(edges, fn {from, to, weight} ->
        %{
          from: from,
          to: to,
          label: serialize_data(weight, edge_ser)
        }
      end)

    %{
      nodes: nodes_json,
      edges: edges_json
    }
  end

  defp to_generic_multi_format(graph, node_ser, edge_ser, include_metadata?) do
    graph_type = if graph.kind == :directed, do: "directed", else: "undirected"
    nodes = Map.to_list(graph.nodes)

    # Collect all edges with their IDs
    edges =
      graph.edges
      |> Map.to_list()
      |> Enum.map(fn {edge_id, {from, to, weight}} ->
        {edge_id, from, to, weight}
      end)

    nodes_json =
      Enum.map(nodes, fn {id, data} ->
        %{
          id: id,
          data: serialize_data(data, node_ser)
        }
      end)

    edges_json =
      Enum.map(edges, fn {edge_id, from, to, weight} ->
        %{
          id: edge_id,
          source: from,
          target: to,
          weight: serialize_data(weight, edge_ser)
        }
      end)

    result = %{
      format: "yog-generic",
      version: "2.0",
      graph_type: graph_type,
      multigraph: true,
      nodes: nodes_json,
      edges: edges_json,
      edge_count: length(edges)
    }

    if include_metadata? do
      Map.put(result, :metadata, build_multi_metadata(graph))
    else
      result
    end
  end

  defp build_metadata(graph) do
    {:graph, type, _, _, _} = graph

    %{
      node_count: Yog.Model.order(graph),
      edge_count: length(get_all_edges(graph)),
      directed: type == :directed
    }
  end

  # Extract all edges from the graph
  defp get_all_edges({:graph, type, _, out_edges, _}) do
    if type == :directed do
      # For directed graphs, just collect from out_edges
      for {from, dests} <- out_edges,
          {to, weight} <- dests do
        {from, to, weight}
      end
    else
      # For undirected graphs, edges appear in both directions
      # We need to deduplicate by only taking edges where from <= to
      for {from, dests} <- out_edges,
          {to, weight} <- dests,
          from <= to do
        {from, to, weight}
      end
    end
  end

  defp build_multi_metadata(graph) do
    %{
      node_count: map_size(graph.nodes),
      edge_count: map_size(graph.edges),
      directed: graph.kind == :directed
    }
  end
end
