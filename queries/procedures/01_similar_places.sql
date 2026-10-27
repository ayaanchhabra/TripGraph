-- queries/procedures/01_similar_places.sql
-- "Places like this one": same category, price within one level, best match first.
-- Run after the schema, the triggers and the views (any time before the demo).
--
--   SELECT * FROM similar_places(1);                -- 5 places like place 1
--   SELECT * FROM similar_places(1, 10);            -- up to 10
--   SELECT * FROM similar_places(1, 5, true);       -- only ones with a student discount
--
-- Ranking: smaller price difference first, then higher average rating, then more reviews.
-- The target place is found with a nested subquery; the place itself is never returned.
-- A place id that does not exist returns no rows.

CREATE OR REPLACE FUNCTION similar_places(
    p_place_id         place.place_id%TYPE,
    p_limit            integer DEFAULT 5,
    p_discount_only    boolean DEFAULT false
)
RETURNS TABLE (
    place_id         place.place_id%TYPE,
    name             place.name%TYPE,
    category         category.name%TYPE,
    price_level      place.price_level%TYPE,
    price_difference integer,
    avg_rating       place.avg_rating%TYPE,
    review_count     place.review_count%TYPE,
    student_discount place.student_discount%TYPE
)
LANGUAGE sql STABLE
AS $$
    SELECT p.place_id, p.name, c.name, p.price_level,
           abs(p.price_level - t.price_level)::integer,
           p.avg_rating, p.review_count, p.student_discount
    FROM place p
    JOIN category c ON c.category_id = p.category_id
    JOIN (SELECT x.place_id, x.category_id, x.price_level
          FROM place x
          WHERE x.place_id = p_place_id) t
      ON t.category_id = p.category_id
    WHERE p.place_id <> t.place_id
      AND abs(p.price_level - t.price_level) <= 1
      AND (NOT p_discount_only OR p.student_discount)
    ORDER BY abs(p.price_level - t.price_level), p.avg_rating DESC, p.review_count DESC, p.name
    LIMIT p_limit;
$$;

-- Let the app roles call it (skipped if the security files have not been run yet).
-- The signature is looked up, so this works whatever integer type place_id has.
DO $$
DECLARE f regprocedure;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tripgraph_student') THEN
        FOR f IN SELECT oid::regprocedure FROM pg_proc
                 WHERE proname = 'similar_places' AND pronamespace = 'public'::regnamespace
        LOOP
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO tripgraph_student', f);
        END LOOP;
    END IF;
END $$;
