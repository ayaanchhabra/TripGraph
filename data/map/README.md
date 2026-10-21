# Mini map (A)

15 nodes and 32 edges (16 two-way roads stored as 2 directed rows each).

Files
- nodes.csv: node(node_id, name, kind)
- edges.csv: edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare)
- load_map.sql: loads both CSVs (nodes first, then edges)
- validate_map.sql: sanity checks to run after loading

Conventions
- node.kind values: gate, erickshaw_stand, bus_stop, metro, place
- edge.mode values: walk, erickshaw, auto, metro
- Walking fare is 0.
- Every two-way road has two rows (edge ids 1-16 forward, 17-32 reverse).
- Names, distances and fares are estimates and should be adjusted to the real area.
- Place nodes (Cafe X, Dhaba Y, ...) are what place.node_id will point to.
