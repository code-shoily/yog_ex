defmodule Yog.IO.TGF do
  @moduledoc """
  Trivial Graph Format (TGF) serialization support.

  Provides functions to serialize and deserialize graphs in TGF format,
  a simple text-based format suitable for quick graph exchange and debugging.

  ## Format Overview

  TGF consists of three parts:
  1. **Node section**: Each line is `node_id node_label`
  2. **Separator**: A single `#` character on its own line
  3. **Edge section**: Each line is `source_id target_id [edge_label]`

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")
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

  ## Complexity

  - `serialize/1` and `serialize_with/2`: $\\mathcal{O}(V \\log V + E)$ time complexity due to node ID sorting, and $\\mathcal{O}(V + E)$ space complexity.
  - `parse/2` and `parse_with/4`: $\\mathcal{O}(V + E)$ time and space complexity.
  """

  alias Yog.Model

  @doc """
  Returns default TGF serialization options.

  Default behavior:
  - Node labels: Convert data to string using `to_string/1`
  - Edge labels: No labels (returns `:none`)
  - Node formatter: `Yog.Utils.safe_string/1`
  - Edge formatter: `Yog.Utils.safe_string/1`

  ## Example

      iex> {:tgf_options, _node_fn, _edge_fn, _node_fmt, _edge_fmt} = Yog.IO.TGF.default_options()
      iex> :ok
      :ok
  """
  def default_options do
    {:tgf_options, fn data -> Yog.Utils.to_label("", data) end, fn _ -> :none end,
     &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}
  end

  @doc """
  Creates TGF options with custom node and edge label functions.

  ## Parameters

  - `node_label` - Function to convert node data to string label `(node_data) -> string`
  - `edge_label` - Function to convert edge data to optional label `(edge_data) -> :none | {:some, string}`
  - `opts` - Keyword list options:
    - `:node_formatter` - Function converting node ID to string (default: `&Yog.Utils.safe_string/1`)
    - `:edge_formatter` - Function converting edge label to string (default: `&Yog.Utils.safe_string/1`)

  ## Returns

  TGF options tuple for use with `serialize_with/2`

  ## Errors

  - Raises `ArgumentError` if `node_label` or `edge_label` are not arity-1 functions.
  - Raises `ArgumentError` if `opts` is not a keyword list or contains unknown options.

  ## Example

      iex> options = Yog.IO.TGF.options_with(
      ...>   fn data -> "Node: " <> to_string(data) end,
      ...>   fn weight -> {:some, "W:" <> to_string(weight)} end
      ...> )
      iex> {:tgf_options, _, _, _, _} = options
      iex> :ok
      :ok
  """
  def options_with(node_label, edge_label, opts \\ []) do
    if not is_function(node_label, 1) do
      raise ArgumentError,
            "expected node_label to be an arity-1 function, got: #{inspect(node_label)}"
    end

    if not is_function(edge_label, 1) do
      raise ArgumentError,
            "expected edge_label to be an arity-1 function, got: #{inspect(edge_label)}"
    end

    if not Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    allowed_keys = [:node_formatter, :edge_formatter]

    Enum.each(Keyword.keys(opts), fn key ->
      if key not in allowed_keys do
        raise ArgumentError, "unknown option: #{inspect(key)}"
      end
    end)

    node_fmt = Keyword.get(opts, :node_formatter, &Yog.Utils.safe_string/1)
    edge_fmt = Keyword.get(opts, :edge_formatter, &Yog.Utils.safe_string/1)

    if not is_function(node_fmt, 1) do
      raise ArgumentError,
            "expected :node_formatter to be an arity-1 function, got: #{inspect(node_fmt)}"
    end

    if not is_function(edge_fmt, 1) do
      raise ArgumentError,
            "expected :edge_formatter to be an arity-1 function, got: #{inspect(edge_fmt)}"
    end

    {:tgf_options, node_label, edge_label, node_fmt, edge_fmt}
  end

  @doc """
  Serializes a graph to TGF format with custom label functions.

  Allows full control over how node and edge data are converted to TGF labels.

  ## Parameters

  - `options` - TGF options tuple (see `options_with/2`)
  - `graph` - The `Yog.Graph` or `Yog.DAG` to serialize

  ## Returns

  TGF format string

  ## Errors

  - Raises `ArgumentError` if `graph` is not a valid Yog graph struct.
  - Raises `ArgumentError` if `options` is not a valid options tuple.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, %{name: "Alice"})
      ...> |> Yog.add_node(2, %{name: "Bob"})
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      iex> options = Yog.IO.TGF.options_with(
      ...>   fn data -> data.name end,
      ...>   fn weight -> {:some, Integer.to_string(weight)} end
      ...> )
      iex> tgf_string = Yog.IO.TGF.serialize_with(options, graph)
      iex> String.contains?(tgf_string, "1 Alice") and String.contains?(tgf_string, "1 2 10")
      true
  """
  def serialize_with(options, graph) do
    target_graph = unwrap_graph!(graph)

    {node_label_fn, edge_label_fn, node_fmt, edge_fmt} =
      case options do
        {:tgf_options, n_lbl, e_lbl, n_fmt, e_fmt}
        when is_function(n_lbl, 1) and is_function(e_lbl, 1) and is_function(n_fmt, 1) and
               is_function(e_fmt, 1) ->
          {n_lbl, e_lbl, n_fmt, e_fmt}

        {:tgf_options, n_lbl, e_lbl}
        when is_function(n_lbl, 1) and is_function(e_lbl, 1) ->
          {n_lbl, e_lbl, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}

        other ->
          raise ArgumentError,
                "expected valid options tuple from default_options/0 or options_with/2, got: #{inspect(other)}"
      end

    # Serialize nodes
    node_lines =
      target_graph.nodes
      |> Enum.sort()
      |> Enum.map(fn {id, data} ->
        label = node_label_fn.(data)
        "#{node_fmt.(id)} #{node_fmt.(label)}"
      end)

    # Serialize edges
    edges = Model.all_edges(target_graph)

    edge_lines =
      edges
      |> Enum.map(fn {from, to, weight} ->
        case edge_label_fn.(weight) do
          :none -> "#{node_fmt.(from)} #{node_fmt.(to)}"
          {:some, label} -> "#{node_fmt.(from)} #{node_fmt.(to)} #{edge_fmt.(label)}"
        end
      end)

    # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
    (node_lines ++ ["#"] ++ edge_lines ++ [""])
    |> Enum.join("\n")
  end

  @doc """
  Serializes a graph to TGF format using default label conversion.

  Node data is converted to strings, edge labels are omitted.

  ## Errors

  - Raises `ArgumentError` if `graph` is not a valid Yog graph struct.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")
      iex> tgf = Yog.IO.TGF.serialize(graph)
      iex> String.contains?(tgf, "1 Alice") and String.contains?(tgf, "1 2")
      true
  """
  def serialize(graph) do
    serialize_with(default_options(), graph)
  end

  @doc """
  Writes a graph to a TGF file using default label conversion.

  ## Parameters

  - `path` - File path to write to
  - `graph` - The graph to serialize

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on file write failure

  ## Errors

  - Raises `ArgumentError` if `path` is not a binary.
  - Raises `ArgumentError` if `graph` is not a valid Yog graph struct.

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "follows")

      Yog.IO.TGF.write("network.tgf", graph)
      # => :ok
  """
  def write(path, graph) do
    if not is_binary(path) do
      raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
    end

    content = serialize(graph)
    File.write(path, content)
  end

  @doc """
  Writes a graph to a TGF file with custom label functions.

  ## Parameters

  - `path` - File path to write to
  - `options` - TGF options tuple (see `options_with/2`)
  - `graph` - The graph to serialize

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on file write failure

  ## Errors

  - Raises `ArgumentError` if `path` is not a binary.
  - Raises `ArgumentError` if `options` or `graph` are invalid.

  ## Example

      graph = Yog.directed() |> Yog.add_node(1, %{name: "Alice"})
      options = Yog.IO.TGF.options_with(fn d -> d.name end, fn _ -> :none end)

      Yog.IO.TGF.write_with("network.tgf", options, graph)
  """
  def write_with(path, options, graph) do
    if not is_binary(path) do
      raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
    end

    content = serialize_with(options, graph)
    File.write(path, content)
  end

  @doc """
  Parses a TGF string into a graph with custom parsers.

  This function allows you to transform TGF labels into custom Elixir data
  structures as the graph is built.

  ## Parameters

  - `input` - TGF format string
  - `graph_type` - `:directed` or `:undirected`
  - `node_parser` - Function transforming node label to node data `(label) -> node_data` or `(id, label) -> node_data`
  - `edge_parser` - Function transforming edge label to edge data `(string | nil) -> edge_data`

  ## Returns

  - `{:ok, {:tgf_result, graph, warnings}}` on success
  - `{:error, reason}` on parsing failure

  ## Errors

  - Raises `ArgumentError` if `graph_type` is not `:directed` or `:undirected`.
  - Raises `ArgumentError` if `input` is not a binary.
  - Raises `ArgumentError` if `node_parser` or `edge_parser` are invalid functions.

  ## Example

      tgf = "1 Alice\\n2 Bob\\n#\\n1 2 5\\n"

      node_parser = fn label -> String.upcase(label) end
      edge_parser = fn label ->
        case label do
          nil -> 1
          val -> String.to_integer(val)
        end
      end

      {:ok, {:tgf_result, graph, _warnings}} =
        Yog.IO.TGF.parse_with(tgf, :directed, node_parser, edge_parser)
  """
  def parse_with(input, graph_type, node_parser, edge_parser) do
    unless graph_type in [:directed, :undirected] do
      raise ArgumentError,
            "Invalid graph type: #{inspect(graph_type)}. Expected :directed or :undirected"
    end

    if not is_binary(input) do
      raise ArgumentError, "expected input to be a binary string, got: #{inspect(input)}"
    end

    if not (is_function(node_parser, 1) or is_function(node_parser, 2)) do
      raise ArgumentError,
            "expected node_parser to be an arity-1 or arity-2 function, got: #{inspect(node_parser)}"
    end

    if not is_function(edge_parser, 1) do
      raise ArgumentError,
            "expected edge_parser to be an arity-1 function, got: #{inspect(edge_parser)}"
    end

    lines = String.split(input, "\n", trim: false)

    case parse_lines(lines, graph_type, node_parser, edge_parser) do
      {:ok, graph, warnings} -> {:ok, {:tgf_result, graph, warnings}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses a TGF string into a graph with String labels.

  Node and edge labels are stored as strings. For custom data structures,
  use `parse_with/4`.

  ## Parameters

  - `input` - TGF format string
  - `gtype` - `:directed` or `:undirected`

  ## Returns

  - `{:ok, {:tgf_result, graph, warnings}}` on success
  - `{:error, reason}` on parsing failure

  The warnings list contains any malformed lines that were skipped.

  ## Errors

  - Raises `ArgumentError` if `gtype` is not `:directed` or `:undirected`.
  - Raises `ArgumentError` if `input` is not a binary.

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
  Reads a graph from a TGF file using String labels.

  ## Parameters

  - `path` - File path to read from
  - `gtype` - `:directed` or `:undirected`

  ## Returns

  - `{:ok, {:tgf_result, graph, warnings}}` on success
  - `{:error, reason}` on file read or parse failure

  ## Errors

  - Raises `ArgumentError` if `path` is not a binary string.

  ## Example

      {:ok, {:tgf_result, graph, warnings}} =
        Yog.IO.TGF.read("network.tgf", :directed)

      if warnings != [] do
        IO.puts("Warning: Some lines were malformed")
      end
  """
  def read(path, gtype) do
    if not is_binary(path) do
      raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
    end

    case File.read(path) do
      {:ok, content} -> parse(content, gtype)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reads a graph from a TGF file with custom parsers.

  ## Errors

  - Raises `ArgumentError` if `path` is not a binary string.
  """
  def read_with(path, gtype, node_parser, edge_parser) do
    if not is_binary(path) do
      raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
    end

    case File.read(path) do
      {:ok, content} -> parse_with(content, gtype, node_parser, edge_parser)
      {:error, _} = error -> error
    end
  end

  # Private functions

  defp unwrap_graph!(%Yog.Graph{} = g), do: g
  defp unwrap_graph!(%Yog.DAG{graph: g}), do: g

  defp unwrap_graph!(other) do
    raise ArgumentError, "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(other)}"
  end

  defp parse_lines(lines, graph_type, node_parser, edge_parser) do
    # Find separator
    case Enum.find_index(lines, &(&1 == "#" || String.trim(&1) == "#")) do
      nil ->
        {:error, {:missing_separator, "Input must contain '#' separator"}}

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

      {:warning, warning} ->
        parse_nodes_loop(rest, graph, node_parser, [warning | warnings], line_num + 1)
    end
  end

  defp add_node_if_unique(graph, id, data, rest, node_parser, warnings, line_num) do
    %Yog.Graph{nodes: nodes_map} = graph

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
        {:ok, id} = parse_int(id_str)
        data = apply_node_parser(node_parser, id, Kernel.to_string(id))
        {:ok, id, data}

      [id_str, label] ->
        {:ok, id} = parse_int(id_str)
        normalized_label = label |> String.split() |> Enum.join(" ")
        data = apply_node_parser(node_parser, id, normalized_label)
        {:ok, id, data}

      [] ->
        {:warning, {:empty_line, line_num}}
    end
  end

  defp apply_node_parser(node_parser, id, label) do
    if is_function(node_parser, 2) do
      node_parser.(id, label)
    else
      node_parser.(label)
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

  defp parse_int_or_error(str, _line_num) do
    parse_int(str)
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> {:ok, str}
    end
  end

  defp ensure_node(graph, id) do
    %Yog.Graph{nodes: nodes_map} = graph

    if Map.has_key?(nodes_map, id) do
      graph
    else
      Yog.Model.add_node(graph, id, Kernel.to_string(id))
    end
  end
end
