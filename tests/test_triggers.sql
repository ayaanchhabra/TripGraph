-- tests/test_triggers.sql   (K)
-- Rating trigger (triggers/01_review_rating.sql) and trip-leg trigger (triggers/02_trip_leg_continuity.sql).
-- Run from the repo root:
--   psql -U postgres -d tripgraph -f tests/test_triggers.sql
-- Everything is rolled back at the end.

\set ON_ERROR_STOP on
BEGIN;
\i tests/00_helpers.sql
\i tests/01_fixtures.sql
\o /dev/null

-- ---------- Rating trigger: avg_rating / review_count on place ----------
SELECT pg_temp.expect_eq('Rating trigger', 'new place starts at 0 stars, 0 reviews',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '0.00/0');

INSERT INTO review(user_id, place_id, rating) VALUES (900001, 900001, 5);
SELECT pg_temp.expect_eq('Rating trigger', 'one 5-star review gives 5.00 / 1',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '5.00/1');

INSERT INTO review(user_id, place_id, rating) VALUES (900002, 900001, 2);
SELECT pg_temp.expect_eq('Rating trigger', 'adding a 2-star review gives 3.50 / 2',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '3.50/2');

UPDATE review SET rating = 4 WHERE user_id = 900002 AND place_id = 900001;
SELECT pg_temp.expect_eq('Rating trigger', 'editing a review (2 to 4 stars) gives 4.50 / 2',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '4.50/2');

INSERT INTO review(user_id, place_id, rating) VALUES (900003, 900001, 3);
SELECT pg_temp.expect_eq('Rating trigger', 'third review (3 stars) gives 4.00 / 3',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '4.00/3');

DELETE FROM review WHERE user_id = 900003 AND place_id = 900001;
SELECT pg_temp.expect_eq('Rating trigger', 'deleting a review gives 4.50 / 2 again',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '4.50/2');

UPDATE review SET place_id = 900002 WHERE user_id = 900002;
SELECT pg_temp.expect_eq('Rating trigger', 'moving a review: old place updated (5.00 / 1)',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '5.00/1');
SELECT pg_temp.expect_eq('Rating trigger', 'moving a review: new place updated (4.00 / 1)',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900002$q$, '4.00/1');

DELETE FROM review WHERE place_id IN (900001, 900002);
SELECT pg_temp.expect_eq('Rating trigger', 'deleting every review resets place 1 to 0.00 / 0',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '0.00/0');
SELECT pg_temp.expect_eq('Rating trigger', 'deleting every review resets place 2 to 0.00 / 0',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900002$q$, '0.00/0');

SELECT pg_temp.expect_fail('Rating trigger', 'invalid rating is still rejected',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (900001, 900001, 9)$q$, 'ck_review_rating');
SELECT pg_temp.expect_eq('Rating trigger', 'a rejected review does not change the counts',
  $q$SELECT avg_rating || '/' || review_count FROM place WHERE place_id = 900001$q$, '0.00/0');

SELECT pg_temp.expect_ok('Rating trigger', 'deleting a place that has reviews works (cascade)',
  $q$WITH p AS (INSERT INTO place(place_id, name, category_id, lat, lon, price_level, node_id)
                SELECT 900003, 'TEST Temp', min(category_id), 28.61, 77.03, 1, 900004 FROM category RETURNING place_id),
          r AS (INSERT INTO review(user_id, place_id, rating) SELECT 900001, place_id, 3 FROM p RETURNING place_id)
     DELETE FROM place WHERE place_id = 900003$q$);

-- ---------- Trip-leg trigger: leg n must end where leg n+1 starts ----------
-- edges: 900001 Gate->Stand, 900002 Stand->Cafe, 900003 Gate->Cafe, 900004 Cafe->Gate
SELECT pg_temp.expect_ok('Trip-leg trigger', 'leg 1 can start anywhere (Gate -> Stand)',
  $q$INSERT INTO trip_leg VALUES (900001, 1, 900001)$q$);
SELECT pg_temp.expect_ok('Trip-leg trigger', 'leg 2 that starts where leg 1 ended is accepted (Stand -> Cafe)',
  $q$INSERT INTO trip_leg VALUES (900001, 2, 900002)$q$);
SELECT pg_temp.expect_fail('Trip-leg trigger', 'leg 3 that starts somewhere else is rejected (Gate -> Cafe after arriving at Cafe)',
  $q$INSERT INTO trip_leg VALUES (900001, 3, 900003)$q$, 'starts at node');
SELECT pg_temp.expect_ok('Trip-leg trigger', 'leg 3 that continues from the Cafe is accepted (Cafe -> Gate)',
  $q$INSERT INTO trip_leg VALUES (900001, 3, 900004)$q$);
SELECT pg_temp.expect_fail('Trip-leg trigger', 'skipping a leg number is rejected (leg 5 with no leg 4)',
  $q$INSERT INTO trip_leg VALUES (900001, 5, 900001)$q$, 'has no leg');
SELECT pg_temp.expect_fail('Trip-leg trigger', 'editing leg 2 so it no longer follows leg 1 is rejected',
  $q$UPDATE trip_leg SET edge_id = 900003 WHERE trip_id = 900001 AND leg_no = 2$q$, 'starts at node');
SELECT pg_temp.expect_fail('Trip-leg trigger', 'editing leg 1 so leg 2 no longer follows it is rejected',
  $q$UPDATE trip_leg SET edge_id = 900003 WHERE trip_id = 900001 AND leg_no = 1$q$, 'ends at node');
SELECT pg_temp.expect_eq('Trip-leg trigger', 'the rejected edits left the trip unchanged (3 legs)',
  $q$SELECT count(*)::text FROM trip_leg WHERE trip_id = 900001$q$, '3');

\o
SELECT n AS "#", area, test, status FROM test_results ORDER BY n;
SELECT count(*) FILTER (WHERE status = 'PASS') AS passed,
       count(*) FILTER (WHERE status = 'FAIL') AS failed
FROM test_results;
SELECT n AS "#", test, detail AS "what went wrong" FROM test_results WHERE status = 'FAIL' ORDER BY n;
ROLLBACK;
