defmodule Yog.PriorityQueue do
  @moduledoc """
  A Priority Queue implementation based on [Pairing Heap](https://en.wikipedia.org/wiki/Pairing_heap).

  This module provides a priority queue with support for custom comparison functions,
  making it suitable for various graph algorithms like Dijkstra's, Prim's, and A*.

  Implementation inspired by [Gleamy Structures](https://github.com/schurhammer/gleamy_structures/blob/main/src/gleamy/pairing_heap.gleam)
  and [ex_algo](https://github.com/code-shoily/ex_algo/blob/main/lib/ex_algo/heap/pairing_heap.ex)

  ## Features

  - O(1) insertion
  - O(1) find-min
  - O(log n) amortized delete-min
  - Custom comparison functions for flexible ordering
  - Functional/persistent data structure

  ## Examples

      # Min-priority queue (default)
      pq = Yog.PriorityQueue.new()
      |> Yog.PriorityQueue.push(5)
      |> Yog.PriorityQueue.push(3)
      |> Yog.PriorityQueue.push(7)

      {:ok, 3, pq} = Yog.PriorityQueue.pop(pq)

      # Max-priority queue with custom comparator
      pq = Yog.PriorityQueue.new(fn a, b -> a >= b end)
      |> Yog.PriorityQueue.push({:node, 5})
      |> Yog.PriorityQueue.push({:node, 10})

      {:ok, {:node, 10}, _} = Yog.PriorityQueue.pop(pq)

      # Priority queue for Dijkstra's algorithm
      pq = Yog.PriorityQueue.new(fn {dist1, _}, {dist2, _} -> dist1 <= dist2 end)
      |> Yog.PriorityQueue.push({0, :start})
      |> Yog.PriorityQueue.push({5, :a})
      |> Yog.PriorityQueue.push({3, :b})
  """

  defmodule Node do
    @moduledoc false
    defstruct [:value, :compare_fn, children: [], size: 1]
  end

  defmodule Empty do
    @moduledoc false
    defstruct [:compare_fn, size: 0]
  end

  @type compare_fn :: (any(), any() -> boolean())
  @type t :: %Node{} | %Empty{}

  @doc """
  Creates a new empty priority queue.

  By default, uses natural ordering (min-heap for numbers).

  ## Examples

      iex> pq = Yog.PriorityQueue.new()
      iex> Yog.PriorityQueue.empty?(pq)
      true

      iex> pq = Yog.PriorityQueue.new(fn a, b -> a >= b end)  # max-heap
      iex> Yog.PriorityQueue.empty?(pq)
      true
  """
  @spec new() :: t()
  def new, do: %Empty{compare_fn: fn a, b -> a <= b end, size: 0}

  @spec new(compare_fn()) :: t()
  def new(compare_fn), do: %Empty{compare_fn: compare_fn, size: 0}

  @doc """
  Checks if the priority queue is empty.

  ## Examples

      iex> Yog.PriorityQueue.empty?(Yog.PriorityQueue.new())
      true

      iex> Yog.PriorityQueue.empty?(Yog.PriorityQueue.new() |> Yog.PriorityQueue.push(1))
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%Empty{}), do: true
  def empty?(%Node{}), do: false

  @doc """
  Inserts a value into the priority queue.

  ## Examples

      iex> pq = Yog.PriorityQueue.new() |> Yog.PriorityQueue.push(5) |> Yog.PriorityQueue.push(3)
      iex> Yog.PriorityQueue.peek(pq)
      {:ok, 3}
  """
  @spec push(t(), any()) :: t()
  def push(%Empty{compare_fn: cmp}, value), do: node(value, [], cmp)

  def push(%Node{compare_fn: cmp} = heap, value) do
    merge(heap, node(value, [], cmp), cmp)
  end

  @doc """
  Returns the minimum element without removing it.

  Returns `{:ok, value}` if the queue is not empty, `:error` otherwise.

  ## Examples

      iex> pq = Yog.PriorityQueue.new() |> Yog.PriorityQueue.push(5) |> Yog.PriorityQueue.push(3)
      iex> Yog.PriorityQueue.peek(pq)
      {:ok, 3}

      iex> Yog.PriorityQueue.peek(Yog.PriorityQueue.new())
      :error
  """
  @spec peek(t()) :: {:ok, any()} | :error
  def peek(%Empty{}), do: :error
  def peek(%Node{value: v}), do: {:ok, v}

  @doc """
  Removes and returns the minimum element.

  Returns `{:ok, value, new_queue}` if the queue is not empty, `:error` otherwise.

  ## Examples

      iex> pq = Yog.PriorityQueue.new() |> Yog.PriorityQueue.push(5) |> Yog.PriorityQueue.push(3) |> Yog.PriorityQueue.push(7)
      iex> {:ok, min, pq} = Yog.PriorityQueue.pop(pq)
      iex> min
      3
      iex> {:ok, next_min, _} = Yog.PriorityQueue.pop(pq)
      iex> next_min
      5
  """
  @spec pop(t()) :: {:ok, any(), t()} | :error
  def pop(%Empty{}), do: :error

  def pop(%Node{value: v, children: c, compare_fn: cmp}) do
    {:ok, v, combine(c, cmp)}
  end

  @doc """
  Converts a list to a priority queue.

  ## Examples

      iex> pq = Yog.PriorityQueue.from_list([3, 1, 4, 1, 5])
      iex> {:ok, min, _} = Yog.PriorityQueue.pop(pq)
      iex> min
      1
  """
  @spec from_list([any()]) :: t()
  def from_list(list), do: from_list(list, fn a, b -> a <= b end)

  @spec from_list([any()], compare_fn()) :: t()
  def from_list(list, compare_fn) do
    Enum.reduce(list, new(compare_fn), fn x, acc -> push(acc, x) end)
  end

  @doc """
  Converts the priority queue to a sorted list.

  ## Examples

      iex> Yog.PriorityQueue.new() |> Yog.PriorityQueue.push(3) |> Yog.PriorityQueue.push(1) |> Yog.PriorityQueue.push(2) |> Yog.PriorityQueue.to_list()
      [1, 2, 3]
  """
  @spec to_list(t()) :: [any()]
  def to_list(pq), do: to_list(pq, [])

  defp to_list(%Empty{}, acc), do: Enum.reverse(acc)

  defp to_list(pq, acc) do
    case pop(pq) do
      {:ok, v, new_pq} -> to_list(new_pq, [v | acc])
      :error -> Enum.reverse(acc)
    end
  end

  @doc """
  Returns the number of elements in the queue.

  ## Examples

      iex> Yog.PriorityQueue.new() |> Yog.PriorityQueue.push(1) |> Yog.PriorityQueue.push(2) |> Yog.PriorityQueue.size()
      2
  """
  @spec size(t()) :: non_neg_integer()
  def size(%Empty{size: s}), do: s
  def size(%Node{size: s}), do: s

  # Private functions

  defp node(value, children, compare_fn) do
    total_size = 1 + Enum.reduce(children, 0, fn %Node{size: s}, acc -> acc + s end)
    %Node{value: value, children: children, compare_fn: compare_fn, size: total_size}
  end

  defp merge(h, %Empty{}, _cmp), do: h
  defp merge(%Empty{}, h, _cmp), do: h

  defp merge(
         %Node{value: v1, children: c1, compare_fn: cmp} = h1,
         %Node{value: v2, children: c2} = h2,
         cmp
       ) do
    if cmp.(v1, v2) do
      node(v1, [h2 | c1], cmp)
    else
      node(v2, [h1 | c2], cmp)
    end
  end

  defp combine([], cmp), do: %Empty{compare_fn: cmp, size: 0}
  defp combine([h], _cmp), do: h

  defp combine([h1, h2 | rest], cmp) do
    merge(merge(h1, h2, cmp), combine(rest, cmp), cmp)
  end
end
