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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 4, to: 1, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(graph)
      true

  ## References

  - [Wikipedia: Eulerian Path](https://en.wikipedia.org/wiki/Eulerian_path)
  - [Wikipedia: Seven Bridges of Königsberg](https://en.wikipedia.org/wiki/Seven_Bridges_of_K%C3%B6nigsberg)
  - [Wikipedia: Hierholzer's Algorithm](https://en.wikipedia.org/wiki/Eulerian_path#Hierholzer's_algorithm)
  - [Wikipedia: Route Inspection Problem](https://en.wikipedia.org/wiki/Route_inspection_problem)
  - [CP-Algorithms: Eulerian Path](https://cp-algorithms.com/graph/euler_path.html)
  """

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 4, to: 1, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(graph)
      true

      # Path does not have circuit (ends have odd degree)
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(path)
      false

      # Empty graph has no circuit
      iex> Yog.Property.Eulerian.has_eulerian_circuit?(Yog.undirected())
      false

  ## Time Complexity

  O(V + E)
  """
  @spec has_eulerian_circuit?(Yog.graph()) :: boolean()
  def has_eulerian_circuit?(graph), do: :yog@property@eulerian.has_eulerian_circuit(graph)

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_path?(graph)
      true

      # Square has path (actually has circuit)
      iex> square = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 4, to: 1, with: 1)
      iex> Yog.Property.Eulerian.has_eulerian_path?(square)
      true

      # Empty graph has no path
      iex> Yog.Property.Eulerian.has_eulerian_path?(Yog.undirected())
      false

  ## Time Complexity

  O(V + E)
  """
  @spec has_eulerian_path?(Yog.graph()) :: boolean()
  def has_eulerian_path?(graph), do: :yog@property@eulerian.has_eulerian_path(graph)

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 4, to: 1, with: 1)
      iex> {:ok, circuit} = Yog.Property.Eulerian.eulerian_circuit(graph)
      iex> length(circuit)
      5  # Includes return to start

      # No circuit in path graph
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Property.Eulerian.eulerian_circuit(path)
      {:error, :no_eulerian_circuit}

  ## Time Complexity

  O(E)
  """
  @spec eulerian_circuit(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :no_eulerian_circuit}
  def eulerian_circuit(graph) do
    case :yog@property@eulerian.find_eulerian_circuit(graph) do
      {:some, circuit} -> {:ok, circuit}
      :none -> {:error, :no_eulerian_circuit}
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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> {:ok, path} = Yog.Property.Eulerian.eulerian_path(graph)
      iex> length(path)
      3

      # Path in square (starts and ends at same node since it has circuit)
      iex> square = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 4, to: 1, with: 1)
      iex> {:ok, path} = Yog.Property.Eulerian.eulerian_path(square)
      iex> length(path)
      5

  ## Time Complexity

  O(E)
  """
  @spec eulerian_path(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :no_eulerian_path}
  def eulerian_path(graph) do
    case :yog@property@eulerian.find_eulerian_path(graph) do
      {:some, path} -> {:ok, path}
      :none -> {:error, :no_eulerian_path}
    end
  end

  defdelegate find_eulerian_path(graph), to: __MODULE__, as: :eulerian_path
end

defmodule Yog.Eulerian do
  @moduledoc "Deprecated. Use `Yog.Property.Eulerian` instead."
  defdelegate has_eulerian_circuit?(graph), to: Yog.Property.Eulerian
  defdelegate has_eulerian_path?(graph), to: Yog.Property.Eulerian
  defdelegate eulerian_circuit(graph), to: Yog.Property.Eulerian
  defdelegate find_eulerian_circuit(graph), to: Yog.Property.Eulerian
  defdelegate eulerian_path(graph), to: Yog.Property.Eulerian
  defdelegate find_eulerian_path(graph), to: Yog.Property.Eulerian
end
