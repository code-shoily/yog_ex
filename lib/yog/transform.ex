defmodule Yog.Transform do
  @moduledoc """
  Graph transformation operations.

  - `transpose/1` - Reverse edge directions (O(1)!)
  - `map_nodes/2` - Transform node data
  - `map_edges/2` - Transform edge weights
  - `filter_nodes/2` - Remove nodes matching predicate
  - `merge/2` - Combine two graphs

  ## Examples

      # Reverse all edges
      transposed = Yog.Transform.transpose(graph)

      # Double all edge weights
      doubled = Yog.Transform.map_edges(graph, fn weight -> weight * 2 end)

      # Convert node data to uppercase
      upper = Yog.Transform.map_nodes(graph, &String.upcase/1)
  """

  @doc """
  Reverses all edge directions in O(1) time.

  Simply swaps the internal `out_edges` and `in_edges` dictionaries
  without any iteration. Useful for algorithms like finding predecessors
  or reversing dependency graphs.

  ## Examples

      # Original: A -> B -> C
      graph = Yog.directed()
        |> Yog.add_edge(from: "A", to: "B", with: 1)
        |> Yog.add_edge(from: "B", to: "C", with: 2)

      # Transposed: C -> B -> A
      transposed = Yog.Transform.transpose(graph)

      # Now successors become predecessors
      Yog.successors(transposed, "C")
      #=> [{"B", 2}]
  """
  @spec transpose(Yog.graph()) :: Yog.graph()
  defdelegate transpose(graph), to: :yog@transform

  @doc """
  Applies a transformation function to all node data.

  The graph structure (edges) remains unchanged. The transformation
  can change the type of node data.

  ## Examples

      # String to atom
      graph = Yog.directed()
        |> Yog.add_node(1, "node_a")
        |> Yog.add_node(2, "node_b")

      atom_graph = Yog.Transform.map_nodes(graph, &String.to_atom/1)

      # Uppercase strings
      upper_graph = Yog.Transform.map_nodes(graph, &String.upcase/1)
  """
  @spec map_nodes(Yog.graph(), (term() -> term())) :: Yog.graph()
  defdelegate map_nodes(graph, fun), to: :yog@transform

  @doc """
  Applies a transformation function to all edge weights.

  The graph structure (nodes and connections) remains unchanged.

  ## Examples

      # Double all weights
      doubled = Yog.Transform.map_edges(graph, fn w -> w * 2 end)

      # Convert integers to floats
      float_graph = Yog.Transform.map_edges(graph, fn w -> w / 1.0 end)

      # Normalize weights
      max_weight = 100
      normalized = Yog.Transform.map_edges(graph, fn w -> w / max_weight end)
  """
  @spec map_edges(Yog.graph(), (term() -> term())) :: Yog.graph()
  defdelegate map_edges(graph, fun), to: :yog@transform

  @doc """
  Removes nodes matching a predicate and prunes their edges.

  The predicate receives the node data, and returns `true`
  to keep the node or `false` to remove it.

  ## Examples

      # Keep only nodes with string "active"
      even_graph = Yog.Transform.filter_nodes(graph, fn data ->
        data == "active"
      end)

      # Remove nodes with nil data
      clean_graph = Yog.Transform.filter_nodes(graph, fn data ->
        data != nil
      end)

      # Keep nodes matching a pattern
      filtered = Yog.Transform.filter_nodes(graph, fn data ->
        String.starts_with?(to_string(data), "active_")
      end)
  """
  @spec filter_nodes(Yog.graph(), (term() -> boolean())) :: Yog.graph()
  defdelegate filter_nodes(graph, predicate), to: :yog@transform

  @doc """
  Merges two graphs.

  When nodes or edges exist in both graphs, the second graph's data
  takes precedence. The merged graph preserves the base graph's type
  (directed/undirected).

  ## Examples

      graph1 = Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_edge(from: 1, to: 2, with: 10)

      graph2 = Yog.directed()
        |> Yog.add_node(2, "B")
        |> Yog.add_edge(from: 2, to: 3, with: 5)

      merged = Yog.Transform.merge(graph1, graph2)
      # Contains nodes 1, 2, 3 and both edges
  """
  @spec merge(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate merge(base, other), to: :yog@transform

  @doc """
  Creates a subgraph containing only the specified nodes and edges between them.

  Nodes not in the `keeping` list are removed, implicitly removing all edges
  connected to them.

  ## Examples

      graph = Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge(from: 1, to: 2, with: 10)
        |> Yog.add_edge(from: 2, to: 3, with: 20)

      # Keep only nodes 2 and 3
      sub = Yog.Transform.subgraph(graph, [2, 3])

      # Edge 2->3 remains, Edge 1->2 is removed
  """
  @spec subgraph(Yog.graph(), [Yog.node_id()]) :: Yog.graph()
  defdelegate subgraph(graph, keeping), to: :yog@transform

  @doc """
  Filters edges by a predicate, preserving all nodes.

  The predicate receives `(src, dst, weight)` and returns `true` to keep.

  ## Examples

      # Keep only edges with weight >= 10
      heavy = Yog.Transform.filter_edges(graph, fn _src, _dst, w -> w >= 10 end)

      # Remove self-loops
      no_loops = Yog.Transform.filter_edges(graph, fn s, d, _w -> s != d end)
  """
  @spec filter_edges(Yog.graph(), (Yog.node_id(), Yog.node_id(), term() -> boolean())) ::
          Yog.graph()
  defdelegate filter_edges(graph, predicate), to: :yog@transform

  @doc """
  Creates the complement of a graph.

  Connects all non-adjacent node pairs, removes existing edges.
  Self-loops are never added.

  ## Examples

      comp = Yog.Transform.complement(graph, 1)
      # Non-connected pairs now connected with weight 1
  """
  @spec complement(Yog.graph(), term()) :: Yog.graph()
  defdelegate complement(graph, default_weight), to: :yog@transform

  @doc """
  Converts an undirected graph to directed. O(1) — just a flag change.

  Already-directed graphs are returned unchanged.
  """
  @spec to_directed(Yog.graph()) :: Yog.graph()
  defdelegate to_directed(graph), to: :yog@transform

  @doc """
  Converts a directed graph to undirected by mirroring edges.

  The `resolve` function handles conflicting weights when both A→B and B→A exist.

  ## Examples

      undirected = Yog.Transform.to_undirected(graph, &min/2)
  """
  @spec to_undirected(Yog.graph(), (term(), term() -> term())) :: Yog.graph()
  defdelegate to_undirected(graph, resolve), to: :yog@transform

  @doc """
  Contracts an edge by merging node `b` into node `a`.

  All of `b`'s edges are redirected to `a`, with conflicting edge weights
  combined using `combine_weight`. Self-loops are removed. Node `b`'s data is lost.

  ## Examples

      contracted = Yog.Transform.contract(graph, 1, 2, &Kernel.+/2)
      # Node 2 merged into node 1
  """
  @spec contract(
          Yog.graph(),
          Yog.node_id(),
          Yog.node_id(),
          (term(), term() -> term())
        ) :: Yog.graph()
  defdelegate contract(graph, a, b, combine_weight), to: :yog@transform
end
