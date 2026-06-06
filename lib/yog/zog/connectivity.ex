defmodule Yog.Zog.Connectivity do
  @moduledoc """
  Native graph connectivity algorithms backed by Zog (Zig) via Zigler.
  """
  alias Yog.Builder.Zog

  if Code.ensure_loaded?(Zig) do
    use Zig,
      otp_app: :yog_ex,
      extra_modules: [zog: {"../../../priv/zog/src/root.zig", []}],
      nifs: [
        nif_core_numbers: [concurrency: :dirty_cpu],
        nif_analyze_connectivity: [concurrency: :dirty_cpu]
      ]

    ~Z"""
    const std = @import("std");
    const beam = @import("beam");
    const zog = @import("zog");

    const ArrayGraph = zog.models.ArrayGraph;

    fn buildGraph(node_count: usize, from: []u32, to: []u32, weight: []f64) !ArrayGraph(void, f64) {
        const allocator = beam.allocator;
        var g = ArrayGraph(void, f64).init(allocator);
        errdefer g.deinit();

        try g.nodes.ensureTotalCapacity(allocator, node_count);
        try g.edges.ensureTotalCapacity(allocator, from.len);

        for (0..node_count) |_| {
            _ = try g.addNode({});
        }

        for (from, to, weight) |f, t, w| {
            _ = try g.addEdge(f, t, w);
        }

        return g;
    }

    pub fn nif_core_numbers(node_count: usize, from: []u32, to: []u32, weight: []f64) ![]u32 {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        return try zog.connectivity.coreNumbers(beam.allocator, g);
    }

    pub fn nif_analyze_connectivity(node_count: usize, from: []u32, to: []u32, weight: []f64) !beam.term {
        var g = try buildGraph(node_count, from, to, weight);
        defer g.deinit();

        const res = try zog.connectivity.analyzeConnectivity(beam.allocator, g);
        errdefer {
            beam.allocator.free(res.bridges);
            beam.allocator.free(res.articulation_points);
        }

        const term = beam.make(.{.ok, res.bridges, res.articulation_points}, .{});

        beam.allocator.free(res.bridges);
        beam.allocator.free(res.articulation_points);

        return term;
    }
    """

    @doc """
    Calculates all core numbers for all nodes in the graph natively.
    """
    @spec core_numbers(Zog.t()) :: %{Zog.label() => integer()}
    def core_numbers(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      labels = Zog.all_labels(builder)
      labels_tuple = List.to_tuple(labels)

      case nif_core_numbers(node_count, from, to, weights) do
        [] ->
          %{}

        cores ->
          cores
          |> Enum.with_index()
          |> Map.new(fn {core, idx} -> {elem(labels_tuple, idx), core} end)
      end
    end

    @doc """
    Detects the k-core of a graph natively.
    Returns a `Yog.Builder.Zog` containing the k-core subgraph.
    """
    @spec detect(Zog.t(), integer()) :: Zog.t()
    def detect(%Yog.Builder.Zog{} = builder, k) when k >= 0 do
      if builder.kind == :directed do
        raise ArgumentError, "k-core decomposition requires an undirected graph"
      end

      cores = core_numbers(builder)

      keep_labels =
        cores
        |> Enum.filter(fn {_label, core} -> core >= k end)
        |> Enum.map(fn {label, _core} -> label end)
        |> MapSet.new()

      new_builder =
        Enum.reduce(keep_labels, Zog.undirected(), fn label, acc ->
          Zog.add_node(acc, label)
        end)

      edges = Zog.all_edges(builder)

      Enum.reduce(edges, new_builder, fn {u_id, v_id, w}, acc ->
        if u_id < v_id do
          u = Zog.id_to_label(builder, u_id)
          v = Zog.id_to_label(builder, v_id)

          if MapSet.member?(keep_labels, u) and MapSet.member?(keep_labels, v) do
            Zog.add_edge(acc, u, v, w)
          else
            acc
          end
        else
          acc
        end
      end)
    end

    @type bridge :: {Zog.label(), Zog.label()}

    @doc """
    Analyzes an undirected graph natively to find all bridges and articulation points.
    """
    @spec analyze(Zog.t()) :: %{
            bridges: [bridge()],
            articulation_points: [Zog.label()]
          }
    def analyze(%Yog.Builder.Zog{} = builder) do
      node_count = Zog.node_count(builder)
      {from, to, weights} = Zog.to_edge_arrays(builder)

      labels = Zog.all_labels(builder)
      labels_tuple = List.to_tuple(labels)

      case nif_analyze_connectivity(node_count, from, to, weights) do
        {:ok, bridges, articulation_points} ->
          bridges_tuples =
            bridges
            |> Enum.map(fn [u_idx, v_idx] ->
              u = elem(labels_tuple, u_idx)
              v = elem(labels_tuple, v_idx)
              if u < v, do: {u, v}, else: {v, u}
            end)
            |> Enum.sort()

          ap_labels =
            articulation_points
            |> Enum.map(fn idx -> elem(labels_tuple, idx) end)
            |> Enum.sort()

          %{bridges: bridges_tuples, articulation_points: ap_labels}
      end
    end
  else
    @moduledoc """
    Native graph connectivity algorithms backed by Zog (Zig) via Zigler.

    **Not available** — zigler is not installed. All functions will raise at runtime.
    """

    def core_numbers(_builder) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end

    def detect(_builder, _k) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end

    def analyze(_builder) do
      raise "zigler is not installed. Add {:zigler, \"~> 0.15.2\", runtime: false} to your deps and run mix deps.get."
    end
  end
end
