defmodule Yog.IO.Sparse6 do
  @moduledoc """
  Sparse6 format import/export for undirected simple graphs.

  Sparse6 is a compact ASCII encoding for large, sparse, undirected simple
  graphs. Like graph6, it only supports undirected simple graphs with no loops
  or multiple edges. It stores edges column-by-column using a variable-length
  integer encoding, making it much more space-efficient than graph6 for sparse
  graphs.

  ## Format

  A sparse6 string starts with `:` followed by:
  1. A header encoding the number of vertices `n` (same as graph6)
  2. Edge data encoded as a sequence of variable-length integers

  Edges are listed in order of the column (higher endpoint), and within each
  column in decreasing order of the smaller endpoint. For each column `v`:
  - If the column is empty: nothing is written
  - If the column has exactly the same edges as `v-1`: nothing is written
  - Otherwise: `v` is written first, followed by `v - u` for each edge `(u, v)`

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1) |> Yog.add_edge_ensure(1, 2, 1) |> Yog.add_edge_ensure(2, 3, 1) |> Yog.add_edge_ensure(3, 4, 1) |> Yog.add_edge_ensure(0, 4, 1)
      iex> {:ok, s6} = Yog.IO.Sparse6.serialize(graph)
      iex> String.starts_with?(s6, ":")
      true

      iex> {:ok, graph} = Yog.IO.Sparse6.parse(":DgA?")
      iex> Yog.Model.node_count(graph)
      5

  ## See Also

  - `Yog.IO.Graph6` - Graph6 format for dense graphs
  """

  alias Yog.Model

  @doc """
  Parses a sparse6 string into an undirected graph.

  Returns `{:ok, graph}` on success, or `{:error, reason}` if the string is
  empty, missing the `:` prefix, or malformed.

  Raises `ArgumentError` if `string` is not a binary string.

  Time complexity: $\\mathcal{O}(V + E)$ where $V$ is the number of nodes and $E$ is the number of edges.

  ## Examples

      iex> {:ok, graph} = Yog.IO.Sparse6.parse(":DgA?")
      iex> Yog.Model.node_count(graph)
      5
  """
  @spec parse(String.t()) :: {:ok, Yog.graph()} | {:error, atom()}
  def parse("") do
    {:error, :empty_input}
  end

  def parse(":" <> rest) when is_binary(rest) do
    with {:ok, n, data} <- parse_header(rest),
         {:ok, numbers} <- decode_numbers(data) do
      {:ok, build_graph(numbers, n)}
    end
  end

  def parse(string) when is_binary(string) do
    {:error, :missing_sparse6_prefix}
  end

  def parse(string) do
    raise ArgumentError, "expected string to be a binary string, got: #{inspect(string)}"
  end

  @doc """
  Serializes an undirected simple graph to a sparse6 string.

  The graph must be undirected, simple, and use integer node IDs `0..n-1`.

  Returns `{:ok, string}` on success, or `{:error, reason}` if the graph
  cannot be represented in sparse6 format.

  Raises `ArgumentError` if `graph` is not a `Yog.Graph` or `Yog.DAG` struct.

  Time complexity: $\\mathcal{O}(V + E \\log E)$ where $V$ is the number of nodes and $E$ is the number of edges.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1) |> Yog.add_edge_ensure(1, 2, 1) |> Yog.add_edge_ensure(2, 3, 1)
      iex> {:ok, s6} = Yog.IO.Sparse6.serialize(graph)
      iex> String.starts_with?(s6, ":")
      true
  """
  @spec serialize(Yog.graph()) :: {:ok, String.t()} | {:error, atom()}
  def serialize(graph) when is_struct(graph, Yog.Graph) or is_struct(graph, Yog.DAG) do
    cond do
      Model.type(graph) != :undirected ->
        {:error, :directed_graph_not_supported}

      not simple?(graph) ->
        {:error, :multigraph_not_supported}

      true ->
        nodes = Model.all_nodes(graph) |> Enum.sort()

        if valid_node_range?(nodes) do
          n = length(nodes)
          numbers = encode_edges(graph, n)
          header = encode_header(n)
          payload = encode_numbers(numbers)
          {:ok, ":" <> header <> payload}
        else
          {:error, :invalid_node_ids}
        end
    end
  end

  def serialize(graph) do
    raise ArgumentError, "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(graph)}"
  end

  @doc """
  Reads one or more sparse6 graphs from a file.

  Each non-empty line in the file is treated as a separate sparse6 string.
  Returns `{:ok, [graph]}` on success.

  Raises `ArgumentError` if `path` is not a binary string.
  """
  @spec read(String.t()) :: {:ok, [Yog.graph()]} | {:error, atom()}
  def read(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&String.starts_with?(&1, "#"))

        graphs =
          Enum.reduce_while(lines, {:ok, []}, fn line, {:ok, acc} ->
            case parse(line) do
              {:ok, graph} -> {:cont, {:ok, [graph | acc]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)

        case graphs do
          {:ok, list} -> {:ok, Enum.reverse(list)}
          {:error, reason} -> {:error, reason}
        end

      {:error, _} = error ->
        error
    end
  end

  def read(path) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  @doc """
  Writes one or more graphs to a sparse6 file.

  Accepts either a single graph or a list of graphs. Each graph is written
  on its own line.

  Raises `ArgumentError` if `path` is not a binary string or if `graphs` is not a valid graph struct or list of graph structs.
  """
  @spec write(String.t(), Yog.graph() | [Yog.graph()]) :: :ok | {:error, atom()}
  def write(path, graphs) when is_binary(path) and is_list(graphs) do
    lines =
      Enum.reduce_while(graphs, {:ok, []}, fn graph, {:ok, acc} ->
        case serialize(graph) do
          {:ok, s6} -> {:cont, {:ok, [s6 | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case lines do
      {:ok, list} -> File.write(path, Enum.join(Enum.reverse(list), "\n") <> "\n")
      {:error, _} = error -> error
    end
  end

  def write(path, graph) when is_binary(path) do
    write(path, [graph])
  end

  def write(path, _graphs) when not is_binary(path) do
    raise ArgumentError, "expected path to be a binary string, got: #{inspect(path)}"
  end

  # =============================================================================
  # Private helpers - parsing
  # =============================================================================

  defp parse_header(<<c, rest::binary>>) when c in 63..126 do
    value = c - 63

    cond do
      value <= 62 ->
        {:ok, value, rest}

      c == 126 ->
        parse_extended_header(rest)

      true ->
        {:error, :invalid_header}
    end
  end

  defp parse_header(_), do: {:error, :invalid_header}

  defp parse_extended_header(<<126, a, b, c, d, e, f, rest::binary>>)
       when a in 63..126 and b in 63..126 and c in 63..126 and d in 63..126 and e in 63..126 and
              f in 63..126 do
    n =
      (a - 63) * 1_073_741_824 +
        (b - 63) * 16_777_216 +
        (c - 63) * 262_144 +
        (d - 63) * 4096 +
        (e - 63) * 64 +
        (f - 63)

    {:ok, n, rest}
  end

  defp parse_extended_header(<<a, b, c, rest::binary>>)
       when a in 63..126 and b in 63..126 and c in 63..126 do
    n = (a - 63) * 4096 + (b - 63) * 64 + (c - 63)
    {:ok, n, rest}
  end

  defp parse_extended_header(_), do: {:error, :invalid_extended_header}

  defp decode_numbers(data) do
    decode_numbers(data, [])
  end

  defp decode_numbers(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_numbers(<<c, rest::binary>>, acc) when c in 63..126 do
    value = c - 63

    if value == 63 do
      decode_extended_number(rest, acc, 0)
    else
      decode_numbers(rest, [value | acc])
    end
  end

  defp decode_numbers(<<_c, _rest::binary>>, _acc), do: {:error, :invalid_character}

  defp decode_extended_number(<<>>, _acc, _x), do: {:error, :truncated_extended_number}

  defp decode_extended_number(<<c, rest::binary>>, acc, x) when c in 63..126 do
    value = c - 63
    x = x * 64 + value

    if value == 63 do
      decode_extended_number(rest, acc, x)
    else
      decode_numbers(rest, [x | acc])
    end
  end

  defp decode_extended_number(<<_c, _rest::binary>>, _acc, _x), do: {:error, :invalid_character}

  defp build_graph(numbers, n) do
    initial_graph =
      Enum.reduce(0..(n - 1)//1, Yog.undirected(), fn i, acc ->
        Model.add_node(acc, i, nil)
      end)

    {final_graph, _remaining, _prev} =
      Enum.reduce(1..(n - 1)//1, {initial_graph, numbers, []}, fn v, {g, nums, prev_edges} ->
        {col_edges, remaining} = take_column(nums, v, prev_edges)

        updated_g =
          Enum.reduce(col_edges, g, fn u, acc ->
            Model.add_edge!(acc, u, v, 1)
          end)

        {updated_g, remaining, col_edges}
      end)

    final_graph
  end

  defp take_column(numbers, v, prev_edges) do
    case numbers do
      [^v | rest] ->
        {edges, remaining} = read_differences(rest, v, [])
        {Enum.reverse(edges), remaining}

      _ ->
        if prev_edges == [] do
          {[], numbers}
        else
          {prev_edges, numbers}
        end
    end
  end

  defp read_differences([], _v, acc), do: {acc, []}

  defp read_differences([x | rest], v, acc) do
    if x > v do
      {acc, [x | rest]}
    else
      u = v - x
      read_differences(rest, v, [u | acc])
    end
  end

  # =============================================================================
  # Private helpers - serialization
  # =============================================================================

  defp valid_node_range?(nodes) do
    nodes == Enum.to_list(0..(length(nodes) - 1)//1)
  end

  defp simple?(graph) do
    not Enum.any?(Model.all_edges(graph), fn {u, v, _} -> u == v end)
  end

  defp encode_edges(graph, n) do
    edges_by_high =
      Enum.reduce(Model.all_edges(graph), %{}, fn {u, v, _}, acc ->
        {low, high} = if u < v, do: {u, v}, else: {v, u}
        Map.update(acc, high, [low], fn existing -> [low | existing] end)
      end)

    columns =
      for v <- 1..(n - 1)//1 do
        rows =
          edges_by_high
          |> Map.get(v, [])
          |> Enum.sort(:desc)

        {v, rows}
      end

    {numbers_rev, _prev} =
      Enum.reduce(columns, {[], []}, fn {v, rows}, {acc, prev} ->
        cond do
          rows == prev ->
            {acc, rows}

          rows == [] ->
            if prev == [] do
              {acc, []}
            else
              {[v | acc], []}
            end

          true ->
            diffs = Enum.map(rows, fn u -> v - u end)
            new_acc = Enum.reverse(diffs, [v | acc])
            {new_acc, rows}
        end
      end)

    Enum.reverse(numbers_rev)
  end

  defp encode_header(n) when n <= 62 do
    <<n + 63>>
  end

  defp encode_header(n) when n <= 258_047 do
    a = div(n, 4096)
    b = div(rem(n, 4096), 64)
    c = rem(n, 64)
    <<126, a + 63, b + 63, c + 63>>
  end

  defp encode_header(n) do
    a = div(n, 1_073_741_824)
    r1 = rem(n, 1_073_741_824)
    b = div(r1, 16_777_216)
    r2 = rem(r1, 16_777_216)
    c = div(r2, 262_144)
    r3 = rem(r2, 262_144)
    d = div(r3, 4096)
    r4 = rem(r3, 4096)
    e = div(r4, 64)
    f = rem(r4, 64)
    <<126, 126, a + 63, b + 63, c + 63, d + 63, e + 63, f + 63>>
  end

  defp encode_numbers(numbers) do
    for x <- numbers, into: <<>> do
      encode_number(x)
    end
  end

  defp encode_number(x) when x <= 30 do
    <<x + 63>>
  end

  defp encode_number(x) when x <= 4126 do
    y = x - 31
    <<126, div(y, 64) + 63, rem(y, 64) + 63>>
  end

  defp encode_number(x) when x <= 266_270 do
    y = x - 4127
    <<126, 126, div(y, 4096) + 63, div(rem(y, 4096), 64) + 63, rem(y, 64) + 63>>
  end

  defp encode_number(x) do
    y = x - 266_271

    <<126, 126, 126, div(y, 262_144) + 63, div(rem(y, 262_144), 4096) + 63,
      div(rem(y, 4096), 64) + 63, rem(y, 64) + 63>>
  end
end
