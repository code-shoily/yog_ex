defmodule Yog.Connectivity do
  @moduledoc """
  Graph connectivity analysis - finding connected components, bridges, articulation points,
  and strongly connected components.

  This module provides algorithms for analyzing the connectivity structure of graphs,
  identifying components, and finding critical elements whose removal would disconnect the graph.

  ## Component Types

  | Component Type | Function | Graph Type | Description |
  |----------------|----------|------------|-------------|
  | **Connected Components** | `connected_components/1` | Undirected | Maximal connected subgraphs |
  | **Weakly Connected Components** | `weakly_connected_components/1` | Directed | Connected when ignoring direction |
  | **Strongly Connected Components** | `strongly_connected_components/1` | Directed | Connected following edge directions |

  ## Bridges vs Articulation Points

  - **Bridge** (cut edge): An edge whose removal increases the number of connected components.
    In a network, this represents a single point of failure.
  - **Articulation Point** (cut vertex): A node whose removal increases the number of connected
    components. These are critical nodes in the network.

  ## Algorithms

  | Algorithm | Function | Use Case | Complexity |
  |-----------|----------|----------|------------|
  | DFS-based CC | `connected_components/1` | Undirected graph components | O(V + E) |
  | DFS-based WCC | `weakly_connected_components/1` | Directed graph, ignore direction | O(V + E) |
  | [Tarjan's SCC](https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm) | `strongly_connected_components/1` | Find SCCs in one pass | O(V + E) |
  | [Kosaraju's Algorithm](https://en.wikipedia.org/wiki/Kosaraju%27s_algorithm) | `kosaraju/1` | Find SCCs using two DFS passes | O(V + E) |
  | [Tarjan's Bridge-Finding](https://en.wikipedia.org/wiki/Bridge_(graph_theory)) | `analyze/1` | Find bridges and articulation points | O(V + E) |

  All algorithms run in **O(V + E)** linear time.
  """

  @type bridge :: {Yog.node_id(), Yog.node_id()}
  @type component :: [Yog.node_id()]
  @type connectivity_results :: %{
          bridges: [bridge()],
          articulation_points: [Yog.node_id()]
        }

  @doc """
  Analyzes an **undirected graph** to find all bridges and articulation points
  using Tarjan's algorithm in a single DFS pass.

  Important: This algorithm is designed for undirected graphs. For directed
  graphs, use strongly connected components analysis instead.

  Bridges are edges whose removal increases the number of connected components.
  Articulation points (cut vertices) are nodes whose removal increases the number
  of connected components.

  Bridge ordering: Bridges are returned as `{lower_id, higher_id}` for consistency.

  ## Example

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: nil)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: nil)
      iex>
      iex> results = Yog.Connectivity.analyze(in: graph)
      iex> Enum.sort(results.bridges)
      [{1, 2}, {2, 3}]
      iex> results.articulation_points
      [2]

  Time Complexity: O(V + E)
  """
  @spec analyze(keyword()) :: connectivity_results()
  def analyze(options \\ []) do
    graph = Keyword.fetch!(options, :in)
    {:connectivity_results, bridges, points} = :yog@connectivity.analyze(graph)
    %{bridges: bridges, articulation_points: points}
  end

  @doc """
  Finds Strongly Connected Components (SCC) using Tarjan's Algorithm.

  Returns a list of components, where each component is a list of node IDs.
  O(V + E) linear time.
  """
  @spec strongly_connected_components(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate strongly_connected_components(graph), to: :yog@connectivity

  @doc """
  Alias for `strongly_connected_components/1`.
  """
  defdelegate scc(graph), to: :yog@connectivity, as: :strongly_connected_components

  @doc """
  Finds Strongly Connected Components (SCC) using Kosaraju's Algorithm.

  Returns a list of components, where each component is a list of node IDs.
  Kosaraju's algorithm uses two DFS passes and graph transposition:

  1. First DFS: Compute finishing times
  2. Transpose the graph (reverse all edges) - O(1) operation in Yog!
  3. Second DFS: Process nodes in reverse finishing time order on transposed graph

  Time Complexity: O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex>
      iex> sccs = Yog.Connectivity.kosaraju(graph)
      iex> hd(sccs) |> Enum.sort()
      [1, 2, 3]
  """
  @spec kosaraju(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate kosaraju(graph), to: :yog@connectivity

  @doc """
  Finds Connected Components in an **undirected graph**.

  A connected component is a maximal subgraph where every node is reachable
  from every other node via undirected edges. This uses simple DFS and runs
  in linear time.

  Important: This algorithm is designed for undirected graphs. For directed
  graphs, use `weakly_connected_components/1` instead.

  Time Complexity: O(V + E)

  ## Example

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_node(4, "D")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex>
      iex> components = Yog.Connectivity.connected_components(graph)
      iex> Enum.map(components, &Enum.sort/1) |> Enum.sort()
      [[1, 2], [3, 4]]
  """
  @spec connected_components(Yog.graph()) :: [component()]
  defdelegate connected_components(graph), to: :yog@connectivity

  @doc """
  Finds Weakly Connected Components in a **directed graph**.

  A weakly connected component is a maximal subgraph where, if you ignore
  edge directions, all nodes are reachable from each other. This is equivalent
  to finding connected components on the underlying undirected graph.

  Time Complexity: O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 2, with: 1)  # 1->2<-3
      iex>
      iex> # WCCs: [1, 2, 3] (weakly connected as undirected)
      iex> wccs = Yog.Connectivity.weakly_connected_components(graph)
      iex> hd(wccs) |> Enum.sort()
      [1, 2, 3]
  """
  @spec weakly_connected_components(Yog.graph()) :: [component()]
  defdelegate weakly_connected_components(graph), to: :yog@connectivity
end
