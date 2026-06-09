"""MST adapters for NetworkX oracle."""

import networkx as nx


def minimum_spanning_tree(graph, options):
    algorithm = options.get("algorithm", "kruskal")
    weight = options.get("weight", "weight")
    mst = nx.minimum_spanning_tree(graph, algorithm=algorithm, weight=weight)
    total_weight = mst.size(weight=weight)
    return total_weight


def maximum_spanning_tree(graph, options):
    algorithm = options.get("algorithm", "kruskal")
    weight = options.get("weight", "weight")
    mst = nx.maximum_spanning_tree(graph, algorithm=algorithm, weight=weight)
    total_weight = mst.size(weight=weight)
    return total_weight


def minimum_spanning_arborescence(graph, options):
    weight = options.get("weight", "weight")
    arb = nx.minimum_spanning_arborescence(graph, attr=weight)
    total_weight = arb.size(weight=weight)
    return total_weight


DISPATCH = {
    "minimum_spanning_tree": minimum_spanning_tree,
    "maximum_spanning_tree": maximum_spanning_tree,
    "minimum_spanning_arborescence": minimum_spanning_arborescence,
}
