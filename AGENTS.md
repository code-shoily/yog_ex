# YogEx Agent Guidelines

## Project Overview

YogEx is a pure Elixir graph algorithm library. The codebase is currently being migrated from a concrete `Yog.Model`-centric API to a **polymorphic protocol-based architecture** while maintaining backwards compatibility.

## Core Architecture

### The Three Protocols

All graph implementations must implement one or more of these protocols:

| Protocol | Purpose | Required By |
|----------|---------|-------------|
| `Yog.Queryable` | Read-only graph queries (successors, order, has_node?, etc.) | Pathfinders, Traversal, Analysis |
| `Yog.Modifiable` | Graph modifications (add_node, add_edge, remove_node, etc.) | Transformers, Builders, I/O |
| `Yog.Transformable` | Structural transformations (transpose, map_nodes, empty, etc.) | Operations, Contraction |

### Backwards Compatibility

`Yog.Graph` (the default graph struct) implements all three protocols by delegating to `Yog.Model` functions. This means:

- **Existing code using `Yog.Model.*` continues to work**
- **Protocol-based code works with `Yog.Graph`**
- New graph implementations can be used with existing algorithms

```elixir
# These are equivalent for Yog.Graph:
Yog.Model.order(graph)      # Direct module call
Model.order(graph)          # Via protocol (Queryable)

# But only the protocol version works for ALL graph types
```

## Migration Guidelines

### Step 1: Replace `Yog.Model.*` Calls

Change from concrete module calls to protocol calls:

```elixir
# BEFORE
alias Yog.Model

def my_function(graph) do
  Model.order(graph)
  Model.successors(graph, id)
  Model.add_node(graph, id, data)
end

# AFTER
alias Yog.Queryable, as: Model
alias Yog.Modifiable, as: Mutator

def my_function(graph) do
  Model.order(graph)
  Model.successors(graph, id)
  Mutator.add_node(graph, id, data)
end
```

### Step 2: Remove Direct Struct Access (Algorithm Modules)

For algorithm modules, never access graph struct fields directly. Always use protocol functions:

```elixir
# FORBIDDEN in algorithms - Breaks polymorphism
graph.nodes[id]
graph.out_edges[src]
graph.kind

# CORRECT - Works with any graph implementation
Model.node(graph, id)
Model.successors(graph, src)
Model.type(graph)
```

**Exception:** I/O and Render modules use direct struct access since they're implementation-specific.

### Step 3: Protocol Implementations

When implementing protocols for a new graph type:

```elixir
# ❌ WRONG - Default parameters in protocol impl
defimpl Yog.Queryable, for: MyCustomGraph do
  def successors(graph, id, opts \\ [])  # DON'T DO THIS
  
# ✅ CORRECT - Match the protocol contract exactly
defimpl Yog.Queryable, for: MyCustomGraph do
  def successors(graph, id)  # Exact arity match
```

**CRITICAL**: Protocol implementations MUST match the protocol contract exactly - no default parameters, no extra arguments.

## Aliasing Conventions

Follow these naming conventions for consistency:

```elixir
# Read operations only
alias Yog.Queryable, as: Model

# Modification operations
alias Yog.Modifiable, as: Mutator

# Transformable is used directly (less common)
# Yog.Transformable.empty(graph)
```

## Module Categories

Different modules need different protocols:

| Module Type | Protocols Needed | Examples |
|-------------|------------------|----------|
| Pathfinders | Queryable only | A*, Dijkstra, Bellman-Ford |
| Traversal | Queryable only | BFS, DFS, Walk |
| Analysis | Queryable only | Centrality, Connectivity |
| Transformers | Queryable + Modifiable + Transformable | SCC, Transpose, Operations |
| Builders | Modifiable + Queryable | Grid, Labeled, Toroidal |
| I/O | Modifiable + Queryable | GraphML, JSON, Pajek |

## File Structure

```
lib/yog/
├── protocols.ex          # The three protocol definitions
├── model.ex              # Concrete implementation + protocol delegation
├── graph.ex              # Graph struct + protocol implementations
├── queryable.ex          # (Optional) Queryable-specific utilities
├── modifiable.ex         # (Optional) Modifiable-specific utilities
└── transformable.ex      # (Optional) Transformable-specific utilities
```

## Testing Protocol Compliance

When testing new graph implementations:

1. Test that they implement all required protocols
2. Test protocol behavior matches `Yog.Graph` semantics
3. Run existing algorithm tests with the new graph type

```elixir
# In tests for new graph implementations
defmodule MyGraph.ProtocolTest do
  use ExUnit.Case
  
  test "implements Queryable" do
    graph = MyGraph.new(:directed)
    assert is_list(Yog.Queryable.all_nodes(graph))
    assert is_integer(Yog.Queryable.order(graph))
  end
end
```

## Special Cases

### I/O, Render, and Generator Modules (No Migration Needed)

**I/O modules** (`Yog.IO.*`), **Render modules** (`Yog.Render.*`), and **Generator modules** (`Yog.Generator.*`) do NOT need to be migrated to protocols:

#### I/O and Render
They are inherently tied to `Yog.Graph` because:

1. **Implementation-specific serialization** - Converting to/from external formats (JSON, GraphML, DOT, etc.) requires knowledge of the internal representation
2. **Need internal structure access** - They require `graph.nodes`, `graph.out_edges`, `graph.kind` for efficient serialization
3. **They CREATE graphs** - Deserialization functions construct `Yog.Graph` structs directly

**For I/O modules, use:**
- Direct struct field access for **reading** (`graph.nodes`, `graph.out_edges`, `graph.kind`)
- `Yog.Graph.new/1` for creating empty graphs
- `Yog.Modifiable` protocol (as `Mutator`) for **building** during deserialization

Example:
```elixir
alias Yog.Modifiable, as: Mutator

# Serialization - direct struct access
def serialize(graph) do
  nodes = graph.nodes
  edges = graph.out_edges
  kind = graph.kind
  # ... format-specific serialization
end

# Deserialization - use Modifiable protocol
def deserialize(data) do
  Enum.reduce(nodes, Yog.Graph.new(:directed), fn {id, data}, g ->
    Mutator.add_node(g, id, data)
  end)
end
```

#### Generator Modules
Generators **create** `Yog.Graph` structs from parameters using the high-level `Yog` module functions:

```elixir
def complete(n) do
  base = Yog.new(:undirected)  # Creates Yog.Graph
  
  Enum.reduce(0..(n-1), base, fn i, g ->
    Yog.add_node(g, i, nil)    # Works via protocols
  end)
  |> add_edges_via_protocols()
end
```

Generators don't need protocols because:
1. They **produce** graphs, not consume them
2. They use `Yog.new/1`, `Yog.add_node/3`, `Yog.add_edge!/4` which already work polymorphically
3. Their output is always a fresh `Yog.Graph` struct

#### Transform Async Functions

The async variants in `Yog.Transform` (`map_nodes_async/3`, `map_edges_async/3`, `map_edges_indexed/2`) are specifically optimized for `Yog.Graph` and use direct struct access. They:
- Pattern match on `%Yog.Graph{}` 
- Use `Task.async_stream` for parallel processing
- Access `graph.nodes`, `graph.out_edges`, `graph.in_edges` directly

These are acceptable as `Yog.Graph`-specific optimizations. Alternative graph implementations should provide their own optimized parallel transformation functions.

## Common Pitfalls

### 1. Default Parameters in Protocol Impls
```elixir
# WRONG
defimpl Yog.Queryable, for: MyGraph do
  def successors(graph, id, opts \\ [])  # Default param = protocol mismatch
  
# CORRECT
defimpl Yog.Queryable, for: MyGraph do
  def successors(graph, id)
```

### 2. Direct Struct Access (Except I/O and Render)
```elixir
# WRONG for algorithm modules
%{nodes: nodes, out_edges: out} = graph

# CORRECT for algorithm modules
nodes = Model.all_nodes(graph)

# OK for I/O and Render modules (implementation-specific)
nodes = graph.nodes
edges = graph.out_edges
```

### 3. Assuming Graph Type
```elixir
# WRONG
if graph.kind == :directed do  # Assumes Yog.Graph struct

# CORRECT
if Model.type(graph) == :directed do
```

### 4. Mixed Module/Protocol Usage
```elixir
# WRONG - Inconsistent
alias Yog.Queryable, as: Model

def foo(graph) do
  Model.order(graph)           # Via protocol
  Yog.Model.add_node(graph, ...)  # Bypassing protocol!
end

# CORRECT
alias Yog.Queryable, as: Model
alias Yog.Modifiable, as: Mutator

def foo(graph) do
  Model.order(graph)
  Mutator.add_node(graph, ...)
end
```

### 5. Type Spec References
```elixir
# WRONG - References concrete module types
@spec my_func(Yog.Model.graph(), Yog.Model.node_id()) :: Yog.graph()

# CORRECT - Uses top-level type aliases
@spec my_func(Yog.Graph.t(), Yog.node_id()) :: Yog.Graph.t()
```

## Protocol Reference

### Yog.Queryable

**Core Protocol** (7 required functions):

```elixir
# Navigation (fundamental)
successors(graph, id) :: [{id, weight}]
predecessors(graph, id) :: [{id, weight}]

# Graph metadata
type(graph) :: :directed | :undirected
order(graph) :: integer()
edge_count(graph) :: integer()
all_nodes(graph) :: [id]

# Node data
node(graph, id) :: data | nil
```

**Functions with Defaults** (via `Yog.Queryable.Defaults`):

```elixir
# Derived from successors/predecessors
out_degree(graph, id) :: integer()    # default: length(successors)
in_degree(graph, id) :: integer()     # default: length(predecessors)
degree(graph, id) :: integer()        # default: out + in (or just out for undirected)
successor_ids(graph, id) :: [id]      # default: extract IDs from successors
predecessor_ids(graph, id) :: [id]    # default: extract IDs from predecessors
neighbors(graph, id) :: [{id, weight}] # default: merge successors + predecessors
neighbor_ids(graph, id) :: [id]       # default: unique union

# Derived from all_nodes
has_node?(graph, id) :: boolean()     # default: id in all_nodes
nodes(graph) :: %{id => data}         # default: map all_nodes to their data
node_count(graph) :: integer()        # default: order

# Derived from successors
has_edge?(graph, src, dst) :: boolean() # default: dst in successors(src)
edge_data(graph, src, dst) :: weight | nil # default: find in successors(src)
all_edges(graph) :: [{src, dst, weight}]   # default: iterate all nodes + successors
```

> **Design Note**: Only 7 core functions are required! All others have working default
> implementations in `Yog.Queryable.Defaults`. Override defaults when your implementation
> can provide better efficiency (e.g., O(1) `out_degree` vs O(degree) default).
>
> Example minimal implementation:
> ```elixir
> defimpl Yog.Queryable, for: MyGraph do
>   def successors(g, id), do: ...
>   def predecessors(g, id), do: ...
>   def type(g), do: ...
>   def node(g, id), do: ...
>   def all_nodes(g), do: ...
>   def order(g), do: ...
>   def edge_count(g), do: ...
>
>   # Override for efficiency
>   def out_degree(g, id), do: Map.get(g.degrees, id, 0)
>   defdelegate has_edge?(g, s, d), to: Yog.Queryable.Defaults
> end
> ```

### Yog.Modifiable

**Core Protocol** (required for all implementations):

```elixir
# Nodes
add_node(graph, id, data) :: graph
remove_node(graph, id) :: graph

# Edges
add_edge(graph, src, dst, weight) :: {:ok, graph} | {:error, String.t()}
add_edges(graph, edges :: [{src, dst, weight}]) :: {:ok, graph} | {:error, String.t()}
remove_edge(graph, src, dst) :: graph

# Semantic operations
add_edge_ensure(graph, src, dst, weight, default_data) :: graph
add_edge_with_combine(graph, src, dst, weight, combine_fn) :: {:ok, graph} | {:error, String.t()}
```

**Convenience Functions** (provided by `Yog` / `Yog.Model`, delegate to protocol):

```elixir
add_unweighted_edge(graph, from, to) :: {:ok, graph} | {:error, String.t()}
add_simple_edges(graph, edges :: [{src, dst}]) :: {:ok, graph} | {:error, String.t()}
add_unweighted_edges(graph, edges :: [{src, dst}]) :: {:ok, graph} | {:error, String.t()}
```

> **Design Note**: The protocol is intentionally minimal. Convenience functions for unweighted edges, simple edges (weight=1), etc., live in the main API modules (`Yog`, `Yog.Model`) and delegate to the core protocol functions. This reduces boilerplate for external implementations while maintaining a rich public API.

### Yog.Transformable

```elixir
empty(graph) :: graph
empty(graph, kind :: :directed | :undirected) :: graph
transpose(graph) :: graph
map_nodes(graph, fun) :: graph
map_edges(graph, fun) :: graph
```

## Migration Status

These modules have been migrated to the protocol-based API:

- ✅ `Yog.Operation` - Uses `Queryable` (as Model), `Modifiable` (as Mutator), `Transformable`
- ✅ `Yog.Pathfinding.AStar` - Uses `Queryable` (as Model)
- ✅ `Yog.Builder.Grid` - Uses `Queryable` (as Model), `Modifiable` (as Mutator), `Transformable`
- ✅ `Yog.Builder.GridGraph` - Uses `Queryable`
- ✅ `Yog.Builder.Labeled` - Uses `Queryable` (as Model), `Modifiable` (as Mutator), `Transformable`
- ✅ `Yog.Builder.Live` - Uses `Modifiable` (as Mutator)
- ✅ `Yog.Builder.Toroidal` - Uses `Queryable` (as Model), `Modifiable` (as Mutator), `Transformable`
- ✅ `Yog.Builder.ToroidalGraph` - Uses `Queryable`
- ✅ `Yog.Centrality` - Uses `Queryable` (as Model)
- ✅ `Yog.Community.*` - Uses `Queryable` (as Model) and `Modifiable` (as Mutator)
- ✅ `Yog.Connectivity.*` - Uses `Queryable` (as Model) and `Modifiable`
- ✅ `Yog.DAG.Algorithm` - Uses `Queryable` (as QueryModel)
- ✅ `Yog.DAG.Graph` - Uses `Modifiable` (as Mutator) and `Queryable` (as QueryModel)
- ✅ `Yog.DAG.Model` - Uses `Modifiable` (as Mutator)
- ✅ `Yog.Flow.*` - Uses `Queryable` (as Model) and `Modifiable` (as Mutator)
- ✅ `Yog.Health` - Uses `Queryable` (as Model)
- ✅ `Yog.MST` - Uses `Queryable` (as Model)
- ✅ `Yog.Multi.Graph` - Uses `Modifiable` (as Mutator)
- ✅ `Yog.Operation` - Uses `Queryable` (as Model), `Modifiable` (as Mutator), `Transformable`
- ✅ `Yog.Pathfinding.*` - Uses `Queryable` (as Model)
- ✅ `Yog.Property.*` - Uses `Queryable` (as Model)
- ✅ `Yog.Render.ASCII` - Uses `Queryable` (as Model)
- ✅ `Yog.Render.DOT` - Uses direct struct access (render-specific for Yog.Graph)
- ✅ `Yog.Render.Mermaid` - Uses direct struct access (render-specific for Yog.Graph)
- ✅ `Yog.Traversal.*` - Uses `Queryable` (as Model)
- ✅ `Yog.Transform` - Uses `Queryable` (as Model), `Modifiable` (as Mutator), `Transformable`

**Modules that DON'T need migration:**
- 🚫 `Yog.IO.*` - I/O is inherently tied to `Yog.Graph` representation  
- 🚫 `Yog.Render.*` - Rendering is inherently tied to `Yog.Graph` representation
- 🚫 `Yog.Generator.*` - Generators CREATE `Yog.Graph` structs using high-level API (`Yog.new/1`, `Yog.add_node/3`, etc.)

- ⏳ Pathfinding modules (Dijkstra, Bellman-Ford, Floyd-Warshall, etc.)
- ⏳ Centrality
- ⏳ Community detection
- ⏳ Connectivity
- ⏳ I/O modules
- ⏳ Transform

## Summary Checklist

When working on this codebase:

- [ ] Replace `Yog.Model.*` with protocol calls via aliases
- [ ] Remove all direct struct field access (`graph.nodes`, `graph.out_edges`, etc.)
- [ ] Use `alias Yog.Queryable, as: Model` for readability
- [ ] Use `alias Yog.Modifiable, as: Mutator` for modifications
- [ ] Ensure protocol implementations have NO default parameters
- [ ] Verify the module only uses the protocols it needs
- [ ] Test with `Yog.Graph` to ensure backwards compatibility
