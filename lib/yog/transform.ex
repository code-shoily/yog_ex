defmodule Yog.Transform do
  @moduledoc """
  Graph transformations and mappings - functor operations on graphs.

  This module provides operations that transform graphs while preserving or reshaping
  their structure. These are useful for adapting graph data types, creating derived graphs,
  and preparing graphs for specific algorithms.

  ## Available Transformations

  | Transformation | Function | Complexity | Use Case |
  |----------------|----------|------------|----------|
  | Transpose | `transpose/1` | $\\mathcal{O}(1)$ | Reverse edge directions |
  | Add Self-Loops | `add_self_loops/2` | $\\mathcal{O}(V)$ | Add reflexivity to nodes |
  | Remove Self-Loops | `remove_self_loops/1` | $\\mathcal{O}(E)$ | Remove reflexive edges |
  | To Directed | `to_directed/1` | $\\mathcal{O}(1)$ | Convert undirected to directed |
  | To Undirected | `to_undirected/2` | $\\mathcal{O}(E)$ | Mirror directed edges symmetrically |
  | Map Nodes | `map_nodes/2` | $\\mathcal{O}(V)$ | Transform node data |
  | Map Nodes Indexed | `map_nodes_indexed/2` | $\\mathcal{O}(V)$ | Transform node data with node ID |
  | Map Nodes Async | `map_nodes_async/3` | $\\mathcal{O}(V / \\text{cores})$ | Parallel node transforms |
  | Relabel Nodes | `relabel_nodes/2` | $\\mathcal{O}(V + E)$ | Rename node IDs |
  | Normalize Node IDs | `normalize_node_ids/1` | $\\mathcal{O}(V \\log V + E)$ | Reindex node IDs to `0..n-1` |
  | Update Node | `update_node/4` | $\\mathcal{O}(1)$ | Update specific node payload |
  | Filter Nodes | `filter_nodes/2` | $\\mathcal{O}(V + E)$ | Subgraph node predicate filtering |
  | Filter Nodes Indexed | `filter_nodes_indexed/2` | $\\mathcal{O}(V + E)$ | Subgraph node/ID predicate filtering |
  | Map Edges | `map_edges/2` | $\\mathcal{O}(E)$ | Transform edge weights |
  | Map Edges Indexed | `map_edges_indexed/2` | $\\mathcal{O}(E)$ | Transform edge weights with endpoints |
  | Map Edges Async | `map_edges_async/3` | $\\mathcal{O}(E / \\text{cores})$ | Parallel edge weight transforms |
  | Update Edge | `update_edge/5` | $\\mathcal{O}(1)$ | Update specific edge weight |
  | Filter Edges | `filter_edges/2` | $\\mathcal{O}(E)$ | Remove edges by predicate |
  | Merge | `merge/2` | $\\mathcal{O}(V + E)$ | Union two graphs |
  | Complement | `complement/2` | $\\mathcal{O}(V^2 + E)$ | Inverse graph edges |
  | Subgraph | `subgraph/2` | $\\mathcal{O}(V + E)$ | Extract subset of nodes |
  | Ego Graph | `ego_graph/4` | $\\mathcal{O}(V + E)$ | Extract k-hop neighborhood |
  | Contract | `contract/4` | $\\mathcal{O}(\\text{deg}(a) + \\text{deg}(b))$ | Merge node pair |
  | Quotient Graph | `quotient_graph/4` | $\\mathcal{O}(V + E)$ | Condense partition blocks |
  | Transitive Closure | `transitive_closure/1` | $\\mathcal{O}(V \\cdot (V + E))$ | Compute all reachable pairs |
  | Transitive Reduction | `transitive_reduction/1` | $\\mathcal{O}(V \\cdot (V + E))$ | Compute minimal reachability DAG |

  ## The O(1) Transpose Operation

  Due to Yog's dual-map representation (storing both outgoing and incoming edges),
  transposing a graph is a single pointer swap - dramatically faster than $\\mathcal{O}(E)$
  implementations in traditional adjacency list libraries.

  ## Functor Laws

  The mapping operations satisfy standard functor laws:
  - Identity: `map_nodes(g, fn x -> x end) == g`
  - Composition: `map_nodes(map_nodes(g, f), h) == map_nodes(g, fn x -> h.(f.(x)) end)`
  """

  alias Yog.Graph
  alias Yog.Model
  alias Yog.Utils

  # =============================================================================
  # STRUCTURE TRANSFORMATIONS
  # =============================================================================

  @doc """
  Reverses the direction of every edge in the graph (graph transpose).

  Due to the dual-map representation (storing both out_edges and in_edges),
  this is an **O(1) operation** - just a pointer swap! This is dramatically
  faster than most graph libraries where transpose is O(E).

  **Time Complexity:** O(1)

  **Property:** `transpose(transpose(G)) = G`

  ## Example

      iex> {:ok, graph} =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 20}])
      iex> reversed = Yog.Transform.transpose(graph)
      iex> Yog.successors(reversed, 2)
      [{1, 10}]
  """
  @spec transpose(Graph.t()) :: Graph.t()
  def transpose(graph) do
    validate_graph!(graph)
    %{graph | out_edges: graph.in_edges, in_edges: graph.out_edges}
  end

  @doc """
  Adds self-loops (edges from a node to itself) to all nodes in the graph.

  Existing self-loops are kept as-is. New self-loops are created with the
  supplied `default_weight`.

  **Time Complexity:** O(V)
  """
  @spec add_self_loops(Graph.t(), term()) :: Graph.t()
  def add_self_loops(graph, default_weight \\ 1) do
    validate_graph!(graph)

    Utils.map_fold(graph.nodes, graph, fn node_id, _data, g_acc ->
      if Model.has_edge?(g_acc, node_id, node_id) do
        g_acc
      else
        Model.add_edge!(g_acc, node_id, node_id, default_weight)
      end
    end)
  end

  @doc """
  Removes all self-loops (edges from a node to itself) from the graph.

  **Time Complexity:** O(E)
  """
  @spec remove_self_loops(Graph.t()) :: Graph.t()
  def remove_self_loops(graph) do
    validate_graph!(graph)
    filter_edges(graph, fn u, v, _w -> u != v end)
  end

  @doc """
  Converts an undirected graph to a directed graph.

  Since Yog internally stores undirected edges as bidirectional directed edges,
  this is essentially free — it just changes the `kind` flag.

  If the graph is already directed, it is returned unchanged.

  **Time Complexity:** O(1)
  """
  @spec to_directed(Graph.t()) :: Graph.t()
  def to_directed(graph) do
    validate_graph!(graph)
    %{graph | kind: :directed}
  end

  @doc """
  Converts a directed graph to an undirected graph using `resolve` for weight conflicts.

  If the graph is already undirected, it is returned unchanged.

  **Time Complexity:** O(E)

  ## Errors

  - Raises `ArgumentError` if `resolve` is not an arity-2 function.
  """
  @spec to_undirected(Graph.t(), (term(), term() -> term())) :: Graph.t()
  def to_undirected(graph, resolve) do
    validate_graph!(graph)

    unless is_function(resolve, 2) do
      raise ArgumentError,
            "expected resolve to be an arity-2 function, got: #{inspect(resolve)}"
    end

    if graph.kind == :undirected do
      graph
    else
      out_edges = graph.out_edges

      symmetric_out =
        Utils.map_fold(out_edges, out_edges, fn src, inner, acc_outer ->
          Utils.map_fold(inner, acc_outer, fn dst, weight, acc ->
            dst_inner = Map.get(acc, dst, %{})

            updated_inner =
              case Map.fetch(dst_inner, src) do
                {:ok, existing} -> Map.put(dst_inner, src, resolve.(existing, weight))
                :error -> Map.put(dst_inner, src, weight)
              end

            Map.put(acc, dst, updated_inner)
          end)
        end)

      %{graph | kind: :undirected, out_edges: symmetric_out, in_edges: symmetric_out}
    end
  end

  # =============================================================================
  # NODE TRANSFORMATIONS
  # =============================================================================

  @doc """
  Transforms node data using a function, preserving graph structure.

  **Time Complexity:** O(V)

  ## Errors

  - Raises `ArgumentError` if `fun` is not an arity-1 function.
  """
  @spec map_nodes(Graph.t(), (term() -> term())) :: Graph.t()
  def map_nodes(graph, fun) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    new_nodes = Map.new(graph.nodes, fn {id, data} -> {id, fun.(data)} end)
    %{graph | nodes: new_nodes}
  end

  @doc """
  Transforms node data using a function that also takes the node ID.

  **Time Complexity:** O(V)

  ## Errors

  - Raises `ArgumentError` if `fun` is not an arity-2 function.
  """
  @spec map_nodes_indexed(Graph.t(), (Yog.node_id(), term() -> term())) :: Graph.t()
  def map_nodes_indexed(graph, fun) do
    validate_graph!(graph)

    unless is_function(fun, 2) do
      raise ArgumentError, "expected fun to be an arity-2 function, got: #{inspect(fun)}"
    end

    new_nodes = Map.new(graph.nodes, fn {id, data} -> {id, fun.(id, data)} end)
    %{graph | nodes: new_nodes}
  end

  @doc """
  Relabels all node IDs in the graph using a mapping function.

  **Time Complexity:** O(V + E)

  ## Errors

  - Raises `ArgumentError` if `fun` is not an arity-1 function.
  """
  @spec relabel_nodes(Graph.t(), (Yog.node_id() -> Yog.node_id())) :: Graph.t()
  def relabel_nodes(graph, fun \\ &:erlang.phash2/1) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    base = Model.new(graph.kind)

    graph_with_nodes =
      Utils.map_fold(graph.nodes, base, fn id, data, acc ->
        Model.add_node(acc, fun.(id), data)
      end)

    is_directed = graph.kind == :directed

    Utils.map_fold(graph.out_edges, graph_with_nodes, fn u, dests, acc_outer ->
      Utils.map_fold(dests, acc_outer, fn v, w, acc ->
        if is_directed or u <= v do
          Model.add_edge!(acc, fun.(u), fun.(v), w)
        else
          acc
        end
      end)
    end)
  end

  @doc """
  Normalizes all node IDs to a continuous range of integers `0..n-1`.

  **Time Complexity:** O(V log V + E)
  """
  @spec normalize_node_ids(Graph.t()) :: Graph.t()
  def normalize_node_ids(graph) do
    validate_graph!(graph)

    mapping =
      graph.nodes
      |> Map.keys()
      |> Enum.sort()
      |> Enum.with_index()
      |> Map.new()

    relabel_nodes(graph, fn id -> Map.fetch!(mapping, id) end)
  end

  @doc """
  Transforms node data using a function in parallel.

  **Time Complexity:** O(V/cores)

  ## Options

  - `:max_concurrency` - Maximum concurrent tasks (default: `System.schedulers_online()`)
  - `:timeout` - Task timeout in milliseconds (default: 5000)
  - `:ordered` - Preserve order (default: false)
  """
  @spec map_nodes_async(Graph.t(), (term() -> term()), keyword()) :: Graph.t()
  def map_nodes_async(graph, fun, opts \\ []) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    unless Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    default_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: 5000,
      ordered: false
    ]

    stream_opts = Keyword.merge(default_opts, opts)

    new_nodes =
      graph.nodes
      |> Task.async_stream(
        fn {id, data} -> {id, fun.(data)} end,
        stream_opts
      )
      |> Enum.reduce(%{}, fn {:ok, {id, new_data}}, acc ->
        Map.put(acc, id, new_data)
      end)

    %{graph | nodes: new_nodes}
  end

  @doc """
  Updates a specific node's data using an updater function.

  **Time Complexity:** O(1)
  """
  @spec update_node(Graph.t(), Yog.node_id(), term(), (term() -> term())) :: Graph.t()
  def update_node(graph, id, default, fun) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    %{graph | nodes: Map.update(graph.nodes, id, default, fun)}
  end

  @doc """
  Filters nodes by a predicate, automatically pruning connected edges.

  **Time Complexity:** O(V + E)
  """
  @spec filter_nodes(Graph.t(), (term() -> boolean())) :: Graph.t()
  def filter_nodes(graph, predicate) do
    validate_graph!(graph)

    unless is_function(predicate, 1) do
      raise ArgumentError,
            "expected predicate to be an arity-1 function, got: #{inspect(predicate)}"
    end

    kept_nodes = Map.filter(graph.nodes, fn {_id, data} -> predicate.(data) end)

    %{
      graph
      | nodes: kept_nodes,
        out_edges: prune_edges(graph.out_edges, kept_nodes),
        in_edges: prune_edges(graph.in_edges, kept_nodes)
    }
  end

  @doc """
  Filters nodes by a predicate that receives `(node_id, node_data)`.

  **Time Complexity:** O(V + E)
  """
  @spec filter_nodes_indexed(Graph.t(), (Yog.node_id(), term() -> boolean())) :: Graph.t()
  def filter_nodes_indexed(graph, predicate) do
    validate_graph!(graph)

    unless is_function(predicate, 2) do
      raise ArgumentError,
            "expected predicate to be an arity-2 function, got: #{inspect(predicate)}"
    end

    kept_nodes = Map.filter(graph.nodes, fn {id, data} -> predicate.(id, data) end)

    %{
      graph
      | nodes: kept_nodes,
        out_edges: prune_edges(graph.out_edges, kept_nodes),
        in_edges: prune_edges(graph.in_edges, kept_nodes)
    }
  end

  # =============================================================================
  # EDGE TRANSFORMATIONS
  # =============================================================================

  @doc """
  Transforms edge weights using a function, preserving graph structure.

  **Time Complexity:** O(E)
  """
  @spec map_edges(Graph.t(), (term() -> term())) :: Graph.t()
  def map_edges(graph, fun) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    transform_inner = fn inner_map ->
      Map.new(inner_map, fn {dst, weight} -> {dst, fun.(weight)} end)
    end

    transform_outer = fn outer_map ->
      Map.new(outer_map, fn {src, inner_map} -> {src, transform_inner.(inner_map)} end)
    end

    %{
      graph
      | out_edges: transform_outer.(graph.out_edges),
        in_edges: transform_outer.(graph.in_edges)
    }
  end

  @doc """
  Transforms edge weights using a function in parallel.

  **Time Complexity:** O(E/cores)
  """
  @spec map_edges_async(Graph.t(), (term() -> term()), keyword()) :: Graph.t()
  def map_edges_async(graph, fun, opts \\ []) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    unless Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    default_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: 5000,
      ordered: false
    ]

    stream_opts = Keyword.merge(default_opts, opts)

    all_out_edges =
      for {src, inner} <- graph.out_edges,
          {dst, weight} <- inner,
          do: {:out, src, dst, weight}

    all_in_edges =
      for {dst, inner} <- graph.in_edges,
          {src, weight} <- inner,
          do: {:in, dst, src, weight}

    all_edges = all_out_edges ++ all_in_edges

    processed_edges =
      all_edges
      |> Task.async_stream(
        fn
          {:out, src, dst, weight} -> {:out, src, dst, fun.(weight)}
          {:in, dst, src, weight} -> {:in, dst, src, fun.(weight)}
        end,
        stream_opts
      )
      |> Enum.reduce({%{}, %{}}, fn {:ok, edge}, {out_acc, in_acc} ->
        case edge do
          {:out, src, dst, new_weight} ->
            new_inner = Map.get(out_acc, src, %{}) |> Map.put(dst, new_weight)
            {Map.put(out_acc, src, new_inner), in_acc}

          {:in, dst, src, new_weight} ->
            new_inner = Map.get(in_acc, dst, %{}) |> Map.put(src, new_weight)
            {out_acc, Map.put(in_acc, dst, new_inner)}
        end
      end)

    {new_out_edges, new_in_edges} = processed_edges

    %{
      graph
      | out_edges: new_out_edges,
        in_edges: new_in_edges
    }
  end

  @doc """
  Transforms edge weights using a function that receives `(src, dst, weight)`.

  **Time Complexity:** O(E)
  """
  @spec map_edges_indexed(Graph.t(), (Yog.node_id(), Yog.node_id(), term() -> term())) ::
          Graph.t()
  def map_edges_indexed(graph, fun) do
    validate_graph!(graph)

    unless is_function(fun, 3) do
      raise ArgumentError, "expected fun to be an arity-3 function, got: #{inspect(fun)}"
    end

    new_out =
      Map.new(graph.out_edges, fn {src, inner} ->
        {src, Map.new(inner, fn {dst, weight} -> {dst, fun.(src, dst, weight)} end)}
      end)

    new_in =
      Map.new(graph.in_edges, fn {dst, inner} ->
        {dst, Map.new(inner, fn {src, weight} -> {src, fun.(src, dst, weight)} end)}
      end)

    %{graph | out_edges: new_out, in_edges: new_in}
  end

  @doc """
  Updates a specific edge's weight using an updater function.

  **Time Complexity:** O(1)
  """
  @spec update_edge(Graph.t(), Yog.node_id(), Yog.node_id(), term(), (term() -> term())) ::
          Graph.t()
  def update_edge(graph, u, v, default, fun) do
    validate_graph!(graph)

    unless is_function(fun, 1) do
      raise ArgumentError, "expected fun to be an arity-1 function, got: #{inspect(fun)}"
    end

    if Map.has_key?(graph.nodes, u) and Map.has_key?(graph.nodes, v) do
      update_directed = fn g, src, dst ->
        update_map = fn map, start, finish ->
          inner = Map.get(map, start, %{})
          new_inner = Map.update(inner, finish, default, fun)
          Map.put(map, start, new_inner)
        end

        %{
          g
          | out_edges: update_map.(g.out_edges, src, dst),
            in_edges: update_map.(g.in_edges, dst, src)
        }
      end

      case graph.kind do
        :directed ->
          update_directed.(graph, u, v)

        :undirected ->
          if u == v do
            update_directed.(graph, u, v)
          else
            graph
            |> update_directed.(u, v)
            |> update_directed.(v, u)
          end
      end
    else
      graph
    end
  end

  @doc """
  Filters edges by a predicate receiving `(src, dst, weight)`.

  **Time Complexity:** O(E)
  """
  @spec filter_edges(Graph.t(), (Yog.node_id(), Yog.node_id(), term() -> boolean())) ::
          Graph.t()
  def filter_edges(graph, predicate) do
    validate_graph!(graph)

    unless is_function(predicate, 3) do
      raise ArgumentError,
            "expected predicate to be an arity-3 function, got: #{inspect(predicate)}"
    end

    new_out =
      for {src, inner_map} <- graph.out_edges, reduce: %{} do
        acc ->
          filtered_inner =
            Map.filter(inner_map, fn {dst, weight} -> predicate.(src, dst, weight) end)

          if map_size(filtered_inner) > 0 do
            Map.put(acc, src, filtered_inner)
          else
            acc
          end
      end

    new_in =
      for {dst, inner_map} <- graph.in_edges, reduce: %{} do
        acc ->
          filtered_inner =
            Map.filter(inner_map, fn {src, weight} -> predicate.(src, dst, weight) end)

          if map_size(filtered_inner) > 0 do
            Map.put(acc, dst, filtered_inner)
          else
            acc
          end
      end

    %{graph | out_edges: new_out, in_edges: new_in}
  end

  # =============================================================================
  # GRAPH COMBINATIONS
  # =============================================================================

  @doc """
  Combines two graphs, with the second graph's data taking precedence on conflicts.

  **Time Complexity:** O(V + E)
  """
  @spec merge(Graph.t(), Graph.t()) :: Graph.t()
  def merge(graph1, graph2) do
    validate_graph!(graph1)
    validate_graph!(graph2)

    merge_inner = fn m1, m2 -> Map.merge(m1, m2) end

    merge_outer = fn outer1, outer2 ->
      Map.merge(outer1, outer2, fn _src, inner1, inner2 ->
        merge_inner.(inner1, inner2)
      end)
    end

    %{
      graph1
      | nodes: Map.merge(graph1.nodes, graph2.nodes),
        out_edges: merge_outer.(graph1.out_edges, graph2.out_edges),
        in_edges: merge_outer.(graph1.in_edges, graph2.in_edges)
    }
  end

  @doc """
  Returns the complement of a graph.

  **Time Complexity:** O(V² + E)
  """
  @spec complement(Graph.t(), term()) :: Graph.t()
  def complement(graph, default_weight) do
    validate_graph!(graph)

    node_ids = Map.keys(graph.nodes)

    out_edges =
      List.foldl(node_ids, %{}, fn src, acc_outer ->
        old_inner = Map.get(graph.out_edges, src, %{})

        inner =
          List.foldl(node_ids, %{}, fn dst, acc_inner ->
            cond do
              src == dst -> acc_inner
              Map.has_key?(old_inner, dst) -> acc_inner
              true -> Map.put(acc_inner, dst, default_weight)
            end
          end)

        if map_size(inner) > 0 do
          Map.put(acc_outer, src, inner)
        else
          acc_outer
        end
      end)

    in_edges =
      if graph.kind == :directed do
        Utils.map_fold(out_edges, %{}, fn src, inners, acc_in ->
          Utils.map_fold(inners, acc_in, fn dst, weight, acc_in_inner ->
            inner = Map.get(acc_in_inner, dst, %{}) |> Map.put(src, weight)
            Map.put(acc_in_inner, dst, inner)
          end)
        end)
      else
        out_edges
      end

    %{graph | out_edges: out_edges, in_edges: in_edges}
  end

  @doc """
  Extracts a subgraph containing only the specified nodes and their connecting edges.

  **Time Complexity:** O(V + E)
  """
  @spec subgraph(Graph.t(), [Yog.node_id()]) :: Graph.t()
  def subgraph(graph, ids) do
    validate_graph!(graph)

    unless is_list(ids) or is_struct(ids, MapSet) do
      raise ArgumentError, "expected ids to be a list or MapSet, got: #{inspect(ids)}"
    end

    id_set = MapSet.new(ids)

    filtered_nodes = Map.filter(graph.nodes, fn {id, _} -> MapSet.member?(id_set, id) end)

    %{
      graph
      | nodes: filtered_nodes,
        out_edges: prune_edges(graph.out_edges, id_set),
        in_edges: prune_edges(graph.in_edges, id_set)
    }
  end

  @doc """
  Returns the ego graph of a node within `radius` hops.

  **Time Complexity:** O(V + E)
  """
  @spec ego_graph(Graph.t(), Yog.node_id(), non_neg_integer(), keyword()) :: Graph.t()
  def ego_graph(graph, node, radius \\ 1, opts \\ []) do
    validate_graph!(graph)

    unless is_integer(radius) and radius >= 0 do
      raise ArgumentError,
            "expected radius to be a non-negative integer, got: #{inspect(radius)}"
    end

    unless Keyword.keyword?(opts) do
      raise ArgumentError, "expected opts to be a keyword list, got: #{inspect(opts)}"
    end

    mode = Keyword.get(opts, :mode, :successors)

    unless mode in [:successors, :neighbors] do
      raise ArgumentError,
            "expected :mode option to be :successors or :neighbors, got: #{inspect(mode)}"
    end

    id_set = ego_bfs(graph, node, radius, mode)
    subgraph(graph, MapSet.to_list(id_set))
  end

  defp ego_bfs(graph, node, radius, mode) do
    do_ego_bfs(graph, [node], 0, radius, MapSet.new([node]), mode)
  end

  defp do_ego_bfs(_graph, [], _dist, _max_dist, acc, _mode), do: acc

  defp do_ego_bfs(_graph, _queue, dist, max_dist, acc, _mode) when dist >= max_dist,
    do: acc

  defp do_ego_bfs(graph, queue, dist, max_dist, acc, mode) do
    {next_queue, next_acc} =
      Enum.reduce(queue, {[], acc}, fn current, {q, a} ->
        neighbors =
          case {graph.kind, mode} do
            {:undirected, _} -> Model.successor_ids(graph, current)
            {:directed, :neighbors} -> Model.neighbor_ids(graph, current)
            {:directed, _} -> Model.successor_ids(graph, current)
          end

        Enum.reduce(neighbors, {q, a}, fn n, {q2, a2} ->
          if MapSet.member?(a2, n) do
            {q2, a2}
          else
            {[n | q2], MapSet.put(a2, n)}
          end
        end)
      end)

    do_ego_bfs(graph, Enum.reverse(next_queue), dist + 1, max_dist, next_acc, mode)
  end

  @doc """
  Contracts an edge by merging node `b` into node `a`.

  **Time Complexity:** O(deg(a) + deg(b))
  """
  @spec contract(
          Graph.t(),
          Yog.node_id(),
          Yog.node_id(),
          (term(), term() -> term())
        ) :: Graph.t()
  def contract(graph, a, b, combine_weight) do
    validate_graph!(graph)

    unless is_function(combine_weight, 2) do
      raise ArgumentError,
            "expected combine_weight to be an arity-2 function, got: #{inspect(combine_weight)}"
    end

    if Map.has_key?(graph.nodes, a) and Map.has_key?(graph.nodes, b) and a != b do
      b_in = Map.get(graph.in_edges, b, %{})
      b_out = Map.get(graph.out_edges, b, %{})

      a_out = merge_adjacent(Map.get(graph.out_edges, a, %{}), b_out, combine_weight, a, b)

      out_edges =
        graph.out_edges
        |> redirect_neighbors(b_in, a, b, combine_weight)
        |> Map.put(a, a_out)
        |> Map.delete(b)

      if graph.kind == :undirected do
        %{graph | nodes: Map.delete(graph.nodes, b), out_edges: out_edges, in_edges: out_edges}
      else
        a_in = merge_adjacent(Map.get(graph.in_edges, a, %{}), b_in, combine_weight, a, b)
        in_edges = redirect_neighbors(graph.in_edges, b_out, a, b, combine_weight)
        in_edges = in_edges |> Map.put(a, a_in) |> Map.delete(b)

        %{graph | nodes: Map.delete(graph.nodes, b), out_edges: out_edges, in_edges: in_edges}
      end
    else
      graph
    end
  end

  @doc """
  Contracts nodes according to a partition map, producing a quotient graph.

  **Time Complexity:** O(V + E)
  """
  @spec quotient_graph(
          Graph.t(),
          %{Yog.node_id() => Yog.node_id()},
          (term(), term() -> term()),
          (term(), term() -> term())
        ) :: Graph.t()
  def quotient_graph(
        graph,
        partition,
        combine_weight \\ &Kernel.+/2,
        combine_data \\ fn exist, _new -> exist end
      ) do
    validate_graph!(graph)

    unless is_map(partition) do
      raise ArgumentError, "expected partition to be a map, got: #{inspect(partition)}"
    end

    unless is_function(combine_weight, 2) do
      raise ArgumentError,
            "expected combine_weight to be an arity-2 function, got: #{inspect(combine_weight)}"
    end

    unless is_function(combine_data, 2) do
      raise ArgumentError,
            "expected combine_data to be an arity-2 function, got: #{inspect(combine_data)}"
    end

    block_for = fn node -> Map.get(partition, node, node) end

    block_nodes =
      Yog.Utils.map_fold(graph.nodes, %{}, fn node, data, acc ->
        block = block_for.(node)
        Map.update(acc, block, data, fn existing -> combine_data.(existing, data) end)
      end)

    block_edges =
      List.foldl(Model.all_edges(graph), %{}, fn {u, v, weight}, acc ->
        bu = block_for.(u)
        bv = block_for.(v)

        if bu == bv do
          acc
        else
          Map.update(acc, {bu, bv}, weight, fn existing ->
            combine_weight.(existing, weight)
          end)
        end
      end)

    new_graph = %Graph{graph | nodes: block_nodes, out_edges: %{}, in_edges: %{}}

    Yog.Utils.map_fold(block_edges, new_graph, fn {from, to}, weight, g ->
      Yog.add_edge_ensure(g, from, to, weight)
    end)
  end

  # =============================================================================
  # REACHABILITY TRANSFORMATIONS
  # =============================================================================

  @doc """
  Computes the transitive closure of the graph.

  **Time Complexity:** O(V × (V + E))
  """
  @spec transitive_closure(Graph.t()) :: Graph.t()
  def transitive_closure(graph) do
    validate_graph!(graph)

    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        reachability_map = solve_transitive_reachability(graph, Enum.reverse(sorted))

        Utils.map_fold(reachability_map, graph, fn node, targets, g ->
          add_closure_edges(g, node, targets)
        end)

      {:error, :contains_cycle} ->
        nodes = Map.keys(graph.nodes)

        List.foldl(nodes, graph, fn src, g_acc ->
          reachable = Yog.Traversal.walk(in: graph, from: src, using: :breadth_first) |> tl()

          List.foldl(reachable, g_acc, fn dst, g ->
            if Model.has_edge?(g, src, dst) do
              g
            else
              Model.add_edge!(g, src, dst, 1)
            end
          end)
        end)
    end
  end

  @doc """
  Computes the transitive reduction of a DAG.

  **Time Complexity:** O(V × (V + E))
  """
  @spec transitive_reduction(Graph.t()) :: {:ok, Graph.t()} | {:error, :contains_cycle}
  def transitive_reduction(graph) do
    validate_graph!(graph)

    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        reachability = compute_reachability_dp(graph, sorted)
        out_edges = graph.out_edges

        edges_to_remove =
          List.foldl(sorted, [], fn node, acc ->
            case Map.fetch(out_edges, node) do
              {:ok, inner} when map_size(inner) > 0 ->
                targets = Map.keys(inner)

                List.foldl(targets, acc, fn target, inner_acc ->
                  has_indirect =
                    Enum.any?(targets, fn other_succ ->
                      other_succ != target and
                        MapSet.member?(
                          Map.get(reachability, other_succ, MapSet.new()),
                          target
                        )
                    end)

                  if has_indirect do
                    [{node, target} | inner_acc]
                  else
                    inner_acc
                  end
                end)

              _ ->
                acc
            end
          end)

        new_graph =
          List.foldl(edges_to_remove, graph, fn {from, to}, g ->
            Model.remove_edge(g, from, to)
          end)

        {:ok, new_graph}

      {:error, :contains_cycle} ->
        {:error, :contains_cycle}
    end
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  defp validate_graph!(%Graph{}), do: :ok

  defp validate_graph!(other) do
    raise ArgumentError, "expected a Yog.Graph struct, got: #{inspect(other)}"
  end

  defp prune_edges(outer_map, allowed) do
    outer_map
    |> Map.filter(fn {src, _} -> contains?(allowed, src) end)
    |> Map.new(fn {src, inner_map} ->
      {src, Map.filter(inner_map, fn {dst, _} -> contains?(allowed, dst) end)}
    end)
  end

  defp contains?(%MapSet{} = set, key), do: MapSet.member?(set, key)
  defp contains?(map, key) when is_map(map), do: Map.has_key?(map, key)

  defp merge_adjacent(a_edges, b_edges, combine_weight, a, b) do
    Map.merge(a_edges, b_edges, fn _k, v1, v2 -> combine_weight.(v1, v2) end)
    |> Map.delete(a)
    |> Map.delete(b)
  end

  defp redirect_neighbors(adj_map, edges_to_redirect, a, b, combine_weight) do
    Utils.map_fold(edges_to_redirect, adj_map, fn nb, w, acc ->
      if nb == a or nb == b do
        acc
      else
        Map.update(acc, nb, %{a => w}, fn nb_edges ->
          nb_edges
          |> Map.delete(b)
          |> Map.update(a, w, &combine_weight.(&1, w))
        end)
      end
    end)
  end

  defp solve_transitive_reachability(graph, sorted_nodes) do
    out_edges = graph.out_edges

    List.foldl(sorted_nodes, %{}, fn node, acc ->
      successors =
        case Map.fetch(out_edges, node) do
          {:ok, inner} -> Map.keys(inner)
          :error -> []
        end

      all_reachable =
        List.foldl(successors, MapSet.new(successors), fn child, set_acc ->
          child_reachable = Map.get(acc, child, MapSet.new())
          MapSet.union(set_acc, child_reachable)
        end)

      Map.put(acc, node, all_reachable)
    end)
  end

  defp add_closure_edges(graph, node, targets) do
    existing =
      case Map.fetch(graph.out_edges, node) do
        {:ok, edges} -> Map.keys(edges) |> MapSet.new()
        :error -> MapSet.new()
      end

    List.foldl(MapSet.to_list(targets), graph, fn target, g_acc ->
      if MapSet.member?(existing, target) do
        g_acc
      else
        Model.add_edge!(g_acc, node, target, 1)
      end
    end)
  end

  defp compute_reachability_dp(graph, sorted_nodes) do
    out_edges = graph.out_edges

    List.foldl(Enum.reverse(sorted_nodes), %{}, fn node, acc ->
      case Map.fetch(out_edges, node) do
        {:ok, edges} when map_size(edges) > 0 ->
          successors = Map.keys(edges)

          reachable_from_successors =
            List.foldl(successors, MapSet.new(), fn succ, set ->
              succ_reachable = Map.get(acc, succ, MapSet.new())
              MapSet.union(set, succ_reachable)
            end)

          all_reachable = MapSet.union(reachable_from_successors, MapSet.new(successors))
          Map.put(acc, node, all_reachable)

        _ ->
          acc
      end
    end)
  end
end
