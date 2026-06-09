defmodule Yog.Oracle.NetworkX do
  @moduledoc """
  NetworkX oracle harness via subprocess Python + JSON.

  Dispatches graph algorithm calls to a pinned NetworkX installation
  running in a separate Python process.  The process boundary makes
  debugging trivial and avoids NIF complexity.

  ## Adapter discipline

  Before any oracle test runs the harness must pass 10 round-trip
  self-tests (see `adapter_health/0`).  Failures skip the entire
  oracle suite cleanly with `:adapter_broken`.
  """

  @python_script Path.join([__DIR__, "scripts", "run_algorithm.py"])

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Run a NetworkX algorithm on a Yog graph and return the decoded result.

  Raises `Yog.Oracle.NetworkX.Error` when the Python subprocess fails or
  returns invalid JSON.  Callers in property tests should rescue and
  skip the test when the oracle is unavailable.
  """
  @spec run(String.t(), Yog.graph(), keyword()) :: term()
  def run(algorithm, graph, opts \\ []) do
    payload = %{
      algorithm: algorithm,
      graph: encode_graph(graph),
      options: Map.new(opts)
    }

    input = Jason.encode!(payload)
    tmp = Path.join(System.tmp_dir!(), "yog_nx_oracle_#{System.unique_integer([:positive])}.json")

    try do
      File.write!(tmp, input)

      case System.cmd("python3", [@python_script, tmp],
             stderr_to_stdout: true,
             parallelism: false
           ) do
        {output, 0} ->
          Jason.decode!(output) |> decode_result(algorithm)

        {output, status} ->
          raise __MODULE__.Error,
            message: "Python oracle exited #{status} for #{algorithm}: #{output}"
      end
    after
      File.rm(tmp)
    end
  rescue
    Jason.EncodeError ->
      raise __MODULE__.Error,
        message: "Failed to encode graph payload for #{algorithm}"

    Jason.DecodeError ->
      raise __MODULE__.Error,
        message: "Failed to decode Python output for #{algorithm}"
  end

  @doc """
  Run the 10 round-trip adapter self-tests required by the hardening plan.

  Returns `:ok` on success or `{:error, reason}` on failure, where `reason`
  describes which self-test failed.
  """
  @spec adapter_health() :: :ok | {:error, String.t()}
  def adapter_health do
    tests = [
      {"empty graph", fn -> empty_graph_test() end},
      {"single node no edges", fn -> single_node_test() end},
      {"single directed edge", fn -> single_directed_edge_test() end},
      {"self-loop directed", fn -> self_loop_directed_test() end},
      {"self-loop undirected", fn -> self_loop_undirected_test() end},
      {"disconnected components", fn -> disconnected_components_test() end},
      {"atom node ids", fn -> atom_node_ids_test() end},
      {"string node ids", fn -> string_node_ids_test() end},
      {"integer node ids", fn -> integer_node_ids_test() end},
      {"weighted float negative", fn -> weighted_float_test() end}
    ]

    Enum.reduce_while(tests, :ok, fn {name, test_fn}, _acc ->
      try do
        test_fn.()
        {:cont, :ok}
      rescue
        e ->
          {:halt, {:error, "Adapter self-test '#{name}' failed: #{Exception.message(e)}"}}
      catch
        kind, value ->
          {:halt,
           {:error,
            "Adapter self-test '#{name}' caught #{inspect(kind)}: #{inspect(value, limit: 200)}"}}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Graph encoding
  # ---------------------------------------------------------------------------

  defp encode_graph(%Yog.Graph{kind: kind, nodes: nodes} = graph) do
    %{
      directed: kind == :directed,
      nodes: Map.keys(nodes),
      edges:
        Yog.Model.all_edges(graph)
        |> Enum.map(fn {u, v, w} ->
          %{from: encode_node_id(u), to: encode_node_id(v), weight: encode_weight(w)}
        end)
    }
  end

  # Node IDs are passed through as-is when JSON-compatible.
  # Atoms become strings (Jason default); tests that need round-trip
  # atom identity use string or integer IDs exclusively.
  defp encode_node_id(id) when is_atom(id), do: Atom.to_string(id)
  defp encode_node_id(id), do: id

  defp encode_weight(:infinity), do: "__Inf__"
  defp encode_weight(:neg_infinity), do: "__NegInf__"
  defp encode_weight(:nan), do: "__NaN__"
  defp encode_weight(w), do: w

  # ---------------------------------------------------------------------------
  # Result decoding
  # ---------------------------------------------------------------------------

  # Algorithms that return node-keyed distance maps.
  defp decode_result(result, algo)
       when algo in [
              "single_source_dijkstra_path_length",
              "all_pairs_shortest_path_length",
              "floyd_warshall",
              "johnson"
            ] do
    decode_node_keyed_map(result)
  end

  # bidirectional_dijkstra returns %{"length" => _, "path" => _} or error
  defp decode_result(%{"error" => "no_path"}, "bidirectional_dijkstra") do
    {:error, :no_path}
  end

  defp decode_result(%{"length" => length, "path" => path}, "bidirectional_dijkstra") do
    %{length: length, path: Enum.map(path, &decode_node_id/1)}
  end

  # Generic path lists (astar, bidirectional_shortest_path, shortest_simple_paths)
  defp decode_result(%{"error" => "no_path"}, algo)
       when algo in ["astar_path", "bidirectional_shortest_path"] do
    {:error, :no_path}
  end

  defp decode_result(result, algo)
       when algo in [
              "astar_path",
              "bidirectional_shortest_path"
            ] do
    Enum.map(result, &decode_node_id/1)
  end

  defp decode_result(result, "shortest_simple_paths") do
    Enum.map(result, fn path -> Enum.map(path, &decode_node_id/1) end)
  end

  # bellman_ford returns either a number or an error map
  defp decode_result(%{"error" => err}, "bellman_ford_path_length") do
    {:error, String.to_atom(err)}
  end

  # dijkstra_path_length returns either a number or an error map
  defp decode_result(%{"error" => "no_path"}, "dijkstra_path_length") do
    {:error, :no_path}
  end

  # Default: pass through
  defp decode_result(result, _algo), do: result

  defp decode_node_keyed_map(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      {decode_node_id(k), maybe_decode_nested(v)}
    end
  end

  defp maybe_decode_nested(v) when is_map(v), do: decode_node_keyed_map(v)
  defp maybe_decode_nested("__Inf__"), do: :infinity
  defp maybe_decode_nested(v), do: v

  defp decode_node_id(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> str
    end
  end

  defp decode_node_id(other), do: other

  # ---------------------------------------------------------------------------
  # Self-tests
  # ---------------------------------------------------------------------------

  defp empty_graph_test do
    g = Yog.Model.new(:directed)
    result = run("health_check", g, [])
    unless result["node_count"] == 0, do: raise("expected empty graph")
    :ok
  end

  defp single_node_test do
    g = Yog.Model.new(:directed) |> Yog.Model.add_node(:a, nil)
    result = run("health_check", g, [])
    unless result["node_count"] == 1, do: raise("expected 1 node, got #{inspect(result)}")
    :ok
  end

  defp single_directed_edge_test do
    g =
      Yog.Model.new(:directed)
      |> Yog.Model.add_node(1, nil)
      |> Yog.Model.add_node(2, nil)
      |> Yog.Model.add_edge!(1, 2, 5)

    result = run("health_check", g, [])
    unless result["edge_count"] == 1, do: raise("expected 1 edge, got #{inspect(result)}")
    :ok
  end

  defp self_loop_directed_test do
    g =
      Yog.Model.new(:directed)
      |> Yog.Model.add_node(1, nil)
      |> Yog.Model.add_edge!(1, 1, 3)

    result = run("health_check", g, [])
    unless result["edge_count"] == 1, do: raise("expected 1 edge, got #{inspect(result)}")
    :ok
  end

  defp self_loop_undirected_test do
    g =
      Yog.Model.new(:undirected)
      |> Yog.Model.add_node(1, nil)
      |> Yog.Model.add_edge!(1, 1, 3)

    result = run("health_check", g, [])
    unless result["edge_count"] == 1, do: raise("expected 1 edge, got #{inspect(result)}")
    :ok
  end

  defp disconnected_components_test do
    g =
      Yog.Model.new(:undirected)
      |> Yog.Model.add_node(1, nil)
      |> Yog.Model.add_node(2, nil)
      |> Yog.Model.add_node(3, nil)
      |> Yog.Model.add_edge!(1, 2, 1)

    result = run("health_check", g, [])

    unless result["node_count"] == 3 and result["edge_count"] == 1,
      do: raise("unexpected result: #{inspect(result)}")

    :ok
  end

  defp atom_node_ids_test do
    g =
      Yog.Model.new(:directed)
      |> Yog.Model.add_node(:foo, nil)
      |> Yog.Model.add_node(:bar, nil)
      |> Yog.Model.add_edge!(:foo, :bar, 1)

    # Atoms round-trip as strings in JSON; just verify no crash
    _ = run("health_check", g, [])
    :ok
  end

  defp string_node_ids_test do
    g =
      Yog.Model.new(:directed)
      |> Yog.Model.add_node("alice", nil)
      |> Yog.Model.add_node("bob", nil)
      |> Yog.Model.add_edge!("alice", "bob", 7)

    result = run("dijkstra_path_length", g, source: "alice", target: "bob")
    unless result == 7, do: raise("expected 7, got #{inspect(result)}")
    :ok
  end

  defp integer_node_ids_test do
    g =
      Yog.Model.new(:directed)
      |> Yog.Model.add_node(42, nil)
      |> Yog.Model.add_node(99, nil)
      |> Yog.Model.add_edge!(42, 99, 11)

    result = run("dijkstra_path_length", g, source: 42, target: 99)
    unless result == 11, do: raise("expected 11, got #{inspect(result)}")
    :ok
  end

  defp weighted_float_test do
    g =
      Yog.Model.new(:undirected)
      |> Yog.Model.add_node(1, nil)
      |> Yog.Model.add_node(2, nil)
      |> Yog.Model.add_edge!(1, 2, -3.5)

    result = run("dijkstra_path_length", g, source: 1, target: 2)
    unless result == -3.5, do: raise("expected -3.5, got #{inspect(result)}")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Exception
  # ---------------------------------------------------------------------------

  defmodule Error do
    defexception [:message]
  end
end
