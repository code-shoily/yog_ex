defmodule Yog.Builder.Live do
  @moduledoc """
  A live builder for incremental graph construction with label-to-ID registry.

  Unlike the static `Yog.Builder.Labeled` which follows a "Build-Freeze-Analyze" pattern,
  `Live` provides a **Transaction-style API** that tracks pending changes.
  This allows efficient synchronization of an existing `Graph` with new labeled edges
  in O(ΔE) time, where ΔE is the number of new edges since last sync.

  ## Use Cases

  - **REPL environments**: Incrementally build and analyze graphs
  - **UI editors**: Add nodes/edges interactively without rebuilding
  - **Streaming data**: Ingest new relationships as they arrive
  - **Large graphs**: Avoid O(E) rebuild for single-edge updates

  ## Guarantees

  - **ID Stability:** Once a label is mapped to a `NodeId`, that mapping is immutable
  - **Idempotency:** Calling `sync/2` with no pending changes is effectively free
  - **Opaque Integration:** Uses the same ID generation as static builders

  ## Important: Managing the Pending Queue

  The `Live` builder queues changes in memory until `sync/2` is called. In streaming
  scenarios, if you add edges continuously without syncing, the pending queue will
  grow unbounded and consume memory.

  **Best Practice:** Sync periodically based on your workload:

      # For high-frequency streaming (e.g., Kafka consumer)
      # Sync every N messages or every T seconds
      {builder, graph} =
        if Yog.Builder.Live.pending_count(builder) > 1000 do
          Yog.Builder.Live.sync(builder, graph)
        else
          {builder, graph}
        end

      # For batch processing
      # Build up a batch, then sync once
      builder = Enum.reduce(batch, builder, fn {from, to, weight}, b ->
        Yog.Builder.Live.add_edge(b, from, to, weight)
      end)
      {builder, graph} = Yog.Builder.Live.sync(builder, graph)

  ## Recovery

  If you need to discard pending changes without applying them:
  - Use `purge_pending/1` to abandon changes
  - Use `checkpoint/1` to keep registry but clear pending

  ## Limitations

  - **Memory:** Pending changes are stored in memory until synced
  - **No Persistence:** The pending queue is lost if the process crashes
  - **Single-threaded:** Not designed for concurrent updates from multiple actors

  ## Example Usage

      # Initial setup - build base graph
      builder = Yog.Builder.Live.new() |> Yog.Builder.Live.add_edge("A", "B", 10)
      {builder, graph} = Yog.Builder.Live.sync(builder, Yog.directed())

      # Incremental update - add new edge efficiently
      builder = Yog.Builder.Live.add_edge(builder, "B", "C", 5)
      {builder, graph} = Yog.Builder.Live.sync(builder, graph)  # O(1) for just this edge!

      # Use with algorithms - get IDs from registry
      {:ok, a_id} = Yog.Builder.Live.get_id(builder, "A")
      {:ok, c_id} = Yog.Builder.Live.get_id(builder, "C")

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.Builder.Labeled
  alias Yog.Model

  @typedoc "Live builder type: {:live_builder, registry, next_id, pending}"
  @type builder :: {:live_builder, map(), integer(), [transition()]}

  @typedoc "Any type can be used as a label"
  @type label :: term()

  @typedoc "A pending transition"
  @type transition ::
          {:add_node, Yog.node_id(), label()}
          | {:add_edge, Yog.node_id(), Yog.node_id(), term()}
          | {:remove_edge, Yog.node_id(), Yog.node_id()}
          | {:remove_node, Yog.node_id()}

  # ============= Constructors =============

  @doc """
  Creates a new live builder for directed graphs.

  ## Examples

      iex> builder = Yog.Builder.Live.directed()
      iex> is_tuple(builder)
      true
  """
  @spec directed() :: builder()
  def directed, do: new()

  @doc """
  Creates a new live builder for undirected graphs.

  ## Examples

      iex> builder = Yog.Builder.Live.undirected()
      iex> is_tuple(builder)
      true
  """
  @spec undirected() :: builder()
  def undirected, do: new()

  @doc """
  Creates a new live builder with the specified graph type.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      iex> is_tuple(builder)
      true
  """
  @spec new() :: builder()
  def new do
    {:live_builder, %{}, 0, []}
  end

  @doc """
  Creates a live builder from an existing labeled builder.

  This is useful for transitioning from static to incremental building.

  ## Examples

      iex> labeled = Yog.Builder.Labeled.directed()
      ...> |> Yog.Builder.Labeled.add_edge("A", "B", 5)
      iex> Yog.Builder.Live.from_labeled(labeled)
      ...> |> is_tuple()
      true
  """
  @spec from_labeled(Labeled.builder()) :: builder()
  def from_labeled(labeled_builder) do
    registry = Labeled.to_registry(labeled_builder)
    next_id = Labeled.next_id(labeled_builder)
    {:live_builder, registry, next_id, []}
  end

  # ============= Edge Operations =============

  @doc """
  Adds an edge between two labeled nodes with a weight.

  The change is queued until `sync/2` is called.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> Yog.Builder.Live.pending_count(builder) > 0
      true
  """
  @spec add_edge(builder(), label(), label(), term()) :: builder()
  def add_edge(builder, from, to, weight) do
    {builder_with_src, src_id} = ensure_node(builder, from)
    {builder_with_both, dst_id} = ensure_node(builder_with_src, to)

    {:live_builder, registry, next_id, pending} = builder_with_both
    transition = {:add_edge, src_id, dst_id, weight}
    {:live_builder, registry, next_id, [transition | pending]}
  end

  @doc """
  Adds an unweighted edge (weight = nil) between two labeled nodes.

  ## Examples

      iex> Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_unweighted_edge("A", "B")
      ...> |> is_tuple()
      true
  """
  @spec add_unweighted_edge(builder(), label(), label()) :: builder()
  def add_unweighted_edge(builder, from, to) do
    add_edge(builder, from, to, nil)
  end

  @doc """
  Adds a simple edge with weight 1 between two labeled nodes.

  ## Examples

      iex> Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_simple_edge("A", "B")
      ...> |> is_tuple()
      true
  """
  @spec add_simple_edge(builder(), label(), label()) :: builder()
  def add_simple_edge(builder, from, to) do
    add_edge(builder, from, to, 1)
  end

  @doc """
  Removes an edge between two labeled nodes.

  The change is queued until `sync/2` is called.

  ## Examples

      iex> Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      ...> |> Yog.Builder.Live.remove_edge("A", "B")
      ...> |> is_tuple()
      true
  """
  @spec remove_edge(builder(), label(), label()) :: builder()
  def remove_edge({:live_builder, registry, next_id, pending} = builder, from, to) do
    case {Map.fetch(registry, from), Map.fetch(registry, to)} do
      {{:ok, src_id}, {:ok, dst_id}} ->
        transition = {:remove_edge, src_id, dst_id}
        {:live_builder, registry, next_id, [transition | pending]}

      _ ->
        # One or both nodes don't exist, nothing to remove
        builder
    end
  end

  @doc """
  Removes a node by its label.

  Also removes all edges connected to this node.
  The change is queued until `sync/2` is called.

  ## Examples

      iex> Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      ...> |> Yog.Builder.Live.remove_node("A")
      ...> |> is_tuple()
      true
  """
  @spec remove_node(builder(), label()) :: builder()
  def remove_node({:live_builder, registry, next_id, pending}, label) do
    case Map.fetch(registry, label) do
      {:ok, id} ->
        new_registry = Map.delete(registry, label)
        transition = {:remove_node, id}
        {:live_builder, new_registry, next_id, [transition | pending]}

      :error ->
        # Node doesn't exist, nothing to remove
        {:live_builder, registry, next_id, pending}
    end
  end

  # ============= Synchronization =============

  @doc """
  Applies all pending changes to the graph.

  Returns `{builder, updated_graph}` where the builder has cleared its pending queue.
  This is an O(ΔE) operation where ΔE is the number of pending edges.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> {_builder, graph} = Yog.Builder.Live.sync(builder, Yog.directed())
      iex> length(Yog.all_nodes(graph))
      2
  """
  @spec sync(builder(), Yog.graph()) :: {builder(), Yog.graph()}
  def sync({:live_builder, registry, next_id, pending}, graph) do
    case pending do
      [] ->
        # No pending changes - fast path
        {{:live_builder, registry, next_id, []}, graph}

      _ ->
        # Reverse to apply in insertion order (we prepended)
        transitions = Enum.reverse(pending)

        # Apply all transitions
        new_graph = apply_transitions(graph, transitions)

        # Return builder with empty pending
        {{:live_builder, registry, next_id, []}, new_graph}
    end
  end

  @doc """
  Discards all pending changes without applying them.

  The registry (label-to-ID mappings) is preserved.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> builder = Yog.Builder.Live.purge_pending(builder)
      iex> Yog.Builder.Live.pending_count(builder)
      0
  """
  @spec purge_pending(builder()) :: builder()
  def purge_pending({:live_builder, registry, next_id, _pending}) do
    {:live_builder, registry, next_id, []}
  end

  @doc """
  Creates a checkpoint by clearing pending changes while preserving the registry.

  Similar to `purge_pending/1` but conceptually marks a save point.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> builder = Yog.Builder.Live.checkpoint(builder)
      iex> Yog.Builder.Live.pending_count(builder)
      0
  """
  @spec checkpoint(builder()) :: builder()
  def checkpoint({:live_builder, registry, next_id, _pending}) do
    {:live_builder, registry, next_id, []}
  end

  # ============= Queries =============

  @doc """
  Looks up the internal node ID for a given label.

  Returns `{:ok, id}` if the label exists in the registry,
  `{:error, nil}` otherwise.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      ...> |> Yog.Builder.Live.sync(Yog.directed())
      ...> |> elem(0)
      iex> Yog.Builder.Live.get_id(builder, "A")
      {:ok, 0}
  """
  @spec get_id(builder(), label()) :: {:ok, Yog.node_id()} | {:error, nil}
  def get_id({:live_builder, registry, _next_id, _pending}, label) do
    case Map.fetch(registry, label) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, nil}
    end
  end

  @doc """
  Returns all labels that have been registered.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> labels = Yog.Builder.Live.all_labels(builder)
      iex> Enum.sort(labels)
      ["A", "B"]
  """
  @spec all_labels(builder()) :: [label()]
  def all_labels({:live_builder, registry, _next_id, _pending}) do
    Map.keys(registry)
  end

  @doc """
  Returns the number of registered nodes.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> Yog.Builder.Live.node_count(builder)
      2
  """
  @spec node_count(builder()) :: integer()
  def node_count({:live_builder, registry, _next_id, _pending}) do
    map_size(registry)
  end

  @doc """
  Returns the number of pending changes.

  Use this to monitor queue growth and trigger syncs when needed.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> Yog.Builder.Live.pending_count(builder) > 0
      true
  """
  @spec pending_count(builder()) :: integer()
  def pending_count({:live_builder, _registry, _next_id, pending}) do
    length(pending)
  end

  # ============= Private Helpers =============

  defp ensure_node({:live_builder, registry, next_id, pending}, label) do
    case Map.fetch(registry, label) do
      {:ok, id} ->
        {{:live_builder, registry, next_id, pending}, id}

      :error ->
        id = next_id
        new_registry = Map.put(registry, label, id)
        transition = {:add_node, id, label}
        new_builder = {:live_builder, new_registry, id + 1, [transition | pending]}
        {new_builder, id}
    end
  end

  defp apply_transitions(graph, transitions) do
    Enum.reduce(transitions, graph, fn transition, g ->
      case transition do
        {:add_node, id, label} ->
          Model.add_node(g, id, label)

        {:add_edge, src, dst, weight} ->
          case Model.add_edge(g, src, dst, weight) do
            {:ok, new_g} -> new_g
            {:error, _} -> g
          end

        {:remove_edge, src, dst} ->
          Model.remove_edge(g, src, dst)

        {:remove_node, id} ->
          Model.remove_node(g, id)
      end
    end)
  end
end
