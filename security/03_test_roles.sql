-- security/03_test_roles.sql
-- Purpose: proves the permissions. Each check switches to a role with SET ROLE, tries one statement and
-- records whether it was ALLOWED or DENIED, then compares that with what we expect (PASS or FAIL).
-- Everything runs inside a transaction that ends with ROLLBACK, so no data is changed.
-- How to run (as the database owner or a superuser), after security/01_roles.sql and 02_grants.sql:
--   psql -U postgres -d tripgraph -f security/03_test_roles.sql
-- Re-runnable. A check shows SKIP when the object it needs is not installed (for example the search functions).

\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE role_results (
  n        SERIAL,
  role     TEXT,
  test     TEXT,
  expected TEXT,
  actual   TEXT,
  status   TEXT
);

-- check_role(role, description, expected, statement [, verify query] [, needs])
--   expected  'allowed' or 'denied'
--   verify    optional query (run as the owner) that must return true after an allowed statement
--   needs     optional 'fn:name(argtypes)' or 'rel:name'; the check is SKIPped when that object is missing
-- Each statement is undone afterwards, so checks do not affect each other.
CREATE FUNCTION pg_temp.check_role(p_role TEXT, p_test TEXT, p_expect TEXT, p_sql TEXT,
                                   p_verify TEXT DEFAULT NULL, p_needs TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  outcome  TEXT;
  verified BOOLEAN := true;
  missing  BOOLEAN := false;
BEGIN
  IF p_needs LIKE 'fn:%' THEN
    missing := to_regprocedure(substr(p_needs, 4)) IS NULL;
  ELSIF p_needs LIKE 'rel:%' THEN
    missing := to_regclass(substr(p_needs, 5)) IS NULL;
  END IF;
  IF missing THEN
    INSERT INTO role_results(role, test, expected, actual, status)
    VALUES (p_role, p_test, p_expect, 'object not installed', 'SKIP');
    RETURN;
  END IF;

  BEGIN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql;
    RESET ROLE;
    IF p_verify IS NOT NULL THEN
      EXECUTE p_verify INTO verified;
    END IF;
    outcome := 'allowed';
    RAISE EXCEPTION 'check_role_rollback';          -- undo whatever the statement did
  EXCEPTION
    WHEN insufficient_privilege THEN
      outcome := 'denied';
    WHEN OTHERS THEN
      IF SQLERRM <> 'check_role_rollback' THEN
        outcome := 'error: ' || SQLERRM;
      END IF;
  END;

  INSERT INTO role_results(role, test, expected, actual, status)
  VALUES (p_role, p_test, p_expect, outcome,
          CASE WHEN outcome = p_expect AND COALESCE(verified, false) THEN 'PASS' ELSE 'FAIL' END);
END;
$$;

-- Test data (rolled back at the end): one user, one place, one review, one favorite
INSERT INTO app_user (user_id, name, email) VALUES (990001, 'Role Test User', 'role.test@example.com');
INSERT INTO place (place_id, name, category_id, lat, lon, price_level, node_id)
SELECT 990001, 'Role Test Place', min(category_id), 28.61, 77.03, 1, (SELECT min(node_id) FROM node) FROM category;
INSERT INTO review (user_id, place_id, rating, review_text) VALUES (990001, 990001, 3, 'role test');
INSERT INTO favorite (user_id, place_id) VALUES (990001, 990001);

\o /dev/null

-- ============================== STUDENT ==============================
-- reads
SELECT pg_temp.check_role('tripgraph_student', 'read places',          'allowed', $q$SELECT count(*) FROM place$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read categories',      'allowed', $q$SELECT count(*) FROM category$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read map edges',       'allowed', $q$SELECT count(*) FROM edge$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read reviews',         'allowed', $q$SELECT count(*) FROM review$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read top_rated_places view', 'allowed', $q$SELECT count(*) FROM top_rated_places$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read open_now view',   'allowed', $q$SELECT count(*) FROM open_now$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read trending_this_month view (if installed)', 'allowed',
  $q$SELECT count(*) FROM trending_this_month$q$, NULL, 'rel:trending_this_month');

-- functions
SELECT pg_temp.check_role('tripgraph_student', 'call cheapest_route()', 'allowed',
  $q$SELECT count(*) FROM cheapest_route(1, TIMESTAMP '2026-10-26 12:00')$q$);
SELECT pg_temp.check_role('tripgraph_student', 'call search_places()', 'allowed',
  $q$SELECT count(*) FROM search_places('cafe')$q$, NULL, 'fn:search_places(text,integer)');
SELECT pg_temp.check_role('tripgraph_student', 'call places_with_tags()', 'allowed',
  $q$SELECT count(*) FROM places_with_tags(ARRAY['veg'])$q$, NULL, 'fn:places_with_tags(text[])');

-- allowed writes (the review trigger runs as the table owner, so the rating is recomputed)
SELECT pg_temp.check_role('tripgraph_student', 'insert a review (rating trigger still updates the place)', 'allowed',
  $q$INSERT INTO review(user_id, place_id, rating, review_text)
     SELECT 990001, min(place_id), 5, 'role test' FROM place WHERE place_id <> 990001$q$,
  $q$SELECT p.avg_rating = (SELECT round(avg(r.rating), 2) FROM review r WHERE r.place_id = p.place_id)
            AND p.review_count = (SELECT count(*) FROM review r WHERE r.place_id = p.place_id)
     FROM place p WHERE p.place_id = (SELECT min(place_id) FROM place WHERE place_id <> 990001)$q$);
SELECT pg_temp.check_role('tripgraph_student', 'edit the rating of a review (place rating recomputed)', 'allowed',
  $q$UPDATE review SET rating = 5 WHERE user_id = 990001 AND place_id = 990001$q$,
  $q$SELECT avg_rating = 5.00 AND review_count = 1 FROM place WHERE place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'delete a review', 'allowed',
  $q$DELETE FROM review WHERE user_id = 990001 AND place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'add a favorite', 'allowed',
  $q$INSERT INTO favorite(user_id, place_id) SELECT 990001, min(place_id) FROM place WHERE place_id <> 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'mark a favorite as visited', 'allowed',
  $q$UPDATE favorite SET visited = true WHERE user_id = 990001 AND place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'save a trip with a leg (trip-leg trigger runs)', 'allowed',
  $q$WITH t AS (INSERT INTO trip(user_id) VALUES (990001) RETURNING trip_id)
     INSERT INTO trip_leg(trip_id, leg_no, edge_id) SELECT trip_id, 1, (SELECT min(edge_id) FROM edge) FROM t$q$);

-- denied
SELECT pg_temp.check_role('tripgraph_student', 'insert a place',  'denied',
  $q$INSERT INTO place(name, category_id, lat, lon, price_level, node_id)
     SELECT 'Student Place', min(category_id), 28.6, 77.0, 1, (SELECT min(node_id) FROM node) FROM category$q$);
SELECT pg_temp.check_role('tripgraph_student', 'update a place',  'denied',
  $q$UPDATE place SET name = 'Hacked' WHERE place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'delete a place',  'denied',
  $q$DELETE FROM place WHERE place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'insert a map edge', 'denied',
  $q$INSERT INTO edge(from_node, to_node, mode, distance_m, time_min, fare)
     SELECT min(node_id), max(node_id), 'walk', 100, 2, 0 FROM node$q$);
SELECT pg_temp.check_role('tripgraph_student', 'move a review to another place (no column right)', 'denied',
  $q$UPDATE review SET place_id = (SELECT min(place_id) FROM place WHERE place_id <> 990001)
     WHERE user_id = 990001 AND place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read audit_log', 'denied', $q$SELECT count(*) FROM audit_log$q$);
SELECT pg_temp.check_role('tripgraph_student', 'read app_user (emails are private)', 'denied', $q$SELECT count(*) FROM app_user$q$);
SELECT pg_temp.check_role('tripgraph_student', 'TRUNCATE the review table', 'denied', $q$TRUNCATE review$q$);
SELECT pg_temp.check_role('tripgraph_student', 'create a table', 'denied', $q$CREATE TABLE sneaky(x INT)$q$);

-- ============================== ADMIN ==============================
SELECT pg_temp.check_role('tripgraph_admin', 'inherits student rights: read reviews', 'allowed', $q$SELECT count(*) FROM review$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'inherits student rights: call cheapest_route()', 'allowed',
  $q$SELECT count(*) FROM cheapest_route(1, TIMESTAMP '2026-10-26 12:00')$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert a place', 'allowed',
  $q$INSERT INTO place(name, category_id, lat, lon, price_level, node_id)
     SELECT 'Admin Test Place', min(category_id), 28.6, 77.0, 1, (SELECT min(node_id) FROM node) FROM category$q$,
  $q$SELECT EXISTS (SELECT 1 FROM place WHERE name = 'Admin Test Place')$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'update a place (name)', 'allowed',
  $q$UPDATE place SET name = 'Renamed by admin' WHERE place_id = 990001$q$,
  $q$SELECT EXISTS (SELECT 1 FROM place WHERE name = 'Renamed by admin')$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'delete a place', 'allowed',
  $q$DELETE FROM place WHERE place_id = 990001$q$,
  $q$SELECT NOT EXISTS (SELECT 1 FROM place WHERE place_id = 990001)$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert a category', 'allowed',
  $q$INSERT INTO category(name, group_name) VALUES ('Role Test Category', 'Test')$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert a map node', 'allowed',
  $q$INSERT INTO node(name, kind) VALUES ('Role Test Node', 'place')$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert a map edge', 'allowed',
  $q$INSERT INTO edge(from_node, to_node, mode, distance_m, time_min, fare)
     SELECT min(node_id), max(node_id), 'walk', 100, 2, 0 FROM node$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert opening hours', 'allowed',
  $q$INSERT INTO opening_hours VALUES (990001, 1, '09:00', '18:00')$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert a tag and link it to a place', 'allowed',
  $q$WITH t AS (INSERT INTO tag(name) VALUES ('role-test-tag') RETURNING tag_id)
     INSERT INTO place_tag(place_id, tag_id) SELECT 990001, tag_id FROM t$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'insert a food_outlet row', 'allowed',
  $q$INSERT INTO food_outlet(place_id, cuisine, is_veg) VALUES (990001, 'Test', true)$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'delete a review (moderation)', 'allowed',
  $q$DELETE FROM review WHERE user_id = 990001 AND place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'read audit_log', 'allowed', $q$SELECT count(*) FROM audit_log$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'write avg_rating by hand (trigger-owned column)', 'denied',
  $q$UPDATE place SET avg_rating = 5 WHERE place_id = 990001$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'read app_user (not granted to any role)', 'denied', $q$SELECT count(*) FROM app_user$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'TRUNCATE the place table', 'denied', $q$TRUNCATE place CASCADE$q$);
SELECT pg_temp.check_role('tripgraph_admin', 'has GRANT OPTION on audit_log (can pass the right on)', 'allowed',
  $q$SELECT 1$q$, $q$SELECT has_table_privilege('tripgraph_admin', 'audit_log', 'SELECT WITH GRANT OPTION')$q$);

-- ============================== DEMO LOGIN ROLES (inherit from the groups) ==============================
SELECT pg_temp.check_role('tripgraph_demo_student', 'read places', 'allowed', $q$SELECT count(*) FROM place$q$);
SELECT pg_temp.check_role('tripgraph_demo_student', 'insert a place', 'denied',
  $q$INSERT INTO place(name, category_id, lat, lon, price_level, node_id)
     SELECT 'Demo Student Place', min(category_id), 28.6, 77.0, 1, (SELECT min(node_id) FROM node) FROM category$q$);
SELECT pg_temp.check_role('tripgraph_demo_admin', 'insert a place', 'allowed',
  $q$INSERT INTO place(name, category_id, lat, lon, price_level, node_id)
     SELECT 'Demo Admin Place', min(category_id), 28.6, 77.0, 1, (SELECT min(node_id) FROM node) FROM category$q$);

\o

-- ============================== GRANT and REVOKE, live ==============================
-- Same statement, three moments: before the GRANT, after the GRANT, after the REVOKE.
\o /dev/null
SELECT pg_temp.check_role('tripgraph_student', 'before GRANT: read audit_log', 'denied', $q$SELECT count(*) FROM audit_log$q$);
GRANT SELECT ON audit_log TO tripgraph_student;
SELECT pg_temp.check_role('tripgraph_student', 'after GRANT SELECT: read audit_log', 'allowed', $q$SELECT count(*) FROM audit_log$q$);
REVOKE SELECT ON audit_log FROM tripgraph_student;
SELECT pg_temp.check_role('tripgraph_student', 'after REVOKE SELECT: read audit_log', 'denied', $q$SELECT count(*) FROM audit_log$q$);
\o

SELECT n AS "#", role, test, expected, actual, status FROM role_results ORDER BY n;
SELECT count(*) FILTER (WHERE status = 'PASS') AS passed,
       count(*) FILTER (WHERE status = 'FAIL') AS failed,
       count(*) FILTER (WHERE status = 'SKIP') AS skipped
FROM role_results;
SELECT n AS "#", role, test, expected, actual FROM role_results WHERE status = 'FAIL' ORDER BY n;
ROLLBACK;

-- ============================================================================
-- VIVA NOTES
-- GRANT vs REVOKE:
--   GRANT gives a role a right on an object (SELECT, INSERT, UPDATE, DELETE, EXECUTE ...), optionally on
--   chosen columns only. REVOKE takes it back. Without WITH GRANT OPTION a role cannot pass a right on.
-- Role inheritance:
--   tripgraph_admin is a member of tripgraph_student, so it automatically has every student right.
--   We grant the admin only the extras. Change the student rights once and the admin follows.
-- Why REVOKE ... FROM PUBLIC first:
--   PUBLIC means "every role". PostgreSQL gives PUBLIC the right to run any new function, so anything
--   we forgot to lock would be open to everybody. Starting closed means a right exists only if a GRANT
--   in security/02_grants.sql gives it.
-- Column-level rights:
--   A student may update review.rating but not review.place_id, and an admin may not write place.avg_rating.
-- SECURITY DEFINER:
--   The rating trigger changes place, which a student may not touch directly. It runs as the table owner
--   (SECURITY DEFINER), so reviews still update the rating while direct edits stay blocked.
-- What we do NOT have: row-level security. PostgreSQL cannot stop a student from editing another
--   student's review; the application restricts each write to the logged-in user's own rows.
-- ============================================================================
