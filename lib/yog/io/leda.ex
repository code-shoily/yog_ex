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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")
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

  # credo:disable-for-this-file Credo.Check.Refactor.AppendSingleItem

  alias Yog.Model

  @doc """
  Returns default LEDA options for String node and edge data.

  Default behavior:
  - Serialization: Convert data to string using `to_string/1`
  - Deserialization: Keep data as-is (identity function)

  ## Example

      iex> {:leda_options, _, _, _, _, _, _} = Yog.IO.LEDA.default_options()
      iex> :ok
      :ok
  """
  @spec default_options() :: tuple()
  def default_options do
    {:leda_options, fn data -> Yog.Utils.to_label("", data) end, &Yog.Utils.to_weight_label/1,
     fn s -> s end, fn s -> s end, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}
  end

  @doc """
  Creates LEDA options with custom serializers and deserializers.

  Raises `ArgumentError` if any serializer or deserializer is not an arity-1 function or `opts` is invalid.

  Time complexity: $\\mathcal{O}(1)$

  ## Parameters

  - `node_serializer` - Function to convert node data to string for output
    `(node_data) -> string`
  - `edge_serializer` - Function to convert edge data to string for output
    `(edge_data) -> string`
  - `node_deserializer` - Function to convert string to node data on input
    `(string) -> node_data`
  - `edge_deserializer` - Function to convert string to edge data on input
    `(string) -> edge_data`

  ## Returns

  LEDA options tuple for use with `serialize_with/2` and `parse_with/2`

  ## Example

      options = Yog.IO.LEDA.options_with(
        fn %{name: n} -> n end,                    # Serialize node
        fn weight -> Integer.to_string(weight) end, # Serialize edge
        fn str -> %{name: str} end,                 # Deserialize node
        fn str -> String.to_integer(str) end        # Deserialize edge
      )
  """
  @spec options_with(
          (any() -> any()),
          (any() -> any()),
          (any() -> any()),
          (any() -> any()),
          keyword()
        ) :: tuple()
  def options_with(node_ser, edge_ser, node_deser, edge_deser, opts \\ []) do
    if not is_function(node_ser, 1) do
      raise ArgumentError, "expected node_serializer to be an arity-1 function"
    end

    if not is_function(edge_ser, 1) do
      raise ArgumentError, "expected edge_serializer to be an arity-1 function"
    end

    if not is_function(node_deser, 1) do
      raise ArgumentError, "expected node_deserializer to be an arity-1 function"
    end

    if not is_function(edge_deser, 1) do
      raise ArgumentError, "expected edge_deserializer to be an arity-1 function"
    end

    if not Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    node_fmt = Keyword.get(opts, :node_formatter, &Yog.Utils.safe_string/1)
    edge_fmt = Keyword.get(opts, :edge_formatter, &Yog.Utils.safe_string/1)

    if not is_function(node_fmt, 1) do
      raise ArgumentError, "expected node_formatter to be an arity-1 function"
    end

    if not is_function(edge_fmt, 1) do
      raise ArgumentError, "expected edge_formatter to be an arity-1 function"
    end

    {:leda_options, node_ser, edge_ser, node_deser, edge_deser, node_fmt, edge_fmt}
  end

  @doc """
  Serializes a graph to LEDA format with custom options.

  Allows full control over how node and edge data are converted to LEDA format.

  Raises `ArgumentError` if `graph` or `options` are invalid.

  Time complexity: $\\mathcal{O}(V + E)$ where $V$ is node count and $E$ is edge count.

  ## Parameters

  - `options` - LEDA options tuple (see `options_with/5`)
  - `graph` - The graph to serialize

  ## Returns

  LEDA format string

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, %{name: "Alice"})
      |> Yog.add_node(2, %{name: "Bob"})

      options = Yog.IO.LEDA.options_with(
        fn data -> data.name end,
        fn _ -> "1" end,
        fn _ -> nil end,
        fn _ -> nil end
      )

      leda = Yog.IO.LEDA.serialize_with(options, graph)
  """
  @spec serialize_with(tuple(), Yog.graph() | Yog.DAG.t()) :: String.t()
  def serialize_with(options, graph) do
    target_graph =
      case graph do
        %Yog.Graph{} ->
          graph

        %Yog.DAG{graph: inner} ->
          inner

        _ ->
          raise ArgumentError, "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(graph)}"
      end

    {node_ser, edge_ser, _node_deser, _edge_deser, node_fmt, _edge_fmt} =
      case options do
        {:leda_options, ns, es, nd, ed, nf, ef}
        when is_function(ns, 1) and is_function(es, 1) and is_function(nd, 1) and
               is_function(ed, 1) and is_function(nf, 1) and is_function(ef, 1) ->
          {ns, es, nd, ed, nf, ef}

        {:leda_options, ns, es, nd, ed}
        when is_function(ns, 1) and is_function(es, 1) and is_function(nd, 1) and
               is_function(ed, 1) ->
          {ns, es, nd, ed, &Yog.Utils.safe_string/1, &Yog.Utils.safe_string/1}

        _ ->
          raise ArgumentError, "expected valid leda_options tuple, got: #{inspect(options)}"
      end

    %Yog.Graph{kind: type, nodes: nodes_map} = target_graph

    direction = if type == :directed, do: "-1", else: "-2"

    node_count = map_size(nodes_map)

    node_lines =
      nodes_map
      |> Enum.sort()
      |> Enum.map(fn {_id, data} ->
        serialized = node_ser.(data)
        "|{#{serialized}}|"
      end)

    edges = Model.all_edges(target_graph)
    edge_count = length(edges)

    edge_lines =
      edges
      |> Enum.map(fn {from, to, weight} ->
        serialized = edge_ser.(weight)
        "#{node_fmt.(from)} #{node_fmt.(to)} 0 |{#{serialized}}|"
      end)

    (["LEDA.GRAPH", "string", "string", direction, "#{node_count}"] ++
       node_lines ++ ["#{edge_count}"] ++ edge_lines ++ [""])
    |> Enum.join("\n")
  end

  @doc """
  Serializes a graph to LEDA format using default string conversion.

  Node and edge data are converted to strings.

  Raises `ArgumentError` if `graph` is invalid.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")
      iex> leda = Yog.IO.LEDA.serialize(graph)
      iex> String.contains?(leda, "LEDA.GRAPH") and String.contains?(leda, "Alice")
      true
  """
  @spec serialize(Yog.graph() | Yog.DAG.t()) :: String.t()
  def serialize(graph) do
    serialize_with(default_options(), graph)
  end

  @doc """
  Alias for `serialize/1`.

  Provided for compatibility with other serialization libraries.

  Time complexity: $\\mathcal{O}(V + E)$
  """
  @spec to_string(Yog.graph() | Yog.DAG.t()) :: String.t()
  def to_string(graph) do
    serialize(graph)
  end

  @doc """
  Writes a graph to a LEDA file using default string conversion.

  Raises `ArgumentError` if `path` is not a binary string or `graph` is invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O

  ## Parameters

  - `path` - File path to write to
  - `graph` - The graph to serialize

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on file write failure

  ## Example

      graph = Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")

      Yog.IO.LEDA.write("network.leda", graph)
      # => :ok
  """
  @spec write(String.t(), Yog.graph() | Yog.DAG.t()) :: :ok | {:error, atom()}
  def write(path, graph) when is_binary(path) do
    content = serialize(graph)
    File.write(path, content)
  end

  def write(path, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Writes a graph to a LEDA file with custom serialization options.

  Raises `ArgumentError` if `path` is not a binary string or options/graph are invalid.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O

  ## Parameters

  - `path` - File path to write to
  - `options` - LEDA options tuple (see `options_with/5`)
  - `graph` - The graph to serialize

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on file write failure

  ## Example

      graph = Yog.directed() |> Yog.add_node(1, %{name: "Alice"})
      options = Yog.IO.LEDA.options_with(
        fn d -> d.name end, fn _ -> "1" end,
        fn _ -> nil end, fn _ -> nil end
      )

      Yog.IO.LEDA.write_with("network.leda", options, graph)
  """
  @spec write_with(String.t(), tuple(), Yog.graph() | Yog.DAG.t()) :: :ok | {:error, atom()}
  def write_with(path, options, graph) when is_binary(path) do
    content = serialize_with(options, graph)
    File.write(path, content)
  end

  def write_with(path, _options, _graph) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Parses a LEDA string into a graph with custom parser options.

  This function allows you to transform LEDA data into custom Elixir data
  structures as the graph is built.

  Raises `ArgumentError` if `input` is not a binary string or parsers are invalid.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Parameters

  - `input` - LEDA format string
  - `node_parser` - Function to transform node string to node data
    `(string) -> node_data`
  - `edge_parser` - Function to transform edge string to edge data
    `(string) -> edge_data`

  ## Returns

  - `{:ok, {:leda_result, graph, warnings}}` on success
  - `{:error, reason}` on parsing failure

  The warnings list contains any issues encountered during parsing.

  ## Example

      leda_str = "LEDA.GRAPH\\nstring\\nstring\\n-1\\n2\\n|{Alice}|\\n|{Bob}|\\n1\\n1 2 0 |{5}|"

      node_parser = fn str -> String.upcase(str) end
      edge_parser = fn str -> String.to_integer(str) end

      {:ok, {:leda_result, graph, _warnings}} =
        Yog.IO.LEDA.parse_with(leda_str, node_parser, edge_parser)
  """
  @spec parse_with(String.t(), (any() -> any()), (any() -> any())) ::
          {:ok, {:leda_result, Yog.graph(), list()}} | {:error, term()}
  def parse_with(input, node_parser, edge_parser) when is_binary(input) do
    if not is_function(node_parser, 1) do
      raise ArgumentError, "expected node_parser to be an arity-1 function"
    end

    if not is_function(edge_parser, 1) do
      raise ArgumentError, "expected edge_parser to be an arity-1 function"
    end

    case parse_leda(input, node_parser, edge_parser) do
      {:ok, graph, warnings} -> {:ok, {:leda_result, graph, warnings}}
      {:error, _} = error -> error
    end
  end

  def parse_with(input, _node_parser, _edge_parser) do
    raise ArgumentError, "expected input to be a binary string, got: #{inspect(input)}"
  end

  @doc """
  Parses a LEDA string into a graph with String labels.

  Node and edge data are stored as strings. For custom data structures,
  use `parse_with/3`.

  Raises `ArgumentError` if `input` is not a binary string.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Parameters

  - `input` - LEDA format string

  ## Returns

  - `{:ok, {:leda_result, graph, warnings}}` on success
  - `{:error, reason}` on parsing failure

  ## Example

      iex> leda_string = "LEDA.GRAPH\\nstring\\nstring\\n-1\\n2\\n|{Alice}|\\n|{Bob}|\\n1\\n1 2 0 |{follows}|"
      iex> {:ok, {:leda_result, graph, _warnings}} = Yog.IO.LEDA.parse(leda_string)
      iex> Yog.Model.node_count(graph)
      2
  """
  @spec parse(String.t()) :: {:ok, {:leda_result, Yog.graph(), list()}} | {:error, term()}
  def parse(input) do
    parse_with(input, fn s -> s end, fn s -> s end)
  end

  @doc """
  Reads a graph from a LEDA file using String labels.

  Raises `ArgumentError` if `path` is not a binary string.

  Time complexity: $\\mathcal{O}(V + E)$ + file I/O

  ## Parameters

  - `path` - File path to read from

  ## Returns

  - `{:ok, {:leda_result, graph, warnings}}` on success
  - `{:error, reason}` on file read or parse failure

  ## Example

      {:ok, {:leda_result, graph, warnings}} =
        Yog.IO.LEDA.read("network.leda")

      IO.puts("Loaded graph with \#{Yog.Model.node_count(graph)} nodes")
  """
  @spec read(String.t()) :: {:ok, {:leda_result, Yog.graph(), list()}} | {:error, term()}
  def read(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse(content)
      {:error, _} = error -> error
    end
  end

  def read(path) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Reads a graph from a LEDA file with custom parsers.

  Raises `ArgumentError` if `path` is not a binary string.
  """
  @spec read_with(String.t(), (any() -> any()), (any() -> any())) ::
          {:ok, {:leda_result, Yog.graph(), list()}} | {:error, term()}
  def read_with(path, node_parser, edge_parser) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse_with(content, node_parser, edge_parser)
      {:error, _} = error -> error
    end
  end

  def read_with(path, _node_parser, _edge_parser) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  # Private functions

  defp parse_leda(input, node_parser, edge_parser) do
    if String.trim(input) == "" do
      {:error, :empty_input}
    else
      lines = String.split(input, "\n", trim: false)
      parse_lines(lines, node_parser, edge_parser)
    end
  end

  defp parse_lines(lines, node_parser, edge_parser) do
    with {:ok, lines} <- verify_header(lines),
         {:ok, lines} <- skip_node_type(lines),
         {:ok, lines} <- skip_edge_type(lines),
         {:ok, graph_type, lines} <- parse_direction(lines),
         {:ok, graph, lines, node_warnings} <- parse_nodes_section(lines, graph_type, node_parser),
         {:ok, final_graph, edge_warnings} <- parse_edges_section(lines, graph, edge_parser) do
      {:ok, final_graph, node_warnings ++ edge_warnings}
    else
      {:error, _} = error -> error
    end
  end

  defp verify_header([line | rest]) do
    if String.trim(line) == "LEDA.GRAPH" do
      {:ok, rest}
    else
      {:error, :invalid_header}
    end
  end

  defp verify_header([]) do
    {:error, :empty_input}
  end

  defp skip_node_type([_line | rest]), do: {:ok, rest}
  defp skip_node_type([]), do: {:error, :missing_node_type}

  defp skip_edge_type([_line | rest]), do: {:ok, rest}
  defp skip_edge_type([]), do: {:error, :missing_edge_type}

  defp parse_direction([line | rest]) do
    case String.trim(line) do
      "-1" -> {:ok, :directed, rest}
      "-2" -> {:ok, :undirected, rest}
      other -> {:error, {:invalid_direction, 4, other}}
    end
  end

  defp parse_direction([]) do
    {:error, :missing_direction}
  end

  defp parse_nodes_section([count_line | rest], graph_type, node_parser) do
    case parse_int(String.trim(count_line)) do
      {:ok, node_count} ->
        graph = Yog.Model.new(graph_type)
        parse_nodes_loop(rest, graph, node_parser, node_count, 1, [])

      :error ->
        {:error, :invalid_node_count}
    end
  end

  defp parse_nodes_section([], _graph_type, _node_parser) do
    {:error, :missing_node_count}
  end

  defp parse_nodes_loop(lines, graph, _node_parser, node_count, current_id, warnings)
       when current_id > node_count do
    {:ok, graph, lines, Enum.reverse(warnings)}
  end

  defp parse_nodes_loop([line | rest], graph, node_parser, node_count, current_id, warnings) do
    {:ok, data} = parse_node_data(line, node_parser)
    graph = Yog.Model.add_node(graph, current_id, data)
    parse_nodes_loop(rest, graph, node_parser, node_count, current_id + 1, warnings)
  end

  defp parse_nodes_loop([], _graph, _node_parser, _node_count, _current_id, warnings) do
    {:error, {:unexpected_end_of_nodes, Enum.reverse(warnings)}}
  end

  defp parse_node_data(line, node_parser) do
    case Regex.run(~r/\|{(.*)}\|/, line) do
      [_, data] ->
        {:ok, node_parser.(data)}

      nil ->
        {:ok, node_parser.(String.trim(line))}
    end
  end

  defp parse_edges_section([count_line | rest], graph, edge_parser) do
    case parse_int(String.trim(count_line)) do
      {:ok, edge_count} ->
        parse_edges_loop(rest, graph, edge_parser, edge_count, [])

      :error ->
        {:error, :invalid_edge_count}
    end
  end

  defp parse_edges_section([], _graph, _edge_parser) do
    {:error, :missing_edge_count}
  end

  defp parse_edges_loop(_lines, graph, _edge_parser, 0, warnings) do
    {:ok, graph, Enum.reverse(warnings)}
  end

  defp parse_edges_loop([line | rest], graph, edge_parser, remaining, warnings) do
    trimmed = String.trim(line)

    if trimmed == "" do
      parse_edges_loop(rest, graph, edge_parser, remaining, warnings)
    else
      case parse_edge_line(trimmed, graph, edge_parser) do
        {:ok, new_graph} ->
          parse_edges_loop(rest, new_graph, edge_parser, remaining - 1, warnings)

        {:warning, warning} ->
          parse_edges_loop(rest, graph, edge_parser, remaining - 1, [warning | warnings])
      end
    end
  end

  defp parse_edges_loop([], graph, _edge_parser, _remaining, warnings) do
    {:ok, graph, Enum.reverse(warnings)}
  end

  defp parse_edge_line(line, graph, edge_parser) do
    case Regex.run(~r/^(\d+)\s+(\d+)\s+(\d+)\s+\|{(.*)}\|/, line) do
      [_, from_str, to_str, _rev_idx, edge_data] ->
        add_parsed_edge(graph, from_str, to_str, edge_data, edge_parser, line)

      nil ->
        {:warning, {:malformed_edge, line}}
    end
  end

  defp add_parsed_edge(graph, from_str, to_str, edge_data, edge_parser, _line) do
    from = String.to_integer(from_str)
    to = String.to_integer(to_str)
    weight = edge_parser.(edge_data)
    try_add_edge(graph, from, to, weight)
  end

  defp try_add_edge(graph, from, to, weight) do
    if Yog.Model.has_node?(graph, from) and Yog.Model.has_node?(graph, to) do
      {:ok, new_graph} = Yog.Model.add_edge(graph, from, to, weight)
      {:ok, new_graph}
    else
      {:warning, {:nonexistent_nodes, from, to}}
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end
end
