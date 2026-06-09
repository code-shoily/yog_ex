"""Oracle adapter dispatch table.

Each adapter module exposes a DISPATCH dict mapping algorithm names to
functions with signature `(nx.Graph | nx.DiGraph, dict) -> JSON-serializable`.
"""

from . import centrality
from . import flow
from . import mst
from . import pathfinding

DISPATCH = {
    **pathfinding.DISPATCH,
    **flow.DISPATCH,
    **mst.DISPATCH,
    **centrality.DISPATCH,
}
