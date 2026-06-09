#!/usr/bin/env python3
"""NetworkX oracle entry point.

Reads a JSON payload from stdin or from the file given as the first
argument, dispatches to the appropriate adapter, and writes the JSON
result to stdout.

Payload shape:
    {
        "algorithm": "dijkstra_path_length",
        "graph": {
            "directed": false,
            "nodes": [1, 2, 3],
            "edges": [
                {"from": 1, "to": 2, "weight": 5},
                {"from": 2, "to": 3, "weight": 2}
            ]
        },
        "options": {
            "source": 1,
            "target": 3,
            "weight": "weight"
        }
    }
"""

import json
import sys

import networkx as nx

from adapters import DISPATCH


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r") as f:
            payload = json.load(f)
    else:
        payload = json.load(sys.stdin)

    graph = build_graph(payload["graph"])
    result = DISPATCH[payload["algorithm"]](graph, payload.get("options", {}))
    json.dump(result, sys.stdout)


def build_graph(spec):
    cls = nx.DiGraph if spec["directed"] else nx.Graph
    g = cls()
    for n in spec["nodes"]:
        g.add_node(n)
    for e in spec["edges"]:
        g.add_edge(e["from"], e["to"], weight=e["weight"])
    return g


if __name__ == "__main__":
    main()
