defmodule Yog.IO.Pajek do
  @moduledoc """
  Pajek (.net) format serialization support.

  Provides functions to serialize and deserialize graphs in the Pajek .net format,
  a standard format for social network analysis used by the Pajek software and
  compatible with many network analysis tools.

  ## Format Overview

  Pajek files have a structured text format with distinct sections:
  - **Vertices**: `*Vertices N` followed by node definitions
  - **Arcs**: `*Arcs` section for directed edges
  - **Edges**: `*Edges` section for undirected edges

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "5")
      iex>
      iex> pajek_string = Yog.IO.Pajek.serialize(graph)
      iex> String.contains?(pajek_string, "*Vertices 2")
      true
      iex> String.contains?(pajek_string, "\\\"Alice\\\"")
      true

  ## Default Configurations
  To handle visual parameters like shapes, pass options via `options_with`.
  """

  @doc """
  Default node attributes (no special visualization).
  """
  defdelegate default_node_attributes, to: :yog_io@pajek

  @doc """
  Default Pajek options for String node and edge data.
  """
  defdelegate default_options, to: :yog_io@pajek

  @doc """
  Creates Pajek options with custom configurations for visualizations and labels.
  """
  defdelegate options_with(
                node_label,
                edge_weight,
                node_attributes,
                include_coordinates,
                include_visuals
              ),
              to: :yog_io@pajek

  @doc """
  Serializes a graph to Pajek format with custom options.
  """
  defdelegate serialize_with(options, graph), to: :yog_io@pajek

  @doc """
  Serializes a graph to Pajek format for `String` data types.
  """
  defdelegate serialize(graph), to: :yog_io@pajek

  @doc """
  Alias for `serialize/1`.
  """
  defdelegate to_string(graph), to: :yog_io@pajek

  @doc """
  Writes a graph to a Pajek file.
  """
  defdelegate write(path, graph), to: :yog_io@pajek

  @doc """
  Writes a graph to a Pajek file with custom options.
  """
  defdelegate write_with(path, options, graph), to: :yog_io@pajek

  @doc """
  Parses a Pajek string into a graph with custom parser options.

  Returns `{:ok, {:pajek_result, graph, warnings}}` or `{:error, reason}`.
  """
  defdelegate parse_with(input, node_parser, edge_parser), to: :yog_io@pajek

  @doc """
  Parses a Pajek string into a graph with String labels.

  ## Example

      iex> input = "*Vertices 2\\n1 \\\"Alice\\\"\\n2 \\\"Bob\\\"\\n*Arcs\\n1 2"
      iex> {:ok, {:pajek_result, graph, _warnings}} = Yog.IO.Pajek.parse(input)
      iex> Yog.Model.node_count(graph)
      2
  """
  defdelegate parse(input), to: :yog_io@pajek

  @doc """
  Reads a graph from a Pajek file.
  """
  defdelegate read(path), to: :yog_io@pajek

  @doc """
  Reads a graph from a Pajek file with custom parsers.
  """
  defdelegate read_with(path, node_parser, edge_parser), to: :yog_io@pajek
end
