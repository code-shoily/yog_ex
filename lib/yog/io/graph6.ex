defmodule Yog.IO.Graph6 do
  @moduledoc """
  Graph6 format import/export for undirected simple graphs.

  Graph6 is a compact ASCII encoding for undirected simple graphs (no loops,
  no multiple edges). It encodes the upper triangle of the adjacency matrix
  column by column into printable characters.

  This module provides bidirectional conversion between `Yog.Graph` structures
  and graph6 strings, as well as file I/O for datasets commonly found in
  graph theory repositories (e.g., House of Graphs, nauty).

  ## Format

  A graph6 string consists of:
  1. A header encoding the number of vertices `n`
  2. A payload of 6-bit chunks encoding the strict upper triangle of the
     adjacency matrix

  ## Examples

      iex> {:ok, graph} = Yog.IO.Graph6.parse("DqK")
      iex> Yog.Model.node_count(graph)
      5
      iex> Yog.Model.edge_count(graph)
      5

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1) |> Yog.add_edge_ensure(0, 2, 1) |> Yog.add_edge_ensure(1, 3, 1) |> Yog.add_edge_ensure(2, 4, 1) |> Yog.add_edge_ensure(3, 4, 1)
      iex> {:ok, g6} = Yog.IO.Graph6.serialize(graph)
      iex> g6
      "DqK"

  ## See Also

  - `Yog.IO.Sparse6` - Sparse6 format for large sparse graphs
  - `Yog.IO.Matrix` - Adjacency matrix format
  - `Yog.IO.JSON` - JSON graph format
  """

  alias Yog.Model

  @doc """
  Parses a graph6 string into an undirected graph.

  Returns `{:ok, graph}` on success, or `{:error, reason}` if the string is
  malformed or contains invalid data.

  ## Examples

      iex> {:ok, graph} = Yog.IO.Graph6.parse("DqK")
      iex> Yog.Model.node_count(graph)
      5
      iex> Yog.Model.edge_count(graph)
      5
  """
  @spec parse(String.t()) :: {:ok, Yog.graph()} | {:error, atom()}
  def parse(<<>>), do: {:error, :empty_input}

  def parse(string) when is_binary(string) do
    with {:ok, n, rest} <- parse_header(string),
         {:ok, bits} <- parse_payload(rest, n) do
      {:ok, build_graph(bits, n)}
    end
  end

  @doc """
  Serializes an undirected simple graph to a graph6 string.

  The graph must be undirected, simple, and use integer node IDs `0..n-1`.

  Returns `{:ok, string}` on success, or `{:error, reason}` if the graph
  cannot be represented in graph6 format.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1) |> Yog.add_edge_ensure(0, 2, 1) |> Yog.add_edge_ensure(1, 3, 1) |> Yog.add_edge_ensure(2, 4, 1) |> Yog.add_edge_ensure(3, 4, 1)
      iex> {:ok, g6} = Yog.IO.Graph6.serialize(graph)
      iex> g6
      "DqK"
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

          # Safety check: Graph6 is O(V^2) and not suitable for very large graphs
          # 258,048 is the threshold for 6-char header, but bitstring size is ~4.1GB.
          # We'll allow up to 100k nodes (~625MB bitstring) before warning/erroring.
          if n > 100_000 do
            {:error, :graph_too_large_for_graph6}
          else
            if Model.edge_count(graph) == 0 do
              header = encode_header(n)
              expected_bits = div(n * (n - 1), 2)
              expected_chars = div(expected_bits + 5, 6)
              # In Graph6, '?' represents 0 (63-63)
              payload = String.duplicate("?", expected_chars)
              {:ok, header <> payload}
            else
              bits = adjacency_bits(graph, n)
              header = encode_header(n)
              payload = encode_payload(bits)
              {:ok, header <> payload}
            end
          end
        else
          {:error, :invalid_node_ids}
        end
    end
  end

  @doc """
  Reads one or more graph6 graphs from a file.

  Each non-empty line in the file is treated as a separate graph6 string.
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
  Writes one or more graphs to a graph6 file.

  Accepts either a single graph or a list of graphs. Each graph is written
  on its own line.
  """
  @spec write(String.t(), Yog.graph() | [Yog.graph()]) :: :ok | {:error, atom()}
  def write(path, graphs) when is_list(graphs) do
    lines =
      Enum.reduce_while(graphs, {:ok, []}, fn graph, {:ok, acc} ->
        case serialize(graph) do
          {:ok, g6} -> {:cont, {:ok, [g6 | acc]}}
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

  defp parse_extended_header(<<126, a, b, c, d, e, f, rest::binary>>) do
    n =
      (a - 63) * 1_073_741_824 +
        (b - 63) * 16_777_216 +
        (c - 63) * 262_144 +
        (d - 63) * 4096 +
        (e - 63) * 64 +
        (f - 63)

    {:ok, n, rest}
  end

  defp parse_extended_header(<<a, b, c, rest::binary>>) do
    n = (a - 63) * 4096 + (b - 63) * 64 + (c - 63)
    {:ok, n, rest}
  end

  defp parse_extended_header(_), do: {:error, :invalid_extended_header}

  defp parse_payload(rest, n) do
    expected_bits = div(n * (n - 1), 2)
    expected_chars = div(expected_bits + 5, 6)

    if byte_size(rest) == expected_chars do
      # Fast path: if it's all '?' (0), return early without building bitstring
      if all_zeros?(rest) do
        {:ok, :empty}
      else
        bits =
          for <<c <- rest>>, into: <<>> do
            <<c - 63::6>>
          end

        {:ok, bits}
      end
    else
      {:error, :invalid_payload_length}
    end
  end

  defp all_zeros?(<<>>), do: true
  defp all_zeros?(<<"?", rest::binary>>), do: all_zeros?(rest)
  defp all_zeros?(_), do: false

  defp build_graph(:empty, n) do
    Enum.reduce(0..(n - 1)//1, Yog.undirected(), fn i, acc ->
      Model.add_node(acc, i, nil)
    end)
  end

  defp build_graph(bits, n) do
    initial_graph =
      Enum.reduce(0..(n - 1)//1, Yog.undirected(), fn i, acc ->
        Model.add_node(acc, i, nil)
      end)

    {final_graph, _remaining_bits} =
      for j <- 1..(n - 1)//1,
          i <- 0..(j - 1)//1,
          reduce: {initial_graph, bits} do
        {g, <<bit::1, rest::bitstring>>} ->
          new_g = if bit == 1, do: Model.add_edge!(g, i, j, 1), else: g
          {new_g, rest}
      end

    final_graph
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

  defp adjacency_bits(graph, n) do
    # Get all edges once and group by higher endpoint
    edges_by_high =
      Enum.reduce(Model.all_edges(graph), %{}, fn {u, v, _}, acc ->
        {low, high} = if u < v, do: {u, v}, else: {v, u}
        Map.update(acc, high, [low], fn existing -> [low | existing] end)
      end)

    1..(n - 1)//1
    |> Enum.map(fn j ->
      case Map.get(edges_by_high, j) do
        nil ->
          <<0::size(j)>>

        rows ->
          sorted_rows = Enum.sort(rows)

          {bits, last_idx} =
            Enum.reduce(sorted_rows, {<<>>, -1}, fn u, {b_acc, last} ->
              gap_size = u - last - 1
              {<<b_acc::bitstring, 0::size(gap_size), 1::1>>, u}
            end)

          remaining = j - last_idx - 1
          <<bits::bitstring, 0::size(remaining)>>
      end
    end)
    |> :erlang.list_to_bitstring()
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

  defp encode_payload(bits) do
    pad = rem(6 - rem(bit_size(bits), 6), 6)
    padded = <<bits::bitstring, 0::size(pad)>>

    for <<chunk::6 <- padded>>, into: <<>> do
      <<chunk + 63>>
    end
  end
end
