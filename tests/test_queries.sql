-- tests/test_queries.sql
-- Views (top_rated_places, open_now), is_open_at() and cheapest_route().
-- Run from the repo root (needs schema, triggers, queries/views and queries/trips loaded):
--   psql -U postgres -d tripgraph -f tests/test_queries.sql
-- Everything is rolled back at the end. 2026-10-23 is a Friday.

\set ON_ERROR_STOP on
BEGIN;
\i tests/00_helpers.sql
\i tests/01_fixtures.sql
\o /dev/null

-- ---------- is_open_at ----------
-- TEST Cafe: 09:00-22:00.  TEST Night Cafe: 18:00-02:00 (closes after midnight).
SELECT pg_temp.expect_eq('is_open_at', 'open at 10:00',
  $q$SELECT is_open_at(900001, TIMESTAMP '2026-10-23 10:00')::text$q$, 'true');
SELECT pg_temp.expect_eq('is_open_at', 'open exactly at opening time 09:00',
  $q$SELECT is_open_at(900001, TIMESTAMP '2026-10-23 09:00')::text$q$, 'true');
SELECT pg_temp.expect_eq('is_open_at', 'closed one minute before opening',
  $q$SELECT is_open_at(900001, TIMESTAMP '2026-10-23 08:59')::text$q$, 'false');
SELECT pg_temp.expect_eq('is_open_at', 'open one minute before closing',
  $q$SELECT is_open_at(900001, TIMESTAMP '2026-10-23 21:59')::text$q$, 'true');
SELECT pg_temp.expect_eq('is_open_at', 'closed exactly at closing time 22:00',
  $q$SELECT is_open_at(900001, TIMESTAMP '2026-10-23 22:00')::text$q$, 'false');
SELECT pg_temp.expect_eq('is_open_at', 'after-midnight shop: open at 19:00',
  $q$SELECT is_open_at(900002, TIMESTAMP '2026-10-23 19:00')::text$q$, 'true');
SELECT pg_temp.expect_eq('is_open_at', 'after-midnight shop: closed at 17:59',
  $q$SELECT is_open_at(900002, TIMESTAMP '2026-10-23 17:59')::text$q$, 'false');
SELECT pg_temp.expect_eq('is_open_at', 'after-midnight shop: still open at 01:59 the next morning',
  $q$SELECT is_open_at(900002, TIMESTAMP '2026-10-23 01:59')::text$q$, 'true');
SELECT pg_temp.expect_eq('is_open_at', 'after-midnight shop: closed at 02:00',
  $q$SELECT is_open_at(900002, TIMESTAMP '2026-10-23 02:00')::text$q$, 'false');
SELECT pg_temp.expect_eq('is_open_at', 'after-midnight shop: closed at 03:00',
  $q$SELECT is_open_at(900002, TIMESTAMP '2026-10-23 03:00')::text$q$, 'false');
SELECT pg_temp.expect_eq('is_open_at', 'a place that does not exist counts as closed',
  $q$SELECT is_open_at(999999999, TIMESTAMP '2026-10-23 12:00')::text$q$, 'false');

-- ---------- open_now view ----------
SELECT pg_temp.expect_eq('open_now view', 'view agrees with is_open_at for the current Indian time',
  $q$SELECT ((SELECT count(*) FROM open_now WHERE place_id = 900001)
            = is_open_at(900001, now() AT TIME ZONE 'Asia/Kolkata')::int)::text$q$, 'true');

-- ---------- top_rated_places view ----------
SELECT pg_temp.expect_eq('top_rated_places view', 'places with no reviews are not listed',
  $q$SELECT count(*)::text FROM top_rated_places WHERE place_id IN (900001, 900002)$q$, '0');

INSERT INTO review(user_id, place_id, rating) VALUES (900001, 900001, 5), (900002, 900001, 4), (900001, 900002, 3);

SELECT pg_temp.expect_eq('top_rated_places view', 'places with reviews are listed',
  $q$SELECT count(*)::text FROM top_rated_places WHERE place_id IN (900001, 900002)$q$, '2');
SELECT pg_temp.expect_eq('top_rated_places view', 'shows the average rating and review count (4.50 / 2)',
  $q$SELECT avg_rating || '/' || review_count FROM top_rated_places WHERE place_id = 900001$q$, '4.50/2');
SELECT pg_temp.expect_eq('top_rated_places view', 'higher-rated place ranks above lower-rated place in the same category',
  $q$SELECT ((SELECT rank_in_category FROM top_rated_places WHERE place_id = 900001)
           < (SELECT rank_in_category FROM top_rated_places WHERE place_id = 900002))::text$q$, 'true');

-- ---------- cheapest_route ----------
-- All routes start at TEST Gate (p_from_node) and go to TEST Cafe (place 900001).
--   free walk: 20 min, Rs 0      |      walk + e-rickshaw: 10 min, Rs 10
-- The map has cycles (return edges), so these also prove the search terminates.
SELECT pg_temp.expect_eq('cheapest_route', 'cheapest = free walk (1 leg, Rs 0, 20 min)',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 12:00', p_from_node => 900001)$q$, '1 legs, fare 0, 20 min');
SELECT pg_temp.expect_eq('cheapest_route', 'fastest = walk + e-rickshaw (2 legs, Rs 10, 10 min)',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 12:00', p_optimize => 'time', p_from_node => 900001)$q$, '2 legs, fare 10, 10 min');
SELECT pg_temp.expect_eq('cheapest_route', 'fare budget of Rs 5 rules out the e-rickshaw even when fastest is wanted',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 12:00', p_max_fare => 5, p_optimize => 'time', p_from_node => 900001)$q$, '1 legs, fare 0, 20 min');
SELECT pg_temp.expect_eq('cheapest_route', 'deadline of 12:15 rules out the 20-minute walk',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 12:00', p_arrive_by => TIMESTAMP '2026-10-23 12:15', p_from_node => 900001)$q$, '2 legs, fare 10, 10 min');
SELECT pg_temp.expect_eq('cheapest_route', 'leaving 21:45: free walk arrives 22:05 (closed), so the faster route is chosen',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 21:45', p_from_node => 900001)$q$, '2 legs, fare 10, 10 min');
SELECT pg_temp.expect_eq('cheapest_route', 'leaving 21:55: every route arrives after closing, so no route',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 21:55', p_from_node => 900001)$q$, '0 legs, fare -, - min');
SELECT pg_temp.expect_eq('cheapest_route', 'limit of 1 leg allows only the direct walk',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900001, TIMESTAMP '2026-10-23 12:00', p_optimize => 'time', p_max_legs => 1, p_from_node => 900001)$q$, '1 legs, fare 0, 20 min');
SELECT pg_temp.expect_eq('cheapest_route', 'a place on a node nothing connects to gives no route',
  $q$SELECT count(*) || ' legs, fare ' || COALESCE(max(total_fare)::int::text, '-') || ', ' || COALESCE(max(total_time)::text, '-') || ' min'
     FROM cheapest_route(900002, TIMESTAMP '2026-10-23 19:00', p_from_node => 900001)$q$, '0 legs, fare -, - min');
SELECT pg_temp.expect_eq('cheapest_route', 'legs come back in order with running totals (leg 2 total fare = 10)',
  $q$SELECT total_fare::int::text FROM cheapest_route(900001, TIMESTAMP '2026-10-23 12:00', p_optimize => 'time', p_from_node => 900001) WHERE leg_no = 2$q$, '10');

\o
SELECT n AS "#", area, test, status FROM test_results ORDER BY n;
SELECT count(*) FILTER (WHERE status = 'PASS') AS passed,
       count(*) FILTER (WHERE status = 'FAIL') AS failed
FROM test_results;
SELECT n AS "#", test, detail AS "what went wrong" FROM test_results WHERE status = 'FAIL' ORDER BY n;
ROLLBACK;
