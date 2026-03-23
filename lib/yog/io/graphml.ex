defmodule Yog.IO.GraphML do
  @moduledoc """
  GraphML (Graph Markup Language) serialization support.

  Provides functions to serialize and deserialize graphs in the GraphML format,
  an XML-based format widely supported by graph visualization and analysis tools
  like Gephi, yEd, Cytoscape, and NetworkX.

  ## Format Overview

  GraphML is an XML-based format that supports:
  - **Nodes** with custom attributes
  - **Edges** with custom attributes
  - **Directed and undirected** graphs
  - **Hierarchical graphs** (not yet supported)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "friend")
      iex>
      iex> xml = Yog.IO.GraphML.serialize(graph)
      iex> String.contains?(xml, "Alice")
      true
      iex> String.contains?(xml, "Bob")
      true
  """

  @doc """
  Default GraphML serialization options.
  """
  def default_options do
    {:graphml_options, 2, true}
  end

  @doc """
  Serializes a graph to a GraphML string with custom attribute mappers.
  """
  def serialize_with(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GraphML with typed attributes for Gephi compatibility.
  """
  def serialize_with_types(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GraphML with typed attributes and custom options.
  """
  def serialize_with_types_and_options(node_attr, edge_attr, options, graph) do
    serialize_with_options(node_attr, edge_attr, options, graph)
  end

  @doc """
  Serializes a graph to a GraphML string with custom options.
  """
  def serialize_with_options(node_attr, edge_attr, options, graph) do
    {:graphml_options, indent, include_xml_declaration} = options
    {:graph, type, nodes_map, _, _} = graph

    # Collect all node and edge attributes
    node_attrs_list =
      nodes_map
      |> Enum.map(fn {_id, data} -> node_attr.(data) end)

    edges = get_all_edges(graph)

    edge_attrs_list =
      edges
      |> Enum.map(fn {_from, _to, weight} -> edge_attr.(weight) end)

    # Extract unique keys
    node_keys =
      node_attrs_list
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()
      |> Enum.sort()

    edge_keys =
      edge_attrs_list
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()
      |> Enum.sort()

    # Build XML
    indent_str = String.duplicate(" ", indent)

    xml_declaration =
      if include_xml_declaration do
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      else
        ""
      end

    graphml_open = "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">\n"

    # Key definitions
    key_defs =
      (Enum.map(node_keys, fn key ->
         indent_str <>
           "<key id=\"#{escape_xml(key)}\" for=\"node\" attr.name=\"#{escape_xml(key)}\" attr.type=\"string\"/>"
       end) ++
         Enum.map(edge_keys, fn key ->
           indent_str <>
             "<key id=\"#{escape_xml(key)}\" for=\"edge\" attr.name=\"#{escape_xml(key)}\" attr.type=\"string\"/>"
         end))
      |> Enum.join("\n")

    key_defs_section = if key_defs != "", do: key_defs <> "\n", else: ""

    # Graph
    edge_default = if type == :directed, do: "directed", else: "undirected"
    graph_open = indent_str <> "<graph id=\"G\" edgedefault=\"#{edge_default}\">\n"

    # Nodes
    nodes_xml =
      nodes_map
      |> Enum.sort()
      |> Enum.map_join("\n", fn {id, data} ->
        attrs = node_attr.(data)

        data_elements =
          Enum.map_join(attrs, "\n", fn {key, value} ->
            indent_str <>
              indent_str <>
              indent_str <> "<data key=\"#{escape_xml(key)}\">#{escape_xml(value)}</data>"
          end)

        node_content =
          if data_elements != "" do
            "\n" <> data_elements <> "\n" <> indent_str <> indent_str
          else
            ""
          end

        indent_str <> indent_str <> "<node id=\"#{id}\">#{node_content}</node>"
      end)

    nodes_section = if nodes_xml != "", do: nodes_xml <> "\n", else: ""

    # Edges
    edges_xml =
      edges
      |> Enum.map_join("\n", fn {from, to, weight} ->
        attrs = edge_attr.(weight)

        data_elements =
          Enum.map_join(attrs, "\n", fn {key, value} ->
            indent_str <>
              indent_str <>
              indent_str <> "<data key=\"#{escape_xml(key)}\">#{escape_xml(value)}</data>"
          end)

        edge_content =
          if data_elements != "" do
            "\n" <> data_elements <> "\n" <> indent_str <> indent_str
          else
            ""
          end

        indent_str <>
          indent_str <> "<edge source=\"#{from}\" target=\"#{to}\">#{edge_content}</edge>"
      end)

    edges_section = if edges_xml != "", do: edges_xml <> "\n", else: ""

    graph_close = indent_str <> "</graph>\n"
    graphml_close = "</graphml>"

    xml_declaration <>
      graphml_open <>
      key_defs_section <>
      graph_open <> nodes_section <> edges_section <> graph_close <> graphml_close
  end

  @doc """
  Serializes a graph to a GraphML string.
  """
  def serialize(graph) do
    node_attr = fn data -> %{"label" => Kernel.to_string(data)} end
    edge_attr = fn data -> %{"weight" => Kernel.to_string(data)} end
    serialize_with(node_attr, edge_attr, graph)
  end

  @doc """
  Writes a graph to a GraphML file.
  """
  def write(path, graph) do
    content = serialize(graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Writes a graph to a GraphML file with custom attribute mappers.
  """
  def write_with(path, node_attr, edge_attr, graph) do
    content = serialize_with(node_attr, edge_attr, graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Writes a graph to a GraphML file with typed attributes for Gephi compatibility.
  """
  def write_with_types(path, node_attr, edge_attr, graph) do
    content = serialize_with_types(node_attr, edge_attr, graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Deserializes a GraphML string into a graph with custom data mappers.

  Returns `{:ok, graph}` on success or `{:error, reason}`.
  """
  def deserialize_with(node_folder, edge_folder, xml) do
    parse_graphml(xml, node_folder, edge_folder)
  end

  @doc """
  Deserializes a GraphML string to a graph.

  ## Example

      iex> xml = \"\"\"
      ...> <?xml version="1.0" encoding="UTF-8"?>
      ...> <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      ...>   <graph id="G" edgedefault="directed">
      ...>     <node id="1"><data key="label">Alice</data></node>
      ...>     <node id="2"><data key="label">Bob</data></node>
      ...>   </graph>
      ...> </graphml>
      ...> \"\"\"
      iex> {:ok, graph} = Yog.IO.GraphML.deserialize(xml)
      iex> Yog.Model.node_count(graph)
      2
  """
  def deserialize(xml) do
    parse_graphml(xml, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  @doc """
  Reads a graph from a GraphML file.
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} -> deserialize(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a GraphML file with custom data mappers.
  """
  def read_with(path, node_folder, edge_folder) do
    case File.read(path) do
      {:ok, content} -> deserialize_with(node_folder, edge_folder, content)
      {:error, _} = error -> error
    end
  end

  # Private functions

  defp get_all_edges({:graph, type, _, out_edges, _}) do
    if type == :directed do
      for {from, dests} <- out_edges,
          {to, weight} <- dests do
        {from, to, weight}
      end
    else
      for {from, dests} <- out_edges,
          {to, weight} <- dests,
          from <= to do
        {from, to, weight}
      end
    end
  end

  defp escape_xml(value) do
    value
    |> Kernel.to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp parse_graphml(xml, node_folder, edge_folder) do
    # Parse XML using :xmerl
    xml_charlist = String.to_charlist(xml)

    {doc, _} =
      :xmerl_scan.string(xml_charlist,
        quiet: true,
        space: :normalize
      )

    # Extract graph type (directed/undirected)
    graph_type = extract_graph_type(doc)

    # Extract nodes
    nodes = extract_nodes(doc, node_folder)

    # Build initial graph
    graph = Yog.Model.new(graph_type)

    graph =
      Enum.reduce(nodes, graph, fn {id, data}, acc ->
        Yog.Model.add_node(acc, id, data)
      end)

    # Extract and add edges
    edges = extract_edges(doc, edge_folder)

    final_graph =
      Enum.reduce(edges, graph, fn {from, to, weight}, acc ->
        case Yog.Model.add_edge(acc, from, to, weight) do
          {:ok, new_graph} -> new_graph
          {:error, _} -> acc
        end
      end)

    {:ok, final_graph}
  rescue
    e ->
      {:error, {:parse_error, Exception.message(e)}}
  end

  # Helper to extract string from xmerl result
  defp xmerl_string_value(result) do
    case result do
      {:xmlObj, :string, charlist} -> List.to_string(charlist)
      charlist when is_list(charlist) -> List.to_string(charlist)
      _ -> ""
    end
  end

  defp extract_graph_type(doc) do
    # Find graph element and check edgedefault attribute
    case :xmerl_xpath.string(~c'/graphml/graph/@edgedefault', doc) do
      [_attr | _] ->
        value =
          :xmerl_xpath.string(~c'string(/graphml/graph/@edgedefault)', doc)
          |> xmerl_string_value()

        if value == "undirected", do: :undirected, else: :directed

      [] ->
        :directed
    end
  end

  defp extract_nodes(doc, node_folder) do
    node_elements = :xmerl_xpath.string(~c'/graphml/graph/node', doc)

    Enum.map(node_elements, fn node_elem ->
      # Extract node id
      id_str =
        :xmerl_xpath.string(~c'string(@id)', node_elem)
        |> xmerl_string_value()

      id =
        case Integer.parse(id_str) do
          {int, _} -> int
          :error -> id_str
        end

      # Extract data elements
      data_elements = :xmerl_xpath.string(~c'./data', node_elem)

      attrs =
        Enum.reduce(data_elements, %{}, fn data_elem, acc ->
          key =
            :xmerl_xpath.string(~c'string(@key)', data_elem)
            |> xmerl_string_value()

          value =
            :xmerl_xpath.string(~c'string(.)', data_elem)
            |> xmerl_string_value()

          Map.put(acc, key, value)
        end)

      data = node_folder.(attrs)
      {id, data}
    end)
  end

  defp extract_edges(doc, edge_folder) do
    edge_elements = :xmerl_xpath.string(~c'/graphml/graph/edge', doc)

    Enum.map(edge_elements, fn edge_elem ->
      # Extract source and target
      source_str =
        :xmerl_xpath.string(~c'string(@source)', edge_elem)
        |> xmerl_string_value()

      target_str =
        :xmerl_xpath.string(~c'string(@target)', edge_elem)
        |> xmerl_string_value()

      source =
        case Integer.parse(source_str) do
          {int, _} -> int
          :error -> source_str
        end

      target =
        case Integer.parse(target_str) do
          {int, _} -> int
          :error -> target_str
        end

      # Extract data elements
      data_elements = :xmerl_xpath.string(~c'./data', edge_elem)

      attrs =
        Enum.reduce(data_elements, %{}, fn data_elem, acc ->
          key =
            :xmerl_xpath.string(~c'string(@key)', data_elem)
            |> xmerl_string_value()

          value =
            :xmerl_xpath.string(~c'string(.)', data_elem)
            |> xmerl_string_value()

          Map.put(acc, key, value)
        end)

      weight = edge_folder.(attrs)
      {source, target, weight}
    end)
  end
end
