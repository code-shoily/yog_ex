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


def bridges(graph, options):
    result = list(nx.bridges(graph))
    return [sorted(list(edge)) for edge in result]


def articulation_points(graph, options):
    result = list(nx.articulation_points(graph))
    return sorted(list(result))


DISPATCH = {
    "strongly_connected_components": strongly_connected_components,
    "connected_components": connected_components,
    "weakly_connected_components": weakly_connected_components,
    "bridges": bridges,
    "articulation_points": articulation_points,
}
