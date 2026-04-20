defmodule Yog.IO.GraphML.Xmerl do
  @moduledoc false

  alias Yog.IO.XMLUtils

  @doc """
  Builds a graph from an xmerl-parsed XML document.
  """
  def build_graph_from_doc(doc, node_folder, edge_folder) do
    graph_type = extract_graph_type(doc)
    nodes = extract_nodes(doc, node_folder)

    graph =
      Enum.reduce(nodes, Yog.Model.new(graph_type), fn {id, data}, acc ->
        Yog.Model.add_node(acc, id, data)
      end)

    edges = extract_edges(doc, edge_folder)

    final_graph =
      Enum.reduce(edges, graph, fn {from, to, weight}, acc ->
        case Yog.Model.add_edge(acc, from, to, weight) do
          {:ok, new_graph} -> new_graph
          {:error, _} -> acc
        end
      end)

    {:ok, final_graph}
  end

  @doc """
  Parses GraphML XML using the xmerl fallback path.
  """
  def parse_graphml_xmerl(xml, node_folder, edge_folder) do
    case XMLUtils.try_parse_xml(xml) do
      {:ok, doc} ->
        build_graph_from_doc(doc, node_folder, edge_folder)

      {:error, :bad_character} ->
        sanitized_xml = XMLUtils.sanitize_xml(xml)

        case XMLUtils.try_parse_xml(sanitized_xml) do
          {:ok, doc} -> build_graph_from_doc(doc, node_folder, edge_folder)
          {:error, reason} -> {:error, {:parse_error, reason}}
        end

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  @doc """
  Extracts the graph type (directed/undirected) from an xmerl document.
  """
  def extract_graph_type(doc) do
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

  @doc """
  Extracts nodes from an xmerl document.
  """
  def extract_nodes(doc, node_folder) do
    node_elements = :xmerl_xpath.string(~c'/graphml/graph/node', doc)

    Enum.map(node_elements, fn node_elem ->
      id_str =
        :xmerl_xpath.string(~c'string(@id)', node_elem)
        |> xmerl_string_value()

      id =
        case Integer.parse(id_str) do
          {int, _} -> int
          :error -> id_str
        end

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

  @doc """
  Extracts edges from an xmerl document.
  """
  def extract_edges(doc, edge_folder) do
    edge_elements = :xmerl_xpath.string(~c'/graphml/graph/edge', doc)

    Enum.map(edge_elements, fn edge_elem ->
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

  @doc """
  Helper to extract a string value from an xmerl query result.
  """
  def xmerl_string_value(result) do
    case result do
      {:xmlObj, :string, charlist} -> List.to_string(charlist)
      charlist when is_list(charlist) -> List.to_string(charlist)
      _ -> ""
    end
  end
end
