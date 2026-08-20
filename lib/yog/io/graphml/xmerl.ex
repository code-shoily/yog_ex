defmodule Yog.IO.GraphML.Xmerl do
  @moduledoc """
  Fallback GraphML parser using `:xmerl`.

  Provides XPath-based XML parsing routines for GraphML graphs when `Saxy` streaming parser is absent or for direct fallback processing.
  """

  alias Yog.IO.XMLUtils

  @doc """
  Builds a graph from an xmerl-parsed XML document.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec build_graph_from_doc(tuple(), (map() -> any()), (map() -> any())) :: {:ok, Yog.graph()}
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

  Raises `ArgumentError` if xml or folder functions are invalid.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec parse_graphml_xmerl(String.t(), (map() -> any()), (map() -> any())) ::
          {:ok, Yog.graph()} | {:error, term()}
  def parse_graphml_xmerl(xml, node_folder, edge_folder) when is_binary(xml) do
    if not is_function(node_folder, 1) do
      raise ArgumentError, "expected node_folder to be an arity-1 function"
    end

    if not is_function(edge_folder, 1) do
      raise ArgumentError, "expected edge_folder to be an arity-1 function"
    end

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

  def parse_graphml_xmerl(xml, _node_folder, _edge_folder) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  @doc """
  Extracts the graph type (directed/undirected) from an xmerl document.

  Time complexity: $\\mathcal{O}(1)$
  """
  @spec extract_graph_type(tuple()) :: :directed | :undirected
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

  Time complexity: $\\mathcal{O}(V \\cdot K)$ where $K$ is data attribute count per node.
  """
  @spec extract_nodes(tuple(), (map() -> any())) :: list({any(), any()})
  def extract_nodes(doc, node_folder) do
    node_elements = :xmerl_xpath.string(~c'/graphml/graph/node', doc)

    Enum.map(node_elements, fn node_elem ->
      id_str =
        :xmerl_xpath.string(~c'string(@id)', node_elem)
        |> xmerl_string_value()

      id = parse_id(id_str)
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

  Time complexity: $\\mathcal{O}(E \\cdot K)$ where $K$ is data attribute count per edge.
  """
  @spec extract_edges(tuple(), (map() -> any())) :: list({any(), any(), any()})
  def extract_edges(doc, edge_folder) do
    edge_elements = :xmerl_xpath.string(~c'/graphml/graph/edge', doc)

    Enum.map(edge_elements, fn edge_elem ->
      source_str =
        :xmerl_xpath.string(~c'string(@source)', edge_elem)
        |> xmerl_string_value()

      target_str =
        :xmerl_xpath.string(~c'string(@target)', edge_elem)
        |> xmerl_string_value()

      source = parse_id(source_str)
      target = parse_id(target_str)

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

  Time complexity: $\\mathcal{O}(N)$ where $N$ is charlist length.
  """
  @spec xmerl_string_value(any()) :: String.t()
  def xmerl_string_value(result) do
    case result do
      {:xmlObj, :string, charlist} -> List.to_string(charlist)
      charlist when is_list(charlist) -> List.to_string(charlist)
      _ -> ""
    end
  end

  defp parse_id(id_str) do
    case Integer.parse(id_str) do
      {int, ""} -> int
      _ -> id_str
    end
  end
end
