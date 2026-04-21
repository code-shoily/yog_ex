defmodule Yog.IO.GDF do
  @moduledoc """
  GDF (GUESS Graph Format) serialization support.

  Provides functions to serialize and deserialize graphs in GDF format,
  a simple text-based format used by Gephi and other graph visualization tools.
  GDF uses a column-based format similar to CSV with separate sections for nodes and edges.

  ## Format Overview

  GDF files consist of two sections:
  - **nodedef>** - Defines node columns and data
  - **edgedef>** - Defines edge columns and data

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")
      iex>
      iex> # Serialize to GDF
      iex> _gdf_string = Yog.IO.GDF.serialize(graph)
      iex>
      iex> # You could then write to a file:
      iex> # Yog.IO.GDF.write("graph.gdf", graph)

  ## Output Format

  ```
  nodedef>name VARCHAR,label VARCHAR
  1,Alice
  2,Bob
  edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
  1,2,true,5
  ```

  ## References

  - [GDF Format Specification](https://gephi.org/users/supported-graph-formats/gdf-format/)
  - [GUESS Visualization Tool](https://graphexploration.cond.org/)
  """

  alias Yog.Model

  @doc """
  Default GDF serialization options.

  Returns a Gleam `GdfOptions` record used by the `_with` serialization functions.
  It includes:
  - `separator`: `","`
  - `include_types`: `true`
  - `include_directed`: `{:none}` (auto-detects from graph type)
  - `node_formatter`: `Kernel.to_string/1`
  - `edge_formatter`: `Kernel.to_string/1`
  """
  def default_options do
    {:gdf_options, ",", true, :none, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}
  end

  @doc """
  Serializes a graph to GDF format with custom attribute mappers and options.

  This function allows you to control how node and edge data are converted
  to GDF attributes, and customize the output format.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, %{name: "Alice", age: 30})
      ...> |> Yog.add_node(2, %{name: "Bob", age: 25})
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: %{weight: 10, relation: "friend"})
      iex>
      iex> node_attr = fn data -> %{"label" => data.name, "age" => Integer.to_string(data.age)} end
      iex> edge_attr = fn data -> %{"weight" => Integer.to_string(data.weight), "type" => data.relation} end
      iex>
      iex> gdf = Yog.IO.GDF.serialize_with(node_attr, edge_attr, Yog.IO.GDF.default_options(), graph)
      iex> String.contains?(gdf, "nodedef>name")
      true
      iex> String.contains?(gdf, "Alice")
      true
      iex> String.contains?(gdf, "30")
      true
  """
  def serialize_with(node_attr, edge_attr, options, graph) do
    {separator, include_types, node_fmt, edge_fmt} =
      case options do
        {:gdf_options, sep, types, _, n_fmt, e_fmt} ->
          {sep, types, n_fmt, e_fmt}

        {:gdf_options, sep, types, _} ->
          {sep, types, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}
      end

    %Yog.Graph{kind: type, nodes: nodes_map} = graph

    # 1. Schema Discovery for Nodes
    all_nodes_data =
      nodes_map
      |> Enum.sort_by(fn {id, _} -> id end)
      |> Enum.map(fn {id, data} ->
        attrs = node_attr.(data)
        # Ensure ID is there as 'name', and remove any user 'name' to avoid collision
        attrs = attrs |> Map.delete("name") |> Map.put("name", id)
        {id, attrs}
      end)

    node_columns =
      all_nodes_data
      |> Enum.reduce(MapSet.new(), fn {_, attrs}, acc ->
        MapSet.union(acc, MapSet.new(Map.keys(attrs)))
      end)
      |> MapSet.delete("name")
      |> Enum.sort()
      |> then(fn cols -> ["name" | cols] end)

    node_header = build_section_header("nodedef>", node_columns, separator, include_types)

    node_lines =
      Enum.map(all_nodes_data, fn {_, attrs} ->
        Enum.map_join(node_columns, separator, fn col ->
          value = Map.get(attrs, col, "")
          escape_csv(value, separator, node_fmt)
        end)
      end)

    # 2. Schema Discovery for Edges
    edges = Model.all_edges(graph)

    all_edges_data =
      Enum.map(edges, fn {from, to, weight} ->
        attrs = edge_attr.(weight)

        attrs =
          attrs
          |> Map.delete("node1")
          |> Map.delete("node2")
          |> Map.delete("directed")
          |> Map.put("node1", from)
          |> Map.put("node2", to)
          |> Map.put("directed", if(type == :directed, do: "true", else: "false"))

        attrs
      end)

    edge_columns =
      all_edges_data
      |> Enum.reduce(MapSet.new(), fn attrs, acc ->
        MapSet.union(acc, MapSet.new(Map.keys(attrs)))
      end)
      |> MapSet.delete("node1")
      |> MapSet.delete("node2")
      |> MapSet.delete("directed")
      |> Enum.sort()
      |> then(fn cols -> ["node1", "node2", "directed" | cols] end)

    edge_header = build_section_header("edgedef>", edge_columns, separator, include_types)

    edge_lines =
      Enum.map(all_edges_data, fn attrs ->
        Enum.map_join(edge_columns, separator, fn col ->
          value = Map.get(attrs, col, "")
          escape_csv(value, separator, edge_fmt)
        end)
      end)

    # Combine all sections
    ([node_header] ++ node_lines ++ [edge_header] ++ edge_lines)
    |> Enum.join("\n")
  end

  defp build_section_header(prefix, columns, separator, include_types) do
    if include_types do
      prefix <>
        Enum.map_join(columns, separator, fn col ->
          type_str = get_column_type(prefix, col)
          "#{col} #{type_str}"
        end)
    else
      prefix <> Enum.join(columns, separator)
    end
  end

  defp get_column_type(_, "directed"), do: "BOOLEAN"
  defp get_column_type(_, _), do: "VARCHAR"

  @doc """
  Serializes a graph to GDF format where node and edge data are strings.

  This is a simplified version of `serialize_with` for graphs where
  node data and edge data are already strings. The string data is used
  as the "label" attribute for both nodes and edges.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "friend")
      iex>
      iex> gdf = Yog.IO.GDF.serialize(graph)
      iex> String.contains?(gdf, "1,Alice")
      true
      iex> String.contains?(gdf, "1,2,true,friend")
      true
  """
  def serialize(graph) do
    node_attr = fn data -> %{"label" => Yog.Utils.to_label("", data)} end
    edge_attr = fn data -> %{"label" => Yog.Utils.to_weight_label(data)} end
    serialize_with(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Serializes a graph to GDF format with integer edge weights.

  This is a convenience function for the common case of graphs with
  integer weights. Node data is used as labels, and edge weights are
  serialized to the "weight" column.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex>
      iex> gdf = Yog.IO.GDF.serialize_weighted(graph)
      iex> String.contains?(gdf, "1,2,true,5")
      true
  """
  def serialize_weighted(graph) do
    node_attr = fn data -> %{"label" => Yog.Utils.to_label("", data)} end
    edge_attr = fn data -> %{"weight" => Yog.Utils.to_weight_label(data)} end
    serialize_with(node_attr, edge_attr, default_options(), graph)
  end

  @doc """
  Writes a graph to a GDF file.

  Returns `{:ok, nil}` on success, or `{:error, reason}` on failure.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Start")
      ...> |> Yog.add_node(2, "End")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "connection")
      iex>
      iex> path = "/tmp/test1.gdf"
      iex> Yog.IO.GDF.write(path, graph)
      {:ok, nil}
  """
  def write(path, graph) do
    content = serialize(graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Writes a graph to a GDF file with custom attribute mappers.
  """
  def write_with(path, node_attr, edge_attr, options, graph) do
    content = serialize_with(node_attr, edge_attr, options, graph)

    case File.write(path, content) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Deserializes a GDF string into a graph with custom data mappers.

  This function allows you to control how GDF columns are converted
  to your node and edge data types. Use `deserialize/1` for simple cases
  where you want node/edge data as string dictionaries.

  **Time Complexity:** O(V + E)

  ## Example

      iex> node_folder = fn attrs ->
      ...>   name = Map.get(attrs, "label", "")
      ...>   age = Map.get(attrs, "age", "0") |> String.to_integer()
      ...>   %{name: name, age: age}
      ...> end
      iex>
      iex> edge_folder = fn attrs -> Map.get(attrs, "weight", "") end
      iex>
      iex> gdf = \"\"\"
      ...> nodedef>name VARCHAR,label VARCHAR,age VARCHAR
      ...> 1,Alice,30
      ...> edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
      ...> 1,2,true,strong
      ...> \"\"\"
      iex> {:ok, graph} = Yog.IO.GDF.deserialize_with(node_folder, edge_folder, gdf)
      iex> Yog.Model.node_count(graph)
      2
  """
  def deserialize_with(node_folder, edge_folder, gdf) do
    parse_gdf(gdf, node_folder, edge_folder)
  end

  @doc """
  Deserializes a GDF string to a graph.

  This is a simplified version of `deserialize_with` for graphs where
  you want node data and edge data as string dictionaries containing all attributes.

  **Time Complexity:** O(V + E)

  ## Example

      iex> gdf_string = \"\"\"
      ...> nodedef>name VARCHAR,label VARCHAR
      ...> 1,Alice
      ...> edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
      ...> 1,2,true,10
      ...> \"\"\"
      iex> {:ok, graph} = Yog.IO.GDF.deserialize(gdf_string)
      iex> node1_data = Yog.Model.node(graph, 1)
      iex> Map.get(node1_data, "label")
      "Alice"
  """
  def deserialize(gdf) do
    parse_gdf(gdf, fn attrs -> attrs end, fn attrs -> attrs end)
  end

  @doc """
  Reads a graph from a GDF file.

  Returns `{:ok, graph}` on success, where the attributes on nodes and edges are generic.
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} -> deserialize(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a GDF file with custom data mappers.
  """
  def read_with(path, node_folder, edge_folder) do
    case File.read(path) do
      {:ok, content} -> deserialize_with(node_folder, edge_folder, content)
      {:error, _} = error -> error
    end
  end

  # Private functions

  defp escape_csv(value, separator, formatter) do
    str_value = if is_binary(value), do: value, else: formatter.(value)

    # Check if we need to quote (contains separator, quotes, or newlines)
    needs_quoting =
      String.contains?(str_value, separator) or
        String.contains?(str_value, "\"") or
        String.contains?(str_value, "\n")

    if needs_quoting do
      # Escape quotes by doubling them
      escaped = String.replace(str_value, "\"", "\"\"")
      "\"#{escaped}\""
    else
      str_value
    end
  end

  defp parse_gdf(input, node_folder, edge_folder) do
    lines = String.split(input, "\n", trim: false)

    with {:ok, node_columns, node_lines, rest} <- parse_node_section(lines),
         {:ok, graph} <- build_nodes(node_columns, node_lines, node_folder),
         {:ok, edge_columns, edge_lines} <- parse_edge_section(rest),
         {:ok, final_graph} <- build_edges(graph, edge_columns, edge_lines, edge_folder) do
      {:ok, final_graph}
    else
      {:error, _} = error -> error
    end
  end

  defp parse_node_section(lines) do
    # Find nodedef> line
    case Enum.find_index(lines, fn line -> String.starts_with?(line, "nodedef>") end) do
      nil ->
        {:error, :missing_nodedef}

      nodedef_index ->
        header_line = Enum.at(lines, nodedef_index)
        # Parse column names from header
        columns_part = String.trim_leading(header_line, "nodedef>")
        columns = parse_column_names(columns_part)

        # Get node data lines (until edgedef> or end)
        data_lines =
          lines
          |> Enum.drop(nodedef_index + 1)
          |> Enum.take_while(fn line -> not String.starts_with?(line, "edgedef>") end)
          |> Enum.reject(&(String.trim(&1) == ""))

        rest =
          lines
          |> Enum.drop(nodedef_index + 1)
          |> Enum.drop_while(fn line -> not String.starts_with?(line, "edgedef>") end)

        {:ok, columns, data_lines, rest}
    end
  end

  defp parse_edge_section([]) do
    # No edge section
    {:ok, [], []}
  end

  defp parse_edge_section([header_line | rest]) do
    if String.starts_with?(header_line, "edgedef>") do
      columns_part = String.trim_leading(header_line, "edgedef>")
      columns = parse_column_names(columns_part)

      data_lines = Enum.reject(rest, &(String.trim(&1) == ""))

      {:ok, columns, data_lines}
    else
      {:ok, [], []}
    end
  end

  defp parse_column_names(columns_str) do
    # Split by comma/separator and remove type annotations
    columns_str
    |> String.split(",")
    |> Enum.map(fn col ->
      col
      |> String.trim()
      |> String.split(~r/\s+/)
      |> List.first()
    end)
  end

  defp build_nodes(columns, data_lines, node_folder) do
    graph = Yog.Model.new(:directed)

    Enum.reduce_while(data_lines, {:ok, graph}, fn line, {:ok, acc_graph} ->
      values = parse_csv_values(line)
      add_node_from_values(values, columns, acc_graph, node_folder)
    end)
  end

  defp add_node_from_values(values, columns, acc_graph, node_folder) do
    if length(values) != length(columns) do
      {:cont, {:ok, acc_graph}}
    else
      [id_str | _rest] = values

      # Yog supports any term as ID. Convert to integer if possible for convenience,
      # but keep as string otherwise.
      id =
        case Integer.parse(id_str) do
          {val, ""} -> val
          _ -> id_str
        end

      attrs = Enum.zip(columns, values) |> Enum.into(%{})
      data = node_folder.(attrs)
      new_graph = Yog.Model.add_node(acc_graph, id, data)
      {:cont, {:ok, new_graph}}
    end
  end

  defp build_edges(graph, columns, data_lines, edge_folder) do
    initial_graph = maybe_convert_to_undirected(graph, columns, data_lines)

    # Process all edges
    Enum.reduce_while(data_lines, {:ok, initial_graph}, fn line, {:ok, acc_graph} ->
      process_edge_line(line, columns, acc_graph, edge_folder)
    end)
  end

  defp maybe_convert_to_undirected(graph, columns, data_lines) do
    needs_undirected = check_if_undirected(data_lines, columns)

    if needs_undirected do
      Yog.to_undirected(graph, fn a, _b -> a end)
    else
      graph
    end
  end

  defp check_if_undirected([], _columns), do: false

  defp check_if_undirected([first_line | _], columns) do
    case parse_csv_line(first_line, columns) do
      {:ok, attrs} ->
        directed_str = Map.get(attrs, "directed", "true")
        String.downcase(String.trim(directed_str)) != "true"

      {:error, _} ->
        false
    end
  end

  defp process_edge_line(line, columns, acc_graph, edge_folder) do
    case parse_csv_line(line, columns) do
      {:ok, attrs} ->
        add_edge_from_attrs(attrs, acc_graph, edge_folder)

      {:error, _} ->
        {:cont, {:ok, acc_graph}}
    end
  end

  defp add_edge_from_attrs(attrs, acc_graph, edge_folder) do
    node1_str = Map.get(attrs, "node1", "")
    node2_str = Map.get(attrs, "node2", "")

    if node1_str != "" and node2_str != "" do
      from =
        case Integer.parse(node1_str) do
          {val, ""} -> val
          _ -> node1_str
        end

      to =
        case Integer.parse(node2_str) do
          {val, ""} -> val
          _ -> node2_str
        end

      # Ensure nodes exist (auto-create if needed)
      acc_graph = ensure_node_exists(acc_graph, from, edge_folder)
      acc_graph = ensure_node_exists(acc_graph, to, edge_folder)

      weight = edge_folder.(attrs)

      case Yog.Model.add_edge(acc_graph, from, to, weight) do
        {:ok, new_graph} -> {:cont, {:ok, new_graph}}
        {:error, _} -> {:cont, {:ok, acc_graph}}
      end
    else
      {:cont, {:ok, acc_graph}}
    end
  end

  defp ensure_node_exists(graph, node_id, _edge_folder) do
    %Yog.Graph{nodes: nodes_map} = graph

    if Map.has_key?(nodes_map, node_id) do
      graph
    else
      # Auto-create node with empty map as data
      Yog.Model.add_node(graph, node_id, %{})
    end
  end

  defp parse_csv_line(line, columns) do
    # Parse CSV with quote handling
    values = parse_csv_values(line)

    if length(values) == length(columns) do
      attrs =
        Enum.zip(columns, values)
        |> Enum.into(%{})

      {:ok, attrs}
    else
      {:error, :column_count_mismatch}
    end
  end

  defp parse_csv_values(line) do
    # Simple CSV parser that handles quotes
    line
    |> String.split(~r/,(?=(?:[^"]*"[^"]*")*[^"]*$)/)
    |> Enum.map(fn value ->
      value = String.trim(value)

      # Remove surrounding quotes and unescape doubled quotes
      if String.starts_with?(value, "\"") and String.ends_with?(value, "\"") do
        value
        |> String.slice(1..-2//1)
        |> String.replace("\"\"", "\"")
      else
        value
      end
    end)
  end
end
