defmodule Yog.BalancedTree do
  @moduledoc """
  A [GB Tree](https://www.erlang.org/doc/apps/stdlib/gb_trees.html) based priority queue.

  This module provides a priority queue backed by Erlang's `:gb_trees` implementation,
  which is a balanced binary tree written in C. This provides O(log n) performance
  for both insertions and deletions, making it suitable for algorithms with balanced
  push/pop ratios like Dijkstra's algorithm.

  ## Performance Characteristics

  - **Insert (push)**: O(log n)
  - **Delete-min (pop)**: O(log n)
  - **Peek**: O(log n) (performs pop without consuming)

  Compared to `Yog.PairingHeap`:
  - Better for balanced push/pop operations (e.g., Dijkstra where every push is popped)
  - Worse for push-heavy operations (e.g., A* where many nodes are pruned by heuristic)
  - Uses less memory for large queues

  ## Duplicate Keys

  Unlike `PairingHeap`, `BalancedTree` handles duplicate keys by using a unique
  counter suffix. This means duplicate values are preserved.

  ## Examples

      # Min-priority queue (default)
      pq = Yog.BalancedTree.new()
      |> Yog.BalancedTree.push(5)
      |> Yog.BalancedTree.push(3)
      |> Yog.BalancedTree.push(7)

      {:ok, 3, pq} = Yog.BalancedTree.pop(pq)

      # Priority queue for Dijkstra's algorithm
      pq = Yog.BalancedTree.new()
      |> Yog.BalancedTree.push({0, :start})
      |> Yog.BalancedTree.push({5, :a})
      |> Yog.BalancedTree.push({3, :b})
  """

  defstruct [:tree, :size, :counter]

  @typedoc "A balanced tree priority queue"
  @type t :: %__MODULE__{
          tree: :gb_trees.tree(),
          size: non_neg_integer(),
          counter: non_neg_integer()
        }

  @doc """
  Creates a new empty priority queue.

  ## Examples

      iex> pq = Yog.BalancedTree.new()
      iex> Yog.BalancedTree.empty?(pq)
      true
  """
  @spec new() :: t()
  def new do
    %__MODULE__{tree: :gb_trees.empty(), size: 0, counter: 0}
  end

  @doc """
  Checks if the priority queue is empty.

  ## Examples

      iex> Yog.BalancedTree.empty?(Yog.BalancedTree.new())
      true

      iex> Yog.BalancedTree.empty?(Yog.BalancedTree.new() |> Yog.BalancedTree.push(1))
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{size: 0}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Inserts a value into the priority queue.

  Values are ordered by Erlang term ordering (numbers, then atoms, then tuples, etc.)
  For custom ordering, wrap values in tuples where the first element is the sort key.

  Duplicate values are preserved using an internal counter.

  ## Examples

      iex> pq =
      ...>   Yog.BalancedTree.new()
      ...>   |> Yog.BalancedTree.push(5)
      ...>   |> Yog.BalancedTree.push(3)
      iex> Yog.BalancedTree.peek(pq)
      {:ok, 3}

      # For Dijkstra with custom ordering:
      iex> pq = Yog.BalancedTree.new()
      iex> pq = Yog.BalancedTree.push(pq, {5, :a})
      iex> pq = Yog.BalancedTree.push(pq, {3, :b})
      iex> {:ok, val, _} = Yog.BalancedTree.pop(pq)
      iex> val
      {3, :b}

      # Duplicates are preserved
      iex> pq = Yog.BalancedTree.new()
      iex> pq = Yog.BalancedTree.push(pq, 5)
      iex> pq = Yog.BalancedTree.push(pq, 5)
      iex> Yog.BalancedTree.size(pq)
      2
  """
  @spec push(t(), any()) :: t()
  def push(%__MODULE__{tree: tree, size: size, counter: counter} = pq, value) do
    # Use {value, counter} as key to allow duplicates
    # The counter ensures uniqueness while preserving ordering
    new_tree = :gb_trees.insert({value, counter}, nil, tree)
    %{pq | tree: new_tree, size: size + 1, counter: counter + 1}
  end

  @doc """
  Returns the minimum element without removing it.

  Returns `{:ok, value}` if the queue is not empty, `:error` otherwise.

  ## Examples

      iex> pq = Yog.BalancedTree.new() |> Yog.BalancedTree.push(5) |> Yog.BalancedTree.push(3)
      iex> Yog.BalancedTree.peek(pq)
      {:ok, 3}

      iex> Yog.BalancedTree.peek(Yog.BalancedTree.new())
      :error
  """
  @spec peek(t()) :: {:ok, any()} | :error
  def peek(%__MODULE__{size: 0}), do: :error

  def peek(%__MODULE__{tree: tree}) do
    {{value, _counter}, _} = :gb_trees.smallest(tree)
    {:ok, value}
  end

  @doc """
  Removes and returns the minimum element.

  Returns `{:ok, value, new_queue}` if the queue is not empty, `:error` otherwise.

  ## Examples

      iex> pq = Yog.BalancedTree.new() |> Yog.BalancedTree.push(5) |> Yog.BalancedTree.push(3) |> Yog.BalancedTree.push(7)
      iex> {:ok, min, pq} = Yog.BalancedTree.pop(pq)
      iex> min
      3
      iex> {:ok, next_min, _} = Yog.BalancedTree.pop(pq)
      iex> next_min
      5
  """
  @spec pop(t()) :: {:ok, any(), t()} | :error
  def pop(%__MODULE__{size: 0}), do: :error

  def pop(%__MODULE__{tree: tree, size: size} = pq) do
    {{value, _counter}, _, new_tree} = :gb_trees.take_smallest(tree)
    {:ok, value, %{pq | tree: new_tree, size: size - 1}}
  end

  @doc """
  Converts a list to a priority queue.

  ## Examples

      iex> pq = Yog.BalancedTree.from_list([3, 1, 4, 1, 5])
      iex> {:ok, min, _} = Yog.BalancedTree.pop(pq)
      iex> min
      1
  """
  @spec from_list([any()]) :: t()
  def from_list(list) do
    List.foldl(list, new(), fn x, acc -> push(acc, x) end)
  end

  @doc """
  Converts the priority queue to a sorted list.

  ## Examples

      iex> Yog.BalancedTree.new()
      ...> |> Yog.BalancedTree.push(3)
      ...> |> Yog.BalancedTree.push(1)
      ...> |> Yog.BalancedTree.push(2)
      ...> |> Yog.BalancedTree.to_list()
      [1, 2, 3]
  """
  @spec to_list(t()) :: [any()]
  def to_list(pq), do: to_list(pq, [])

  defp to_list(%__MODULE__{size: 0}, acc), do: Enum.reverse(acc)

  defp to_list(pq, acc) do
    case pop(pq) do
      {:ok, v, new_pq} -> to_list(new_pq, [v | acc])
      :error -> Enum.reverse(acc)
    end
  end

  @doc """
  Returns the number of elements in the queue.

  ## Examples

      iex> Yog.BalancedTree.new()
      ...> |> Yog.BalancedTree.push(1)
      ...> |> Yog.BalancedTree.push(2)
      ...> |> Yog.BalancedTree.size()
      2
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{size: s}), do: s
end
