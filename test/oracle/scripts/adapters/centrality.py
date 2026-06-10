"""Centrality adapters for NetworkX oracle."""

import networkx as nx


def degree_centrality(graph, options):
    result = nx.degree_centrality(graph)
    return {str(k): v for k, v in result.items()}


def in_degree_centrality(graph, options):
    result = nx.in_degree_centrality(graph)
    return {str(k): v for k, v in result.items()}


def out_degree_centrality(graph, options):
    result = nx.out_degree_centrality(graph)
    return {str(k): v for k, v in result.items()}


def closeness_centrality(graph, options):
    wf_improved = options.get("wf_improved", True)
    # Use edge weights as distances to match Yog's weighted Dijkstra.
    result = nx.closeness_centrality(graph, wf_improved=wf_improved, distance="weight")
    return {str(k): v for k, v in result.items()}


def harmonic_centrality(graph, options):
    # Use edge weights as distances to match Yog (which runs Dijkstra
    # with the graph's edge weights).
    result = nx.harmonic_centrality(graph, distance="weight")
    return {str(k): v for k, v in result.items()}


def betweenness_centrality(graph, options):
    normalized = options.get("normalized", True)
    endpoints = options.get("endpoints", False)
    # Use edge weights to match Yog's weighted Brandes.
    result = nx.betweenness_centrality(
        graph, normalized=normalized, endpoints=endpoints, weight="weight"
    )
    return {str(k): v for k, v in result.items()}


def pagerank(graph, options):
    alpha = options.get("alpha", 0.85)
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    # Yog's PageRank is unweighted (uniform 1/out_degree transitions);
    # pass weight=None so NetworkX matches that convention.
    result = nx.pagerank(graph, alpha=alpha, tol=tol, max_iter=max_iter, weight=None)
    return {str(k): v for k, v in result.items()}


def hits(graph, options):
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    try:
        h, a = nx.hits(graph, normalized=True, max_iter=max_iter, tol=tol)
    except Exception as e:
        # NetworkX HITS uses scipy SVD which raises on degenerate
        # adjacency matrices (isolated nodes, certain disconnected
        # directed structures). Treat as out-of-class input for the
        # oracle and let the Elixir side skip the comparison.
        return {"error": "hits_undefined", "reason": str(e)[:200]}
    return {
        "hubs": {str(k): v for k, v in h.items()},
        "authorities": {str(k): v for k, v in a.items()},
    }


def eigenvector_centrality(graph, options):
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    try:
        result = nx.eigenvector_centrality(graph, tol=tol, max_iter=max_iter, weight=None)
    except nx.PowerIterationFailedConvergence:
        return {"error": "power_iteration_failed"}
    return {str(k): v for k, v in result.items()}


def katz_centrality(graph, options):
    alpha = options.get("alpha", 0.1)
    beta = options.get("beta", 1.0)
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    normalized = options.get("normalized", False)
    result = nx.katz_centrality(
        graph,
        alpha=alpha,
        beta=beta,
        tol=tol,
        max_iter=max_iter,
        weight=None,
        normalized=normalized
    )
    return {str(k): v for k, v in result.items()}


DISPATCH = {
    "degree_centrality": degree_centrality,
    "in_degree_centrality": in_degree_centrality,
    "out_degree_centrality": out_degree_centrality,
    "closeness_centrality": closeness_centrality,
    "harmonic_centrality": harmonic_centrality,
    "betweenness_centrality": betweenness_centrality,
    "pagerank": pagerank,
    "hits": hits,
    "eigenvector_centrality": eigenvector_centrality,
    "katz_centrality": katz_centrality,
}
