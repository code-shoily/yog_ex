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

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  @typedoc """
  Disjoint Set Union (Union-Find) data structure.

  Efficiently tracks a partition of elements into disjoint sets.
  Uses path compression and union by rank for near-constant time operations.

  **Time Complexity:** O(α(n)) amortized per operation, where α is the inverse Ackermann function
  """
  @type t :: {:disjoint_set, map(), map()}

  @doc """
  Creates a new empty disjoint set structure.

  ## Example

      iex> dsu = Yog.DisjointSet.new()
      iex> Yog.DisjointSet.size(dsu)
      0
  """
  @spec new() :: t()
  def new do
    {:disjoint_set, %{}, %{}}
  end

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
  def add({:disjoint_set, parents, ranks}, element) do
    if Map.has_key?(parents, element) do
      {:disjoint_set, parents, ranks}
    else
      new_parents = Map.put(parents, element, element)
      new_ranks = Map.put(ranks, element, 0)
      {:disjoint_set, new_parents, new_ranks}
    end
  end

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
  def find({:disjoint_set, parents, ranks} = dsu, element) do
    case Map.fetch(parents, element) do
      :error ->
        # Element not found, add it and return as its own root
        new_dsu = add(dsu, element)
        {new_dsu, element}

      {:ok, parent} when parent == element ->
        # Element is its own parent (root)
        {dsu, element}

      {:ok, parent} ->
        # Recursively find root with path compression
        {updated_dsu, root} = find({:disjoint_set, parents, ranks}, parent)
        # Compress path: point element directly to root
        new_parents = Map.put(updated_dsu |> elem(1), element, root)
        {{:disjoint_set, new_parents, updated_dsu |> elem(2)}, root}
    end
  end

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
  def union(dsu, x, y) do
    {dsu1, root_x} = find(dsu, x)
    {dsu2, root_y} = find(dsu1, y)

    if root_x == root_y do
      dsu2
    else
      do_union_by_rank(dsu2, root_x, root_y)
    end
  end

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
  def from_pairs(pairs) do
    Enum.reduce(pairs, new(), fn {x, y}, acc ->
      union(acc, x, y)
    end)
  end

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
  def connected?(dsu, x, y) do
    {dsu1, root_x} = find(dsu, x)
    {dsu2, root_y} = find(dsu1, y)
    {dsu2, root_x == root_y}
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
  def size({:disjoint_set, parents, _ranks}) do
    map_size(parents)
  end

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
  def count_sets({:disjoint_set, parents, _ranks} = dsu) do
    parents
    |> Map.keys()
    |> Enum.map(fn element -> find_root_readonly(dsu, element) end)
    |> Enum.uniq()
    |> length()
  end

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
  def to_lists({:disjoint_set, parents, _ranks} = dsu) do
    parents
    |> Map.keys()
    |> Enum.reduce(%{}, fn element, acc ->
      root = find_root_readonly(dsu, element)

      Map.update(acc, root, [element], fn members ->
        [element | members]
      end)
    end)
    |> Map.values()
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  # Unions two sets by their ranks (internal helper).
  # Precondition: root_x and root_y are different roots.
  defp do_union_by_rank({:disjoint_set, parents, ranks}, root_x, root_y) do
    rank_x = Map.get(ranks, root_x, 0)
    rank_y = Map.get(ranks, root_y, 0)

    cond do
      rank_x < rank_y ->
        # Attach x's tree under y's tree
        new_parents = Map.put(parents, root_x, root_y)
        {:disjoint_set, new_parents, ranks}

      rank_x >= rank_y ->
        # Attach y's tree under x's tree
        new_parents = Map.put(parents, root_y, root_x)

        # If ranks are equal, increment x's rank
        new_ranks =
          if rank_x == rank_y do
            Map.put(ranks, root_x, rank_x + 1)
          else
            ranks
          end

        {:disjoint_set, new_parents, new_ranks}
    end
  end

  # Finds root without path compression (read-only operation).
  # Used by count_sets and to_lists to avoid modifying structure.
  defp find_root_readonly({:disjoint_set, parents, _ranks}, element) do
    case Map.fetch(parents, element) do
      :error ->
        element

      {:ok, parent} when parent == element ->
        element

      {:ok, parent} ->
        find_root_readonly({:disjoint_set, parents, %{}}, parent)
    end
  end
end
