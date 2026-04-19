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
  malformed.
  """
  @spec parse(String.t()) :: {:ok, Yog.graph()} | {:error, atom()}
  def parse(":" <> rest) when is_binary(rest) do
    with {:ok, n, data} <- parse_header(rest),
         {:ok, numbers} <- decode_numbers(data) do
      {:ok, build_graph(numbers, n)}
    end
  end

  def parse(<<>>), do: {:error, :empty_input}
  def parse(_), do: {:error, :missing_sparse6_prefix}

  @doc """
  Serializes an undirected simple graph to a sparse6 string.

  The graph must be undirected, simple, and use integer node IDs `0..n-1`.

  Returns `{:ok, string}` on success, or `{:error, reason}` if the graph
  cannot be represented in sparse6 format.
  """
  @spec serialize(Yog.graph()) :: {:ok, String.t()} | {:error, atom()}
  def serialize(graph) do
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

  @doc """
  Reads one or more sparse6 graphs from a file.

  Each non-empty line in the file is treated as a separate sparse6 string.
  Returns `{:ok, [graph]}` on success.
  """
  @spec read(String.t()) :: {:ok, [Yog.graph()]} | {:error, atom()}
  def read(path) do
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

  @doc """
  Writes one or more graphs to a sparse6 file.

  Accepts either a single graph or a list of graphs. Each graph is written
  on its own line.
  """
  @spec write(String.t(), Yog.graph() | [Yog.graph()]) :: :ok | {:error, atom()}
  def write(path, graphs) when is_list(graphs) do
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

  def write(path, graph) do
    write(path, [graph])
  end

  # =============================================================================
  # Private helpers - parsing
  # =============================================================================

  defp parse_header(<<c, rest::binary>>) do
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

  defp parse_extended_header(<<a, b, c, rest::binary>>) do
    n = (a - 63) * 4096 + (b - 63) * 64 + (c - 63)
    {:ok, n, rest}
  end

  defp parse_extended_header(<<126, a, b, c, d, e, f, rest::binary>>) do
    n =
      (a - 63) * 2_821_109_907_456 +
        (b - 63) * 68_719_476_736 +
        (c - 63) * 1_073_741_824 +
        (d - 63) * 16_777_216 +
        (e - 63) * 262_144 +
        (f - 63) * 4096

    {:ok, n, rest}
  end

  defp parse_extended_header(_), do: {:error, :invalid_extended_header}

  defp decode_numbers(data) do
    decode_numbers(data, [])
  end

  defp decode_numbers(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_numbers(<<c, rest::binary>>, acc) do
    value = c - 63

    if value == 63 do
      decode_extended_number(rest, acc, 0)
    else
      decode_numbers(rest, [value | acc])
    end
  end

  defp decode_extended_number(<<>>, _acc, _x), do: {:error, :truncated_extended_number}

  defp decode_extended_number(<<c, rest::binary>>, acc, x) do
    value = c - 63
    x = x * 64 + value

    if value == 63 do
      decode_extended_number(rest, acc, x)
    else
      decode_numbers(rest, [x | acc])
    end
  end

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
        # Column is explicitly specified, read differences until next column marker
        {edges, remaining} = read_differences(rest, v, [])
        {Enum.reverse(edges), remaining}

      _ ->
        # Column not specified: either empty or same as previous
        if prev_edges == [] do
          {[], numbers}
        else
          # Same as previous column
          {prev_edges, numbers}
        end
    end
  end

  # Read differences for column v until we hit the next column marker
  defp read_differences([], _v, acc), do: {acc, []}

  defp read_differences([x | rest], v, acc) do
    # If x >= v, it's a column marker for a future column (or same column, which shouldn't happen),
    # so we stop. Note: x can never equal v because that would mean u=0 and v=v, giving x=v.
    # Actually x = v - u, and u can be 0, so x CAN equal v. Wait, if u=0, x=v, which is valid.
    # But x > v is impossible for a valid edge, so x > v means it's a column marker.
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
    # Build adjacency by column (higher endpoint), rows in decreasing order
    columns =
      for v <- 1..(n - 1)//1 do
        rows =
          for u <- (v - 1)..0//-1,
              Model.has_edge?(graph, u, v) do
            u
          end

        {v, rows}
      end

    {numbers_rev, _prev} =
      Enum.reduce(columns, {[], []}, fn {v, rows}, {acc, prev} ->
        cond do
          rows == [] ->
            {acc, []}

          rows == prev ->
            {acc, rows}

          true ->
            # diffs: [d1, d2, ...]
            # acc: [... d2, d1, v]
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
    a = div(n, 2_821_109_907_456)
    r1 = rem(n, 2_821_109_907_456)
    b = div(r1, 68_719_476_736)
    r2 = rem(r1, 68_719_476_736)
    c = div(r2, 1_073_741_824)
    r3 = rem(r2, 1_073_741_824)
    d = div(r3, 16_777_216)
    r4 = rem(r3, 16_777_216)
    e = div(r4, 262_144)
    f = div(rem(r4, 262_144), 4096)
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
