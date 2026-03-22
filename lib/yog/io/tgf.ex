defmodule Yog.IO.TGF do
  @moduledoc """
  Trivial Graph Format (TGF) serialization support.

  Provides functions to serialize and deserialize graphs in TGF format,
  a very simple text-based format suitable for quick graph exchange and debugging.

  Provides delegation to the Gleam core module `:yog_io@tgf` to maintain API alignment.

  ## Format Overview

  TGF consists of three parts:
  1. **Node section**: Each line is `node_id node_label`
  2. **Separator**: A single `#` character on its own line
  3. **Edge section**: Each line is `source_id target_id [edge_label]`

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "follows")
      iex>
      iex> tgf_string = Yog.IO.TGF.serialize(graph)
      iex> String.contains?(tgf_string, "1 Alice")
      true
      iex> String.contains?(tgf_string, "1 2")
      true

  ## Parsing Behavior

  When parsing TGF files, the following behaviors apply:
  - **Auto-node creation**: If an edge references a node ID that was not declared
    in the node section, a node is automatically created with the ID as its label.
  - **Empty labels**: Nodes without labels default to using their ID as the label.
  - **Malformed lines**: Lines that cannot be parsed are skipped and collected
    as warnings in the `TgfResult`.
  """

  @doc """
  Default TGF serialization options.

  Returns a Gleam `TgfOptions` record.
  """
  defdelegate default_options, to: :yog_io@tgf

  @doc """
  Creates TGF options with custom node and edge label functions.
  """
  defdelegate options_with(node_label, edge_label), to: :yog_io@tgf

  @doc """
  Serializes a graph to TGF format with custom label functions.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, %{name: "Alice"})
      ...> |> Yog.add_node(2, %{name: "Bob"})
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 10)
      iex>
      iex> options = Yog.IO.TGF.options_with(
      ...>   fn data -> data.name end,
      ...>   fn weight -> {:some, Integer.to_string(weight)} end
      ...> )
      iex> tgf_string = Yog.IO.TGF.serialize_with(options, graph)
      iex> String.contains?(tgf_string, "1 Alice")
      true
      iex> String.contains?(tgf_string, "1 2 10")
      true
  """
  defdelegate serialize_with(options, graph), to: :yog_io@tgf

  @doc """
  Serializes a graph to TGF format.
  """
  defdelegate serialize(graph), to: :yog_io@tgf

  @doc """
  Alias for `serialize/1`.
  """
  defdelegate to_string(graph), to: :yog_io@tgf

  @doc """
  Writes a graph to a TGF file.
  """
  defdelegate write(path, graph), to: :yog_io@tgf

  @doc """
  Writes a graph to a TGF file with custom options.
  """
  defdelegate write_with(path, options, graph), to: :yog_io@tgf

  @doc """
  Parses a TGF string into a graph with custom parsers.

  Returns `{:ok, {:tgf_result, graph, warnings}}` on success.
  Requires passing the graph type as `:directed` or `:undirected`.
  """
  defdelegate parse_with(input, graph_type, node_parser, edge_parser), to: :yog_io@tgf

  @doc """
  Parses a TGF string into a graph with String labels.

  ## Example

      iex> tgf_string = \"\"\"
      ...> 1 Alice
      ...> 2 Bob
      ...> #
      ...> 1 2 follows
      ...> \"\"\"
      iex> {:ok, {:tgf_result, graph, []}} = Yog.IO.TGF.parse(tgf_string, :directed)
      iex> Yog.Model.node_count(graph)
      2
  """
  defdelegate parse(input, gtype), to: :yog_io@tgf

  @doc """
  Reads a graph from a TGF file.
  """
  defdelegate read(path, gtype), to: :yog_io@tgf

  @doc """
  Reads a graph from a TGF file with custom parsers.
  """
  defdelegate read_with(path, gtype, node_parser, edge_parser), to: :yog_io@tgf
end
