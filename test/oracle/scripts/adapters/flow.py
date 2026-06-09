"""Flow & cuts adapters for NetworkX oracle."""

import networkx as nx


def maximum_flow(graph, options):
    """Generic max-flow dispatcher used by Edmonds-Karp and Dinic tests."""
    source = options["source"]
    sink = options["target"]
    flow_func_name = options.get("flow_func", "edmonds_karp")
    capacity = options.get("capacity", "capacity")

    flow_func = getattr(nx.algorithms.flow, flow_func_name)

    flow_value, _ = nx.maximum_flow(graph, source, sink, capacity=capacity, flow_func=flow_func)
    return flow_value


def stoer_wagner(graph, options):
    """Global min cut — returns cut value only (partition is non-unique)."""
    cut_value, _ = nx.stoer_wagner(graph, weight=options.get("weight", "weight"))
    return cut_value


DISPATCH = {
    "maximum_flow": maximum_flow,
    "stoer_wagner": stoer_wagner,
}
