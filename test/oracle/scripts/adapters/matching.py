"""Graph matching adapters for NetworkX oracle."""

import networkx as nx


def _matching_cost(graph, matching_dict):
    """Sum edge weights for each matched pair exactly once."""
    seen = set()
    total = 0
    for u, v in matching_dict.items():
        if u not in seen:
            seen.add(u)
            seen.add(v)
            total += graph[u][v].get("weight", 1)
    return total


def hopcroft_karp(graph, options):
    """Return cardinality of a maximum bipartite matching."""
    if graph.number_of_nodes() == 0:
        return 0

    color = nx.bipartite.color(graph)
    top_nodes = {n for n, c in color.items() if c == 0}
    matching = nx.bipartite.maximum_matching(graph, top_nodes=top_nodes)
    return len(matching) // 2


def blossom_maximum_matching(graph, options):
    """Return cardinality of a maximum matching in a general graph."""
    matching = nx.algorithms.matching.max_weight_matching(
        graph, maxcardinality=True, weight="weight"
    )
    return len(matching)


def minimum_weight_full_matching(graph, options):
    """Return total weight of a minimum/maximum weight full matching."""
    if graph.number_of_nodes() == 0:
        return 0

    color = nx.bipartite.color(graph)
    top_nodes = {n for n, c in color.items() if c == 0}
    opt = options.get("optimization", "min")

    if opt == "max":
        # Negate weights to turn max into min
        G = graph.copy()
        for u, v, data in G.edges(data=True):
            data["weight"] = -data.get("weight", 1)
        result = nx.bipartite.minimum_weight_full_matching(
            G, top_nodes=top_nodes, weight="weight"
        )
        # The negated total is the minimum; negate back for maximum
        return -_matching_cost(G, result)
    else:
        result = nx.bipartite.minimum_weight_full_matching(
            graph, top_nodes=top_nodes, weight="weight"
        )
        return _matching_cost(graph, result)


DISPATCH = {
    "hopcroft_karp": hopcroft_karp,
    "blossom_maximum_matching": blossom_maximum_matching,
    "minimum_weight_full_matching": minimum_weight_full_matching,
}
