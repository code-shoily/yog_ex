defmodule Yog.Functional.Analysis do
  @moduledoc """
  Structural analysis for inductive graphs — components, bridges, articulation
  points, reachability closure, biconnected components, and dominators.

  This module analyzes graph structure using the inductive primitives from
  `Yog.Functional.Model`. Component extraction uses `match/2`, while bridge,
  articulation-point, and biconnected-component detection use Tarjan-style DFS.

  ## Available Analyses

  | Analysis | Function | Description |
  |----------|----------|-------------|
  | Connected Components | `connected_components/1` | Extract components by following outgoing adjacency |
  | Bridges & Articulation Points | `analyze_connectivity/1` | Single-pass Tarjan DFS for undirected graphs |
  | Transitive Closure | `transitive_closure/1` | Compute complete directed reachability |
  | Biconnected Components | `biconnected_components/1` | Find maximal non-separable edge components in undirected graphs |
  | Dominators | `dominators/2` | Compute immediate dominators for reachable flow-graph nodes |

  ## Semantics and Caveats

  - `connected_components/1`, `analyze_connectivity/1`, and
    `biconnected_components/1` are intended for undirected graphs. They operate on
    each context's `out_edges`; undirected functional graphs store symmetric
    out-edges, so this represents ordinary adjacency.
  - On directed graphs, `connected_components/1` follows outgoing edges only. It is
    therefore not a weakly-connected-components or strongly-connected-components
    algorithm.
  - `transitive_closure/1` and `dominators/2` are directed reachability analyses.
  - `dominators/2` returns immediate dominators only for nodes reachable from the
    provided start node. A missing start node returns an empty map.

  ## Key Concepts

  - **Bridge** (cut-edge): An edge whose removal disconnects the graph.
  - **Articulation Point** (cut-vertex): A node whose removal disconnects the graph.
  - **Biconnected Component**: A maximal edge set that remains connected after
    removing any single non-articulation vertex.
  - Components are extracted inductively via `match/2`, naturally preventing
    revisits without an explicit visited set.

  ## Complexity

  `connected_components/1`, `analyze_connectivity/1`, `transitive_closure/1`, and
  `biconnected_components/1` are `O(V + E)` over the relevant traversal work,
  except `transitive_closure/1`, which performs reachability from every node and is
  `O(V * (V + E))`. `dominators/2` uses a fixed-point algorithm suitable for small
  functional flow graphs rather than maximum raw throughput.

  ## References

  - [Wikipedia: Bridge (Graph Theory)](https://en.wikipedia.org/wiki/Bridge_(graph_theory))
  - [Wikipedia: Biconnected Component](https://en.wikipedia.org/wiki/Biconnected_component)
  """
  alias Yog.Functional.{Model, Traversal}

  @type bridge :: {Model.node_id(), Model.node_id()}

  @doc """
  Finds all connected components in an undirected graph.

  Returns a list of lists of node IDs. This function follows `out_edges`; for an
  undirected functional graph those edges are symmetric and represent ordinary
  adjacency. On directed graphs this is an outgoing-reachability component
  extraction, not weak or strong connectivity.

  ## Examples

      iex> alias Yog.Functional.{Model, Analysis}
      iex> graph = Model.new(:undirected)
      ...> |> Model.put_node(1, "A")
      ...> |> Model.put_node(2, "B")
      ...> |> Model.put_node(3, "C")
      ...> |> Model.add_edge!(1, 2)
      iex> components = Analysis.connected_components(graph)
      iex> Enum.map(components, &Enum.sort/1) |> Enum.sort()
      [[1, 2], [3]]
  """
  @spec connected_components(Model.t()) :: [[Model.node_id()]]
  def connected_components(graph) do
    do_find_components(graph, [])
  end

  defp do_find_components(graph, acc) do
    if Model.empty?(graph) do
      Enum.reverse(acc)
    else
      [start_id | _] = Model.node_ids(graph)

      {component, remaining_graph} = extract_component(graph, [start_id], [])
      do_find_components(remaining_graph, [component | acc])
    end
  end

  @doc """
  Identifies bridges (cut-edges) and articulation points (cut-vertices)
  in an undirected graph using a single-pass DFS.

  The function assumes undirected adjacency represented by symmetric `out_edges`,
  which `Yog.Functional.Model` maintains for graphs created with
  `Model.new(:undirected)`.

  ## Examples

      iex> alias Yog.Functional.{Model, Analysis}
      iex> graph = Model.new(:undirected)
      ...> |> Model.put_node(1, "A") |> Model.put_node(2, "B") |> Model.put_node(3, "C")
      ...> |> Model.add_edge!(1, 2) |> Model.add_edge!(2, 3)
      iex> result = Analysis.analyze_connectivity(graph)
      iex> result.bridges |> Enum.sort()
      [{1, 2}, {2, 3}]
      iex> result.points |> Enum.sort()
      [2]
  """
  @spec analyze_connectivity(Model.t()) ::
          %{bridges: [bridge()], points: [Model.node_id()]}
  def analyze_connectivity(graph) do
    initial_state = %{
      tin: %{},
      low: %{},
      timer: 0,
      bridges: [],
      points: MapSet.new(),
      visited: MapSet.new()
    }

    final_state =
      Enum.reduce(Model.node_ids(graph), initial_state, fn id, acc ->
        if MapSet.member?(acc.visited, id) do
          acc
        else
          tarjan_dfs(graph, id, nil, acc) |> elem(0)
        end
      end)

    %{bridges: final_state.bridges, points: MapSet.to_list(final_state.points)}
  end

  defp tarjan_dfs(graph, v, parent, state) do
    tin = Map.put(state.tin, v, state.timer)
    low = Map.put(state.low, v, state.timer)
    visited = MapSet.put(state.visited, v)
    timer = state.timer + 1

    base_state = %{state | tin: tin, low: low, visited: visited, timer: timer}

    {:ok, ctx} = Model.get_node(graph, v)
    neighbors = Map.keys(ctx.out_edges)

    {reduce_state, children_count} =
      Enum.reduce(neighbors, {base_state, 0}, fn to, {acc_state, children} ->
        process_neighbor(graph, v, to, parent, acc_state, children)
      end)

    final_state =
      if parent == nil and children_count > 1 do
        %{reduce_state | points: MapSet.put(reduce_state.points, v)}
      else
        reduce_state
      end

    {final_state, children_count}
  end

  defp process_neighbor(graph, v, to, parent, acc_state, children) do
    cond do
      to == parent ->
        {acc_state, children}

      MapSet.member?(acc_state.visited, to) ->
        new_low = min(acc_state.low[v], acc_state.tin[to])
        {%{acc_state | low: Map.put(acc_state.low, v, new_low)}, children}

      true ->
        {post_dfs_state, _} = tarjan_dfs(graph, to, v, acc_state)

        new_v_low = min(post_dfs_state.low[v], post_dfs_state.low[to])

        new_bridges =
          if post_dfs_state.low[to] > post_dfs_state.tin[v] do
            [{min(v, to), max(v, to)} | post_dfs_state.bridges]
          else
            post_dfs_state.bridges
          end

        new_points =
          if parent != nil and post_dfs_state.low[to] >= post_dfs_state.tin[v] do
            MapSet.put(post_dfs_state.points, v)
          else
            post_dfs_state.points
          end

        {%{
           post_dfs_state
           | low: Map.put(post_dfs_state.low, v, new_v_low),
             bridges: new_bridges,
             points: new_points
         }, children + 1}
    end
  end

  defp extract_component(graph, [], acc), do: {acc, graph}

  defp extract_component(graph, [id | stack], acc) do
    case Model.match(graph, id) do
      {:error, :not_found} ->
        extract_component(graph, stack, acc)

      {:ok, ctx, remaining} ->
        neighbors = Map.keys(ctx.out_edges)
        extract_component(remaining, neighbors ++ stack, [id | acc])
    end
  end

  @doc """
  Computes the transitive closure of the graph as a map of node reachability.

  Returns `%{node_id => [reachable_node_ids]}`. Each reachable list includes the
  source node itself because reachability is computed via traversal starting at
  that node.

  ## Examples

      iex> alias Yog.Functional.{Model, Analysis}
      iex> graph = Model.empty() |> Model.put_node(1, "A") |> Model.put_node(2, "B")
      ...> |> Model.add_edge!(1, 2)
      iex> tc = Analysis.transitive_closure(graph)
      iex> tc[1] |> Enum.sort()
      [1, 2]
  """
  @spec transitive_closure(Model.t()) :: %{Model.node_id() => [Model.node_id()]}
  def transitive_closure(graph) do
    ids = Model.node_ids(graph)

    Enum.reduce(ids, %{}, fn id, acc ->
      reachable = Traversal.reachable(graph, id)
      Map.put(acc, id, reachable)
    end)
  end

  @doc """
  Finds the biconnected components of an undirected graph.

  Each component is represented as a list of edge tuples `{u, v}`. Isolated nodes
  do not form edge-biconnected components and therefore do not appear in the
  result.

  ## Examples

      iex> alias Yog.Functional.{Model, Analysis}
      iex> graph = Model.new(:undirected)
      ...> |> Model.put_node(1, "A") |> Model.put_node(2, "B")
      ...> |> Model.put_node(3, "C") |> Model.add_edge!(1, 2)
      ...> |> Model.add_edge!(2, 3)
      iex> bccs = Analysis.biconnected_components(graph)
      iex> length(bccs)
      2
  """
  @spec biconnected_components(Model.t()) :: [[{Model.node_id(), Model.node_id()}]]
  def biconnected_components(graph) do
    # This uses a variation of Tarjan's DFS tracking edges in a stack
    initial_state = %{
      tin: %{},
      low: %{},
      timer: 0,
      edge_stack: [],
      components: [],
      visited: MapSet.new()
    }

    final_state =
      Enum.reduce(Model.node_ids(graph), initial_state, fn id, acc ->
        if MapSet.member?(acc.visited, id) do
          acc
        else
          {state, _} = bcc_dfs(graph, id, nil, acc)
          state
        end
      end)

    final_state.components
  end

  defp bcc_dfs(graph, v, parent, state) do
    tin = Map.put(state.tin, v, state.timer)
    low = Map.put(state.low, v, state.timer)
    visited = MapSet.put(state.visited, v)
    timer = state.timer + 1

    base_state = %{state | tin: tin, low: low, visited: visited, timer: timer}

    {:ok, ctx} = Model.get_node(graph, v)
    neighbors = Map.keys(ctx.out_edges)

    Enum.reduce(neighbors, {base_state, 0}, fn to, {acc_state, children} ->
      cond do
        to == parent ->
          {acc_state, children}

        Map.has_key?(acc_state.tin, to) ->
          # Back-edge
          new_stack =
            if acc_state.tin[to] < acc_state.tin[v] do
              [{v, to} | acc_state.edge_stack]
            else
              acc_state.edge_stack
            end

          new_low = min(acc_state.low[v], acc_state.tin[to])

          {%{acc_state | low: Map.put(acc_state.low, v, new_low), edge_stack: new_stack},
           children}

        true ->
          # Tree-edge
          state_with_edge = %{acc_state | edge_stack: [{v, to} | acc_state.edge_stack]}
          {post_dfs_state, _} = bcc_dfs(graph, to, v, state_with_edge)

          new_v_low = min(post_dfs_state.low[v], post_dfs_state.low[to])

          {final_state, popped_stack} =
            if post_dfs_state.low[to] >= post_dfs_state.tin[v] do
              {comp, remaining_stack} = pop_bcc_stack(post_dfs_state.edge_stack, {v, to}, [])

              {%{post_dfs_state | components: [comp | post_dfs_state.components]},
               remaining_stack}
            else
              {post_dfs_state, post_dfs_state.edge_stack}
            end

          {%{final_state | low: Map.put(final_state.low, v, new_v_low), edge_stack: popped_stack},
           children + 1}
      end
    end)
  end

  defp pop_bcc_stack([{u, v} | rest], target, acc) when {u, v} == target do
    {[{u, v} | acc], rest}
  end

  defp pop_bcc_stack([edge | rest], target, acc) do
    pop_bcc_stack(rest, target, [edge | acc])
  end

  defp pop_bcc_stack([], _, acc), do: {acc, []}

  @doc """
  Finds immediate dominators of all reachable nodes from a start node.

  Returns `%{node_id => idom_id}`. The start node dominates itself. Nodes that are
  not reachable from `start` are omitted. If `start` is not present in the graph,
  the result is `%{}`.

  Uses a recursive fixed-point implementation suitable for small functional flow
  graphs and proof-oriented examples.
  """
  @spec dominators(Model.t(), Model.node_id()) :: %{Model.node_id() => Model.node_id()}
  def dominators(graph, start) do
    # Filter only reachable nodes to simplify
    reachable_ids = Traversal.reachable(graph, start)
    # Get predecessors for these nodes (only considering those in reachable set)
    predecessors =
      Enum.into(reachable_ids, %{}, fn id ->
        {:ok, in_n} = Model.in_neighbors(graph, id)
        {id, Map.keys(in_n)}
      end)

    # Initial dominators: D(start) = {start}, D(v) = {all reachable nodes}
    initial_doms =
      Enum.into(reachable_ids, %{}, fn
        id when id == start -> {id, [id]}
        id -> {id, reachable_ids}
      end)

    compute_dominators(initial_doms, predecessors, reachable_ids, start)
  end

  defp compute_dominators(doms, preds, ids, start) do
    new_doms =
      Enum.reduce(ids, doms, fn v, acc ->
        if v == Enum.at(acc[v], 0) and length(acc[v]) == 1 do
          acc
        else
          # D(v) = {v} union Intersection of D(p) for all predecessors p of v
          intersection =
            case preds[v] do
              [] -> []
              ps -> Enum.map(ps, &acc[&1]) |> Enum.reduce(&intersect/2)
            end

          Map.put(acc, v, Enum.uniq([v | intersection]))
        end
      end)

    if new_doms == doms do
      # Convert set of dominators to immediate dominator (idom)
      # idom(v) is the node in D(v) \ {v} that is "closest" to v,
      # which in the set-based approach is the one with the largest dominator set among D(v) \ {v}.
      Enum.into(new_doms, %{}, fn {v, ds} ->
        if v == start do
          {v, v}
        else
          # Filter out v itself
          candidates = Enum.reject(ds, &(&1 == v))

          # The idom is the candidate whose own dominator set is the largest.
          # (Wait, if A dominates B, then D(A) is a subset of D(B). So idom is the one with largest D(x) in D(v)\{v})
          idom = Enum.max_by(candidates, fn c -> length(new_doms[c]) end)
          {v, idom}
        end
      end)
    else
      compute_dominators(new_doms, preds, ids, start)
    end
  end

  defp intersect(a, b), do: Enum.filter(a, &(&1 in b))
end
