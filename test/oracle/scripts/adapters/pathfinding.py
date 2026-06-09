"""Pathfinding adapters for NetworkX oracle."""

import networkx as nx


def health_check(graph, options):
    return {
        "node_count": graph.number_of_nodes(),
        "edge_count": graph.number_of_edges(),
        "directed": graph.is_directed(),
    }


def single_source_dijkstra_path_length(graph, options):
    source = options["source"]
    weight = options.get("weight", "weight")
    try:
        result = nx.single_source_dijkstra_path_length(graph, source, weight=weight)
    except nx.NetworkXNodeNotFound:
        return {"error": "node_not_found"}
    return {str(k): v for k, v in result.items()}


def dijkstra_path_length(graph, options):
    source = options["source"]
    target = options["target"]
    weight = options.get("weight", "weight")
    try:
        return nx.dijkstra_path_length(graph, source, target, weight=weight)
    except nx.NetworkXNoPath:
        return {"error": "no_path"}


def astar_path(graph, options):
    source = options["source"]
    target = options["target"]
    weight = options.get("weight", "weight")
    try:
        path = nx.astar_path(graph, source, target, weight=weight)
    except nx.NetworkXNoPath:
        return {"error": "no_path"}
    return path


def bellman_ford_path_length(graph, options):
    source = options["source"]
    target = options["target"]
    weight = options.get("weight", "weight")
    try:
        return nx.bellman_ford_path_length(graph, source, target, weight=weight)
    except nx.NetworkXUnbounded:
        return {"error": "negative_cycle"}
    except nx.NetworkXNoPath:
        return {"error": "no_path"}


def floyd_warshall(graph, options):
    weight = options.get("weight", "weight")
    result = nx.floyd_warshall(graph, weight=weight)
    out = {}
    for k, v in result.items():
        row = {}
        for kk, vv in v.items():
            if vv == float('inf'):
                row[str(kk)] = "__Inf__"
            else:
                row[str(kk)] = vv
        out[str(k)] = row
    return out


def johnson(graph, options):
    weight = options.get("weight", "weight")
    paths = nx.johnson(graph, weight=weight)
    # NetworkX johnson returns dict-of-dicts of *paths*, not distances.
    # Compute distances by summing edge weights along each path.
    out = {}
    for u, dests in paths.items():
        row = {}
        for v, path in dests.items():
            dist = 0
            for i in range(len(path) - 1):
                dist += graph[path[i]][path[i + 1]].get(weight, 1)
            row[str(v)] = dist
        out[str(u)] = row
    return out


def bidirectional_dijkstra(graph, options):
    source = options["source"]
    target = options["target"]
    weight = options.get("weight", "weight")
    try:
        length, path = nx.bidirectional_dijkstra(graph, source, target, weight=weight)
    except nx.NetworkXNoPath:
        return {"error": "no_path"}
    return {"length": length, "path": path}


def bidirectional_shortest_path(graph, options):
    source = options["source"]
    target = options["target"]
    try:
        path = nx.bidirectional_shortest_path(graph, source, target)
    except nx.NetworkXNoPath:
        return {"error": "no_path"}
    return path


def shortest_simple_paths(graph, options):
    source = options["source"]
    target = options["target"]
    k = options.get("k", 3)
    gen = nx.shortest_simple_paths(graph, source, target, weight=options.get("weight", "weight"))
    return [list(p) for p in __import__("itertools").islice(gen, k)]


def single_source_shortest_path_length(graph, options):
    source = options["source"]
    result = nx.single_source_shortest_path_length(graph, source)
    return {str(k): v for k, v in result.items()}


def all_pairs_shortest_path_length(graph, options):
    result = dict(nx.all_pairs_shortest_path_length(graph))
    return {str(k): {str(kk): vv for kk, vv in v.items()} for k, v in result.items()}


DISPATCH = {
    "health_check": health_check,
    "single_source_dijkstra_path_length": single_source_dijkstra_path_length,
    "dijkstra_path_length": dijkstra_path_length,
    "astar_path": astar_path,
    "bellman_ford_path_length": bellman_ford_path_length,
    "floyd_warshall": floyd_warshall,
    "johnson": johnson,
    "bidirectional_dijkstra": bidirectional_dijkstra,
    "bidirectional_shortest_path": bidirectional_shortest_path,
    "shortest_simple_paths": shortest_simple_paths,
    "single_source_shortest_path_length": single_source_shortest_path_length,
    "all_pairs_shortest_path_length": all_pairs_shortest_path_length,
}
