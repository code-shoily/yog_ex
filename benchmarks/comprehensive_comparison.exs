# Comprehensive comparison between Yog, libgraph, and :digraph using Benchee.

alias Yog.Generator.Random

# Helper to generate native graphs for each library
generate_graphs = fn n, m ->
  # Yog
  yog = Random.erdos_renyi_gnp_with_type(n, m / (n * (n - 1)), :directed, 42)

  # libgraph
  libgraph = Graph.new()
  libgraph = Enum.reduce(0..(n - 1), libgraph, fn i, g -> Graph.add_vertex(g, i) end)
  # Extract edges from Yog to ensure identical structure
  yog_edges = Yog.Model.all_edges(yog)

  libgraph =
    Enum.reduce(yog_edges, libgraph, fn {u, v, w}, g -> Graph.add_edge(g, u, v, weight: w) end)

  # :digraph
  dg = :digraph.new()
  Enum.each(0..(n - 1), fn i -> :digraph.add_vertex(dg, i) end)
  Enum.each(yog_edges, fn {u, v, _w} -> :digraph.add_edge(dg, u, v) end)

  {yog, libgraph, dg}
end

IO.puts("Generating test graphs...")
small = generate_graphs.(100, 150)
medium = generate_graphs.(500, 1000)
large = generate_graphs.(1000, 3000)

top_inputs = %{
  "Small (100n, 150e)" => small,
  "Medium (500n, 1000e)" => medium
}

IO.puts("\n== Topological Sort Comparison ==")

Benchee.run(
  %{
    "Yog (Kahn)" => fn {yog, _, _} -> Yog.Traversal.Sort.topological_sort(yog) end,
    "libgraph (DFS)" => fn {_, lib, _} -> Graph.topsort(lib) end,
    ":digraph (DFS)" => fn {_, _, dg} -> :digraph_utils.topsort(dg) end
  },
  inputs: top_inputs,
  time: 1,
  warmup: 1
)

IO.puts("\n== Connected Components (Undirected) ==")
# Extract undirected variants
generate_undirected = fn {yog, lib, dg} ->
  yog_u = Yog.Transform.to_undirected(yog, &max/2)

  lib_u = Graph.new(type: :undirected)
  lib_u = Enum.reduce(Graph.vertices(lib), lib_u, fn v, g -> Graph.add_vertex(g, v) end)

  lib_u =
    Enum.reduce(Graph.edges(lib), lib_u, fn %Graph.Edge{v1: u, v2: v, weight: w}, g ->
      Graph.add_edge(g, u, v, weight: w)
    end)

  dg_u = :digraph.new()
  Enum.each(:digraph.vertices(dg), fn v -> :digraph.add_vertex(dg_u, v) end)

  Enum.each(Yog.Model.all_edges(yog_u), fn {u, v, _} ->
    :digraph.add_edge(dg_u, u, v)
    :digraph.add_edge(dg_u, v, u)
  end)

  {yog_u, lib_u, dg_u}
end

small_u = generate_undirected.(small)
medium_u = generate_undirected.(medium)

Benchee.run(
  %{
    "Yog" => fn {yog, _, _} -> Yog.Connectivity.Components.connected_components(yog) end,
    "libgraph" => fn {_, lib, _} -> Graph.components(lib) end,
    ":digraph" => fn {_, _, dg} -> :digraph_utils.components(dg) end
  },
  inputs: %{"Small" => small_u, "Medium" => medium_u},
  time: 1,
  warmup: 1
)

IO.puts("\n== Strongly Connected Components ==")

Benchee.run(
  %{
    "Yog (Tarjan)" => fn {yog, _, _} ->
      Yog.Connectivity.SCC.strongly_connected_components(yog)
    end,
    "libgraph" => fn {_, lib, _} -> Graph.strong_components(lib) end,
    ":digraph" => fn {_, _, dg} -> :digraph_utils.strong_components(dg) end
  },
  inputs: top_inputs,
  time: 5,
  warmup: 2
)

IO.puts("\n== Shortest Path (Random Query) ==")
{yog_m, lib_m, dg_m} = medium
source = 0
target = 499

Benchee.run(
  %{
    "Yog (Dijkstra)" => fn ->
      Yog.Pathfinding.Dijkstra.shortest_path(in: yog_m, from: source, to: target)
    end,
    "libgraph (Dijkstra)" => fn -> Graph.dijkstra(lib_m, source, target) end,
    ":digraph (BFS)" => fn -> :digraph.get_short_path(dg_m, source, target) end
  },
  time: 1,
  warmup: 1
)

# Cleanup :digraphs
Enum.each([small, medium, large, small_u, medium_u], fn {_, _, dg} -> :digraph.delete(dg) end)
