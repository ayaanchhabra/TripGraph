-- data/sample_data/load_sample.sql
-- Purpose: loads all sample data in the right order, then prints verification queries.
-- Run from the REPO ROOT, AFTER the full load order up to data/load_all.sql
-- (schema, triggers, views, trip query, map and places). The triggers must be ENABLED.
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f data/sample_data/load_sample.sql
-- Re-runnable: nothing is duplicated.

\i data/sample_data/01_sample_users.sql
\i data/sample_data/02_sample_reviews.sql
\i data/sample_data/03_sample_favorites.sql
\i data/sample_data/04_sample_trips.sql

\echo
\echo '=== 1. Row counts (expect users 8+, reviews 45+, favorites 16+, trips 2+, legs 7+) ==='
SELECT (SELECT count(*) FROM app_user)  AS users,
       (SELECT count(*) FROM review)    AS reviews,
       (SELECT count(*) FROM favorite)  AS favorites,
       (SELECT count(*) FROM trip)      AS trips,
       (SELECT count(*) FROM trip_leg)  AS trip_legs;

\echo
\echo '=== 2. Roles (expect 2 admins) ==='
SELECT role, count(*) FROM app_user GROUP BY role ORDER BY role;

\echo
\echo '=== 3. Rating trigger check: stored avg_rating and review_count vs the real reviews (expect 0 mismatches) ==='
SELECT count(*) AS mismatched_places
FROM place p
WHERE p.review_count <> (SELECT count(*) FROM review r WHERE r.place_id = p.place_id)
   OR p.avg_rating   <> COALESCE((SELECT round(avg(r.rating), 2) FROM review r WHERE r.place_id = p.place_id), 0);

\echo
\echo '=== 4. Places with their trigger-filled rating (places with no reviews show 0.00 / 0) ==='
SELECT place_id, name, avg_rating, review_count FROM place ORDER BY place_id;

\echo
\echo '=== 5. Reviews dated in the current month (expect 10 or more) and in the last 30 days ==='
SELECT count(*) FILTER (WHERE created_at >= date_trunc('month', now())) AS this_month,
       count(*) FILTER (WHERE created_at >= now() - INTERVAL '30 days') AS last_30_days,
       min(created_at)::date AS oldest_review
FROM review;

\echo
\echo '=== 6. Places with 5 or more reviews (expect 5 or more rows) ==='
SELECT name, review_count FROM place WHERE review_count >= 5 ORDER BY review_count DESC, name;

\echo
\echo '=== 7. Sample trips, leg by leg (each leg starts where the previous one ended) ==='
SELECT t.trip_id, u.name AS student, l.leg_no, nf.name AS from_stop, nt.name AS to_stop, e.mode, e.fare
FROM trip t
JOIN app_user u  ON u.user_id = t.user_id
JOIN trip_leg l  ON l.trip_id = t.trip_id
JOIN edge e      ON e.edge_id = l.edge_id
JOIN node nf     ON nf.node_id = e.from_node
JOIN node nt     ON nt.node_id = e.to_node
ORDER BY t.trip_id, l.leg_no;

\echo
\echo '=== 8. Top rated places now return rows ==='
SELECT * FROM top_rated_places WHERE rank_in_category <= 3 ORDER BY category, rank_in_category;
