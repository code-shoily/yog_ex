defmodule Yog.Traversal do
  @moduledoc """
  Graph traversal algorithms.

  Supports breadth-first search (BFS) and depth-first search (DFS) with
  optional early termination, fold-based traversal with metadata,
  implicit graph traversal, and cycle detection.

  ## Examples

      # BFS traversal
      nodes = Yog.Traversal.walk(
        from: 1,
        in: graph,
        using: :breadth_first
      )

      # Fold with metadata (depth, parent)
      result = Yog.Traversal.fold_walk(
        over: graph,
        from: 1,
        using: :breadth_first,
        initial: [],
        with: fn acc, node_id, meta ->
          {:continue, [{node_id, meta.depth} | acc]}
        end
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

    :yog@traversal.walk(graph, from, gleam_order)
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

    :yog@traversal.walk_until(graph, from, gleam_order, should_stop)
  end

  @doc """
  Fold over nodes during traversal with metadata (depth, parent).

  The folder function receives `(accumulator, node_id, metadata)` where
  metadata is `%{depth: integer, parent: node_id | nil}`.

  The folder returns `{control, new_accumulator}` where control is:
  - `:continue` — explore successors normally
  - `:stop` — skip this node's successors, continue with other queued nodes
  - `:halt` — stop the entire traversal immediately

  ## Options

  - `:over` - The graph to traverse
  - `:from` - Starting node ID
  - `:using` - `:breadth_first` or `:depth_first`
  - `:initial` - Initial accumulator value
  - `:with` - Folder function `(acc, node_id, metadata) -> {control, acc}`

  ## Examples

      # Collect nodes within depth 2
      result = Yog.Traversal.fold_walk(
        over: graph,
        from: 1,
        using: :breadth_first,
        initial: [],
        with: fn acc, node_id, meta ->
          if meta.depth <= 2 do
            {:continue, [node_id | acc]}
          else
            {:stop, acc}
          end
        end
      )
  """
  def fold_walk(opts) do
    graph = Keyword.fetch!(opts, :over)
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    folder = Keyword.fetch!(opts, :with)

    # Wrap the Elixir folder to bridge the Gleam WalkMetadata type
    gleam_folder = fn acc, node_id, walk_metadata ->
      # WalkMetadata is {:walk_metadata, depth, parent}
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node_id, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    gleam_order =
      case order do
        :breadth_first -> :breadth_first
        :depth_first -> :depth_first
      end

    :yog@traversal.fold_walk(graph, from, gleam_order, initial, gleam_folder)
  end

  @doc """
  Traverse implicit graphs using BFS or DFS without materializing a `Graph`.

  Provide a `successors_of` function that computes neighbors on demand.

  ## Options

  - `:from` - Starting state
  - `:using` - `:breadth_first` or `:depth_first`
  - `:initial` - Initial accumulator value
  - `:successors_of` - `fn state -> [state]`
  - `:with` - Folder `(acc, state, metadata) -> {control, acc}`

  The metadata map has `:depth` and `:parent` keys.
  """
  def implicit_fold(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    gleam_folder = fn acc, node, walk_metadata ->
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    :yog@traversal.implicit_fold(from, order, initial, successors, gleam_folder)
  end

  @doc """
  Like `implicit_fold/1`, but deduplicates visited nodes by a custom key.

  Additional option:
  - `:visited_by` - `fn state -> key` for deduplication
  """
  def implicit_fold_by(opts) do
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    visited_by = Keyword.fetch!(opts, :visited_by)
    folder = Keyword.fetch!(opts, :with)

    gleam_folder = fn acc, node, walk_metadata ->
      {:walk_metadata, depth, parent} = walk_metadata

      elixir_parent =
        case parent do
          {:some, p} -> p
          :none -> nil
        end

      elixir_meta = %{depth: depth, parent: elixir_parent}

      case folder.(acc, node, elixir_meta) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    :yog@traversal.implicit_fold_by(from, order, initial, successors, visited_by, gleam_folder)
  end

  @doc """
  Traverses an *implicit* weighted graph using Dijkstra's algorithm,
  folding over visited nodes in order of increasing cost.

  Like `implicit_fold` but uses a priority queue so nodes are visited
  cheapest-first. Ideal for shortest-path problems on implicit state spaces
  where edge costs vary.

  ## Options

  - `:from` - Starting state
  - `:initial` - Initial accumulator value
  - `:successors_of` - `fn state -> [{neighbor, cost}]` returns neighbors with edge costs
  - `:with` - Folder function `(acc, node, cost_so_far) -> {control, acc}`

  The folder receives the accumulated cost to reach the node as the third argument.
  Control values: `:continue`, `:stop`, `:halt`.

  ## Examples

      # Find shortest path cost to target
      result = Yog.Traversal.implicit_dijkstra(
        from: 1,
        initial: -1,
        successors_of: fn n ->
          case n do
            1 -> [{2, 10}, {3, 5}]
            2 -> [{4, 1}]
            3 -> [{4, 2}]
            _ -> []
          end
        end,
        with: fn _acc, node, cost ->
          if node == 4 do
            {:halt, cost}  # Found target, return cost
          else
            {:continue, -1}
          end
        end
      )
      #=> 7  (shortest path: 1->3->4 with cost 5+2=7)
  """
  def implicit_dijkstra(opts) do
    from = Keyword.fetch!(opts, :from)
    initial = Keyword.fetch!(opts, :initial)
    successors = Keyword.fetch!(opts, :successors_of)
    folder = Keyword.fetch!(opts, :with)

    gleam_folder = fn acc, node, cost ->
      case folder.(acc, node, cost) do
        {:continue, new_acc} -> {:continue, new_acc}
        {:stop, new_acc} -> {:stop, new_acc}
        {:halt, new_acc} -> {:halt, new_acc}
      end
    end

    :yog@traversal.implicit_dijkstra(from, initial, successors, gleam_folder)
  end

  @doc """
  Returns `true` if the graph contains at least one cycle.

  For directed graphs, uses topological sort. For undirected graphs,
  uses DFS-based cycle detection.

  **Time Complexity:** O(V + E)
  """
  @spec is_cyclic(Yog.graph()) :: boolean()
  defdelegate is_cyclic(graph), to: :yog@traversal

  @doc """
  Returns `true` if the graph contains no cycles (is a DAG or forest).

  **Time Complexity:** O(V + E)
  """
  @spec is_acyclic(Yog.graph()) :: boolean()
  defdelegate is_acyclic(graph), to: :yog@traversal

  @doc """
  Performs a standard topological sort using Kahn's algorithm.

  Returns `{:ok, [node_ids]}` if the graph is a DAG, or `{:error, :contains_cycle}` if
  the graph has a cycle (and therefore cannot be topologically sorted).
  """
  @spec topological_sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def topological_sort(graph) do
    case :yog@traversal.topological_sort(graph) do
      {:ok, order} -> {:ok, order}
      {:error, nil} -> {:error, :contains_cycle}
    end
  end

  @doc """
  Performs a lexicographical topological sort.

  When multiple nodes are available to be placed next in the sorted order, this
  variant strictly prefers the node with the \"smallest\" value based on the provided
  `compare` function, which operates on **node data** (not node IDs).
  """
  @spec lexicographical_topological_sort(Yog.graph(), fun()) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_topological_sort(graph, compare_fn) do
    case :yog@traversal.lexicographical_topological_sort(graph, compare_fn) do
      {:ok, order} -> {:ok, order}
      {:error, nil} -> {:error, :contains_cycle}
    end
  end

  @doc """
  Finds the shortest path between two nodes in an unweighted graph using BFS.

  Returns a list of node IDs forming the path, or `nil` if no path exists.
  """
  @spec find_path(Yog.graph(), Yog.node_id(), Yog.node_id()) :: [Yog.node_id()] | nil
  def find_path(graph, from, to) do
    if from == to do
      [from]
    else
      # We use fold_walk to build a parent map using BFS (shortest path for unweighted).
      parents =
        fold_walk(
          over: graph,
          from: from,
          using: :breadth_first,
          initial: %{},
          with: fn acc, node, meta ->
            acc = if meta.parent, do: Map.put(acc, node, meta.parent), else: acc

            if node == to do
              {:halt, acc}
            else
              {:continue, acc}
            end
          end
        )

      if Map.has_key?(parents, to) do
        reconstruct_path(parents, from, to, [to])
      else
        nil
      end
    end
  end

  defp reconstruct_path(_parents, start, start, path), do: path

  defp reconstruct_path(parents, start, target, path) do
    parent = Map.get(parents, target)
    reconstruct_path(parents, start, parent, [parent | path])
  end
end
