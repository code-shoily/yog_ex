# Interoperability Guide

YogEx is designed around protocols that enable seamless interoperability with other graph libraries and data structures. This guide explains how to integrate external graph types with YogEx's algorithm suite.

## Overview

YogEx defines three core protocols in the `Yog` namespace:

| Protocol | Purpose | Module Alias |
|----------|---------|--------------|
| `Yog.Queryable` | Read-only graph operations | `Yog.Model` |
| `Yog.Modifiable` | Graph mutations | `Yog.Mutator` |
| `Yog.Transformable` | Structural transformations | `Yog.Transform` |

By implementing these protocols for your graph type, you unlock YogEx's entire algorithm library.

## The Queryable Protocol

The `Yog.Queryable` protocol is the foundation. Most YogEx algorithms (centrality, pathfinding, community detection) only require this protocol.

### Required Functions

```elixir
defprotocol Yog.Queryable do
  @spec successors(t, node_id) :: [{node_id, weight}]
  def successors(graph, node_id)

  @spec predecessors(t, node_id) :: [{node_id, weight}]
  def predecessors(graph, node_id)

  @spec type(t) :: :directed | :undirected
  def type(graph)

  @spec order(t) :: non_neg_integer
  def order(graph)

  @spec has_node?(t, node_id) :: boolean
  def has_node?(graph, node_id)

  @spec node(t, node_id) :: term | nil
  def node(graph, node_id)

  @spec all_nodes(t) :: [node_id]
  def all_nodes(graph)

  @spec out_degree(t, node_id) :: non_neg_integer
  def out_degree(graph, node_id)

  @spec in_degree(t, node_id) :: non_neg_integer
  def in_degree(graph, node_id)

  @spec edge_data(t, node_id, node_id) :: weight | nil
  def edge_data(graph, src, dst)
end
```

### Optional Functions

These have default implementations that derive from the required functions:

- `neighbors/2` - Combined successors and predecessors
- `neighbor_ids/2` - IDs only (no weights)
- `successor_ids/2` - IDs only
- `predecessor_ids/2` - IDs only
- `nodes/1` - Map of id => node data
- `degree/2` - Total degree (out + in)
- `has_edge?/3` - Check edge existence
- `node_count/1` - Alias for `order/1`
- `edge_count/1` - Requires implementation for efficiency
- `all_edges/1` - List all edges as `{src, dst, weight}`

## Example 1: libgraph Integration

[libgraph](https://github.com/bitwalker/libgraph) is a popular Elixir graph library. Here's how to integrate it:

```elixir
defimpl Yog.Queryable, for: Graph do
  def successors(graph, id) do
    graph
    |> Graph.out_neighbors(id)
    |> Enum.map(fn neighbor ->
      %Graph.Edge{weight: weight} = Graph.edge(graph, id, neighbor)
      {neighbor, weight}
    end)
  end

  def predecessors(graph, id) do
    graph
    |> Graph.in_neighbors(id)
    |> Enum.map(fn neighbor ->
      %Graph.Edge{weight: weight} = Graph.edge(graph, neighbor, id)
      {neighbor, weight}
    end)
  end

  def type(%Graph{type: type}), do: type
  def order(graph), do: Graph.num_vertices(graph)
  def node_count(graph), do: Graph.num_vertices(graph)
  def edge_count(graph), do: Graph.num_edges(graph)
  def has_node?(graph, id), do: Graph.has_vertex?(graph, id)
  
  def has_edge?(graph, src, dst) do
    Graph.edge(graph, src, dst) != nil
  end
  
  def node(graph, id) do
    if has_node?(graph, id), do: id, else: nil
  end
  
  def all_nodes(graph), do: Graph.vertices(graph)
  def out_degree(graph, id), do: Graph.out_degree(graph, id)
  def in_degree(graph, id), do: Graph.in_degree(graph, id)
  def degree(graph, id), do: Graph.degree(graph, id)
  
  def edge_data(graph, src, dst) do
    case Graph.edge(graph, src, dst) do
      %Graph.Edge{v1: ^src, v2: ^dst, weight: weight} -> weight
      _ -> nil
    end
  end
  
  def all_edges(graph) do
    Graph.edges(graph)
  end
end
```

### Using libgraph with YogEx

```elixir
# Create a libgraph graph
libgraph = 
  Graph.new(type: :undirected)
  |> Graph.add_vertices([:a, :b, :c])
  |> Graph.add_edge(:a, :b, weight: 1)
  |> Graph.add_edge(:b, :c, weight: 2)

# Run YogEx algorithms directly!
Yog.Centrality.degree(libgraph)
# => %{a: 0.5, b: 1.0, c: 0.5}

Yog.Pathfinding.dijkstra(libgraph, :a, :c)
# => %{path: [:a, :b, :c], distance: 3}

Yog.Community.louvain(libgraph)
# => %{communities: [...], modularity: ...}
```

## Example 2: Erlang :digraph Integration

Erlang's `:digraph` module provides a built-in graph data structure:

```elixir
defimpl Yog.Queryable, for: Reference do
  # Check if reference is a digraph
  defp digraph?(ref) do
    try do
      :digraph.info(ref)
      true
    rescue
      _ -> false
    end
  end

  def successors(ref, id) do
    case digraph?(ref) do
      false -> []
      true ->
        ref
        |> :digraph.out_edges(id)
        |> Enum.map(fn edge ->
          {_, ^id, to, weight} = :digraph.edge(ref, edge)
          {to, weight}
        end)
    end
  end

  def predecessors(ref, id) do
    case digraph?(ref) do
      false -> []
      true ->
        ref
        |> :digraph.in_edges(id)
        |> Enum.map(fn edge ->
          {_, from, ^id, weight} = :digraph.edge(ref, edge)
          {from, weight}
        end)
    end
  end

  def type(ref) do
    with true <- digraph?(ref),
         info <- :digraph.info(ref),
         true <- Keyword.get(info, :cyclicity) == :acyclic do
      :directed
    else
      _ -> :directed  # Default for digraph
    end
  end

  def order(ref) do
    case digraph?(ref) do
      false -> 0
      true -> length(:digraph.vertices(ref))
    end
  end

  def has_node?(ref, id) do
    case digraph?(ref) do
      false -> false
      true -> :digraph.vertex(ref, id) != false
    end
  end

  def node(ref, id) do
    case digraph?(ref) do
      false -> nil
      true -> 
        case :digraph.vertex(ref, id) do
          {^id, label} -> label
          false -> nil
        end
    end
  end

  def all_nodes(ref) do
    case digraph?(ref) do
      false -> []
      true -> :digraph.vertices(ref)
    end
  end

  def out_degree(ref, id) do
    case digraph?(ref) do
      false -> 0
      true -> :digraph.out_degree(ref, id)
    end
  end

  def in_degree(ref, id) do
    case digraph?(ref) do
      false -> 0
      true -> :digraph.in_degree(ref, id)
    end
  end

  def edge_data(ref, src, dst) do
    case digraph?(ref) do
      false -> nil
      true ->
        ref
        |> :digraph.edges(src, dst)
        |> List.first()
        |> case do
          nil -> nil
          edge ->
            {_, _, _, weight} = :digraph.edge(ref, edge)
            weight
        end
    end
  end
end
```

### Using :digraph with YogEx

```elixir
# Create an Erlang digraph
dg = :digraph.new([:cyclic, :protected])
:a = :digraph.add_vertex(dg, :a, "Node A")
:b = :digraph.add_vertex(dg, :b, "Node B")
:c = :digraph.add_vertex(dg, :c, "Node C")

:digraph.add_edge(dg, :a, :b, 1.0)
:digraph.add_edge(dg, :b, :c, 2.0)

# Run YogEx algorithms!
Yog.Centrality.degree(dg)
Yog.Pathfinding.shortest_path(dg, :a, :c)
```

## The Modifiable Protocol

For graph builders and transformations, implement `Yog.Modifiable`:

```elixir
defprotocol Yog.Modifiable do
  @spec add_node(t, node_id, term) :: t
  def add_node(graph, id, data)

  @spec add_edge(t, node_id, node_id, weight) :: {:ok, t} | {:error, term}
  def add_edge(graph, src, dst, weight)

  @spec add_edge!(t, node_id, node_id, weight) :: t
  def add_edge!(graph, src, dst, weight)

  @spec remove_node(t, node_id) :: t
  def remove_node(graph, id)

  @spec remove_edge(t, node_id, node_id) :: t
  def remove_edge(graph, src, dst)

  @spec clear(t) :: t
  def clear(graph)

  @spec update_node(t, node_id, (term -> term)) :: t
  def update_node(graph, id, updater)
end
```

## The Transformable Protocol

For structural operations:

```elixir
defprotocol Yog.Transformable do
  @spec reverse(t) :: t
  def reverse(graph)

  @spec transpose(t) :: t
  def transpose(graph)

  @spec subgraph(t, [node_id]) :: t
  def subgraph(graph, nodes)

  @spec contract(t, node_id, node_id) :: t
  def contract(graph, u, v)
end
```

## Performance Considerations

### 1. Batch Operations

When implementing for external libraries, consider batching:

```elixir
def all_edges(graph) do
  # Some libraries provide efficient batch access
  graph.library_specific_all_edges()
  |> Enum.map(fn {src, dst, weight} -> {src, dst, weight} end)
end
```

### 2. Lazy Evaluation

For large graphs, implement lazy enumeration:

```elixir
def successors(graph, id) do
  graph
  |> ExternalLib.out_neighbors_lazy(id)  # Returns Stream
  |> Stream.map(fn {neighbor, weight} -> {neighbor, weight} end)
end
```

### 3. Caching

Consider caching frequently accessed properties:

```elixir
defimpl Yog.Queryable, for: MyGraph do
  def order(%MyGraph{cache: %{order: order}}), do: order
  def order(graph) do
    # Compute and cache
  end
end
```

## Testing Your Implementation

YogEx provides property-based tests that verify protocol compliance:

```elixir
defmodule MyGraph.ProtocolTest do
  use ExUnit.Case
  use ExUnitProperties

  property "successors returns valid nodes" do
    check all graph <- graph_generator(),
              node <- member_of(Yog.Queryable.all_nodes(graph)) do
      successors = Yog.Queryable.successors(graph, node)
      
      # All successors must exist in graph
      for {succ, _weight} <- successors do
        assert Yog.Queryable.has_node?(graph, succ)
      end
    end
  end
end
```

## Complete Example: Adjacency List

Here's a minimal implementation for a custom adjacency list:

```elixir
defmodule MyApp.AdjacencyList do
  defstruct nodes: %{}, type: :directed
  
  def new(type \\ :directed) do
    %__MODULE__{type: type}
  end
  
  def add_edge(%__MODULE__{nodes: nodes} = g, src, dst, weight \\ 1.0) do
    neighbors = Map.get(nodes, src, [])
    new_nodes = Map.put(nodes, src, [{dst, weight} | neighbors])
    %__MODULE__{g | nodes: new_nodes}
  end
end

defimpl Yog.Queryable, for: MyApp.AdjacencyList do
  alias MyApp.AdjacencyList

  def successors(%AdjacencyList{nodes: nodes}, id) do
    Map.get(nodes, id, [])
  end

  def predecessors(%AdjacencyList{nodes: nodes}, id) do
    nodes
    |> Enum.flat_map(fn {src, edges} ->
      Enum.filter(edges, fn {dst, _} -> dst == id end)
      |> Enum.map(fn {_, w} -> {src, w} end)
    end)
  end

  def type(%AdjacencyList{type: type}), do: type
  def order(%AdjacencyList{nodes: nodes}), do: map_size(nodes)
  def has_node?(%AdjacencyList{nodes: nodes}, id), do: Map.has_key?(nodes, id)
  def node(graph, id), do: if(has_node?(graph, id), do: id, else: nil)
  def all_nodes(%AdjacencyList{nodes: nodes}), do: Map.keys(nodes)
  
  def out_degree(graph, id) do
    length(successors(graph, id))
  end
  
  def in_degree(graph, id) do
    length(predecessors(graph, id))
  end
  
  def edge_data(graph, src, dst) do
    graph
    |> successors(src)
    |> Enum.find_value(fn {d, w} -> if d == dst, do: w end)
  end
end
```

## Summary

| To use YogEx with... | Implement... |
|---------------------|--------------|
| Read-only algorithms | `Yog.Queryable` |
| Graph building | `Yog.Queryable` + `Yog.Modifiable` |
| Full transformation support | All three protocols |

The protocol-based design means you can:
- **Use YogEx algorithms** on any graph data structure
- **Migrate gradually** from other libraries
- **Optimize** for your specific use case while keeping the same API
- **Test** with confidence using the protocol contracts
