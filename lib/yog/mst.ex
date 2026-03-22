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
  """

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

    edges = :yog@mst.kruskal(graph, compare)

    Enum.map(edges, fn {:edge, from, to, weight} ->
      %{from: from, to: to, weight: weight}
    end)
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

    edges = :yog@mst.prim(graph, compare)

    Enum.map(edges, fn {:edge, from, to, weight} ->
      %{from: from, to: to, weight: weight}
    end)
  end
end
