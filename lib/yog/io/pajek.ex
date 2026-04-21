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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")
      iex>
      iex> pajek_string = Yog.IO.Pajek.serialize(graph)
      iex> String.contains?(pajek_string, "*Vertices 2")
      true
      iex> String.contains?(pajek_string, "\\\"Alice\\\"")
      true

  ## Default Configurations
  To handle visual parameters like shapes, pass options via `options_with`.
  """

  alias Yog.Model

  @doc """
  Returns default node attributes with no special visualization.

  Node attributes control visual properties like shape, color, and coordinates
  in Pajek visualizations.

  ## Example

      iex> {:node_attributes, _, _, _, _, _} = Yog.IO.Pajek.default_node_attributes()
      iex> :ok
      :ok
  """
  def default_node_attributes do
    {:node_attributes, :none, :none, :none, :none, :none}
  end

  @doc """
  Returns default Pajek options for String node and edge data.

  Default behavior:
  - Node labels: Convert data to string
  - Edge weights: No weights (returns `:none`)
  - Node attributes: No special visualization
  - Coordinates: Not included
  - Visuals: Not included
  - Node formatter: `Kernel.to_string/1`
  - Edge formatter: `Kernel.to_string/1`

  ## Example

      iex> {:pajek_options, _, _, _, _, _, _, _} = Yog.IO.Pajek.default_options()
      iex> :ok
      :ok
  """
  def default_options do
    {:pajek_options, fn data -> Yog.Utils.to_label("", data) end, fn _ -> :none end,
     fn _ -> default_node_attributes() end, false, false, &Yog.Utils.safe_string/1,
     &Yog.Utils.safe_string/1}
  end

  @doc """
  Creates Pajek options with custom configurations for visualizations and labels.

  **Time Complexity:** O(1)

  ## Parameters

  - `node_label` - Function to convert node data to string label
    `(node_data) -> string`
  - `edge_weight` - Function to convert edge data to optional weight
    `(edge_data) -> :none | {:some, number}`
  - `node_attributes` - Function to generate visual attributes per node
    `(node_data) -> node_attributes`
  - `include_coordinates` - Whether to include x, y, z coordinates
  - `include_visuals` - Whether to include shape, color, etc.

  ## Returns

  Pajek options tuple for use with `serialize_with/2`

  ## Example

      options = Yog.IO.Pajek.options_with(
        fn data -> data.name end,                    # Node label
        fn weight -> {:some, weight} end,            # Edge weight
        fn _ -> Yog.IO.Pajek.default_node_attributes() end,  # No visuals
        false,                                       # No coordinates
        false                                        # No visuals
      )
  """
  def options_with(
        node_label,
        edge_weight,
        node_attributes,
        include_coordinates,
        include_visuals,
        opts \\ []
      ) do
    node_fmt = Keyword.get(opts, :node_formatter, &Yog.Utils.safe_string/1)
    edge_fmt = Keyword.get(opts, :edge_formatter, &Yog.Utils.safe_string/1)

    {:pajek_options, node_label, edge_weight, node_attributes, include_coordinates,
     include_visuals, node_fmt, edge_fmt}
  end

  @doc """
  Serializes a graph to Pajek format with custom options.

  Allows full control over labels, weights, and visualization attributes.

  **Time Complexity:** O(V + E) where V is nodes and E is edges

  ## Parameters

  - `options` - Pajek options tuple (see `options_with/5`)
  - `graph` - The graph to serialize

  ## Returns

  Pajek format string

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, %{name: "Alice"})
      |> Yog.add_node(2, %{name: "Bob"})
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      options = Yog.IO.Pajek.options_with(
        fn data -> data.name end,
        fn weight -> {:some, weight} end,
        fn _ -> Yog.IO.Pajek.default_node_attributes() end,
        false, false
      )

      pajek = Yog.IO.Pajek.serialize_with(options, graph)
  """
  def serialize_with(options, graph) do
    {node_label_fn, edge_weight_fn, _node_attr_fn, _include_coords, _include_visuals, node_fmt,
     edge_fmt} =
      case options do
        {:pajek_options, nl, ew, na, ic, iv, nf, ef} ->
          {nl, ew, na, ic, iv, nf, ef}

        {:pajek_options, nl, ew, na, ic, iv} ->
          {nl, ew, na, ic, iv, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}
      end

    %Yog.Graph{kind: type, nodes: nodes_map} = graph

    # Vertices section
    node_count = map_size(nodes_map)
    vertices_header = "*Vertices #{node_count}\n"

    node_lines =
      nodes_map
      |> Enum.sort()
      |> Enum.map_join("\n", fn {id, data} ->
        label = node_label_fn.(data)
        ~s(#{node_fmt.(id)} "#{node_fmt.(label)}")
      end)

    # Edges section
    edges = Model.all_edges(graph)

    edge_header = if type == :directed, do: "*Arcs\n", else: "*Edges\n"

    edge_lines =
      edges
      |> Enum.map_join("\n", fn {from, to, weight} ->
        case edge_weight_fn.(weight) do
          :none -> "#{node_fmt.(from)} #{node_fmt.(to)}"
          {:some, w} -> "#{node_fmt.(from)} #{node_fmt.(to)} #{edge_fmt.(w)}"
        end
      end)

    [vertices_header, node_lines, edge_header, edge_lines, ""]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  @doc """
  Serializes a graph to Pajek format using default string conversion.

  Node data is converted to strings, edge weights are omitted.

  **Time Complexity:** O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")
      iex> pajek = Yog.IO.Pajek.serialize(graph)
      iex> String.contains?(pajek, "*Vertices 2") and String.contains?(pajek, ~s("Alice"))
      true
  """
  def serialize(graph) do
    serialize_with(default_options(), graph)
  end

  @doc """
  Alias for `serialize/1`.

  Provided for compatibility with other serialization libraries.

  **Time Complexity:** O(V + E)
  """
  def to_string(graph) do
    serialize(graph)
  end

  @doc """
  Writes a graph to a Pajek file using default string conversion.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to write to (typically `.net` extension)
  - `graph` - The graph to serialize

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on file write failure

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

      Yog.IO.Pajek.write("network.net", graph)
      # => :ok
  """
  def write(path, graph) do
    content = serialize(graph)
    File.write(path, content)
  end

  @doc """
  Writes a graph to a Pajek file with custom options.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to write to (typically `.net` extension)
  - `options` - Pajek options tuple (see `options_with/5`)
  - `graph` - The graph to serialize

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on file write failure

  ## Example

      graph = Yog.directed() |> Yog.add_node(1, %{name: "Alice"})
      options = Yog.IO.Pajek.options_with(
        fn d -> d.name end, fn _ -> :none end,
        fn _ -> Yog.IO.Pajek.default_node_attributes() end,
        false, false
      )

      Yog.IO.Pajek.write_with("network.net", options, graph)
  """
  def write_with(path, options, graph) do
    content = serialize_with(options, graph)
    File.write(path, content)
  end

  @doc """
  Parses a Pajek string into a graph with custom parser options.

  This function allows you to transform Pajek data into custom Elixir data
  structures as the graph is built.

  **Time Complexity:** O(V + E)

  ## Parameters

  - `input` - Pajek format string
  - `node_parser` - Function to transform node label to node data
    `(string) -> node_data`
  - `edge_parser` - Function to transform edge weight to edge data
    `(number | nil) -> edge_data`

  ## Returns

  - `{:ok, {:pajek_result, graph, warnings}}` on success
  - `{:error, reason}` on parsing failure

  The warnings list contains any issues encountered during parsing.

  ## Example

      pajek_str = "*Vertices 2\\n1 \\"Alice\\"\\n2 \\"Bob\\"\\n*Arcs\\n1 2 5"

      node_parser = fn label -> String.upcase(label) end
      edge_parser = fn weight -> weight || 1 end

      {:ok, {:pajek_result, graph, _warnings}} =
        Yog.IO.Pajek.parse_with(pajek_str, node_parser, edge_parser)
  """
  def parse_with(input, node_parser, edge_parser) do
    case parse_pajek(input, node_parser, edge_parser) do
      {:ok, graph, warnings} -> {:ok, {:pajek_result, graph, warnings}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses a Pajek string into a graph with String labels.

  Node labels are stored as strings, edge weights as numbers. For custom data
  structures, use `parse_with/3`.

  **Time Complexity:** O(V + E)

  ## Parameters

  - `input` - Pajek format string

  ## Returns

  - `{:ok, {:pajek_result, graph, warnings}}` on success
  - `{:error, reason}` on parsing failure

  ## Example

      iex> input = "*Vertices 2\\n1 \\\"Alice\\\"\\n2 \\\"Bob\\\"\\n*Arcs\\n1 2"
      iex> {:ok, {:pajek_result, graph, _warnings}} = Yog.IO.Pajek.parse(input)
      iex> Yog.Model.node_count(graph)
      2
  """
  def parse(input) do
    parse_with(input, fn s -> s end, fn _ -> "" end)
  end

  @doc """
  Reads a graph from a Pajek file using String labels.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to read from (typically `.net` extension)

  ## Returns

  - `{:ok, {:pajek_result, graph, warnings}}` on success
  - `{:error, reason}` on file read or parse failure

  ## Example

      {:ok, {:pajek_result, graph, warnings}} =
        Yog.IO.Pajek.read("network.net")

      IO.puts("Loaded \#{Yog.Model.node_count(graph)} nodes")
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} -> parse(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a Pajek file with custom parsers.

  **Time Complexity:** O(V + E) + file I/O

  ## Parameters

  - `path` - File path to read from
  - `node_parser` - Function to transform node label to node data
  - `edge_parser` - Function to transform edge weight to edge data

  ## Returns

  - `{:ok, {:pajek_result, graph, warnings}}` on success
  - `{:error, reason}` on file read or parse failure

  ## Example

      node_parser = fn label -> %{name: label} end
      edge_parser = fn weight -> weight || 1 end

      {:ok, {:pajek_result, graph, _warnings}} =
        Yog.IO.Pajek.read_with("network.net", node_parser, edge_parser)
  """
  def read_with(path, node_parser, edge_parser) do
    case File.read(path) do
      {:ok, content} -> parse_with(content, node_parser, edge_parser)
      {:error, _} = error -> error
    end
  end

  # Private functions

  defp parse_pajek(input, node_parser, edge_parser) do
    if String.trim(input) == "" do
      {:error, :empty_input}
    else
      lines = String.split(input, "\n", trim: false)
      # Remove comments and blank lines
      lines = Enum.reject(lines, fn line -> String.starts_with?(String.trim(line), "%") end)
      parse_lines(lines, node_parser, edge_parser)
    end
  end

  defp parse_lines(lines, node_parser, edge_parser) do
    with {:ok, node_count, rest} <- parse_vertices_header(lines),
         {:ok, graph, rest, node_warnings} <- parse_nodes(rest, node_count, node_parser),
         {:ok, graph_type, rest} <- parse_edge_header(rest),
         {:ok, final_graph, edge_warnings} <-
           parse_edges(rest, graph, graph_type, edge_parser) do
      {:ok, final_graph, node_warnings ++ edge_warnings}
    else
      {:error, _} = error -> error
    end
  end

  defp parse_vertices_header([line | rest]) do
    trimmed = String.trim(line)

    # Skip empty lines
    if trimmed == "" do
      parse_vertices_header(rest)
    else
      parse_vertices_count(trimmed, rest)
    end
  end

  defp parse_vertices_header([]) do
    {:error, :empty_input}
  end

  defp parse_vertices_count(trimmed, rest) do
    with [_, count_str] <- Regex.run(~r/^\*vertices\s+(\d+)/i, trimmed),
         {count, _} <- Integer.parse(count_str) do
      {:ok, count, rest}
    else
      :error -> {:error, {:invalid_vertex_count, 1, trimmed}}
      nil -> {:error, {:invalid_vertices_line, 1, trimmed}}
    end
  end

  defp parse_nodes(lines, node_count, node_parser) do
    graph = Yog.Model.new(:directed)
    parse_nodes_loop(lines, graph, node_parser, node_count, 1, [])
  end

  defp parse_nodes_loop(lines, graph, _node_parser, node_count, current_id, warnings)
       when current_id > node_count do
    {:ok, graph, lines, Enum.reverse(warnings)}
  end

  defp parse_nodes_loop([line | rest], graph, node_parser, node_count, current_id, warnings) do
    trimmed = String.trim(line)

    # Skip empty lines
    if trimmed == "" do
      parse_nodes_loop(rest, graph, node_parser, node_count, current_id, warnings)
    else
      case parse_node_line(trimmed, node_parser) do
        {:ok, id, data} ->
          graph = Yog.Model.add_node(graph, id, data)
          parse_nodes_loop(rest, graph, node_parser, node_count, current_id + 1, warnings)

        {:warning, warning} ->
          parse_nodes_loop(rest, graph, node_parser, node_count, current_id + 1, [
            warning | warnings
          ])
      end
    end
  end

  defp parse_nodes_loop([], _graph, _node_parser, _node_count, _current_id, _warnings) do
    {:error, :unexpected_end_of_nodes}
  end

  defp parse_node_line(line, node_parser) do
    # Try to parse: id "label" [x y] [shape] [size] [color]
    # We support both quoted and unquoted labels
    if String.contains?(line, "\"") do
      parse_quoted_node(line, node_parser)
    else
      parse_unquoted_node(line, node_parser)
    end
  end

  defp parse_quoted_node(line, node_parser) do
    case Regex.run(~r/^([^\s]+)\s+"([^"]*)"/, line) do
      [_, id_str, label] ->
        parse_node_id(id_str, label, node_parser, line)

      nil ->
        {:warning, {:invalid_node_line, line}}
    end
  end

  defp parse_unquoted_node(line, node_parser) do
    case String.split(line, ~r/\s+/, parts: 2) do
      [id_str, label | _] ->
        label_word = label |> String.split() |> List.first()
        parse_node_id(id_str, label_word, node_parser, line)

      [id_str] ->
        {:ok, id} = parse_int(id_str)
        {:ok, id, node_parser.(Kernel.to_string(id))}

      _ ->
        {:warning, {:invalid_node_line, line}}
    end
  end

  defp parse_node_id(id_str, label, node_parser, _line) do
    {:ok, id} = parse_int(id_str)
    {:ok, id, node_parser.(label)}
  end

  defp parse_edge_header([line | rest]) do
    trimmed = String.trim(line)

    # Skip empty lines
    if trimmed == "" do
      parse_edge_header(rest)
    else
      # Case-insensitive match for *Arcs or *Edges
      cond do
        String.match?(trimmed, ~r/^\*arcs/i) ->
          {:ok, :directed, rest}

        String.match?(trimmed, ~r/^\*edges/i) ->
          {:ok, :undirected, rest}

        true ->
          # No edge header found, assume no edges
          {:ok, :directed, [line | rest]}
      end
    end
  end

  defp parse_edge_header([]) do
    # No edges section
    {:ok, :directed, []}
  end

  defp parse_edges(lines, graph, graph_type, edge_parser) do
    # Convert graph to the appropriate type
    final_graph =
      if graph_type == :undirected do
        Yog.to_undirected(graph, fn a, _b -> a end)
      else
        graph
      end

    parse_edges_loop(lines, final_graph, edge_parser, [])
  end

  defp parse_edges_loop([], graph, _edge_parser, warnings) do
    {:ok, graph, Enum.reverse(warnings)}
  end

  defp parse_edges_loop([line | rest], graph, edge_parser, warnings) do
    trimmed = String.trim(line)

    # Skip empty lines or lines starting with *
    if trimmed == "" or String.starts_with?(trimmed, "*") do
      parse_edges_loop(rest, graph, edge_parser, warnings)
    else
      case parse_edge_line(trimmed, graph, edge_parser) do
        {:ok, new_graph} ->
          parse_edges_loop(rest, new_graph, edge_parser, warnings)

        {:warning, warning} ->
          parse_edges_loop(rest, graph, edge_parser, [warning | warnings])
      end
    end
  end

  defp parse_edge_line(line, graph, edge_parser) do
    # Parse: source target [weight]
    parts = String.split(line, ~r/\s+/)

    case parts do
      [from_str, to_str] ->
        # No weight
        with {:ok, from} <- parse_int(from_str),
             {:ok, to} <- parse_int(to_str) do
          weight = edge_parser.(:none)
          add_edge_to_graph(graph, from, to, weight)
        else
          :error -> {:warning, {:invalid_edge_format, line}}
        end

      [from_str, to_str | weight_parts] ->
        # With weight
        with {:ok, from} <- parse_int(from_str),
             {:ok, to} <- parse_int(to_str) do
          weight_str = Enum.join(weight_parts, " ")
          weight_value = parse_weight_value(weight_str)
          weight = edge_parser.({:some, weight_value})
          add_edge_to_graph(graph, from, to, weight)
        else
          :error -> {:warning, {:invalid_edge_format, line}}
        end

      _ ->
        {:warning, {:malformed_edge, line}}
    end
  end

  defp parse_weight_value(weight_str) do
    case Float.parse(weight_str) do
      {w, _} -> w
      :error -> weight_str
    end
  end

  defp add_edge_to_graph(graph, from, to, weight) do
    %Yog.Graph{nodes: nodes_map} = graph

    if Map.has_key?(nodes_map, from) and Map.has_key?(nodes_map, to) do
      case Yog.Model.add_edge(graph, from, to, weight) do
        {:ok, new_graph} -> {:ok, new_graph}
        {:error, reason} -> {:warning, {:edge_add_failed, reason}}
      end
    else
      {:warning, {:nonexistent_nodes, from, to}}
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {int, _} -> {:ok, int}
      :error -> {:ok, str}
    end
  end
end
