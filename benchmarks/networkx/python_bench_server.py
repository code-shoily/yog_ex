#!/usr/bin/env python3
import sys
import json
import warnings

# Suppress warnings to prevent output pollution on stdout/stderr
warnings.filterwarnings("ignore")

import networkx as nx

# Store graphs globally so we don't have to serialize/deserialize them on every algorithm run
GRAPHS = {}

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            cmd = req.get("cmd")
            if cmd == "ping":
                sys.stdout.write(json.dumps({"status": "ok"}) + "\n")
                sys.stdout.flush()
            elif cmd == "build_graph":
                graph_id = req["graph_id"]
                directed = req["directed"]
                nodes = req["nodes"]
                edges = req["edges"]
                
                g = nx.DiGraph() if directed else nx.Graph()
                g.add_nodes_from(nodes)
                for e in edges:
                    # e is {"from": u, "to": v, "weight": w}
                    g.add_edge(e["from"], e["to"], weight=e.get("weight", 1.0))
                
                GRAPHS[graph_id] = g
                sys.stdout.write(json.dumps({"status": "ok"}) + "\n")
                sys.stdout.flush()
            elif cmd == "clear":
                GRAPHS.clear()
                sys.stdout.write(json.dumps({"status": "ok"}) + "\n")
                sys.stdout.flush()
            elif cmd == "run":
                graph_id = req["graph_id"]
                algo = req["algorithm"]
                opts = req.get("options", {})
                
                g = GRAPHS.get(graph_id)
                if g is None:
                    sys.stdout.write(json.dumps({"status": "error", "reason": f"Graph {graph_id} not found"}) + "\n")
                    sys.stdout.flush()
                    continue
                
                # Execute the algorithm
                res = execute_algo(g, algo, opts)
                sys.stdout.write(json.dumps({"status": "ok", "result": res}) + "\n")
                sys.stdout.flush()
            else:
                sys.stdout.write(json.dumps({"status": "error", "reason": f"Unknown command {cmd}"}) + "\n")
                sys.stdout.flush()
        except Exception as e:
            sys.stdout.write(json.dumps({"status": "error", "reason": str(e)}) + "\n")
            sys.stdout.flush()

def execute_algo(g, algo, opts):
    if algo == "topological_sort":
        return len(list(nx.topological_sort(g)))

    elif algo == "dijkstra":
        source = opts["source"]
        target = opts["target"]
        return nx.dijkstra_path_length(g, source, target, weight="weight")
        
    elif algo == "bellman_ford":
        source = opts["source"]
        target = opts["target"]
        return nx.bellman_ford_path_length(g, source, target, weight="weight")
        
    elif algo == "a_star":
        source = opts["source"]
        target = opts["target"]
        grid_n = opts.get("grid_n")
        if grid_n:
            def h(u, v):
                ux, uy = divmod(u, grid_n)
                vx, vy = divmod(v, grid_n)
                return abs(ux - vx) + abs(uy - vy)
            return nx.astar_path_length(g, source, target, heuristic=h, weight="weight")
        else:
            return nx.astar_path_length(g, source, target, weight="weight")
            
    elif algo == "bidirectional_dijkstra":
        source = opts["source"]
        target = opts["target"]
        length, _path = nx.bidirectional_dijkstra(g, source, target, weight="weight")
        return length
        
    elif algo == "pagerank":
        # Returns a dict
        return len(nx.pagerank(g))
        
    elif algo == "betweenness_centrality":
        return len(nx.betweenness_centrality(g))
        
    elif algo == "closeness_centrality":
        return len(nx.closeness_centrality(g))
        
    elif algo == "louvain":
        return len(list(nx.community.louvain_communities(g)))
        
    elif algo == "label_propagation":
        return len(list(nx.community.label_propagation_communities(g)))
        
    elif algo == "edmonds_karp":
        source = opts["source"]
        target = opts["target"]
        return nx.maximum_flow_value(g, source, target, capacity="weight", flow_func=nx.algorithms.flow.edmonds_karp)
        
    elif algo == "dinic":
        source = opts["source"]
        target = opts["target"]
        return nx.maximum_flow_value(g, source, target, capacity="weight", flow_func=nx.algorithms.flow.dinitz)
        
    elif algo == "kruskal":
        mst = nx.minimum_spanning_tree(g, algorithm="kruskal", weight="weight")
        return mst.size(weight="weight")
        
    elif algo == "prim":
        mst = nx.minimum_spanning_tree(g, algorithm="prim", weight="weight")
        return mst.size(weight="weight")
        
    elif algo == "connected_components":
        return len(list(nx.connected_components(g)))
        
    elif algo == "strongly_connected_components":
        return len(list(nx.strongly_connected_components(g)))
        
    else:
        raise ValueError(f"Unsupported algorithm: {algo}")

if __name__ == "__main__":
    main()
