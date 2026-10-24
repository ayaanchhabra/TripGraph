-- tests/test_constraints.sql   (K)
-- Valid and invalid data against the schema rules (CHECK, UNIQUE, FOREIGN KEY, cascades).
-- Run from the repo root (needs schema/*.sql and triggers/*.sql loaded):
--   psql -U postgres -d tripgraph -f tests/test_constraints.sql
-- Safe to run on a database with real data: everything is rolled back.

\set ON_ERROR_STOP on
BEGIN;
\i tests/00_helpers.sql
\i tests/01_fixtures.sql
\o /dev/null

-- ---------- Reviews ----------
SELECT pg_temp.expect_ok  ('Reviews', 'valid review is accepted',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (900001, 900001, 4)$q$);
SELECT pg_temp.expect_fail('Reviews', 'second review by same user for same place is rejected',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (900001, 900001, 5)$q$, 'review_pkey');
SELECT pg_temp.expect_fail('Reviews', 'rating 0 is rejected',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (900002, 900001, 0)$q$, 'ck_review_rating');
SELECT pg_temp.expect_fail('Reviews', 'rating 6 is rejected',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (900002, 900001, 6)$q$, 'ck_review_rating');
SELECT pg_temp.expect_fail('Reviews', 'review for a place that does not exist is rejected',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (900002, 999999999, 4)$q$, 'fk_review_place');
SELECT pg_temp.expect_fail('Reviews', 'review by a user that does not exist is rejected',
  $q$INSERT INTO review(user_id, place_id, rating) VALUES (999999999, 900001, 4)$q$, 'fk_review_user');

-- ---------- Places ----------
SELECT pg_temp.expect_fail('Places', 'price_level 0 is rejected',
  $q$UPDATE place SET price_level = 0 WHERE place_id = 900001$q$, 'ck_place_price');
SELECT pg_temp.expect_fail('Places', 'price_level 4 is rejected',
  $q$UPDATE place SET price_level = 4 WHERE place_id = 900001$q$, 'ck_place_price');
SELECT pg_temp.expect_fail('Places', 'place with a category that does not exist is rejected',
  $q$UPDATE place SET category_id = -1 WHERE place_id = 900001$q$, 'fk_place_category');
SELECT pg_temp.expect_fail('Places', 'place with a map node that does not exist is rejected',
  $q$UPDATE place SET node_id = -1 WHERE place_id = 900001$q$, 'fk_place_node');
SELECT pg_temp.expect_fail('Places', 'avg_rating above 5 is rejected',
  $q$UPDATE place SET avg_rating = 6 WHERE place_id = 900001$q$, 'ck_place_rating');
SELECT pg_temp.expect_fail('Places', 'negative review_count is rejected',
  $q$UPDATE place SET review_count = -1 WHERE place_id = 900001$q$, 'ck_place_count');
SELECT pg_temp.expect_fail('Places', 'a map node that a place uses cannot be deleted',
  $q$DELETE FROM node WHERE node_id = 900004$q$, 'fk_place_node');

-- deleting a place removes its hours and tag links too (ON DELETE CASCADE)
SELECT pg_temp.expect_ok('Places', 'extra place can be inserted',
  $q$INSERT INTO place(place_id, name, category_id, lat, lon, price_level, node_id)
     SELECT 900003, 'TEST Temp', min(category_id), 28.61, 77.03, 1, 900004 FROM category$q$);
SELECT pg_temp.expect_ok('Places', 'hours for the extra place can be inserted',
  $q$INSERT INTO opening_hours VALUES (900003, 1, '09:00', '18:00')$q$);
SELECT pg_temp.expect_ok('Places', 'tag link for the extra place can be inserted',
  $q$INSERT INTO place_tag VALUES (900003, 900001)$q$);
SELECT pg_temp.expect_ok('Places', 'place can be deleted',
  $q$DELETE FROM place WHERE place_id = 900003$q$);
SELECT pg_temp.expect_eq('Places', 'deleting a place also removes its hours and tag links',
  $q$SELECT ((SELECT count(*) FROM opening_hours WHERE place_id = 900003)
           + (SELECT count(*) FROM place_tag     WHERE place_id = 900003))::text$q$, '0');

-- ---------- Map ----------
SELECT pg_temp.expect_fail('Map', 'negative fare is rejected',
  $q$INSERT INTO edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES (900010, 900001, 900004, 'walk', 10, 1, -5)$q$, 'ck_edge_fare');
SELECT pg_temp.expect_fail('Map', 'zero distance is rejected',
  $q$INSERT INTO edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES (900010, 900001, 900004, 'walk', 0, 1, 0)$q$, 'ck_edge_distance');
SELECT pg_temp.expect_fail('Map', 'edge from a node to itself is rejected',
  $q$INSERT INTO edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES (900010, 900001, 900001, 'walk', 10, 1, 0)$q$, 'ck_edge_no_loop');
SELECT pg_temp.expect_fail('Map', 'unknown transport mode is rejected',
  $q$INSERT INTO edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES (900010, 900001, 900004, 'teleport', 10, 1, 0)$q$, 'ck_edge_mode');
SELECT pg_temp.expect_fail('Map', 'edge to a node that does not exist is rejected',
  $q$INSERT INTO edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES (900010, 900001, 999999999, 'walk', 10, 1, 0)$q$, 'fk_edge_to');
SELECT pg_temp.expect_fail('Map', 'two nodes with the same name are rejected',
  $q$INSERT INTO node(node_id, name, kind) VALUES (900010, 'TEST Gate', 'gate')$q$, 'uq_node_name');
SELECT pg_temp.expect_ok('Map', 'valid edge is accepted',
  $q$INSERT INTO edge(edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES (900010, 900001, 900004, 'auto', 900, 6, 25)$q$);

-- ---------- Opening hours ----------
SELECT pg_temp.expect_fail('Opening hours', 'day 8 is rejected',
  $q$INSERT INTO opening_hours VALUES (900001, 8, '09:00', '18:00')$q$, 'ck_hours_day');
SELECT pg_temp.expect_fail('Opening hours', 'day 0 is rejected',
  $q$INSERT INTO opening_hours VALUES (900001, 0, '09:00', '18:00')$q$, 'ck_hours_day');
SELECT pg_temp.expect_fail('Opening hours', 'two rows for the same place and day are rejected',
  $q$INSERT INTO opening_hours VALUES (900001, 1, '10:00', '20:00')$q$, 'opening_hours_pkey');
SELECT pg_temp.expect_ok('Opening hours', 'closing after midnight (20:00 to 03:00) is accepted',
  $q$UPDATE opening_hours SET open_time = '20:00', close_time = '03:00' WHERE place_id = 900002 AND day = 1$q$);

-- ---------- Users and reference data ----------
SELECT pg_temp.expect_fail('Users', 'duplicate email is rejected',
  $q$INSERT INTO app_user(user_id, name, email) VALUES (900010, 'Copy', 't1@tripgraph.test')$q$, 'uq_user_email');
SELECT pg_temp.expect_fail('Users', 'unknown role is rejected',
  $q$INSERT INTO app_user(user_id, name, email, role) VALUES (900011, 'Boss', 'boss@tripgraph.test', 'superuser')$q$, 'ck_user_role');
SELECT pg_temp.expect_fail('Reference data', 'duplicate category name is rejected',
  $q$INSERT INTO category(category_id, name, group_name) SELECT 900010, name, 'x' FROM category LIMIT 1$q$, 'uq_category_name');
SELECT pg_temp.expect_fail('Reference data', 'duplicate tag name is rejected',
  $q$INSERT INTO tag(tag_id, name) VALUES (900010, 'test-tag')$q$, 'uq_tag_name');

-- ---------- Trips ----------
SELECT pg_temp.expect_fail('Trips', 'trip for a user that does not exist is rejected',
  $q$INSERT INTO trip(trip_id, user_id) VALUES (900010, 999999999)$q$, 'fk_trip_user');
SELECT pg_temp.expect_fail('Trips', 'leg number 0 is rejected',
  $q$INSERT INTO trip_leg VALUES (900001, 0, 900001)$q$, 'ck_leg_no');
SELECT pg_temp.expect_fail('Trips', 'leg that uses an edge that does not exist is rejected',
  $q$INSERT INTO trip_leg VALUES (900001, 1, 999999999)$q$, 'fk_leg_edge');

\o
SELECT n AS "#", area, test, status FROM test_results ORDER BY n;
SELECT count(*) FILTER (WHERE status = 'PASS') AS passed,
       count(*) FILTER (WHERE status = 'FAIL') AS failed
FROM test_results;
SELECT n AS "#", test, detail AS "what went wrong" FROM test_results WHERE status = 'FAIL' ORDER BY n;
ROLLBACK;
