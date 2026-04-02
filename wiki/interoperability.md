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

### Minimal Implementation (7 Functions)

Only these 7 functions are **required**. All others have working defaults in `Yog.Queryable.Defaults`:

```elixir
defimpl Yog.Queryable, for: MyGraph do
  # Navigation - the fundamental graph operations
  def successors(graph, id), do: ...
  def predecessors(graph, id), do: ...
  
  # Metadata
  def type(graph), do: ...           # :directed or :undirected
  def order(graph), do: ...          # number of nodes
  def edge_count(graph), do: ...     # number of edges
  def all_nodes(graph), do: ...      # list of node IDs
  
  # Node data
  def node(graph, id), do: ...       # data for a node, or nil
end
```

### Functions with Defaults

These functions have working defaults derived from the 7 core functions above:

| Function | Default Implementation | Override When... |
|----------|----------------------|------------------|
| `out_degree/2` | `length(successors(graph, id))` | You track degree explicitly (O(1) vs O(degree)) |
| `in_degree/2` | `length(predecessors(graph, id))` | You track degree explicitly |
| `degree/2` | `out_degree + in_degree` | You need undirected graph semantics |
| `has_node?/2` | `id in all_nodes(graph)` | You have faster lookup (e.g., MapSet) |
| `has_edge?/3` | Search successors | You have O(1) edge lookup |
| `edge_data/3` | Find in successors | You have O(1) edge weight lookup |
| `nodes/1` | Map all_nodes to data | N/A (rarely needs override) |
| `all_edges/1` | Iterate all nodes + successors | You have batch edge access |
| `successor_ids/2` | Extract from successors | N/A |
| `predecessor_ids/2` | Extract from predecessors | N/A |
| `neighbors/2` | Merge successors + predecessors | N/A |
| `neighbor_ids/2` | Unique union | N/A |
| `node_count/1` | Alias for order | N/A |

### Example: Using Defaults

```elixir
defimpl Yog.Queryable, for: Graph do
  alias Yog.Queryable.Defaults

  # Required - 7 core functions
  def successors(graph, id) do
    # your implementation
  end
  
  def predecessors(graph, id) do
    # your implementation
  end
  
  def type(graph), do: graph.type
  def order(graph), do: map_size(graph.nodes)
  def edge_count(graph), do: graph.edge_count
  def all_nodes(graph), do: Map.keys(graph.nodes)
  def node(graph, id), do: Map.get(graph.nodes, id)

  # Override defaults for efficiency
  def out_degree(graph, id), do: Map.get(graph.out_degrees, id, 0)
  def in_degree(graph, id), do: Map.get(graph.in_degrees, id, 0)
  
  # Use defaults for the rest
  defdelegate degree(graph, id), to: Defaults
  defdelegate has_node?(graph, id), to: Defaults
  defdelegate has_edge?(graph, src, dst), to: Defaults
  defdelegate edge_data(graph, src, dst), to: Defaults
  defdelegate nodes(graph), to: Defaults
  defdelegate all_edges(graph), to: Defaults
  defdelegate successor_ids(graph, id), to: Defaults
  defdelegate predecessor_ids(graph, id), to: Defaults
  defdelegate neighbors(graph, id), to: Defaults
  defdelegate neighbor_ids(graph, id), to: Defaults
  defdelegate node_count(graph), to: Defaults
end
```

## Example 1: libgraph Integration

[libgraph](https://github.com/bitwalker/libgraph) is a popular Elixir graph library. Here's a minimal integration using only 7 required functions + 2 efficiency overrides:

```elixir
defimpl Yog.Queryable, for: Graph do
  alias Yog.Queryable.Defaults

  # === Required: 7 core functions ===
  
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
  def edge_count(graph), do: Graph.num_edges(graph)
  def all_nodes(graph), do: Graph.vertices(graph)
  
  def node(graph, id) do
    # libgraph doesn't store separate node data, return ID itself
    if Graph.has_vertex?(graph, id), do: id, else: nil
  end

  # === Overrides for O(1) efficiency ===
  
  def out_degree(graph, id), do: Graph.out_degree(graph, id)
  def in_degree(graph, id), do: Graph.in_degree(graph, id)
  def degree(graph, id), do: Graph.degree(graph, id)

  # === Use defaults for the rest ===
  
  defdelegate has_node?(graph, id), to: Defaults
  defdelegate has_edge?(graph, src, dst), to: Defaults
  defdelegate edge_data(graph, src, dst), to: Defaults
  defdelegate nodes(graph), to: Defaults
  defdelegate all_edges(graph), to: Defaults
  defdelegate successor_ids(graph, id), to: Defaults
  defdelegate predecessor_ids(graph, id), to: Defaults
  defdelegate neighbors(graph, id), to: Defaults
  defdelegate neighbor_ids(graph, id), to: Defaults
  defdelegate node_count(graph), to: Defaults
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
  alias Yog.Queryable.Defaults

  # Check if reference is a digraph
  defp digraph?(ref) do
    try do
      :digraph.info(ref)
      true
    rescue
      _ -> false
    end
  end

  # === Required: 7 core functions ===
  
  def successors(ref, id) do
    with true <- digraph?(ref),
         edges <- :digraph.out_edges(ref, id) do
      Enum.map(edges, fn edge ->
        {_, ^id, to, weight} = :digraph.edge(ref, edge)
        {to, weight}
      end)
    else
      _ -> []
    end
  end

  def predecessors(ref, id) do
    with true <- digraph?(ref),
         edges <- :digraph.in_edges(ref, id) do
      Enum.map(edges, fn edge ->
        {_, from, ^id, weight} = :digraph.edge(ref, edge)
        {from, weight}
      end)
    else
      _ -> []
    end
  end

  def type(_ref), do: :directed  # :digraph is always directed

  def order(ref) do
    if digraph?(ref), do: length(:digraph.vertices(ref)), else: 0
  end

  def edge_count(ref) do
    if digraph?(ref), do: length(:digraph.edges(ref)), else: 0
  end

  def all_nodes(ref) do
    if digraph?(ref), do: :digraph.vertices(ref), else: []
  end

  def node(ref, id) do
    with true <- digraph?(ref),
         {^id, label} <- :digraph.vertex(ref, id) do
      label
    else
      _ -> nil
    end
  end

  # === Overrides for O(1) efficiency ===
  
  def out_degree(ref, id) do
    if digraph?(ref), do: :digraph.out_degree(ref, id), else: 0
  end

  def in_degree(ref, id) do
    if digraph?(ref), do: :digraph.in_degree(ref, id), else: 0
  end

  # === Use defaults for the rest ===
  
  defdelegate has_node?(ref, id), to: Defaults
  defdelegate has_edge?(ref, src, dst), to: Defaults
  defdelegate edge_data(ref, src, dst), to: Defaults
  defdelegate nodes(ref), to: Defaults
  defdelegate all_edges(ref), to: Defaults
  defdelegate degree(ref, id), to: Defaults
  defdelegate successor_ids(ref, id), to: Defaults
  defdelegate predecessor_ids(ref, id), to: Defaults
  defdelegate neighbors(ref, id), to: Defaults
  defdelegate neighbor_ids(ref, id), to: Defaults
  defdelegate node_count(ref), to: Defaults
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

  @spec remove_node(t, node_id) :: t
  def remove_node(graph, id)

  @spec add_edge(t, node_id, node_id, weight) :: {:ok, t} | {:error, term}
  def add_edge(graph, src, dst, weight)

  @spec add_edges(t, [{node_id, node_id, weight}]) :: {:ok, t} | {:error, term}
  def add_edges(graph, edges)

  @spec remove_edge(t, node_id, node_id) :: t
  def remove_edge(graph, src, dst)

  @spec add_edge_ensure(t, node_id, node_id, weight, default_data) :: t
  def add_edge_ensure(graph, src, dst, weight, default_data)

  @spec add_edge_with_combine(t, node_id, node_id, weight, (weight, weight -> weight)) :: {:ok, t} | {:error, term}
  def add_edge_with_combine(graph, src, dst, weight, with_combine)
end
```

**Note**: Convenience functions like `add_simple_edges/2` (weight=1), `add_unweighted_edge/2` (weight=nil), 
`add_edge_ensure/2` (keyword opts), etc. are provided by the `Yog` and `Yog.Model` API modules, not the protocol.

## The Transformable Protocol

For structural operations:

```elixir
defprotocol Yog.Transformable do
  @spec empty(t) :: t
  def empty(graph)

  @spec empty(t, :directed | :undirected) :: t
  def empty(graph, kind)

  @spec transpose(t) :: t
  def transpose(graph)

  @spec map_nodes(t, (term -> term)) :: t
  def map_nodes(graph, fun)

  @spec map_edges(t, (weight -> weight)) :: t
  def map_edges(graph, fun)
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

Here's a minimal implementation for a custom adjacency list using **only 7 functions**:

```elixir
defmodule MyApp.AdjacencyList do
  defstruct nodes: %{}, type: :directed
  
  def new(type \\ :directed) do
    %__MODULE__{type: type}
  end
  
  def add_edge(%__MODULE__{nodes: nodes} = g, src, dst, weight \\ 1.0) do
    neighbors = Map.get(nodes, src, [])
    new_nodes = Map.put(nodes, src, [{dst, weight} | neighbors])
    %{g | nodes: new_nodes}
  end
end

defimpl Yog.Queryable, for: MyApp.AdjacencyList do
  alias Yog.Queryable.Defaults

  # === Required: Only 7 functions! ===

  def successors(%MyApp.AdjacencyList{nodes: nodes}, id) do
    Map.get(nodes, id, [])
  end

  def predecessors(%MyApp.AdjacencyList{nodes: nodes}, id) do
    nodes
    |> Enum.flat_map(fn {src, edges} ->
      edges
      |> Enum.filter(fn {dst, _} -> dst == id end)
      |> Enum.map(fn {_, w} -> {src, w} end)
    end)
  end

  def type(%MyApp.AdjacencyList{type: type}), do: type
  def order(%MyApp.AdjacencyList{nodes: nodes}), do: map_size(nodes)
  def edge_count(%MyApp.AdjacencyList{nodes: nodes}) do
    nodes |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end
  def all_nodes(%MyApp.AdjacencyList{nodes: nodes}), do: Map.keys(nodes)
  def node(graph, id), do: if(has_node?(graph, id), do: id, else: nil)

  # === Use defaults for everything else ===
  
  defdelegate has_node?(graph, id), to: Defaults
  defdelegate has_edge?(graph, src, dst), to: Defaults
  defdelegate out_degree(graph, id), to: Defaults
  defdelegate in_degree(graph, id), to: Defaults
  defdelegate degree(graph, id), to: Defaults
  defdelegate edge_data(graph, src, dst), to: Defaults
  defdelegate nodes(graph), to: Defaults
  defdelegate all_edges(graph), to: Defaults
  defdelegate successor_ids(graph, id), to: Defaults
  defdelegate predecessor_ids(graph, id), to: Defaults
  defdelegate neighbors(graph, id), to: Defaults
  defdelegate neighbor_ids(graph, id), to: Defaults
  defdelegate node_count(graph), to: Defaults
end
```

That's it! With just 7 functions implemented, you get:
- Full YogEx algorithm compatibility (centrality, pathfinding, community detection)
- All derived functions (degrees, edge checks, neighbor lists) work automatically
- Zero boilerplate for common operations

## Summary

| To use YogEx with... | Implement... | Minimum Functions |
|---------------------|--------------|-------------------|
| Read-only algorithms | `Yog.Queryable` | **7** |
| Graph building | `Yog.Queryable` + `Yog.Modifiable` | **7 + 7 = 14** |
| Full transformation support | All three protocols | **7 + 7 + 5 = 19** |

### Quick Reference

**Queryable (7 required):**
```elixir
successors/2, predecessors/2, type/1, node/2, all_nodes/1, order/1, edge_count/1
```

**Modifiable (7 required):**
```elixir
add_node/3, remove_node/2, add_edge/4, add_edges/2, remove_edge/3, 
add_edge_ensure/5, add_edge_with_combine/5
```

**Transformable (5 required):**
```elixir
empty/1, empty/2, transpose/1, map_nodes/2, map_edges/2
```

### Design Philosophy

The protocol-based design means you can:
- **Use YogEx algorithms** on any graph data structure with minimal effort (7 functions!)
- **Migrate gradually** from other libraries without rewriting your graph code
- **Optimize** only what matters - override defaults for your hot paths
- **Test** with confidence using the protocol contracts in `Yog.Queryable.Defaults`
