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
end
