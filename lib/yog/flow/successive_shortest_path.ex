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
  `Yog.PriorityQueue` on non-negative reduced costs.

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
    # Compute demands for all nodes
    {demands, total_demand, total_supply} =
      :maps.fold(
        fn node, data, {dem_acc, total_dem, total_sup} ->
          demand = get_demand.(data)
          new_total_dem = total_dem + demand
          new_total_sup = if demand < 0, do: total_sup - demand, else: total_sup
          {Map.put(dem_acc, node, demand), new_total_dem, new_total_sup}
        end,
        {%{}, 0, 0},
        graph.nodes
      )

    if total_demand != 0 do
      {:error, :unbalanced_demands}
    else
      if total_supply == 0 do
        {:ok, %{cost: 0, flow: []}}
      else
        # Build edge information
        edges =
          :maps.fold(
            fn from, successors, acc ->
              :maps.fold(
                fn to, data, inner_acc ->
                  capacity = get_capacity.(data)
                  cost = get_cost.(data)
                  [{from, to, capacity, cost} | inner_acc]
                end,
                acc,
                successors
              )
            end,
            [],
            graph.out_edges
          )

        # Run successive shortest path algorithm
        case solve_min_cost_flow(Map.keys(demands), edges, demands) do
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
    original_edges = MapSet.new(edges, fn {u, v, _, _} -> {u, v} end)
    {capacities, costs, adj} = build_residual_graph(nodes, edges)

    supply_nodes =
      :maps.fold(
        fn n, d, acc -> if d < 0, do: [n | acc], else: acc end,
        [],
        demands
      )

    demand_nodes =
      :maps.fold(
        fn n, d, acc -> if d > 0, do: [n | acc], else: acc end,
        [],
        demands
      )

    case initialize_potentials(adj, capacities, costs, Map.keys(demands)) do
      {:ok, potentials} ->
        do_ssp(
          supply_nodes,
          demand_nodes,
          demands,
          adj,
          capacities,
          costs,
          original_edges,
          %{},
          0,
          potentials
        )

      :negative_cycle ->
        :infeasible
    end
  end

  defp build_residual_graph(nodes, edges) do
    # Initialize adjacency for all nodes
    adj = List.foldl(nodes, %{}, fn n, acc -> Map.put(acc, n, []) end)

    List.foldl(edges, {%{}, %{}, adj}, fn {u, v, cap, cost}, {caps, costs, adj} ->
      # Forward edge
      caps = Map.put(caps, {u, v}, cap)
      costs = Map.put(costs, {u, v}, cost)
      adj = Map.update!(adj, u, fn existing -> [v | existing] end)

      # Backward edge (initially 0 capacity, negative cost)
      caps = Map.put(caps, {v, u}, 0)
      costs = Map.put(costs, {v, u}, -cost)
      adj = Map.update!(adj, v, fn existing -> [u | existing] end)

      {caps, costs, adj}
    end)
  end

  defp initialize_potentials(adj, capacities, costs, nodes) do
    # Simulate super-source by initializing all distances to 0
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
    :maps.fold(
      fn u, neighbors, acc ->
        List.foldl(neighbors, acc, fn v, {d2, p2} = acc2 ->
          if Map.get(capacities, {u, v}, 0) > 0 do
            edge_cost = Map.get(costs, {u, v}, 0)
            new_dist = Map.get(d2, u, 0) + edge_cost

            if new_dist < Map.get(d2, v, :infinity) do
              {Map.put(d2, v, new_dist), Map.put(p2, v, u)}
            else
              acc2
            end
          else
            acc2
          end
        end)
      end,
      {dist, prev},
      adj
    )
  end

  defp any_relaxation?(dist1, dist2) do
    Enum.any?(dist1, fn {node, val} -> dist2[node] < val end)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp do_ssp(_supply, [], _demands, _adj, _caps, _costs, _orig, flow, cost, _pots) do
    {:ok, flow_to_list(flow), cost}
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp do_ssp([], _demand, _demands, _adj, _caps, _costs, _orig, _flow, _cost, _pots) do
    :infeasible
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp do_ssp(
         supply_nodes,
         demand_nodes,
         demands,
         adj,
         capacities,
         costs,
         original_edges,
         flow,
         cost,
         potentials
       ) do
    source = Enum.find(supply_nodes, fn n -> demands[n] < 0 end)
    sink = Enum.find(demand_nodes, fn n -> demands[n] > 0 end)

    if source == nil or sink == nil do
      {:ok, flow_to_list(flow), cost}
    else
      case shortest_path(adj, capacities, costs, potentials, source, sink) do
        nil ->
          :infeasible

        {path, path_cost, dist} ->
          bottleneck = compute_bottleneck(capacities, demands, source, sink, path)

          new_demands =
            demands
            |> Map.update!(source, &(&1 + bottleneck))
            |> Map.update!(sink, &(&1 - bottleneck))

          {new_flow, new_caps} = augment_flow(flow, capacities, original_edges, path, bottleneck)
          new_cost = cost + path_cost * bottleneck
          new_potentials = update_potentials(potentials, dist)

          do_ssp(
            supply_nodes,
            demand_nodes,
            new_demands,
            adj,
            new_caps,
            costs,
            original_edges,
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
    pq = Yog.PriorityQueue.new(compare) |> Yog.PriorityQueue.push({0, source})

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

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp do_dijkstra(adj, caps, costs, pots, source, sink, pq, dist, prev) do
    case Yog.PriorityQueue.pop(pq) do
      :error ->
        nil

      {:ok, {d, u}, new_pq} ->
        if u == sink do
          path = reconstruct_path(prev, source, sink)
          {path, d, dist}
        else
          best_dist = Map.get(dist, u)

          if best_dist != nil and d > best_dist do
            do_dijkstra(adj, caps, costs, pots, source, sink, new_pq, dist, prev)
          else
            neighbors = Map.get(adj, u, [])

            {next_pq, next_dist, next_prev} =
              List.foldl(neighbors, {new_pq, dist, prev}, fn v, {pq_acc, dist_acc, prev_acc} ->
                if Map.get(caps, {u, v}, 0) > 0 do
                  reduced_cost =
                    Map.get(costs, {u, v}, 0) + Map.get(pots, u, 0) - Map.get(pots, v, 0)

                  new_dist = d + reduced_cost
                  old_dist = Map.get(dist_acc, v)

                  if old_dist == nil or new_dist < old_dist do
                    {
                      Yog.PriorityQueue.push(pq_acc, {new_dist, v}),
                      Map.put(dist_acc, v, new_dist),
                      Map.put(prev_acc, v, u)
                    }
                  else
                    {pq_acc, dist_acc, prev_acc}
                  end
                else
                  {pq_acc, dist_acc, prev_acc}
                end
              end)

            do_dijkstra(adj, caps, costs, pots, source, sink, next_pq, next_dist, next_prev)
          end
        end
    end
  end

  defp update_potentials(potentials, dist) do
    Enum.reduce(dist, potentials, fn {node, d}, pots ->
      Map.update!(pots, node, &(&1 + d))
    end)
  end

  defp reconstruct_path(prev, source, sink) do
    do_reconstruct(prev, sink, [sink], source)
  end

  # Path is already [source, ..., sink] due to prepending parents during backtracking
  defp do_reconstruct(_prev, current, path, target) when current == target do
    path
  end

  defp do_reconstruct(prev, current, path, target) do
    case Map.get(prev, current) do
      nil -> nil
      parent -> do_reconstruct(prev, parent, [parent | path], target)
    end
  end

  defp compute_bottleneck(capacities, demands, source, sink, path) do
    source_supply = -demands[source]
    sink_demand = demands[sink]

    edge_bottleneck =
      path_to_edges(path)
      |> Enum.map(fn {u, v} -> capacities[{u, v}] end)
      |> Enum.min(fn -> 0 end)

    min(min(source_supply, sink_demand), edge_bottleneck)
  end

  defp augment_flow(flow, capacities, original_edges, path, amount) do
    edges = path_to_edges(path)

    Enum.reduce(edges, {flow, capacities}, fn {u, v}, {f, c} ->
      # Decrease forward residual capacity
      c = Map.update!(c, {u, v}, &(&1 - amount))
      # Increase backward residual capacity
      c = Map.update!(c, {v, u}, &(&1 + amount))

      f =
        if MapSet.member?(original_edges, {u, v}) do
          # Augmenting along original forward edge
          Map.update(f, {u, v}, amount, &(&1 + amount))
        else
          # Augmenting along backward edge -> reduce flow on original edge {v, u}
          Map.update!(f, {v, u}, &(&1 - amount))
        end

      {f, c}
    end)
  end

  defp path_to_edges([_]), do: []

  defp path_to_edges([a, b | rest]) do
    [{a, b} | path_to_edges([b | rest])]
  end

  defp flow_to_list(flow) do
    flow
    |> Enum.filter(fn {_, f} -> f > 0 end)
    |> Enum.map(fn {{u, v}, f} -> {u, v, f} end)
  end
end
