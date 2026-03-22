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
      # {builder, graph} =
      #   if Yog.Builder.Live.pending_count(builder) > 1000 do
      #     Yog.Builder.Live.sync(builder, graph)
      #   else
      #     {builder, graph}
      #   end

      # For batch processing
      # Build up a batch, then sync once
      # builder = Enum.reduce(batch, builder, fn {from, to, weight}, b ->
      #   Yog.Builder.Live.add_edge(b, from, to, weight)
      # end)
      # {builder, graph} = Yog.Builder.Live.sync(builder, graph)

  ## Recovery

  If you need to discard pending changes without applying them:
  - Use `purge_pending/1` to abandon changes
  - Use `checkpoint/1` to keep registry but clear pending

  ## Limitations

  - **Memory:** Pending changes are stored in memory until synced
  - **No Persistence:** The pending queue is lost if the process crashes
  - **Single-threaded:** Not designed for concurrent updates from multiple actors

  ## Example Usage (Not a doctest - delegates to Erlang)

      # Initial setup - build base graph
      # builder = Yog.Builder.Live.new() |> Yog.Builder.Live.add_edge("A", "B", 10)
      # {builder, graph} = Yog.Builder.Live.sync(builder, Yog.directed())

      # Incremental update - add new edge efficiently
      # builder = Yog.Builder.Live.add_edge(builder, "B", "C", 5)
      # {builder, graph} = Yog.Builder.Live.sync(builder, graph)  # O(1) for just this edge!

      # Use with algorithms - get IDs from registry
      # {:ok, a_id} = Yog.Builder.Live.get_id(builder, "A")
      # {:ok, c_id} = Yog.Builder.Live.get_id(builder, "C")
      # path = Yog.Pathfinding.shortest_path(graph, a_id, c_id, ...)
  """

  @typedoc "Opaque live builder type"
  @type builder :: term()

  @typedoc "Any type can be used as a label"
  @type label :: term()

  # ============= Constructors =============

  @doc """
  Creates a new live builder for directed graphs.

  ## Examples

      iex> builder = Yog.Builder.Live.directed()
      iex> is_tuple(builder)
      true
  """
  @spec directed() :: builder()
  defdelegate directed(), to: :yog@builder@live

  @doc """
  Creates a new live builder for undirected graphs.

  ## Examples

      iex> builder = Yog.Builder.Live.undirected()
      iex> is_tuple(builder)
      true
  """
  @spec undirected() :: builder()
  defdelegate undirected(), to: :yog@builder@live

  @doc """
  Creates a new live builder with the specified graph type.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      iex> is_tuple(builder)
      true
  """
  @spec new() :: builder()
  defdelegate new(), to: :yog@builder@live

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
  @spec from_labeled(Yog.Builder.Labeled.builder()) :: builder()
  defdelegate from_labeled(labeled_builder), to: :yog@builder@live

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
  defdelegate add_edge(builder, from, to, weight), to: :yog@builder@live

  @doc """
  Adds an unweighted edge (weight = 1) between two labeled nodes.

  ## Examples

      iex> Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_unweighted_edge("A", "B")
      ...> |> is_tuple()
      true
  """
  @spec add_unweighted_edge(builder(), label(), label()) :: builder()
  defdelegate add_unweighted_edge(builder, from, to), to: :yog@builder@live

  @doc """
  Adds a simple edge with no weight data between two labeled nodes.

  ## Examples

      iex> Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_simple_edge("A", "B")
      ...> |> is_tuple()
      true
  """
  @spec add_simple_edge(builder(), label(), label()) :: builder()
  defdelegate add_simple_edge(builder, from, to), to: :yog@builder@live

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
  defdelegate remove_edge(builder, from, to), to: :yog@builder@live

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
  defdelegate remove_node(builder, label), to: :yog@builder@live

  # ============= Synchronization =============

  @doc """
  Applies all pending changes to the graph.

  Returns `{builder, updated_graph}` where the builder has cleared its pending queue.
  This is an O(ΔE) operation where ΔE is the number of pending edges.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> {builder, graph} = Yog.Builder.Live.sync(builder, Yog.directed())
      iex> length(Yog.all_nodes(graph))
      2
  """
  @spec sync(builder(), Yog.graph()) :: {builder(), Yog.graph()}
  defdelegate sync(builder, graph), to: :yog@builder@live

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
  defdelegate purge_pending(builder), to: :yog@builder@live

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
  defdelegate checkpoint(builder), to: :yog@builder@live

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
  def get_id(builder, label) do
    case :yog@builder@live.get_id(builder, label) do
      {:ok, id} -> {:ok, id}
      {:error, _} -> {:error, nil}
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
  defdelegate all_labels(builder), to: :yog@builder@live

  @doc """
  Returns the number of registered nodes.

  ## Examples

      iex> builder = Yog.Builder.Live.new()
      ...> |> Yog.Builder.Live.add_edge("A", "B", 10)
      iex> Yog.Builder.Live.node_count(builder)
      2
  """
  @spec node_count(builder()) :: integer()
  defdelegate node_count(builder), to: :yog@builder@live

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
  defdelegate pending_count(builder), to: :yog@builder@live
end
