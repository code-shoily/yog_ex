"""Traversal adapters for NetworkX oracle."""

import networkx as nx


def bfs_layers(graph, options):
    """Return BFS layers as a list of lists from the given source."""
    source = options["source"]
    return list(nx.bfs_layers(graph, source))


def lexicographical_topological_sort(graph, options):
    """Return lexicographical topological sort as a list."""
    return list(nx.lexicographical_topological_sort(graph, key=lambda n: n))


def topological_generations(graph, options):
    """Return topological generations as a list of lists."""
    return list(nx.topological_generations(graph))


DISPATCH = {
    "bfs_layers": bfs_layers,
    "lexicographical_topological_sort": lexicographical_topological_sort,
    "topological_generations": topological_generations,
}
