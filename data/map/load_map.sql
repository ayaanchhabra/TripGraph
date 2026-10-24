-- data/map/load_map.sql
-- Loads the hand-built mini map into node and edge.
-- Run from the REPO ROOT (so the relative paths work):
--   psql -U postgres -d tripgraph -f data/map/load_map.sql
-- Requires K's schema (schema/01_tables.sql) to be loaded first.
-- Nodes must load before edges because edge has foreign keys to node.

BEGIN;

\copy node(node_id, name, kind) FROM 'data/map/nodes.csv' WITH (FORMAT csv, HEADER true)
\copy edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) FROM 'data/map/edges.csv' WITH (FORMAT csv, HEADER true)

-- If node_id / edge_id are SERIAL, move the sequences past the loaded ids.
-- (Returns NULL and does nothing if the column is not serial.)
SELECT setval(pg_get_serial_sequence('node', 'node_id'), (SELECT max(node_id) FROM node));
SELECT setval(pg_get_serial_sequence('edge', 'edge_id'), (SELECT max(edge_id) FROM edge));

COMMIT;

-- To reload from scratch while no places/trips exist yet, uncomment and run first:
-- DELETE FROM edge;
-- DELETE FROM node;
