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


def min_cost_flow(graph, options):
    demands = options.get("demands", {})
    edge_attrs = options.get("edge_attrs", [])

    for node in graph.nodes:
        demand_val = demands.get(str(node))
        if demand_val is None:
            demand_val = demands.get(node, 0)
        graph.nodes[node]['demand'] = demand_val

    for attr in edge_attrs:
        u = attr["from"]
        v = attr["to"]
        u_typed = int(u) if (isinstance(u, str) and u.isdigit()) else u
        v_typed = int(v) if (isinstance(v, str) and v.isdigit()) else v
        if graph.has_edge(u_typed, v_typed):
            graph[u_typed][v_typed]['capacity'] = attr["capacity"]
            graph[u_typed][v_typed]['weight'] = attr["cost"]

    try:
        flow_cost, flow_dict = nx.network_simplex(graph)
        flow_list = []
        for u, neighbors in flow_dict.items():
            for v, val in neighbors.items():
                if val > 0:
                    flow_list.append([u, v, val])
        return {"status": "ok", "cost": flow_cost, "flow": flow_list}
    except nx.NetworkXUnfeasible:
        return {"status": "error", "reason": "infeasible"}
    except nx.NetworkXUnbalanced:
        return {"status": "error", "reason": "unbalanced"}
    except nx.NetworkXUnbounded:
        return {"status": "error", "reason": "unbounded"}


DISPATCH = {
    "maximum_flow": maximum_flow,
    "stoer_wagner": stoer_wagner,
    "min_cost_flow": min_cost_flow,
}
