defmodule Yog.MinCut do
  @moduledoc """
  Global minimum cut algorithms for undirected graphs.

  This module provides convenient access to the `Yog.Flow.MinCut` module
  for finding the global minimum cut in undirected graphs.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Stoer-Wagner](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm) | `global_min_cut/1` | O(V³) | Dense undirected graphs |

  ## Example

      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])

      result = Yog.MinCut.global_min_cut(graph)
      # => %{weight: 3, group_a_size: 1, group_b_size: 2}

  ## References

  - [Wikipedia: Minimum Cut](https://en.wikipedia.org/wiki/Minimum_cut)
  - [Wikipedia: Stoer-Wagner Algorithm](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm)
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

  ## Example

      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])

      result = Yog.MinCut.global_min_cut(graph)
      # => %{weight: 3, group_a_size: 1, group_b_size: 2}

  ## Notes

  - The graph must be undirected
  - Edge weights must be integers
  - The result gives partition sizes, not the actual node partitions
  """
  @spec global_min_cut(Yog.graph()) :: min_cut()
  defdelegate global_min_cut(graph), to: Yog.Flow.MinCut
end
