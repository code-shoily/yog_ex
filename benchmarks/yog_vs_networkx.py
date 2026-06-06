import sys
import time
import networkx as nx

def main():
    if len(sys.argv) < 5:
        print("Usage: python yog_vs_networkx.py <N> <m> <N_small> <seed>")
        sys.exit(1)

    n = int(sys.argv[1])
    m = int(sys.argv[2])
    n_small = int(sys.argv[3])
    seed = int(sys.argv[4])

    # --- 1. Large Graph generation for PageRank and Louvain ---
    G = nx.barabasi_albert_graph(n, m, seed=seed)
    # Ensure edges have weight 1.0
    for u, v in G.edges():
        G[u][v]['weight'] = 1.0

    # PageRank (max 20 iterations, tol 1e-6)
    from networkx.algorithms.link_analysis.pagerank_alg import _pagerank_python
    t0 = time.perf_counter()
    _pagerank_python(G, alpha=0.85, max_iter=20, tol=1e-6)
    pagerank_time = (time.perf_counter() - t0) * 1000

    # Louvain Community Detection
    t0 = time.perf_counter()
    nx.community.louvain_communities(G, seed=seed)
    louvain_time = (time.perf_counter() - t0) * 1000

    # Dijkstra Pathfinding
    t0 = time.perf_counter()
    nx.dijkstra_path(G, 0, n - 1)
    dijkstra_time = (time.perf_counter() - t0) * 1000

    # --- 2. Small Dense Graph for Floyd-Warshall ---
    # Generate a dense graph of size n_small
    G_small = nx.gnp_random_graph(n_small, 0.4, seed=seed, directed=True)
    # Ensure positive weights for Floyd-Warshall
    for u, v in G_small.edges():
        G_small[u][v]['weight'] = 1.0

    t0 = time.perf_counter()
    nx.floyd_warshall(G_small)
    floyd_time = (time.perf_counter() - t0) * 1000

    print(f"pagerank_time:{pagerank_time:.2f}")
    print(f"louvain_time:{louvain_time:.2f}")
    print(f"dijkstra_time:{dijkstra_time:.2f}")
    print(f"floyd_time:{floyd_time:.2f}")

if __name__ == '__main__':
    main()
