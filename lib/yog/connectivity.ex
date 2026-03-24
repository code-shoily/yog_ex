defmodule Yog.Connectivity do
  @moduledoc """
  Graph connectivity analysis - finding connected components, bridges, articulation points,
  strongly connected components, and k-core decomposition.

  This module provides a unified API for analyzing the connectivity structure of graphs.

  ## Algorithms

  ### Connectivity Analysis
  - `analyze/1` - Find bridges and articulation points (undirected).

  ### Strongly Connected Components (Directed)
  - `strongly_connected_components/1` (alias `scc/1`) - Tarjan's algorithm.
  - `kosaraju/1` - Kosaraju's two-pass algorithm.

  ### (Weakly) Connected Components
  - `connected_components/1` - Standard CC (undirected).
  - `weakly_connected_components/1` - WCC (directed).

  ### Higher-Order Connectivity
  - `k_core/2` - Find maximal subgraphs with minimum degree k.
  - `core_numbers/1` - Core number for all nodes.
  - `degeneracy/1` - Maximum core number.
  """

  alias Yog.Connectivity.Analysis
  alias Yog.Connectivity.Components
  alias Yog.Connectivity.KCore
  alias Yog.Connectivity.SCC

  @type bridge :: Analysis.bridge()
  @type component :: Components.component()
  @type connectivity_results :: Analysis.connectivity_results()

  @doc """
  Analyzes an **undirected graph** to find all bridges and articulation points.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: nil)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: nil)
      iex> results = Yog.Connectivity.analyze(in: graph)
      iex> results.bridges
      [{1, 2}, {2, 3}]
      iex> results.articulation_points
      [2]
  """
  @spec analyze(keyword() | Yog.graph()) :: connectivity_results()
  defdelegate analyze(options_or_graph), to: Analysis

  @doc """
  Finds Strongly Connected Components (SCC) using Tarjan's Algorithm.
  """
  @spec strongly_connected_components(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate strongly_connected_components(graph), to: SCC

  @doc """
  Alias for `strongly_connected_components/1`.
  """
  @spec scc(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate scc(graph), to: SCC, as: :strongly_connected_components

  @doc """
  Finds Strongly Connected Components (SCC) using Kosaraju's Algorithm.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> sccs = Yog.Connectivity.kosaraju(graph)
      iex> hd(sccs) |> Enum.sort()
      [1, 2, 3]
  """
  @spec kosaraju(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate kosaraju(graph), to: SCC

  @doc """
  Finds Connected Components in an **undirected graph**.

  ## Example

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_node(4, "D")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex> components = Yog.Connectivity.connected_components(graph)
      iex> Enum.map(components, &Enum.sort/1) |> Enum.sort()
      [[1, 2], [3, 4]]
  """
  @spec connected_components(Yog.graph()) :: [component()]
  defdelegate connected_components(graph), to: Components

  @doc """
  Finds Weakly Connected Components in a **directed graph**.

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 2, with: 1)
      iex> wccs = Yog.Connectivity.weakly_connected_components(graph)
      iex> hd(wccs) |> Enum.sort()
      [1, 2, 3]
  """
  @spec weakly_connected_components(Yog.graph()) :: [component()]
  defdelegate weakly_connected_components(graph), to: Components

  @doc """
  Extracts the k-core of a graph (maximal subgraph with minimum degree k).

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 4, 1, nil)
      ...> |> Yog.add_edge_ensure(4, 1, 1, nil)
      iex> core_2 = Yog.Connectivity.k_core(graph, 2)
      iex> Yog.node_count(core_2)
      4
  """
  @spec k_core(Yog.graph(), integer()) :: Yog.graph()
  defdelegate k_core(graph, k), to: KCore, as: :detect

  @doc """
  Calculates all core numbers for all nodes in the graph.
  """
  @spec core_numbers(Yog.graph()) :: %{Yog.node_id() => integer()}
  defdelegate core_numbers(graph), to: KCore

  @doc """
  Finds the degeneracy of the graph, which is the maximum core number.
  """
  @spec degeneracy(Yog.graph()) :: integer()
  defdelegate degeneracy(graph), to: KCore
end
