"""Graph property adapters for NetworkX oracle."""

import networkx as nx


def is_bipartite(graph, options):
    return nx.is_bipartite(graph)


def is_tree(graph, options):
    return nx.is_tree(graph)


def is_forest(graph, options):
    return nx.is_forest(graph)


def is_directed_acyclic_graph(graph, options):
    return nx.is_directed_acyclic_graph(graph)


def is_chordal(graph, options):
    return nx.is_chordal(graph)


def is_complete_graph(graph, options):
    n = graph.number_of_nodes()
    if n <= 1:
        return True
    expected = n * (n - 1) / 2
    return graph.number_of_edges() == expected


def graph_clique_number(graph, options):
    cliques = list(nx.find_cliques(graph))
    if not cliques:
        return 0
    return max(len(c) for c in cliques)


def _build_graph(spec):
    cls = nx.DiGraph if spec["directed"] else nx.Graph
    g = cls()
    for n in spec["nodes"]:
        g.add_node(n)
    for e in spec["edges"]:
        g.add_edge(e["from"], e["to"], weight=e["weight"])
    return g


def is_isomorphic(graph, options):
    other_graph = _build_graph(options["other_graph"])
    return nx.is_isomorphic(graph, other_graph)


DISPATCH = {
    "is_bipartite": is_bipartite,
    "is_tree": is_tree,
    "is_forest": is_forest,
    "is_directed_acyclic_graph": is_directed_acyclic_graph,
    "is_chordal": is_chordal,
    "is_complete_graph": is_complete_graph,
    "graph_clique_number": graph_clique_number,
    "is_isomorphic": is_isomorphic,
}
