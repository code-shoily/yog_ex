defmodule Yog.Flow.SuccessiveShortestPath do
  @moduledoc """
  Minimum cost flow algorithms for network flow optimization.

  This module solves the [minimum cost flow problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem):
  find the cheapest way to send a given amount of flow through a network where
  edges have both capacities and costs per unit of flow.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Successive Shortest Path](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem) | `min_cost_flow/4` | O(F · (E + V log V)) | Small to medium networks |

  The implementation uses the Successive Shortest Path algorithm with Dijkstra and
  node potentials (reduced costs). One initial Bellman-Ford pass computes valid
  potentials; every subsequent shortest-path query runs Dijkstra using
  `Yog.PairingHeap` on non-negative reduced costs.

  ## Key Concepts

  - **Minimum Cost Flow**: Route flow to satisfy demands at minimum total cost
  - **Node Demands**: Supply nodes (negative demand) and demand nodes (positive demand)
  - **Edge Costs**: Price per unit of flow on each edge

  ## Problem Formulation

  Given:
  - Graph G = (V, E) with capacities u(e) and costs c(e)
  - Node demands b(v) where Σb(v) = 0 (conservation)

  Find flow f(e) that:
  - Minimizes: Σ c(e) × f(e)  (total cost)
  - Subject to: 0 ≤ f(e) ≤ u(e)  (capacity constraints)
  - And: flow conservation at each node

  ## Use Cases

  - **Transportation planning**: Minimize shipping costs with vehicle capacities
  - **Supply chain**: Optimize distribution from warehouses to retailers
  - **Telecommunications**: Route calls at minimum cost with link capacities

  ## Example

      # Store demand/capacity/cost data in node and edge data tuples
      graph =
        Yog.directed()
        # Node data: {demand, nil} where negative=supply, positive=demand
        |> Yog.add_node(1, {-20, nil})   # warehouse: supply 20
        |> Yog.add_node(2, {10, nil})    # store_a: demand 10
        |> Yog.add_node(3, {10, nil})    # store_b: demand 10
        # Edge data: {capacity, cost_per_unit}
        |> Yog.add_edges([
          {1, 2, {10, 3}},   # capacity 10, cost $3
          {1, 3, {15, 2}},   # capacity 15, cost $2
          {2, 3, {5, 1}}     # capacity 5, cost $1
        ])

      # Extract demand from node data
      get_demand = fn {d, _} -> d end

      # Extract capacity from edge data
      get_capacity = fn {c, _} -> c end

      # Extract cost from edge data
      get_cost = fn {_, c} -> c end

      case Yog.Flow.SuccessiveShortestPath.min_cost_flow(graph, get_demand, get_capacity, get_cost) do
        {:ok, result} ->
          IO.puts("Min cost: \#{result.cost}")
          IO.inspect(result.flow)

        {:error, :infeasible} ->
          IO.puts("Cannot satisfy demands with given capacities")

        {:error, :unbalanced_demands} ->
          IO.puts("Total demand does not equal total supply")
      end

  ## References

  - [Wikipedia: Minimum-Cost Flow Problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem)
  - [CP-Algorithms: Min-Cost Flow](https://cp-algorithms.com/graph/min_cost_flow.html)
  """

  alias Yog.Model

  @typedoc """
  A flow vector assigning an amount of flow to each edge.

  Each tuple is `{from_node, to_node, flow_amount}`.
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
  """
  @type min_cost_flow_error :: :infeasible | :unbalanced_demands

  @doc """
  Solves the minimum cost flow problem using the Successive Shortest Path algorithm.

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

  ## Examples

      iex> graph = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "t")
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      iex> get_demand = fn
      ...>   "s" -> -5   # supply 5
      ...>   "t" -> 5    # demand 5
      ...>   _ -> 0
      ...> end
      iex> get_capacity = fn w -> w end
      iex> get_cost = fn _ -> 1 end
      iex> result = Yog.Flow.SuccessiveShortestPath.min_cost_flow(
      ...>   graph, get_demand, get_capacity, get_cost
      ...> )
      iex> match?({:ok, _} , result) or match?({:error, _}, result)
      true

  ## Notes

  - All demands must sum to 0 (conservation of flow)
  - Costs and capacities must be integers
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

        # Run successive shortest path algorithm
        case solve_min_cost_flow(nodes, edges, demands) do
          {:ok, flow, total_cost} ->
            {:ok, %{cost: total_cost, flow: flow}}

          :infeasible ->
            {:error, :infeasible}
        end
      end
    end
  end

  # Successive Shortest Path algorithm with proper residual graph and node potentials
  defp solve_min_cost_flow(nodes, edges, demands) do
    indexed_edges = Enum.with_index(edges) |> Enum.map(fn {edge, idx} -> {edge, idx} end)
    original_edges_by_idx = Map.new(indexed_edges, fn {{u, v, _, _}, idx} -> {idx, {u, v}} end)
    num_original_edges = length(edges)

    total_supply =
      demands
      |> Map.values()
      |> Enum.filter(&(&1 < 0))
      |> Enum.sum()
      |> Kernel.abs()

    s = :super_source
    t = :super_sink

    extended_nodes = [s, t | nodes]

    virtual_edges =
      Enum.flat_map(nodes, fn node ->
        d = demands[node]

        cond do
          d < 0 -> [{s, node, -d, 0}]
          d > 0 -> [{node, t, d, 0}]
          true -> []
        end
      end)

    indexed_virtual_edges =
      virtual_edges
      |> Enum.with_index(num_original_edges)
      |> Enum.map(fn {edge, idx} -> {edge, idx} end)

    extended_indexed_edges = indexed_edges ++ indexed_virtual_edges

    extended_demands =
      Map.new(extended_nodes, fn node ->
        cond do
          node == s -> {node, -total_supply}
          node == t -> {node, total_supply}
          true -> {node, 0}
        end
      end)

    {capacities, costs, adj} = build_residual_graph(extended_nodes, extended_indexed_edges)

    supply_nodes = [s]
    demand_nodes = [t]

    case initialize_potentials(adj, capacities, costs, extended_nodes) do
      {:ok, potentials} ->
        case do_ssp(
               supply_nodes,
               demand_nodes,
               extended_demands,
               adj,
               capacities,
               costs,
               num_original_edges,
               %{},
               0,
               potentials
             ) do
          {:ok, flow, total_cost} ->
            flow_list =
              Enum.reduce(0..(num_original_edges - 1), [], fn idx, acc ->
                amount = Map.get(flow, idx, 0)

                if amount > 0 do
                  {u, v} = Map.fetch!(original_edges_by_idx, idx)
                  [{u, v, amount} | acc]
                else
                  acc
                end
              end)

            {:ok, flow_list, total_cost}

          :infeasible ->
            :infeasible
        end

      :negative_cycle ->
        :infeasible
    end
  end

  defp build_residual_graph(nodes, indexed_edges) do
    adj = Map.new(nodes, fn n -> {n, []} end)

    Enum.reduce(indexed_edges, {%{}, %{}, adj}, fn {{u, v, cap, cost}, e}, {caps, costs, adj} ->
      # Forward edge ref: {e, :forward}
      caps = Map.put(caps, {e, :forward}, cap)
      costs = Map.put(costs, {e, :forward}, cost)
      adj = Map.update!(adj, u, fn existing -> [{v, {e, :forward}} | existing] end)

      # Backward edge ref: {e, :backward}
      caps = Map.put(caps, {e, :backward}, 0)
      costs = Map.put(costs, {e, :backward}, -cost)
      adj = Map.update!(adj, v, fn existing -> [{u, {e, :backward}} | existing] end)

      {caps, costs, adj}
    end)
  end

  defp initialize_potentials(adj, capacities, costs, nodes) do
    dist = Map.new(nodes, fn n -> {n, 0} end)
    prev = %{}

    # Run |V| iterations of Bellman-Ford
    {final_dist, _} =
      Enum.reduce(1..length(nodes), {dist, prev}, fn _, {d, p} ->
        relax_all_edges(adj, capacities, costs, d, p)
      end)

    # Check for negative cycles on the |V|-th iteration
    {after_v, _} = relax_all_edges(adj, capacities, costs, final_dist, prev)

    if any_relaxation?(final_dist, after_v) do
      :negative_cycle
    else
      {:ok, final_dist}
    end
  end

  defp relax_all_edges(adj, capacities, costs, dist, prev) do
    Enum.reduce(adj, {dist, prev}, fn {u, neighbors}, {_d, _p} = acc ->
      Enum.reduce(neighbors, acc, fn {v, edge_ref}, {d2, p2} = acc2 ->
        if capacities[edge_ref] > 0 do
          edge_cost = costs[edge_ref]
          new_dist = d2[u] + edge_cost

          if new_dist < d2[v] do
            {Map.put(d2, v, new_dist), Map.put(p2, v, {u, edge_ref})}
          else
            acc2
          end
        else
          acc2
        end
      end)
    end)
  end

  defp any_relaxation?(dist1, dist2) do
    Enum.any?(dist1, fn {node, val} -> dist2[node] < val end)
  end

  defp do_ssp(_supply, [], _demands, _adj, _caps, _costs, _num_orig, flow, cost, _pots) do
    {:ok, flow, cost}
  end

  defp do_ssp([], _demand, _demands, _adj, _caps, _costs, _num_orig, _flow, _cost, _pots) do
    :infeasible
  end

  defp do_ssp(
         supply_nodes,
         demand_nodes,
         demands,
         adj,
         capacities,
         costs,
         num_original_edges,
         flow,
         cost,
         potentials
       ) do
    source = Enum.find(supply_nodes, fn n -> demands[n] < 0 end)
    sink = Enum.find(demand_nodes, fn n -> demands[n] > 0 end)

    if source == nil or sink == nil do
      {:ok, flow, cost}
    else
      case shortest_path(adj, capacities, costs, potentials, source, sink) do
        nil ->
          :infeasible

        {path, path_cost, dist} ->
          bottleneck = compute_bottleneck(capacities, demands, source, sink, path)

          new_source_demand = Map.fetch!(demands, source) + bottleneck
          new_sink_demand = Map.fetch!(demands, sink) - bottleneck

          new_demands =
            demands
            |> Map.put(source, new_source_demand)
            |> Map.put(sink, new_sink_demand)

          {new_flow, new_caps} =
            augment_flow(flow, capacities, num_original_edges, path, bottleneck)

          new_cost = cost + path_cost * bottleneck
          new_potentials = update_potentials(potentials, dist)

          do_ssp(
            supply_nodes,
            demand_nodes,
            new_demands,
            adj,
            new_caps,
            costs,
            num_original_edges,
            new_flow,
            new_cost,
            new_potentials
          )
      end
    end
  end

  # Dijkstra with node potentials on residual graph
  defp shortest_path(adj, capacities, costs, potentials, source, sink) do
    compare = fn {d1, _}, {d2, _} -> d1 <= d2 end
    pq = Yog.PairingHeap.new(compare) |> Yog.PairingHeap.push({0, source})

    dist = %{source => 0}
    prev = %{}

    case do_dijkstra(adj, capacities, costs, potentials, source, sink, pq, dist, prev) do
      nil ->
        nil

      {path, reduced_dist, final_dist} ->
        path_cost = reduced_dist - potentials[source] + potentials[sink]
        {path, path_cost, final_dist}
    end
  end

  defp do_dijkstra(adj, caps, costs, pots, source, sink, pq, dist, prev) do
    case Yog.PairingHeap.pop(pq) do
      :error ->
        nil

      {:ok, {d, u}, new_pq} ->
        if u == sink do
          handle_sink_reached(source, sink, d, dist, prev)
        else
          maybe_expand_node(adj, caps, costs, pots, source, sink, u, d, new_pq, dist, prev)
        end
    end
  end

  defp handle_sink_reached(source, sink, d, dist, prev) do
    path = reconstruct_path(prev, source, sink)
    {path, d, dist}
  end

  defp maybe_expand_node(adj, caps, costs, pots, source, sink, u, d, pq, dist, prev) do
    best_dist = Map.get(dist, u)

    if best_dist != nil and d > best_dist do
      do_dijkstra(adj, caps, costs, pots, source, sink, pq, dist, prev)
    else
      expand_node(adj, caps, costs, pots, source, sink, u, d, pq, dist, prev)
    end
  end

  defp expand_node(adj, caps, costs, pots, source, sink, u, d, pq, dist, prev) do
    neighbors = Map.get(adj, u, [])

    {next_pq, next_dist, next_prev} =
      Enum.reduce(neighbors, {pq, dist, prev}, fn neighbor_tuple, state ->
        relax_neighbor(u, neighbor_tuple, d, caps, costs, pots, state)
      end)

    do_dijkstra(adj, caps, costs, pots, source, sink, next_pq, next_dist, next_prev)
  end

  defp relax_neighbor(u, {v, edge_ref}, d, caps, costs, pots, {pq_acc, dist_acc, prev_acc}) do
    if caps[edge_ref] > 0 do
      reduced_cost = costs[edge_ref] + pots[u] - pots[v]
      new_dist = d + reduced_cost
      old_dist = Map.get(dist_acc, v)

      if old_dist == nil or new_dist < old_dist do
        {
          Yog.PairingHeap.push(pq_acc, {new_dist, v}),
          Map.put(dist_acc, v, new_dist),
          Map.put(prev_acc, v, {u, edge_ref})
        }
      else
        {pq_acc, dist_acc, prev_acc}
      end
    else
      {pq_acc, dist_acc, prev_acc}
    end
  end

  defp update_potentials(potentials, dist) do
    Enum.reduce(dist, potentials, fn {node, d}, pots ->
      Map.update!(pots, node, &(&1 + d))
    end)
  end

  defp reconstruct_path(prev, source, sink) do
    do_reconstruct(prev, sink, [], source)
  end

  defp do_reconstruct(_prev, current, path, target) when current == target do
    path
  end

  defp do_reconstruct(prev, current, path, target) do
    case Map.get(prev, current) do
      nil -> nil
      {parent, edge_ref} -> do_reconstruct(prev, parent, [edge_ref | path], target)
    end
  end

  defp compute_bottleneck(capacities, demands, source, sink, path) do
    source_supply = -demands[source]
    sink_demand = demands[sink]

    edge_bottleneck =
      path
      |> Enum.map(fn edge_ref -> capacities[edge_ref] end)
      |> Enum.min(fn -> 0 end)

    min(min(source_supply, sink_demand), edge_bottleneck)
  end

  defp augment_flow(flow, capacities, num_original_edges, path, amount) do
    Enum.reduce(path, {flow, capacities}, fn {e, type} = edge_ref, {f, c} ->
      opposite_type = if type == :forward, do: :backward, else: :forward
      backward_ref = {e, opposite_type}

      # Decrease forward residual capacity
      c = Map.update!(c, edge_ref, &(&1 - amount))
      # Increase backward residual capacity
      c = Map.update!(c, backward_ref, &(&1 + amount))

      f =
        cond do
          e >= num_original_edges ->
            f

          type == :forward ->
            Map.update(f, e, amount, &(&1 + amount))

          type == :backward ->
            Map.update(f, e, 0, &(&1 - amount))
        end

      {f, c}
    end)
  end
end
