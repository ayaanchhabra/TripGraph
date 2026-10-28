-- user_features/favorites.sql
-- Purpose: the seven favorites and visited-history queries, written with psql variables so each one can be
-- reused with any user and place. The queries run in this order:
--   1. Save a place as a favorite           (INSERT ... ON CONFLICT DO NOTHING)
--   2. Mark a favorite as visited           (UPDATE)
--   3. List a user's favorites              (with place name, category and average rating)
--   4. List the places a user has visited   (visited only)
--   5. Most-favorited places overall        (GROUP BY and count)
--   6. A user's favorites that are open right now (uses is_open_at)
--   7. Remove a favorite                    (DELETE; it runs last so this file leaves the data as it found it)
-- How to run (needs the favorite table, the sample data and queries/views/02_open_now.sql for is_open_at):
--   psql -d tripgraph -v ON_ERROR_STOP=1 -f user_features/favorites.sql
-- Use other values by passing them on the command line (it must be a user and a place that exist, and a
-- place the user has NOT saved yet, because query 7 removes it at the end):
--   psql -d tripgraph -v ON_ERROR_STOP=1 -v user_id=2 -v place_id=11 -f user_features/favorites.sql
-- Re-runnable: saving the same place twice does nothing, and the last query removes what the first one added.
--
-- OWN ROWS ONLY: the database has no row-level security, so PostgreSQL cannot stop one student from
-- changing another student's favorites. That rule is enforced by the application: it must always
-- pass the id of the LOGGED-IN user as :user_id (in Python: user_id = %s). Every query below filters on it.
-- These queries need only the rights the student role already has (see security/02_grants.sql).

-- Default values, used when none were passed with -v. Sample user 1 has not saved place 10 yet.
\if :{?user_id}
\else
  \set user_id 1
\endif
\if :{?place_id}
\else
  \set place_id 10
\endif

\echo
\echo '=== 1. Save a place as a favorite (saving it twice does nothing) ==='
INSERT INTO favorite (user_id, place_id)
VALUES (:user_id, :place_id)
ON CONFLICT (user_id, place_id) DO NOTHING;
-- visited starts as false and saved_at as now(), both from the column defaults.

\echo
\echo '=== 2. Mark the favorite as visited ==='
UPDATE favorite
SET visited = true
WHERE user_id = :user_id
  AND place_id = :place_id;

\echo
\echo '=== 3. List the user favorites: place name, category, average rating (newest first) ==='
SELECT p.place_id,
       p.name,
       c.name AS category,
       p.avg_rating,
       p.review_count,
       f.visited,
       f.saved_at::date AS saved_on
FROM favorite f
JOIN place p    ON p.place_id    = f.place_id
JOIN category c ON c.category_id = p.category_id
WHERE f.user_id = :user_id
ORDER BY f.saved_at DESC, p.name;

\echo
\echo '=== 4. Visited places only ==='
SELECT p.place_id,
       p.name,
       c.name AS category,
       p.avg_rating,
       f.saved_at::date AS saved_on
FROM favorite f
JOIN place p    ON p.place_id    = f.place_id
JOIN category c ON c.category_id = p.category_id
WHERE f.user_id = :user_id
  AND f.visited
ORDER BY p.name;

\echo
\echo '=== 5. Most-favorited places overall (top 5; ties are broken by name) ==='
SELECT p.place_id,
       p.name,
       c.name AS category,
       count(*)                          AS times_saved,
       count(*) FILTER (WHERE f.visited) AS times_visited,
       p.avg_rating
FROM favorite f
JOIN place p    ON p.place_id    = f.place_id
JOIN category c ON c.category_id = p.category_id
GROUP BY p.place_id, p.name, c.name, p.avg_rating
ORDER BY times_saved DESC, p.name
LIMIT 5;

\echo
\echo '=== 6. The user favorites that are open right now (Indian time) ==='
-- is_open_at(place, time) comes from queries/views/02_open_now.sql. A place with no opening hours counts as closed.
SELECT p.place_id,
       p.name,
       c.name AS category,
       p.avg_rating
FROM favorite f
JOIN place p    ON p.place_id    = f.place_id
JOIN category c ON c.category_id = p.category_id
WHERE f.user_id = :user_id
  AND is_open_at(p.place_id, now() AT TIME ZONE 'Asia/Kolkata')
ORDER BY p.name;

\echo
\echo '=== 7. Remove the favorite (undoes query 1) ==='
DELETE FROM favorite
WHERE user_id = :user_id
  AND place_id = :place_id;
