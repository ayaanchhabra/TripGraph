-- queries/trips/01_cheapest_route.sql
-- cheapest_route(): best route from the NSUT Main Gate to a place, returned leg by leg.
--
-- How it works (explain this in the viva):
--   1. A RECURSIVE CTE starts at the gate and keeps adding one edge at a time,
--      keeping a running total of fare, time and the list of nodes visited.
--   2. CYCLE AVOIDANCE: an edge is skipped if it leads to a node already on the path.
--   3. LIMITS stop the recursion: total fare <= p_max_fare, number of legs <= p_max_legs.
--   4. Among paths that END at the place's node, keep only those where the place is
--      still OPEN when we arrive (uses is_open_at from queries/views/02_open_now.sql)
--      and arrival is before the optional deadline.
--   5. Pick the best one (cheapest, or fastest) and return it as ordered legs.
--
-- Parameters (all but the first are optional):
--   p_place_id   place to go to
--   p_start      when we leave (default: now, Indian time)
--   p_max_fare   maximum total fare in Rs (default 1000)
--   p_arrive_by  deadline as a timestamp, e.g. TIMESTAMP '2026-10-23 21:00' (default none)
--   p_optimize   'fare' (cheapest first, default) or 'time' (fastest first)
--   p_max_legs   maximum number of legs (default 6)
--   p_from_node  start node (default: the node named 'NSUT Main Gate')
--
-- Examples:
--   SELECT * FROM cheapest_route(1);
--   SELECT * FROM cheapest_route(1, p_optimize => 'time');
--   SELECT * FROM cheapest_route(2, TIMESTAMP '2026-10-23 20:00', p_max_fare => 50,
--                                   p_arrive_by => TIMESTAMP '2026-10-23 21:00');
--
-- Simplification: waiting time for metro/auto is not modelled; time_min is used as is.
-- No rows come back if no route fits the limits, or the place is closed on arrival.

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION cheapest_route(
  p_place_id  INT,
  p_start     TIMESTAMP DEFAULT (now() AT TIME ZONE 'Asia/Kolkata'),
  p_max_fare  NUMERIC   DEFAULT 1000,
  p_arrive_by TIMESTAMP DEFAULT NULL,
  p_optimize  TEXT      DEFAULT 'fare',
  p_max_legs  INT       DEFAULT 6,
  p_from_node INT       DEFAULT NULL
)
RETURNS TABLE (
  leg_no     INT,
  from_stop  TEXT,
  to_stop    TEXT,
  mode       TEXT,
  distance_m INT,
  time_min   INT,
  fare       NUMERIC,
  total_fare NUMERIC,
  total_time INT
)
LANGUAGE sql STABLE AS $$
  WITH RECURSIVE
  start_node AS (
    SELECT COALESCE(p_from_node, (SELECT node_id FROM node WHERE name = 'NSUT Main Gate')) AS node_id
  ),
  target AS (
    SELECT node_id FROM place WHERE place_id = p_place_id
  ),
  paths (last_node, node_path, edge_path, total_fare, total_time, legs) AS (
    -- start: at the gate, nothing spent yet
    SELECT s.node_id, ARRAY[s.node_id], ARRAY[]::INT[], 0::NUMERIC, 0, 0
    FROM start_node s
    UNION ALL
    -- step: follow one more edge from where the path currently ends
    SELECT e.to_node,
           p.node_path || e.to_node,
           p.edge_path || e.edge_id,
           p.total_fare + e.fare,
           p.total_time + e.time_min,
           p.legs + 1
    FROM paths p
    JOIN edge e ON e.from_node = p.last_node
    WHERE NOT (e.to_node = ANY (p.node_path))        -- no going in circles
      AND p.total_fare + e.fare <= p_max_fare        -- fare budget
      AND p.legs < p_max_legs                        -- leg limit
  ),
  best AS (
    SELECT p.*
    FROM paths p
    JOIN target t ON t.node_id = p.last_node
    WHERE p.legs > 0
      AND is_open_at(p_place_id, p_start + p.total_time * INTERVAL '1 minute')
      AND (p_arrive_by IS NULL
           OR p_start + p.total_time * INTERVAL '1 minute' <= p_arrive_by)
    ORDER BY CASE WHEN p_optimize = 'time' THEN p.total_time ELSE p.total_fare END,
             CASE WHEN p_optimize = 'time' THEN p.total_fare ELSE p.total_time END
    LIMIT 1
  )
  SELECT l.leg_no::INT,
         nf.name,
         nt.name,
         e.mode,
         e.distance_m,
         e.time_min,
         e.fare::NUMERIC,
         SUM(e.fare)     OVER (ORDER BY l.leg_no)::NUMERIC,
         SUM(e.time_min) OVER (ORDER BY l.leg_no)::INT
  FROM best b
  CROSS JOIN LATERAL unnest(b.edge_path) WITH ORDINALITY AS l(edge_id, leg_no)
  JOIN edge e  ON e.edge_id  = l.edge_id
  JOIN node nf ON nf.node_id = e.from_node
  JOIN node nt ON nt.node_id = e.to_node
  ORDER BY l.leg_no;
$$;
