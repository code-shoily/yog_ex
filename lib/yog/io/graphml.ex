defmodule Yog.IO.GraphML do
  @compile {:no_warn_undefined, [Saxy, Yog.IO.GraphML.SaxyHandler]}
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
  """

  alias Yog.IO.GraphML.Xmerl
  alias Yog.IO.XMLUtils
  alias Yog.Model

  @doc """
  Returns default GraphML serialization options.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec default_options() :: tuple()
  def default_options do
    {:graphml_options, 2, true, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}
  end

  @doc """
  Creates GraphML options with custom formatting.

  Raises `ArgumentError` if parameters are invalid.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec options_with(non_neg_integer(), boolean(), keyword()) :: tuple()
  def options_with(indent, include_declaration, opts \\ [])

  def options_with(indent, include_declaration, opts)
      when is_integer(indent) and indent >= 0 and is_boolean(include_declaration) and
             is_list(opts) do
    node_fmt = Keyword.get(opts, :node_formatter, &Yog.Utils.safe_string/1)
    edge_fmt = Keyword.get(opts, :edge_formatter, &Yog.Utils.safe_string/1)

    if not is_function(node_fmt, 1) do
      raise ArgumentError, "expected :node_formatter to be an arity-1 function"
    end

    if not is_function(edge_fmt, 1) do
      raise ArgumentError, "expected :edge_formatter to be an arity-1 function"
    end

    {:graphml_options, indent, include_declaration, node_fmt, edge_fmt}
  end

  def options_with(indent, include_declaration, _opts) do
    raise ArgumentError,
          "expected non-negative integer indent and boolean include_declaration, got: #{inspect({indent, include_declaration})}"
  end

  @doc """
  Serializes a graph to GraphML string with custom attribute mappers.

  Raises `ArgumentError` if mappers or graph are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec serialize_with((any() -> map()), (any() -> map()), Yog.graph() | Yog.DAG.t()) ::
          String.t()
  def serialize_with(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GraphML with typed attributes for Gephi compatibility.

  Raises `ArgumentError` if mappers or graph are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec serialize_with_types((any() -> map()), (any() -> map()), Yog.graph() | Yog.DAG.t()) ::
          String.t()
  def serialize_with_types(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GraphML with typed attributes and custom options.

  Raises `ArgumentError` if arguments or options are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec serialize_with_types_and_options(
          (any() -> map()),
          (any() -> map()),
          tuple(),
          Yog.graph() | Yog.DAG.t()
        ) :: String.t()
  def serialize_with_types_and_options(node_attr, edge_attr, options, graph) do
    serialize_with_options(node_attr, edge_attr, options, graph)
  end

  @doc """
  Serializes a graph to a GraphML string with custom options.

  Raises `ArgumentError` if arguments or options are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec serialize_with_options(
          (any() -> map()),
          (any() -> map()),
          tuple(),
          Yog.graph() | Yog.DAG.t()
        ) :: String.t()
  def serialize_with_options(node_attr, edge_attr, options, graph) do
    if not is_function(node_attr, 1) do
      raise ArgumentError, "expected node_attr to be an arity-1 function"
    end

    if not is_function(edge_attr, 1) do
      raise ArgumentError, "expected edge_attr to be an arity-1 function"
    end

    target_graph =
      case graph do
        %Yog.Graph{} ->
          graph

        %Yog.DAG{graph: inner} ->
          inner

        _ ->
          raise ArgumentError, "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(graph)}"
      end

    {indent, include_xml_declaration, node_fmt, edge_fmt} =
      case options do
        {:graphml_options, i, d, nf, ef}
        when is_integer(i) and i >= 0 and is_boolean(d) and is_function(nf, 1) and
               is_function(ef, 1) ->
          {i, d, nf, ef}

        {:graphml_options, i, d} when is_integer(i) and i >= 0 and is_boolean(d) ->
          {i, d, &Kernel.to_string/1, &Kernel.to_string/1}

        _ ->
          raise ArgumentError, "expected valid graphml_options tuple, got: #{inspect(options)}"
      end

    %Yog.Graph{kind: type, nodes: nodes_map} = target_graph

    node_attrs_list = Enum.map(nodes_map, fn {_id, data} -> node_attr.(data) end)
    edges = Model.all_edges(target_graph)
    edge_attrs_list = Enum.map(edges, fn {_from, _to, weight} -> edge_attr.(weight) end)

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

    indent_str = String.duplicate(" ", indent)

    xml_declaration =
      if include_xml_declaration do
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      else
        ""
      end

    graphml_open = "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">\n"

    key_defs =
      (Enum.map(node_keys, fn key ->
         indent_str <>
           "<key id=\"#{escape_xml(key, node_fmt)}\" for=\"node\" attr.name=\"#{escape_xml(key, node_fmt)}\" attr.type=\"string\"/>"
       end) ++
         Enum.map(edge_keys, fn key ->
           indent_str <>
             "<key id=\"#{escape_xml(key, edge_fmt)}\" for=\"edge\" attr.name=\"#{escape_xml(key, edge_fmt)}\" attr.type=\"string\"/>"
         end))
      |> Enum.join("\n")

    key_defs_section = if key_defs != "", do: key_defs <> "\n", else: ""

    edge_default = if type == :directed, do: "directed", else: "undirected"
    graph_open = indent_str <> "<graph id=\"G\" edgedefault=\"#{edge_default}\">\n"

    nodes_xml =
      nodes_map
      |> Enum.sort()
      |> Enum.map_join("\n", fn {id, data} ->
        attrs = node_attr.(data)

        data_elements =
          Enum.map_join(attrs, "\n", fn {key, value} ->
            indent_str <>
              indent_str <>
              indent_str <>
              "<data key=\"#{escape_xml(key, node_fmt)}\">#{escape_xml(value, node_fmt)}</data>"
          end)

        node_content =
          if data_elements != "" do
            "\n" <> data_elements <> "\n" <> indent_str <> indent_str
          else
            ""
          end

        indent_str <> indent_str <> "<node id=\"#{node_fmt.(id)}\">#{node_content}</node>"
      end)

    nodes_section = if nodes_xml != "", do: nodes_xml <> "\n", else: ""

    edges_xml =
      edges
      |> Enum.map_join("\n", fn {from, to, weight} ->
        attrs = edge_attr.(weight)

        data_elements =
          Enum.map_join(attrs, "\n", fn {key, value} ->
            indent_str <>
              indent_str <>
              indent_str <>
              "<data key=\"#{escape_xml(key, edge_fmt)}\">#{escape_xml(value, edge_fmt)}</data>"
          end)

        edge_content =
          if(data_elements != "",
            do: "\n" <> data_elements <> "\n" <> indent_str <> indent_str,
            else: ""
          )

        indent_str <>
          indent_str <>
          "<edge source=\"#{node_fmt.(from)}\" target=\"#{node_fmt.(to)}\">#{edge_content}</edge>"
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

  Raises `ArgumentError` if graph is invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec serialize(Yog.graph() | Yog.DAG.t()) :: String.t()
  def serialize(graph) do
    node_attr = fn data -> %{"label" => Yog.Utils.to_label("", data)} end
    edge_attr = fn data -> %{"weight" => Yog.Utils.to_weight_label(data)} end
    serialize_with(node_attr, edge_attr, graph)
  end

  @doc """
  Writes a graph to a GraphML file using default attribute conversion.

  Raises `ArgumentError` if path is not a binary string or graph is invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec write(String.t(), Yog.graph() | Yog.DAG.t()) :: {:ok, nil} | {:error, atom()}
  def write(path, graph) when is_binary(path) do
    content = serialize(graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  def write(path, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Writes a graph to a GraphML file with custom attribute mappers.

  Raises `ArgumentError` if path is not a binary string or graph/mappers are invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec write_with(String.t(), (any() -> map()), (any() -> map()), Yog.graph() | Yog.DAG.t()) ::
          {:ok, nil} | {:error, atom()}
  def write_with(path, node_attr, edge_attr, graph) when is_binary(path) do
    content = serialize_with(node_attr, edge_attr, graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  def write_with(path, _node_attr, _edge_attr, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Writes a graph to a GraphML file with typed attributes for Gephi compatibility.

  Raises `ArgumentError` if path is not a binary string or graph/mappers are invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec write_with_types(
          String.t(),
          (any() -> map()),
          (any() -> map()),
          Yog.graph() | Yog.DAG.t()
        ) :: {:ok, nil} | {:error, atom()}
  def write_with_types(path, node_attr, edge_attr, graph) when is_binary(path) do
    content = serialize_with_types(node_attr, edge_attr, graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  def write_with_types(path, _node_attr, _edge_attr, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Deserializes a GraphML string into a graph with custom data mappers.

  Raises `ArgumentError` if xml or data mappers are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec deserialize_with((map() -> any()), (map() -> any()), String.t()) ::
          {:ok, Yog.graph()} | {:error, term()}
  def deserialize_with(node_folder, edge_folder, xml) when is_binary(xml) do
    if not is_function(node_folder, 1) do
      raise ArgumentError, "expected node_folder to be an arity-1 function"
    end

    if not is_function(edge_folder, 1) do
      raise ArgumentError, "expected edge_folder to be an arity-1 function"
    end

    parse_graphml(xml, node_folder, edge_folder)
  end

  def deserialize_with(_node_folder, _edge_folder, xml) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  @doc """
  Deserializes a GraphML string to a graph using default conversion.

  Raises `ArgumentError` if xml is not a binary string.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec deserialize(String.t()) :: {:ok, Yog.graph()} | {:error, term()}
  def deserialize(xml) when is_binary(xml) do
    parse_graphml(xml, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  def deserialize(xml) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  @doc """
  Reads a graph from a GraphML file using default conversion.

  Raises `ArgumentError` if path is not a binary string.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec read(String.t()) :: {:ok, Yog.graph()} | {:error, term()}
  def read(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> deserialize(content)
      {:error, _} = error -> error
    end
  end

  def read(path) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Reads a graph from a GraphML file with custom data mappers.

  Raises `ArgumentError` if path is not a binary string or mappers are invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec read_with(String.t(), (map() -> any()), (map() -> any())) ::
          {:ok, Yog.graph()} | {:error, term()}
  def read_with(path, node_folder, edge_folder) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> deserialize_with(node_folder, edge_folder, content)
      {:error, _} = error -> error
    end
  end

  def read_with(path, _node_folder, _edge_folder) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  # Private functions

  defp escape_xml(value, formatter) do
    value
    |> formatter.()
    |> XMLUtils.escape_xml()
  end

  defp parse_graphml(xml, node_folder, edge_folder) do
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

  @doc false
  @spec parse_graphml_xmerl(String.t(), (map() -> any()), (map() -> any())) ::
          {:ok, Yog.graph()} | {:error, term()}
  def parse_graphml_xmerl(xml, node_folder, edge_folder) do
    Xmerl.parse_graphml_xmerl(xml, node_folder, edge_folder)
  end
end
