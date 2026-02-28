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
        |> Yog.add_edge(from: "A", to: "B", weight: 1)
        |> Yog.add_edge(from: "B", to: "C", weight: 2)

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

  The predicate receives the node ID and node data, and returns `true`
  to keep the node or `false` to remove it.

  ## Examples

      # Keep only nodes with even IDs
      even_graph = Yog.Transform.filter_nodes(graph, fn id, _data ->
        rem(id, 2) == 0
      end)

      # Remove nodes with nil data
      clean_graph = Yog.Transform.filter_nodes(graph, fn _id, data ->
        data != nil
      end)

      # Keep nodes matching a pattern
      filtered = Yog.Transform.filter_nodes(graph, fn _id, data ->
        String.starts_with?(data, "active_")
      end)
  """
  @spec filter_nodes(Yog.graph(), (integer(), term() -> boolean())) :: Yog.graph()
  defdelegate filter_nodes(graph, predicate), to: :yog@transform

  @doc """
  Merges two graphs.
  
  When nodes or edges exist in both graphs, the second graph's data
  takes precedence. The merged graph preserves the base graph's type
  (directed/undirected).
  
  ## Examples
  
      graph1 = Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
  
      graph2 = Yog.directed()
        |> Yog.add_node(2, "B")
        |> Yog.add_edge(from: 2, to: 3, weight: 5)
  
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
        |> Yog.add_edge(from: 1, to: 2, weight: 10)
        |> Yog.add_edge(from: 2, to: 3, weight: 20)
  
      # Keep only nodes 2 and 3
      sub = Yog.Transform.subgraph(graph, [2, 3])
      
      # Edge 2->3 remains, Edge 1->2 is removed
  """
  @spec subgraph(Yog.graph(), [Yog.node_id()]) :: Yog.graph()
  defdelegate subgraph(graph, keeping), to: :yog@transform
end
