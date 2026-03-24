defmodule Yog.Functional.Traversal do
  @moduledoc """
  Inductive graph traversals — BFS and DFS without explicit visited sets.

  Unlike traditional graph traversals that maintain a separate "visited" set, these
  implementations rely on the structural `match/2` operation. When a node is extracted,
  it is removed from the graph along with all its incident edges, so the *shrunken*
  graph naturally prevents revisits.

  ## Available Traversals

  | Traversal | Function | Data Structure |
  |-----------|----------|----------------|
  | [DFS](https://en.wikipedia.org/wiki/Depth-first_search) | `dfs/2` | Stack (list) |
  | [BFS](https://en.wikipedia.org/wiki/Breadth-first_search) | `bfs/2` | Queue (`:queue`) |

  ## Key Principle

  Iterating with the shrunken graph naturally prevents revisiting nodes and
  terminates when the graph is empty — no `MapSet` of visited nodes needed.

  **Time Complexity:** O(V + E) for both BFS and DFS.

  ## References

  - [Original FGL Paper (Erwig, 2001)](https://web.engr.oregonstate.edu/~erwig/papers/InductiveGraphs_JFP01.pdf)
  - [Wikipedia: Graph Traversal](https://en.wikipedia.org/wiki/Graph_traversal)
  """
  alias Yog.Functional.Model

  @doc """
  Performs a Depth-First Search starting from the given node ID(s).

  Returns a list of node contexts in the order they were visited.

  This is an inductive DFS: each step calls `match/2` to simultaneously
  extract a node and obtain the *shrunken* graph without that node.
  Revisit prevention comes naturally from the graph shrinking — a node already
  visited simply won't be found in the remaining graph.

  For directed graphs, only outgoing edges are followed. For undirected graphs,
  edges are stored symmetrically so `out_edges` covers all adjacent nodes.
  """
  @spec dfs(Model.t(), Model.node_id() | [Model.node_id()]) :: [Model.Context.t()]
  def dfs(graph, start_nodes) when is_list(start_nodes) do
    do_dfs(graph, start_nodes, [])
  end

  def dfs(graph, start_node), do: dfs(graph, [start_node])

  defp do_dfs(_graph, [], acc), do: Enum.reverse(acc)

  defp do_dfs(graph, [current_id | stack], acc) do
    case Model.match(graph, current_id) do
      {:ok, ctx, remaining_graph} ->
        new_stack = neighbors_of(ctx) ++ stack
        do_dfs(remaining_graph, new_stack, [ctx | acc])

      {:error, :not_found} ->
        do_dfs(graph, stack, acc)
    end
  end

  @doc """
  Performs a Breadth-First Search starting from the given node ID(s).

  Returns a list of node contexts in the order they were visited.

  This is an inductive BFS: each step calls `match/2` to extract a node
  and obtain the shrunken graph, ensuring nodes are visited at most once.
  """
  @spec bfs(Model.t(), Model.node_id() | [Model.node_id()]) :: [Model.Context.t()]
  def bfs(graph, start_nodes) when is_list(start_nodes) do
    queue = :queue.from_list(start_nodes)
    do_bfs(graph, queue, [])
  end

  def bfs(graph, start_node), do: bfs(graph, [start_node])

  defp do_bfs(graph, queue, acc) do
    case :queue.out(queue) do
      {{:value, current_id}, rest_queue} ->
        case Model.match(graph, current_id) do
          {:ok, ctx, remaining_graph} ->
            new_queue = Enum.reduce(neighbors_of(ctx), rest_queue, &:queue.in/2)
            do_bfs(remaining_graph, new_queue, [ctx | acc])

          {:error, :not_found} ->
            do_bfs(graph, rest_queue, acc)
        end

      {:empty, _} ->
        Enum.reverse(acc)
    end
  end

  defp neighbors_of(%Model.Context{out_edges: edges}), do: Map.keys(edges)
end
