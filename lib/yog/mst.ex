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
  | Edmonds' | `minimum_arborescence/2` | Directed MST (Minimum Spanning Arborescence) |

  ## Important: Undirected Graphs Only

  MST algorithms (Kruskal, Prim, Borůvka) are **only defined for undirected graphs**.
  Passing a directed graph to these will return `{:error, :undirected_only}`.
  Use `minimum_arborescence/2` for directed graphs.

  ## Properties of MSTs

  - Connects all nodes with exactly `V - 1` edges (for a connected graph with V nodes)
  - Contains no cycles
  - Minimizes the sum of edge weights
  - May not be unique if multiple edges have the same weight

  ## References

  - [Wikipedia: Minimum Spanning Tree](https://en.wikipedia.org/wiki/Minimum_spanning_tree)
  - [CP-Algorithms: MST](https://cp-algorithms.com/graph/mst_kruskal.html)

  ## Example: Visualizing an MST

  <div class="graphviz">
  graph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    A [label="A"]; B [label="B"]; C [label="C"]; D [label="D"]; E [label="E"];

    // MST edges (solid, colored)
    A -- B [label="2", color="#6366f1", penwidth=2.5];
    B -- D [label="2", color="#6366f1", penwidth=2.5];
    D -- C [label="1", color="#6366f1", penwidth=2.5];
    E -- A [label="4", color="#6366f1", penwidth=2.5];

    // Non-MST edges (dashed, muted)
    B -- C [label="3", style=dashed, color="#94a3b8"];
    A -- C [label="6", style=dashed, color="#94a3b8"];
    D -- E [label="5", style=dashed, color="#94a3b8"];
  }
  </div>

      iex> alias Yog.MST
      iex> graph = Yog.from_edges(:undirected, [
      ...>   {"A", "B", 2}, {"B", "D", 2}, {"D", "C", 1}, {"E", "A", 4},
      ...>   {"B", "C", 3}, {"A", "C", 6}, {"D", "E", 5}
      ...> ])
      iex> {:ok, result} = MST.kruskal(in: graph)
      iex> result.total_weight
      9
      iex> result.edge_count
      4
  """

  alias Yog.MST.{Boruvka, Edmonds, Kruskal, Prim, Result, Wilson}

  @typedoc """
  Represents an edge in a spanning tree or arborescence.
  """
  @type edge :: %{from: Yog.node_id(), to: Yog.node_id(), weight: term()}

  # =============================================================================
  # Kruskal's Algorithm
  # =============================================================================

  @doc """
  Finds the Minimum Spanning Tree (MST) using Kruskal's algorithm.

  **Time Complexity:** O(E log E)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 2}, {1, 3, 3}])
      iex> {:ok, result} = Yog.MST.kruskal(in: graph)
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
  """
  @spec kruskal(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal(graph, compare \\ &Yog.Utils.compare/2)

  def kruskal(%Yog.Graph{kind: :directed}, _compare) do
    {:error, :undirected_only}
  end

  def kruskal(graph, compare) do
    Kruskal.compute(graph, compare)
  end

  @doc """
  Finds the Maximum Spanning Tree (MaxST) using Kruskal's algorithm.

  **Time Complexity:** O(E log E)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 20}, {1, 3, 3}])
      iex> {:ok, result} = Yog.MST.kruskal_max(in: graph)
      iex> result.total_weight
      23
  """
  @spec kruskal_max(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal_max(opts) when is_list(opts) do
    kruskal(Keyword.put_new(opts, :compare, &Yog.Utils.compare_desc/2))
  end

  @spec kruskal_max(Yog.graph()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def kruskal_max(graph) do
    kruskal(graph, &Yog.Utils.compare_desc/2)
  end

  # =============================================================================
  # Prim's Algorithm
  # =============================================================================

  @doc """
  Finds the Minimum Spanning Tree (MST) using Prim's algorithm.

  **Time Complexity:** O(E log V)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 2}, {1, 3, 3}])
      iex> {:ok, result} = Yog.MST.prim(in: graph, from: 1)
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
  """
  @spec prim(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def prim(graph, compare \\ &Yog.Utils.compare/2) do
    prim(graph, compare, nil)
  end

  @spec prim(Yog.graph(), (term(), term() -> :lt | :eq | :gt), term() | nil) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def prim(%Yog.Graph{kind: :directed}, _compare, _start_node) do
    {:error, :undirected_only}
  end

  def prim(graph, compare, start_node) do
    Prim.compute(graph, compare, start_node)
  end

  @doc """
  Finds the Maximum Spanning Tree (MaxST) using Prim's algorithm.

  **Time Complexity:** O(E log V)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 20}, {1, 3, 3}])
      iex> {:ok, result} = Yog.MST.prim_max(in: graph, from: 1)
      iex> result.total_weight
      23
  """
  @spec prim_max(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def prim_max(opts) when is_list(opts) do
    prim(Keyword.put_new(opts, :compare, &Yog.Utils.compare_desc/2))
  end

  @spec prim_max(Yog.graph()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def prim_max(graph) do
    prim(graph, &Yog.Utils.compare_desc/2)
  end

  # =============================================================================
  # Borůvka's Algorithm
  # =============================================================================

  @doc """
  Finds the Minimum Spanning Tree (MST) using Borůvka's algorithm.

  **Time Complexity:** O(E log V)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}, {1, 3, 20}])
      iex> {:ok, result} = Yog.MST.boruvka(in: graph)
      iex> result.total_weight
      15
  """
  @spec boruvka(keyword()) :: {:ok, Result.t()} | {:error, :undirected_only}
  def boruvka(opts) when is_list(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = opts[:compare] || (&Yog.Utils.compare/2)
    boruvka(graph, compare)
  end

  @doc """
  Finds the Minimum Spanning Tree (MST) using Borůvka's algorithm.
  """
  @spec boruvka(Yog.graph(), (term(), term() -> :lt | :eq | :gt)) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def boruvka(graph, compare \\ &Yog.Utils.compare/2)

  def boruvka(%Yog.Graph{kind: :directed}, _compare) do
    {:error, :undirected_only}
  end

  def boruvka(graph, compare) do
    Boruvka.compute(graph, compare)
  end

  # =============================================================================
  # Wilson's Algorithm (Uniform Spanning Tree)
  # =============================================================================

  @doc """
  Generates a Uniform Spanning Tree (UST) using Wilson's algorithm.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges of the spanning tree.

  ## Parameters

  - `opts`: Options including:
    - `:in` - The graph to sample from.
    - `:root` - (Optional) The node to start the tree with.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {1, 3, 1}])
      iex> {:ok, result} = Yog.MST.uniform_spanning_tree(in: graph)
      iex> result.edge_count
      2
  """
  @spec uniform_spanning_tree(keyword()) :: {:ok, Result.t()}
  def uniform_spanning_tree(opts) when is_list(opts) do
    graph = Keyword.fetch!(opts, :in)
    Wilson.compute(graph, opts)
  end

  @spec uniform_spanning_tree(Yog.graph(), keyword()) :: {:ok, Result.t()}
  def uniform_spanning_tree(graph, opts \\ []) do
    Wilson.compute(graph, opts)
  end

  # =============================================================================
  # Edmonds' Algorithm (Minimum Spanning Arborescence)
  # =============================================================================

  @doc """
  Finds the Minimum Spanning Arborescence (MSA) using the Chu-Liu/Edmonds algorithm.

  **Time Complexity:** O(VE)

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Root") |> Yog.add_node(2, "A") |> Yog.add_node(3, "B")
      ...> |> Yog.add_edges!([{1, 2, 10}, {1, 3, 20}, {2, 3, 5}])
      iex> {:ok, result} = Yog.MST.minimum_arborescence(in: graph, root: 1)
      iex> result.total_weight
      15
  """
  @spec minimum_arborescence(keyword()) :: {:ok, Result.t()} | {:error, term()}
  def minimum_arborescence(opts) when is_list(opts) do
    graph = Keyword.fetch!(opts, :in)
    root = Keyword.fetch!(opts, :root)
    Edmonds.compute(graph, root)
  end

  @spec minimum_arborescence(Yog.graph(), term()) :: {:ok, Result.t()} | {:error, term()}
  def minimum_arborescence(graph, root) do
    Edmonds.compute(graph, root)
  end

  @doc """
  Alias for `minimum_arborescence/2`.
  """
  @spec chu_liu_edmonds(keyword() | Yog.graph(), term()) ::
          {:ok, Result.t()} | {:error, term()}
  def chu_liu_edmonds(opts_or_graph, root \\ nil)
  def chu_liu_edmonds(opts, nil) when is_list(opts), do: minimum_arborescence(opts)
  def chu_liu_edmonds(graph, root), do: minimum_arborescence(graph, root)

  # =============================================================================
  # Facades
  # =============================================================================

  @doc """
  Facade for Maximum Spanning Tree (MaxST). Defaults to Kruskal's algorithm.
  """
  @spec maximum_spanning_tree(keyword() | Yog.graph()) ::
          {:ok, Result.t()} | {:error, :undirected_only}
  def maximum_spanning_tree(opts) when is_list(opts), do: kruskal_max(opts)
  def maximum_spanning_tree(graph), do: kruskal_max(graph)

  # =============================================================================
  # Shared Internal Helpers
  # =============================================================================

  @doc false
  def extract_edges(%Yog.Graph{kind: kind, out_edges: out_edges}) do
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

  @doc false
  def push_all(pq, edges) do
    List.foldl(edges, pq, fn edge, acc -> Yog.PairingHeap.push(acc, edge) end)
  end
end
