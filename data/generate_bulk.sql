-- data/generate_bulk.sql   (A)   PHASE 3: bulk data for indexing benchmarks
--
-- Builds a SEPARATE schema called "bench" with generated copies of the tables.
-- Your real demo data in the public schema is never touched.
--
-- Run from the repo root, AFTER the schema, seed (category) and map are loaded:
--   psql -U postgres -d tripgraph -f data/generate_bulk.sql
-- Different sizes (defaults: 100000 places, 5000 users, 300000 reviews):
--   psql -U postgres -d tripgraph -v n_places=200000 -v n_reviews=600000 -f data/generate_bulk.sql
--
-- RE-RUNNABLE: it drops and rebuilds the bench schema each time.
--
-- Why a separate schema instead of loading into public.place?
--   1. The avg_rating trigger (K) would fire once per generated review and make the load very slow.
--      bench tables are plain copies with NO triggers and NO foreign keys, so the load is fast.
--      avg_rating / review_count are computed once at the end with one UPDATE (same values the trigger would give).
--   2. The viva demo (routes, top-rated lists) stays small and readable.
--   3. bench tables start with NO indexes and NO primary keys, which is exactly the
--      "no index" baseline Phase 4 needs. create_indexes.sql adds them.
--
-- The data is GENERATED, not real. Names are random word combinations.

\set ON_ERROR_STOP on
\timing on

\if :{?n_places}
\else
  \set n_places 100000
\endif
\if :{?n_users}
\else
  \set n_users 5000
\endif
\if :{?n_reviews}
\else
  \set n_reviews 300000
\endif

-- 0. Preconditions
DO $$
BEGIN
  IF (SELECT count(*) FROM public.category) = 0 THEN
    RAISE EXCEPTION 'public.category is empty: load schema/03_seed_reference.sql first';
  END IF;
  IF (SELECT count(*) FROM public.node WHERE kind = 'place') = 0 THEN
    RAISE EXCEPTION 'No place-kind nodes in public.node: load data/map/load_map.sql first';
  END IF;
END $$;

-- 1. Fresh bench schema; copies keep column names, types, defaults, NOT NULL and CHECK rules
--    but NOT primary keys, foreign keys, indexes or triggers.
DROP SCHEMA IF EXISTS bench CASCADE;
CREATE SCHEMA bench;

CREATE TABLE bench.app_user     (LIKE public.app_user     INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
CREATE TABLE bench.place        (LIKE public.place        INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
CREATE TABLE bench.food_outlet  (LIKE public.food_outlet  INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
CREATE TABLE bench.tag          (LIKE public.tag          INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
CREATE TABLE bench.place_tag    (LIKE public.place_tag    INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
CREATE TABLE bench.review       (LIKE public.review       INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);

-- 2. Helpers (temporary, vanish when the session ends)
-- pick(array, r): choose an element using a random number r in [0,1)
CREATE FUNCTION pg_temp.pick(text[], float8) RETURNS text
  LANGUAGE sql IMMUTABLE AS $$ SELECT $1[1 + floor($2 * cardinality($1))::int] $$;

-- real categories and real place-kind map nodes, numbered 1..N so we can pick by number
CREATE TEMP TABLE _cat AS
  SELECT category_id, group_name, row_number() OVER (ORDER BY category_id) AS rn
  FROM public.category;
CREATE TEMP TABLE _node AS
  SELECT node_id, row_number() OVER (ORDER BY node_id) AS rn
  FROM public.node WHERE kind = 'place';

SELECT count(*) AS n_cat  FROM _cat  \gset
SELECT count(*) AS n_node FROM _node \gset

-- 3. Users
INSERT INTO bench.app_user (user_id, name, email, role, created_at)
SELECT i, 'Bench User ' || i, 'bench_user_' || i || '@example.com', 'student',
       now() - random() * interval '365 days'
FROM generate_series(1, :n_users) AS i;

-- 4. Places
--    category: skewed (some categories are much bigger than others)
--    price_level: ~50% level 1, ~35% level 2, ~15% level 3
--    student_discount: ~25% true
--    coordinates: random point inside the Dwarka box used by validate_places.sql
--    node_id: a real place-kind node from the hand-built map
INSERT INTO bench.place (place_id, name, category_id, address, lat, lon,
                         price_level, student_discount, node_id)
WITH g AS MATERIALIZED (
  SELECT i AS place_id,
         1 + least(:n_cat - 1, floor(:n_cat * power(random(), 1.6))::int) AS cat_rn,
         1 + floor(random() * :n_node)::int AS node_rn,
         random() AS r_price, random() AS r_disc,
         random() AS r_lat,   random() AS r_lon,
         random() AS r_w1,    random() AS r_w2,
         random() AS r_shop,  random() AS r_sector
  FROM generate_series(1, :n_places) AS i
)
SELECT g.place_id,
       pg_temp.pick(ARRAY['Sharma','Gupta','Delhi','Royal','Punjabi','Student','Sunrise','Metro',
                          'Dwarka','Fresh','Happy','City','Golden','Annapurna','Balaji','Shiv',
                          'Lucky','New','Modern','Classic'], g.r_w1)
         || ' ' ||
         CASE WHEN c.group_name = 'Food and drink'
              THEN pg_temp.pick(ARRAY['Chai Point','Cafe','Dhaba','Bakery','Juice Corner',
                                      'Chaat Corner','Tiffin Service','Kitchen'], g.r_w2)
              ELSE pg_temp.pick(ARRAY['Store','Shop','Centre','Point','Hub','Mart'], g.r_w2)
         END
         || ' ' || g.place_id,
       c.category_id,
       'Shop ' || (1 + floor(g.r_shop * 200)::int) || ', Sector ' || (1 + floor(g.r_sector * 23)::int) || ', Dwarka',
       round((28.58 + g.r_lat * 0.06)::numeric, 5),
       round((77.00 + g.r_lon * 0.08)::numeric, 5),
       CASE WHEN g.r_price < 0.50 THEN 1 WHEN g.r_price < 0.85 THEN 2 ELSE 3 END,
       g.r_disc < 0.25,
       n.node_id
FROM g
JOIN _cat  c ON c.rn = g.cat_rn
JOIN _node n ON n.rn = g.node_rn;

-- 5. food_outlet rows for Food and drink places
INSERT INTO bench.food_outlet (place_id, cuisine, is_veg)
SELECT p.place_id,
       pg_temp.pick(ARRAY['North Indian','South Indian','Chinese','Street Food','Continental',
                          'Mughlai','Bakery','Beverages'], random()),
       random() < 0.5
FROM bench.place p
JOIN public.category c ON c.category_id = p.category_id
WHERE c.group_name = 'Food and drink';

-- 6. Tags (a fixed vocabulary) and 1 to 4 tags per place
INSERT INTO bench.tag (tag_id, name)
SELECT row_number() OVER (), t
FROM unnest(ARRAY['veg','non-veg','chai','cheap','wifi','late-night','coffee','chaat','printing',
                  'photocopy','second-hand','medicine','hangout','movies','essentials','ac','delivery',
                  'student-friendly','family','quiet','open-24x7','takeaway','home-style','spicy',
                  'sweet','snacks','organic','budget','premium','parking','outdoor']) AS t;

SELECT count(*) AS n_tag FROM bench.tag \gset

INSERT INTO bench.place_tag (place_id, tag_id)
SELECT p.place_id, 1 + ((p.place_id::bigint * 37 + k) % :n_tag)::int
FROM bench.place p
CROSS JOIN generate_series(0, 3) AS k
WHERE k <= p.place_id % 4;          -- 1 to 4 consecutive tag ids, so never a duplicate pair

-- 7. Reviews
--    place: skewed, so a few places get many reviews and most get few (like real life)
--    rating: each place has a hidden quality, so average ratings spread out (not all 3.0)
--    DISTINCT ON removes accidental duplicate (user, place) pairs, so the count lands a little under n_reviews
INSERT INTO bench.review (user_id, place_id, rating, review_text, created_at)
WITH r AS MATERIALIZED (
  SELECT 1 + floor(random() * :n_users)::int                                   AS user_id,
         1 + least(:n_places - 1, floor(:n_places * power(random(), 2))::int)  AS place_id,
         random() AS r_noise, random() AS r_text, random() AS r_time
  FROM generate_series(1, :n_reviews)
),
q AS (
  SELECT user_id, place_id,
         greatest(1, least(5, round(2.5 + ((place_id::bigint * 7919) % 1000) / 1000.0 * 2.5
                                    + (r_noise - 0.5) * 2.5)))::int AS rating,
         pg_temp.pick(ARRAY['Good value for students','Nice place','Average','Too crowded','Loved it',
                            'Staff was helpful','Overpriced','Will visit again'], r_text) AS review_text,
         now() - r_time * interval '365 days' AS created_at
  FROM r
)
SELECT DISTINCT ON (user_id, place_id) user_id, place_id, rating, review_text, created_at
FROM q
ORDER BY user_id, place_id;

-- 8. avg_rating / review_count in ONE statement (what the trigger would have computed review by review)
UPDATE bench.place p
SET avg_rating = a.avg_r, review_count = a.cnt
FROM (SELECT place_id, round(avg(rating)::numeric, 2) AS avg_r, count(*)::int AS cnt
      FROM bench.review GROUP BY place_id) a
WHERE a.place_id = p.place_id;

-- 9. Fresh planner statistics (needed so EXPLAIN ANALYZE results are meaningful)
ANALYZE bench.app_user;
ANALYZE bench.place;
ANALYZE bench.food_outlet;
ANALYZE bench.tag;
ANALYZE bench.place_tag;
ANALYZE bench.review;

\echo 'Done. Row counts:'
SELECT (SELECT count(*) FROM bench.place)        AS places,
       (SELECT count(*) FROM bench.food_outlet)  AS food_outlets,
       (SELECT count(*) FROM bench.app_user)     AS users,
       (SELECT count(*) FROM bench.place_tag)    AS place_tags,
       (SELECT count(*) FROM bench.review)       AS reviews;
\echo 'Next: psql -U postgres -d tripgraph -f data/bench_checks.sql'
