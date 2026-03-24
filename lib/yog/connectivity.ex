defmodule Yog.Connectivity do
  @moduledoc """
  Graph connectivity analysis - finding connected components, bridges, articulation points,
  and strongly connected components.

  This module provides algorithms for analyzing the connectivity structure of graphs,
  identifying components, and finding critical elements whose removal would disconnect the graph.

  ## Component Types

  | Component Type | Function | Graph Type | Description |
  |----------------|----------|------------|-------------|
  | **Connected Components** | `connected_components/1` | Undirected | Maximal connected subgraphs |
  | **Weakly Connected Components** | `weakly_connected_components/1` | Directed | Connected when ignoring direction |
  | **Strongly Connected Components** | `strongly_connected_components/1` | Directed | Connected following edge directions |

  ## Bridges vs Articulation Points

  - **Bridge** (cut edge): An edge whose removal increases the number of connected components.
    In a network, this represents a single point of failure.
  - **Articulation Point** (cut vertex): A node whose removal increases the number of connected
    components. These are critical nodes in the network.

  ## Algorithms

  | Algorithm | Function | Use Case | Complexity |
  |-----------|----------|----------|------------|
  | DFS-based CC | `connected_components/1` | Undirected graph components | O(V + E) |
  | DFS-based WCC | `weakly_connected_components/1` | Directed graph, ignore direction | O(V + E) |
  | [Tarjan's SCC](https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm) | `strongly_connected_components/1` | Find SCCs in one pass | O(V + E) |
  | [Kosaraju's Algorithm](https://en.wikipedia.org/wiki/Kosaraju%27s_algorithm) | `kosaraju/1` | Find SCCs using two DFS passes | O(V + E) |
  | [Tarjan's Bridge-Finding](https://en.wikipedia.org/wiki/Bridge_(graph_theory)) | `analyze/1` | Find bridges and articulation points | O(V + E) |

  All algorithms run in **O(V + E)** linear time.
  """

  alias Yog.Model

  @type bridge :: {Yog.node_id(), Yog.node_id()}
  @type component :: [Yog.node_id()]
  @type connectivity_results :: %{
          bridges: [bridge()],
          articulation_points: [Yog.node_id()]
        }

  @doc """
  Analyzes an **undirected graph** to find all bridges and articulation points.

  Can be called in two ways:
  - With keyword options: `analyze(in: graph)`
  - With graph directly (for pipelines): `graph |> analyze()`

  ## Examples

  Using keyword options:

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: nil)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: nil)
      iex> results = Yog.Connectivity.analyze(in: graph)
      iex> results.bridges
      [{1, 2}, {2, 3}]
      iex> results.articulation_points
      [2]

  Using pipeline style:

      iex> results =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_edge!(from: 1, to: 2, with: nil)
      ...>   |> Yog.add_edge!(from: 2, to: 3, with: nil)
      ...>   |> Yog.Connectivity.analyze()
      iex> results.bridges
      [{1, 2}, {2, 3}]
      iex> results.articulation_points
      [2]
  """
  @spec analyze(keyword() | Yog.graph()) :: connectivity_results()
  def analyze(options_or_graph) do
    graph =
      if is_list(options_or_graph) do
        Keyword.fetch!(options_or_graph, :in)
      else
        options_or_graph
      end

    do_analyze(graph)
  end

  defp do_analyze(graph) do
    all_nodes = Model.all_nodes(graph)

    # State: {disc, low, parent, time, bridges, articulation_points}
    initial_state = %{
      disc: %{},
      low: %{},
      parent: %{},
      time: 0,
      bridges: [],
      articulation_points: MapSet.new()
    }

    final_state =
      Enum.reduce(all_nodes, initial_state, fn node, state ->
        if Map.has_key?(state.disc, node) do
          state
        else
          analyze_dfs(graph, node, state)
        end
      end)

    %{
      bridges: Enum.sort(final_state.bridges),
      articulation_points: Enum.sort(MapSet.to_list(final_state.articulation_points))
    }
  end

  defp analyze_dfs(graph, node, state) do
    state =
      Map.update!(state, :disc, &Map.put(&1, node, state.time))
      |> Map.update!(:low, &Map.put(&1, node, state.time))
      |> Map.update!(:time, &(&1 + 1))

    neighbors = Model.successor_ids(graph, node)

    children_count = init_counter(0)

    state_after_neighbors =
      Enum.reduce(neighbors, state, fn neighbor, acc_state ->
        case Map.fetch(acc_state.disc, neighbor) do
          :error ->
            # Tree edge
            increment_counter(children_count)

            new_state =
              Map.update!(acc_state, :parent, &Map.put(&1, neighbor, node))
              |> then(&analyze_dfs(graph, neighbor, &1))

            # Update low value
            new_low = min(Map.fetch!(new_state.low, node), Map.fetch!(new_state.low, neighbor))
            new_state = Map.update!(new_state, :low, &Map.put(&1, node, new_low))

            # Check for articulation point
            parent = Map.get(new_state.parent, node)

            new_state =
              if parent != nil and
                   Map.fetch!(new_state.low, neighbor) >= Map.fetch!(new_state.disc, node) do
                Map.update!(new_state, :articulation_points, &MapSet.put(&1, node))
              else
                new_state
              end

            # Check for bridge
            new_state =
              if Map.fetch!(new_state.low, neighbor) > Map.fetch!(new_state.disc, node) do
                bridge = if node < neighbor, do: {node, neighbor}, else: {neighbor, node}
                Map.update!(new_state, :bridges, &[bridge | &1])
              else
                new_state
              end

            new_state

          {:ok, _} ->
            # Back edge
            if Map.get(acc_state.parent, node) != neighbor do
              new_low = min(Map.fetch!(acc_state.low, node), Map.fetch!(acc_state.disc, neighbor))
              Map.update!(acc_state, :low, &Map.put(&1, node, new_low))
            else
              acc_state
            end
        end
      end)

    # Root node articulation point check
    if Map.get(state_after_neighbors.parent, node) == nil and get_counter(children_count) > 1 do
      Map.update!(state_after_neighbors, :articulation_points, &MapSet.put(&1, node))
    else
      state_after_neighbors
    end
  end

  # Simple mutable counter using Agent-like pattern with a tuple
  # We use the process dictionary for this local mutable state
  defp init_counter(initial) do
    key = make_ref()
    Process.put(key, initial)
    key
  end

  defp get_counter(key), do: Process.get(key)

  defp increment_counter(key) do
    current = Process.get(key)
    Process.put(key, current + 1)
  end

  @doc """
  Finds Strongly Connected Components (SCC) using Tarjan's Algorithm.

  Returns a list of components, where each component is a list of node IDs.
  O(V + E) linear time.
  """
  @spec strongly_connected_components(Yog.graph()) :: [[Yog.node_id()]]
  def strongly_connected_components(graph) do
    all_nodes = Model.all_nodes(graph)

    state = %{
      index: 0,
      indices: %{},
      lowlinks: %{},
      stack: [],
      on_stack: MapSet.new(),
      sccs: []
    }

    final_state =
      Enum.reduce(all_nodes, state, fn node, acc_state ->
        if Map.has_key?(acc_state.indices, node) do
          acc_state
        else
          tarjan_dfs(graph, node, acc_state)
        end
      end)

    final_state.sccs
  end

  defp tarjan_dfs(graph, node, state) do
    state =
      Map.update!(state, :indices, &Map.put(&1, node, state.index))
      |> Map.update!(:lowlinks, &Map.put(&1, node, state.index))
      |> Map.update!(:index, &(&1 + 1))
      |> Map.update!(:stack, &[node | &1])
      |> Map.update!(:on_stack, &MapSet.put(&1, node))

    neighbors = Model.successor_ids(graph, node)

    state_after_neighbors =
      Enum.reduce(neighbors, state, fn neighbor, acc_state ->
        case Map.fetch(acc_state.indices, neighbor) do
          :error ->
            # Successor not yet visited
            new_state = tarjan_dfs(graph, neighbor, acc_state)

            new_lowlink =
              min(
                Map.fetch!(new_state.lowlinks, node),
                Map.fetch!(new_state.lowlinks, neighbor)
              )

            Map.update!(new_state, :lowlinks, &Map.put(&1, node, new_lowlink))

          {:ok, _} ->
            # Successor already visited
            if MapSet.member?(acc_state.on_stack, neighbor) do
              new_lowlink =
                min(
                  Map.fetch!(acc_state.lowlinks, node),
                  Map.fetch!(acc_state.indices, neighbor)
                )

              Map.update!(acc_state, :lowlinks, &Map.put(&1, node, new_lowlink))
            else
              acc_state
            end
        end
      end)

    # If node is a root node, pop the stack to generate an SCC
    if Map.fetch!(state_after_neighbors.lowlinks, node) ==
         Map.fetch!(state_after_neighbors.indices, node) do
      {scc, new_stack, new_on_stack} =
        pop_scc(state_after_neighbors.stack, state_after_neighbors.on_stack, node, [])

      %{
        state_after_neighbors
        | stack: new_stack,
          on_stack: new_on_stack,
          sccs: [scc | state_after_neighbors.sccs]
      }
    else
      state_after_neighbors
    end
  end

  defp pop_scc([head | rest], on_stack, target, acc) when head == target do
    {Enum.reverse([head | acc]), rest, MapSet.delete(on_stack, head)}
  end

  defp pop_scc([head | rest], on_stack, target, acc) do
    pop_scc(rest, MapSet.delete(on_stack, head), target, [head | acc])
  end

  @doc """
  Alias for `strongly_connected_components/1`.
  """
  @spec scc(Yog.graph()) :: [[Yog.node_id()]]
  def scc(graph), do: strongly_connected_components(graph)

  @doc """
  Finds Strongly Connected Components (SCC) using Kosaraju's Algorithm.

  Returns a list of components, where each component is a list of node IDs.
  Kosaraju's algorithm uses two DFS passes and graph transposition:

  1. First DFS: Compute finishing times
  2. Transpose the graph (reverse all edges) - O(1) operation in Yog!
  3. Second DFS: Process nodes in reverse finishing time order on transposed graph

  Time Complexity: O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex>
      iex> sccs = Yog.Connectivity.kosaraju(graph)
      iex> hd(sccs) |> Enum.sort()
      [1, 2, 3]
  """
  @spec kosaraju(Yog.graph()) :: [[Yog.node_id()]]
  def kosaraju(graph) do
    all_nodes = Model.all_nodes(graph)

    # First DFS to get finishing order
    {_, finish_order} =
      Enum.reduce(all_nodes, {MapSet.new(), []}, fn node, {visited, order} ->
        if MapSet.member?(visited, node) do
          {visited, order}
        else
          dfs_finish(graph, node, visited, order)
        end
      end)

    # Transpose the graph
    transposed = Yog.Transform.transpose(graph)

    # Second DFS on transposed graph in reverse finishing order
    {_, sccs} =
      Enum.reduce(finish_order, {MapSet.new(), []}, fn node, {visited, components} ->
        if MapSet.member?(visited, node) do
          {visited, components}
        else
          {new_visited, component} = dfs_collect(transposed, node, visited, [])
          {new_visited, [component | components]}
        end
      end)

    sccs
  end

  defp dfs_finish(graph, node, visited, order) do
    visited = MapSet.put(visited, node)

    neighbors = Model.successor_ids(graph, node)

    {final_visited, final_order} =
      Enum.reduce(neighbors, {visited, order}, fn neighbor, {acc_visited, acc_order} ->
        if MapSet.member?(acc_visited, neighbor) do
          {acc_visited, acc_order}
        else
          dfs_finish(graph, neighbor, acc_visited, acc_order)
        end
      end)

    {final_visited, [node | final_order]}
  end

  defp dfs_collect(graph, node, visited, component) do
    visited = MapSet.put(visited, node)

    neighbors = Model.successor_ids(graph, node)

    Enum.reduce(neighbors, {visited, [node | component]}, fn neighbor, {acc_visited, acc_comp} ->
      if MapSet.member?(acc_visited, neighbor) do
        {acc_visited, acc_comp}
      else
        dfs_collect(graph, neighbor, acc_visited, acc_comp)
      end
    end)
  end

  @doc """
  Finds Connected Components in an **undirected graph**.

  A connected component is a maximal subgraph where every node is reachable
  from every other node via undirected edges. This uses simple DFS and runs
  in linear time.

  Important: This algorithm is designed for undirected graphs. For directed
  graphs, use `weakly_connected_components/1` instead.

  Time Complexity: O(V + E)

  ## Example

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_node(4, "D")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex>
      iex> components = Yog.Connectivity.connected_components(graph)
      iex> Enum.map(components, &Enum.sort/1) |> Enum.sort()
      [[1, 2], [3, 4]]
  """
  @spec connected_components(Yog.graph()) :: [component()]
  def connected_components(graph) do
    all_nodes = Model.all_nodes(graph)

    {_, components} =
      Enum.reduce(all_nodes, {MapSet.new(), []}, fn node, {visited, components} ->
        if MapSet.member?(visited, node) do
          {visited, components}
        else
          {new_visited, component} = dfs_component(graph, node, visited, [])
          {new_visited, [component | components]}
        end
      end)

    components
  end

  defp dfs_component(graph, node, visited, component) do
    visited = MapSet.put(visited, node)

    neighbors = Model.successor_ids(graph, node)

    Enum.reduce(neighbors, {visited, [node | component]}, fn neighbor, {acc_visited, acc_comp} ->
      if MapSet.member?(acc_visited, neighbor) do
        {acc_visited, acc_comp}
      else
        dfs_component(graph, neighbor, acc_visited, acc_comp)
      end
    end)
  end

  @doc """
  Finds Weakly Connected Components in a **directed graph**.

  A weakly connected component is a maximal subgraph where, if you ignore
  edge directions, all nodes are reachable from each other. This is equivalent
  to finding connected components on the underlying undirected graph.

  Time Complexity: O(V + E)

  ## Example

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_node(3, "C")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 2, with: 1)  # 1->2<-3
      iex>
      iex> # WCCs: [1, 2, 3] (weakly connected as undirected)
      iex> wccs = Yog.Connectivity.weakly_connected_components(graph)
      iex> hd(wccs) |> Enum.sort()
      [1, 2, 3]
  """
  @spec weakly_connected_components(Yog.graph()) :: [component()]
  def weakly_connected_components(graph) do
    all_nodes = Model.all_nodes(graph)

    # For weak connectivity, we need to treat the graph as undirected
    # So we need to consider both successors and predecessors
    {_, components} =
      Enum.reduce(all_nodes, {MapSet.new(), []}, fn node, {visited, components} ->
        if MapSet.member?(visited, node) do
          {visited, components}
        else
          {new_visited, component} = dfs_weak_component(graph, node, visited, [])
          {new_visited, [component | components]}
        end
      end)

    components
  end

  defp dfs_weak_component(graph, node, visited, component) do
    visited = MapSet.put(visited, node)

    # Get all neighbors (both successors and predecessors)
    successors = Model.successor_ids(graph, node)
    predecessors = Model.predecessors(graph, node) |> Enum.map(fn {id, _} -> id end)
    all_neighbors = Enum.uniq(successors ++ predecessors)

    Enum.reduce(all_neighbors, {visited, [node | component]}, fn neighbor,
                                                                 {acc_visited, acc_comp} ->
      if MapSet.member?(acc_visited, neighbor) do
        {acc_visited, acc_comp}
      else
        dfs_weak_component(graph, neighbor, acc_visited, acc_comp)
      end
    end)
  end
end
