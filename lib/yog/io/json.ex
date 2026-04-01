defmodule Yog.IO.JSON do
  @moduledoc """
  JSON format import/export for graph data exchange.

  This module provides comprehensive JSON serialization capabilities for graph data,
  supporting multiple formats used by popular visualization libraries, as well as
  import functionality for round-trip serialization.

  ## Format Support

  - **Generic**: Full metadata with type preservation
  - **D3Force**: D3.js force-directed graphs
  - **Cytoscape**: Cytoscape.js network visualization
  - **VisJs**: vis.js network format
  - **NetworkX**: Python NetworkX compatibility

  ## Examples

  ### Export to JSON

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")
      iex>
      iex> json_string = Yog.IO.JSON.to_json(graph)
      iex> String.contains?(json_string, "Alice")
      true

  ### Import from JSON

      iex> json = ~s|{"graph_type":"directed","nodes":[{"id":1,"data":"Alice"},{"id":2,"data":"Bob"}],"edges":[{"source":1,"target":2,"weight":"follows"}]}|
      iex> {:ok, graph} = Yog.IO.JSON.from_json(json)
      iex> Yog.Model.order(graph)
      2

  ### Import from Map (PostgreSQL JSONB)

      iex> map = %{
      ...>   "graph_type" => "undirected",
      ...>   "nodes" => [%{"id" => 1, "data" => "A"}, %{"id" => 2, "data" => "B"}],
      ...>   "edges" => [%{"source" => 1, "target" => 2, "weight" => 1}]
      ...> }
      iex> {:ok, graph} = Yog.IO.JSON.from_map(map)
      iex> Yog.Model.edge_count(graph)
      1
  """

  alias Yog.Model

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
  def to_json(graph, options \\ default_export_options()) do
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
  def to_json_file(graph, path, options \\ default_export_options()) do
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
  def to_json_multi(graph, options \\ default_export_options()) do
    {:json_export_options, _format, include_metadata?, node_ser, edge_ser, _pretty?, _meta} =
      options

    to_generic_multi_format(graph, node_ser, edge_ser, include_metadata?)
    |> Jason.encode!()
  end

  @doc """
  Exports a multigraph to a JSON file.
  """
  def to_json_file_multi(graph, path, options \\ default_export_options()) do
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
    %Yog.Graph{kind: type, nodes: nodes_map} = graph
    graph_type = if type == :directed, do: "directed", else: "undirected"
    edges = Model.all_edges(graph)

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
    %Yog.Graph{kind: type, nodes: nodes_map} = graph
    directed = type == :directed
    edges = Model.all_edges(graph)

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
    %Yog.Graph{nodes: nodes_map} = graph
    edges = Model.all_edges(graph)

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
    %Yog.Graph{nodes: nodes_map} = graph
    edges = Model.all_edges(graph)

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
    %Yog.Graph{nodes: nodes_map} = graph
    edges = Model.all_edges(graph)

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
    # Note: using direct field access as this function handles both Yog.Graph and Yog.Multi.Graph
    # This will be replaced with protocol dispatch when protocols are implemented
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
    %Yog.Graph{kind: type} = graph

    %{
      node_count: Yog.Model.order(graph),
      edge_count: length(Model.all_edges(graph)),
      directed: type == :directed
    }
  end

  defp build_multi_metadata(graph) do
    %{
      # Note: using direct field access as this function handles both Yog.Graph and Yog.Multi.Graph
      node_count: map_size(graph.nodes),
      edge_count: map_size(graph.edges),
      directed: graph.kind == :directed
    }
  end

  # ============= Detection Functions =============

  @doc """
  Detects the JSON graph format of the given input.

  Supports detection from both JSON strings and decoded maps.

  ## Parameters

  - `input` - JSON string or map to detect the format of

  ## Returns

  - `{:ok, type}` - One of `:yog_generic`, `:network_x`, `:d3_force`, `:cytoscape`, `:visjs`, or `:simple`
  - `{:error, reason}` - If input is a string and parsing fails

  ## Examples

      iex> json = ~s|{"graph_type":"directed","nodes":[],"edges":[]}|
      iex> Yog.IO.JSON.json_type(json)
      {:ok, :yog_generic}

      iex> network_x_map = %{"nodes" => [], "links" => [], "directed" => true}
      iex> Yog.IO.JSON.json_type(network_x_map)
      {:ok, :network_x}

      iex> d3_force_map = %{"nodes" => [], "links" => []}
      iex> Yog.IO.JSON.json_type(d3_force_map)
      {:ok, :d3_force}
  """
  @spec json_type(String.t() | map()) :: {:ok, atom()} | {:error, String.t()}
  def json_type(input) when is_binary(input) do
    case Jason.decode(input) do
      {:ok, map} -> json_type(map)
      {:error, _} = error -> error
    end
  end

  def json_type(map) when is_map(map) do
    {:ok, detect_format(map)}
  end

  @doc """
  Detects the JSON graph format, raising on error for string input.

  ## Examples

      iex> json = ~s|{"elements": []}|
      iex> Yog.IO.JSON.json_type!(json)
      :cytoscape
  """
  @spec json_type!(String.t() | map()) :: atom()
  def json_type!(input) do
    case json_type(input) do
      {:ok, type} -> type
      {:error, reason} -> raise ArgumentError, "Failed to detect JSON format: #{inspect(reason)}"
    end
  end

  # ============= Import Functions =============

  @doc """
  Parses a JSON string and creates a graph.

  Supports the generic Yog format and common variations.

  ## Parameters

  - `json_string` - JSON string to parse

  ## Returns

  - `{:ok, graph}` - Successfully parsed graph
  - `{:error, reason}` - Parsing failed

  ## Examples

      iex> json = ~s|{"graph_type":"directed","nodes":[{"id":1,"data":"A"}],"edges":[]}|
      iex> {:ok, graph} = Yog.IO.JSON.from_json(json)
      iex> Yog.Model.order(graph)
      1

      iex> # NetworkX format
      iex> nx_json = ~s|{"directed":true,"multigraph":false,"nodes":[{"id":1}],"links":[]}|
      iex> {:ok, graph} = Yog.IO.JSON.from_json(nx_json)
      iex> Yog.Model.type(graph)
      :directed

      iex> # D3 format (nodes + links)
      iex> d3_json = ~s|{"nodes":[{"id":1},{"id":2}],"links":[{"source":1,"target":2,"weight":5}]}|
      iex> {:ok, graph} = Yog.IO.JSON.from_json(d3_json)
      iex> Yog.Model.edge_count(graph)
      1

      iex> # Cytoscape format
      iex> cy_json = ~s|{"elements":[{"data":{"id":1}},{"data":{"id":2}},{"data":{"source":1,"target":2}}]}|
      iex> {:ok, graph} = Yog.IO.JSON.from_json(cy_json)
      iex> Yog.Model.order(graph)
      2
  """
  @spec from_json(String.t()) :: {:ok, Yog.graph()} | {:error, String.t()}
  def from_json(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, map} -> from_map(map)
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses a JSON string and creates a graph, raising on error.

  ## Examples

      iex> json = ~s|{"graph_type":"undirected","nodes":[],"edges":[]}|
      iex> graph = Yog.IO.JSON.from_json!(json)
      iex> Yog.Model.order(graph)
      0
  """
  @spec from_json!(String.t()) :: Yog.graph()
  def from_json!(json_string) when is_binary(json_string) do
    case from_json(json_string) do
      {:ok, graph} -> graph
      {:error, reason} -> raise ArgumentError, "Failed to parse JSON: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a graph from a map (useful for PostgreSQL JSONB).

  Auto-detects format based on keys present in the map.

  ## Parameters

  - `map` - Map containing graph data

  ## Supported Formats

  - **Yog Generic**: `%{"graph_type" => "directed", "nodes" => [...], "edges" => [...]}`
  - **NetworkX**: `%{"directed" => true, "nodes" => [...], "links" => [...]}`
  - **D3**: `%{"nodes" => [...], "links" => [...]}`
  - **Cytoscape**: `%{"elements" => [...]}`
  - **VisJs**: `%{"nodes" => [...], "edges" => [...]}` (with `from`/`to`)

  ## Examples

      iex> map = %{
      ...>   "graph_type" => "undirected",
      ...>   "nodes" => [%{"id" => 1, "data" => "Node A"}],
      ...>   "edges" => []
      ...> }
      iex> {:ok, graph} = Yog.IO.JSON.from_map(map)
      iex> Yog.Model.order(graph)
      1

      iex> # From PostgreSQL JSONB (simple format)
      iex> simple = %{
      ...>   "type" => "directed",
      ...>   "nodes" => [%{"id" => 1}, %{"id" => 2}],
      ...>   "edges" => [%{"from" => 1, "to" => 2}]
      ...> }
      iex> {:ok, graph} = Yog.IO.JSON.from_map(simple)
      iex> Yog.has_edge?(graph, 1, 2)
      true
  """
  @spec from_map(map()) :: {:ok, Yog.graph()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    graph = do_from_map(map)
    {:ok, graph}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp do_from_map(map) do
    case detect_format(map) do
      :cytoscape -> parse_cytoscape_format(map)
      :visjs -> parse_visjs_format(map)
      :network_x -> parse_networkx_format(map)
      :yog_generic -> parse_generic_format(map)
      :d3_force -> parse_d3_format(map)
      :simple -> parse_simple_format(map)
    end
  end

  defp detect_format(map) do
    cond do
      # Cytoscape format: elements array
      Map.has_key?(map, "elements") ->
        :cytoscape

      # VisJs format: nodes and edges with from/to
      Map.has_key?(map, "nodes") and Map.has_key?(map, "edges") and
          has_visjs_edges?(map["edges"]) ->
        :visjs

      # NetworkX format: directed + multigraph + links
      Map.has_key?(map, "directed") ->
        :network_x

      # Yog generic format: graph_type + edges
      Map.has_key?(map, "graph_type") or Map.has_key?(map, "edges") ->
        :yog_generic

      # D3 format: nodes + links (no type indicator)
      Map.has_key?(map, "nodes") and Map.has_key?(map, "links") ->
        :d3_force

      # Fallback: try to interpret as simple graph
      true ->
        :simple
    end
  end

  defp has_visjs_edges?(edges) when is_list(edges) do
    case List.first(edges) do
      nil -> false
      edge -> Map.has_key?(edge, "from") and Map.has_key?(edge, "to")
    end
  end

  defp has_visjs_edges?(_), do: false

  defp parse_generic_format(map) do
    graph_type = parse_graph_type(map["graph_type"] || map["type"] || "undirected")
    nodes = map["nodes"] || []
    edges = map["edges"] || []

    base = Yog.new(graph_type)

    graph =
      Enum.reduce(nodes, base, fn node, g ->
        id = parse_id(node["id"])
        data = node["data"] || node["label"] || nil
        Yog.add_node(g, id, data)
      end)

    Enum.reduce(edges, graph, fn edge, g ->
      from = parse_id(edge["source"] || edge["from"])
      to = parse_id(edge["target"] || edge["to"])
      weight = edge["weight"] || edge["label"] || 1
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  defp parse_networkx_format(map) do
    graph_type = if map["directed"], do: :directed, else: :undirected
    nodes = map["nodes"] || []
    links = map["links"] || map["edges"] || []

    base = Yog.new(graph_type)

    graph =
      Enum.reduce(nodes, base, fn node, g ->
        id = parse_id(node["id"])
        data = node["data"] || nil
        Yog.add_node(g, id, data)
      end)

    Enum.reduce(links, graph, fn link, g ->
      from = parse_id(link["source"])
      to = parse_id(link["target"])
      weight = link["weight"] || 1
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  defp parse_d3_format(map) do
    # D3 format doesn't specify directed/undirected, assume undirected
    nodes = map["nodes"] || []
    links = map["links"] || []

    base = Yog.new(:undirected)

    graph =
      Enum.reduce(nodes, base, fn node, g ->
        id = parse_id(node["id"])
        data = node["data"] || node["label"] || nil
        Yog.add_node(g, id, data)
      end)

    Enum.reduce(links, graph, fn link, g ->
      from = parse_id(link["source"])
      to = parse_id(link["target"])
      weight = link["weight"] || link["value"] || 1
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  defp parse_cytoscape_format(map) do
    elements = map["elements"] || []

    # Separate nodes and edges
    {nodes, edges} =
      Enum.split_with(elements, fn elem ->
        data = elem["data"] || %{}
        Map.has_key?(data, "id") and not Map.has_key?(data, "source")
      end)

    # Try to detect if directed
    graph_type = :undirected

    base = Yog.new(graph_type)

    graph =
      Enum.reduce(nodes, base, fn elem, g ->
        data = elem["data"] || %{}
        id = parse_id(data["id"])
        label = data["label"] || data["name"] || nil
        Yog.add_node(g, id, label)
      end)

    Enum.reduce(edges, graph, fn elem, g ->
      data = elem["data"] || %{}
      from = parse_id(data["source"])
      to = parse_id(data["target"])
      weight = data["weight"] || data["label"] || 1
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  defp parse_visjs_format(map) do
    nodes = map["nodes"] || []
    edges = map["edges"] || []

    # VisJs can be directed or undirected, assume undirected by default
    graph_type = :undirected

    base = Yog.new(graph_type)

    graph =
      Enum.reduce(nodes, base, fn node, g ->
        id = parse_id(node["id"])
        label = node["label"] || node["name"] || nil
        Yog.add_node(g, id, label)
      end)

    Enum.reduce(edges, graph, fn edge, g ->
      from = parse_id(edge["from"])
      to = parse_id(edge["to"])
      weight = edge["label"] || edge["weight"] || 1
      Yog.add_edge!(g, from, to, weight)
    end)
  end

  defp parse_simple_format(map) do
    # Most basic format - just try to extract nodes and edges
    nodes = map["nodes"] || []
    edges = map["edges"] || map["links"] || []

    base = Yog.new(:undirected)

    graph =
      Enum.reduce(nodes, base, fn node, g ->
        id =
          if is_map(node) do
            parse_id(node["id"] || node["node_id"])
          else
            parse_id(node)
          end

        data = if is_map(node), do: node["data"], else: nil
        Yog.add_node(g, id, data)
      end)

    Enum.reduce(edges, graph, fn edge, g ->
      {from, to, weight} =
        cond do
          is_map(edge) ->
            f = parse_id(edge["from"] || edge["source"] || edge["node1"])
            t = parse_id(edge["to"] || edge["target"] || edge["node2"])
            w = edge["weight"] || edge["value"] || 1
            {f, t, w}

          is_tuple(edge) and tuple_size(edge) == 2 ->
            {parse_id(elem(edge, 0)), parse_id(elem(edge, 1)), 1}

          is_tuple(edge) and tuple_size(edge) == 3 ->
            {parse_id(elem(edge, 0)), parse_id(elem(edge, 1)), elem(edge, 2)}

          is_list(edge) and length(edge) >= 2 ->
            {parse_id(Enum.at(edge, 0)), parse_id(Enum.at(edge, 1)), Enum.at(edge, 2, 1)}

          true ->
            {nil, nil, 1}
        end

      if from != nil and to != nil do
        Yog.add_edge!(g, from, to, weight)
      else
        g
      end
    end)
  end

  defp parse_graph_type("directed"), do: :directed
  defp parse_graph_type("undirected"), do: :undirected
  defp parse_graph_type("digraph"), do: :directed
  defp parse_graph_type("graph"), do: :undirected
  defp parse_graph_type(true), do: :directed
  defp parse_graph_type(false), do: :undirected
  defp parse_graph_type(_), do: :undirected

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> id
    end
  end

  defp parse_id(id), do: id
end
