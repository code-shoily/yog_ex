defmodule Yog.DisjointSet do
  @moduledoc """
  Disjoint Set Union (Union-Find) data structure for efficient set operations.

  The disjoint-set data structure maintains a partition of elements into disjoint (non-overlapping)
  sets. It provides near-constant time operations to add elements, find which set an element
  belongs to, and merge two sets together.

  ## Key Operations

  | Operation | Function | Complexity |
  |-----------|----------|------------|
  | Make Set | `add/2` | O(1) |
  | Find | `find/2` | O(α(n)) amortized |
  | Union | `union/3` | O(α(n)) amortized |

  Where α(n) is the [inverse Ackermann function](https://en.wikipedia.org/wiki/Ackermann_function#Inverse),
  which grows so slowly that it is effectively a small constant (≤ 4) for all practical inputs.

  ## Optimizations

  This implementation uses two key optimizations:
  - **Path Compression**: Flattens the tree structure during find operations, making future queries faster
  - **Union by Rank**: Attaches the shorter tree under the taller tree to minimize tree height

  ## Use Cases

  - [Kruskal's MST algorithm](https://en.wikipedia.org/wiki/Kruskal%27s_algorithm) - detecting cycles
  - Connected components in dynamic graphs
  - Equivalence relations and partitioning
  - Percolation theory and network reliability

  ## References

  - [Wikipedia: Disjoint-set data structure](https://en.wikipedia.org/wiki/Disjoint-set_data_structure)
  - [CP-Algorithms: Disjoint Set Union](https://cp-algorithms.com/data_structures/disjoint_set_union.html)
  """

  @typedoc """
  Disjoint Set Union (Union-Find) data structure.

  Efficiently tracks a partition of elements into disjoint sets.
  Uses path compression and union by rank for near-constant time operations.

  **Time Complexity:** O(α(n)) amortized per operation, where α is the inverse Ackermann function
  """
  @type t :: term()

  @doc """
  Creates a new empty disjoint set structure.

  ## Example

      iex> dsu = Yog.DisjointSet.new()
      iex> Yog.DisjointSet.size(dsu)
      0
  """
  @spec new() :: t()
  defdelegate new(), to: :yog@disjoint_set

  @doc """
  Adds a new element to the disjoint set.

  The element starts in its own singleton set.
  If the element already exists, the structure is returned unchanged.

  ## Example

      iex> dsu =
      ...>   Yog.DisjointSet.new()
      ...>   |> Yog.DisjointSet.add(1)
      ...>   |> Yog.DisjointSet.add(2)
      iex> Yog.DisjointSet.size(dsu)
      2
  """
  @spec add(t(), term()) :: t()
  defdelegate add(dsu, element), to: :yog@disjoint_set

  @doc """
  Finds the representative (root) of the set containing the element.

  Uses path compression to flatten the tree structure for future queries.
  If the element doesn't exist, it's automatically added first.

  Returns a tuple of `{updated_disjoint_set, root}`.

  ## Example

      iex> dsu =
      ...>   Yog.DisjointSet.new()
      ...>   |> Yog.DisjointSet.add(1)
      ...>   |> Yog.DisjointSet.add(2)
      ...>   |> Yog.DisjointSet.union(1, 2)
      iex> {_, root} = Yog.DisjointSet.find(dsu, 1)
      iex> # Root is the representative of the set containing 1
      iex> is_integer(root)
      true
  """
  @spec find(t(), term()) :: {t(), term()}
  defdelegate find(dsu, element), to: :yog@disjoint_set

  @doc """
  Merges the sets containing the two elements.

  Uses union by rank to keep the tree balanced.
  If the elements are already in the same set, returns unchanged.

  ## Example

      iex> dsu =
      ...>   Yog.DisjointSet.new()
      ...>   |> Yog.DisjointSet.add(1)
      ...>   |> Yog.DisjointSet.add(2)
      ...>   |> Yog.DisjointSet.union(1, 2)
      iex> {_, root1} = Yog.DisjointSet.find(dsu, 1)
      iex> {_, root2} = Yog.DisjointSet.find(dsu, 2)
      iex> # Both elements now have the same root
      iex> root1 == root2
      true
  """
  @spec union(t(), term(), term()) :: t()
  defdelegate union(dsu, element_1, element_2), to: :yog@disjoint_set

  @doc """
  Creates a disjoint set from a list of pairs to union.

  This is a convenience function for building a disjoint set from edge lists
  or connection pairs. Perfect for graph problems, AoC, and competitive programming.

  ## Example

      iex> dsu = Yog.DisjointSet.from_pairs([{1, 2}, {3, 4}, {2, 3}])
      iex> # Results in: {1,2,3,4} as one set
      iex> {_, root1} = Yog.DisjointSet.find(dsu, 1)
      iex> {_, root4} = Yog.DisjointSet.find(dsu, 4)
      iex> root1 == root4
      true
  """
  @spec from_pairs([{term(), term()}]) :: t()
  defdelegate from_pairs(pairs), to: :yog@disjoint_set

  @doc """
  Checks if two elements are in the same set (connected).

  Returns the updated disjoint set (due to path compression) and a boolean result.

  ## Example

      iex> dsu = Yog.DisjointSet.from_pairs([{1, 2}, {3, 4}])
      iex> {_dsu2, result1} = Yog.DisjointSet.connected?(dsu, 1, 2)
      iex> result1
      true
      iex> {_dsu3, result2} = Yog.DisjointSet.connected?(dsu, 1, 3)
      iex> result2
      false
  """
  @spec connected?(t(), term(), term()) :: {t(), boolean()}
  def connected?(dsu, element_1, element_2) do
    :yog@disjoint_set.connected(dsu, element_1, element_2)
  end

  @doc """
  Returns the total number of elements in the structure.

  ## Example

      iex> dsu =
      ...>   Yog.DisjointSet.new()
      ...>   |> Yog.DisjointSet.add(1)
      ...>   |> Yog.DisjointSet.add(2)
      iex> Yog.DisjointSet.size(dsu)
      2
  """
  @spec size(t()) :: non_neg_integer()
  defdelegate size(dsu), to: :yog@disjoint_set

  @doc """
  Returns the number of disjoint sets.

  Counts the distinct sets by finding the unique roots.

  ## Example

      iex> dsu = Yog.DisjointSet.from_pairs([{1, 2}, {3, 4}])
      iex> # 2 sets: {1,2} and {3,4}
      iex> Yog.DisjointSet.count_sets(dsu)
      2
  """
  @spec count_sets(t()) :: non_neg_integer()
  defdelegate count_sets(dsu), to: :yog@disjoint_set

  @doc """
  Returns all disjoint sets as a list of lists.

  Each inner list contains all members of one set. The order of sets and
  elements within sets is unspecified.

  Note: This operation doesn't perform path compression, so the structure
  is not modified.

  ## Example

      iex> dsu = Yog.DisjointSet.from_pairs([{1, 2}, {3, 4}, {5, 6}])
      iex> result = Yog.DisjointSet.to_lists(dsu)
      iex> length(result)
      3
  """
  @spec to_lists(t()) :: [[term()]]
  defdelegate to_lists(dsu), to: :yog@disjoint_set
end
