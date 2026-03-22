defmodule Yog.DAG do
  @moduledoc """
  Directed Acyclic Graph (DAG) type and operations.

  A DAG is a directed graph that contains no cycles. This module provides:
  - A type-safe wrapper around graphs that guarantees acyclicity
  - Operations that preserve the DAG invariant
  - Algorithms that leverage the acyclic structure

  ## Type Safety

  The `Yog.DAG` type wraps a regular graph and guarantees it has no cycles.
  Operations that could create cycles return `{:error, reason}` tuples.

  ## When to Use

  - Task scheduling with dependencies
  - Build systems
  - Dependency resolution
  - Version control (merge bases)
  - Any problem requiring topological ordering

  ## Examples

      # Create a DAG from an existing graph
      case Yog.DAG.from_graph(graph) do
        {:ok, dag} ->
          # Safe to use DAG-specific operations
          sorted = Yog.DAG.topological_sort(dag)
          
        {:error, :cycle_detected} ->
          # Handle cyclic graph
      end

      # Build a DAG incrementally
      dag = Yog.DAG.new(:directed)
      dag = Yog.DAG.add_node(dag, :a, "Task A")
      dag = Yog.DAG.add_node(dag, :b, "Task B")
      {:ok, dag} = Yog.DAG.add_edge(dag, :a, :b, 1)  # a must complete before b
  """

  alias Yog.DAG.{Algorithms, Models}

  @typedoc "A directed acyclic graph"
  @type t :: Models.t()

  @typedoc "Error type for DAG operations"
  @type error :: Models.error()

  # ============================================================
  # Construction
  # ============================================================

  @doc """
  Creates a new, empty DAG.

  ## Examples

      dag = Yog.DAG.new(:directed)
      dag = Yog.DAG.new(:undirected)  # Will still enforce acyclicity
  """
  @spec new(Yog.graph_type()) :: t()
  def new(type) do
    Models.new(type)
  end

  @doc """
  Attempts to create a DAG from a regular graph.

  Returns `{:ok, dag}` if the graph is acyclic, otherwise `{:error, :cycle_detected}`.

  ## Examples

      graph = Yog.directed()
      |> Yog.add_edge!(:a, :b, 1)
      |> Yog.add_edge!(:b, :c, 1)

      case Yog.DAG.from_graph(graph) do
        {:ok, dag} -> dag
        {:error, :cycle_detected} -> nil
      end
  """
  @spec from_graph(Yog.graph()) :: {:ok, t()} | {:error, :cycle_detected}
  def from_graph(graph) do
    Models.from_graph(graph)
  end

  @doc """
  Unwraps a DAG back into a regular graph.

  This is useful when you need to use operations that work on any graph type.

  ## Examples

      graph = Yog.DAG.to_graph(dag)
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph(dag) do
    Models.to_graph(dag)
  end

  # ============================================================
  # Node Operations
  # ============================================================

  @doc """
  Adds a node to the DAG.

  Adding a node cannot create a cycle, so this operation always succeeds.

  ## Examples

      dag = Yog.DAG.new(:directed)
      dag = Yog.DAG.add_node(dag, :a, "Task A")
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node(dag, id, data) do
    Models.add_node(dag, id, data)
  end

  @doc """
  Removes a node and all its connected edges from the DAG.

  Removing nodes cannot create a cycle.

  ## Examples

      dag = Yog.DAG.remove_node(dag, :a)
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  def remove_node(dag, id) do
    Models.remove_node(dag, id)
  end

  # ============================================================
  # Edge Operations
  # ============================================================

  @doc """
  Adds an edge to the DAG.

  Because adding an edge can potentially create a cycle, this operation
  validates the resulting graph and returns a Result type.

  ## Examples

      {:ok, dag} = Yog.DAG.add_edge(dag, :a, :b, 1)
      {:error, :cycle_detected} = Yog.DAG.add_edge(dag, :b, :a, 1)  # Would create cycle
  """
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) ::
          {:ok, t()} | {:error, :cycle_detected}
  def add_edge(dag, from, to, weight) do
    Models.add_edge(dag, from, to, weight)
  end

  @doc """
  Removes an edge from the DAG.

  Removing edges cannot create a cycle.

  ## Examples

      dag = Yog.DAG.remove_edge(dag, :a, :b)
  """
  @spec remove_edge(t(), Yog.node_id(), Yog.node_id()) :: t()
  def remove_edge(dag, from, to) do
    Models.remove_edge(dag, from, to)
  end

  # ============================================================
  # Algorithms (delegated to Algorithms module)
  # ============================================================

  @doc """
  Returns a topological ordering of all nodes in the DAG.

  Unlike `Yog.traversal.topological_sort/1` which returns a Result (since general
  graphs may contain cycles), this version always returns a valid ordering
  because the DAG type guarantees acyclicity.

  In a topological ordering, every node appears before all nodes it has edges to.

  ## Examples

      # Given edges: 1->2, 1->3, 2->4, 3->4
      # Valid topological sorts include: [1, 2, 3, 4] or [1, 3, 2, 4]
      sorted = Yog.DAG.topological_sort(dag)
  """
  @spec topological_sort(t()) :: [Yog.node_id()]
  def topological_sort(dag) do
    Algorithms.topological_sort(dag)
  end

  @doc """
  Finds the longest path (critical path) in a weighted DAG.

  The longest path is the path with maximum total edge weight from any source
  node to any sink node. This is the dual of shortest path and is useful for:
  - Project scheduling (finding the critical path)
  - Dependency chains with durations
  - Determining minimum time to complete all tasks

  ## Examples

      critical_path = Yog.DAG.longest_path(dag)
      #=> [:start, :task_a, :task_b, :end]
  """
  @spec longest_path(t()) :: [Yog.node_id()]
  def longest_path(dag) do
    Algorithms.longest_path(dag)
  end

  @doc """
  Computes the transitive closure of the DAG.

  The transitive closure adds an edge from node A to node C whenever there is
  a path from A to C. The result is a DAG where reachability can be checked
  in O(1) by looking for a direct edge.

  ## Examples

      closure = Yog.DAG.transitive_closure(dag)
  """
  @spec transitive_closure(t()) :: t()
  def transitive_closure(dag) do
    Algorithms.transitive_closure(dag)
  end

  @doc """
  Computes the transitive reduction of the DAG.

  The transitive reduction removes edges that are implied by transitivity.
  It produces the minimal DAG with the same reachability properties.

  ## Examples

      reduction = Yog.DAG.transitive_reduction(dag)
  """
  @spec transitive_reduction(t()) :: t()
  def transitive_reduction(dag) do
    Algorithms.transitive_reduction(dag)
  end

  @doc """
  Finds the shortest path between two nodes in a weighted DAG.

  Uses dynamic programming on the topologically sorted DAG for efficiency.

  ## Examples

      case Yog.DAG.shortest_path(dag, :a, :d) do
        {:some, path} -> path.nodes
        :none -> :no_path
      end
  """
  @spec shortest_path(t(), Yog.node_id(), Yog.node_id()) ::
          {:some, Yog.Pathfinding.Utils.path(any())} | :none
  def shortest_path(dag, from, to) do
    Algorithms.shortest_path(dag, from, to)
  end

  @doc """
  Counts the number of ancestors or descendants for every node.

  For each node, returns how many other nodes are reachable from it
  (`:descendants`) or can reach it (`:ancestors`).

  ## Examples

      # Count descendants (nodes reachable from each node)
      descendant_counts = Yog.DAG.count_reachability(dag, :descendants)

      # Count ancestors (nodes that can reach each node)
      ancestor_counts = Yog.DAG.count_reachability(dag, :ancestors)
  """
  @spec count_reachability(t(), :ancestors | :descendants) :: %{Yog.node_id() => integer()}
  def count_reachability(dag, direction) do
    Algorithms.count_reachability(dag, direction)
  end

  @doc """
  Finds the lowest common ancestors (LCAs) of two nodes.

  A common ancestor of nodes A and B is any node that has paths to both A and B.
  The "lowest" common ancestors are those that are not ancestors of any other
  common ancestor - they are the "closest" shared dependencies.

  This is useful for:
  - Finding merge bases in version control
  - Identifying shared dependencies
  - Computing dominators in control flow graphs

  ## Examples

      # Given: X->A, X->B, Y->A, Z->B
      # LCAs of A and B are [X] - the most specific shared ancestor
      lcas = Yog.DAG.lowest_common_ancestors(dag, :a, :b)
      #=> [:x]
  """
  @spec lowest_common_ancestors(t(), Yog.node_id(), Yog.node_id()) :: [Yog.node_id()]
  def lowest_common_ancestors(dag, node_a, node_b) do
    Algorithms.lowest_common_ancestors(dag, node_a, node_b)
  end
end
