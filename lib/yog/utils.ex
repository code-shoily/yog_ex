defmodule Yog.Utils do
  @moduledoc """
  Shared utility functions used across the Yog library.

  This module provides common helper functions that are used by multiple
  modules in the Yog library, such as comparison functions for custom
  numeric types.
  """

  @doc """
  A standard Gleam-compatible comparison function for numbers in Elixir.

  Many algorithms (like Dijkstra, A*, and centrality measures) require an
  explicit comparison function that returns `:lt`, `:eq`, or `:gt` to order
  values in priority queues. Writing this manually can be repetitive.

  This function evaluates to:
  - `:lt` when `a < b`
  - `:eq` when `a == b`
  - `:gt` when `a > b`

  It works for both integers and floats.

  While this function initially was influenced by the Gleamy origin of Yog,
  it felt more of a direction agnotic way to handle comparisons in algorithms
  that needed comparators passed into them, for instance, Dijkstra's algorithm
  could sometimes show `compare.(a, b) == true` but we would need to remember if
  it means a < b or a > b (what if the comparator passed in was > instead of < ?).

  We could name the parameter `less_than` and `greater_than` to address this, but
  ternary operator felt more explicit, especially in cases where the algorithms need
  for comparison would be direction agnostic. Having only :lt or :gt would add to
  confusion as to where it was `if a < b ... else ...` or `if a > b ... else ...`
  so a ternary outcome felt explicit (We have examples in `Version` and `Date`)

  ## Examples

      iex> Yog.Utils.compare(10, 20)
      :lt
      iex> Yog.Utils.compare(20, 20)
      :eq
      iex> Yog.Utils.compare(30, 20)
      :gt
      iex> Yog.Utils.compare(1.5, 3.2)
      :lt
  """
  @spec compare(number(), number()) :: :lt | :eq | :gt
  def compare(a, b) when a < b, do: :lt
  def compare(a, b) when a > b, do: :gt
  def compare(_, _), do: :eq

  @doc """
  Calculates the difference (distance) between two vectors (maps of scores)
  using the specified norm type.

  Supported types:
  - `:l1`  - Manhattan Distance (Sum of absolute differences)
  - `:l2`  - Euclidean Distance (Square root of sum of squares)
  - `:max` - Chebyshev Distance (Maximum absolute difference)

  ## Examples

      iex> Utils.norm_diff(%{a: 1, b: 2}, %{a: 3, b: 4}, :l1)
      4.0

      iex> Utils.norm_diff(%{a: 1, b: 2}, %{a: 3, b: 4}, :l2)
      2.8284271247461903

      iex> Utils.norm_diff(%{a: 1.1, b: 2}, %{a: 3, b: 4}, :max)
      2
  """
  @spec norm_diff(map(), map(), :l1 | :l2 | :max) :: number()
  def norm_diff(m1, m2, type) do
    case type do
      :l1 ->
        Enum.reduce(m1, 0.0, fn {k, v1}, acc ->
          acc + abs(v1 - Map.get(m2, k, 0.0))
        end)

      :l2 ->
        sum_sq =
          Enum.reduce(m1, 0.0, fn {k, v1}, acc ->
            acc + :math.pow(v1 - Map.get(m2, k, 0.0), 2)
          end)

        :math.sqrt(sum_sq)

      :max ->
        Enum.reduce(m1, 0.0, fn {k, v1}, acc ->
          max(acc, abs(v1 - Map.get(m2, k, 0.0)))
        end)
    end
  end

  @doc """
  Fisher-Yates shuffle: O(n) unbiased shuffling.

  Uses Erlang's :array for efficient mutable-style operations.
  Deterministic when given a seed (for reproducibility).

  ## Examples

      iex> Yog.Utils.fisher_yates([1, 2, 3, 4, 5], 42)
      [3, 2, 5, 4, 1]

      iex> Yog.Utils.fisher_yates([], 123)
      []
  """
  @spec fisher_yates([a], integer()) :: [a] when a: var
  def fisher_yates(list, seed \\ :rand.uniform(1_000_000)) do
    n = length(list)

    if n <= 1 do
      list
    else
      arr = :array.from_list(list)
      a = 1_103_515_245
      c = 12_345
      m = 2_147_483_648

      {shuffled_arr, _final_seed} =
        Enum.reduce(0..(n - 2), {arr, seed}, fn i, {arr_acc, current_seed} ->
          next_seed = rem(a * current_seed + c, m)
          j = i + rem(next_seed, n - i)

          val_i = :array.get(i, arr_acc)
          val_j = :array.get(j, arr_acc)
          arr_acc = :array.set(i, val_j, arr_acc)
          arr_acc = :array.set(j, val_i, arr_acc)

          {arr_acc, next_seed}
        end)

      :array.to_list(shuffled_arr)
    end
  end

  @doc """
  Generates all k-combinations of a list.

  A k-combination is a subset of k distinct elements from the list,
  where order does not matter.

  ## Examples

      iex> Yog.Utils.combinations([1, 2, 3], 2)
      [[1, 2], [1, 3], [2, 3]]

      iex> Yog.Utils.combinations([1, 2, 3], 0)
      [[]]
  """
  @spec combinations([a], integer()) :: [[a]] when a: var
  def combinations(_list, 0), do: [[]]
  def combinations([], _k), do: []

  def combinations([h | t], k) do
    with_h = for(l <- combinations(t, k - 1), do: [h | l])
    without_h = combinations(t, k)
    with_h ++ without_h
  end

  @doc """
  Folds over a map using the fast BIF `:maps.fold/3`.

  This is a wrapper around `:maps.fold/3` with a more Elixir-friendly API:
  - Data (map) comes first (like `Enum.reduce`)
  - Followed by the initial accumulator
  - Then the function with arity 3: `(key, value, acc) -> new_acc`

  This avoids the overhead of `Enum.reduce` protocol dispatch and eliminates
  the need for `Map.to_list` + `List.foldl` which creates intermediate lists.

  ## Performance Comparison

  | Approach | Speed | Notes |
  |----------|-------|-------|
  | `Yog.Utils.map_fold/3` | **Fastest** | Direct BIF call, no allocation |
  | `:maps.fold/3` | **Fastest** | Same as above, but awkward argument order |
  | `Enum.reduce(map, ...)` | Slower | Protocol dispatch overhead |
  | `List.foldl(Map.to_list(map), ...)` | Slowest | Allocates intermediate list |

  ## Examples

      iex> map = %{a: 1, b: 2, c: 3}
      iex> Yog.Utils.map_fold(map, 0, fn _k, v, acc -> acc + v end)
      6

      iex> map = %{x: 10, y: 20}
      iex> Yog.Utils.map_fold(map, %{}, fn k, v, acc -> Map.put(acc, k, v * 2) end)
      %{x: 20, y: 40}

  ## When to Use

  Use this function when:
  - You need to iterate over a map's key-value pairs
  - Performance matters (hot paths, large maps)
  - You don't need the generic `Enumerable` protocol features

  For lists, use `List.foldl/3` instead. For other enumerables, use `Enum.reduce/3`.
  """
  @spec map_fold(map(), acc, (key, value, acc -> acc)) :: acc
        when key: any(), value: any(), acc: var
  def map_fold(map, acc, fun) when is_map(map) and is_function(fun, 3) do
    :maps.fold(fun, acc, map)
  end
end
