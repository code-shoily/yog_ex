defmodule Yog.IO.LEDA do
  @moduledoc """
  LEDA (Library of Efficient Data types and Algorithms) graph format support.

  Provides functions to serialize and deserialize graphs in the LEDA format,
  a text-based format used by the LEDA library and compatible with NetworkX.

  ## Format Overview

  LEDA files have a structured text format with distinct sections:
  - **Header**: `LEDA.GRAPH`
  - **Type declarations**: Node type and edge type
  - **Direction**: `-1` for directed, `-2` for undirected
  - **Nodes**: Count followed by node data lines
  - **Edges**: Count followed by edge data lines

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "5")
      iex>
      iex> leda_string = Yog.IO.LEDA.serialize(graph)
      iex> String.contains?(leda_string, "LEDA.GRAPH")
      true
      iex> String.contains?(leda_string, "Alice")
      true

  ## Parsing Behavior

  - **1-indexed nodes**: LEDA format uses 1-based indexing
  - **Sequential order**: Nodes must appear in sequential order
  - **Strict node references**: Auto-creation is not supported
  - **Reversal edges**: Third field indicates index for undirected graphs
  """

  @doc """
  Default LEDA options for String node and edge data.
  """
  defdelegate default_options, to: :yog_io@leda

  @doc """
  Creates LEDA options with custom serializers and deserializers.
  """
  defdelegate options_with(
                node_serializer,
                edge_serializer,
                node_deserializer,
                edge_deserializer
              ),
              to: :yog_io@leda

  @doc """
  Serializes a graph to LEDA format with custom options.
  """
  defdelegate serialize_with(options, graph), to: :yog_io@leda

  @doc """
  Serializes a graph to LEDA format for `String` data types.
  """
  defdelegate serialize(graph), to: :yog_io@leda

  @doc """
  Alias for `serialize/1`.
  """
  defdelegate to_string(graph), to: :yog_io@leda

  @doc """
  Writes a graph to a LEDA file.
  """
  defdelegate write(path, graph), to: :yog_io@leda

  @doc """
  Writes a graph to a LEDA file with custom options.
  """
  defdelegate write_with(path, options, graph), to: :yog_io@leda

  @doc """
  Parses a LEDA string into a graph with custom parser options.

  Returns `{:ok, {:leda_result, graph, warnings}}` or `{:error, reason}`.
  """
  defdelegate parse_with(input, node_parser, edge_parser), to: :yog_io@leda

  @doc """
  Parses a LEDA string into a graph with String labels.

  ## Example

      iex> leda_string = "LEDA.GRAPH\\nstring\\nstring\\n-1\\n2\\n|{Alice}|\\n|{Bob}|\\n1\\n1 2 0 |{follows}|"
      iex> {:ok, {:leda_result, graph, _warnings}} = Yog.IO.LEDA.parse(leda_string)
      iex> Yog.Model.node_count(graph)
      2
  """
  defdelegate parse(input), to: :yog_io@leda

  @doc """
  Reads a graph from a LEDA file.
  """
  defdelegate read(path), to: :yog_io@leda

  @doc """
  Reads a graph from a LEDA file with custom parsers.
  """
  defdelegate read_with(path, node_parser, edge_parser), to: :yog_io@leda
end
