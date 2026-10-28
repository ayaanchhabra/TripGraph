-- queries/views/cheapest_edges.sql
-- For every pair of map nodes that is joined by more than one edge (for example a free walk,
-- an e-rickshaw and a bus between the same two stops), keep only the cheapest one.
-- Ties on fare are broken by the shorter time, then the shorter distance, then edge_id.
-- Uses a window function (ROW_NUMBER) to rank the edges inside each pair.
--
--   SELECT * FROM cheapest_edges WHERE from_name = 'NSUT Main Gate';
--   SELECT * FROM cheapest_edges WHERE alternatives > 0;   -- pairs where a cheaper choice was dropped
--
-- Run after the schema. Run security/02_grants.sql again afterwards so the roles can read it.

CREATE OR REPLACE VIEW cheapest_edges AS
SELECT r.edge_id,
       r.from_node,
       nf.name AS from_name,
       r.to_node,
       nt.name AS to_name,
       r.mode,
       r.distance_m,
       r.time_min,
       r.fare,
       r.alternatives
FROM (SELECT e.*,
             ROW_NUMBER() OVER (PARTITION BY e.from_node, e.to_node
                                ORDER BY e.fare, e.time_min, e.distance_m, e.edge_id) AS rn,
             COUNT(*)     OVER (PARTITION BY e.from_node, e.to_node) - 1 AS alternatives
      FROM edge e) r
JOIN node nf ON nf.node_id = r.from_node
JOIN node nt ON nt.node_id = r.to_node
WHERE r.rn = 1;