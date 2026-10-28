-- security/02_grants.sql
-- Purpose: GRANT and REVOKE statements for the two roles (Unit I, DCL).
-- How to run (as the database owner or a superuser), AFTER security/01_roles.sql and AFTER every table,
-- view and function exists (schema, triggers, views, trip query, data, indexing/fulltext_search.sql):
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f security/02_grants.sql
-- Re-runnable. Run it again whenever a new view or function is added (for example the trending view),
-- and again after re-running triggers/01_review_rating.sql (see section 5).
--
-- THE RULES
--   Student: read the place directory, map, reviews and favorites; write only review, favorite,
--            trip and trip_leg; may call cheapest_route and the search functions; no audit_log, no app_user.
--   Admin:   everything a student can do (inherited) plus INSERT/UPDATE/DELETE on the place directory
--            and the map, and read access to audit_log.
--
-- NO ROW-LEVEL SECURITY: we do not use it. PostgreSQL therefore cannot stop one student from editing
-- ANOTHER student's review or favorite. "Own rows only" is enforced by the application (every write must
-- carry WHERE user_id = the logged-in user). The grants below only decide which tables and columns a role may touch.

-- ---------------------------------------------------------------------------
-- 1. Start closed: take every right away from PUBLIC (everybody).
--    PUBLIC is a built-in pseudo-role that every role belongs to. Anything granted to PUBLIC reaches
--    every user, so we remove it first and then give back only what each role needs.
--    (Functions are the important case: PostgreSQL gives EXECUTE on new functions to PUBLIC by default.)
-- ---------------------------------------------------------------------------
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;         -- nobody except the owner may create objects

-- Clean slate for our two roles, so that re-running this file also removes any right that was
-- deleted from this file (revoking on a table also removes its column-level rights).
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM tripgraph_student, tripgraph_admin;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM tripgraph_student, tripgraph_admin;

-- ---------------------------------------------------------------------------
-- 2. Student
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO tripgraph_student;

-- Read access
GRANT SELECT ON place, category, tag, place_tag, opening_hours, food_outlet,
                node, edge, review, favorite, trip, trip_leg
  TO tripgraph_student;
GRANT SELECT ON top_rated_places, open_now TO tripgraph_student;

-- Write access: only their own activity tables.
-- Column-level GRANT: a student may change the rating and text of a review, and the visited flag of a
-- favorite, but not which user or place the row belongs to.
GRANT INSERT, DELETE        ON review, favorite TO tripgraph_student;
GRANT UPDATE (rating, review_text) ON review    TO tripgraph_student;
GRANT UPDATE (visited)             ON favorite  TO tripgraph_student;
GRANT INSERT, UPDATE, DELETE ON trip, trip_leg  TO tripgraph_student;

-- Functions (EXECUTE). cheapest_route reads node, edge and place and calls is_open_at,
-- so both need EXECUTE.
GRANT EXECUTE ON FUNCTION cheapest_route(INT, TIMESTAMP, NUMERIC, TIMESTAMP, TEXT, INT, INT) TO tripgraph_student;
GRANT EXECUTE ON FUNCTION is_open_at(INT, TIMESTAMP) TO tripgraph_student;

-- Objects that other files create. Granted only if they exist, so this file never fails because of
-- them. If you see a NOTICE below, create the object first and then run this file again.
DO $$
BEGIN
  IF to_regprocedure('search_places(text,integer)') IS NOT NULL THEN
    GRANT EXECUTE ON FUNCTION search_places(text, integer) TO tripgraph_student;
  ELSE
    RAISE NOTICE 'search_places() does not exist yet: run indexing/fulltext_search.sql, then run this file again';
  END IF;

  IF to_regprocedure('places_with_tags(text[])') IS NOT NULL THEN
    GRANT EXECUTE ON FUNCTION places_with_tags(text[]) TO tripgraph_student;
  ELSE
    RAISE NOTICE 'places_with_tags() does not exist yet: run indexing/fulltext_search.sql, then run this file again';
  END IF;

  -- search_places() reads this view, so the caller needs SELECT on it
  IF to_regclass('place_search') IS NOT NULL THEN
    GRANT SELECT ON place_search TO tripgraph_student;
  ELSE
    RAISE NOTICE 'view place_search does not exist yet: run indexing/fulltext_search.sql, then run this file again';
  END IF;

  IF to_regclass('trending_this_month') IS NOT NULL THEN
    GRANT SELECT ON trending_this_month TO tripgraph_student;
  ELSE
    RAISE NOTICE 'view trending_this_month does not exist yet: run it when it is added, then run this file again';
  END IF;
  IF to_regclass('cheapest_edges') IS NOT NULL THEN
    GRANT SELECT ON cheapest_edges TO tripgraph_student;
  ELSE
    RAISE NOTICE 'view cheapest_edges does not exist yet: run queries/views/cheapest_edges.sql, then run this file again';
  END IF;

  IF to_regclass('freshers_guide_cheap_eats') IS NOT NULL THEN
    GRANT SELECT ON freshers_guide_cheap_eats TO tripgraph_student;
  ELSE
    RAISE NOTICE 'view freshers_guide_cheap_eats does not exist yet: run queries/views/freshers_guide_cheap_eats.sql, then run this file again';
  END IF;

  IF to_regprocedure('similar_places(integer,integer,boolean)') IS NOT NULL THEN
    GRANT EXECUTE ON FUNCTION similar_places(integer, integer, boolean) TO tripgraph_student;
  ELSE
    RAISE NOTICE 'similar_places() does not exist yet: run queries/procedures/01_similar_places.sql, then run this file again';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Admin (also gets everything a student has, through membership in tripgraph_student)
-- ---------------------------------------------------------------------------
GRANT INSERT, UPDATE, DELETE ON category, tag, place_tag, opening_hours, food_outlet, node, edge
  TO tripgraph_admin;

-- place: an admin may add, edit and delete places, but NOT write the two rating columns.
-- avg_rating and review_count belong to the review trigger; writing them by hand would break the numbers.
GRANT DELETE ON place TO tripgraph_admin;
GRANT INSERT (name, category_id, address, lat, lon, price_level, student_discount, node_id)
  ON place TO tripgraph_admin;
GRANT UPDATE (name, category_id, address, lat, lon, price_level, student_discount, node_id)
  ON place TO tripgraph_admin;

-- WITH GRANT OPTION example: the admin may read the audit log AND hand that same right on to someone else
-- (for example a future auditor role): GRANT SELECT ON audit_log TO some_role;  (run by the admin)
GRANT SELECT ON audit_log TO tripgraph_admin WITH GRANT OPTION;

-- Optional view of trending places (see section 2): admins inherit it from the student role.

-- ---------------------------------------------------------------------------
-- 4. REVOKE reminder (used above and in security/03_test_roles.sql):
--      REVOKE ... FROM PUBLIC          closes the default doors (section 1)
--      REVOKE SELECT ON audit_log FROM tripgraph_student;   takes one right back from one role
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 5. The rating trigger must run with the TABLE OWNER's rights.
--    When a student inserts a review, the trigger updates place.avg_rating. A student has no UPDATE
--    right on place, so without this the insert would fail with "permission denied for table place".
--    SECURITY DEFINER makes the function run as the role that owns it. SET search_path pins which
--    schemas it may look in, which is the standard safety rule for SECURITY DEFINER functions.
--    NOTE: CREATE OR REPLACE FUNCTION in triggers/01_review_rating.sql resets this setting, so run this
--    file again after re-loading that trigger file.
-- ---------------------------------------------------------------------------
ALTER FUNCTION trg_review_rating() SECURITY DEFINER SET search_path = public, pg_temp;

\echo 'Grants applied.'
