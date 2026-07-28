defmodule Yog.IO.List do
  @moduledoc """
  Adjacency list import/export for graph serialization.

  Adjacency lists are a compact way to represent sparse graphs where each node
  stores only its neighbors. This format is commonly used in:
  - Algorithm competitions and textbooks
  - Graph database exports
  - Network analysis tools
  - Configuration files

  ## Format

  Each line represents one node and its neighbors:

  ```
  node_id: neighbor1 neighbor2 neighbor3...
  ```

  For weighted graphs, neighbors include weights:

  ```
  node_id: neighbor1,weight1 neighbor2,weight2...
  ```

  ## Examples

  Simple unweighted adjacency list:

  ```
  1: 2 3
  2: 3 4
  3: 4
  4:
  ```

  Weighted adjacency list:

  ```
  1: 2,5 3,10
  2: 3,2
  3: 4,7
  ```

  ## Limitations

  This format is intended for simple graphs where:
  - Node IDs are integers or strings.
  - Edge weights are numbers or maps with a `"weight"` key.

  For graphs with complex node IDs (like tuples) or rich metadata, use `Yog.IO.JSON`
  or `Yog.IO.GEXF` instead.

  ## Use Cases

  - Importing graphs from text files and databases
  - Human-readable graph representation
  - Sparse graph serialization
  - Algorithm competition input format
  - Adjacency matrix conversion

  ## Complexity

  - `from_list/2` and `from_string/3`: $\\mathcal{O}(V + E)$ time and space complexity.
  - `to_list/1` and `to_string/2`: $\\mathcal{O}(V \\log V + E \\log E)$ time due to sorting nodes and neighbors, and $\\mathcal{O}(V + E)$ space complexity.

  ## See Also

  - `Yog.IO.Matrix` - Dense adjacency matrix format
  - `Yog.IO.JSON` - JSON graph format
  """

  alias Yog.Model

  @typedoc "Adjacency list entry: {node_id, [{neighbor_id, weight}]}"
  @type adjacency_entry :: {Yog.node_id(), [{Yog.node_id(), number()}]}

  @doc """
  Creates a graph from an adjacency list.

  ## Parameters

  - `type` - `:directed` or `:undirected`
  - `entries` - List of `{node_id, neighbors}` tuples where neighbors is a list
    of `{neighbor_id, weight}` or `neighbor_id` elements. For unweighted graphs, weight defaults to 1.

  ## Examples

      iex> # Unweighted adjacency list
      ...> entries = [
      ...>   {1, [{2, 1}, {3, 1}]},
      ...>   {2, [{3, 1}]},
      ...>   {3, []}
      ...> ]
      iex> graph = Yog.IO.List.from_list(:undirected, entries)
      iex> Yog.Model.order(graph)
      3
      iex> Yog.Model.edge_count(graph)
      3

      iex> # Weighted adjacency list
      ...> weighted = [
      ...>   {1, [{2, 5}, {3, 10}]},
      ...>   {2, [{3, 2}]},
      ...>   {3, []}
      ...> ]
      iex> digraph = Yog.IO.List.from_list(:directed, weighted)
      iex> Yog.Model.edge_count(digraph)
      3

  ## Errors

  - Raises `ArgumentError` if `type` is not `:directed` or `:undirected`.
  - Raises `ArgumentError` if `entries` is not a list or contains malformed entries.

  ## Notes

  - For undirected graphs, edges are added in both directions automatically.
  - Nodes with empty neighbor lists are still added to the graph.
  - Nodes mentioned only as neighbors are automatically created.
  """
  @spec from_list(:directed | :undirected, [adjacency_entry()]) :: Yog.graph()
  def from_list(type, entries) do
    unless type in [:directed, :undirected] do
      raise ArgumentError,
            "Invalid graph type: #{inspect(type)}. Expected :directed or :undirected"
    end

    if not is_list(entries) do
      raise ArgumentError, "expected entries to be a list, got: #{inspect(entries)}"
    end

    base = Yog.new(type)

    # First pass: add all specified nodes
    graph_with_nodes =
      Enum.reduce(entries, base, fn
        {node_id, _neighbors}, g ->
          Model.add_node(g, node_id, nil)

        other, _g ->
          raise ArgumentError,
                "expected entry to be a tuple {node_id, neighbors_list}, got: #{inspect(other)}"
      end)

    # Second pass: add all edges and missing neighbor nodes
    Enum.reduce(entries, graph_with_nodes, fn {node_id, neighbors}, g ->
      if not is_list(neighbors) do
        raise ArgumentError,
              "expected neighbors for node #{inspect(node_id)} to be a list, got: #{inspect(neighbors)}"
      end

      Enum.reduce(neighbors, g, fn
        {neighbor_id, weight}, acc ->
          acc = ensure_node_exists(acc, neighbor_id)
          Model.add_edge!(acc, node_id, neighbor_id, weight)

        {neighbor_id}, acc ->
          acc = ensure_node_exists(acc, neighbor_id)
          Model.add_edge!(acc, node_id, neighbor_id, 1)

        neighbor_id, acc when not is_tuple(neighbor_id) ->
          acc = ensure_node_exists(acc, neighbor_id)
          Model.add_edge!(acc, node_id, neighbor_id, 1)

        other, _acc ->
          raise ArgumentError,
                "expected neighbor to be a node ID or {node_id, weight} tuple, got: #{inspect(other)}"
      end)
    end)
  end

  @doc """
  Creates a graph from a string representation of an adjacency list.

  Parses a string in the format:

  ```
  node_id: neighbor1 neighbor2...
  ```

  ## Parameters

  - `type` - `:directed` or `:undirected`
  - `string` - Multiline string with adjacency list format
  - `opts` - Options:
    - `:weighted` - `true` to parse weighted edges (format: "neighbor,weight") (default: `false`)
    - `:delimiter` - Delimiter string between node ID and neighbors (default: `":"`)

  ## Examples

      iex> text = \"\"\"
      ...> 1: 2 3
      ...> 2: 3
      ...> 3:
      ...> \"\"\"
      iex> graph = Yog.IO.List.from_string(:undirected, text)
      iex> Yog.Model.order(graph)
      3

      iex> # Weighted format
      iex> weighted_text = \"\"\"
      ...> 1: 2,5 3,10
      ...> 2: 3,2
      ...> \"\"\"
      iex> graph = Yog.IO.List.from_string(:directed, weighted_text, weighted: true)
      iex> Yog.Model.edge_count(graph)
      3

  ## Errors

  - Raises `ArgumentError` if `type` is not `:directed` or `:undirected`.
  - Raises `ArgumentError` if `string` is not a binary.
  - Raises `ArgumentError` if `opts` is not a keyword list or contains unknown options.
  - Raises `ArgumentError` if node IDs or numerical weights are invalid.
  """
  @spec from_string(:directed | :undirected, String.t(), keyword()) :: Yog.graph()
  def from_string(type, string, opts \\ []) do
    unless type in [:directed, :undirected] do
      raise ArgumentError,
            "Invalid graph type: #{inspect(type)}. Expected :directed or :undirected"
    end

    if not is_binary(string) do
      raise ArgumentError, "expected string to be a binary, got: #{inspect(string)}"
    end

    if not Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    allowed_keys = [:weighted, :delimiter]

    Enum.each(Keyword.keys(opts), fn key ->
      if key not in allowed_keys do
        raise ArgumentError, "unknown option: #{inspect(key)}"
      end
    end)

    weighted = Keyword.get(opts, :weighted, false)
    delimiter = Keyword.get(opts, :delimiter, ":")

    if not is_boolean(weighted) do
      raise ArgumentError, "expected :weighted to be a boolean, got: #{inspect(weighted)}"
    end

    if not is_binary(delimiter) or delimiter == "" do
      raise ArgumentError,
            "expected :delimiter to be a non-empty string, got: #{inspect(delimiter)}"
    end

    entries =
      string
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn line -> line == "" or String.starts_with?(line, "#") end)
      |> Enum.map(fn line ->
        parse_line(line, delimiter, weighted)
      end)

    from_list(type, entries)
  end

  @doc """
  Exports a graph to an adjacency list representation.

  Returns a list of `{node_id, neighbors}` tuples where neighbors is a list
  of `{neighbor_id, weight}` tuples.

  ## Parameters

  - `graph` - A `Yog.Graph` or `Yog.DAG` struct.

  ## Examples

      iex> graph = Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)
      iex> entries = Yog.IO.List.to_list(graph)
      iex> entries
      [{1, [{2, 5}]}, {2, [{1, 5}, {3, 7}]}, {3, [{2, 7}]}]

  ## Errors

  - Raises `ArgumentError` if `graph` is not a valid Yog graph struct.

  ## Notes

  - Node order is deterministic (sorted by node ID).
  - For undirected graphs, each edge appears twice (once for each direction).
  - Isolated nodes have empty neighbor lists.
  """
  @spec to_list(Yog.graph() | Yog.DAG.t()) :: [adjacency_entry()]
  def to_list(graph) do
    target_graph = unwrap_graph!(graph)
    nodes = Model.all_nodes(target_graph) |> Enum.sort()

    Enum.map(nodes, fn node_id ->
      neighbors =
        target_graph
        |> Model.successors(node_id)
        |> Enum.sort_by(&elem(&1, 0))

      {node_id, neighbors}
    end)
  end

  @doc """
  Exports a graph to a string representation of an adjacency list.

  ## Parameters

  - `graph` - A `Yog.Graph` or `Yog.DAG` struct.
  - `opts` - Options:
    - `:weighted` - `true` to include weights (format: "neighbor,weight") (default: `false`)
    - `:delimiter` - Delimiter string between node ID and neighbors (default: `":"`)
    - `:node_formatter` - Function converting node ID to string (default: `&Yog.Utils.safe_string/1`)
    - `:weight_formatter` - Function converting weight to string (default: `&Yog.Utils.to_weight_label/1`)

  ## Examples

      iex> graph = Yog.undirected()
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)
      iex> Yog.IO.List.to_string(graph)
      "1: 2\\n2: 1 3\\n3: 2"

      iex> # Using custom formatters for complex types
      iex> graph = Yog.undirected()
      ...>   |> Yog.add_edge_with({1, 2}, {3, 4}, [weight: 10], & &1)
      iex> Yog.IO.List.to_string(graph,
      ...>   node_formatter: fn {a, b} -> "\#{a}_\#{b}" end,
      ...>   weight_formatter: fn [weight: w] -> "w\#{w}" end,
      ...>   weighted: true
      ...> )
      "1_2: 3_4,w10\\n3_4: 1_2,w10"

  ## Errors

  - Raises `ArgumentError` if `graph` is not a valid Yog graph struct.
  - Raises `ArgumentError` if `opts` is not a keyword list or contains unknown options.
  - Raises `ArgumentError` if `:node_formatter` or `:weight_formatter` are not arity-1 functions.
  """
  @spec to_string(Yog.graph() | Yog.DAG.t(), keyword()) :: String.t()
  def to_string(graph, opts \\ []) do
    if not Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    allowed_keys = [:weighted, :delimiter, :node_formatter, :weight_formatter]

    Enum.each(Keyword.keys(opts), fn key ->
      if key not in allowed_keys do
        raise ArgumentError, "unknown option: #{inspect(key)}"
      end
    end)

    weighted = Keyword.get(opts, :weighted, false)
    delimiter = Keyword.get(opts, :delimiter, ":")
    node_fmt = Keyword.get(opts, :node_formatter, &Yog.Utils.safe_string/1)
    weight_fmt = Keyword.get(opts, :weight_formatter, &Yog.Utils.to_weight_label/1)

    if not is_boolean(weighted) do
      raise ArgumentError, "expected :weighted to be a boolean, got: #{inspect(weighted)}"
    end

    if not is_binary(delimiter) do
      raise ArgumentError, "expected :delimiter to be a string, got: #{inspect(delimiter)}"
    end

    if not is_function(node_fmt, 1) do
      raise ArgumentError,
            "expected :node_formatter to be an arity-1 function, got: #{inspect(node_fmt)}"
    end

    if not is_function(weight_fmt, 1) do
      raise ArgumentError,
            "expected :weight_formatter to be an arity-1 function, got: #{inspect(weight_fmt)}"
    end

    entries = to_list(graph)

    lines =
      Enum.map(entries, fn {node_id, neighbors} ->
        neighbor_str =
          if weighted do
            neighbors
            |> Enum.map_join(" ", fn {n, w} -> "#{node_fmt.(n)},#{weight_fmt.(w)}" end)
          else
            neighbors
            |> Enum.map_join(" ", fn {n, _w} -> "#{node_fmt.(n)}" end)
          end

        if neighbor_str == "" do
          "#{node_fmt.(node_id)}#{delimiter}"
        else
          "#{node_fmt.(node_id)}#{delimiter} #{neighbor_str}"
        end
      end)

    Enum.join(lines, "\n")
  end

  defp unwrap_graph!(%Yog.Graph{} = g), do: g
  defp unwrap_graph!(%Yog.DAG{graph: g}), do: g

  defp unwrap_graph!(other) do
    raise ArgumentError,
          "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(other)}"
  end

  defp ensure_node_exists(graph, node_id) do
    if Model.has_node?(graph, node_id) do
      graph
    else
      Model.add_node(graph, node_id, nil)
    end
  end

  # Private helper to parse a single line of adjacency list
  defp parse_line(line, delimiter, weighted) do
    case String.split(line, delimiter, parts: 2) do
      [node_str] ->
        {parse_id(node_str), []}

      [node_str, neighbors_str] ->
        node_id = parse_id(node_str)
        neighbors = parse_neighbors(String.trim(neighbors_str), weighted)
        {node_id, neighbors}
    end
  end

  defp parse_id(str) do
    str = String.trim(str)

    if str == "" do
      raise ArgumentError, "Node ID cannot be empty"
    end

    case Integer.parse(str) do
      {int, ""} -> int
      _ -> str
    end
  end

  defp parse_neighbors("", _weighted), do: []

  defp parse_neighbors(str, weighted) do
    str
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn neighbor_str ->
      if weighted do
        case String.split(neighbor_str, ",", parts: 2) do
          [n, w] -> {parse_id(n), parse_number(w)}
          [n] -> {parse_id(n), 1}
        end
      else
        {parse_id(neighbor_str), 1}
      end
    end)
  end

  defp parse_number(str) do
    str = String.trim(str)

    case Integer.parse(str) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(str) do
          {float, ""} ->
            float

          _ ->
            raise ArgumentError, "invalid numerical weight: #{inspect(str)}"
        end
    end
  end
end
