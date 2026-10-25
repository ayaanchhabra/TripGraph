-- data/sample_data/demo_invalid_inserts.sql
-- Purpose: viva demo. Three inserts that SHOULD FAIL. Each one runs inside BEGIN ... ROLLBACK,
-- so the database is left unchanged. Run it after load_sample.sql.
--   psql -U postgres -d tripgraph -f data/sample_data/demo_invalid_inserts.sql
-- Note: ON_ERROR_STOP is NOT set here on purpose. We want psql to show the error and carry on
-- to the next demo. Each ERROR line below is the expected, correct result.

-- Make sure the sample data is there. Without it the demo inserts would silently insert nothing.
\set ON_ERROR_STOP on
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM review r
                 JOIN app_user u ON u.user_id = r.user_id
                 JOIN place p    ON p.place_id = r.place_id
                 WHERE u.email = 'aarav.sharma@example.com' AND p.name = 'Sample Dhaba') THEN
    RAISE EXCEPTION 'Sample data not found. Run data/sample_data/load_sample.sql first (on a database loaded with the 12 places).';
  END IF;
END $$;
\set ON_ERROR_STOP off

\echo
\echo '=== Demo 1: second review by the same user for the same place ==='
\echo 'Rule: one review per user per place (primary key review_pkey). Expect: duplicate key error.'
BEGIN;
INSERT INTO review (user_id, place_id, rating, review_text)
SELECT u.user_id, p.place_id, 5, 'Trying to review the same place twice'
FROM app_user u, place p
WHERE u.email = 'aarav.sharma@example.com' AND p.name = 'Sample Dhaba';   -- Aarav already reviewed it
ROLLBACK;

\echo
\echo '=== Demo 2: rating of 6 ==='
\echo 'Rule: rating must be 1 to 5 (CHECK constraint ck_review_rating). Expect: check constraint error.'
BEGIN;
INSERT INTO review (user_id, place_id, rating, review_text)
SELECT u.user_id, p.place_id, 6, 'Six stars!'
FROM app_user u, place p
WHERE u.email = 'sana.khan@example.com' AND p.name = 'Sample Dhaba';      -- a new pair, so only the rating is wrong
ROLLBACK;

\echo
\echo '=== Demo 3: trip whose second leg does not start where the first leg ended ==='
\echo 'Rule: leg n+1 must start where leg n ended (trigger trip_leg_continuity). Expect: error from the trigger.'
BEGIN;
WITH new_trip AS (
  INSERT INTO trip (user_id)
  SELECT user_id FROM app_user WHERE email = 'rohan.gupta@example.com'
  RETURNING trip_id
),
gate_edges AS (            -- two different edges that both LEAVE the gate
  SELECT e.edge_id, row_number() OVER (ORDER BY e.edge_id) AS rn
  FROM edge e
  JOIN node n ON n.node_id = e.from_node
  WHERE n.name = 'NSUT Main Gate'
)
INSERT INTO trip_leg (trip_id, leg_no, edge_id)
SELECT t.trip_id, g.rn, g.edge_id      -- leg 2 starts at the gate, but leg 1 ended somewhere else
FROM new_trip t, gate_edges g
WHERE g.rn <= 2
ORDER BY g.rn;
ROLLBACK;

\echo
\echo '=== Check: nothing was saved (expect 2 trips, the sample ones) ==='
SELECT count(*) AS trips FROM trip;