-- data/load_places.sql
-- Loads places, food outlets, tags and opening hours from the place CSV files.
-- Run from the REPO ROOT, AFTER schema/*.sql and data/map/load_map.sql:
--   psql -U postgres -d tripgraph -f data/load_places.sql
--
-- To test before the final place CSV files arrive, point the paths below at data/csv_examples/.
--
-- Why staging tables: the place CSV files use readable names (category_name, node_name,
-- tag_name). This script turns them into category_id / node_id / tag_id, and
-- stops with a clear message if a name does not match. All-or-nothing: one bad
-- row rolls back everything.

\set ON_ERROR_STOP on
BEGIN;

-- 1. Staging tables (vanish at COMMIT)
CREATE TEMP TABLE stg_place (
  place_id         int,
  name             text,
  category_name    text,
  address          text,
  lat              numeric,
  lon              numeric,
  price_level      int,
  student_discount boolean,
  node_name        text,
  cuisine          text,
  is_veg           boolean
) ON COMMIT DROP;

CREATE TEMP TABLE stg_place_tag (
  place_id int,
  tag_name text
) ON COMMIT DROP;

\copy stg_place     FROM 'data/csv/places.csv'      WITH (FORMAT csv, HEADER true)
\copy stg_place_tag FROM 'data/csv/place_tags.csv'   WITH (FORMAT csv, HEADER true)

-- 2. Fail early with readable messages
DO $$
DECLARE bad text;
BEGIN
  SELECT string_agg(DISTINCT s.category_name, ' | ') INTO bad
  FROM stg_place s LEFT JOIN category c ON c.name = s.category_name
  WHERE c.category_id IS NULL;
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'places.csv: category_name not found in category table: %', bad;
  END IF;

  SELECT string_agg(DISTINCT s.node_name, ' | ') INTO bad
  FROM stg_place s LEFT JOIN node n ON n.name = s.node_name
  WHERE n.node_id IS NULL;
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'places.csv: node_name not found in node table: %', bad;
  END IF;

  SELECT string_agg(place_id::text, ', ') INTO bad
  FROM (SELECT place_id FROM stg_place GROUP BY place_id HAVING count(*) > 1) d;
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'places.csv: duplicate place_id: %', bad;
  END IF;

  SELECT string_agg(DISTINCT t.place_id::text, ', ') INTO bad
  FROM stg_place_tag t LEFT JOIN stg_place s ON s.place_id = t.place_id
  WHERE s.place_id IS NULL;
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'place_tags.csv: place_id not present in places.csv: %', bad;
  END IF;
END $$;

-- 3. place (avg_rating / review_count are left to their defaults; the trigger fills them later)
INSERT INTO place (place_id, name, category_id, address, lat, lon,
                   price_level, student_discount, node_id)
SELECT s.place_id, s.name, c.category_id, s.address, s.lat, s.lon,
       s.price_level, COALESCE(s.student_discount, false), n.node_id
FROM stg_place s
JOIN category c ON c.name = s.category_name
JOIN node n     ON n.name = s.node_name
ORDER BY s.place_id;

-- 4. food_outlet (specialization): only rows where is_veg is filled in
INSERT INTO food_outlet (place_id, cuisine, is_veg)
SELECT place_id, cuisine, is_veg
FROM stg_place
WHERE is_veg IS NOT NULL;

-- 5. tags: create the missing ones, then link
INSERT INTO tag (name)
SELECT DISTINCT lower(trim(t.tag_name))
FROM stg_place_tag t
WHERE NOT EXISTS (SELECT 1 FROM tag g WHERE g.name = lower(trim(t.tag_name)));

INSERT INTO place_tag (place_id, tag_id)
SELECT DISTINCT t.place_id, g.tag_id
FROM stg_place_tag t
JOIN tag g ON g.name = lower(trim(t.tag_name))
ON CONFLICT DO NOTHING;

-- 6. opening_hours: column names match, so copy straight in
--    (columns: place_id, day, open_time, close_time)
\copy opening_hours(place_id, day, open_time, close_time) FROM 'data/csv/opening_hours.csv' WITH (FORMAT csv, HEADER true)

-- 7. If ids are SERIAL/IDENTITY, move the sequences past the loaded ids
--    (returns NULL and does nothing if the column is not serial)
SELECT setval(pg_get_serial_sequence('place', 'place_id'), (SELECT max(place_id) FROM place));
SELECT setval(pg_get_serial_sequence('tag',   'tag_id'),   (SELECT max(tag_id)   FROM tag));

COMMIT;

\echo 'Loaded. Now run: psql -U postgres -d tripgraph -f data/validate_places.sql'
