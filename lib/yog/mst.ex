defmodule Yog.MST do
  @moduledoc """
  Minimum Spanning Tree (MST) algorithms for finding optimal network connections.

  A [Minimum Spanning Tree](https://en.wikipedia.org/wiki/Minimum_spanning_tree) connects all nodes
  in a weighted **undirected** graph with the minimum possible total edge weight. MSTs have
  applications in network design, clustering, and optimization problems.

  ## Available Algorithms

  | Algorithm | Function | Best For |
  |-----------|----------|----------|
  | Kruskal's | `kruskal/2`, `kruskal_max/2` | Sparse graphs, edge lists |
  | Prim's | `prim/2`, `prim_max/2` | Dense graphs, growing from a start node |
  | Borůvka's | `boruvka/1` | Parallelized MST for large graphs |

  ## Important: Undirected Graphs Only

  MST algorithms are **only defined for undirected graphs**. Passing a directed graph
  will return `{:error, :undirected_only}`.

  ### What About Directed Graphs?

  For directed graphs, the equivalent problem is the **Minimum Spanning Arborescence** (MSA),
  also known as the **Minimum Cost Arborescence** or **Optimum Branching**. This finds a
  directed tree (arborescence) rooted at a specific node that reaches all other nodes
  with minimum total weight.

  The MSA problem is solved by **Edmonds' algorithm** (also called Chu-Liu/Edmonds algorithm),
  which is not currently implemented in this module.

  ## Properties of MSTs

  - Connects all nodes with exactly `V - 1` edges (for a connected graph with V nodes)
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
  - [Wikipedia: Edmonds' Algorithm](https://en.wikipedia.org/wiki/Edmonds%27_algorithm) (for directed graphs)
  """

  alias Yog.DisjointSet
  alias Yog.MST.Result
  alias Yog.PairingHeap, as: PQ

  @typedoc """
  Represents an edge in the minimum spanning tree.

  - `from`: Source node ID
  - `to`: Destination node ID
  - `weight`: Edge weight
  """
  @type edge :: %{from: Yog.node_id(), to: Yog.node_id(), weight: term()}

  @doc """
  Finds the Minimum Spanning Tree (MST) using Kruskal's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges that form the MST.
  The total weight of these edges is minimized while ensuring all nodes are connected.

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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)
      iex> {:ok, result} = Yog.MST.kruskal(in: graph, compare: fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> result.edge_count
      2
      iex> result.total_weight
      3
  """
  @spec kruskal(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal(opts) when is_list(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)
      iex> {:ok, result} = graph |> Yog.MST.kruskal(fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> result.edge_count
      2
  """
  @spec kruskal(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal(graph, compare \\ &Yog.Utils.compare/2)

  def kruskal(%Yog.Graph{kind: :directed}, _compare) do
    {:error, :undirected_only}
  end

  def kruskal(graph, compare) do
    edges = extract_edges(graph)
    sorted_edges = Enum.sort(edges, fn a, b -> compare.(a.weight, b.weight) == :lt end)

    result = do_kruskal(sorted_edges, DisjointSet.new(), [])
    {:ok, Result.new(result, :kruskal, map_size(graph.nodes))}
  end

  @doc """
  Finds the Maximum Spanning Tree (MaxST) using Kruskal's algorithm.

  Connects all nodes with the maximum possible total edge weight. In an
  undirected graph, the path between any two nodes in the MaxST is the
  widest path (maximum bottleneck capacity) between them.

  ## Options

  - `:in` - The graph to find the MaxST in
  - Other options are passed to `kruskal/2`.

  ## Examples

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_edges!([{1, 2, 10}, {2, 3, 20}, {1, 3, 5}])
      iex> {:ok, result} = Yog.MST.kruskal_max(in: graph)
      iex> result.total_weight
      30
  """
  @spec kruskal_max(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal_max(opts) when is_list(opts) do
    kruskal(Keyword.put_new(opts, :compare, &Yog.Utils.compare_desc/2))
  end

  @spec kruskal_max(Yog.graph()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal_max(graph) do
    kruskal(graph, &Yog.Utils.compare_desc/2)
  end

  @doc """
  Finds the Maximum Spanning Tree (MaxST) using Prim's algorithm.

  ## Options

  - `:in` - The graph to search
  - `:from` - Starting node ID
  - Other options are passed to `prim/2`.

  ## Examples

      iex> graph = 
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_edges!([{1, 2, 10}, {2, 3, 20}, {1, 3, 5}])
      iex> {:ok, result} = Yog.MST.prim_max(in: graph, from: 1)
      iex> result.total_weight
      30
  """
  @spec prim_max(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def prim_max(opts) when is_list(opts) do
    prim(Keyword.put_new(opts, :compare, &Yog.Utils.compare_desc/2))
  end

  @spec prim_max(Yog.graph()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def prim_max(graph) do
    prim(graph, &Yog.Utils.compare_desc/2)
  end

  @doc """
  Facade for Maximum Spanning Tree (MaxST). Defaults to Kruskal's algorithm.
  """
  @spec maximum_spanning_tree(keyword() | Yog.graph()) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def maximum_spanning_tree(opts) when is_list(opts), do: kruskal_max(opts)
  def maximum_spanning_tree(graph), do: kruskal_max(graph)

  @doc """
  Finds the Minimum Spanning Tree (MST) using Prim's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges that form the MST.
  Unlike Kruskal's which processes all edges globally, Prim's grows the MST
  from a starting node by repeatedly adding the minimum-weight edge that
  connects a visited node to an unvisited node.

  **Time Complexity:** O(E log V) where E is the number of edges and V is the number of vertices

  **Disconnected Graphs:** For disconnected graphs, Prim's only returns edges
  for the connected component containing the starting node (or the first node
  in the graph if no start node is provided). Use Kruskal's if you need a
  minimum spanning forest that covers all components.

  ## Options

  - `:in` - The graph to find the MST in
  - `:compare` - A comparison function that takes two weights and returns
    `:lt`, `:eq`, or `:gt`
  - `:from` - The starting node ID (optional; defaults to the first node in the graph)

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)
      iex> {:ok, result} = Yog.MST.prim(in: graph, compare: fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> result.edge_count
      2
      iex> result.total_weight
      3
  """
  @spec prim(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def prim(opts) when is_list(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    start_node = opts[:from]
    prim(graph, compare, start_node)
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
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 2)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 3, with: 3)
      iex> {:ok, result} = graph |> Yog.MST.prim(fn a, b ->
      ...>   cond do
      ...>     a < b -> :lt
      ...>     a > b -> :gt
      ...>     true -> :eq
      ...>   end
      ...> end)
      iex> result.edge_count
      2
  """
  @spec prim(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def prim(graph, compare \\ &Yog.Utils.compare/2) do
    prim(graph, compare, nil)
  end

  def prim(%Yog.Graph{kind: :directed}, _compare, _start_node) do
    {:error, :undirected_only}
  end

  def prim(graph, compare, nil) do
    node_ids = Map.keys(graph.nodes)

    case node_ids do
      [] ->
        {:ok, Result.new([], :prim, 0)}

      [start | _] ->
        do_prim(graph, start, compare)
    end
  end

  def prim(graph, compare, start_node) do
    if Map.has_key?(graph.nodes, start_node) do
      do_prim(graph, start_node, compare)
    else
      {:ok, Result.new([], :prim, map_size(graph.nodes))}
    end
  end

  # Helper to push all edges into the priority queue
  defp push_all(pq, edges) do
    List.foldl(edges, pq, fn edge, acc -> PQ.push(acc, edge) end)
  end

  # =============================================================================
  # Private Helper Functions - Kruskal's Algorithm
  # =============================================================================

  # Extracts all edges from a graph.
  # For undirected graphs, only includes each edge once (when from_id <= to_id).
  defp extract_edges(%Yog.Graph{kind: kind, out_edges: out_edges}) do
    List.foldl(Map.to_list(out_edges), [], fn {from_id, targets}, acc ->
      List.foldl(Map.to_list(targets), acc, fn {to_id, weight}, inner_acc ->
        if kind == :undirected && from_id > to_id do
          inner_acc
        else
          [%{from: from_id, to: to_id, weight: weight} | inner_acc]
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

    # Optimization: early check if from and to are same set before second find
    case Map.fetch(ds1.parents, edge.to) do
      :error ->
        # to not in DS yet, add it and include edge
        ds2 = DisjointSet.add(ds1, edge.to)
        ds3 = DisjointSet.union(ds2, edge.from, edge.to)
        do_kruskal(rest, ds3, [edge | acc])

      {:ok, _} ->
        {ds2, root_to} = DisjointSet.find(ds1, edge.to)

        if root_from == root_to do
          do_kruskal(rest, ds2, acc)
        else
          ds3 = DisjointSet.union(ds2, edge.from, edge.to)
          do_kruskal(rest, ds3, [edge | acc])
        end
    end
  end

  # =============================================================================
  # Private Helper Functions - Prim's Algorithm
  # =============================================================================

  defp do_prim(graph, start, compare) do
    initial_edges = get_all_edges_from_node(graph, start)

    initial_pq =
      PQ.new(fn a, b -> compare.(a.weight, b.weight) == :lt end)
      |> push_all(initial_edges)

    initial_visited = %{start => true}

    result = do_prim_loop(graph, initial_pq, initial_visited, [], compare)
    {:ok, Result.new(result, :prim, map_size(graph.nodes))}
  end

  # Main Prim loop - grows MST from starting node.
  defp do_prim_loop(_graph, pq, _visited, acc, _compare) when pq == %{} do
    Enum.reverse(acc)
  end

  defp do_prim_loop(graph, pq, visited, acc, compare) do
    if PQ.empty?(pq) do
      Enum.reverse(acc)
    else
      {:ok, edge, rest_pq} = PQ.pop(pq)

      if Map.has_key?(visited, edge.to) do
        do_prim_loop(graph, rest_pq, visited, acc, compare)
      else
        new_visited = Map.put(visited, edge.to, true)
        new_acc = [edge | acc]

        new_edges = get_all_edges_from_node(graph, edge.to)

        # Filter and push edges in one pass using List.foldl
        new_pq =
          List.foldl(new_edges, rest_pq, fn e, acc_pq ->
            if Map.has_key?(new_visited, e.to) do
              acc_pq
            else
              PQ.push(acc_pq, e)
            end
          end)

        do_prim_loop(graph, new_pq, new_visited, new_acc, compare)
      end
    end
  end

  # Gets all outgoing edges from a specific node.
  defp get_all_edges_from_node(graph, from_id) do
    case Map.fetch(graph.out_edges, from_id) do
      {:ok, edges} ->
        List.foldl(Map.to_list(edges), [], fn {to_id, weight}, acc ->
          [%{from: from_id, to: to_id, weight: weight} | acc]
        end)

      :error ->
        []
    end
  end
end
