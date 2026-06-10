# Shared helper functions for NetworkX vs YogEx benchmarks

defmodule Benchmarks.NetworkX.Server do
  use GenServer

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def call(pid, cmd, args) do
    GenServer.call(pid, {:call, cmd, args}, 30000)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server Callbacks
  @impl true
  def init(_) do
    python_path = System.find_executable("python3") || "python3"
    script_path = Path.expand("benchmarks/networkx/python_bench_server.py")

    port =
      Port.open({:spawn_executable, python_path}, [
        :binary,
        :stream,
        {:args, [script_path]},
        :use_stdio,
        :hide
      ])

    state = %{port: port, caller: nil, buffer: ""}
    {:ok, state}
  end

  @impl true
  def handle_call({:call, cmd, args}, from, state) do
    payload = Map.put(args, :cmd, cmd)
    line = Jason.encode!(payload) <> "\n"
    Port.command(state.port, line)

    # Keep track of who called us, and wait for port data
    {:noreply, %{state | caller: from, buffer: ""}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    new_buffer = state.buffer <> data

    if String.contains?(new_buffer, "\n") do
      [line | rest] = String.split(new_buffer, "\n", parts: 2)
      decoded = Jason.decode!(line)
      GenServer.reply(state.caller, decoded)

      # Keep rest of buffer if any, but reset caller
      {:noreply, %{state | caller: nil, buffer: Enum.join(rest, "\n")}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end
end

defmodule Benchmarks.NetworkX.Shared do
  @moduledoc """
  Shared helper functions for benchmarking YogEx against NetworkX.
  """

  @doc """
  Starts the Python benchmark server.
  """
  def start_port do
    {:ok, pid} = Benchmarks.NetworkX.Server.start_link(nil)

    # Ping test
    case call(pid, "ping", %{}) do
      %{"status" => "ok"} ->
        pid

      other ->
        stop_port(pid)
        raise "Failed to initialize Python benchmark server: #{inspect(other)}"
    end
  end

  @doc """
  Stops the Python benchmark server.
  """
  def stop_port(pid) do
    Benchmarks.NetworkX.Server.stop(pid)
  end

  @doc """
  Calls a command on the Python benchmark server.
  """
  def call(pid, cmd, args) do
    Benchmarks.NetworkX.Server.call(pid, cmd, args)
  end

  @doc """
  Registers the YogEx graph in the Python benchmark server under `graph_id`.
  """
  def register_graph(pid, graph_id, %Yog.Graph{} = graph) do
    nodes = Map.keys(graph.nodes)

    edges =
      Yog.Model.all_edges(graph)
      |> Enum.map(fn {u, v, w} ->
        %{
          "from" => encode_node_id(u),
          "to" => encode_node_id(v),
          "weight" => encode_weight(w)
        }
      end)

    case call(pid, "build_graph", %{
           "graph_id" => graph_id,
           "directed" => graph.kind == :directed,
           "nodes" => Enum.map(nodes, &encode_node_id/1),
           "edges" => edges
         }) do
      %{"status" => "ok"} ->
        :ok

      other ->
        raise "Failed to register graph in Python benchmark server: #{inspect(other)}"
    end
  end

  defp encode_node_id(id) when is_atom(id), do: Atom.to_string(id)
  defp encode_node_id(id), do: id

  defp encode_weight(:infinity), do: 1_000_000_000.0
  defp encode_weight(w), do: w

  @doc """
  Returns a function that runs the NetworkX benchmark via the Port.
  """
  def benchmark_nx(pid, graph_id, algorithm, options) do
    fn ->
      case call(pid, "run", %{
             "graph_id" => graph_id,
             "algorithm" => algorithm,
             "options" => options
           }) do
        %{"status" => "ok", "result" => _res} ->
          :ok

        other ->
          raise "NetworkX algorithm run failed: #{inspect(other)}"
      end
    end
  end
end
