defmodule Yog.MST do
  @moduledoc """
  Minimum Spanning Tree (MST) algorithms for finding optimal network connections.

  A [Minimum Spanning Tree](https://en.wikipedia.org/wiki/Minimum_spanning_tree) connects all nodes
  in a weighted undirected graph with the minimum possible total edge weight. MSTs have
  applications in network design, clustering, and optimization problems.

  ## Available Algorithms

  | Algorithm | Function | Best For |
  |-----------|----------|----------|
  | [Kruskal's](https://en.wikipedia.org/wiki/Kruskal%27s_algorithm) | `kruskal/2` | Sparse graphs, edge lists |
  | [Prim's](https://en.wikipedia.org/wiki/Prim%27s_algorithm) | `prim/2` | Dense graphs, growing from a start node |

  ## Properties of MSTs

  - Connects all nodes with exactly `V - 1` edges (for a graph with V nodes)
  - Contains no cycles
  - Minimizes the sum of edge weights
  - May not be unique if multiple edges have the same weight

  ## Example Use Cases

  - **Network Design**: Minimizing cable length to connect buildings
  - **Cluster Analysis**: Hierarchical clustering via MST
  - **Approximation**: Traveling Salesman Problem approximations
  - **Image Segmentation**: Computer vision applications

  ## References

  - [Wikipedia: Minimum Spanning Tree](https://en.wikipedia.org/wiki/Minimum_spanning_tree)
  - [CP-Algorithms: MST](https://cp-algorithms.com/graph/mst_kruskal.html)

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.DisjointSet
  alias Yog.PQ

  @typedoc """
  Represents an edge in the minimum spanning tree.

  - `from`: Source node ID
  - `to`: Destination node ID
  - `weight`: Edge weight
  """
  @type edge :: %{from: Yog.node_id(), to: Yog.node_id(), weight: term()}

  @doc """
  Finds the Minimum Spanning Tree (MST) using Kruskal's algorithm.

  Returns a list of edges that form the MST. The total weight of these edges
  is minimized while ensuring all nodes are connected.

  **Time Complexity:** O(E log E) where E is the number of edges

  ## Options

  - `:in` - The graph to find the MST in
  - `:compare` - A comparison function that takes two weights and returns
    `:lt`, `:eq`, or `:gt` (like `&Integer.compare/2` or a custom function)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 3)
      iex> mst_edges = Yog.MST.kruskal(in: graph, compare: fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> length(mst_edges)
      2
      iex> Enum.reduce(mst_edges, 0, fn e, acc -> acc + e.weight end)
      3
  """
  @spec kruskal(keyword()) :: [edge()]
  def kruskal(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = Keyword.fetch!(opts, :compare)
    kruskal(graph, compare)
  end

  @doc """
  Finds the Minimum Spanning Tree (MST) using Kruskal's algorithm.

  Same as `kruskal/1` but with explicit positional arguments for pipeline use.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 3)
      iex> mst_edges = graph |> Yog.MST.kruskal(fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> length(mst_edges)
      2
  """
  @spec kruskal(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) :: [edge()]
  def kruskal(graph, compare) do
    edges = extract_edges(graph)
    sorted_edges = Enum.sort(edges, fn a, b -> compare.(a.weight, b.weight) == :lt end)

    do_kruskal(sorted_edges, DisjointSet.new(), [])
  end

  @doc """
  Finds the Minimum Spanning Tree (MST) using Prim's algorithm.

  Returns a list of edges that form the MST. Unlike Kruskal's which processes
  all edges globally, Prim's grows the MST from a starting node by repeatedly
  adding the minimum-weight edge that connects a visited node to an unvisited node.

  **Time Complexity:** O(E log V) where E is the number of edges and V is the number of vertices

  **Disconnected Graphs:** For disconnected graphs, Prim's only returns edges
  for the connected component containing the starting node (the first node in the graph).
  Use Kruskal's if you need a minimum spanning forest that covers all components.

  ## Options

  - `:in` - The graph to find the MST in
  - `:compare` - A comparison function that takes two weights and returns
    `:lt`, `:eq`, or `:gt`

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 3)
      iex> mst_edges = Yog.MST.prim(in: graph, compare: fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> length(mst_edges)
      2
      iex> Enum.reduce(mst_edges, 0, fn e, acc -> acc + e.weight end)
      3
  """
  @spec prim(keyword()) :: [edge()]
  def prim(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = Keyword.fetch!(opts, :compare)

    node_ids = get_all_nodes(graph)

    case node_ids do
      [] ->
        []

      [start | _] ->
        initial_edges = get_all_edges_from_node(graph, start)

        initial_pq =
          PQ.new(fn a, b -> compare.(a.weight, b.weight) == :lt end)
          |> push_all(initial_edges)

        initial_visited = MapSet.new([start])

        do_prim(graph, initial_pq, initial_visited, [], compare)
    end
  end

  @doc """
  Finds the Minimum Spanning Tree (MST) using Prim's algorithm.

  Same as `prim/1` but with explicit positional arguments for pipeline use.

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge!(from: 1, to: 3, with: 3)
      iex> mst_edges = graph |> Yog.MST.prim(fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> length(mst_edges)
      2
  """
  @spec prim(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) :: [edge()]
  def prim(graph, compare) do
    node_ids = get_all_nodes(graph)

    case node_ids do
      [] ->
        []

      [start | _] ->
        initial_edges = get_all_edges_from_node(graph, start)

        initial_pq =
          PQ.new(fn a, b -> compare.(a.weight, b.weight) == :lt end)
          |> push_all(initial_edges)

        initial_visited = MapSet.new([start])

        do_prim(graph, initial_pq, initial_visited, [], compare)
    end
  end

  # Helper to push all edges into the priority queue
  defp push_all(pq, edges) do
    Enum.reduce(edges, pq, fn edge, acc -> PQ.push(acc, edge) end)
  end

  # =============================================================================
  # Private Helper Functions - Kruskal's Algorithm
  # =============================================================================

  # Extracts all edges from a graph.
  # For undirected graphs, only includes each edge once (when from_id <= to_id).
  defp extract_edges(%Yog.Graph{kind: kind, out_edges: out_edges}) do
    Enum.flat_map(out_edges, fn {from_id, targets} ->
      Enum.flat_map(targets, fn {to_id, weight} ->
        # For undirected graphs, only include each edge once
        if kind == :undirected && from_id > to_id do
          []
        else
          [%{from: from_id, to: to_id, weight: weight}]
        end
      end)
    end)
  end

  # Main Kruskal loop - processes edges in order, adding them if they don't form cycles.
  defp do_kruskal([], _disjoint_set, acc) do
    Enum.reverse(acc)
  end

  defp do_kruskal([edge | rest], disjoint_set, acc) do
    {ds1, root_from} = DisjointSet.find(disjoint_set, edge.from)
    {ds2, root_to} = DisjointSet.find(ds1, edge.to)

    if root_from == root_to do
      # Skip this edge - would form a cycle
      do_kruskal(rest, ds2, acc)
    else
      # Add this edge to MST
      ds3 = DisjointSet.union(ds2, edge.from, edge.to)
      do_kruskal(rest, ds3, [edge | acc])
    end
  end

  # =============================================================================
  # Private Helper Functions - Prim's Algorithm
  # =============================================================================

  # Gets all node IDs from a graph.
  defp get_all_nodes(%Yog.Graph{nodes: nodes}) do
    Map.keys(nodes)
  end

  # Gets all outgoing edges from a specific node.
  defp get_all_edges_from_node(%Yog.Graph{out_edges: out_edges}, from_id) do
    case Map.fetch(out_edges, from_id) do
      {:ok, targets} ->
        Enum.map(targets, fn {to_id, weight} ->
          %{from: from_id, to: to_id, weight: weight}
        end)

      :error ->
        []
    end
  end

  # Main Prim loop - grows MST from starting node.
  defp do_prim(graph, pq, visited, acc, compare) do
    if PQ.empty?(pq) do
      Enum.reverse(acc)
    else
      {:ok, edge, rest_pq} = PQ.pop(pq)

      if MapSet.member?(visited, edge.to) do
        # Skip - already visited
        do_prim(graph, rest_pq, visited, acc, compare)
      else
        # Add this edge to MST
        new_visited = MapSet.put(visited, edge.to)
        new_acc = [edge | acc]

        # Get new edges from the newly visited node
        new_edges = get_all_edges_from_node(graph, edge.to)

        # Filter out edges to already visited nodes and add to PQ
        new_pq =
          Enum.reject(new_edges, fn e -> MapSet.member?(new_visited, e.to) end)
          |> Enum.reduce(rest_pq, fn e, acc_pq -> PQ.push(acc_pq, e) end)

        do_prim(graph, new_pq, new_visited, new_acc, compare)
      end
    end
  end
end
