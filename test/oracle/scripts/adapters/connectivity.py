"""Connectivity adapters for NetworkX oracle."""

import networkx as nx


def strongly_connected_components(graph, options):
    result = list(nx.strongly_connected_components(graph))
    return [sorted(list(c)) for c in result]


def connected_components(graph, options):
    result = list(nx.connected_components(graph))
    return [sorted(list(c)) for c in result]


def weakly_connected_components(graph, options):
    result = list(nx.weakly_connected_components(graph))
    return [sorted(list(c)) for c in result]


DISPATCH = {
    "strongly_connected_components": strongly_connected_components,
    "connected_components": connected_components,
    "weakly_connected_components": weakly_connected_components,
}
