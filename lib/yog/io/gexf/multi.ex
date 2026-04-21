defmodule Yog.IO.GEXF.Multi do
  @moduledoc """
  GEXF serialization support for **multigraphs** (`Yog.Multi.Model.Graph`).

  Mirrors `Yog.IO.GEXF` but works with parallel edges. Each edge in the
  multigraph is preserved as a distinct `<edge>` element with its internal
  edge ID.
  """

  alias Yog.IO.GEXF.Common
  alias Yog.IO.XMLUtils
  alias Yog.Multi.Model
  alias Yog.Utils

  @doc """
  Returns default GEXF serialization options.
  """
  def default_options do
    {:gexf_options, &Utils.safe_string/1, &Utils.safe_string/1}
  end

  @doc """
  Creates GEXF options with custom formatters.
  """
  def options_with(node_fmt, edge_fmt) do
    {:gexf_options, node_fmt, edge_fmt}
  end

  @doc """
  Serializes a multigraph to GEXF with custom attribute mappers.
  """
  def serialize_with(node_attr, edge_attr, graph) do
    serialize_with_options(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a multigraph to GEXF format with custom attribute mappers and options.
  """
  def serialize_with_options(node_attr, edge_attr, options, graph) do
    {:gexf_options, node_fmt, edge_fmt} = options
    %Model.Graph{kind: type, nodes: nodes_map, edges: edges_map} = graph
    edge_default = if type == :directed, do: "directed", else: "undirected"

    node_attrs_list = Enum.map(nodes_map, fn {_id, data} -> node_attr.(data) end)

    edge_attrs_list =
      Enum.map(edges_map, fn {_eid, {_from, _to, weight}} -> edge_attr.(weight) end)

    node_keys = Common.discover_keys_with_types(node_attrs_list, "label")
    edge_keys = Common.discover_keys_with_types(edge_attrs_list, "weight")

    [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
      "<gexf xmlns=\"http://gexf.net/1.3\" xmlns:viz=\"http://gexf.net/1.3/viz\" version=\"1.3\">\n",
      "  <graph mode=\"static\" defaultedgetype=\"#{edge_default}\">\n",
      Common.build_attribute_definitions(node_keys, edge_keys),
      Common.build_nodes_xml(nodes_map, node_attr, node_keys, node_fmt),
      build_edges_xml(edges_map, edge_attr, edge_keys, node_fmt, edge_fmt),
      "  </graph>\n",
      "</gexf>"
    ]
    |> IO.iodata_to_binary()
  end

  @doc """
  Serializes a multigraph to GEXF using default attribute conversion.
  """
  def serialize(graph) do
    node_attr = fn data -> %{"label" => Yog.Utils.to_label("", data)} end
    edge_attr = fn data -> %{"weight" => Yog.Utils.to_weight_label(data)} end
    serialize_with(node_attr, edge_attr, graph)
  end

  @doc """
  Writes a multigraph to a GEXF file using default attribute conversion.
  """
  def write(path, graph) do
    case File.write(path, serialize(graph)) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Writes a multigraph to a GEXF file with custom attribute mappers.
  """
  def write_with(path, node_attr, edge_attr, graph) do
    case File.write(path, serialize_with(node_attr, edge_attr, graph)) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Deserializes a GEXF string into a **multigraph** with custom data mappers.
  """
  def deserialize_with(node_folder, edge_folder, xml) do
    parse_gexf_multi(xml, node_folder, edge_folder)
  end

  @doc """
  Deserializes a GEXF string to a multigraph using default conversion.
  """
  def deserialize(xml) do
    parse_gexf_multi(xml, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  @doc """
  Reads a multigraph from a GEXF file using default conversion.
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} -> deserialize(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a multigraph from a GEXF file with custom data mappers.
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

  defp build_edges_xml(edges_map, edge_attr, edge_keys, node_fmt, edge_fmt) do
    if map_size(edges_map) == 0 do
      "    <edges></edges>\n"
    else
      edges_inner =
        edges_map
        |> Enum.sort_by(fn {eid, _} -> eid end)
        |> Enum.map(fn {eid, {from, to, weight}} ->
          Common.build_single_edge_xml(
            eid,
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

  defp parse_gexf_multi(xml, node_folder, edge_folder) do
    if Code.ensure_loaded?(Saxy) do
      parse_gexf_multi_saxy(xml, node_folder, edge_folder)
    else
      parse_gexf_multi_xmerl(xml, node_folder, edge_folder)
    end
  end

  defp parse_gexf_multi_saxy(xml, node_folder, edge_folder) do
    initial_state = %Yog.IO.GEXF.SaxyHandler{
      node_folder: node_folder,
      edge_folder: edge_folder,
      multigraph: true
    }

    case Saxy.parse_string(xml, Yog.IO.GEXF.SaxyHandler, initial_state) do
      {:ok, state} ->
        final_graph = Common.build_graph_from_saxy_state(state, Model, true)
        {:ok, final_graph}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp parse_gexf_multi_xmerl(xml, node_folder, edge_folder) do
    case XMLUtils.try_parse_xml(xml) do
      {:ok, doc} ->
        Common.build_graph_from_doc(doc, node_folder, edge_folder, Model, true)

      {:error, :bad_character} ->
        sanitized_xml = XMLUtils.sanitize_xml(xml)

        case XMLUtils.try_parse_xml(sanitized_xml) do
          {:ok, doc} -> Common.build_graph_from_doc(doc, node_folder, edge_folder, Model, true)
          {:error, reason} -> {:error, {:parse_error, reason}}
        end

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
end
