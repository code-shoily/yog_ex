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

  - **Route planning**: Garbage collection, snow plowing, mail delivery
  - **DNA sequencing**: Constructing genomes from overlapping fragments
  - **Circuit board drilling**: Optimizing drill paths for PCB manufacturing
  - **Layout printing**: Efficient pen plotting without lifting
  - **Museum guard tours**: Covering all corridors efficiently

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
      case graph.kind do
        :undirected -> has_eulerian_circuit_undirected?(graph, nodes)
        :directed -> has_eulerian_circuit_directed?(graph, nodes)
      end
    end
  end

  defp has_eulerian_circuit_undirected?(graph, nodes) do
    # All nodes must have even parity (self loops count as 2, so they don't affect parity)
    out_edges = graph.out_edges

    all_even =
      Enum.all?(nodes, fn node ->
        inner = Map.get(out_edges, node, %{})
        degree = map_size(inner)
        adjusted_degree = if Map.has_key?(inner, node), do: degree - 1, else: degree
        rem(adjusted_degree, 2) == 0
      end)

    all_even and connected?(graph, nodes)
  end

  defp has_eulerian_circuit_directed?(graph, nodes) do
    in_edges = graph.in_edges
    out_edges = graph.out_edges

    # All nodes must have in_degree == out_degree
    all_balanced =
      Enum.all?(nodes, fn node ->
        in_deg = map_size(Map.get(in_edges, node, %{}))
        out_deg = map_size(Map.get(out_edges, node, %{}))
        in_deg == out_deg
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
      case graph.kind do
        :undirected -> has_eulerian_path_undirected?(graph, nodes)
        :directed -> has_eulerian_path_directed?(graph, nodes)
      end
    end
  end

  defp has_eulerian_path_undirected?(graph, nodes) do
    out_edges = graph.out_edges

    # 0 or 2 odd degree nodes (excluding self loops which don't affect parity)
    odd_count =
      Enum.count(nodes, fn node ->
        inner = Map.get(out_edges, node, %{})
        degree = map_size(inner)
        adjusted_degree = if Map.has_key?(inner, node), do: degree - 1, else: degree

        rem(adjusted_degree, 2) == 1
      end)

    (odd_count == 0 or odd_count == 2) and connected?(graph, nodes)
  end

  defp has_eulerian_path_directed?(graph, nodes) do
    in_edges = graph.in_edges
    out_edges = graph.out_edges

    # At most one start (out - in = 1), at most one end (in - out = 1)
    stats =
      Enum.reduce(nodes, {0, 0, true}, fn node, {starts, ends, valid} ->
        in_deg = map_size(Map.get(in_edges, node, %{}))
        out_deg = map_size(Map.get(out_edges, node, %{}))
        diff = out_deg - in_deg

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

  # Check if graph is connected (weakly for directed)
  defp connected?(graph, nodes) do
    source = hd(nodes)
    visited = bfs_visited(graph, source)
    Enum.all?(nodes, fn n -> n in visited end)
  end

  defp bfs_visited(graph, source) do
    do_bfs(graph, [source], MapSet.new([source]))
  end

  defp do_bfs(_graph, [], visited), do: MapSet.to_list(visited)

  defp do_bfs(graph, [current | rest], visited) do
    # For both directed and undirected, consider neighbors in both directions
    neighbors = Model.neighbor_ids(graph, current)

    new_neighbors = Enum.reject(neighbors, fn n -> MapSet.member?(visited, n) end)
    new_visited = Enum.reduce(new_neighbors, visited, fn n, acc -> MapSet.put(acc, n) end)

    do_bfs(graph, rest ++ new_neighbors, new_visited)
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

  defdelegate find_eulerian_circuit(graph), to: __MODULE__, as: :eulerian_circuit

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

  defdelegate find_eulerian_path(graph), to: __MODULE__, as: :eulerian_path

  # Find the start vertex for an Eulerian path
  defp find_path_start(graph) do
    nodes = Model.all_nodes(graph)

    case graph.kind do
      :undirected ->
        # Find odd degree vertex
        Enum.find(nodes, fn node ->
          degree = length(Model.neighbor_ids(graph, node))
          rem(degree, 2) == 1
        end) || hd(nodes)

      :directed ->
        # Find vertex with out - in = 1
        Enum.find(nodes, fn node ->
          in_deg = length(Model.predecessors(graph, node))
          out_deg = length(Model.successors(graph, node))
          out_deg - in_deg == 1
        end) || hd(nodes)
    end
  end

  # Hierholzer's algorithm implementation
  defp hierholzer(graph, start) do
    # Build mutable edge map
    # edge_map: {from, to} -> count (for undirected we store both directions)
    edge_map = build_edge_map(graph)

    # Run Hierholzer
    {_map, circuit} = do_hierholzer(graph, start, edge_map, [])

    # circuit is built in correct order via post-order accumulation
    circuit
  end

  defp build_edge_map(graph) do
    Enum.reduce(Model.all_nodes(graph), %{}, fn from, acc ->
      successors = Model.successor_ids(graph, from)

      Enum.reduce(successors, acc, fn to, acc2 ->
        key = {from, to}
        Map.update(acc2, key, 1, &(&1 + 1))
      end)
    end)
  end

  defp do_hierholzer(graph, current, edge_map, path) do
    case find_unused_edge(graph, current, edge_map) do
      nil ->
        {edge_map, [current | path]}

      next ->
        # Use this edge
        key = {current, next}
        new_map = Map.update!(edge_map, key, &(&1 - 1))
        new_map = if new_map[key] == 0, do: Map.delete(new_map, key), else: new_map

        # For undirected, also remove reverse edge
        new_map =
          if graph.kind == :undirected and current != next do
            rev_key = {next, current}
            new_map = Map.update!(new_map, rev_key, &(&1 - 1))
            if new_map[rev_key] == 0, do: Map.delete(new_map, rev_key), else: new_map
          else
            new_map
          end

        # 1. Take the branch deep
        {m2, p2} = do_hierholzer(graph, next, new_map, path)

        # 2. Backtrack and continue search from current for other cycles
        do_hierholzer(graph, current, m2, p2)
    end
  end

  defp find_unused_edge(graph, current, edge_map) do
    candidates =
      case graph.kind do
        :undirected -> Model.neighbor_ids(graph, current)
        :directed -> Model.successor_ids(graph, current)
      end

    Enum.find(candidates, fn to ->
      key = {current, to}
      Map.get(edge_map, key, 0) > 0
    end)
  end
end
