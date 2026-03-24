defmodule Yog.PQ do
  @moduledoc """
  A Priority Queue implementation based on Pairing Heap.

  This module provides a priority queue with support for custom comparison functions,
  making it suitable for various graph algorithms like Dijkstra's, Prim's, and A*.

  ## Features

  - O(1) insertion
  - O(1) find-min
  - O(log n) amortized delete-min
  - Custom comparison functions for flexible ordering
  - Functional/persistent data structure

  ## Examples

      # Min-priority queue (default)
      pq = Yog.PQ.new()
      |> Yog.PQ.push(5)
      |> Yog.PQ.push(3)
      |> Yog.PQ.push(7)

      {3, pq} = Yog.PQ.pop(pq)

      # Max-priority queue with custom comparator
      pq = Yog.PQ.new(fn a, b -> a >= b end)
      |> Yog.PQ.push({:node, 5})
      |> Yog.PQ.push({:node, 10})

      {{:node, 10}, pq} = Yog.PQ.pop(pq)

      # Priority queue for Dijkstra's algorithm
      pq = Yog.PQ.new(fn {dist1, _}, {dist2, _} -> dist1 <= dist2 end)
      |> Yog.PQ.push({0, :start})
      |> Yog.PQ.push({5, :a})
      |> Yog.PQ.push({3, :b})
  """

  defmodule Node do
    @moduledoc false
    defstruct [:value, :compare_fn, children: []]
  end

  defmodule Empty do
    @moduledoc false
    defstruct [:compare_fn]
  end

  @type compare_fn :: (any(), any() -> boolean())
  @type t :: %Node{} | %Empty{}

  @doc """
  Creates a new empty priority queue.

  By default, uses natural ordering (min-heap for numbers).

  ## Examples

      iex> pq = Yog.PQ.new()
      iex> Yog.PQ.empty?(pq)
      true

      iex> pq = Yog.PQ.new(fn a, b -> a >= b end)  # max-heap
      iex> Yog.PQ.empty?(pq)
      true
  """
  @spec new() :: t()
  def new, do: %Empty{compare_fn: fn a, b -> a <= b end}

  @spec new(compare_fn()) :: t()
  def new(compare_fn), do: %Empty{compare_fn: compare_fn}

  @doc """
  Checks if the priority queue is empty.

  ## Examples

      iex> Yog.PQ.empty?(Yog.PQ.new())
      true

      iex> Yog.PQ.empty?(Yog.PQ.new() |> Yog.PQ.push(1))
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%Empty{}), do: true
  def empty?(%Node{}), do: false

  @doc """
  Inserts a value into the priority queue.

  ## Examples

      iex> pq = Yog.PQ.new() |> Yog.PQ.push(5) |> Yog.PQ.push(3)
      iex> Yog.PQ.peek(pq)
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

      iex> pq = Yog.PQ.new() |> Yog.PQ.push(5) |> Yog.PQ.push(3)
      iex> Yog.PQ.peek(pq)
      {:ok, 3}

      iex> Yog.PQ.peek(Yog.PQ.new())
      :error
  """
  @spec peek(t()) :: {:ok, any()} | :error
  def peek(%Empty{}), do: :error
  def peek(%Node{value: v}), do: {:ok, v}

  @doc """
  Removes and returns the minimum element.

  Returns `{:ok, value, new_queue}` if the queue is not empty, `:error` otherwise.

  ## Examples

      iex> pq = Yog.PQ.new() |> Yog.PQ.push(5) |> Yog.PQ.push(3) |> Yog.PQ.push(7)
      iex> {:ok, min, pq} = Yog.PQ.pop(pq)
      iex> min
      3
      iex> {:ok, next_min, _} = Yog.PQ.pop(pq)
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

      iex> pq = Yog.PQ.from_list([3, 1, 4, 1, 5])
      iex> {:ok, min, _} = Yog.PQ.pop(pq)
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

      iex> Yog.PQ.new() |> Yog.PQ.push(3) |> Yog.PQ.push(1) |> Yog.PQ.push(2) |> Yog.PQ.to_list()
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

      iex> Yog.PQ.new() |> Yog.PQ.push(1) |> Yog.PQ.push(2) |> Yog.PQ.size()
      2
  """
  @spec size(t()) :: non_neg_integer()
  def size(%Empty{}), do: 0
  def size(%Node{children: c}), do: 1 + Enum.reduce(c, 0, fn child, acc -> acc + size(child) end)

  # Private functions

  defp node(value, children, compare_fn) do
    %Node{value: value, children: children, compare_fn: compare_fn}
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

  defp combine([], cmp), do: %Empty{compare_fn: cmp}
  defp combine([h], _cmp), do: h

  defp combine([h1, h2 | rest], cmp) do
    merge(merge(h1, h2, cmp), combine(rest, cmp), cmp)
  end
end
