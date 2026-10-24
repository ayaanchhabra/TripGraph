-- data/map/validate_map.sql
-- Sanity checks after loading the map. Run from the repo root:
--   psql -U postgres -d tripgraph -f data/map/validate_map.sql

\echo '1. Row counts (expect 15 nodes, 32 edges)'
SELECT (SELECT count(*) FROM node) AS nodes, (SELECT count(*) FROM edge) AS edges;

\echo '2. Edges pointing to missing nodes (expect 0 rows)'
SELECT e.edge_id FROM edge e
LEFT JOIN node f ON f.node_id = e.from_node
LEFT JOIN node t ON t.node_id = e.to_node
WHERE f.node_id IS NULL OR t.node_id IS NULL;

\echo '3. Nodes with no edges (expect 0 rows)'
SELECT n.node_id, n.name FROM node n
WHERE NOT EXISTS (SELECT 1 FROM edge e WHERE e.from_node = n.node_id OR e.to_node = n.node_id);

\echo '4. Edges with no reverse edge (expect 0 rows)'
SELECT e.edge_id, e.from_node, e.to_node FROM edge e
WHERE NOT EXISTS (
  SELECT 1 FROM edge r
  WHERE r.from_node = e.to_node AND r.to_node = e.from_node AND r.mode = e.mode
);

\echo '5. Negative fares (expect 0 rows)'
SELECT edge_id, fare FROM edge WHERE fare < 0;

\echo '6. Nodes NOT reachable from NSUT Main Gate (expect 0 rows)'
WITH RECURSIVE reach(node_id) AS (
  SELECT node_id FROM node WHERE name = 'NSUT Main Gate'
  UNION
  SELECT e.to_node FROM reach r JOIN edge e ON e.from_node = r.node_id
)
SELECT n.node_id, n.name FROM node n
WHERE n.node_id NOT IN (SELECT node_id FROM reach);

\echo '7. Edge count by mode'
SELECT mode, count(*) FROM edge GROUP BY mode ORDER BY mode;
