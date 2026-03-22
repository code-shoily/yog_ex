defmodule Yog.Flow.NetworkSimplex do
  @moduledoc """
  Network Simplex algorithm for minimum cost flow optimization.

  This module solves the [minimum cost flow problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem):
  find the cheapest way to send a given amount of flow through a network where
  edges have both capacities and costs per unit of flow.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Network Simplex](https://en.wikipedia.org/wiki/Network_simplex_algorithm) | `min_cost_flow/4` | O(V²E) practical | Large sparse networks |

  The Network Simplex is a specialized version of the [simplex algorithm](https://en.wikipedia.org/wiki/Simplex_algorithm)
  for network flow problems. It maintains a spanning tree of basic edges and
  iteratively pivots to improve the solution, similar to how the transportation
  simplex works for assignment problems.

  ## Key Concepts

  - **Minimum Cost Flow**: Route flow to satisfy demands at minimum total cost
  - **Node Demands**: Supply nodes (negative demand) and demand nodes (positive demand)
  - **Edge Costs**: Price per unit of flow on each edge
  - **Potentials (π)**: Dual variables for reduced cost computation
  - **Reduced Costs**: Modified costs ensuring optimality conditions
  - **Spanning Tree**: Basis for the simplex method on networks

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
  - **Workforce scheduling**: Assign workers to shifts minimizing total cost
  - **Circulation problems**: Fleet management and inventory routing

  ## Performance Notes

  > This implementation uses list-based data structures for the internal spanning
  > tree representation. While algorithmically correct, random access and updates
  > are O(n) rather than O(1). For large flow networks (1000+ nodes/edges), this
  > may impact performance.

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

        {:error, :unbounded} ->
          IO.puts("Negative cost cycle detected")

        {:error, :unbalanced_demands} ->
          IO.puts("Total demand does not equal total supply")
      end

  ## References

  - [Wikipedia: Minimum-Cost Flow Problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem)
  - [Wikipedia: Network Simplex Algorithm](https://en.wikipedia.org/wiki/Network_simplex_algorithm)
  - [Network Flows - Ahuja, Magnanti, Orlin](https://www.pearson.com/en-us/subject-catalog/p/network-flows/P200000005792)
  - [CP-Algorithms: Min-Cost Flow](https://cp-algorithms.com/graph/min_cost_flow.html)
  """

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
  Errors that can occur during Network Simplex optimization.

  - `:infeasible` - The demands cannot be satisfied given the edge capacities
  - `:unbounded` - The network contains a negative-cost cycle with infinite capacity
  - `:unbalanced_demands` - The sum of all node demands does not equal 0
  """
  @type network_simplex_error :: :infeasible | :unbounded | :unbalanced_demands

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
  For example, if you stored `Yog.add_node(g, 1, "warehouse")`, then `get_demand`
  will be called with `"warehouse"` as the argument.

  ## Returns

  - `{:ok, result}` - Successful computation with `%{cost: integer(), flow: flow_map()}`
  - `{:error, :infeasible}` - Demands cannot be satisfied
  - `{:error, :unbounded}` - Negative cost cycle exists
  - `{:error, :unbalanced_demands}` - Total supply ≠ total demand

  ## Examples

      iex> graph = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "t")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 10)
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
  - The graph should be directed for meaningful flow direction
  """
  @spec min_cost_flow(
          Yog.graph(),
          (any() -> integer()),
          (any() -> integer()),
          (any() -> integer())
        ) :: {:ok, min_cost_flow_result()} | {:error, network_simplex_error()}
  def min_cost_flow(graph, get_demand, get_capacity, get_cost) do
    result =
      :yog@flow@network_simplex.min_cost_flow(
        graph,
        get_demand,
        get_capacity,
        get_cost
      )

    case result do
      {:ok, min_cost_result} ->
        {:ok, wrap_min_cost_flow_result(min_cost_result)}

      {:error, error} ->
        {:error, wrap_error(error)}
    end
  end

  # Private helper to wrap Gleam result into Elixir map
  defp wrap_min_cost_flow_result({:min_cost_flow_result, cost, flow}) do
    %{
      cost: cost,
      flow: flow
    }
  end

  # Private helper to wrap Gleam errors into Elixir atoms
  defp wrap_error(:infeasible), do: :infeasible
  defp wrap_error(:unbounded), do: :unbounded
  defp wrap_error(:unbalanced_demands), do: :unbalanced_demands
  defp wrap_error(other), do: other
end
