defmodule Yog.Property.Bipartite do
  @moduledoc """
  [Bipartite graph](https://en.wikipedia.org/wiki/Bipartite_graph) analysis and matching algorithms.

  A graph is bipartite (2-colorable) if its vertices can be divided into two disjoint sets
  such that every edge connects a vertex in one set to a vertex in the other set.
  Equivalently, a bipartite graph contains no odd-length cycles.

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Bipartite check | [BFS 2-coloring](https://en.wikipedia.org/wiki/Bipartite_graph#Testing_bipartiteness) | `bipartite?/1`, `partition/1` | O(V + E) |
  | Maximum matching | [Augmenting paths](https://en.wikipedia.org/wiki/Matching_(graph_theory)) | `maximum_matching/2` | O(VE) |
  | Stable matching | [Gale-Shapley](https://en.wikipedia.org/wiki/Gale%E2%80%93Shapley_algorithm) | `stable_marriage/2` | O(V²) |

  ## Key Concepts

  - **Bipartite Graph**: Vertices partitioned into two sets L and R, edges only go between sets
  - **2-Coloring**: Adjacent vertices always have different colors (equivalent to bipartite)
  - **Matching**: Set of edges without common vertices
  - **Maximum Matching**: Matching with largest possible number of edges
  - **Perfect Matching**: Every vertex is matched (requires |L| = |R|)
  - **Stable Matching**: No unmatched pair prefers each other over current matches

  ## Characterizations of Bipartite Graphs

  A graph is bipartite if and only if:
  - It is 2-colorable
  - It contains no odd-length cycles
  - Its spectrum is symmetric about 0

  ## König's Theorem

  In bipartite graphs, the size of the maximum matching equals the size of the
  minimum vertex cover. This is a fundamental result that doesn't hold for general graphs.

  ## Use Cases

  - **Job assignment**: Workers to tasks they can perform
  - **Scheduling**: Time slots to events without conflicts
  - **Recommendation systems**: Users to items they might like
  - **Chemistry**: Matching molecules for reactions
  - **Stable marriage**: Matching medical residents to hospitals

  ## Examples

      # Check if a graph is bipartite
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex> Yog.Property.Bipartite.bipartite?(graph)
      true

      # Get the partition
      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_node(4, nil)
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...>   |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex> {:ok, %{left: left, right: right}} = Yog.Property.Bipartite.partition(graph)
      iex> MapSet.size(left) + MapSet.size(right)
      4

  ## References

  - [Wikipedia: Bipartite Graph](https://en.wikipedia.org/wiki/Bipartite_graph)
  - [Wikipedia: Graph Coloring](https://en.wikipedia.org/wiki/Graph_coloring)
  - [Wikipedia: Matching](https://en.wikipedia.org/wiki/Matching_(graph_theory))
  - [Wikipedia: Gale-Shapley Algorithm](https://en.wikipedia.org/wiki/Gale%E2%80%93Shapley_algorithm)
  - [CP-Algorithms: Bipartite Check](https://cp-algorithms.com/graph/bipartite-check.html)
  """

  alias Yog.Model

  @typedoc """
  A partition of a bipartite graph into two independent sets.
  In a bipartite graph, all edges connect vertices from `left` to `right`,
  with no edges within `left` or within `right`.
  """
  @type partition :: %{left: MapSet.t(Yog.node_id()), right: MapSet.t(Yog.node_id())}

  @doc """
  Determines if a graph is bipartite (2-colorable).
  Works for both directed and undirected graphs.

  A graph is bipartite if its vertices can be divided into two disjoint sets
  such that every edge connects a vertex in one set to a vertex in the other set.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Property.Bipartite.bipartite?(graph)
      true

      # Odd cycle (triangle) is not bipartite
      iex> triangle = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Property.Bipartite.bipartite?(triangle)
      false

  ## Time Complexity

  O(V + E)
  """
  @spec bipartite?(Yog.graph()) :: boolean()
  def bipartite?(graph) do
    case do_partition(graph) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Returns the two partitions of a bipartite graph, or an error if not bipartite.

  Uses BFS with 2-coloring to detect bipartiteness and construct the partitions.
  Handles disconnected graphs by checking all components.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex> {:ok, %{left: left, right: right}} = Yog.Property.Bipartite.partition(graph)
      iex> MapSet.size(left) == 2 and MapSet.size(right) == 2
      true

      # Not bipartite - odd cycle
      iex> triangle = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Property.Bipartite.partition(triangle)
      {:error, :not_bipartite}

  ## Time Complexity

  O(V + E)
  """
  @spec partition(Yog.graph()) ::
          {:ok, %{left: MapSet.t(Yog.node_id()), right: MapSet.t(Yog.node_id())}}
          | {:error, :not_bipartite}
  def partition(graph), do: do_partition(graph)

  defp do_partition(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      {:ok, %{left: MapSet.new(), right: MapSet.new()}}
    else
      # BFS coloring: 0 = unvisited, 1 = color A, 2 = color B
      # Use a map to track colors
      case bfs_color_all(graph, nodes, %{}) do
        {:ok, colors} ->
          left =
            colors
            |> Enum.filter(fn {_, color} -> color == 1 end)
            |> Enum.map(&elem(&1, 0))
            |> MapSet.new()

          right =
            colors
            |> Enum.filter(fn {_, color} -> color == 2 end)
            |> Enum.map(&elem(&1, 0))
            |> MapSet.new()

          {:ok, %{left: left, right: right}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Process all components (handles disconnected graphs)
  defp bfs_color_all(graph, nodes, colors) do
    Enum.reduce_while(nodes, {:ok, colors}, fn node, {:ok, acc_colors} ->
      if Map.has_key?(acc_colors, node) do
        {:cont, {:ok, acc_colors}}
      else
        case bfs_color_component(graph, node, acc_colors) do
          {:ok, new_colors} -> {:cont, {:ok, new_colors}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end
    end)
  end

  # BFS color a single connected component starting from source
  defp bfs_color_component(graph, source, colors) do
    queue = :queue.in({source, 1}, :queue.new())
    colors = Map.put(colors, source, 1)

    do_bfs_color(graph, queue, colors)
  end

  defp do_bfs_color(graph, queue, colors) do
    case :queue.out(queue) do
      {{:value, {node, color}}, rest} ->
        next_color = if(color == 1, do: 2, else: 1)

        # Check all neighbors
        neighbors = Model.neighbor_ids(graph, node)

        Enum.reduce_while(neighbors, {:ok, rest, colors}, fn neighbor, {:ok, q, cols} ->
          case Map.get(cols, neighbor) do
            nil ->
              # Unvisited - assign opposite color
              new_cols = Map.put(cols, neighbor, next_color)
              new_q = :queue.in({neighbor, next_color}, q)
              {:cont, {:ok, new_q, new_cols}}

            ^next_color ->
              # Already colored with expected color - OK
              {:cont, {:ok, q, cols}}

            ^color ->
              # Conflict! Neighbor has same color - not bipartite
              {:halt, {:error, :not_bipartite}}
          end
        end)
        |> case do
          {:ok, new_queue, new_colors} -> do_bfs_color(graph, new_queue, new_colors)
          {:error, reason} -> {:error, reason}
        end

      {:empty, _} ->
        {:ok, colors}
    end
  end

  @doc """
  Finds a 2-coloring of a graph if it is bipartite.

  Returns a map where each node ID maps to either 0 or 1, representing the two colors.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> {:ok, coloring} = Yog.Property.Bipartite.coloring(graph)
      iex> # Adjacent nodes should have different colors
      ...> coloring[1] != coloring[2] and coloring[2] != coloring[3]
      true

      iex> triangle = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Property.Bipartite.coloring(triangle)
      {:error, :not_bipartite}
  """
  @spec coloring(Yog.graph()) :: {:ok, %{Yog.node_id() => 0 | 1}} | {:error, :not_bipartite}
  def coloring(graph) do
    case do_partition(graph) do
      {:ok, %{left: left, right: right}} ->
        left_map = Map.new(left, fn id -> {id, 0} end)
        right_map = Map.new(right, fn id -> {id, 1} end)
        {:ok, Map.merge(left_map, right_map)}

      {:error, _} ->
        {:error, :not_bipartite}
    end
  end

  @doc """
  Finds a maximum matching in a bipartite graph.

  A matching is a set of edges with no common vertices. A maximum matching
  has the largest possible number of edges.

  Uses the augmenting path algorithm (also known as the Hungarian algorithm
  for unweighted bipartite matching).

  Returns a list of matched pairs `{left_node, right_node}`.

  ## Examples

      # Complete bipartite graph K_{2,2}
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)  # left
      ...> |> Yog.add_node(2, nil)  # left
      ...> |> Yog.add_node(3, nil)  # right
      ...> |> Yog.add_node(4, nil)  # right
      ...> |> Yog.add_edge!(from: 1, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 4, with: 1)
      iex> {:ok, p} = Yog.Property.Bipartite.partition(graph)
      iex> matching = Yog.Property.Bipartite.maximum_matching(graph, p)
      iex> length(matching)
      2

  ## Time Complexity

  O(V * E)
  """
  @spec maximum_matching(Yog.graph(), %{
          left: MapSet.t(Yog.node_id()),
          right: MapSet.t(Yog.node_id())
        }) :: [{Yog.node_id(), Yog.node_id()}]
  def maximum_matching(graph, partition_map) do
    left = MapSet.to_list(partition_map.left)
    _right = MapSet.to_list(partition_map.right)

    # Build adjacency list for left set
    adj =
      Map.new(left, fn u ->
        neighbors = Model.neighbor_ids(graph, u)
        # Only keep neighbors in right set
        valid = Enum.filter(neighbors, fn v -> MapSet.member?(partition_map.right, v) end)
        {u, valid}
      end)

    # Hopcroft-Karp / augmenting path algorithm
    match_r = %{}

    {matching, _} =
      Enum.reduce(left, {[], match_r}, fn u, {matches, match_right} ->
        visited = MapSet.new()

        case find_augmenting_path(u, adj, match_right, visited) do
          {:ok, v, new_match_right} ->
            {[{u, v} | matches], new_match_right}

          :none ->
            {matches, match_right}
        end
      end)

    Enum.reverse(matching)
  end

  # Find augmenting path using DFS
  defp find_augmenting_path(u, adj, match_r, visited) do
    neighbors = Map.get(adj, u, [])

    Enum.reduce_while(neighbors, :none, fn v, _acc ->
      if MapSet.member?(visited, v) do
        {:cont, :none}
      else
        new_visited = MapSet.put(visited, v)

        case Map.get(match_r, v) do
          nil ->
            # v is free - match with u
            {:halt, {:ok, v, Map.put(match_r, v, u)}}

          u2 ->
            # v is matched to u2 - try to find alternate path for u2
            case find_augmenting_path(u2, adj, match_r, new_visited) do
              {:ok, v2, new_match} ->
                {:halt, {:ok, v2, Map.put(new_match, v, u)}}

              :none ->
                {:cont, :none}
            end
        end
      end
    end)
  end

  @doc """
  Finds a stable matching given preference lists for two groups.

  Uses the Gale-Shapley algorithm to find a stable matching where no two people
  would both prefer each other over their current partners.

  The algorithm is "proposer-optimal" - it finds the best stable matching for
  the proposing group (left), and the worst stable matching for the receiving
  group (right).

  ## Parameters

  - `left_prefs` - Map where each key is a left person and the value is a list of
    right person preferences (most preferred first)
  - `right_prefs` - Map where each key is a right person and the value is a list of
    left person preferences (most preferred first)

  Returns a map of matched pairs (bidirectional).

  ## Examples

      # Medical residency matching
      iex> residents = %{1 => [101, 102], 2 => [102, 101]}
      iex> hospitals = %{101 => [1, 2], 102 => [2, 1]}
      iex> matches = Yog.Property.Bipartite.stable_marriage(residents, hospitals)
      iex> is_map(matches)
      true

  ## Time Complexity

  O(n²) where n is the size of each group
  """
  @spec stable_marriage(
          %{(k1 :: any()) => [k2 :: any()]},
          %{(k2 :: any()) => [k1 :: any()]}
        ) :: %{(k1 :: any()) => k2 :: any(), (k2 :: any()) => k1 :: any()}
  def stable_marriage(left_prefs, right_prefs) when is_map(left_prefs) and is_map(right_prefs) do
    # Gale-Shapley algorithm
    # left proposes to right

    # Initialize: all left are free
    free_left = Map.keys(left_prefs)

    # Current matches: right -> left
    matches = %{}

    # Track proposals made by each left
    proposals = %{}

    do_stable_marriage(free_left, left_prefs, right_prefs, matches, proposals)
  end

  def stable_marriage(opts) when is_list(opts) do
    left = Keyword.fetch!(opts, :left_prefs)
    right = Keyword.fetch!(opts, :right_prefs)
    stable_marriage(left, right)
  end

  defp do_stable_marriage([], _, _, matches, _), do: make_bidirectional(matches)

  defp do_stable_marriage([left | rest], left_prefs, right_prefs, matches, proposals) do
    # Get left's preference list minus already proposed
    prefs = Map.get(left_prefs, left, [])
    proposed = Map.get(proposals, left, [])
    remaining = prefs -- proposed

    case remaining do
      [] ->
        # No more preferences - stays unmatched
        do_stable_marriage(rest, left_prefs, right_prefs, matches, proposals)

      [preferred | _] ->
        new_proposals = Map.put(proposals, left, [preferred | proposed])

        case Map.get(matches, preferred) do
          nil ->
            # Right is free - match them
            new_matches = Map.put(matches, preferred, left)
            do_stable_marriage(rest, left_prefs, right_prefs, new_matches, new_proposals)

          current_left ->
            # Right is matched - check if prefers new left
            right_pref_list = Map.get(right_prefs, preferred, [])

            if prefers?(right_pref_list, left, current_left) do
              # Right prefers new left - switch
              new_matches = Map.put(matches, preferred, left)
              # Previous match becomes free
              do_stable_marriage(
                [current_left | rest],
                left_prefs,
                right_prefs,
                new_matches,
                new_proposals
              )
            else
              # Right keeps current - left stays free but with updated proposals
              do_stable_marriage([left | rest], left_prefs, right_prefs, matches, new_proposals)
            end
        end
    end
  end

  # Check if right prefers new_left over current_left
  defp prefers?(pref_list, new_left, current_left) do
    new_idx = Enum.find_index(pref_list, &(&1 == new_left))
    current_idx = Enum.find_index(pref_list, &(&1 == current_left))

    case {new_idx, current_idx} do
      {nil, _} -> false
      {_, nil} -> true
      {n, c} -> n < c
    end
  end

  defp make_bidirectional(matches) do
    # Convert right -> left to bidirectional
    Enum.reduce(matches, %{}, fn {right, left}, acc ->
      acc
      |> Map.put(left, right)
      |> Map.put(right, left)
    end)
  end

  @doc """
  Gets the partner of a person in a stable matching.

  Returns the partner if the person is matched, `nil` otherwise.

  ## Examples

      iex> residents = %{1 => [101, 102], 2 => [102, 101]}
      iex> hospitals = %{101 => [1, 2], 102 => [2, 1]}
      iex> matches = Yog.Property.Bipartite.stable_marriage(residents, hospitals)
      iex> partner = Yog.Property.Bipartite.get_partner(matches, 1)
      iex> partner in [101, 102]
      true
      iex> Yog.Property.Bipartite.get_partner(matches, 999)
      nil
  """
  @spec get_partner(%{(k :: any()) => v :: any()}, any()) :: any() | nil
  def get_partner(matches, person) when is_map(matches) do
    Map.get(matches, person)
  end

  def get_partner({:stable_marriage, matches}, person) do
    Map.get(matches, person)
  end
end
