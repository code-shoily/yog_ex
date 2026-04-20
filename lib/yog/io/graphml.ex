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

  ## Performance

  For optimal performance with large GraphML files, add the optional `saxy`
  dependency to your project:

      {:saxy, "~> 1.5"}

  When available, `saxy` provides a fast streaming SAX parser that significantly
  improves loading times:
  - **Without saxy:** Uses Erlang's `:xmerl` (DOM parser, slower for large files)
  - **With saxy:** Uses streaming parser (up to 3-4x faster for large files)

  For example, loading a 60MB GraphML file with ~500k edges:
  - xmerl: ~20 seconds
  - saxy: ~6 seconds

  ## Examples

  ### Basic Serialization and Deserialization

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "friend")
      iex> xml = Yog.IO.GraphML.serialize(graph)
      iex> String.contains?(xml, "Alice")
      true
      iex> String.contains?(xml, "Bob")
      true

  ### Custom Attributes with Type Information

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, %{name: "Alice", age: 30})
      ...> |> Yog.add_node(2, %{name: "Bob", age: 25})
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: %{weight: 5, relation: "friend"})
      iex> node_attr = fn data ->
      ...>   %{"label" => data.name, "age" => Integer.to_string(data.age)}
      ...> end
      iex> edge_attr = fn data ->
      ...>   %{"weight" => Integer.to_string(data.weight), "type" => data.relation}
      ...> end
      iex> xml = Yog.IO.GraphML.serialize_with(node_attr, edge_attr, graph)
      iex> String.contains?(xml, "Alice")
      true

  ### Reading from File

      # Read a GraphML file from disk
      {:ok, graph} = Yog.IO.GraphML.read("network.graphml")

  ### Writing to File

      # Write with default string conversion
      Yog.IO.GraphML.write("output.graphml", graph)

  ## Output Format

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
    <key id="label" for="node" attr.name="label" attr.type="string"/>
    <key id="weight" for="edge" attr.name="weight" attr.type="string"/>
    <graph id="G" edgedefault="directed">
      <node id="1">
        <data key="label">Alice</data>
      </node>
      <node id="2">
        <data key="label">Bob</data>
      </node>
      <edge source="1" target="2">
        <data key="weight">friend</data>
      </edge>
    </graph>
  </graphml>
  ```

  ## References

  - [GraphML Specification](http://graphml.graphdrawing.org/)
  - [GraphML Primer](http://graphml.graphdrawing.org/primer/graphml-primer.html)
  - [Gephi GraphML Support](https://gephi.org/users/supported-graph-formats/graphml-format/)
  """

  alias Yog.IO.GraphML.Xmerl
  alias Yog.Model

  @doc """
  Returns default GraphML serialization options.

  The options control XML formatting:
  - **indent:** Number of spaces for indentation (default: 2)
  - **include_xml_declaration:** Whether to include XML declaration (default: true)

  ## Example

      iex> {:graphml_options, indent, include_xml_declaration} = Yog.IO.GraphML.default_options()
      iex> indent
      2
      iex> include_xml_declaration
      true
  """
  def default_options do
    {:graphml_options, 2, true}
  end

  @doc """
  Serializes a graph to GraphML string with custom attribute mappers.

  This is the main serialization function allowing you to control how node and
  edge data are converted to GraphML attributes.

  **Time Complexity:** O(V + E) where V is the number of nodes and E is edges

  ## Parameters

  - `node_attr` - Function that converts node data to a map of attributes
    `(node_data) -> %{string => string}`
  - `edge_attr` - Function that converts edge data to a map of attributes
    `(edge_data) -> %{string => string}`
  - `graph` - The graph to serialize

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, %{name: "Alice", role: "admin"})
      ...> |> Yog.add_node(2, %{name: "Bob", role: "user"})
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: %{since: "2024"})
      iex> node_attr = fn data ->
      ...>   %{"label" => data.name, "role" => data.role}
      ...> end
      iex> edge_attr = fn data ->
      ...>   %{"since" => data.since}
      ...> end
      iex> xml = Yog.IO.GraphML.serialize_with(node_attr, edge_attr, graph)
      iex> String.contains?(xml, "Alice") and String.contains?(xml, "admin")
      true
  """
  def serialize_with(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GraphML with typed attributes for Gephi compatibility.

  Identical to `serialize_with/3` but explicitly intended for tools like Gephi
  that benefit from type information in the key definitions.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Node1")
      ...> |> Yog.add_node(2, "Node2")
      iex> node_attr = fn data -> %{"label" => data} end
      iex> edge_attr = fn _ -> %{} end
      iex> xml = Yog.IO.GraphML.serialize_with_types(node_attr, edge_attr, graph)
      iex> String.contains?(xml, ~s(attr.type="string"))
      true
  """
  def serialize_with_types(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GraphML with typed attributes and custom options.

  Provides full control over both attribute mapping and output formatting.

  **Time Complexity:** O(V + E)

  ## Parameters

  - `node_attr` - Function to convert node data to attributes
  - `edge_attr` - Function to convert edge data to attributes
  - `options` - GraphML options tuple (see `default_options/0`)
  - `graph` - The graph to serialize

  ## Example

      iex> graph = Yog.directed() |> Yog.add_node(1, "A")
      iex> node_attr = fn data -> %{"label" => data} end
      iex> edge_attr = fn _ -> %{} end
      iex> options = {:graphml_options, 4, false}  # 4-space indent, no XML declaration
      iex> xml = Yog.IO.GraphML.serialize_with_types_and_options(node_attr, edge_attr, options, graph)
      iex> String.contains?(xml, "<?xml")
      false
  """
  def serialize_with_types_and_options(node_attr, edge_attr, options, graph) do
    serialize_with_options(node_attr, edge_attr, options, graph)
  end

  @doc """
  Serializes a graph to a GraphML string with custom options.
  """
  def serialize_with_options(node_attr, edge_attr, options, graph) do
    {:graphml_options, indent, include_xml_declaration} = options
    %Yog.Graph{kind: type, nodes: nodes_map} = graph

    # Collect all node and edge attributes
    node_attrs_list =
      nodes_map
      |> Enum.map(fn {_id, data} -> node_attr.(data) end)

    edges = Model.all_edges(graph)

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
  Serializes a graph to GraphML string using default attribute conversion.

  Node and edge data are converted to strings and stored as "label" and "weight"
  attributes respectively. For custom attribute mapping, use `serialize_with/3`.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "friend")
      iex> xml = Yog.IO.GraphML.serialize(graph)
      iex> String.contains?(xml, ~s(<node id="1">)) and String.contains?(xml, "Alice")
      true
  """
  def serialize(graph) do
    node_attr = fn data -> %{"label" => Yog.Utils.to_label("", data)} end
    edge_attr = fn data -> %{"weight" => Yog.Utils.to_weight_label(data)} end
    serialize_with(node_attr, edge_attr, graph)
  end

  @doc """
  Writes a graph to a GraphML file using default attribute conversion.

  This is a convenience function that combines `serialize/1` with `File.write/2`.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to write to
  - `graph` - The graph to serialize

  ## Returns

  - `{:ok, nil}` on success
  - `{:error, reason}` on file write failure

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "friend")

      Yog.IO.GraphML.write("network.graphml", graph)
      # => {:ok, nil}
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

  Use this when you need control over how node and edge data are converted
  to GraphML attributes.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to write to
  - `node_attr` - Function to convert node data to attributes
  - `edge_attr` - Function to convert edge data to attributes
  - `graph` - The graph to serialize

  ## Returns

  - `{:ok, nil}` on success
  - `{:error, reason}` on file write failure

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, %{name: "Alice", score: 95})
      |> Yog.add_node(2, %{name: "Bob", score: 87})

      node_attr = fn data ->
        %{
          "label" => data.name,
          "score" => Integer.to_string(data.score)
        }
      end
      edge_attr = fn _ -> %{} end

      Yog.IO.GraphML.write_with("network.graphml", node_attr, edge_attr, graph)
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

  Identical to `write_with/4` but explicitly intended for tools that require
  type annotations.

  **Time Complexity:** O(V + E) + file I/O

  ## Example

      graph = Yog.directed() |> Yog.add_node(1, "Node1")

      node_attr = fn data -> %{"label" => data} end
      edge_attr = fn _ -> %{} end

      Yog.IO.GraphML.write_with_types("network.graphml", node_attr, edge_attr, graph)
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

  This function allows you to transform the raw GraphML attributes into
  custom Elixir data structures as the graph is built.

  **Time Complexity:** O(V + E) where V is nodes and E is edges

  ## Parameters

  - `node_folder` - Function to transform node attributes to node data
    `(attrs :: map) -> node_data`
  - `edge_folder` - Function to transform edge attributes to edge data
    `(attrs :: map) -> edge_data`
  - `xml` - The GraphML XML string to parse

  ## Returns

  - `{:ok, graph}` on success
  - `{:error, {:parse_error, reason}}` on parsing failure

  ## Example

      iex> xml = \"\"\"
      ...> <?xml version="1.0" encoding="UTF-8"?>
      ...> <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      ...>   <graph id="G" edgedefault="directed">
      ...>     <node id="1">
      ...>       <data key="name">Alice</data>
      ...>       <data key="age">30</data>
      ...>     </node>
      ...>     <node id="2">
      ...>       <data key="name">Bob</data>
      ...>       <data key="age">25</data>
      ...>     </node>
      ...>     <edge source="1" target="2">
      ...>       <data key="weight">5</data>
      ...>     </edge>
      ...>   </graph>
      ...> </graphml>
      ...> \"\"\"
      iex> node_folder = fn attrs ->
      ...>   %{name: Map.get(attrs, "name"), age: String.to_integer(Map.get(attrs, "age", "0"))}
      ...> end
      iex> edge_folder = fn attrs ->
      ...>   String.to_integer(Map.get(attrs, "weight", "1"))
      ...> end
      iex> {:ok, graph} = Yog.IO.GraphML.deserialize_with(node_folder, edge_folder, xml)
      iex> Yog.Model.node_count(graph)
      2
  """
  def deserialize_with(node_folder, edge_folder, xml) do
    parse_graphml(xml, node_folder, edge_folder)
  end

  @doc """
  Deserializes a GraphML string to a graph using default conversion.

  Node and edge attributes are stored as-is in maps. For custom data structures,
  use `deserialize_with/3`.

  **Time Complexity:** O(V + E) where V is nodes and E is edges

  ## Returns

  - `{:ok, graph}` on success
  - `{:error, {:parse_error, reason}}` on parsing failure

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

  ## Performance Note

  For large files, parsing automatically uses the fast `saxy` parser when available,
  falling back to `:xmerl` otherwise. See module documentation for performance details.
  """
  def deserialize(xml) do
    parse_graphml(xml, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  @doc """
  Reads a graph from a GraphML file using default conversion.

  This is a convenience function that combines `File.read/1` with `deserialize/1`.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to read from

  ## Returns

  - `{:ok, graph}` on success
  - `{:error, reason}` on file read or parse failure

  ## Example

      # Read a GraphML file exported from Gephi or NetworkX
      {:ok, graph} = Yog.IO.GraphML.read("social_network.graphml")

      # Check what we loaded
      IO.puts("Nodes: \#{Yog.Model.node_count(graph)}")
      IO.puts("Edges: \#{Yog.Model.edge_count(graph)}")
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} -> deserialize(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a GraphML file with custom data mappers.

  Use this when you want to transform GraphML attributes into custom
  Elixir data structures during loading.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to read from
  - `node_folder` - Function to transform node attributes to node data
  - `edge_folder` - Function to transform edge attributes to edge data

  ## Returns

  - `{:ok, graph}` on success
  - `{:error, reason}` on file read or parse failure

  ## Example

      # Transform GraphML data to custom structs
      node_folder = fn attrs ->
        %Person{
          name: Map.get(attrs, "name", "Unknown"),
          score: String.to_integer(Map.get(attrs, "score", "0"))
        }
      end

      edge_folder = fn attrs ->
        %Relationship{
          type: Map.get(attrs, "type", "knows"),
          strength: String.to_float(Map.get(attrs, "strength", "0.5"))
        }
      end

      {:ok, graph} = Yog.IO.GraphML.read_with(
        "network.graphml",
        node_folder,
        edge_folder
      )
  """
  def read_with(path, node_folder, edge_folder) do
    case File.read(path) do
      {:ok, content} -> deserialize_with(node_folder, edge_folder, content)
      {:error, _} = error -> error
    end
  end

  # Private functions

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
    # Use fast SAX parser if available, otherwise fall back to xmerl
    if Code.ensure_loaded?(Saxy) do
      parse_graphml_saxy(xml, node_folder, edge_folder)
    else
      parse_graphml_xmerl(xml, node_folder, edge_folder)
    end
  end

  defp parse_graphml_saxy(xml, node_folder, edge_folder) do
    initial_state = %Yog.IO.GraphML.SaxyHandler{
      node_folder: node_folder,
      edge_folder: edge_folder
    }

    case Saxy.parse_string(xml, Yog.IO.GraphML.SaxyHandler, initial_state) do
      {:ok, state} ->
        # Build graph from collected data
        graph = Yog.Model.new(state.graph_type)

        graph =
          Enum.reduce(state.nodes, graph, fn {id, data}, acc ->
            Yog.Model.add_node(acc, id, data)
          end)

        final_graph =
          Enum.reduce(state.edges, graph, fn {from, to, weight}, acc ->
            case Yog.Model.add_edge(acc, from, to, weight) do
              {:ok, new_graph} -> new_graph
              {:error, _} -> acc
            end
          end)

        {:ok, final_graph}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp parse_graphml_xmerl(xml, node_folder, edge_folder) do
    Xmerl.parse_graphml_xmerl(xml, node_folder, edge_folder)
  end
end
