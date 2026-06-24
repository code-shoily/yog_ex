defmodule Yog.Flow.NetworkSimplex do
  @moduledoc """
  Minimum cost flow algorithm using the Network Simplex method.

  This module solves the [minimum cost flow problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem):
  find the cheapest way to send a given amount of flow through a network where
  edges have both capacities and costs per unit of flow.

  ## Algorithm

  The Network Simplex algorithm is a specialized primal simplex method for network flows.
  In practice, it runs extremely fast (polynomial-like time) and handles arbitrary flows/demands.
  Unlike pseudo-polynomial algorithms (like Successive Shortest Path), its performance is
  independent of the total flow capacity (F), making it suitable for large networks.

  ## Key Concepts

  - **Minimum Cost Flow**: Route flow to satisfy demands at minimum total cost
  - **Node Demands**: Supply nodes (negative demand) and demand nodes (positive demand)
  - **Edge Costs**: Price per unit of flow on each edge
  - **Reduced Costs**: Modified costs ensuring optimality conditions
  - **Spanning Tree**: Basis for the simplex method on networks

  ## Implementation Notes

  - Internal state is stored in maps keyed by integer indices (nodes and edges).
    For very dense graphs, switching to Erlang `:array` could reduce memory and
    lookup overhead, but it would be a sizeable refactor.
  - The pivot step uses `Enum.find_index/2` to locate the entering and leaving
    edges inside the fundamental cycle. Each call is O(cycle length); building a
    position map would speed up hot paths on large instances.
  - The unboundedness test checks whether any original edge flow is at least
    half of the artificial big-M cost (`faux_inf / 2`). This 2x buffer is a
    defensive choice; NetworkX uses `flow >= faux_inf` directly.
  - Zero-capacity edges are filtered out before solving. Self-loops are kept and
    treated as non-tree edges, so finite negative-cost self-loops are saturated
    when beneficial.
  """

  alias Yog.Model

  # Capacity value used internally to represent infinity.
  @infinity_threshold 100_000_000_000

  @typedoc """
  A flow vector assigning an amount of flow to each edge.

  Each tuple is `{from_node, to_node, flow_amount}`.

  Note: the name `flow_map` is historical; the type is a list of flow tuples,
  not a map.
  """
  @type flow_map :: [{Yog.node_id(), Yog.node_id(), integer()}]

  @typedoc """
  Result of a successful minimum cost flow computation.
  """
  @type min_cost_flow_result :: %{
          cost: integer(),
          flow: flow_map()
        }

  @typedoc """
  Errors that can occur during minimum cost flow optimization.

  - `:infeasible` - The demands cannot be satisfied given the edge capacities
  - `:unbalanced_demands` - The sum of all node demands does not equal 0
  - `:unbounded` - The network contains a negative-cost cycle with infinite capacity
  - `:timeout` - The algorithm did not converge within the allowed number of pivots
  """
  @type min_cost_flow_error :: :infeasible | :unbalanced_demands | :unbounded | :timeout

  @doc """
  Solves the minimum cost flow problem using the Network Simplex algorithm.

  Given a network with edge capacities and costs, and node demands/supplies,
  finds the flow assignment that satisfies all demands at minimum total cost.

  ## Parameters

  - `graph` - The flow network (directed graph with edge data representing capacities)
  - `get_demand` - Function `(node_data) -> demand` where negative = supply, positive = demand
  - `get_capacity` - Function `(edge_data) -> capacity`
  - `get_cost` - Function `(edge_data) -> cost_per_unit`

  Note: These functions take the node/edge **data** stored in the graph, not node IDs.

  ## Returns

  - `{:ok, result}` - Successful computation with `%{cost: integer(), flow: flow_map()}`
  - `{:error, :infeasible}` - Demands cannot be satisfied
  - `{:error, :unbalanced_demands}` - Total supply ≠ total demand
  - `{:error, :unbounded}` - Negative cycle with infinite capacity found
  - `{:error, :timeout}` - Maximum pivot limit exceeded

  ## Examples

  ```elixir
  graph = Yog.directed()
    |> Yog.add_node(1, {-20, nil})
    |> Yog.add_node(2, {10, nil})
    |> Yog.add_node(3, {10, nil})
    |> Yog.add_edges([
      {1, 2, {10, 3}},
      {1, 3, {15, 2}},
      {2, 3, {5, 1}}
    ])

  get_demand = fn {d, _} -> d end
  get_capacity = fn {c, _} -> c end
  get_cost = fn {_, c} -> c end

  {:ok, result} = Yog.Flow.NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost)
  ```
  """
  @spec min_cost_flow(
          Yog.graph(),
          (any() -> integer()),
          (any() -> integer()),
          (any() -> integer())
        ) :: {:ok, min_cost_flow_result()} | {:error, min_cost_flow_error()}
  def min_cost_flow(graph, get_demand, get_capacity, get_cost) do
    nodes = Model.all_nodes(graph)

    # Compute demands for all nodes
    demands =
      Map.new(nodes, fn node ->
        data = Model.node(graph, node)
        {node, get_demand.(data)}
      end)

    # Check if demands are balanced
    total_demand = Enum.sum(Map.values(demands))

    if total_demand != 0 do
      {:error, :unbalanced_demands}
    else
      # Handle trivial case: no flow needed
      total_supply = -Enum.sum(Enum.filter(Map.values(demands), &(&1 < 0)))

      if total_supply == 0 do
        {:ok, %{cost: 0, flow: []}}
      else
        # Build edge information
        edges =
          Enum.flat_map(nodes, fn from ->
            Model.successors(graph, from)
            |> Enum.map(fn {to, data} ->
              capacity = get_capacity.(data)
              cost = get_cost.(data)
              {from, to, capacity, cost}
            end)
          end)

        # Run Network Simplex algorithm
        solve_min_cost_flow(nodes, edges, demands)
      end
    end
  end

  defp solve_min_cost_flow(nodes, edges, demands) do
    # Map nodes to integer indices
    node_to_idx = Map.new(Enum.with_index(nodes))
    idx_to_node = Map.new(Enum.map(node_to_idx, fn {k, v} -> {v, k} end))
    n = length(nodes)

    node_demands =
      Map.new(0..(n - 1), fn idx ->
        node = Map.fetch!(idx_to_node, idx)
        {idx, Map.fetch!(demands, node)}
      end)

    # Separate zero-capacity edges (they can never carry flow).
    {valid_edges, _zero_cap_edges} =
      Enum.split_with(edges, fn {_from, _to, capacity, _cost} ->
        capacity != 0
      end)

    # Check for unboundedness in self loops. A self loop with negative cost and
    # effectively infinite capacity can absorb an unbounded amount of flow.
    is_unbounded_self_loop =
      Enum.any?(edges, fn {from, to, capacity, cost} ->
        from == to and capacity >= @infinity_threshold and cost < 0
      end)

    if is_unbounded_self_loop do
      {:error, :unbounded}
    else
      # Build indexing maps for valid edges
      indexed_edges = Enum.with_index(valid_edges)
      m = length(valid_edges)

      edge_sources =
        Map.new(indexed_edges, fn {{from, _to, _cap, _cost}, idx} ->
          {idx, Map.fetch!(node_to_idx, from)}
        end)

      edge_targets =
        Map.new(indexed_edges, fn {{_from, to, _cap, _cost}, idx} ->
          {idx, Map.fetch!(node_to_idx, to)}
        end)

      edge_capacities =
        Map.new(indexed_edges, fn {{_from, _to, cap, _cost}, idx} ->
          {idx, cap}
        end)

      edge_costs =
        Map.new(indexed_edges, fn {{_from, _to, _cap, cost}, idx} ->
          {idx, cost}
        end)

      # Calculate faux_inf
      sum_caps =
        edge_capacities
        |> Map.values()
        |> Enum.filter(&(&1 < @infinity_threshold))
        |> Enum.sum()

      sum_costs =
        edge_costs
        |> Map.values()
        |> Enum.map(&abs/1)
        |> Enum.sum()

      sum_demands =
        node_demands
        |> Map.values()
        |> Enum.map(&abs/1)
        |> Enum.sum()

      faux_inf = 3 * Enum.max([sum_caps, sum_costs, sum_demands])
      faux_inf = if faux_inf == 0, do: 1, else: faux_inf

      # Append artificial edges (indices m to m + n - 1)
      # Root node is index n
      {edge_sources, edge_targets, edge_capacities, edge_costs, flows} =
        Enum.reduce(
          0..(n - 1),
          {edge_sources, edge_targets, edge_capacities, edge_costs, %{}},
          fn i, {srcs, tgts, caps, csts, fls} ->
            d = Map.fetch!(node_demands, i)
            art_idx = m + i
            {src, tgt} = if d > 0, do: {n, i}, else: {i, n}

            srcs = Map.put(srcs, art_idx, src)
            tgts = Map.put(tgts, art_idx, tgt)
            caps = Map.put(caps, art_idx, faux_inf)
            csts = Map.put(csts, art_idx, faux_inf)
            fls = Map.put(fls, art_idx, abs(d))

            {srcs, tgts, caps, csts, fls}
          end
        )

      # Initialize flow on original edges to 0
      flows =
        if m > 0 do
          Enum.reduce(0..(m - 1), flows, fn idx, fls -> Map.put(fls, idx, 0) end)
        else
          flows
        end

      # Initialize spanning tree attributes
      node_potentials =
        Enum.reduce(0..(n - 1), %{n => 0}, fn i, pots ->
          d = Map.fetch!(node_demands, i)
          val = if d <= 0, do: faux_inf, else: -faux_inf
          Map.put(pots, i, val)
        end)

      parents =
        Enum.reduce(0..(n - 1), %{n => nil}, fn i, pars ->
          Map.put(pars, i, n)
        end)

      parent_edges =
        Enum.reduce(0..(n - 1), %{n => nil}, fn i, pe ->
          Map.put(pe, i, m + i)
        end)

      sizes =
        Enum.reduce(0..(n - 1), %{n => n + 1}, fn i, szs ->
          Map.put(szs, i, 1)
        end)

      nexts =
        if n == 1 do
          %{0 => 1, 1 => 0}
        else
          nxts = Map.new(0..(n - 2), fn i -> {i, i + 1} end)
          nxts |> Map.put(n - 1, n) |> Map.put(n, 0)
        end

      prevs =
        if n == 1 do
          %{0 => 1, 1 => 0}
        else
          prvs = Map.new(1..(n - 1), fn i -> {i, i - 1} end)
          prvs |> Map.put(0, n) |> Map.put(n, n - 1)
        end

      lasts =
        Enum.reduce(0..(n - 1), %{n => n - 1}, fn i, lsts ->
          Map.put(lsts, i, i)
        end)

      # Internal state is map-based. See moduledoc "Implementation Notes" for
      # discussion of potential `:array` optimizations.
      state = %{
        node_count: n,
        edge_count: m,
        node_demands: node_demands,
        edge_sources: edge_sources,
        edge_targets: edge_targets,
        edge_capacities: edge_capacities,
        edge_costs: edge_costs,
        flows: flows,
        node_potentials: node_potentials,
        parents: parents,
        parent_edges: parent_edges,
        sizes: sizes,
        nexts: nexts,
        prevs: prevs,
        lasts: lasts,
        blockmark: 0
      }

      limit = max(5000, 100 * m)

      case pivot_loop(state, 0, limit) do
        {:error, :timeout} ->
          {:error, :timeout}

        {:ok, final_state} ->
          reconstruct_result(final_state, m, n, faux_inf, idx_to_node)
      end
    end
  end

  defp reconstruct_result(final_state, m, n, faux_inf, idx_to_node) do
    # Check for infeasibility: non-zero flow on any artificial edge
    has_artificial_flow =
      Enum.any?(m..(m + n - 1), fn idx ->
        Map.fetch!(final_state.flows, idx) != 0
      end)

    # Check for unboundedness: flow on any original edge exceeds half of faux_inf.
    # See moduledoc "Implementation Notes" for the 2x buffer discussion.
    has_unbounded_flow =
      if m > 0 do
        Enum.any?(0..(m - 1), fn idx ->
          Map.fetch!(final_state.flows, idx) * 2 >= faux_inf
        end)
      else
        false
      end

    cond do
      has_artificial_flow ->
        {:error, :infeasible}

      has_unbounded_flow ->
        {:error, :unbounded}

      true ->
        # Reconstruct final flows and total cost
        {flow_list, total_cost} =
          if m > 0 do
            Enum.reduce(0..(m - 1), {[], 0}, fn idx, {f_acc, cost_acc} ->
              flow = Map.fetch!(final_state.flows, idx)

              if flow > 0 do
                from_idx = Map.fetch!(final_state.edge_sources, idx)
                to_idx = Map.fetch!(final_state.edge_targets, idx)
                from_node = Map.fetch!(idx_to_node, from_idx)
                to_node = Map.fetch!(idx_to_node, to_idx)

                cost = Map.fetch!(final_state.edge_costs, idx)
                {[{from_node, to_node, flow} | f_acc], cost_acc + flow * cost}
              else
                {f_acc, cost_acc}
              end
            end)
          else
            {[], 0}
          end

        {:ok, %{cost: total_cost, flow: Enum.reverse(flow_list)}}
    end
  end

  defp pivot_loop(state, count, limit) do
    if count >= limit do
      {:error, :timeout}
    else
      case find_entering_edge(state) do
        :optimal ->
          {:ok, state}

        {:ok, i, p, q, state} ->
          {wn, we} = find_cycle(state, i, p, q)
          {j, s, t} = find_leaving_edge(state, wn, we)
          flow_delta = residual_capacity(state, j, s)
          state = augment_flow(state, wn, we, flow_delta)

          state =
            if i != j do
              # Ensure s is parent of t
              {s, t} =
                if Map.fetch!(state.parents, t) != s do
                  {t, s}
                else
                  {s, t}
                end

              # Ensure q is in the subtree rooted at t.
              # These scans are O(cycle length); see moduledoc notes.
              i_idx = Enum.find_index(we, &(&1 == i))
              j_idx = Enum.find_index(we, &(&1 == j))

              {p, q} =
                if i_idx > j_idx do
                  {q, p}
                else
                  {p, q}
                end

              state
              |> remove_edge(s, t)
              |> make_root(q)
              |> add_edge(i, p, q)
              |> update_potentials(i, p, q)
            else
              state
            end

          pivot_loop(state, count + 1, limit)
      end
    end
  end

  defp find_entering_edge(state) do
    edge_count = state.edge_count

    if edge_count == 0 do
      :optimal
    else
      b = :math.sqrt(edge_count) |> Float.ceil() |> round()
      m_blocks = div(edge_count + b - 1, b)

      search_entering_edge(state, 0, m_blocks, b, state.blockmark)
    end
  end

  defp search_entering_edge(_state, m, m_blocks, _b, _f) when m >= m_blocks do
    :optimal
  end

  defp search_entering_edge(state, m, m_blocks, b, f) do
    edge_count = state.edge_count
    l = f + b

    edges =
      if l <= edge_count do
        Enum.to_list(f..(l - 1))
      else
        l_wrap = l - edge_count
        Enum.to_list(f..(edge_count - 1)) ++ Enum.to_list(0..(l_wrap - 1))
      end

    next_f = rem(l, edge_count)

    best_edge = Enum.min_by(edges, fn i -> reduced_cost(state, i) end)
    best_cost = reduced_cost(state, best_edge)

    if best_cost >= 0 do
      search_entering_edge(state, m + 1, m_blocks, b, next_f)
    else
      flow = Map.fetch!(state.flows, best_edge)

      {p, q} =
        if flow == 0 do
          {Map.fetch!(state.edge_sources, best_edge), Map.fetch!(state.edge_targets, best_edge)}
        else
          {Map.fetch!(state.edge_targets, best_edge), Map.fetch!(state.edge_sources, best_edge)}
        end

      {:ok, best_edge, p, q, %{state | blockmark: next_f}}
    end
  end

  defp reduced_cost(state, i) do
    w = Map.fetch!(state.edge_costs, i)
    source = Map.fetch!(state.edge_sources, i)
    target = Map.fetch!(state.edge_targets, i)
    s_pot = Map.fetch!(state.node_potentials, source)
    t_pot = Map.fetch!(state.node_potentials, target)
    c = w - s_pot + t_pot
    flow = Map.fetch!(state.flows, i)
    if flow == 0, do: c, else: -c
  end

  defp find_cycle(state, i, p, q) do
    w = find_apex(state, p, q)
    {wn, we} = trace_path(state, p, w)
    wn_rev = Enum.reverse(wn)

    we_rev =
      if we != [i] do
        Enum.reverse([i | we])
      else
        Enum.reverse(we)
      end

    {wn_r, we_r} = trace_path(state, q, w)
    wn_r_len = length(wn_r)
    wn_r_init = if wn_r_len > 0, do: Enum.take(wn_r, wn_r_len - 1), else: []
    {wn_rev ++ wn_r_init, we_rev ++ we_r}
  end

  defp find_apex(state, p, q) do
    size_p = Map.fetch!(state.sizes, p)
    size_q = Map.fetch!(state.sizes, q)
    do_find_apex(state, p, size_p, q, size_q)
  end

  defp do_find_apex(state, p, size_p, q, size_q) do
    cond do
      size_p < size_q ->
        parent_p = Map.fetch!(state.parents, p)
        do_find_apex(state, parent_p, Map.fetch!(state.sizes, parent_p), q, size_q)

      size_p > size_q ->
        parent_q = Map.fetch!(state.parents, q)
        do_find_apex(state, p, size_p, parent_q, Map.fetch!(state.sizes, parent_q))

      true ->
        if p != q do
          parent_p = Map.fetch!(state.parents, p)
          parent_q = Map.fetch!(state.parents, q)

          do_find_apex(
            state,
            parent_p,
            Map.fetch!(state.sizes, parent_p),
            parent_q,
            Map.fetch!(state.sizes, parent_q)
          )
        else
          p
        end
    end
  end

  defp trace_path(state, p, w) do
    do_trace_path(state, p, w, [], [])
  end

  defp do_trace_path(_state, p, w, nodes, edges) when p == w do
    {Enum.reverse([p | nodes]), Enum.reverse(edges)}
  end

  defp do_trace_path(state, p, w, nodes, edges) do
    edge = Map.fetch!(state.parent_edges, p)
    parent = Map.fetch!(state.parents, p)
    do_trace_path(state, parent, w, [p | nodes], [edge | edges])
  end

  defp find_leaving_edge(state, wn, we) do
    pairs = Enum.zip(Enum.reverse(we), Enum.reverse(wn))
    {j, s} = Enum.min_by(pairs, fn {i_idx, p_idx} -> residual_capacity(state, i_idx, p_idx) end)

    source = Map.fetch!(state.edge_sources, j)
    t = if source == s, do: Map.fetch!(state.edge_targets, j), else: source
    {j, s, t}
  end

  defp residual_capacity(state, i, p) do
    cap = Map.fetch!(state.edge_capacities, i)
    flow = Map.fetch!(state.flows, i)
    source = Map.fetch!(state.edge_sources, i)
    if source == p, do: cap - flow, else: flow
  end

  defp augment_flow(state, wn, we, f) do
    new_flows =
      Enum.zip(we, wn)
      |> Enum.reduce(state.flows, fn {i, p}, flows_acc ->
        source = Map.fetch!(state.edge_sources, i)
        current_flow = Map.fetch!(flows_acc, i)
        new_flow = if source == p, do: current_flow + f, else: current_flow - f
        Map.put(flows_acc, i, new_flow)
      end)

    %{state | flows: new_flows}
  end

  defp remove_edge(state, s, t) do
    size_t = Map.fetch!(state.sizes, t)
    prev_t = Map.fetch!(state.prevs, t)
    last_t = Map.fetch!(state.lasts, t)
    next_last_t = Map.fetch!(state.nexts, last_t)

    parents = Map.put(state.parents, t, nil)
    parent_edges = Map.put(state.parent_edges, t, nil)

    nexts =
      state.nexts
      |> Map.put(prev_t, next_last_t)
      |> Map.put(last_t, t)

    prevs =
      state.prevs
      |> Map.put(next_last_t, prev_t)
      |> Map.put(t, last_t)

    state = %{
      state
      | parents: parents,
        parent_edges: parent_edges,
        nexts: nexts,
        prevs: prevs
    }

    update_ancestors_remove(state, s, size_t, last_t, prev_t)
  end

  defp update_ancestors_remove(state, nil, _size_t, _last_t, _prev_t) do
    state
  end

  defp update_ancestors_remove(state, s, size_t, last_t, prev_t) do
    sizes = Map.update!(state.sizes, s, &(&1 - size_t))

    lasts =
      if Map.fetch!(state.lasts, s) == last_t do
        Map.put(state.lasts, s, prev_t)
      else
        state.lasts
      end

    parent = Map.fetch!(state.parents, s)

    update_ancestors_remove(
      %{state | sizes: sizes, lasts: lasts},
      parent,
      size_t,
      last_t,
      prev_t
    )
  end

  defp make_root(state, q) do
    ancestors = get_ancestors(state, q, [])
    do_make_root_loop(state, ancestors)
  end

  defp get_ancestors(_state, nil, acc), do: acc

  defp get_ancestors(state, curr, acc) do
    parent = Map.fetch!(state.parents, curr)
    get_ancestors(state, parent, [curr | acc])
  end

  defp do_make_root_loop(state, [_single_node]) do
    state
  end

  defp do_make_root_loop(state, [p, q | rest]) do
    size_p = Map.fetch!(state.sizes, p)
    last_p_init = Map.fetch!(state.lasts, p)
    prev_q = Map.fetch!(state.prevs, q)
    last_q = Map.fetch!(state.lasts, q)
    next_last_q = Map.fetch!(state.nexts, last_q)

    parents =
      state.parents
      |> Map.put(p, q)
      |> Map.put(q, nil)

    parent_edges =
      state.parent_edges
      |> Map.put(p, Map.fetch!(state.parent_edges, q))
      |> Map.put(q, nil)

    size_q_val = Map.fetch!(state.sizes, q)

    sizes =
      state.sizes
      |> Map.put(p, size_p - size_q_val)
      |> Map.put(q, size_p)

    nexts_temp =
      state.nexts
      |> Map.put(prev_q, next_last_q)
      |> Map.put(last_q, q)

    prevs_temp =
      state.prevs
      |> Map.put(next_last_q, prev_q)
      |> Map.put(q, last_q)

    {lasts_temp, last_p_val} =
      if last_p_init == last_q do
        {Map.put(state.lasts, p, prev_q), prev_q}
      else
        {state.lasts, last_p_init}
      end

    prevs_updated =
      prevs_temp
      |> Map.put(p, last_q)
      |> Map.put(q, last_p_val)

    nexts_updated =
      nexts_temp
      |> Map.put(last_q, p)
      |> Map.put(last_p_val, q)

    lasts_updated = Map.put(lasts_temp, q, last_p_val)

    state = %{
      state
      | parents: parents,
        parent_edges: parent_edges,
        sizes: sizes,
        nexts: nexts_updated,
        prevs: prevs_updated,
        lasts: lasts_updated
    }

    do_make_root_loop(state, [q | rest])
  end

  defp add_edge(state, i, p, q) do
    last_p = Map.fetch!(state.lasts, p)
    next_last_p = Map.fetch!(state.nexts, last_p)
    size_q = Map.fetch!(state.sizes, q)
    last_q = Map.fetch!(state.lasts, q)

    parents = Map.put(state.parents, q, p)
    parent_edges = Map.put(state.parent_edges, q, i)

    nexts =
      state.nexts
      |> Map.put(last_p, q)
      |> Map.put(last_q, next_last_p)

    prevs =
      state.prevs
      |> Map.put(q, last_p)
      |> Map.put(next_last_p, last_q)

    state = %{
      state
      | parents: parents,
        parent_edges: parent_edges,
        nexts: nexts,
        prevs: prevs
    }

    update_ancestors_add(state, p, size_q, last_p, last_q)
  end

  defp update_ancestors_add(state, nil, _size_q, _last_p, _last_q) do
    state
  end

  defp update_ancestors_add(state, p, size_q, last_p, last_q) do
    sizes = Map.update!(state.sizes, p, &(&1 + size_q))

    lasts =
      if Map.fetch!(state.lasts, p) == last_p do
        Map.put(state.lasts, p, last_q)
      else
        state.lasts
      end

    parent = Map.fetch!(state.parents, p)

    update_ancestors_add(
      %{state | sizes: sizes, lasts: lasts},
      parent,
      size_q,
      last_p,
      last_q
    )
  end

  defp update_potentials(state, i, p, q) do
    q_pot = Map.fetch!(state.node_potentials, q)
    p_pot = Map.fetch!(state.node_potentials, p)
    weight = Map.fetch!(state.edge_costs, i)

    target = Map.fetch!(state.edge_targets, i)

    d =
      if q == target do
        p_pot - weight - q_pot
      else
        p_pot + weight - q_pot
      end

    subtree_nodes = trace_subtree(state, q)

    node_potentials =
      Enum.reduce(subtree_nodes, state.node_potentials, fn node, pots ->
        Map.update!(pots, node, &(&1 + d))
      end)

    %{state | node_potentials: node_potentials}
  end

  defp trace_subtree(state, p) do
    limit = Map.fetch!(state.lasts, p)
    do_trace_subtree(state, p, limit, [p])
  end

  defp do_trace_subtree(_state, p, limit, acc) when p == limit do
    Enum.reverse(acc)
  end

  defp do_trace_subtree(state, p, limit, acc) do
    nxt = Map.fetch!(state.nexts, p)
    do_trace_subtree(state, nxt, limit, [nxt | acc])
  end
end
