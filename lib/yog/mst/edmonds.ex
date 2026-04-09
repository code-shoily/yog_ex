defmodule Yog.MST.Edmonds do
  @moduledoc """
  Chu-Liu/Edmonds' algorithm for finding the Minimum Spanning Arborescence (MSA).

  An arborescence (also known as a directed spanning tree) is a directed counterpart
  to a Minimum Spanning Tree. For a given root node, it finds a set of edges that
  allows all other nodes to be reached from the root with minimum total weight.

  The algorithm works by:
  1. Picking the cheapest incoming edge for every node except the root.
  2. If the resulting graph is acyclic, it is the MSA.
  3. If cycles exist, it contracts each cycle into a "super-node", adjusts the
     weights of remaining incoming edges, and recurses.
  4. Finally, it expands the contracted cycles to restore the original graph structure.

  ## Performance

  - **Time Complexity**: O(VE) for simple implementations like this one.
  - **Space Complexity**: O(V + E) to store the graph and recursion metadata.
  """

  alias Yog.MST.Result

  @doc """
  Computes the Minimum Spanning Arborescence (MSA) of a directed graph.

  Returns `{:ok, %Yog.MST.Result{}}` containing the edges of the MSA.

  ## Parameters

  - `graph`: The directed graph to process.
  - `root`: The node ID to use as the root of the arborescence.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Root") |> Yog.add_node(2, "A") |> Yog.add_node(3, "B")
      ...> |> Yog.add_edges!([{1, 2, 10}, {1, 3, 20}, {2, 3, 5}])
      iex> {:ok, result} = Yog.MST.Edmonds.compute(graph, 1)
      iex> result.total_weight
      15
      iex> result.root
      1
  """
  @spec compute(Yog.graph(), term()) :: {:ok, Result.t()} | {:error, term()}
  def compute(graph, root) do
    if graph.kind != :directed do
      {:error, :directed_only}
    else
      case do_compute(graph, root) do
        {:ok, edges} ->
          {:ok, Result.new(edges, :chu_liu_edmonds, map_size(graph.nodes), root)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_compute(graph, root) do
    # 1. For each node v != root, find the minimum weight incoming edge
    best_in = find_best_in_edges(graph, root)

    # If any node besides root has no incoming edges, it might be unreachable
    # Actually, if a node has no incoming edges and it's not the root, it's impossible.
    node_ids = Map.keys(graph.nodes)

    if Enum.any?(node_ids, fn v -> v != root and is_nil(best_in[v]) end) do
      # Check if all nodes are reachable from root
      {:error, :no_arborescence_exists}
    else
      # 2. Check for cycles in the selected edges
      cycle = find_cycle(best_in, node_ids, root)

      if is_nil(cycle) do
        # No cycles! We found the MSA.
        edges = Map.values(best_in)
        {:ok, edges}
      else
        # 3. We found a cycle. Contract it.
        {contracted_graph, cycle_info} = contract_cycle(graph, cycle, best_in)

        case do_compute(contracted_graph, root) do
          {:ok, contracted_edges} ->
            # 4. Expand cycle
            expanded_edges = expand_cycle(contracted_edges, cycle_info, best_in)
            {:ok, expanded_edges}

          error ->
            error
        end
      end
    end
  end

  # Finds the minimum weight incoming edge for each node (except root)
  defp find_best_in_edges(graph, root) do
    Enum.reduce(graph.nodes, %{}, fn {node_id, _}, acc ->
      if node_id == root do
        acc
      else
        case Map.get(graph.in_edges, node_id, %{}) do
          ins when ins == %{} ->
            acc

          ins ->
            # Find min weight edge
            case Enum.min_by(ins, fn {_src, w} -> w end, fn -> nil end) do
              nil -> acc
              {src, w} -> Map.put(acc, node_id, %{from: src, to: node_id, weight: w})
            end
        end
      end
    end)
  end

  # Simple DFS-based cycle detection in the functional graph defined by best_in
  defp find_cycle(best_in, nodes, _root) do
    Enum.find_value(nodes, fn start_node ->
      find_cycle_dfs(start_node, best_in, %{}, [])
    end)
  end

  defp find_cycle_dfs(node, best_in, visited, path) do
    case Map.get(visited, node) do
      :visiting ->
        # Found cycle! Extract it from path.
        [node | Enum.take_while(path, fn x -> x != node end)] |> Enum.reverse()

      :visited ->
        nil

      nil ->
        case Map.get(best_in, node) do
          nil ->
            nil

          edge ->
            find_cycle_dfs(edge.from, best_in, Map.put(visited, node, :visiting), [node | path])
        end
    end
  end

  # Contracts a cycle into a super-node
  defp contract_cycle(graph, cycle, best_in) do
    cycle_nodes = MapSet.new(cycle)
    super_node = {:super_node, make_ref()}

    new_graph =
      Enum.reduce(graph.nodes, Yog.Graph.new(:directed), fn {id, data}, g ->
        if MapSet.member?(cycle_nodes, id) do
          g
        else
          Yog.Model.add_node(g, id, data)
        end
      end)
      |> Yog.Model.add_node(super_node, %{cycle: cycle})

    # 2. Add edges
    # For every edge (u, v, w) in original graph:
    # If u and v both in cycle, ignore (cycle is internal)
    # If u in cycle, v not in cycle, it becomes (super_node, v, w)
    # If v in cycle, u not in cycle, it becomes (u, super_node, w - w_in(v))
    # If neither in cycle, it becomes (u, v, w)

    # We need to track which original edge the new edge corresponds to.
    # We can store this in edge metadata or a separate map.
    # Let's use a mapping: new_edge -> original_edge

    # Actually, we can use Yog.Model.add_edge with Metadata or just custom weights.

    # Let's iterate over ALL edges.
    edges_info = extract_all_edges(graph)

    {contracted_graph, edge_mapping} =
      Enum.reduce(edges_info, {new_graph, %{}}, fn edge, {g, mapping} ->
        u = edge.from
        v = edge.to
        w = edge.weight

        u_in = MapSet.member?(cycle_nodes, u)
        v_in = MapSet.member?(cycle_nodes, v)

        cond do
          # Internal
          u_in and v_in ->
            {g, mapping}

          u_in ->
            # (super_node, v, w)
            # If multiple edges from cycle to same v, keep the best?
            # Yes, but Edmonds' usually only contracts incoming.
            # Actually, outgoing from cycle to same V should also keep min?
            # Wait, standard Edmonds' only cares about incoming to cycle.
            add_contracted_edge(g, mapping, super_node, v, w, edge)

          v_in ->
            # (u, super_node, w - best_in[v].weight)
            new_w = w - best_in[v].weight
            add_contracted_edge(g, mapping, u, super_node, new_w, edge)

          true ->
            # (u, v, w)
            add_contracted_edge(g, mapping, u, v, w, edge)
        end
      end)

    {contracted_graph, %{super_node: super_node, cycle: cycle, mapping: edge_mapping}}
  end

  defp add_contracted_edge(graph, mapping, u, v, w, orig_edge) do
    # If u == v (self loop created by contraction), ignore
    if u == v do
      {graph, mapping}
    else
      # Yog.Model.add_edge_with_combine to handle multigraph properties during contraction
      # (keeping only the minimum weight edge between two nodes)
      case Map.get(graph.out_edges, u, %{}) |> Map.get(v) do
        nil ->
          # New edge
          new_g = Yog.Model.add_edge!(graph, u, v, w)
          new_mapping = Map.put(mapping, {u, v}, orig_edge)
          {new_g, new_mapping}

        existing_w ->
          if w < existing_w do
            new_g = Yog.Model.add_edge!(graph, u, v, w)
            new_mapping = Map.put(mapping, {u, v}, orig_edge)
            {new_g, new_mapping}
          else
            {graph, mapping}
          end
      end
    end
  end

  defp expand_cycle(contracted_edges, cycle_info, best_in) do
    %{super_node: s, cycle: cycle, mapping: mapping} = cycle_info

    # 1. Identify which edge was chosen to enter the super-node
    # (There should be exactly one such edge in the MSA of the contracted graph)
    entry_edge_contracted = Enum.find(contracted_edges, fn e -> e.to == s end)

    # 2. Get the original edge that corresponds to this entry edge
    entry_orig = if entry_edge_contracted, do: mapping[{entry_edge_contracted.from, s}]

    # 3. Add all other edges from contracted_edges (expanding outward edges from cycle)
    final_edges =
      Enum.reduce(contracted_edges, [], fn e, acc ->
        cond do
          # Replaced by original
          e.to == s ->
            [entry_orig | acc]

          e.from == s ->
            # Recover original from -> to
            orig = mapping[{s, e.to}]
            [orig | acc]

          true ->
            [e | acc]
        end
      end)

    # 4. Add all edges from the cycle EXCEPT the one that points to the node
    # where entry_orig enters the cycle.
    # If no entry edge (e.g. super-node contains root?), this shouldn't happen
    # if we roots properly, but check.
    node_to_bypass = if entry_orig, do: entry_orig.to, else: nil

    cycle_edges =
      Enum.reduce(cycle, [], fn node, acc ->
        edge = best_in[node]

        if edge.to == node_to_bypass do
          acc
        else
          [edge | acc]
        end
      end)

    final_edges ++ cycle_edges
  end

  defp extract_all_edges(graph) do
    Enum.flat_map(graph.out_edges, fn {u, neighbors} ->
      Enum.map(neighbors, fn {v, w} -> %{from: u, to: v, weight: w} end)
    end)
  end
end
