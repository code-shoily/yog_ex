defmodule Yog.IO.GEXF do
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

  @doc """
  Serializes a graph to GEXF format with custom attribute mappers.
  """
  def serialize_with(node_attr, edge_attr, graph) do
    %Yog.Graph{kind: type, nodes: nodes_map} = graph
    edge_default = if type == :directed, do: "directed", else: "undirected"

    node_attrs_list = Enum.map(nodes_map, fn {_id, data} -> node_attr.(data) end)
    edges = Model.all_edges(graph)
    edge_attrs_list = Enum.map(edges, fn {_from, _to, weight} -> edge_attr.(weight) end)

    node_keys = Common.discover_keys_with_types(node_attrs_list, "label")
    edge_keys = Common.discover_keys_with_types(edge_attrs_list, "weight")

    [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
      "<gexf xmlns=\"http://gexf.net/1.3\" xmlns:viz=\"http://gexf.net/1.3/viz\" version=\"1.3\">\n",
      "  <graph mode=\"static\" defaultedgetype=\"#{edge_default}\">\n",
      Common.build_attribute_definitions(node_keys, edge_keys),
      Common.build_nodes_xml(nodes_map, node_attr, node_keys),
      build_edges_xml(edges, edge_attr, edge_keys),
      "  </graph>\n",
      "</gexf>"
    ]
    |> IO.iodata_to_binary()
  end

  @doc """
  Serializes a graph to GEXF format using default attribute conversion.
  """
  def serialize(graph) do
    node_attr = fn data -> %{"label" => Yog.Utils.to_label("", data)} end
    edge_attr = fn data -> %{"weight" => Yog.Utils.to_weight_label(data)} end
    serialize_with(node_attr, edge_attr, graph)
  end

  @doc """
  Writes a graph to a GEXF file using default attribute conversion.
  """
  def write(path, graph) do
    case File.write(path, serialize(graph)) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Writes a graph to a GEXF file with custom attribute mappers.
  """
  def write_with(path, node_attr, edge_attr, graph) do
    case File.write(path, serialize_with(node_attr, edge_attr, graph)) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Deserializes a GEXF string into a graph with custom data mappers.
  """
  def deserialize_with(node_folder, edge_folder, xml) do
    parse_gexf(xml, node_folder, edge_folder)
  end

  @doc """
  Deserializes a GEXF string to a graph using default conversion.
  """
  def deserialize(xml) do
    parse_gexf(xml, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  @doc """
  Reads a graph from a GEXF file using default conversion.
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} -> deserialize(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a GEXF file with custom data mappers.
  """
  def read_with(path, node_folder, edge_folder) do
    case File.read(path) do
      {:ok, content} -> deserialize_with(node_folder, edge_folder, content)
      {:error, _} = error -> error
    end
  end

  # ==========================================================================
  # Serialization helpers
  # ==========================================================================

  defp build_edges_xml(edges, edge_attr, edge_keys) do
    if edges == [] do
      "    <edges></edges>\n"
    else
      edges_inner =
        edges
        |> Enum.with_index()
        |> Enum.map(fn {{from, to, weight}, idx} ->
          Common.build_single_edge_xml(idx, from, to, weight, edge_attr, edge_keys)
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

  defp parse_gexf_xmerl(xml, node_folder, edge_folder) do
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
