"""Oracle adapter dispatch table.

Each adapter module exposes a DISPATCH dict mapping algorithm names to
functions with signature `(nx.Graph | nx.DiGraph, dict) -> JSON-serializable`.
"""

from . import centrality
from . import connectivity
from . import flow
from . import matching
from . import mst
from . import pathfinding
from . import properties
from . import traversal

DISPATCH = {
    **pathfinding.DISPATCH,
    **flow.DISPATCH,
    **matching.DISPATCH,
    **mst.DISPATCH,
    **centrality.DISPATCH,
    **connectivity.DISPATCH,
    **properties.DISPATCH,
    **traversal.DISPATCH,
}
