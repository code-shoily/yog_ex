defmodule Yog.Property.Eulerian do
  @moduledoc """
  [Eulerian path](https://en.wikipedia.org/wiki/Eulerian_path) and circuit algorithms using
  [Hierholzer's algorithm](https://en.wikipedia.org/wiki/Eulerian_path#Hierholzer's_algorithm).

  An Eulerian path visits every edge exactly once.
  An Eulerian circuit visits every edge exactly once and returns to the start.
  These problems originated from the famous [Seven Bridges of Königsberg](https://en.wikipedia.org/wiki/Seven_Bridges_of_K%C3%B6nigsberg)
  solved by Leonhard Euler in 1736, founding graph theory.

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Eulerian circuit check | Degree counting | `has_eulerian_circuit?/1` | O(V + E) |
  | Eulerian path check | Degree counting | `has_eulerian_path?/1` | O(V + E) |
  | Find circuit | [Hierholzer's](https://en.wikipedia.org/wiki/Eulerian_path#Hierholzer's_algorithm) | `eulerian_circuit/1` | O(E) |
  | Find path | Hierholzer's | `eulerian_path/1` | O(E) |

  ## Key Concepts

  - **Eulerian Circuit**: Closed walk using every edge exactly once
  - **Eulerian Path**: Open walk using every edge exactly once
  - **Eulerian Graph**: Graph with an Eulerian circuit
  - **Semi-Eulerian Graph**: Graph with an Eulerian path but no circuit

  ## Necessary and Sufficient Conditions

  **Undirected Graphs:**
  - **Circuit**: All vertices have even degree, connected (ignoring isolates)
  - **Path**: Exactly 0 or 2 vertices have odd degree, connected

  **Directed Graphs:**
  - **Circuit**: In-degree = Out-degree for all vertices, weakly connected
  - **Path**: At most one vertex has (out - in) = 1 (start),
    at most one has (in - out) = 1 (end), all others balanced

  ## Hierholzer's Algorithm

  1. Start from any vertex (or odd-degree vertex for path)
  2. Follow unused edges until returning to start (forming a cycle)
  3. If unused edges remain, find vertex on current path with unused edges
  4. Form another cycle from that vertex and splice into main path
  5. Repeat until all edges used

  ## Relationship to Other Problems

  - **Chinese Postman**: Find shortest closed walk using every edge at least once
    (adds duplicate edges to make graph Eulerian)
  - **Route Inspection**: Variant allowing non-closed walks
  - **Hamiltonian Path**: Visits every *vertex* once (much harder, NP-complete)

  ## Use Cases

  - **Route optimization**: Minimizing distance in postal delivery or snow plowing

  ## Eulerian Visualization

  An **Eulerian Circuit** exists if every vertex has an even degree. An **Eulerian Path** exists if exactly zero or two vertices have an odd degree.

  <div class="graphviz">
  graph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];

    subgraph cluster_circuit {
      label="Eulerian Circuit (All Even)"; color="#10b981"; style=rounded;
      A -- B; B -- C; C -- A;
      C -- D; D -- E; E -- C;
    }

    subgraph cluster_path {
      label="Eulerian Path (2 Odd)"; color="#f59e0b"; style=rounded;
      1 -- 2; 2 -- 3; 3 -- 4; 4 -- 1; 1 -- 3;
    }
  }
  </div>

      iex> alias Yog.Property.Eulerian
      iex> circuit = Yog.from_edges(:undirected, [{"A", "B", 1}, {"B", "C", 1}, {"C", "A", 1}, {"C", "D", 1}, {"D", "E", 1}, {"E", "C", 1}])
      iex> Eulerian.has_eulerian_circuit?(circuit)
      true
      iex> path = Yog.from_edges(:undirected, [{"1", "2", 1}, {"2", "3", 1}, {"3", "4", 1}, {"4", "1", 1}, {"1", "3", 1}])
      iex> Eulerian.has_eulerian_path?(path)
      true
      iex> Eulerian.has_eulerian_circuit?(path)
      false

  ## History

  In 1736, Leonhard Euler proved that the Seven Bridges of Königsberg problem
  had no solution, establishing the conditions for Eulerian paths and founding
  graph theory as a mathematical discipline.

  ## Examples

      # Simple Eulerian circuit (square)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 4, to: 1, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(graph)
      true

  ## References

  - [Wikipedia: Eulerian Path](https://en.wikipedia.org/wiki/Eulerian_path)
  - [Wikipedia: Seven Bridges of Königsberg](https://en.wikipedia.org/wiki/Seven_Bridges_of_K%C3%B6nigsberg)
  - [Wikipedia: Hierholzer's Algorithm](https://en.wikipedia.org/wiki/Eulerian_path#Hierholzer's_algorithm)
  - [Wikipedia: Route Inspection Problem](https://en.wikipedia.org/wiki/Route_inspection_problem)
  - [CP-Algorithms: Eulerian Path](https://cp-algorithms.com/graph/euler_path.html)
  """

  alias Yog.Connectivity.Components
  alias Yog.Model

  @doc """
  Checks if the graph contains an Eulerian circuit.

  ## Conditions

  - **Undirected:** All vertices even degree + connected.
  - **Directed:** All vertices balanced (in == out) + connected.

  ## Examples

      # Square has Eulerian circuit (all degrees = 2)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 4, to: 1, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(graph)
      true

      # Path does not have circuit (ends have odd degree)
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(path)
      false

      # Empty graph has no circuit
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(Yog.undirected())
      false

  ## Time Complexity

  O(V + E)
  """
  @spec has_eulerian_circuit?(Yog.graph()) :: boolean()
  def has_eulerian_circuit?(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      false
    else
      case Model.type(graph) do
        :undirected -> has_eulerian_circuit_undirected?(graph, nodes)
        :directed -> has_eulerian_circuit_directed?(graph, nodes)
      end
    end
  end

  defp has_eulerian_circuit_undirected?(graph, nodes) do
    all_even =
      Enum.all?(nodes, fn node ->
        rem(Model.degree(graph, node), 2) == 0
      end)

    all_even and connected?(graph, nodes)
  end

  defp has_eulerian_circuit_directed?(graph, nodes) do
    all_balanced =
      Enum.all?(nodes, fn node ->
        Model.in_degree(graph, node) == Model.out_degree(graph, node)
      end)

    all_balanced and connected?(graph, nodes)
  end

  @doc """
  Checks if the graph contains an Eulerian path.

  ## Conditions

  - **Undirected:** 0 or 2 odd-degree vertices + connected.
  - **Directed:** At most one (out - in = 1), at most one (in - out = 1), others balanced.

  ## Examples

      # Path graph has Eulerian path (2 odd-degree vertices)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_path?(graph)
      true

      # Square has path (actually has circuit)
      iex> square = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 4, to: 1, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_path?(square)
      true

      # Empty graph has no path
      iex> Yog.Property.Eulerian.has_eulerian_path?(Yog.undirected())
      false

  ## Time Complexity

  O(V + E)
  """
  @spec has_eulerian_path?(Yog.graph()) :: boolean()
  def has_eulerian_path?(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      false
    else
      case Model.type(graph) do
        :undirected -> has_eulerian_path_undirected?(graph, nodes)
        :directed -> has_eulerian_path_directed?(graph, nodes)
      end
    end
  end

  defp has_eulerian_path_undirected?(graph, nodes) do
    odd_count =
      Enum.count(nodes, fn node ->
        rem(Model.degree(graph, node), 2) == 1
      end)

    (odd_count == 0 or odd_count == 2) and connected?(graph, nodes)
  end

  defp has_eulerian_path_directed?(graph, nodes) do
    stats =
      Enum.reduce(nodes, {0, 0, true}, fn node, {starts, ends, valid} ->
        diff = Model.out_degree(graph, node) - Model.in_degree(graph, node)

        cond do
          diff == 1 -> {starts + 1, ends, valid and starts < 1}
          diff == -1 -> {starts, ends + 1, valid and ends < 1}
          diff == 0 -> {starts, ends, valid}
          true -> {starts, ends, false}
        end
      end)

    case stats do
      {s, e, true} when (s == 0 and e == 0) or (s == 1 and e == 1) ->
        connected?(graph, nodes)

      _ ->
        false
    end
  end

  # Check if all nodes with degree > 0 are in the same weakly connected component
  defp connected?(graph, _nodes) do
    # Get all weakly connected components
    components = Components.weakly_connected_components(graph)

    # Filter for components that contain at least one edge (non-isolated)
    # A component has an edge if any node in it has degree > 0
    non_isolated_components =
      Enum.filter(components, fn component ->
        Enum.any?(component, fn node -> Model.degree(graph, node) > 0 end)
      end)

    # An Eulerian graph must have at most one such component
    length(non_isolated_components) <= 1
  end

  @doc """
  Finds an Eulerian circuit in the graph using Hierholzer's algorithm.

  Returns `{:ok, circuit}` where circuit is a list of node IDs forming a circuit,
  or `{:error, :no_eulerian_circuit}` if no circuit exists.

  ## Examples

      # Find circuit in square
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 4, to: 1, with: 1)
      iex> {:ok, circuit} = Yog.Property.Eulerian.eulerian_circuit(graph)
      iex> length(circuit)
      5  # Includes return to start

      # No circuit in path graph
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> Yog.Property.Eulerian.eulerian_circuit(path)
      {:error, :no_eulerian_circuit}

  ## Time Complexity

  O(E)
  """
  @spec eulerian_circuit(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :no_eulerian_circuit}
  def eulerian_circuit(graph) do
    if has_eulerian_circuit?(graph) do
      nodes = Model.all_nodes(graph)
      start = hd(nodes)
      {:ok, hierholzer(graph, start)}
    else
      {:error, :no_eulerian_circuit}
    end
  end

  @doc """
  Finds an Eulerian path in the graph using Hierholzer's algorithm.

  Returns `{:ok, path}` where path is a list of node IDs,
  or `{:error, :no_eulerian_path}` if no path exists.

  ## Examples

      # Find path in path graph
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> {:ok, path} = Yog.Property.Eulerian.eulerian_path(graph)
      iex> length(path)
      3

      # Path in square (starts and ends at same node since it has circuit)
      iex> square = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 4, to: 1, with: 1)
      iex> {:ok, path} = Yog.Property.Eulerian.eulerian_path(square)
      iex> length(path)
      5

  ## Time Complexity

  O(E)
  """
  @spec eulerian_path(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :no_eulerian_path}
  def eulerian_path(graph) do
    cond do
      has_eulerian_circuit?(graph) ->
        {:ok, _circuit} = eulerian_circuit(graph)

      has_eulerian_path?(graph) ->
        start = find_path_start(graph)
        {:ok, hierholzer(graph, start)}

      true ->
        {:error, :no_eulerian_path}
    end
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  defp find_path_start(graph) do
    nodes = Model.all_nodes(graph)

    case Model.type(graph) do
      :undirected ->
        Enum.find(nodes, fn node ->
          Model.degree(graph, node) |> rem(2) == 1
        end) || hd(nodes)

      :directed ->
        Enum.find(nodes, fn node ->
          Model.out_degree(graph, node) - Model.in_degree(graph, node) == 1
        end) || hd(nodes)
    end
  end

  defp hierholzer(graph, start) do
    {adj_stacks, edge_counts} = build_hierholzer_data(graph)

    {_adj, _counts, circuit} = do_hierholzer(graph, start, adj_stacks, edge_counts, [])
    circuit
  end

  defp build_hierholzer_data(graph) do
    nodes = Model.all_nodes(graph)

    Enum.reduce(nodes, {%{}, %{}}, fn u, {adj_acc, count_acc} ->
      successors = Model.successor_ids(graph, u)

      new_adj = Map.put(adj_acc, u, successors)

      new_counts =
        Enum.reduce(successors, count_acc, fn v, acc ->
          Map.update(acc, {u, v}, 1, &(&1 + 1))
        end)

      {new_adj, new_counts}
    end)
  end

  defp do_hierholzer(graph, current, adj_stacks, edge_counts, path) do
    case get_unused_edge(graph, current, adj_stacks, edge_counts) do
      {nil, adj_stacks, edge_counts} ->
        {adj_stacks, edge_counts, [current | path]}

      {:ok, next, adj_stacks, edge_counts} ->
        {adj_stacks, edge_counts, path_after_branch} =
          do_hierholzer(graph, next, adj_stacks, edge_counts, path)

        do_hierholzer(graph, current, adj_stacks, edge_counts, path_after_branch)
    end
  end

  defp get_unused_edge(graph, u, adj_stacks, edge_counts) do
    case Map.get(adj_stacks, u, []) do
      [] ->
        {nil, adj_stacks, edge_counts}

      [v | rest_v] ->
        key = {u, v}
        count = Map.get(edge_counts, key, 0)

        updated_stacks = Map.put(adj_stacks, u, rest_v)

        if count > 0 do
          edge_counts = Map.update!(edge_counts, key, &(&1 - 1))

          edge_counts =
            if Model.type(graph) == :undirected and u != v do
              Map.update!(edge_counts, {v, u}, &(&1 - 1))
            else
              edge_counts
            end

          {:ok, v, updated_stacks, edge_counts}
        else
          get_unused_edge(graph, u, updated_stacks, edge_counts)
        end
    end
  end
end
