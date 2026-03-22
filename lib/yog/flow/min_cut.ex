defmodule Yog.Flow.MinCut do
  @moduledoc """
  Global minimum cut algorithms for undirected graphs.

  This module finds the [global minimum cut](https://en.wikipedia.org/wiki/Minimum_cut)
  in an undirected weighted graph - the partition of nodes into two non-empty sets
  that minimizes the total weight of edges crossing between the sets.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Stoer-Wagner](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm) | `global_min_cut/1` | O(V³) | Dense undirected graphs |

  The Stoer-Wagner algorithm uses [Maximum Adjacency Search (MAS)](https://en.wikipedia.org/wiki/Maximum_adjacency_search)
  to iteratively identify minimum s-t cuts and contract nodes, similar to how
  Prim's algorithm builds a minimum spanning tree but selecting by maximum edge weight.

  ## Key Concepts

  - **Global Min-Cut**: The minimum cut over all possible partitions of the graph
  - **s-t Cut**: A cut that separates specific nodes s and t
  - **Maximum Adjacency Search**: Orders vertices by strength of connection to current set
  - **Node Contraction**: Merging two nodes while preserving edge weights

  ## Comparison with s-t Min-Cut

  For finding a cut between specific source and sink nodes, use `Yog.Flow.MaxFlow` instead:
  - `Yog.Flow.MaxFlow.edmonds_karp/8` + `extract_min_cut/1`: O(VE²), for directed graphs
  - `Yog.Flow.MinCut.global_min_cut/1`: O(V³), for undirected graphs, finds best cut globally

  ## Use Cases

  - **Network reliability**: Identify weakest points in communication networks
  - **Image segmentation**: Separate foreground from background in computer vision
  - **Clustering**: Graph partitioning for community detection
  - **VLSI design**: Circuit partitioning to minimize wire crossings

  ## Example

      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_node(4, "D")
        |> Yog.add_edges([
          {1, 2, 3},
          {1, 3, 4},
          {2, 3, 2},
          {2, 4, 5},
          {3, 4, 1}
        ])

      result = Yog.Flow.MinCut.global_min_cut(graph)
      # => %{weight: 3, group_a_size: 1, group_b_size: 3}
      # The minimum cut has weight 3, partitioning into groups of size 1 and 3

  ## References

  - [Wikipedia: Minimum Cut](https://en.wikipedia.org/wiki/Minimum_cut)
  - [Wikipedia: Stoer-Wagner Algorithm](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm)
  - [Wikipedia: Maximum Adjacency Search](https://en.wikipedia.org/wiki/Maximum_adjacency_search)
  - [CP-Algorithms: Stoer-Wagner](https://cp-algorithms.com/graph/stoer_wagner.html)
  """

  @typedoc """
  Result of a global minimum cut computation.

  Contains the cut weight and the sizes of the two partitions.
  """
  @type min_cut :: %{
          weight: integer(),
          group_a_size: integer(),
          group_b_size: integer()
        }

  @doc """
  Finds the global minimum cut of an undirected weighted graph using the
  Stoer-Wagner algorithm.

  Returns a map with the minimum cut weight and the sizes of the two partitions.

  **Time Complexity:** O(V³)

  ## Examples

  Simple triangle graph:

      iex> {:ok, graph} = Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])
      iex> result = Yog.Flow.MinCut.global_min_cut(graph)
      iex> result.group_a_size + result.group_b_size
      3

  A larger example:

      iex> {:ok, graph} = Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges([
      ...>     {1, 2, 3},
      ...>     {1, 3, 4},
      ...>     {2, 3, 2},
      ...>     {2, 4, 5},
      ...>     {3, 4, 1}
      ...>   ])
      iex> result = Yog.Flow.MinCut.global_min_cut(graph)
      iex> result.weight > 0
      true

  ## Notes

  - The graph must be undirected
  - Edge weights must be integers
  - The result gives partition sizes, not the actual node partitions
  """
  @spec global_min_cut(Yog.graph()) :: min_cut()
  def global_min_cut(graph) do
    result = :yog@flow@min_cut.global_min_cut(graph)
    wrap_min_cut(result)
  end

  # Private helper to wrap Gleam result into Elixir map
  defp wrap_min_cut({:min_cut, weight, group_a_size, group_b_size}) do
    %{
      weight: weight,
      group_a_size: group_a_size,
      group_b_size: group_b_size
    }
  end
end
