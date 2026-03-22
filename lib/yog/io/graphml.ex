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

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "friend")
      iex>
      iex> xml = Yog.IO.GraphML.serialize(graph)
      iex> String.contains?(xml, "Alice")
      true
      iex> String.contains?(xml, "Bob")
      true
  """

  @doc """
  Default GraphML serialization options.
  """
  defdelegate default_options, to: :yog_io@graphml

  @doc """
  Serializes a graph to a GraphML string with custom attribute mappers.
  """
  defdelegate serialize_with(node_attr, edge_attr, graph), to: :yog_io@graphml

  @doc """
  Serializes a graph to GraphML with typed attributes for Gephi compatibility.
  """
  defdelegate serialize_with_types(node_attr, edge_attr, graph), to: :yog_io@graphml

  @doc """
  Serializes a graph to GraphML with typed attributes and custom options.
  """
  defdelegate serialize_with_types_and_options(node_attr, edge_attr, options, graph),
    to: :yog_io@graphml

  @doc """
  Serializes a graph to a GraphML string with custom options.
  """
  defdelegate serialize_with_options(node_attr, edge_attr, options, graph), to: :yog_io@graphml

  @doc """
  Serializes a graph to a GraphML string.
  """
  defdelegate serialize(graph), to: :yog_io@graphml

  @doc """
  Writes a graph to a GraphML file.
  """
  defdelegate write(path, graph), to: :yog_io@graphml

  @doc """
  Writes a graph to a GraphML file with custom attribute mappers.
  """
  defdelegate write_with(path, node_attr, edge_attr, graph), to: :yog_io@graphml

  @doc """
  Writes a graph to a GraphML file with typed attributes for Gephi compatibility.
  """
  defdelegate write_with_types(path, node_attr, edge_attr, graph), to: :yog_io@graphml

  @doc """
  Deserializes a GraphML string into a graph with custom data mappers.

  Returns `{:ok, graph}` on success or `{:error, reason}`.
  """
  defdelegate deserialize_with(node_folder, edge_folder, xml), to: :yog_io@graphml

  @doc """
  Deserializes a GraphML string to a graph.

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
  """
  defdelegate deserialize(xml), to: :yog_io@graphml

  @doc """
  Reads a graph from a GraphML file.
  """
  defdelegate read(path), to: :yog_io@graphml

  @doc """
  Reads a graph from a GraphML file with custom data mappers.
  """
  defdelegate read_with(path, node_folder, edge_folder), to: :yog_io@graphml
end
