# Protocol Refactoring Errors & Inconsistencies

## Status: ALL ISSUES RESOLVED ✅

All critical errors and design inconsistencies identified during the protocol refactoring have been fixed.

---

## Fixed Issues

### 1. ✅ `Yog.DAG.Graph` Invariant Breach - FIXED

**Issue**: `add_edge_with_combine/5` directly modified the underlying `Yog.Graph` without performing an acyclicity check.

**Fix**: 
- Modified `Yog.DAG.Model.add_edge_with_combine/5` to check acyclicity after combining edges
- Updated `Yog.Modifiable.DAG.Graph.add_edge_with_combine/5` to delegate to `Model.add_edge_with_combine/5`

---

### 2. ✅ Incomplete Facade Migration (`Yog` module) - FIXED

**Issue**: The main entry point `lib/yog.ex` was only partially migrated to protocols, with many functions still delegating to concrete `Yog.Model`.

**Fix**: Updated all functions in `Yog` module to use protocols:
- `add_edge/2`, `add_edge/4` → `Yog.Modifiable.add_edge/4`
- `add_edge!/2`, `add_edge!/4` → `Yog.Modifiable.add_edge/4` with `elem(1)`
- `add_edge_ensure/2`, `add_edge_ensure/4` → `Yog.Modifiable.add_edge_ensure/5`
- `add_edge_with/5` → Implemented using `Yog.Modifiable.add_node/3` + `add_edge/4`
- `add_unweighted_edge/2`, `add_unweighted_edge/3` → `Yog.Modifiable.add_edge/4` with `nil`
- `add_unweighted_edge!/2`, `add_unweighted_edge!/3` → `Yog.Modifiable.add_edge/4` with `elem(1)`
- `add_simple_edge/2`, `add_simple_edge/3` → `Yog.Modifiable.add_edge/4` with `1`
- `add_simple_edge!/2`, `add_simple_edge!/3` → `Yog.Modifiable.add_edge/4` with `elem(1)`
- `add_simple_edges/2` → `Yog.Modifiable.add_edges/2` with mapped edges
- `add_unweighted_edges/2` → `Yog.Modifiable.add_edges/2` with mapped edges
- `successor_ids/2` → `Yog.Queryable.successor_ids/2`
- `from_edges/2`, `from_unweighted_edges/2` → `Yog.Modifiable.add_edge_ensure/5`

---

### 3. ✅ Stale API in `Yog.DAG.Model` - FIXED

**Issue**: The module contained functions removed from protocols (`add_edge_with/5`, keyword versions) and called `Yog.Model` directly.

**Fix**: 
- Removed `add_simple_edges/2`, `add_unweighted_edges/2` (convenience functions moved to `Yog` module)
- Removed `add_edge_ensure/2` (keyword version)
- Removed `add_edge_with/5` (removed from protocol)
- Fixed `add_edge_ensure/5` to use `Mutator.add_edge_ensure/5` instead of `Yog.Model.add_edge_ensure`
- Added `add_edge_with_combine/5` with acyclicity check

---

### 4. ✅ Missing `Transformable` Implementations - FIXED

**Issue**: `Yog.DAG.Graph` did not implement the `Yog.Transformable` protocol.

**Fix**: Added `Yog.Transformable` implementation for `Yog.DAG.Graph`:
- `empty/1`, `empty/2` - Create empty DAG
- `transpose/1` - Reverses edges (maintains DAG property)
- `map_nodes/2` - Transform node data
- `map_edges/2` - Transform edge weights

---

### 5. ✅ `Yog.Model` Concrete Dependency - FIXED

**Issue**: `Yog.DAG.Model` called `Yog.Model` directly, bypassing polymorphism.

**Fix**: All functions in `Yog.DAG.Model` now use the `Mutator` alias (`Yog.Modifiable` protocol) instead of calling `Yog.Model` directly.

---

### 6. ✅ Coupling in `Inspect` - FIXED

**Issue**: In `dag/graph.ex`, the `Inspect` implementation called `Yog.Graph.edge_count(graph)` instead of using the protocol.

**Fix**: Changed to use `Yog.Queryable.edge_count(graph)`.

---

## Verification

All fixes verified with:
```bash
mix test  # 518 doctests, 76 properties, 1177 tests, 0 failures
```

## Architecture After Fixes

| Layer | Implementation |
|-------|---------------|
| **Public API** (`Yog`) | Uses protocols exclusively (`Yog.Queryable`, `Yog.Modifiable`, `Yog.Transformable`) |
| **Graph Types** | `Yog.Graph`, `Yog.DAG.Graph`, `Yog.Multi.Graph` all implement the three protocols |
| **Model Modules** | `Yog.Model`, `Yog.DAG.Model` provide concrete implementations for their respective types |
| **Defaults** | `Yog.Queryable.Defaults` provides default implementations for derived functions |

The protocol-based architecture now correctly supports polymorphic graph operations across all graph types.
