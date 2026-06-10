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
    result = nx.closeness_centrality(graph, wf_improved=wf_improved)
    return {str(k): v for k, v in result.items()}


def harmonic_centrality(graph, options):
    result = nx.harmonic_centrality(graph)
    return {str(k): v for k, v in result.items()}


def betweenness_centrality(graph, options):
    normalized = options.get("normalized", True)
    endpoints = options.get("endpoints", False)
    result = nx.betweenness_centrality(graph, normalized=normalized, endpoints=endpoints)
    return {str(k): v for k, v in result.items()}


def pagerank(graph, options):
    alpha = options.get("alpha", 0.85)
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    result = nx.pagerank(graph, alpha=alpha, tol=tol, max_iter=max_iter, weight="weight")
    return {str(k): v for k, v in result.items()}


def hits(graph, options):
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    h, a = nx.hits(graph, normalized=True, max_iter=max_iter, tol=tol)
    return {
        "hubs": {str(k): v for k, v in h.items()},
        "authorities": {str(k): v for k, v in a.items()},
    }


def eigenvector_centrality(graph, options):
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    try:
        result = nx.eigenvector_centrality(graph, tol=tol, max_iter=max_iter, weight="weight")
    except nx.PowerIterationFailedConvergence:
        return {"error": "power_iteration_failed"}
    return {str(k): v for k, v in result.items()}


def katz_centrality(graph, options):
    alpha = options.get("alpha", 0.1)
    beta = options.get("beta", 1.0)
    tol = options.get("tol", 1.0e-10)
    max_iter = options.get("max_iter", 1000)
    result = nx.katz_centrality(graph, alpha=alpha, beta=beta, tol=tol, max_iter=max_iter, weight="weight")
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
