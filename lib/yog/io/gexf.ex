defmodule Yog.IO.GEXF do
  @compile {:no_warn_undefined, [Saxy, Yog.IO.GEXF.SaxyHandler]}
  @moduledoc """
  GEXF (Graph Exchange XML Format) serialization support.

  Provides functions to serialize and deserialize graphs in GEXF format,
  the native format of [Gephi](https://gephi.org/) and supported by
  many other graph visualization tools.

  GEXF is an XML-based format that supports:
  - **Nodes** with typed attributes
  - **Edges** with typed attributes and weights
  - **Directed and undirected** graphs
  - **Visual attributes** (viz namespace): color, size, position
  - **Dynamic graphs** (not yet supported)

  ## Performance

  Uses Saxy for fast streaming SAX parsing when available (same as GraphML).
  Falls back to `:xmerl` otherwise.
  """

  alias Yog.IO.GEXF.Common
  alias Yog.IO.XMLUtils
  alias Yog.Model
  alias Yog.Utils

  @doc """
  Returns default GEXF serialization options.

  The options control data formatting:
  - **node_formatter:** Function to convert node IDs to strings (default: `safe_string/1`)
  - **edge_formatter:** Function to convert edge IDs to strings (default: `safe_string/1`)

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec default_options() :: tuple()
  def default_options do
    {:gexf_options, &Utils.safe_string/1, &Utils.safe_string/1}
  end

  @doc """
  Creates GEXF options with custom formatters.

  Raises `ArgumentError` if formatters are invalid.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec options_with((any() -> any()), (any() -> any())) :: tuple()
  def options_with(node_fmt, edge_fmt) do
    if not is_function(node_fmt, 1) do
      raise ArgumentError, "expected node_fmt to be an arity-1 function"
    end

    if not is_function(edge_fmt, 1) do
      raise ArgumentError, "expected edge_fmt to be an arity-1 function"
    end

    {:gexf_options, node_fmt, edge_fmt}
  end

  @doc """
  Serializes a graph to GEXF format with custom attribute mappers.

  Raises `ArgumentError` if mappers or graph are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec serialize_with((any() -> map()), (any() -> map()), Yog.graph() | Yog.DAG.t()) ::
          String.t()
  def serialize_with(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GEXF format with custom attribute mappers and options.

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

    {node_fmt, edge_fmt} =
      case options do
        {:gexf_options, nf, ef} when is_function(nf, 1) and is_function(ef, 1) ->
          {nf, ef}

        _ ->
          raise ArgumentError, "expected valid gexf_options tuple, got: #{inspect(options)}"
      end

    %Yog.Graph{kind: type, nodes: nodes_map} = target_graph
    edge_default = if type == :directed, do: "directed", else: "undirected"

    node_attrs_list = Enum.map(nodes_map, fn {_id, data} -> node_attr.(data) end)
    edges = Model.all_edges(target_graph)
    edge_attrs_list = Enum.map(edges, fn {_from, _to, weight} -> edge_attr.(weight) end)

    node_keys = Common.discover_keys_with_types(node_attrs_list, "label")
    edge_keys = Common.discover_keys_with_types(edge_attrs_list, "weight")

    [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
      "<gexf xmlns=\"http://gexf.net/1.3\" xmlns:viz=\"http://gexf.net/1.3/viz\" version=\"1.3\">\n",
      "  <graph mode=\"static\" defaultedgetype=\"#{edge_default}\">\n",
      Common.build_attribute_definitions(node_keys, edge_keys),
      Common.build_nodes_xml(nodes_map, node_attr, node_keys, node_fmt),
      build_edges_xml(edges, edge_attr, edge_keys, node_fmt, edge_fmt),
      "  </graph>\n",
      "</gexf>"
    ]
    |> IO.iodata_to_binary()
  end

  @doc """
  Serializes a graph to GEXF format using default attribute conversion.

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
  Writes a graph to a GEXF file using default attribute conversion.

  Raises `ArgumentError` if path is not a binary string or graph is invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec write(String.t(), Yog.graph() | Yog.DAG.t()) :: {:ok, nil} | {:error, atom()}
  def write(path, graph) when is_binary(path) do
    case File.write(path, serialize(graph)) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  def write(path, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Writes a graph to a GEXF file with custom attribute mappers.

  Raises `ArgumentError` if path is not a binary string or graph/mappers are invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O
  """
  @spec write_with(String.t(), (any() -> map()), (any() -> map()), Yog.graph() | Yog.DAG.t()) ::
          {:ok, nil} | {:error, atom()}
  def write_with(path, node_attr, edge_attr, graph) when is_binary(path) do
    case File.write(path, serialize_with(node_attr, edge_attr, graph)) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  def write_with(path, _node_attr, _edge_attr, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Deserializes a GEXF string into a graph with custom data mappers.

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

    parse_gexf(xml, node_folder, edge_folder)
  end

  def deserialize_with(_node_folder, _edge_folder, xml) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  @doc """
  Deserializes a GEXF string to a graph using default conversion.

  Raises `ArgumentError` if xml is not a binary string.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec deserialize(String.t()) :: {:ok, Yog.graph()} | {:error, term()}
  def deserialize(xml) when is_binary(xml) do
    parse_gexf(xml, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  def deserialize(xml) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  @doc """
  Reads a graph from a GEXF file using default conversion.

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
  Reads a graph from a GEXF file with custom data mappers.

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

  # ==========================================================================
  # Serialization helpers
  # ==========================================================================

  defp build_edges_xml(edges, edge_attr, edge_keys, node_fmt, edge_fmt) do
    if edges == [] do
      "    <edges></edges>\n"
    else
      edges_inner =
        edges
        |> Enum.with_index()
        |> Enum.map(fn {{from, to, weight}, idx} ->
          Common.build_single_edge_xml(
            idx,
            from,
            to,
            weight,
            edge_attr,
            edge_keys,
            node_fmt,
            edge_fmt
          )
        end)

      ["    <edges>\n", edges_inner, "    </edges>\n"]
    end
  end

  # ==========================================================================
  # Deserialization
  # ==========================================================================

  defp parse_gexf(xml, node_folder, edge_folder) do
    if Code.ensure_loaded?(Saxy) do
      parse_gexf_saxy(xml, node_folder, edge_folder)
    else
      parse_gexf_xmerl(xml, node_folder, edge_folder)
    end
  end

  defp parse_gexf_saxy(xml, node_folder, edge_folder) do
    initial_state = %Yog.IO.GEXF.SaxyHandler{
      node_folder: node_folder,
      edge_folder: edge_folder,
      multigraph: false
    }

    case Saxy.parse_string(xml, Yog.IO.GEXF.SaxyHandler, initial_state) do
      {:ok, state} ->
        final_graph = Common.build_graph_from_saxy_state(state, Model, false)
        {:ok, final_graph}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  @doc false
  @spec parse_gexf_xmerl(String.t(), (map() -> any()), (map() -> any())) ::
          {:ok, Yog.graph()} | {:error, term()}
  def parse_gexf_xmerl(xml, node_folder, edge_folder) do
    case XMLUtils.try_parse_xml(xml) do
      {:ok, doc} ->
        Common.build_graph_from_doc(doc, node_folder, edge_folder, Model, false)

      {:error, :bad_character} ->
        sanitized_xml = XMLUtils.sanitize_xml(xml)

        case XMLUtils.try_parse_xml(sanitized_xml) do
          {:ok, doc} -> Common.build_graph_from_doc(doc, node_folder, edge_folder, Model, false)
          {:error, reason} -> {:error, {:parse_error, reason}}
        end

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
end
