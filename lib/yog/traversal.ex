defmodule Yog.Traversal do
  @moduledoc """
  Graph traversal algorithms.

  Supports breadth-first search (BFS) and depth-first search (DFS) with
  optional early termination.

  ## Examples

      # BFS traversal
      nodes = Yog.Traversal.walk(
        from: 1,
        in: graph,
        using: :breadth_first
      )

      # DFS with early termination
      nodes = Yog.Traversal.walk_until(
        from: 1,
        in: graph,
        using: :depth_first,
        until: fn node_id -> node_id == 5 end
      )
  """

  @type order :: :breadth_first | :depth_first

  @doc """
  Traverses a graph from a starting node.

  Returns all reachable nodes in the order they were visited.

  ## Options

  - `:from` - Starting node ID
  - `:in` - The graph to traverse
  - `:using` - Traversal order (`:breadth_first` or `:depth_first`)

  ## Examples

      # Breadth-first traversal
      nodes = Yog.Traversal.walk(
        from: 1,
        in: graph,
        using: :breadth_first
      )
      #=> [1, 2, 3, 4, 5]

      # Depth-first traversal
      nodes = Yog.Traversal.walk(
        from: 1,
        in: graph,
        using: :depth_first
      )
      #=> [1, 2, 4, 5, 3]
  """
  @spec walk(keyword()) :: [integer()]
  def walk(opts) do
    from = Keyword.fetch!(opts, :from)
    graph = Keyword.fetch!(opts, :in)
    order = Keyword.fetch!(opts, :using)

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.walk(from, graph, gleam_order)
  end

  @doc """
  Traverses a graph with early termination.

  Stops when the predicate function returns `true` for a node.
  Returns all nodes visited including the one that stopped traversal.

  ## Options

  - `:from` - Starting node ID
  - `:in` - The graph to traverse
  - `:using` - Traversal order (`:breadth_first` or `:depth_first`)
  - `:until` - Predicate function that returns `true` to stop

  ## Examples

      # Stop when we find node 5
      nodes = Yog.Traversal.walk_until(
        from: 1,
        in: graph,
        using: :breadth_first,
        until: fn node_id -> node_id == 5 end
      )
      #=> [1, 2, 3, 5]

      # Stop when we find a node with specific data
      nodes = Yog.Traversal.walk_until(
        from: start,
        in: graph,
        using: :depth_first,
        until: fn node_id ->
          case :yog.get_node_data(graph, node_id) do
            {:ok, data} -> data == "goal"
            _ -> false
          end
        end
      )
  """
  @spec walk_until(keyword()) :: [integer()]
  def walk_until(opts) do
    from = Keyword.fetch!(opts, :from)
    graph = Keyword.fetch!(opts, :in)
    order = Keyword.fetch!(opts, :using)
    should_stop = Keyword.fetch!(opts, :until)

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.walk_until(from, graph, gleam_order, should_stop)
  end
end
