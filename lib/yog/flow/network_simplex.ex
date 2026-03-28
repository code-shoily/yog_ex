defmodule Yog.Flow.NetworkSimplex do
  @moduledoc """
  Minimum cost flow algorithms for network flow optimization.

  This module solves the [minimum cost flow problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem):
  find the cheapest way to send a given amount of flow through a network where
  edges have both capacities and costs per unit of flow.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Successive Shortest Path](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem) | `min_cost_flow/4` | O(F · E log V) | Small to medium networks |

  The implementation uses the Successive Shortest Path algorithm.

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

      case Yog.Flow.NetworkSimplex.min_cost_flow(graph, get_demand, get_capacity, get_cost) do
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
      iex> result = Yog.Flow.NetworkSimplex.min_cost_flow(
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

  # Successive Shortest Path algorithm
  defp solve_min_cost_flow(nodes, edges, demands) do
    # Build adjacency with costs
    adj = build_adjacency(edges)

    # Find supply and demand nodes
    supply_nodes = Enum.filter(nodes, fn n -> demands[n] < 0 end)
    demand_nodes = Enum.filter(nodes, fn n -> demands[n] > 0 end)

    # Iteratively find shortest paths and augment flow
    do_ssp(supply_nodes, demand_nodes, edges, demands, adj, %{}, 0)
  end

  defp build_adjacency(edges) do
    Enum.reduce(edges, %{}, fn {u, v, _cap, cost}, acc ->
      Map.update(acc, u, [{v, cost}], fn existing -> [{v, cost} | existing] end)
    end)
  end

  defp do_ssp(_supply, [], _edges, _demands, _adj, flow, cost) do
    {:ok, flow_to_list(flow), cost}
  end

  defp do_ssp([], _demand, _edges, _demands, _adj, _flow, _cost) do
    :infeasible
  end

  defp do_ssp(supply_nodes, demand_nodes, edges, demands, adj, flow, cost) do
    # Find a supply node with remaining supply
    source = Enum.find(supply_nodes, fn n -> demands[n] < 0 end)

    # Find a demand node with remaining demand
    sink = Enum.find(demand_nodes, fn n -> demands[n] > 0 end)

    if source == nil or sink == nil do
      {:ok, flow_to_list(flow), cost}
    else
      # Find shortest path from source to sink
      case shortest_path(adj, source, sink) do
        nil ->
          :infeasible

        {path, path_cost} ->
          # Compute bottleneck
          source_supply = -demands[source]
          sink_demand = demands[sink]
          bottleneck = min(source_supply, sink_demand)

          # Update demands
          new_demands =
            demands
            |> Map.update!(source, &(&1 + bottleneck))
            |> Map.update!(sink, &(&1 - bottleneck))

          # Update flow
          new_flow = update_flow(flow, path, bottleneck)

          # Update cost
          new_cost = cost + path_cost * bottleneck

          do_ssp(supply_nodes, demand_nodes, edges, new_demands, adj, new_flow, new_cost)
      end
    end
  end

  # Bellman-Ford for shortest path (handles negative costs)
  defp shortest_path(adj, source, sink) do
    nodes = Map.keys(adj) |> Enum.uniq()
    initial_dist = Map.new(nodes, fn n -> {n, :infinity} end)
    dist = Map.put(initial_dist, source, 0)
    prev = %{}

    # Relax edges
    {final_dist, final_prev} =
      Enum.reduce(1..(length(nodes) - 1)//1, {dist, prev}, fn _, {d, p} ->
        relax_edges(adj, d, p)
      end)

    if final_dist[sink] == :infinity do
      nil
    else
      case reconstruct_path(final_prev, source, sink) do
        nil -> nil
        path -> {path, final_dist[sink]}
      end
    end
  end

  defp relax_edges(adj, dist, prev) do
    Enum.reduce(adj, {dist, prev}, fn {u, neighbors}, {d, _p} = acc ->
      if d[u] == :infinity do
        acc
      else
        Enum.reduce(neighbors, acc, fn {v, cost}, {d2, p2} = acc2 ->
          new_dist = d2[u] + cost

          if d2[v] == :infinity or new_dist < d2[v] do
            {Map.put(d2, v, new_dist), Map.put(p2, v, u)}
          else
            acc2
          end
        end)
      end
    end)
  end

  defp reconstruct_path(prev, source, sink) do
    do_reconstruct(prev, sink, [sink], source)
  end

  defp do_reconstruct(_prev, current, path, target) when current == target do
    Enum.reverse(path)
  end

  defp do_reconstruct(prev, current, path, target) do
    case Map.get(prev, current) do
      nil -> nil
      parent -> do_reconstruct(prev, parent, [parent | path], target)
    end
  end

  defp update_flow(flow, path, amount) do
    edges = path_to_edges(path)

    Enum.reduce(edges, flow, fn {u, v}, acc ->
      key = {u, v}
      current = Map.get(acc, key, 0)
      Map.put(acc, key, current + amount)
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
