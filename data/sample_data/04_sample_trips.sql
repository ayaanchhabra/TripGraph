-- data/sample_data/04_sample_trips.sql
-- Purpose: 2 sample trips made of REAL connected edges from the map.
--   Trip 1 (Aarav): NSUT Main Gate to Sample Movie Hall, cheapest route (walk, e-rickshaw, metro, walk)
--   Trip 2 (Diya):  NSUT Main Gate to Sample Daily Needs Store, fastest route
-- The edges are chosen by a recursive query, so consecutive legs always connect
-- (the trip-leg trigger would reject them otherwise). The trigger stays ENABLED.
-- How to run (after 01_sample_users.sql and with the map loaded):
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f data/sample_data/04_sample_trips.sql
-- Re-runnable: the two sample users' old trips are deleted first, then created again.
-- Needs a node named exactly 'NSUT Main Gate'.

-- Helper that exists only for this run (a temporary function, gone when psql exits).
-- It walks the map from the gate with a recursive CTE, never revisiting a node, up to 6 legs,
-- and returns the edge ids of the cheapest (or fastest) route to the named place.
CREATE OR REPLACE FUNCTION pg_temp.sample_route(p_place_name TEXT, p_fastest BOOLEAN)
RETURNS INT[]
LANGUAGE sql AS $$
  WITH RECURSIVE paths (last_node, node_path, edge_path, total_fare, total_time, legs) AS (
    SELECT n.node_id, ARRAY[n.node_id], ARRAY[]::INT[], 0::NUMERIC, 0, 0
    FROM node n
    WHERE n.name = 'NSUT Main Gate'
    UNION ALL
    SELECT e.to_node,
           p.node_path || e.to_node,
           p.edge_path || e.edge_id,
           p.total_fare + e.fare,
           p.total_time + e.time_min,
           p.legs + 1
    FROM paths p
    JOIN edge e ON e.from_node = p.last_node
    WHERE NOT (e.to_node = ANY (p.node_path))
      AND p.legs < 6
  )
  SELECT p.edge_path
  FROM paths p
  WHERE p.legs > 0
    AND p.last_node = (SELECT node_id FROM place WHERE name = p_place_name)
  ORDER BY CASE WHEN p_fastest THEN p.total_time ELSE p.total_fare END,
           CASE WHEN p_fastest THEN p.total_fare ELSE p.total_time END
  LIMIT 1;
$$;

-- Stop with a readable message if the map or places are not loaded
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM node WHERE name = 'NSUT Main Gate') THEN
    RAISE EXCEPTION 'Sample trips: no node named NSUT Main Gate. Load the map first (data/load_all.sql).';
  END IF;
  IF pg_temp.sample_route('Sample Movie Hall', false) IS NULL
     OR pg_temp.sample_route('Sample Daily Needs Store', true) IS NULL THEN
    RAISE EXCEPTION 'Sample trips: no route found to Sample Movie Hall or Sample Daily Needs Store. Load the map and places first (data/load_all.sql).';
  END IF;
  IF (SELECT count(*) FROM app_user WHERE email IN ('aarav.sharma@example.com', 'diya.verma@example.com')) < 2 THEN
    RAISE EXCEPTION 'Sample trips: sample users are missing. Run data/sample_data/01_sample_users.sql first.';
  END IF;
END $$;

-- Start clean so the file can be run again (trip_leg rows go with their trip)
DELETE FROM trip
WHERE user_id IN (SELECT user_id FROM app_user
                  WHERE email IN ('aarav.sharma@example.com', 'diya.verma@example.com'));

-- Trip 1: cheapest route to the movie hall
WITH new_trip AS (
  INSERT INTO trip (user_id, created_at)
  SELECT u.user_id, now() - INTERVAL '6 days'
  FROM app_user u
  WHERE u.email = 'aarav.sharma@example.com'
    AND pg_temp.sample_route('Sample Movie Hall', false) IS NOT NULL
  RETURNING trip_id
)
INSERT INTO trip_leg (trip_id, leg_no, edge_id)
SELECT t.trip_id, l.leg_no, l.edge_id
FROM new_trip t
CROSS JOIN LATERAL unnest(pg_temp.sample_route('Sample Movie Hall', false)) WITH ORDINALITY AS l(edge_id, leg_no)
ORDER BY l.leg_no;

-- Trip 2: fastest route to the daily needs store
WITH new_trip AS (
  INSERT INTO trip (user_id, created_at)
  SELECT u.user_id, now() - INTERVAL '2 days'
  FROM app_user u
  WHERE u.email = 'diya.verma@example.com'
    AND pg_temp.sample_route('Sample Daily Needs Store', true) IS NOT NULL
  RETURNING trip_id
)
INSERT INTO trip_leg (trip_id, leg_no, edge_id)
SELECT t.trip_id, l.leg_no, l.edge_id
FROM new_trip t
CROSS JOIN LATERAL unnest(pg_temp.sample_route('Sample Daily Needs Store', true)) WITH ORDINALITY AS l(edge_id, leg_no)
ORDER BY l.leg_no;