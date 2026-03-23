defmodule Yog.IO.TGF do
  @moduledoc """
  Trivial Graph Format (TGF) serialization support.

  Provides functions to serialize and deserialize graphs in TGF format,
  a very simple text-based format suitable for quick graph exchange and debugging.

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
  """
  def default_options do
    {:tgf_options, &to_string/1, fn _ -> :none end}
  end

  @doc """
  Creates TGF options with custom node and edge label functions.
  """
  def options_with(node_label, edge_label) do
    {:tgf_options, node_label, edge_label}
  end

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
  def serialize_with(options, graph) do
    {:tgf_options, node_label_fn, edge_label_fn} = options
    {:graph, _type, nodes_map, _, _} = graph

    # Serialize nodes
    node_lines =
      nodes_map
      |> Enum.sort()
      |> Enum.map(fn {id, data} ->
        label = node_label_fn.(data)
        "#{id} #{label}"
      end)

    # Serialize edges
    edges = get_all_edges(graph)

    edge_lines =
      edges
      |> Enum.map(fn {from, to, weight} ->
        case edge_label_fn.(weight) do
          :none -> "#{from} #{to}"
          {:some, label} -> "#{from} #{to} #{label}"
        end
      end)

    # Combine with separator
    (node_lines ++ ["#"] ++ edge_lines ++ [""])
    |> Enum.join("\n")
  end

  @doc """
  Serializes a graph to TGF format.
  """
  def serialize(graph) do
    serialize_with(default_options(), graph)
  end

  @doc """
  Writes a graph to a TGF file.
  """
  def write(path, graph) do
    content = serialize(graph)
    File.write(path, content)
  end

  @doc """
  Writes a graph to a TGF file with custom options.
  """
  def write_with(path, options, graph) do
    content = serialize_with(options, graph)
    File.write(path, content)
  end

  @doc """
  Parses a TGF string into a graph with custom parsers.

  Returns `{:ok, {:tgf_result, graph, warnings}}` on success.
  Requires passing the graph type as `:directed` or `:undirected`.
  """
  def parse_with(input, graph_type, node_parser, edge_parser) do
    lines = String.split(input, "\n", trim: false)

    case parse_lines(lines, graph_type, node_parser, edge_parser) do
      {:ok, graph, warnings} -> {:ok, {:tgf_result, graph, warnings}}
      {:error, _} = error -> error
    end
  end

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
  def parse(input, gtype) do
    parse_with(input, gtype, fn _id, label -> label end, fn label -> label end)
  end

  @doc """
  Reads a graph from a TGF file.
  """
  def read(path, gtype) do
    case File.read(path) do
      {:ok, content} -> parse(content, gtype)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a TGF file with custom parsers.
  """
  def read_with(path, gtype, node_parser, edge_parser) do
    case File.read(path) do
      {:ok, content} -> parse_with(content, gtype, node_parser, edge_parser)
      {:error, _} = error -> error
    end
  end

  # Private functions

  defp get_all_edges({:graph, type, _, out_edges, _}) do
    if type == :directed do
      for {from, dests} <- out_edges,
          {to, weight} <- dests do
        {from, to, weight}
      end
    else
      for {from, dests} <- out_edges,
          {to, weight} <- dests,
          from <= to do
        {from, to, weight}
      end
    end
  end

  defp parse_lines(lines, graph_type, node_parser, edge_parser) do
    # Find separator
    case Enum.find_index(lines, &(&1 == "#" || String.trim(&1) == "#")) do
      nil ->
        # No separator found
        if Enum.all?(lines, &(String.trim(&1) == "")) do
          {:error, {:missing_separator, "Input must contain '#' separator"}}
        else
          {:error, {:missing_separator, "Input must contain '#' separator"}}
        end

      separator_index ->
        node_lines = Enum.take(lines, separator_index)
        edge_lines = Enum.drop(lines, separator_index + 1)

        # Parse nodes and edges
        with {:ok, graph, node_warnings} <- parse_nodes(node_lines, graph_type, node_parser),
             {:ok, final_graph, edge_warnings} <- parse_edges(edge_lines, graph, edge_parser) do
          {:ok, final_graph, node_warnings ++ edge_warnings}
        end
    end
  end

  defp parse_nodes(lines, graph_type, node_parser) do
    graph = Yog.Model.new(graph_type)
    parse_nodes_loop(lines, graph, node_parser, [], 1)
  end

  defp parse_nodes_loop([], graph, _node_parser, warnings, _line_num) do
    {:ok, graph, Enum.reverse(warnings)}
  end

  defp parse_nodes_loop([line | rest], graph, node_parser, warnings, line_num) do
    trimmed = String.trim(line)

    if trimmed == "" do
      # Skip empty lines
      parse_nodes_loop(rest, graph, node_parser, warnings, line_num + 1)
    else
      process_node_line(trimmed, line_num, graph, node_parser, rest, warnings)
    end
  end

  defp process_node_line(trimmed, line_num, graph, node_parser, rest, warnings) do
    case parse_node_line(trimmed, line_num, node_parser) do
      {:ok, id, data} ->
        add_node_if_unique(graph, id, data, rest, node_parser, warnings, line_num)

      {:error, error} ->
        {:error, error}

      {:warning, warning} ->
        parse_nodes_loop(rest, graph, node_parser, [warning | warnings], line_num + 1)
    end
  end

  defp add_node_if_unique(graph, id, data, rest, node_parser, warnings, line_num) do
    {:graph, _, nodes_map, _, _} = graph

    if Map.has_key?(nodes_map, id) do
      {:error, {:duplicate_node, line_num, id}}
    else
      graph = Yog.Model.add_node(graph, id, data)
      parse_nodes_loop(rest, graph, node_parser, warnings, line_num + 1)
    end
  end

  defp parse_node_line(line, line_num, node_parser) do
    # Split on first whitespace
    case String.split(line, ~r/\s+/, parts: 2) do
      [id_str] ->
        # No label, use ID as label
        case parse_int(id_str) do
          {:ok, id} ->
            data = node_parser.(id, Integer.to_string(id))
            {:ok, id, data}

          :error ->
            {:error, {:invalid_node_id, line_num, id_str}}
        end

      [id_str, label] ->
        case parse_int(id_str) do
          {:ok, id} ->
            # Normalize whitespace: trim and collapse multiple spaces to single space
            normalized_label = label |> String.split() |> Enum.join(" ")
            data = node_parser.(id, normalized_label)
            {:ok, id, data}

          :error ->
            {:error, {:invalid_node_id, line_num, id_str}}
        end

      [] ->
        {:warning, {:empty_line, line_num}}
    end
  end

  defp parse_edges(lines, graph, edge_parser) do
    parse_edges_loop(lines, graph, edge_parser, [], Yog.Model.node_count(graph) + 2)
  end

  defp parse_edges_loop([], graph, _edge_parser, warnings, _line_num) do
    {:ok, graph, Enum.reverse(warnings)}
  end

  defp parse_edges_loop([line | rest], graph, edge_parser, warnings, line_num) do
    trimmed = String.trim(line)

    if trimmed == "" do
      # Skip empty lines
      parse_edges_loop(rest, graph, edge_parser, warnings, line_num + 1)
    else
      process_edge_line(trimmed, line_num, graph, edge_parser, rest, warnings)
    end
  end

  defp process_edge_line(trimmed, line_num, graph, edge_parser, rest, warnings) do
    case parse_edge_line(trimmed, line_num, edge_parser) do
      {:ok, from, to, weight} ->
        add_edge_with_nodes(graph, from, to, weight, rest, edge_parser, warnings, line_num)

      {:error, error} ->
        {:error, error}

      {:warning, warning} ->
        parse_edges_loop(rest, graph, edge_parser, [warning | warnings], line_num + 1)
    end
  end

  defp add_edge_with_nodes(graph, from, to, weight, rest, edge_parser, warnings, line_num) do
    graph =
      graph
      |> ensure_node(from)
      |> ensure_node(to)

    case Yog.Model.add_edge(graph, from, to, weight) do
      {:ok, new_graph} ->
        parse_edges_loop(rest, new_graph, edge_parser, warnings, line_num + 1)

      {:error, _reason} ->
        warning = {:invalid_edge, line_num, "Could not add edge #{from} -> #{to}"}
        parse_edges_loop(rest, graph, edge_parser, [warning | warnings], line_num + 1)
    end
  end

  defp parse_edge_line(line, line_num, edge_parser) do
    parts = String.split(line, ~r/\s+/, parts: 3)

    case parts do
      [from_str, to_str] ->
        # No label
        with {:ok, from} <- parse_int_or_error(from_str, line_num),
             {:ok, to} <- parse_int_or_error(to_str, line_num) do
          weight = edge_parser.("")
          {:ok, from, to, weight}
        end

      [from_str, to_str, label] ->
        # With label
        with {:ok, from} <- parse_int_or_error(from_str, line_num),
             {:ok, to} <- parse_int_or_error(to_str, line_num) do
          weight = edge_parser.(String.trim(label))
          {:ok, from, to, weight}
        end

      [_single] ->
        # Malformed edge line (only one token)
        {:warning, {:malformed_edge, line_num, line}}

      [] ->
        {:warning, {:empty_line, line_num}}
    end
  end

  defp parse_int_or_error(str, line_num) do
    case parse_int(str) do
      {:ok, int} -> {:ok, int}
      :error -> {:error, {:invalid_edge_endpoint, line_num, str}}
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp ensure_node(graph, id) do
    {:graph, _, nodes_map, _, _} = graph

    if Map.has_key?(nodes_map, id) do
      graph
    else
      Yog.Model.add_node(graph, id, Integer.to_string(id))
    end
  end
end
