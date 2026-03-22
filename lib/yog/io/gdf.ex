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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "5")
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

  @doc """
  Default GDF serialization options.

  Returns a Gleam `GdfOptions` record used by the `_with` serialization functions.
  It includes:
  - `separator`: `","`
  - `include_types`: `true`
  - `include_directed`: `{:none}` (auto-detects from graph type)
  """
  defdelegate default_options, to: :yog_io@gdf

  @doc """
  Serializes a graph to GDF format with custom attribute mappers and options.

  This function allows you to control how node and edge data are converted
  to GDF attributes, and customize the output format.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, %{name: "Alice", age: 30})
      ...> |> Yog.add_node(2, %{name: "Bob", age: 25})
      ...> |> Yog.add_edge!(from: 1, to: 2, with: %{weight: 10, relation: "friend"})
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
  defdelegate serialize_with(node_attr, edge_attr, options, graph), to: :yog_io@gdf

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "friend")
      iex>
      iex> gdf = Yog.IO.GDF.serialize(graph)
      iex> String.contains?(gdf, "1,Alice")
      true
      iex> String.contains?(gdf, "1,2,true,friend")
      true
  """
  defdelegate serialize(graph), to: :yog_io@gdf

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 5)
      iex>
      iex> gdf = Yog.IO.GDF.serialize_weighted(graph)
      iex> String.contains?(gdf, "1,2,true,5")
      true
  """
  defdelegate serialize_weighted(graph), to: :yog_io@gdf

  @doc """
  Writes a graph to a GDF file.

  Returns `{:ok, nil}` on success, or `{:error, reason}` on failure.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Start")
      ...> |> Yog.add_node(2, "End")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "connection")
      iex>
      iex> path = "/tmp/test1.gdf"
      iex> Yog.IO.GDF.write(path, graph)
      {:ok, nil}
  """
  defdelegate write(path, graph), to: :yog_io@gdf

  @doc """
  Writes a graph to a GDF file with custom attribute mappers.
  """
  defdelegate write_with(path, node_attr, edge_attr, options, graph), to: :yog_io@gdf

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
  defdelegate deserialize_with(node_folder, edge_folder, gdf), to: :yog_io@gdf

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
  defdelegate deserialize(gdf), to: :yog_io@gdf

  @doc """
  Reads a graph from a GDF file.

  Returns `{:ok, graph}` on success, where the attributes on nodes and edges are generic.
  """
  defdelegate read(path), to: :yog_io@gdf

  @doc """
  Reads a graph from a GDF file with custom data mappers.
  """
  defdelegate read_with(path, node_folder, edge_folder), to: :yog_io@gdf
end
